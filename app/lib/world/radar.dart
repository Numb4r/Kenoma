/// O Radar do celular (docs/GDD.md, "Rastros e scanner"): uma varredura mostra os rastros dos Ecos raros por perto e
/// revela os Ocultos bem perto. Dart puro; o desenho das pegadas é de `ui/game/trace_painter.dart`.
///
/// - **Raros** deixam rastro: variante, Brilhante, Oculto ou nível acima do jogador, a até `trace_range_m`.
/// - A direção do rastro erra por até `trace_error_deg`, num erro fixo por Eco e por janela de 20 minutos (muda a
///   cada janela, não a cada quadro).
/// - **Nível 1** do scanner: pegada e direção, e os Ocultos a até `radius_m` aparecem. **Nível 2** (a partir do nível
///   `level2_player_level` do Conjurador): a pegada mostra também o tipo do Eco.
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

/// O que uma varredura achou.
class RadarOutcome {
  const RadarOutcome({required this.traces, required this.revealed});

  final List<Trace> traces;

  /// Os Ocultos que a varredura revelou.
  final List<WorldSpawn> revealed;

  bool get isEmpty => traces.isEmpty && revealed.isEmpty;
}

/// A varredura. [all] são os Ecos ao redor, inclusive os Ocultos; [distanceM] dá a distância do jogador a um deles.
/// [typeOf] diz o tipo de uma espécie. [showS] é quanto tempo os rastros ficam no mapa.
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
  final revealed = <WorldSpawn>[];
  for (final s in all) {
    if (!s.isEco) continue;
    final d = distanceM(s);
    if (s.behavior == EcoBehavior.hidden && d <= balance.radarRadiusM) {
      revealed.add(s);
      continue; // revelado: aparece no mapa, não precisa de rastro
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
  return RadarOutcome(traces: traces, revealed: revealed);
}

/// A direção em que o rastro aponta, no mundo (x leste, y sul; horário na tela): a do Eco visto do jogador mais o erro.
double traceBearing(Trace t, {required double playerX, required double playerY, required double ecoX, required double ecoY}) =>
    math.atan2(ecoY - playerY, ecoX - playerX) + t.errorRad;

/// Quantos segundos faltam para o Radar recarregar. 0 se está pronto.
int radarWaitS({required int lastUtc, required int nowUtc, required StreetLifeBalance balance}) {
  final left = lastUtc + balance.radarCooldownS.round() - nowUtc;
  return left < 0 ? 0 : left;
}
