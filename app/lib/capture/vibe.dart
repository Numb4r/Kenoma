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
