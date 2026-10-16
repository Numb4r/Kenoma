/// Os spawns ao redor do jogador: Ecos, Fagulhas e pontos de material, derivados de
/// `hash(seed, época, célula, janela)` (docs/fase0-spec.md, seção 3). Dart puro.
///
/// Dois aparelhos com a mesma seed, a mesma época e o mesmo relógio veem os mesmos spawns. O que é
/// individual (o nível do Eco, o que já foi coletado) fica fora daqui ou entra por parâmetro.
library;

import 'dart:math' as math;

import '../core/behavior.dart';
import '../core/epochs.dart';
import '../core/spawn.dart';
import '../core/tiles.dart';
import '../core/weather.dart';
import '../core/windows.dart';
import 'region_map.dart';

/// Um item de spawn no mundo, já com posição e nível.
class WorldSpawn {
  const WorldSpawn({
    required this.uid,
    required this.kind,
    required this.entryId,
    required this.quantity,
    required this.x,
    required this.y,
    required this.cellX,
    required this.cellY,
    required this.window,
    this.level,
    this.behavior = EcoBehavior.passive,
    this.variant,
    this.shiny = false,
  });

  final int uid;

  /// `eco`, `spark` ou `material`.
  final String kind;

  /// Espécie, item de Pó de Essência ou material.
  final String entryId;
  final int quantity;

  /// Posição em células z21 fracionárias.
  final double x;
  final double y;

  /// Célula z20 e janela de onde veio.
  final int cellX;
  final int cellY;
  final int window;

  /// Nível do Eco para o Conjurador de quando ele apareceu. `null` nos outros.
  final int? level;

  /// Só nos Ecos de épocas com o fluxo v2: o comportamento, a chave do bioma da variante e se é Brilhante.
  final EcoBehavior behavior;
  final String? variant;
  final bool shiny;

  /// Cópia com o comportamento, a variante e o Brilhante trocados (o debug força o próximo spawn).
  WorldSpawn withTraits({required EcoBehavior behavior, String? variant, required bool shiny}) => WorldSpawn(
        uid: uid,
        kind: kind,
        entryId: entryId,
        quantity: quantity,
        x: x,
        y: y,
        cellX: cellX,
        cellY: cellY,
        window: window,
        level: level,
        behavior: behavior,
        variant: variant,
        shiny: shiny,
      );

  /// Se é um Eco raro: variante, Brilhante ou Oculto (ou, com [playerLevel], de nível acima do jogador). Só os raros
  /// deixam rastros.
  bool isRare(int playerLevel) => isEco && (variant != null || shiny || behavior == EcoBehavior.hidden || (level ?? 0) > playerLevel);

  bool get isEco => kind == 'eco';
  bool get isSpark => kind == 'spark';
  bool get isMaterial => kind == 'material';

  /// Distância em metros até um ponto, em células z21 fracionárias.
  double distanceM(double px, double py, double metersPerCell21) =>
      math.sqrt((x - px) * (x - px) + (y - py) * (y - py)) * metersPerCell21;
}

class SpawnField {
  SpawnField({required this.seed, required this.schedule, required this.map, this.maxCached = 4000, this.weatherAt, this.typeOf});

  final int seed;
  final EpochSchedule schedule;
  final RegionMap map;
  final int maxCached;

  /// O clima de uma célula z20 no instante, para os pesos de spawn das épocas com o fluxo v2. `null`: sempre limpo.
  final Weather Function(int cellX, int cellY, int tUtc)? weatherAt;

  /// O tipo (`fire`, `plant`, `water`) de uma espécie, para o clima mexer nos pesos.
  final String? Function(String entryId)? typeOf;

  final _cells = <(int, int, int, int), List<SpawnItem>>{};
  final _levels = <int, int>{};

  /// Nível do Eco: `limitar(nível do Conjurador + delta, 1, 20)`, calculado na primeira vez que ele
  /// entra no raio de visão e guardado pelo uid.
  int _levelOf(SpawnItem item, int playerLevel) =>
      _levels.putIfAbsent(item.uid, () => (playerLevel + (item.levelDelta ?? 0)).clamp(1, 20));

  /// Os itens da célula z20 `(cx, cy)` no instante [tUtc]. Todos, existam ou não.
  List<SpawnItem> cellItems(int cx, int cy, int tUtc) {
    final epoch = schedule.select(tUtc).epoch;
    final window = windowIndex(seed, cx, cy, tUtc);
    // O clima só entra nas épocas que o trazem; nas outras a célula não depende dele. É o do COMEÇO da janela de 20 min da
    // célula, não o do instante: assim a espécie de um Eco não muda enquanto o jogador anda até ele, ainda que a janela de 3 h
    // do clima vire no meio.
    final windowStart = window * windowSeconds - windowOffset(seed, cx, cy);
    final weather = epoch.ecoV2 == null || weatherAt == null ? Weather.clear : weatherAt!(cx, cy, windowStart);
    final key = (epoch.id * 8 + weather.index, cx, cy, window);
    final cached = _cells[key];
    if (cached != null) return cached;
    if (_cells.length >= maxCached) _cells.clear();
    final biome = map.biomes.spawnKey(map.spawnBiomeAtCell(cx, cy));
    return _cells[key] = generateCell(seed: seed, epoch: epoch, cellX: cx, cellY: cy, window: window, biomeKey: biome, weather: weather, typeOf: typeOf);
  }

  /// Segundos até a janela da célula acabar.
  int secondsLeft(int cx, int cy, int tUtc) => windowSeconds - (tUtc + windowOffset(seed, cx, cy)) % windowSeconds;

  /// Os spawns existentes a até [radiusM] metros de ([lat], [lon]) em [tUtc].
  List<WorldSpawn> around({
    required double lat,
    required double lon,
    required int tUtc,
    required double radiusM,
    required int playerLevel,
  }) {
    final (px, py) = latLonToTileFraction(lat, lon, biomeZoom);
    final mpc = metersPerCell(lat);
    final r = radiusM / mpc; // em células z21
    final out = <WorldSpawn>[];
    for (var cy = ((py - r) / 2).floor(); cy <= ((py + r) / 2).floor(); cy++) {
      for (var cx = ((px - r) / 2).floor(); cx <= ((px + r) / 2).floor(); cx++) {
        final window = windowIndex(seed, cx, cy, tUtc);
        for (final item in cellItems(cx, cy, tUtc)) {
          if (!item.exists) continue;
          final spawn = WorldSpawn(
            uid: item.uid,
            kind: item.kind,
            entryId: item.entryId,
            quantity: item.quantity,
            x: (cx + item.px) * 2,
            y: (cy + item.py) * 2,
            cellX: cx,
            cellY: cy,
            window: window,
            level: item.kind == 'eco' ? _levelOf(item, playerLevel) : null,
            behavior: item.behavior,
            variant: item.variantBiome,
            shiny: item.shiny,
          );
          if (spawn.distanceM(px, py, mpc) <= radiusM) out.add(spawn);
        }
      }
    }
    return out;
  }
}
