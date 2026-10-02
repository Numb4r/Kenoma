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

List<double> series(TargetSignal s, {double to = 20}) => [for (var t = 0.0; t < to; t += 1 / 60) s.frequencyAt(t)];

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
    final speed = loadTuningBalance().signal.fire.boundaryUPerS;

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

    test('a brasa acende no instante do aviso no ponto da onda que chegará à queima, rola com ela e sobe até o pico', () {
      final warn = s.cues.firstWhere((c) => c.kind == CueKind.fireWarning).at;
      expect(warn, closeTo(kick - lead, 1e-9));
      final start = fx.at(warn + 1e-6).embers.single;
      final late = fx.at(kick - 1e-6).embers.single;
      expect(start.u, closeTo(burn + speed * lead, 1e-4), reason: 'mais à direita: o ponto ainda não rolou até a queima');
      expect(late.u, closeTo(burn, 1e-4), reason: 'no pico a brasa está na queima');
      expect(start.u, greaterThan(late.u), reason: 'rola para a esquerda');
      expect(start.glow, lessThan(0.05));
      expect(late.glow, greaterThan(0.95));
    });

    test('no pico a chama queima o ponto da brasa, a brasa some e a fronteira é a queima', () {
      final st = fx.at(kick + fireBurnS / 2);
      expect(st.embers, isEmpty);
      expect(st.flames.single.u, closeTo(burn - speed * fireBurnS / 2, 1e-9), reason: 'a chama rola com a fronteira');
      expect(st.split!.boundaryU, closeTo(burn - speed * fireBurnS / 2, 1e-9));
    });

    test('as cinzas sobem depois da chama e acabam; a fronteira fica até sair da tela', () {
      final st = fx.at(kick + fireBurnS + fireAshS / 2);
      expect(st.flames, isEmpty);
      expect(st.ashes.single.particles, hasLength(fireAshCount));
      final slow = signal(EcoType.fire, 0.3); // picos espaçados: um efeito não pega o seguinte
      final slowFx = FireFx(slow);
      final k = slow.kickTimes;
      final after = k[0] + fireBurnS + fireAshS + 0.01;
      expect(k[1] - slow.fireWarningLeadS, greaterThan(after));
      final end = slowFx.at(after);
      expect(end.ashes, isEmpty);
      expect(end.flames, isEmpty);
      expect(end.embers, isEmpty);
      expect(end.split!.boundaryU, closeTo(slow.burnUs[0] - speed * (after - k[0]), 1e-9));
      expect(slowFx.at(k[1] + 0.01).split!.index, 1, reason: 'um pico novo muda a fronteira');
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

    test('a espuma aparece no aviso de virada, assenta em foamS (0,5 s em intensidade média) e some', () {
      expect(fx.at(swell - 0.01, 0), isEmpty);
      final first = fx.at(swell + 1e-6, waveScroll(swell)).single;
      final mid = fx.at(swell + fx.foamS / 2, waveScroll(swell)).single;
      expect(first.amplitude, greaterThan(mid.amplitude));
      final swells = [for (final c in s.cues) if (c.kind == CueKind.waterSwell) c.at];
      final after = swell + fx.foamS + 1e-6;
      expect(fx.at(after, 0), hasLength(swells.where((w) => after - w >= 0 && after - w < fx.foamS).length));
    });

    test('a ressaca escala com a intensidade: dura mais e sobe mais, só no visual', () {
      double peakHeight(double intensity) {
        final sig = signal(EcoType.water, intensity);
        final f = WaterFx(sig);
        final at = sig.cues.firstWhere((c) => c.kind == CueKind.waterSwell).at;
        return f.at(at + 1e-6, 0).single.particles.map((p) => p.y).reduce(math.max) / sig.tideAt(at + 1e-6);
      }

      final weak = WaterFx(signal(EcoType.water, 0.2));
      final mid = WaterFx(signal(EcoType.water, 0.5));
      final strong = WaterFx(signal(EcoType.water, 1.0));
      expect(weak.foamS, lessThan(mid.foamS));
      expect(mid.foamS, lessThan(strong.foamS));
      expect(mid.foamS, closeTo(0.5, 1e-9), reason: 'em intensidade média a espuma assenta em 0,5 s');
      expect((weak.foamS, strong.foamS), (lerpPair(waterFoamDuration, 0.2), waterFoamDuration.$2));
      expect(weak.height, lessThan(strong.height));
      expect(peakHeight(0.2), lessThan(peakHeight(1.0)), reason: 'as partículas sobem mais');
      // Dura mais: aos 0,4 s a espuma fraca já assentou e a forte ainda está de pé.
      final wk = signal(EcoType.water, 0.2);
      final st = signal(EcoType.water, 1.0);
      double swell(TargetSignal x) => x.cues.firstWhere((c) => c.kind == CueKind.waterSwell).at;
      expect(WaterFx(wk).at(swell(wk) + 0.4, 0).where((f) => f.amplitude > 0), isEmpty);
      expect(WaterFx(st).at(swell(st) + 0.4, 0), isNotEmpty);
    });

    test('é só visual: o sinal e os avisos da Água não dependem da espuma', () {
      final a = signal(EcoType.water, 0.8, seed: 3);
      final b = signal(EcoType.water, 0.8, seed: 3);
      WaterFx(a).at(5, 0);
      expect(series(a, to: 20), series(b, to: 20));
      expect([for (final c in a.cues) c.at], [for (final c in b.cues) c.at]);
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
        final active = [for (final w in swells) if (t - w >= 0 && t - w < fx.foamS) w];
        final foams = fx.at(t, 0);
        expect(foams, hasLength(active.length));
        for (var k = 0; k < foams.length; k++) {
          expect(foams[k].amplitude, closeTo(s.tideAt(t) * (1 - (t - active[k]) / fx.foamS), 1e-12));
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

    test('uma folha nasce a cada broto, crescendo até o tamanho cheio', () {
      expect(fx.at(buds.first - 0.01).leaves, isEmpty);
      expect(fx.at(buds.first + 0.01).leaves, hasLength(1));
      expect(fx.at(buds.first + 0.01).leaves.single.size, lessThan(0.2));
      expect(fx.at(buds.first + plantLeafGrowS + 0.01).leaves.single.size, 1);
      for (var i = 0; i < 6; i++) {
        expect(fx.at(buds[i] + 0.001).leaves, hasLength(i + 1));
      }
      expect(fx.at(buds[3] + 0.001).leaves.map((l) => l.u).toSet(), hasLength(4), reason: 'cada folha no seu ponto');
    });

    test('no máximo plantMaxLeaves folhas', () {
      expect(fx.at(buds.last + 1).leaves.length, lessThanOrEqualTo(plantMaxLeaves));
    });

    test('as raízes desenhadas são as do sinal: mesma faixa, e crescem logo depois de fincadas', () {
      expect(fx.at(buds.first - 0.01).roots, isEmpty);
      for (var n = 1; n <= 8; n++) {
        final t = buds[n - 1] + 0.001;
        final shown = fx.at(t).roots;
        final live = s.rootsAt(t);
        expect(shown, hasLength(live.length));
        for (var i = 0; i < live.length; i++) {
          expect((shown[i].lo, shown[i].hi), (live[i].lo, live[i].hi));
        }
        expect(shown.last.growth, lessThan(0.1), reason: 'a recém-fincada ainda cresce');
      }
      final t = buds[3] + plantRootGrowS + 0.01;
      expect(fx.at(t).roots.last.growth, 1);
    });

    test('as raízes ficam paradas: a mesma raiz tem a mesma faixa e os mesmos ramos ao longo do tempo', () {
      final a = fx.at(buds[4] + 0.5).roots.last;
      final b = fx.at(buds[4] + 1.0).roots.firstWhere((r) => r.lo == a.lo);
      expect((a.lo, a.hi), (b.lo, b.hi));
      expect([for (final x in a.branches) (x.along, x.length, x.side)], [for (final x in b.branches) (x.along, x.length, x.side)]);
    });

    test('sem resistência não há folhas nem raízes', () {
      final calm = PlantFx(signal(EcoType.plant, 0));
      final st = calm.at(5);
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
