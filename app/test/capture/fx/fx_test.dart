import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/fx/dial_fx.dart';
import 'package:kenoma/capture/fx/fire_fx.dart';
import 'package:kenoma/capture/fx/fx_params.dart';
import 'package:kenoma/capture/fx/plant_fx.dart';
import 'package:kenoma/capture/fx/water_fx.dart';
import 'package:kenoma/capture/fx/wave_geometry.dart';
import 'package:kenoma/capture/signal.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/pcg32.dart';

import '../../support/reference_player.dart';

TargetSignal signal(EcoType type, double intensity, {int seed = 5}) => TargetSignal.generate(
      type: type,
      intensity: intensity,
      rng: Pcg32(fnv1a64([seed]), saltKenoma),
      balance: loadTuningBalance(),
    );

void main() {
  group('geometria da onda', () {
    test('as cristas da forma serrilhada têm valor 1 e ficam dentro do intervalo pedido', () {
      for (final f in [0.1, 0.5, 0.9]) {
        for (final scroll in [0.0, 1.3, 7.7]) {
          final crests = crestUs(f, scroll);
          expect(crests, isNotEmpty);
          for (final u in crests) {
            expect(u, inInclusiveRange(0.1, 0.9));
            expect(triShape(waveTheta(f, u, scroll)), closeTo(1, 1e-9));
          }
        }
      }
    });

    test('hash01 é estável e fica em [0, 1)', () {
      expect(hash01(3, 7), hash01(3, 7));
      for (var i = 0; i < 500; i++) {
        expect(hash01(i, 9), inInclusiveRange(0.0, 0.99999));
      }
    });
  });

  group('Fogo', () {
    final s = signal(EcoType.fire, 0.8);
    final fx = FireFx(s);
    final kick = s.kickTimes.first;
    final burn = s.burnUs.first;
    final lead = s.fireWarningLeadS;

    test('sem resistência não há efeito', () {
      final calm = FireFx(signal(EcoType.fire, 0));
      for (var t = 0.0; t < 20; t += 0.1) {
        expect(calm.at(t).isEmpty, isTrue);
      }
    });

    test('antes do primeiro aviso não há efeito nem onda partida', () {
      expect(fx.at(kick - lead - 0.05).isEmpty, isTrue);
      expect(fx.at(kick - lead - 0.05).split, isNull);
    });

    test('a brasa acende no instante do aviso, no ponto de queima que o sinal dá, e sobe até o pico', () {
      final warn = s.cues.firstWhere((c) => c.kind == CueKind.fireWarning).at;
      expect(warn, closeTo(kick - lead, 1e-9));
      final start = fx.at(warn + 1e-6).embers.single;
      final late = fx.at(kick - 1e-6).embers.single;
      expect(start.u, burn);
      expect(late.u, burn);
      expect(start.glow, lessThan(0.05));
      expect(late.glow, greaterThan(0.95));
    });

    test('no pico a chama queima o ponto da brasa, a brasa some e a fronteira é a queima', () {
      final st = fx.at(kick + fireBurnS / 2);
      expect(st.embers, isEmpty);
      expect(st.flames.single.u, burn);
      expect(st.split!.burnU, burn);
    });

    test('as cinzas sobem depois da chama e acabam; a fronteira fica até o próximo pico', () {
      final st = fx.at(kick + fireBurnS + fireAshS / 2);
      expect(st.flames, isEmpty);
      expect(st.ashes.single.particles, hasLength(fireAshCount));
      final slow = signal(EcoType.fire, 0.3); // picos espaçados: um efeito não pega o seguinte
      final slowFx = FireFx(slow);
      final k = slow.kickTimes;
      final after = k[0] + fireBurnS + fireAshS + 0.01;
      expect(k[1] - lead, greaterThan(after));
      final end = slowFx.at(after);
      expect(end.ashes, isEmpty);
      expect(end.flames, isEmpty);
      expect(end.embers, isEmpty);
      expect(end.split!.burnU, slow.burnUs[0], reason: 'a fronteira continua marcando onde a real começa');
      expect(slowFx.at(k[1] + 0.01).split!.burnU, slow.burnUs[1], reason: 'um pico novo muda a fronteira');
    });

    test('a intensidade controla o tamanho da chama', () {
      double peak(double intensity) {
        final sig = signal(EcoType.fire, intensity);
        final f = FireFx(sig);
        final k = sig.kickTimes.first;
        return [for (var a = 0.0; a < fireBurnS; a += 0.01) f.at(k + a).flames.fold<double>(0, (m, e) => math.max(m, e.height))].reduce(math.max);
      }

      expect(peak(0.2), lessThan(peak(0.6)));
      expect(peak(0.6), lessThan(peak(1.0)));
    });

    test('é determinístico', () {
      expect(FireFx(signal(EcoType.fire, 0.8)).at(kick + 0.1).flames.single.height, fx.at(kick + 0.1).flames.single.height);
    });
  });

  group('Água', () {
    final s = signal(EcoType.water, 0.8);
    final fx = WaterFx(s);
    final swell = s.cues.firstWhere((c) => c.kind == CueKind.waterSwell).at;

    test('sem resistência não há espuma', () {
      final calm = WaterFx(signal(EcoType.water, 0));
      for (var t = 0.0; t < 20; t += 0.1) {
        expect(calm.at(t, waveScroll(t)), isEmpty);
      }
    });

    test('a espuma aparece no aviso de virada, assenta em 0,5 s e some', () {
      expect(fx.at(swell - 0.01, 0), isEmpty);
      final first = fx.at(swell + 1e-6, waveScroll(swell)).single;
      final mid = fx.at(swell + waterFoamS / 2, waveScroll(swell)).single;
      expect(first.amplitude, greaterThan(mid.amplitude));
      final swells = [for (final c in s.cues) if (c.kind == CueKind.waterSwell) c.at];
      final after = swell + waterFoamS + 1e-6;
      expect(fx.at(after, 0), hasLength(swells.where((w) => after - w >= 0 && after - w < waterFoamS).length));
    });

    test('fica na crista da onda', () {
      final scroll = waveScroll(swell);
      final foam = fx.at(swell + 0.1, scroll).single;
      final crests = crestUs(s.frequencyAt(swell + 0.1), scroll);
      expect(crests.any((u) => (u - foam.u).abs() < 1e-9), isTrue);
    });

    test('a amplitude da espuma segue a maré: maré do instante vezes o que falta assentar', () {
      final swells = [for (final c in s.cues) if (c.kind == CueKind.waterSwell) c.at];
      var checked = 0;
      for (final at in swells) {
        final t = at + 0.1;
        final active = [for (final w in swells) if (t - w >= 0 && t - w < waterFoamS) w];
        final foams = fx.at(t, 0);
        expect(foams, hasLength(active.length));
        for (var k = 0; k < foams.length; k++) {
          expect(foams[k].amplitude, closeTo(s.tideAt(t) * (1 - (t - active[k]) / waterFoamS), 1e-12));
          checked++;
        }
      }
      expect(checked, greaterThan(5));
      expect(s.tideAt(swells.first), isNot(closeTo(s.tideAt(swells[3]), 1e-6)), reason: 'a maré muda entre avisos');
    });
  });

  group('Planta', () {
    final s = signal(EcoType.plant, 0.8);
    final fx = PlantFx(s);
    final buds = [for (final c in s.cues) if (c.kind == CueKind.plantPulse) c.at];
    final b = loadTuningBalance();

    PlantFxState at(double t, {double base = 0.1}) =>
        fx.at(t, target: 0.5, tolerance: base * s.toleranceFactorAt(t));

    test('uma folha nasce a cada broto, crescendo até o tamanho cheio', () {
      expect(at(buds.first - 0.01).leaves, isEmpty);
      expect(at(buds.first + 0.01).leaves, hasLength(1));
      expect(at(buds.first + 0.01).leaves.single.size, lessThan(0.2));
      expect(at(buds.first + plantLeafGrowS + 0.01).leaves.single.size, 1);
      for (var i = 0; i < 6; i++) {
        expect(at(buds[i] + 0.001).leaves, hasLength(i + 1));
      }
      expect(at(buds[3] + 0.001).leaves.map((l) => l.u).toSet(), hasLength(4), reason: 'cada folha no seu ponto');
    });

    test('no máximo plantMaxLeaves folhas', () {
      expect(at(buds.last + 1).leaves.length, lessThanOrEqualTo(plantMaxLeaves));
    });

    test('as raízes crescem na mesma proporção em que a janela fecha', () {
      expect(at(0).roots, isEmpty);
      expect(at(0).closed, 0);
      for (final t in [0.5, 1.0, 2.0, 3.0, 10.0]) {
        final st = at(t);
        final expected = ((1 - s.toleranceFactorAt(t)) / (1 - b.signal.plant.toleranceFloor)).clamp(0.0, 1.0);
        expect(st.closed, closeTo(expected, 1e-12));
        // A raiz ocupa exatamente o que a janela já perdeu: da borda original à borda de agora.
        final lo = st.roots.first;
        final tolNow = 0.1 * s.toleranceFactorAt(t);
        expect(lo.fromF, closeTo((0.5 - 0.1).clamp(0.0, 1.0), 1e-12));
        expect(lo.toF, closeTo(0.5 - tolNow, 1e-12));
        expect(st.roots.last.toF, closeTo(0.5 + tolNow, 1e-12));
      }
      expect(at(3.0).closed, greaterThan(at(1.0).closed));
      expect(at(1.0).closed, greaterThan(at(0.3).closed));
    });

    test('a janela fechada no piso deixa as raízes completas', () {
      expect(at(20).closed, 1);
      expect(at(20).roots.first.branches.length, plantMaxBranches);
    });

    test('sem resistência não há folhas nem raízes', () {
      final calm = PlantFx(signal(EcoType.plant, 0));
      final st = calm.at(5, target: 0.5, tolerance: 0.1);
      expect(st.leaves, isEmpty);
      expect(st.roots, isEmpty);
    });
  });

  group('dial', () {
    test('começa violeta e fina, sem partículas', () {
      final d = DialFx();
      d.update(0.016, aligned: false, dialAngle: 1);
      expect(d.blend, 0);
      expect(d.thickness, 1);
      expect(d.glow, 0);
      expect(d.particles, isEmpty);
    });

    test('alinhado, a transição leva 150 ms e o dial engrossa, brilha e solta partículas', () {
      final d = DialFx();
      var t = 0.0;
      while (t < 0.075) {
        d.update(0.005, aligned: true, dialAngle: 1);
        t += 0.005;
      }
      expect(d.blend, closeTo(0.5, 0.05));
      while (t < dialBlendS - 1e-9) {
        d.update(0.005, aligned: true, dialAngle: 1);
        t += 0.005;
      }
      expect(d.blend, closeTo(1, 1e-9));
      expect(d.thickness, closeTo(dialAlignedThickness, 1e-9));
      expect(d.glow, closeTo(1, 1e-9));
      expect(d.particles, isNotEmpty);
    });

    test('perdeu o alinhamento: volta ao violeta em 150 ms e as partículas morrem', () {
      final d = DialFx();
      for (var i = 0; i < 100; i++) {
        d.update(0.01, aligned: true, dialAngle: 1);
      }
      expect(d.particles, isNotEmpty);
      for (var i = 0; i < 15; i++) {
        d.update(0.01, aligned: false, dialAngle: 1);
      }
      expect(d.blend, closeTo(0, 1e-9));
      for (var i = 0; i < 60; i++) {
        d.update(0.01, aligned: false, dialAngle: 1);
      }
      expect(d.particles, isEmpty);
    });

    test('as partículas ficam dentro do limite e a taxa bate com dialParticlesPerS', () {
      final d = DialFx();
      for (var i = 0; i < 600; i++) {
        d.update(1 / 60, aligned: true, dialAngle: 1);
        expect(d.particles.length, lessThanOrEqualTo(dialParticleCap));
      }
      final e = DialFx();
      for (var i = 0; i < 12; i++) {
        e.update(1 / 60, aligned: true, dialAngle: 1); // 0,2 s
      }
      expect(e.particles.length, closeTo(dialParticlesPerS * 0.2, 1.5));
    });
  });
}
