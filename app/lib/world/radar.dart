/// O Radar do celular (docs/GDD.md, "Rastros e scanner"): um pulso do sonar volta com os rastros dos Ecos raros por perto
/// e com as distorções dos Ocultos bem perto. Dart puro; o sonar é de `ui/menu/radar_screen.dart` e as pegadas no chão, de
/// `ui/game/trace_painter.dart`. Nada aqui muda o mundo: o que o pulso acha é só deste aparelho.
///
/// - **Raros** deixam rastro: variante, Brilhante, Oculto ou nível acima do jogador, a até `trace_range_m`. No sonar o
///   rastro é um arco difuso na direção provável, mais estreito quanto mais perto (`arc_far_deg` longe, `arc_near_deg`
///   perto), e a direção erra por até `trace_error_deg`, sempre dentro do arco, num erro fixo por Eco e por janela de 20
///   minutos (muda a cada janela, não a cada quadro).
/// - **Ocultos** a até `radius_m` voltam como uma distorção no lugar deles: só viram Eco no mapa quando o jogador chega a
///   `hidden_resolve_m` dela.
/// - **Nível 1** do scanner: arco e direção. **Nível 2** (a partir do nível `level2_player_level` do Conjurador): o arco
///   leva a cor do tipo do Eco.
library;

import 'dart:math' as math;

import '../core/behavior.dart';
import '../core/fnv.dart';
import '../core/pcg32.dart';
import '../core/windows.dart';
import 'spawn_field.dart';
import 'street_life_balance.dart';

/// O nível do scanner para o nível [playerLevel] do Conjurador: 1, ou 2 a partir do nível que o balanceamento diz.
int scannerLevel(int playerLevel, StreetLifeBalance b) => playerLevel >= b.radarLevel2PlayerLevel ? 2 : 1;

final int saltTrce = salt('TRCE');

/// O erro da direção do rastro do Eco [uid] na janela de [tUtc], em radianos, entre `-max` e `+max`.
double traceError({required int seed, required int uid, required int tUtc, required double maxDeg}) {
  final window = tUtc ~/ windowSeconds;
  final u = Pcg32(fnv1a64([seed, uid, window, saltTrce]), saltKenoma).nextFloat();
  return (u * 2 - 1) * maxDeg * math.pi / 180;
}

/// Um rastro: aponta do jogador para um Eco raro, com o erro da janela.
class Trace {
  const Trace({required this.uid, required this.errorRad, required this.untilUtc, this.typeId, required this.shiny});

  final int uid;
  final double errorRad;

  /// Até quando o rastro fica no mapa (segundos UTC).
  final int untilUtc;

  /// O tipo do Eco (`fire`, `plant`, `water`), só se o scanner é de nível 2.
  final String? typeId;
  final bool shiny;
}

/// Um Oculto que o pulso achou: aparece como distorção até o jogador chegar perto ou passar de [untilUtc].
class Distortion {
  const Distortion({required this.eco, required this.untilUtc});

  final WorldSpawn eco;
  final int untilUtc;
}

/// O que um pulso achou.
class RadarOutcome {
  const RadarOutcome({required this.traces, required this.distortions});

  final List<Trace> traces;

  /// Os Ocultos a até `radius_m`: distorções, ainda não Ecos no mapa.
  final List<Distortion> distortions;

  bool get isEmpty => traces.isEmpty && distortions.isEmpty;
}

/// O pulso. [all] são os Ecos ao redor, inclusive os Ocultos; [distanceM] dá a distância do jogador a um deles.
/// [typeOf] diz o tipo de uma espécie. [showS] é quanto tempo os rastros e as distorções ficam.
RadarOutcome sweep({
  required List<WorldSpawn> all,
  required double Function(WorldSpawn) distanceM,
  required String? Function(String entryId) typeOf,
  required int seed,
  required int tUtc,
  required int playerLevel,
  required StreetLifeBalance balance,
  int showS = 300,
}) {
  final level = scannerLevel(playerLevel, balance);
  final traces = <Trace>[];
  final distortions = <Distortion>[];
  for (final s in all) {
    if (!s.isEco) continue;
    final d = distanceM(s);
    if (s.behavior == EcoBehavior.hidden && d <= balance.radarRadiusM) {
      distortions.add(Distortion(eco: s, untilUtc: tUtc + showS));
      continue; // perto demais para rastro: a distorção já diz onde está
    }
    if (!s.isRare(playerLevel) || d > balance.traceRangeM || d < balance.traceHideWithinM) continue;
    traces.add(Trace(
      uid: s.uid,
      errorRad: traceError(seed: seed, uid: s.uid, tUtc: tUtc, maxDeg: balance.traceErrorDeg),
      untilUtc: tUtc + showS,
      typeId: level >= 2 ? typeOf(s.entryId) : null,
      shiny: s.shiny,
    ));
  }
  return RadarOutcome(traces: traces, distortions: distortions);
}

/// A largura do arco do rastro a [distanceM] metros, em radianos: `arc_near_deg` até `trace_hide_within_m`, `arc_far_deg`
/// no `trace_range_m` e uma reta entre os dois.
double arcWidthRad(double distanceM, StreetLifeBalance b) {
  final u = ((distanceM - b.traceHideWithinM) / (b.traceRangeM - b.traceHideWithinM)).clamp(0.0, 1.0);
  return (b.arcNearDeg + (b.arcFarDeg - b.arcNearDeg) * u) * math.pi / 180;
}

/// Um eco do sonar: um arco (rastro) ou uma distorção (Oculto), visto do jogador agora. [angleRad] é a direção no mundo
/// (x leste, y sul, como `atan2(dy, dx)`); a tela soma a rotação do mapa.
class SonarEcho {
  const SonarEcho({required this.uid, required this.angleRad, required this.widthRad, required this.distanceM, this.typeId, this.shiny = false, this.distortion = false});

  final int uid;
  final double angleRad;

  /// A largura do arco (0 na distorção, que tem posição certa).
  final double widthRad;
  final double distanceM;

  /// O tipo do Eco no nível 2 do scanner (o arco leva a cor dele), senão `null`.
  final String? typeId;
  final bool shiny;
  final bool distortion;
}

/// O arco do rastro [t] com o jogador em ([playerX], [playerY]) e o Eco em ([ecoX], [ecoY]) (células z21). O centro é a
/// direção do Eco mais o erro da janela, preso a 40% da largura para a direção certa ficar sempre dentro do arco.
SonarEcho traceArc(Trace t, {required double playerX, required double playerY, required double ecoX, required double ecoY, required double metersPerCell, required StreetLifeBalance balance}) {
  final dx = ecoX - playerX, dy = ecoY - playerY;
  final d = math.sqrt(dx * dx + dy * dy) * metersPerCell;
  final width = arcWidthRad(d, balance);
  final err = t.errorRad.clamp(-width * 0.4, width * 0.4);
  return SonarEcho(uid: t.uid, angleRad: math.atan2(dy, dx) + err, widthRad: width, distanceM: d, typeId: t.typeId, shiny: t.shiny);
}

/// Tudo o que o sonar mostra agora: os arcos dos [traces] (dos Ecos de [ecoOf] que ainda existem) e as [distortions].
List<SonarEcho> sonarEchoes({
  required List<Trace> traces,
  required List<Distortion> distortions,
  required WorldSpawn? Function(int uid) ecoOf,
  required double playerX,
  required double playerY,
  required double metersPerCell,
  required StreetLifeBalance balance,
}) {
  final out = <SonarEcho>[];
  for (final t in traces) {
    final e = ecoOf(t.uid);
    if (e != null) out.add(traceArc(t, playerX: playerX, playerY: playerY, ecoX: e.x, ecoY: e.y, metersPerCell: metersPerCell, balance: balance));
  }
  for (final d in distortions) {
    final dx = d.eco.x - playerX, dy = d.eco.y - playerY;
    out.add(SonarEcho(uid: d.eco.uid, angleRad: math.atan2(dy, dx), widthRad: 0, distanceM: math.sqrt(dx * dx + dy * dy) * metersPerCell, distortion: true));
  }
  return out;
}

/// As distorções de [all] a até `hidden_resolve_m` do jogador: o jogador chegou, o Oculto vira Eco.
List<Distortion> reachedDistortions(List<Distortion> all, double Function(WorldSpawn) distanceM, StreetLifeBalance b) =>
    [for (final d in all) if (distanceM(d.eco) <= b.hiddenResolveM) d];

/// Quantos segundos faltam para o Radar recarregar. 0 se está pronto.
int radarWaitS({required int lastUtc, required int nowUtc, required StreetLifeBalance balance}) {
  final left = lastUtc + balance.radarCooldownS.round() - nowUtc;
  return left < 0 ? 0 : left;
}
