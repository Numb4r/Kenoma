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
    required this.waterPhase2,
    required this.tidePhase,
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
    // Ordem dos sorteios: a frequência inicial, a fase da deriva, a fase da primeira senoide da
    // Água e os picos do Fogo vêm primeiro e não mudam. Os sorteios novos entram no fim.
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
          break; // os avisos dependem do sinal pronto: entram logo abaixo
        case EcoType.plant:
          for (var at = s.plant.cueEveryS; at <= horizonS; at += s.plant.cueEveryS) {
            final u = (at / s.plant.shrinkOverS).clamp(0.0, 1.0);
            cues.add(TuningCue(at, CueKind.plantPulse, plantPulsePattern(lerpRange(s.plant.pulseMs, u).round())));
          }
      }
    }
    // Sorteios novos, no fim da sequência.
    final waterPhase2 = 2 * math.pi * rng.nextFloat();
    final tidePhase = 2 * math.pi * rng.nextFloat();

    final signal = TargetSignal._(
      type: type,
      intensity: intensity,
      balance: balance,
      start: start,
      wanderPhase: wanderPhase,
      waterPhase: waterPhase,
      waterPhase2: waterPhase2,
      tidePhase: tidePhase,
      kicks: kicks,
      cues: cues,
    );
    if (type == EcoType.water && intensity > 0) cues.addAll(signal._waterCues(horizonS));
    return signal;
  }

  final EcoType type;
  final double intensity;
  final TuningBalance balance;
  final double start;
  final double wanderPhase;
  final double waterPhase;
  final double waterPhase2;
  final double tidePhase;
  final List<_Kick> _kicks;

  /// Vibrações de resistência, em ordem de instante.
  final List<TuningCue> cues;

  /// Instantes dos picos do Fogo.
  List<double> get kickTimes => [for (final k in _kicks) k.at];

  /// Frequência do sinal, em `[0, 1]`. Bordas do eixo refletem.
  double frequencyAt(double t) {
    final s = balance.signal;
    var f = start + s.wanderAmplitude * math.sin(2 * math.pi * t / s.wanderPeriodS + wanderPhase);
    f += waterOffsetAt(t);
    for (final k in _kicks) {
      if (t >= k.at) f += k.delta * math.exp(-(t - k.at) / s.fire.decayS);
    }
    return _fold(f);
  }

  /// Deriva da Água antes de dobrar nas bordas: duas senoides, com períodos `P` e `P × 1,618`, e a
  /// amplitude total modulada pela maré lenta. 0 fora da Água ou sem resistência.
  double waterOffsetAt(double t) {
    if (type != EcoType.water || intensity <= 0) return 0;
    final w = balance.signal.water;
    final amp = lerpRange(w.amplitude, intensity);
    final p1 = lerpRange(w.periodS, intensity);
    final p2 = p1 * w.secondPeriodRatio;
    final tide = (1 + w.tideMin) / 2 + (1 - w.tideMin) / 2 * math.sin(2 * math.pi * t / w.tidePeriodS + tidePhase);
    return tide *
        amp *
        ((1 - w.secondWeight) * math.sin(2 * math.pi * t / p1 + waterPhase) +
            w.secondWeight * math.sin(2 * math.pi * t / p2 + waterPhase2));
  }

  /// Um aviso [WaterBalance.cueLeadS] antes de cada inversão de sentido do sinal (topo, fundo ou
  /// batida na borda do eixo), achadas amostrando o sinal a cada 10 ms.
  List<TuningCue> _waterCues(double horizonS) {
    const step = 0.01;
    final lead = balance.signal.water.cueLeadS;
    final out = <TuningCue>[];
    var prev = frequencyAt(0);
    var prevDir = 0;
    for (var i = 1; i * step <= horizonS + lead; i++) {
      final f = frequencyAt(i * step);
      final dir = f > prev ? 1 : (f < prev ? -1 : 0);
      if (dir != 0) {
        if (prevDir != 0 && dir != prevDir) {
          final at = (i - 1) * step - lead; // o ponto de inversão ficou um passo para trás
          if (at > 0 && at <= horizonS) out.add(TuningCue(at, CueKind.waterSwell, waterSwellPattern));
        }
        prevDir = dir;
      }
      prev = f;
    }
    return out;
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
