/// Tudo que os mapas precisam para desenhar: o pacote da região (conferido contra a época), as
/// texturas dos biomas e os raios do `balance.json`. Compartilhado pelo mapa livre do debug e pelo mapa
/// do jogo.
library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../core/biomes.dart';
import '../../core/epochs.dart';
import '../../net/signed_feed.dart';
import '../../data/nowalk_pack.dart';
import '../../data/visual_pack.dart';
import '../../world/visual_map.dart';
import '../../data/region_loader.dart';
import '../../world/map_balance.dart';
import '../../world/region_map.dart';
import 'biome_textures.dart';
import 'map_renderer.dart';

/// Região da Fase 0: a única com pacote.
const String kRegion = 'campinas';

class MapAssets {
  MapAssets({required this.map, required this.atlas, required this.balance, required this.stale, this.visual, this.noWalk, this.epoch});

  final RegionMap map;

  /// O atlas de texturas. Quem carrega é quem descarta ([dispose]).
  final ui.Image atlas;
  final MapBalance balance;

  /// O relógio está fora das épocas: o mapa funciona, mas o mundo está desatualizado.
  final bool stale;

  /// As geometrias do pacote visual (ruas, água, verde). Só o mapa do jogo as carrega.
  final VisualMap? visual;

  /// As rodovias e vias expressas, onde Fagulhas, materiais e Ecos da época 2 não nascem. Só com o pacote visual.
  final NoWalkPack? noWalk;
  final Epoch? epoch;

  BiomeSet get biomes => map.biomes;

  MapRenderer makeRenderer() => MapRenderer(map: map, atlas: atlas);

  void dispose() => atlas.dispose();
}

/// Carrega os assets do mapa em [nowUtc] (segundos UTC). Devolve [MapAssets] ou, se o pacote não bate
/// com a época vigente (ou falta algo), a mensagem de erro em português: nunca lança.
Future<Object> loadMapAssets({required int nowUtc, AssetBundle? bundle, bool withVisual = false}) async {
  final assets = bundle ?? rootBundle;
  final region = await loadRegion(region: kRegion, nowUtc: nowUtc, bundle: assets);
  if (region is RegionLoadError) return region.message;
  final loaded = region as RegionLoaded;
  try {
    final biomes = BiomeSet.fromJson(jsonDecode(await assets.loadString('assets/data/biomes.json')) as Map<String, dynamic>);
    final balance = MapBalance(jsonDecode(await assets.loadString('assets/data/balance.json')) as Map<String, dynamic>);
    VisualMap? visual;
    NoWalkPack? noWalk;
    if (withVisual) {
      final pack = await loadVisualPack(region: kRegion, epoch: loaded.epoch, bundle: assets);
      if (pack is! VisualPack) return pack as String;
      visual = VisualMap(pack);
      // A época 2 em diante fixa as vias bloqueadas; vale o pacote da primeira época que o lista, mesmo antes dela começar.
      final schedule = EpochSchedule.fromJson(await loadEpochsJson(bundle: assets));
      final withNoWalk = schedule.epochs.where((e) => e.walkable?.exclude != null).toList();
      if (withNoWalk.isNotEmpty) {
        final nw = await loadNoWalkPack(epoch: withNoWalk.first, bundle: assets);
        if (nw is String) return nw;
        noWalk = nw as NoWalkPack?;
      }
    }
    final atlas = await buildBiomeAtlas(biomes);
    return MapAssets(
        map: RegionMap(pack: loaded.pack, biomes: biomes), atlas: atlas, balance: balance, stale: loaded.stale, visual: visual, noWalk: noWalk, epoch: loaded.epoch);
  } catch (e) {
    return 'Não consegui ler os dados do mapa: $e';
  }
}
