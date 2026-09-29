/// Sinal do Eco: a frequência `f_t(t)` que o jogador precisa acompanhar (docs/fase0-spec.md, seção 5).
///
/// Tudo sai de um `Pcg32` semeado por quem chama, então uma sintonia é reproduzível e testável.
/// A resistência do tipo mexe no sinal, nunca no dial:
/// - Fogo: picos bruscos que empurram o sinal e depois deixam voltar.
/// - Água: deriva lenta e contínua, como maré.
/// - Planta: o sinal fica firme, mas a tolerância encolhe durante a sintonia.
library;

import 'dart:math' as math;

import '../core/pcg32.dart';
import 'eco_type.dart';
import 'tuning_balance.dart';
import 'vibe.dart';

enum CueKind { fireWarning, waterSwell, plantPulse }

/// Vibração que a UI deve tocar no instante [at] (segundos desde o início da sintonia).
class TuningCue {
  const TuningCue(this.at, this.kind, this.pattern);

  final double at;
  final CueKind kind;
  final VibePattern pattern;
}

class _Kick {
  const _Kick(this.at, this.delta);

  final double at;
  final double delta;
}

class TargetSignal {
  TargetSignal._({
    required this.type,
    required this.intensity,
    required this.balance,
    required this.start,
    required this.wanderPhase,
    required this.waterPhase,
    required this._kicks,
    required this.cues,
  });

  /// Gera o sinal de uma sintonia. A ordem dos sorteios não depende do tipo, então a frequência
  /// inicial e a deriva de base são iguais para o mesmo `rng`, seja qual for o tipo.
  factory TargetSignal.generate({
    required EcoType type,
    required double intensity,
    required Pcg32 rng,
    required TuningBalance balance,
    double horizonS = 60,
  }) {
    final s = balance.signal;
    final start = lerpRange(s.startRange, rng.nextFloat());
    final wanderPhase = 2 * math.pi * rng.nextFloat();
    final waterPhase = 2 * math.pi * rng.nextFloat();

    final kicks = <_Kick>[];
    final cues = <TuningCue>[];
    if (intensity > 0) {
      switch (type) {
        case EcoType.fire:
          final mean = lerpRange(s.fire.intervalS, intensity);
          final size = lerpRange(s.fire.kick, intensity);
          var at = 0.0;
          while (true) {
            at += mean * (0.75 + 0.5 * rng.nextFloat());
            if (at > horizonS) break;
            final sign = rng.nextFloat() < 0.5 ? -1.0 : 1.0;
            kicks.add(_Kick(at, sign * size * (0.7 + 0.6 * rng.nextFloat())));
            cues.add(TuningCue(math.max(0, at - s.fire.warningLeadS), CueKind.fireWarning, fireWarningPattern));
          }
        case EcoType.water:
          for (var at = s.water.cueEveryS; at <= horizonS; at += s.water.cueEveryS) {
            cues.add(TuningCue(at, CueKind.waterSwell, waterSwellPattern));
          }
        case EcoType.plant:
          for (var at = s.plant.cueEveryS; at <= horizonS; at += s.plant.cueEveryS) {
            final u = (at / s.plant.shrinkOverS).clamp(0.0, 1.0);
            cues.add(TuningCue(at, CueKind.plantPulse, plantPulsePattern(lerpRange(s.plant.pulseMs, u).round())));
          }
      }
    }
    return TargetSignal._(
      type: type,
      intensity: intensity,
      balance: balance,
      start: start,
      wanderPhase: wanderPhase,
      waterPhase: waterPhase,
      kicks: kicks,
      cues: cues,
    );
  }

  final EcoType type;
  final double intensity;
  final TuningBalance balance;
  final double start;
  final double wanderPhase;
  final double waterPhase;
  final List<_Kick> _kicks;

  /// Vibrações de resistência, em ordem de instante.
  final List<TuningCue> cues;

  /// Instantes dos picos do Fogo.
  List<double> get kickTimes => [for (final k in _kicks) k.at];

  /// Frequência do sinal, em `[0, 1]`. Bordas do eixo refletem.
  double frequencyAt(double t) {
    final s = balance.signal;
    var f = start + s.wanderAmplitude * math.sin(2 * math.pi * t / s.wanderPeriodS + wanderPhase);
    if (type == EcoType.water && intensity > 0) {
      final amp = lerpRange(s.water.amplitude, intensity);
      final period = lerpRange(s.water.periodS, intensity);
      f += amp * math.sin(2 * math.pi * t / period + waterPhase);
    }
    for (final k in _kicks) {
      if (t >= k.at) f += k.delta * math.exp(-(t - k.at) / s.fire.decayS);
    }
    return _fold(f);
  }

  /// Multiplicador da tolerância no instante [t]. Só a Planta o reduz.
  double toleranceFactorAt(double t) {
    if (type != EcoType.plant) return 1;
    final plant = balance.signal.plant;
    final u = (t / plant.shrinkOverS).clamp(0.0, 1.0);
    return 1 - plant.toleranceShrink * intensity * u;
  }

  /// 1 enquanto a onda deve tremular, perto de um pico do Fogo. 0 nos outros casos.
  double trembleAt(double t) {
    final f = balance.signal.fire;
    for (final k in _kicks) {
      if (t >= k.at - f.warningLeadS && t <= k.at + f.trembleAfterS) return 1;
    }
    return 0;
  }

  /// Vibrações com instante em `(from, to]`.
  List<TuningCue> cuesIn(double from, double to) => [for (final c in cues) if (c.at > from && c.at <= to) c];
}

/// Dobra o valor para dentro de `[0, 1]`, refletindo nas bordas.
double _fold(double f) {
  final m = f % 2;
  final x = m < 0 ? m + 2 : m;
  return x > 1 ? 2 - x : x;
}
