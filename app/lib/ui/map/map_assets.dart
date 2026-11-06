/// Tudo que os mapas precisam para desenhar: o pacote da região (conferido contra a época), as
/// texturas dos biomas e os raios do `balance.json`. Compartilhado pelo mapa livre do debug e pelo mapa
/// do jogo.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory;
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:path_provider/path_provider.dart';

import '../../core/biomes.dart';
import '../../core/epochs.dart';
import '../../net/signed_feed.dart';
import '../../data/block_cache.dart';
import '../../data/map_sources.dart';
import '../../data/nowalk_pack.dart';
import '../../data/visual_pack.dart';
import '../../world/visual_map.dart';
import '../../data/region_loader.dart';
import '../../net/map_http.dart';
import '../../net/region_manager.dart';
import '../../world/fallback_service.dart';
import '../../world/layered_world.dart';
import '../../world/map_balance.dart';
import '../../world/map_fallback_balance.dart';
import '../../world/map_layers.dart';
import '../../world/region_map.dart';
import 'biome_textures.dart';
import 'map_renderer.dart';

/// Região da Fase 0: a única com pacote.
const String kRegion = kBundledRegion;

class MapAssets {
  MapAssets({required this.map, required this.atlas, required this.balance, required this.stale, this.visual, this.noWalk, this.epoch, this.world, this.fallback, this.codec});

  final RegionMap map;

  /// O atlas de texturas. Quem carrega é quem descarta ([dispose]).
  final ui.Image atlas;
  final MapBalance balance;

  /// O relógio está fora das épocas: o mapa funciona, mas o mundo está desatualizado.
  final bool stale;

  /// As geometrias do pacote visual (ruas, água, verde). Só o mapa do jogo as carrega.
  final VisualMap? visual;

  /// As rodovias e vias expressas, onde Fagulhas, materiais e Ecos da época 2 não nascem. Só com o pacote visual.
  final NoWalkSource? noWalk;
  final Epoch? epoch;

  /// O mundo em camadas. Só com o pacote visual: o mapa livre do debug lê o pacote puro.
  final LayeredWorld? world;
  final MapFallbackBalance? fallback;

  /// `null`: sem consultas à Overpass, só pacotes e piso.
  final FallbackCodec? codec;

  BiomeSet get biomes => map.biomes;

  MapRenderer makeRenderer() => MapRenderer(map: map, atlas: atlas);

  void dispose() => atlas.dispose();
}

/// As funções do bloco com as regras do OSM ligadas.
FallbackCodec? fallbackCodec(Map<String, dynamic> biomesJson) {
  // MERGE-A: ligar às funções reais de `world/fallback/` (agente A), trocando o `return null` por:
  //
  //   final rules = OsmRules.fromJson(biomesJson);
  //   return FallbackCodec(
  //     query: ({required tx, required ty, required dateIso}) => overpassQuery(tx: tx, ty: ty, dateIso: dateIso, rules: rules),
  //     build: ({required overpassJson, required tx, required ty, required epochId}) => buildBlock(overpassJson: overpassJson, tx: tx, ty: ty, epochId: epochId, rules: rules),
  //     encode: encodeBlock,
  //     decode: decodeBlock,
  //   );
  //
  // `build`, `encode` e `decode` rodam em Isolate: `OsmRules` tem de ser só dados.
  return null;
}

/// Liga o fallback e os pacotes baixáveis ao mundo de [assets] e recarrega o que está no disco, em segundo plano. Sem pasta de
/// suporte (testes), o mundo fica só com a região embutida.
Future<MapLayers> openMapLayers({
  required MapAssets assets,
  required EpochSchedule schedule,
  required String appVersion,
  required int Function() nowUtc,
  required int Function() realNowUtc,
  required String Function() baseUrl,
  void Function(String message)? onNotice,
  RegionConfirm? confirm,
}) async {
  final world = assets.world!, balance = assets.fallback!;
  final Directory support;
  try {
    support = await getApplicationSupportDirectory();
  } catch (_) {
    return MapLayers(world: world);
  }
  final regions = RegionManager(
    world: world,
    schedule: schedule,
    dir: Directory('${support.path}/regions'),
    confirmBytes: balance.regionConfirmBytes,
    retryS: balance.retryS,
    nowUtc: nowUtc,
    realNowUtc: realNowUtc,
    baseUrl: baseUrl,
    onNotice: onNotice,
    confirm: confirm,
  );
  unawaited(regions.loadInstalled());
  final codec = assets.codec;
  return MapLayers(
    world: world,
    regions: regions,
    fallback: codec == null
        ? null
        : FallbackService(
            world: world,
            schedule: schedule,
            codec: codec,
            balance: balance,
            post: httpPostForm,
            cache: BlockCache(Directory('${support.path}/blocks'), limitBytes: balance.diskLimitBytes),
            appVersion: appVersion,
            nowUtc: nowUtc,
            realNowUtc: realNowUtc,
          ),
  );
}

/// Carrega os assets do mapa em [nowUtc] (segundos UTC). Devolve [MapAssets] ou, se o pacote não bate
/// com a época vigente (ou falta algo), a mensagem de erro em português: nunca lança.
Future<Object> loadMapAssets({required int nowUtc, AssetBundle? bundle, bool withVisual = false}) async {
  final assets = bundle ?? rootBundle;
  final region = await loadRegion(region: kRegion, nowUtc: nowUtc, bundle: assets);
  if (region is RegionLoadError) return region.message;
  final loaded = region as RegionLoaded;
  try {
    final biomesJson = jsonDecode(await assets.loadString('assets/data/biomes.json')) as Map<String, dynamic>;
    final biomes = BiomeSet.fromJson(biomesJson);
    final balanceJson = jsonDecode(await assets.loadString('assets/data/balance.json')) as Map<String, dynamic>;
    final balance = MapBalance(balanceJson);
    VisualMap? visual;
    NoWalkPack? noWalk;
    LayeredWorld? world;
    if (withVisual) {
      final pack = await loadVisualPack(region: kRegion, epoch: loaded.epoch, bundle: assets);
      if (pack is! VisualPack) return pack as String;
      // A época 2 em diante fixa as vias bloqueadas; vale o pacote da primeira época que o lista, mesmo antes dela começar.
      final schedule = EpochSchedule.fromJson(await loadEpochsJson(bundle: assets));
      final withNoWalk = schedule.epochs.where((e) => e.walkable?.exclude != null).toList();
      if (withNoWalk.isNotEmpty) {
        final nw = await loadNoWalkPack(epoch: withNoWalk.first, bundle: assets);
        if (nw is String) return nw;
        noWalk = nw as NoWalkPack?;
      }
      world = LayeredWorld(regions: [LoadedRegion(id: kRegion, grid: loaded.pack, visual: pack, noWalk: noWalk)], maxBlocks: MapFallbackBalance(balanceJson).memoryBlocks);
      visual = VisualMap(world);
    }
    final atlas = await buildBiomeAtlas(biomes);
    return MapAssets(
      map: RegionMap(pack: world ?? loaded.pack, biomes: biomes),
      atlas: atlas,
      balance: balance,
      stale: loaded.stale,
      visual: visual,
      noWalk: world ?? noWalk,
      epoch: loaded.epoch,
      world: world,
      fallback: world == null ? null : MapFallbackBalance(balanceJson),
      codec: world == null ? null : fallbackCodec(biomesJson),
    );
  } catch (e) {
    return 'Não consegui ler os dados do mapa: $e';
  }
}
