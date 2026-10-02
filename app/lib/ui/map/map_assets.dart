/// Tudo que os mapas precisam para desenhar: o pacote da região (conferido contra a época), as
/// texturas dos biomas e os raios do `balance.json`. Compartilhado pelo mapa livre do debug e pelo mapa
/// do jogo.
library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../core/biomes.dart';
import '../../data/region_loader.dart';
import '../../world/map_balance.dart';
import '../../world/region_map.dart';
import 'biome_textures.dart';
import 'map_renderer.dart';

/// Região da Fase 0: a única com pacote.
const String kRegion = 'campinas';

class MapAssets {
  MapAssets({required this.map, required this.atlas, required this.balance, required this.stale});

  final RegionMap map;

  /// O atlas de texturas. Quem carrega é quem descarta ([dispose]).
  final ui.Image atlas;
  final MapBalance balance;

  /// O relógio está fora das épocas: o mapa funciona, mas o mundo está desatualizado.
  final bool stale;

  BiomeSet get biomes => map.biomes;

  MapRenderer makeRenderer() => MapRenderer(map: map, atlas: atlas);

  void dispose() => atlas.dispose();
}

/// Carrega os assets do mapa em [nowUtc] (segundos UTC). Devolve [MapAssets] ou, se o pacote não bate
/// com a época vigente (ou falta algo), a mensagem de erro em português: nunca lança.
Future<Object> loadMapAssets({required int nowUtc, AssetBundle? bundle}) async {
  final assets = bundle ?? rootBundle;
  final region = await loadRegion(region: kRegion, nowUtc: nowUtc, bundle: assets);
  if (region is RegionLoadError) return region.message;
  final loaded = region as RegionLoaded;
  try {
    final biomes = BiomeSet.fromJson(jsonDecode(await assets.loadString('assets/data/biomes.json')) as Map<String, dynamic>);
    final balance = MapBalance(jsonDecode(await assets.loadString('assets/data/balance.json')) as Map<String, dynamic>);
    final atlas = await buildBiomeAtlas(biomes);
    return MapAssets(map: RegionMap(pack: loaded.pack, biomes: biomes), atlas: atlas, balance: balance, stale: loaded.stale);
  } catch (e) {
    return 'Não consegui ler os dados do mapa: $e';
  }
}
