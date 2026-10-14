/// Os spawns ao redor do jogador: Ecos, Fagulhas e pontos de material, derivados de
/// `hash(seed, época, célula, janela)` (docs/fase0-spec.md, seção 3). Dart puro.
///
/// Dois aparelhos com a mesma seed, a mesma época e o mesmo relógio veem os mesmos spawns. O que é
/// individual (o nível do Eco, o que já foi coletado) fica fora daqui ou entra por parâmetro.
library;

import 'dart:math' as math;

import '../core/epochs.dart';
import '../core/spawn.dart';
import '../core/tiles.dart';
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

  bool get isEco => kind == 'eco';
  bool get isSpark => kind == 'spark';
  bool get isMaterial => kind == 'material';

  /// Distância em metros até um ponto, em células z21 fracionárias.
  double distanceM(double px, double py, double metersPerCell21) =>
      math.sqrt((x - px) * (x - px) + (y - py) * (y - py)) * metersPerCell21;
}

class SpawnField {
  SpawnField({required this.seed, required this.schedule, required this.map, this.maxCached = 4000});

  final int seed;
  final EpochSchedule schedule;
  final RegionMap map;
  final int maxCached;

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
    final key = (epoch.id, cx, cy, window);
    final cached = _cells[key];
    if (cached != null) return cached;
    if (_cells.length >= maxCached) _cells.clear();
    final biome = map.biomes.spawnKey(map.spawnBiomeAtCell(cx, cy));
    return _cells[key] = generateCell(seed: seed, epoch: epoch, cellX: cx, cellY: cy, window: window, biomeKey: biome);
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
          );
          if (spawn.distanceM(px, py, mpc) <= radiusM) out.add(spawn);
        }
      }
    }
    return out;
  }
}
