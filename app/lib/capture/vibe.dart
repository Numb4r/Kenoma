/// Padrões de vibração como dados. Quem toca é a camada de UI, com o pacote `vibration`.
///
/// Cada tipo tem uma identidade que dá para reconhecer de olhos fechados:
/// - Fogo: toques secos e muito curtos, em rajada.
/// - Água: uma onda longa e contínua, que sobe e desce.
/// - Planta: pulsos cada vez mais curtos.
library;

import 'eco_type.dart';

class VibeSegment {
  const VibeSegment(this.pauseMs, this.durationMs, this.amplitude);

  final int pauseMs;
  final int durationMs;

  /// 1 a 255. Aparelhos sem controle de amplitude ignoram.
  final int amplitude;
}

class VibePattern {
  const VibePattern(this.segments);

  final List<VibeSegment> segments;

  int get totalMs => segments.fold(0, (sum, s) => sum + s.pauseMs + s.durationMs);

  /// No formato do pacote `vibration`: espera, vibra, espera, vibra...
  List<int> get pattern => [for (final s in segments) ...[s.pauseMs, s.durationMs]];

  /// Uma amplitude por posição de [pattern]: 0 nas esperas.
  List<int> get intensities => [for (final s in segments) ...[0, s.amplitude]];

  /// Versão para aparelhos sem controle de amplitude: a intensidade vira a fração de tempo ligado
  /// dentro de cada [periodMs] (PWM). O motor demora a girar, então ligar 30% do período dá um
  /// toque fraco e 100% dá o toque cheio. Segmentos a partir de [fullFrom] ficam como estão.
  /// Fatias com menos de [minOnMs] ligado não moveriam o motor e viram silêncio.
  VibePattern toOnOff({int periodMs = 40, int fullFrom = 200, int minOnMs = 8}) {
    final out = <VibeSegment>[];
    var carry = 0; // silêncio acumulado que vai para a pausa do próximo toque
    for (final s in segments) {
      if (s.amplitude >= fullFrom) {
        out.add(VibeSegment(s.pauseMs + carry, s.durationMs, 255));
        carry = 0;
        continue;
      }
      carry += s.pauseMs;
      final onMs = (periodMs * s.amplitude / 255).round();
      final slices = s.durationMs ~/ periodMs;
      for (var i = 0; i < slices; i++) {
        if (onMs < minOnMs) {
          carry += periodMs;
        } else {
          out.add(VibeSegment(carry, onMs, 255));
          carry = periodMs - onMs;
        }
      }
      carry += s.durationMs - slices * periodMs;
    }
    return VibePattern(out);
  }
}

/// Vibração de identidade, no início de toda sintonia, com ou sem resistência.
VibePattern identityPattern(EcoType type) => switch (type) {
      EcoType.fire => const VibePattern([
          VibeSegment(0, 30, 255),
          VibeSegment(50, 30, 255),
          VibeSegment(50, 30, 255),
          VibeSegment(50, 30, 255),
        ]),
      EcoType.water => const VibePattern([
          VibeSegment(0, 70, 40),
          VibeSegment(0, 70, 90),
          VibeSegment(0, 70, 150),
          VibeSegment(0, 70, 210),
          VibeSegment(0, 70, 255),
          VibeSegment(0, 70, 255),
          VibeSegment(0, 70, 210),
          VibeSegment(0, 70, 150),
          VibeSegment(0, 70, 90),
          VibeSegment(0, 70, 40),
        ]),
      EcoType.plant => const VibePattern([
          VibeSegment(0, 150, 220),
          VibeSegment(90, 110, 220),
          VibeSegment(90, 75, 220),
          VibeSegment(90, 45, 220),
        ]),
    };

/// Aviso curto antes de cada pico do Fogo.
const VibePattern fireWarningPattern = VibePattern([VibeSegment(0, 40, 255)]);

/// Ondulação longa da deriva da Água.
const VibePattern waterSwellPattern = VibePattern([
  VibeSegment(0, 90, 45),
  VibeSegment(0, 90, 140),
  VibeSegment(0, 90, 255),
  VibeSegment(0, 90, 140),
  VibeSegment(0, 90, 45),
]);

/// Pulso da Planta, com a duração dada. Os pulsos encurtam conforme a tolerância encolhe.
VibePattern plantPulsePattern(int durationMs) => VibePattern([VibeSegment(0, durationMs, 200)]);

/// Sintonia selada: dois toques que sobem.
const VibePattern successPattern = VibePattern([VibeSegment(0, 60, 120), VibeSegment(70, 120, 255)]);

/// Sinal perdido: um zumbido longo e grave.
const VibePattern failPattern = VibePattern([VibeSegment(0, 500, 90)]);
