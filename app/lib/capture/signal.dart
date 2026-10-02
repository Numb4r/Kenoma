/// Sinal do Eco: a frequência `f_t(t)` que o jogador precisa acompanhar (docs/fase0-spec.md, seção 5).
///
/// Tudo sai de um `Pcg32` semeado por quem chama, então uma sintonia é reproduzível e testável.
/// A resistência do tipo mexe no sinal, nunca no dial:
/// - Fogo: a onda se parte em duas num ponto de queima e as duas rolam para a esquerda (ver
///   `fire_wave.dart`). A real, à direita, desliza para a nova frequência e fica lá. A isca, à
///   esquerda, é cinza, segue na frequência antiga e acaba quando sai da tela.
/// - Água: deriva lenta e contínua, como maré.
/// - Planta: o sinal cresce e dá brotos, e cada broto finca uma raiz numa faixa do dial (ver
///   `plant_roots.dart`). A tolerância não encolhe.
library;

import 'dart:math' as math;

import '../core/pcg32.dart';
import 'eco_type.dart';
import 'fire_wave.dart';
import 'plant_roots.dart';
import 'signal_math.dart';
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
    required this.fire,
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

    final kickTimes = <double>[];
    final kickDeltas = <double>[];
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
            kickTimes.add(at);
            kickDeltas.add(sign * size * (0.7 + 0.6 * rng.nextFloat()));
            cues.add(TuningCue(math.max(0, at - lerpRange(s.fire.warningLeadS, intensity)), CueKind.fireWarning, fireWarningPattern));
          }
        case EcoType.water:
          break; // os avisos dependem do sinal pronto: entram logo abaixo
        case EcoType.plant:
          for (var at = s.plant.cueEveryS; at <= horizonS; at += s.plant.cueEveryS) {
            final u = (at / s.plant.pulseOverS).clamp(0.0, 1.0);
            cues.add(TuningCue(at, CueKind.plantPulse, plantPulsePattern(lerpRange(s.plant.pulseMs, u).round())));
          }
      }
    }
    // Sorteios novos, no fim da sequência.
    final waterPhase2 = 2 * math.pi * rng.nextFloat();
    final tidePhase = 2 * math.pi * rng.nextFloat();
    final plantDirection = rng.nextFloat() < 0.5 ? -1.0 : 1.0;
    // A posição da queima de cada pico e o deslocamento de cada raiz da Planta, em ordem, depois de
    // todos os sorteios que já existiam.
    final burnDraws = [for (final _ in kickTimes) rng.nextFloat()];
    final rootDraws = [if (type == EcoType.plant) for (final _ in cues) rng.nextFloat()];

    double baseAt(double t) =>
        start + s.wanderAmplitude * math.sin(2 * math.pi * t / s.wanderPeriodS + wanderPhase);
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
      fire: kickTimes.isEmpty
          ? FireWave.none(s.fire, baseAt)
          : FireWave.build(
              times: kickTimes, deltas: kickDeltas, draws: burnDraws, fire: s.fire, intensity: intensity, baseAt: baseAt),
      cues: cues,
    );
    if (rootDraws.isNotEmpty) {
      signal.plantRoots = PlantRoots.build(
        times: [for (final c in cues) c.at],
        draws: rootDraws,
        plant: s.plant,
        intensity: intensity,
        frequencyAt: signal.frequencyAt,
      );
    }
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

  /// A onda do Fogo: picos, fronteiras e trechos. Vazia fora do Fogo.
  final FireWave fire;

  /// As raízes da Planta. Vazio fora da Planta.
  PlantRoots plantRoots = PlantRoots.none;

  /// Vibrações de resistência, em ordem de instante.
  final List<TuningCue> cues;

  /// Instantes dos picos do Fogo.
  List<double> get kickTimes => [for (final k in fire.kicks) k.at];

  /// Salto da onda real em cada pico, em ordem: com sinal, em fração do eixo.
  List<double> get kickDeltas => [for (final k in fire.kicks) k.delta];

  /// Posição da queima de cada pico, em ordem.
  List<double> get burnUs => [for (final k in fire.kicks) k.burnU];

  /// Tempo que o trecho novo leva para deslizar até a nova frequência.
  double get fireGlideS => fire.glideS;

  /// Antecedência da brasa e do aviso: cai com a intensidade.
  double get fireWarningLeadS => lerpRange(balance.signal.fire.warningLeadS, intensity);

  /// Frequência da onda real, em `[0, 1]`. Bordas do eixo refletem. É contra ela que a tolerância e o
  /// progresso são medidos.
  ///
  /// No Fogo, cada pico soma o salto dele à frequência com easing smoothstep durante [fireGlideS], e
  /// o salto não decai.
  double frequencyAt(double t) => fold01(_baseAt(t) + waterOffsetAt(t) + plantOffsetAt(t) + fire.offsetAt(t));

  /// Frequência inicial mais a deriva lenta de base, que todas as ondas compartilham.
  double _baseAt(double t) {
    final s = balance.signal;
    return start + s.wanderAmplitude * math.sin(2 * math.pi * t / s.wanderPeriodS + wanderPhase);
  }

  /// Frequência da isca do pico [i] em [t] (ver `FireWave.decoyFrequencyAt`).
  double decoyFrequencyAt(int i, double t) => fire.decoyFrequencyAt(i, t);

  /// Onde a fronteira do pico [i] está em [t]: nasce na queima e rola para a esquerda.
  double fireBoundaryUAt(int i, double t) => fire.boundaryUAt(i, t);

  /// A onda do Fogo partida em duas em [t]: trechos, fronteira e vida da isca. `null` antes do
  /// primeiro pico e fora do Fogo.
  FireSplit? fireSplitAt(double t) => fire.splitAt(t, frequencyAt(t));

  /// As raízes vivas da Planta em [t].
  List<PlantRoot> rootsAt(double t) => plantRoots.activeAt(t);

  /// Se o dial está dentro de uma raiz viva em [t]: aí a sintonia é interrompida.
  bool dialInRoot(double dial, double t) => plantRoots.dialInRoot(dial, t);

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

  /// Vibrações com instante em `(from, to]`.
  List<TuningCue> cuesIn(double from, double to) => [for (final c in cues) if (c.at > from && c.at <= to) c];
}
