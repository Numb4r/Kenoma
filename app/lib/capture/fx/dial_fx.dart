/// Efeito do dial: violeta fora do alinhamento. Alinhado, o dial muda de cor em [dialBlendS], engrossa,
/// brilha e solta partículas. Cor, espessura, brilho e partículas dizem a mesma coisa, então nada
/// depende só da cor.
library;

import 'dart:math' as math;

import 'fx_params.dart';
import 'wave_geometry.dart';

/// Partícula solta do dial: ângulo absoluto onde nasceu, raio (fração do raio do dial) e idade.
class DialParticle {
  DialParticle(this.angle, this.drift, this.speed);

  final double angle;

  /// Desvio de ângulo por segundo.
  final double drift;

  /// Raio por segundo, em frações do raio do dial.
  final double speed;
  double age = 0;

  double get life => (age / dialParticleLifeS).clamp(0.0, 1.0);
  double get radius => 0.9 + speed * age;
  double get alpha => 1 - life;
}

class DialFx {
  /// Mistura de 0 (violeta) a 1 (cor do tipo).
  double blend = 0;
  final List<DialParticle> particles = [];
  double _carry = 0;
  int _spawned = 0;

  /// Espessura do botão e da haste, como múltiplo da normal.
  double get thickness => 1 + (dialAlignedThickness - 1) * blend;

  /// Brilho de 0 a 1.
  double get glow => blend;

  /// Avança [dt]. [dialAngle] é onde o botão está agora, para nascerem partículas ali.
  void update(double dt, {required bool aligned, required double dialAngle}) {
    blend = (blend + (aligned ? dt : -dt) / dialBlendS).clamp(0.0, 1.0);
    for (final p in particles) {
      p.age += dt;
    }
    particles.removeWhere((p) => p.age >= dialParticleLifeS);
    if (!aligned) {
      _carry = 0;
      return;
    }
    _carry += dt * dialParticlesPerS;
    while (_carry >= 1 && particles.length < dialParticleCap) {
      _carry -= 1;
      final i = _spawned++;
      particles.add(DialParticle(
        dialAngle + (hash01(i, 1) - 0.5) * 0.12,
        (hash01(i, 2) - 0.5) * 0.9,
        0.25 + 0.35 * hash01(i, 3),
      ));
    }
    _carry = math.min(_carry, 1);
  }

  /// Volta ao começo, para uma sintonia nova.
  void reset() {
    blend = 0;
    particles.clear();
    _carry = 0;
  }
}
