/// Sinal do Eco: a frequência `f_t(t)` que o jogador precisa acompanhar (docs/fase0-spec.md, seção 5).
///
/// Tudo sai de um `Pcg32` semeado por quem chama, então uma sintonia é reproduzível e testável.
/// A resistência do tipo mexe no sinal, nunca no dial:
/// - Fogo: a onda se parte em duas num ponto de queima. A real, à direita, desliza para a nova
///   frequência e fica lá. A isca, à esquerda, segue na frequência antiga e depois vira cinza.
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
  const _Kick(this.at, this.delta, [this.burnU = 0]);

  final double at;
  final double delta;

  /// Ponto da onda, de 0 a 1, onde a queima parte a onda em duas.
  final double burnU;
}

/// Isca de um pico já passado: onde ela nasceu e a frequência dela agora.
class RetiredDecoy {
  const RetiredDecoy(this.burnU, this.frequency, this.since);

  final double burnU;
  final double frequency;

  /// Segundos desde o pico que a aposentou.
  final double since;
}

/// A onda do Fogo partida em duas, vista no instante [t] (só existe depois do primeiro pico). A real é
/// sempre a que fica à direita de [burnU], e `frequencyAt` já é a dela. A queima é a fronteira vertical.
class FireSplit {
  const FireSplit({
    required this.index,
    required this.burnU,
    required this.since,
    required this.decoyFrequency,
    required this.decoyLife,
    this.retired,
  });

  /// Número do pico, a partir de 0.
  final int index;
  final double burnU;

  /// Segundos desde o pico.
  final double since;

  /// Frequência da isca: a antiga, com a mesma deriva de base.
  final double decoyFrequency;

  /// Quanto falta da vida da isca, de 1 (acabou de nascer) a 0 (cinza).
  final double decoyLife;

  /// A isca do pico anterior, que virou cinza na hora porque um pico novo veio. `null` se ela já
  /// estava cinza ou se este é o primeiro pico.
  final RetiredDecoy? retired;

  bool get decoyAlive => decoyLife > 0;
}

double _smoothstep(double x) {
  final c = x.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
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
    required this.plantDirection,
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
            cues.add(TuningCue(math.max(0, at - lerpRange(s.fire.warningLeadS, intensity)), CueKind.fireWarning, fireWarningPattern));
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
    final plantDirection = rng.nextFloat() < 0.5 ? -1.0 : 1.0;
    // A posição da queima de cada pico, em ordem, depois de todos os sorteios que já existiam.
    final burned = [for (final k in kicks) _Kick(k.at, k.delta, lerpRange(s.fire.burnU, rng.nextFloat()))];

    final signal = TargetSignal._(
      type: type,
      intensity: intensity,
      balance: balance,
      start: start,
      wanderPhase: wanderPhase,
      waterPhase: waterPhase,
      waterPhase2: waterPhase2,
      tidePhase: tidePhase,
      plantDirection: plantDirection,
      kicks: burned,
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

  /// Sentido do crescimento da Planta: -1 ou 1.
  final double plantDirection;
  final List<_Kick> _kicks;

  /// Vibrações de resistência, em ordem de instante.
  final List<TuningCue> cues;

  /// Instantes dos picos do Fogo.
  List<double> get kickTimes => [for (final k in _kicks) k.at];

  /// Salto da onda real em cada pico, em ordem: com sinal, em fração do eixo.
  List<double> get kickDeltas => [for (final k in _kicks) k.delta];

  /// Posição da queima de cada pico, em ordem.
  List<double> get burnUs => [for (final k in _kicks) k.burnU];

  /// Tempo que a onda real leva para deslizar até a nova frequência.
  double get fireGlideS => lerpRange(balance.signal.fire.glideS, intensity);

  /// Antecedência da brasa e do aviso: cai com a intensidade.
  double get fireWarningLeadS => lerpRange(balance.signal.fire.warningLeadS, intensity);

  /// Tempo que a isca vive antes de virar cinza.
  double get fireDecoyS => lerpRange(balance.signal.fire.decoyS, intensity);

  /// Frequência da onda real, em `[0, 1]`. Bordas do eixo refletem. É contra ela que a tolerância e o
  /// progresso são medidos.
  ///
  /// No Fogo, cada pico soma o salto dele à frequência com easing smoothstep durante [fireGlideS], e
  /// o salto não decai.
  double frequencyAt(double t) {
    var f = _baseAt(t) + waterOffsetAt(t) + plantOffsetAt(t);
    final glide = fireGlideS;
    for (final k in _kicks) {
      if (t < k.at) break;
      f += k.delta * _smoothstep((t - k.at) / glide);
    }
    return _fold(f);
  }

  /// Frequência inicial mais a deriva lenta de base, que todas as ondas compartilham.
  double _baseAt(double t) {
    final s = balance.signal;
    return start + s.wanderAmplitude * math.sin(2 * math.pi * t / s.wanderPeriodS + wanderPhase);
  }

  /// Frequência da isca do pico [i] no instante [t]: a da real sem o salto dele (os anteriores
  /// valem) e, com a intensidade acima de `decoy_counter_from`, um deslize no sentido oposto ao da real.
  double decoyFrequencyAt(int i, double t) {
    final fire = balance.signal.fire;
    var f = _baseAt(t);
    final glide = fireGlideS;
    for (var j = 0; j < i; j++) {
      f += _kicks[j].delta * _smoothstep((t - _kicks[j].at) / glide);
    }
    if (intensity > fire.decoyCounterFrom) {
      f -= fire.decoyCounter * _kicks[i].delta * _smoothstep((t - _kicks[i].at) / glide);
    }
    return _fold(f);
  }

  /// A onda do Fogo partida em duas no instante [t]. `null` antes do primeiro pico e fora do Fogo.
  FireSplit? fireSplitAt(double t) {
    var i = -1;
    while (i + 1 < _kicks.length && _kicks[i + 1].at <= t) {
      i++;
    }
    if (i < 0) return null;
    final k = _kicks[i];
    final since = t - k.at;
    // Um pico novo mata a isca antiga na hora: a vida acaba no instante dele.
    RetiredDecoy? retired;
    if (i > 0 && k.at - _kicks[i - 1].at < fireDecoyS) {
      retired = RetiredDecoy(_kicks[i - 1].burnU, decoyFrequencyAt(i - 1, t), since);
    }
    return FireSplit(
      index: i,
      burnU: k.burnU,
      since: since,
      decoyFrequency: decoyFrequencyAt(i, t),
      decoyLife: (1 - since / fireDecoyS).clamp(0.0, 1.0),
      retired: retired,
    );
  }

  /// Deriva da Água antes de dobrar nas bordas: duas senoides, com períodos `P` e `P × 1,618`, e a
  /// amplitude total modulada pela maré lenta. 0 fora da Água ou sem resistência.
  double waterOffsetAt(double t) {
    if (type != EcoType.water || intensity <= 0) return 0;
    final w = balance.signal.water;
    final amp = lerpRange(w.amplitude, intensity);
    final p1 = lerpRange(w.periodS, intensity);
    final p2 = p1 * w.secondPeriodRatio;
    return tideAt(t) *
        amp *
        ((1 - w.secondWeight) * math.sin(2 * math.pi * t / p1 + waterPhase) +
            w.secondWeight * math.sin(2 * math.pi * t / p2 + waterPhase2));
  }

  /// Maré da Água em `[tide.min, 1]`: o fator que modula a amplitude da deriva. 1 fora da Água ou
  /// sem resistência.
  double tideAt(double t) {
    if (type != EcoType.water || intensity <= 0) return 1;
    final w = balance.signal.water;
    return (1 + w.tideMin) / 2 + (1 - w.tideMin) / 2 * math.sin(2 * math.pi * t / w.tidePeriodS + tidePhase);
  }

  /// Crescimento da Planta antes de dobrar nas bordas: uma deriva contínua no sentido sorteado e,
  /// a cada pulso de vibração, um passo extra no mesmo sentido (o broto). 0 fora da Planta ou sem
  /// resistência.
  double plantOffsetAt(double t) {
    if (type != EcoType.plant || intensity <= 0) return 0;
    final p = balance.signal.plant;
    final rate = lerpRange(p.growthPerS, intensity);
    final step = lerpRange(p.budStep, intensity);
    final buds = cues.where((c) => c.at <= t).length;
    return plantDirection * (rate * t + step * buds);
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
    return math.max(plant.toleranceFloor, 1 - plant.toleranceShrink * intensity * u);
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
