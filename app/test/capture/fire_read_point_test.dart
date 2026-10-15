import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/fx/wave_geometry.dart';

import '../support/reference_player.dart';

/// A regra do Fogo: a frequência medida (tolerância e progresso) é exatamente a da onda real desenhada
/// no ponto de leitura, e o dial nessa frequência faz o progresso subir.
void main() {
  final balance = loadTuningBalance();
  const levels = [(1, 1), (5, 10), (10, 15), (15, 20)];

  /// A frequência que a onda desenhada em [u] tem, lida da geometria: a derivada da fase dá os ciclos.
  double drawnFrequency(WaveSegment s, double u) {
    const e = 1e-5;
    final cycles = (s.thetaAt(u + e) - s.thetaAt(u - e)) / (2 * e) / (2 * math.pi);
    return (cycles - 1.5) / 5.0; // inverso de waveCycles
  }

  test('a queima nunca passa do ponto de leitura, nem no caso de trecho vivo curto', () {
    final fire = balance.signal.fire;
    expect(fire.burnU.$2, lessThan(waveReadU));
    expect(fire.burnEdgeU, lessThan(waveReadU));
  });

  test('em qualquer instante, a onda desenhada no ponto de leitura é a real e tem a frequência de frequencyAt(t)', () {
    var checked = 0;
    for (final (pl, eco) in levels) {
      for (var seed = 0; seed < 30; seed++) {
        final s = makeSession(type: EcoType.fire, playerLevel: pl, ecoLevel: eco, seed: seed);
        for (var t = 0.0; t < 25; t += 0.05) {
          final split = s.signal.fireSplitAt(t);
          if (split == null) continue; // antes do primeiro pico a onda é uma só
          final seg = split.segments.firstWhere((x) => x.fromU <= waveReadU && waveReadU <= x.toU);
          expect(seg.real, isTrue, reason: 'nível $eco seed $seed t=$t: o ponto de leitura caiu numa isca');
          expect(drawnFrequency(seg, waveReadU), closeTo(s.signal.frequencyAt(t), 1e-6));
          // E com a mesma fase do dial: o dial nessa frequência cobre a onda real.
          final dial = waveTheta(s.signal.frequencyAt(t), waveReadU, waveScroll(t));
          expect((seg.thetaAt(waveReadU) - dial).abs(), lessThan(1e-9));
          checked++;
        }
      }
    }
    expect(checked, greaterThan(10000));
  });

  test('com o dial em frequencyAt(t) o progresso sobe, e a sintonia fecha em cerca de 5 s', () {
    for (final (pl, eco) in levels) {
      for (var seed = 0; seed < 20; seed++) {
        final s = makeSession(type: EcoType.fire, playerLevel: pl, ecoLevel: eco, seed: seed);
        var last = 0.0;
        while (s.running) {
          s.step(1 / 60, dial: s.signal.frequencyAt(s.t + 1 / 60));
          expect(s.progress, greaterThanOrEqualTo(last), reason: 'nível $eco seed $seed t=${s.t}');
          last = s.progress;
        }
        expect(s.progress, 1, reason: 'nível $eco seed $seed');
        expect(s.t, lessThan(7));
      }
    }
  });
}
