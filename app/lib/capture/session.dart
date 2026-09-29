/// Sessão de sintonia: progresso, tempo e resultado (docs/fase0-spec.md, seção 5).
/// Lógica pura. A tela só desenha o estado e repassa o valor do dial.
library;

import '../core/pcg32.dart';
import 'signal.dart';
import 'tuning_balance.dart';

enum TuningPhase { running, success, failed }

class TuningSession {
  TuningSession({
    required this.signal,
    required this.baseTolerance,
    required this.balance,
    required this.timeLimitS,
    double initialDial = 0.5,
  }) : dial = initialDial;

  final TargetSignal signal;

  /// Tolerância antes de a Planta encolhê-la.
  final double baseTolerance;
  final TuningBalance balance;

  /// 20 s, ou 25 s com tônico.
  final double timeLimitS;

  double dial;
  double t = 0;
  double progress = 0;
  TuningPhase phase = TuningPhase.running;

  bool get running => phase == TuningPhase.running;
  double get targetFrequency => signal.frequencyAt(t);
  double get tolerance => baseTolerance * signal.toleranceFactorAt(t);

  /// Alinhado quando `|f_p − f_t| ≤ tolerância`.
  bool get aligned => (dial - targetFrequency).abs() <= tolerance;
  double get timeRemaining => (timeLimitS - t).clamp(0.0, timeLimitS);

  /// Avança [dt] segundos com o dial em [dial]. Devolve as vibrações de resistência do intervalo.
  List<TuningCue> step(double dt, {required double dial}) {
    if (!running) return const [];
    this.dial = dial.clamp(0.0, 1.0);
    final before = t;
    t += dt;
    final rate = aligned ? balance.progressUpPerS : -balance.progressDownPerS;
    progress = (progress + rate * dt).clamp(0.0, 1.0);
    if (progress >= 1) {
      phase = TuningPhase.success;
    } else if (t >= timeLimitS) {
      phase = TuningPhase.failed;
    }
    return signal.cuesIn(before, t);
  }
}

class TuningOutcome {
  const TuningOutcome({required this.success, required this.durationS, this.ectoplasm = 0, this.fled = false});

  final bool success;
  final double durationS;

  /// Ectoplasma ganho no sucesso.
  final int ectoplasm;

  /// Na falha, se a criatura fugiu. Se não fugiu, dá para tentar de novo.
  final bool fled;
}

/// Resultado de uma sessão terminada: no sucesso, 1 ou 2 de Ectoplasma; na falha, 50% de chance de fuga.
TuningOutcome resolveTuning(TuningSession session, Pcg32 rng) {
  assert(!session.running, 'a sintonia ainda está em andamento');
  final b = session.balance;
  if (session.phase == TuningPhase.success) {
    final (lo, hi) = b.ectoplasmReward;
    return TuningOutcome(success: true, durationS: session.t, ectoplasm: lo + rng.nextInt(hi - lo + 1));
  }
  return TuningOutcome(success: false, durationS: session.t, fled: rng.nextFloat() < b.fleeChanceOnFail);
}
