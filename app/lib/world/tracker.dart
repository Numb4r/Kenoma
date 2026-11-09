/// O rastreador da borda direita: num só lugar, o que o Radar achou (rastros e distorções) e os Ecos perto do jogador que
/// estão fora da tela, com a distância e a direção. Dart puro.
library;

import 'dart:math' as math;

import 'radar.dart';
import 'spawn_field.dart';

class TrackedEco {
  const TrackedEco({required this.spawn, required this.distanceM, required this.angle, this.find});

  final WorldSpawn spawn;
  final double distanceM;

  /// Direção do jogador até o Eco, em radianos, no sentido da tela (x para a direita, y para baixo). No rastro, a direção
  /// provável (o centro do arco), não a certa.
  final double angle;

  /// O que o Radar achou: um arco de rastro ou uma distorção. `null`: o Eco está à vista, só fora da tela.
  final SonarEcho? find;
}

/// Até [max] entradas: primeiro o que o Radar achou ([finds], do mais perto ao mais longe) e que não está à vista em
/// [spawns], depois os Ecos de [spawns] a no máximo [trackerM] metros de ([playerX], [playerY]) (células z21
/// fracionárias) para os quais [offScreen] é verdadeiro, do mais perto para o mais longe.
List<TrackedEco> trackEcos({
  required List<WorldSpawn> spawns,
  required double playerX,
  required double playerY,
  required double metersPerCell21,
  required double trackerM,
  required bool Function(WorldSpawn) offScreen,
  required int max,
  List<({WorldSpawn eco, SonarEcho echo})> finds = const [],
}) {
  final visible = {for (final s in spawns) s.uid};
  final found = [
    for (final f in finds)
      if (!visible.contains(f.eco.uid)) TrackedEco(spawn: f.eco, distanceM: f.echo.distanceM, angle: f.echo.angleRad, find: f.echo),
  ]..sort((a, b) => a.distanceM.compareTo(b.distanceM));
  final out = <TrackedEco>[];
  for (final s in spawns) {
    if (!s.isEco || !offScreen(s)) continue;
    final d = s.distanceM(playerX, playerY, metersPerCell21);
    if (d > trackerM) continue;
    out.add(TrackedEco(spawn: s, distanceM: d, angle: math.atan2(s.y - playerY, s.x - playerX)));
  }
  out.sort((a, b) => a.distanceM.compareTo(b.distanceM));
  final all = [...found, ...out];
  return all.length > max ? all.sublist(0, max) : all;
}
