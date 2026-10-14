/// O rastreador: os Ecos perto do jogador que estão fora da tela, com a distância e a direção. Dart puro.
library;

import 'dart:math' as math;

import 'spawn_field.dart';

class TrackedEco {
  const TrackedEco({required this.spawn, required this.distanceM, required this.angle});

  final WorldSpawn spawn;
  final double distanceM;

  /// Direção do jogador até o Eco, em radianos, no sentido da tela (x para a direita, y para baixo).
  final double angle;
}

/// Até [max] Ecos de [spawns] a no máximo [trackerM] metros de ([playerX], [playerY]) (células z21
/// fracionárias) e para os quais [offScreen] é verdadeiro, do mais perto para o mais longe.
List<TrackedEco> trackEcos({
  required List<WorldSpawn> spawns,
  required double playerX,
  required double playerY,
  required double metersPerCell21,
  required double trackerM,
  required bool Function(WorldSpawn) offScreen,
  required int max,
}) {
  final out = <TrackedEco>[];
  for (final s in spawns) {
    if (!s.isEco || !offScreen(s)) continue;
    final d = s.distanceM(playerX, playerY, metersPerCell21);
    if (d > trackerM) continue;
    out.add(TrackedEco(spawn: s, distanceM: d, angle: math.atan2(s.y - playerY, s.x - playerX)));
  }
  out.sort((a, b) => a.distanceM.compareTo(b.distanceM));
  return out.length > max ? out.sublist(0, max) : out;
}
