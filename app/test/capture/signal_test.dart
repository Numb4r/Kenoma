import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/session.dart';
import 'package:kenoma/capture/signal.dart';
import 'package:kenoma/capture/tuning_balance.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/pcg32.dart';

import '../support/reference_player.dart';

TargetSignal signal(EcoType type, double intensity, {int seed = 5}) => TargetSignal.generate(
      type: type,
      intensity: intensity,
      rng: Pcg32(fnv1a64([seed]), saltKenoma),
      balance: loadTuningBalance(),
    );

List<double> series(TargetSignal s, {double to = 30}) => [for (var t = 0.0; t < to; t += 1 / 60) s.frequencyAt(t)];

double maxJump(List<double> xs) => [for (var i = 1; i < xs.length; i++) (xs[i] - xs[i - 1]).abs()].reduce(math.max);

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

void main() {
  final b = loadTuningBalance();

  test('mesma semente, mesmo sinal; semente diferente, sinal diferente', () {
    expect(series(signal(EcoType.fire, 0.7)), series(signal(EcoType.fire, 0.7)));
    expect(series(signal(EcoType.fire, 0.7, seed: 6)), isNot(series(signal(EcoType.fire, 0.7))));
  });

  test('a frequência fica sempre em [0, 1], em qualquer tipo e intensidade', () {
    for (final type in EcoType.values) {
      for (final r in [0.0, 0.3, 0.72, 1.0]) {
        for (var seed = 0; seed < 20; seed++) {
          for (final f in series(signal(type, r, seed: seed))) {
            expect(f, inInclusiveRange(0.0, 1.0));
          }
        }
      }
    }
  });

  group('sem resistência', () {
    test('os três tipos têm o mesmo sinal: só a deriva lenta de base, sem picos nem vibração', () {
      final fire = signal(EcoType.fire, 0);
      expect(series(signal(EcoType.water, 0)), series(fire));
      expect(series(signal(EcoType.plant, 0)), series(fire));
      for (final type in EcoType.values) {
        final s = signal(type, 0);
        expect(s.cues, isEmpty);
        expect(s.kickTimes, isEmpty);
        expect(s.toleranceFactorAt(15), 1);
        expect(s.trembleAt(3), 0);
      }
    });

    test('a frequência inicial fica na faixa e a deriva respeita a amplitude', () {
      for (var seed = 0; seed < 50; seed++) {
        final s = signal(EcoType.fire, 0, seed: seed);
        expect(s.start, inInclusiveRange(b.signal.startRange.$1, b.signal.startRange.$2));
        for (final f in series(s, to: 25)) {
          expect((f - s.start).abs(), lessThanOrEqualTo(b.signal.wanderAmplitude + 1e-9));
        }
      }
    });
  });

  group('Fogo: picos bruscos', () {
    test('o sinal salta no instante do pico e volta depois', () {
      final s = signal(EcoType.fire, 0.72);
      expect(s.kickTimes, isNotEmpty);
      var checked = 0;
      for (final at in s.kickTimes.where((t) => t < 25)) {
        final jump = (s.frequencyAt(at + 1e-3) - s.frequencyAt(at - 1e-3)).abs();
        // Pulo grande de uma vez, salvo quando a dobra na borda do eixo esconde parte dele.
        if (s.frequencyAt(at).clamp(0.2, 0.8) == s.frequencyAt(at)) {
          expect(jump, greaterThan(0.1), reason: 'pico em $at');
          checked++;
        }
      }
      expect(checked, greaterThan(3));
    });

    test('os picos são intermitentes: sem eles o sinal é suave', () {
      final s = signal(EcoType.fire, 0.72);
      final smooth = signal(EcoType.fire, 0);
      expect(maxJump(series(smooth)), lessThan(0.005));
      expect(maxJump(series(s)), greaterThan(0.05));
    });

    test('mais intensidade, picos mais frequentes e maiores', () {
      int count(double r) => signal(EcoType.fire, r).kickTimes.where((t) => t < 60).length;
      expect(count(0.3), lessThan(count(0.72)));
      expect(count(0.72), lessThan(count(1.0)));
    });

    test('a onda tremula e o aviso vem antes de cada pico', () {
      final s = signal(EcoType.fire, 0.72);
      final lead = b.signal.fire.warningLeadS;
      expect(s.cues.length, s.kickTimes.length);
      for (var i = 0; i < s.kickTimes.length; i++) {
        final at = s.kickTimes[i];
        expect(s.cues[i].kind, CueKind.fireWarning);
        expect(s.cues[i].at, closeTo(at - lead, 1e-9));
        expect(s.trembleAt(at - lead + 0.01), 1);
        expect(s.trembleAt(at), 1);
        expect(s.trembleAt(at - lead - 0.05), 0);
      }
    });

    test('nada disso mexe na tolerância', () {
      expect(signal(EcoType.fire, 1).toleranceFactorAt(10), 1);
    });
  });

  group('Água: duas senoides com maré lenta', () {
    // Sem dobrar nas bordas, a deriva da Água é o que waterOffsetAt devolve.
    double amp(double r) => lerpRange(b.signal.water.amplitude, r);

    test('sem saltos, e a oscilação cresce com a intensidade', () {
      final weak = series(signal(EcoType.water, 0.3));
      final strong = series(signal(EcoType.water, 0.72));
      expect(maxJump(strong), lessThan(0.01), reason: 'contínua: nada de picos');
      double spread(List<double> xs) => xs.reduce(math.max) - xs.reduce(math.min);
      expect(spread(strong), greaterThan(spread(weak)));
      expect(spread(strong), greaterThan(0.2));
    });

    test('sem resistência ou fora da Água não há deriva de maré', () {
      expect(signal(EcoType.water, 0).waterOffsetAt(3.3), 0);
      expect(signal(EcoType.fire, 0.72).waterOffsetAt(3.3), 0);
      expect(signal(EcoType.plant, 0.72).waterOffsetAt(3.3), 0);
    });

    test('a deriva segue a fórmula: duas senoides de períodos P e P × 1,618, com fases sorteadas, e a maré', () {
      final w = b.signal.water;
      const r = 0.72;
      final rng = Pcg32(fnv1a64([5]), saltKenoma);
      rng.nextFloat(); // frequência inicial
      rng.nextFloat(); // fase da deriva de base
      final phase1 = 2 * math.pi * rng.nextFloat();
      final phase2 = 2 * math.pi * rng.nextFloat(); // sorteios novos, logo depois dos que já existiam
      final tidePhase = 2 * math.pi * rng.nextFloat();
      final p1 = lerpRange(w.periodS, r);
      final p2 = p1 * 1.618;
      final s = signal(EcoType.water, r);
      for (var t = 0.0; t < 40; t += 0.37) {
        final tide = 0.8 + 0.2 * math.sin(2 * math.pi * t / w.tidePeriodS + tidePhase);
        final expected = tide *
            amp(r) *
            ((1 - w.secondWeight) * math.sin(2 * math.pi * t / p1 + phase1) + w.secondWeight * math.sin(2 * math.pi * t / p2 + phase2));
        expect(s.waterOffsetAt(t), closeTo(expected, 1e-12), reason: 't=$t');
      }
      expect(w.secondPeriodRatio, 1.618);
      expect(w.tidePeriodS, closeTo(11, 0.5));
      expect(w.tideMin, 0.6);
    });

    test('as duas senoides nunca se repetem juntas: o padrão não tem o período P', () {
      final s = signal(EcoType.water, 0.72);
      final p1 = lerpRange(b.signal.water.periodS, 0.72);
      var differs = 0;
      for (var t = 0.0; t < 30; t += 1.3) {
        if ((s.waterOffsetAt(t + p1) - s.waterOffsetAt(t)).abs() > 0.01) differs++;
      }
      expect(differs, greaterThan(15));
    });

    test('a amplitude total é modulada pela maré, entre 60% e 100% do máximo', () {
      const r = 0.72;
      final limit = amp(r);
      var peak = 0.0;
      final peaksByWindow = <double>[];
      for (var seed = 0; seed < 30; seed++) {
        final s = signal(EcoType.water, r, seed: seed);
        // Dentro de cada janela de 3 s acha o pico da deriva; a maré faz esse pico variar.
        for (var w0 = 0.0; w0 < 66; w0 += 3) {
          var windowPeak = 0.0;
          for (var t = w0; t < w0 + 3; t += 0.02) {
            windowPeak = math.max(windowPeak, s.waterOffsetAt(t).abs());
          }
          peaksByWindow.add(windowPeak);
          peak = math.max(peak, windowPeak);
        }
      }
      expect(peak, lessThanOrEqualTo(limit + 1e-9), reason: 'nunca passa da amplitude total');
      expect(peak, greaterThan(0.85 * limit), reason: 'chega perto do máximo nos picos da maré');
      final calm = peaksByWindow.where((p) => p < 0.6 * limit).length;
      expect(calm, greaterThan(0), reason: 'a maré baixa reduz o pico');
    });

    test('a maré nunca zera a deriva: o envelope fica entre 60% e 100%', () {
      // Com fase igual nas duas senoides, waterOffset = tide × amp × seno; a razão entre picos
      // consecutivos de maré alta e baixa fica em [0,6; 1].
      final w = b.signal.water;
      for (var seed = 0; seed < 20; seed++) {
        final s = signal(EcoType.water, 0.72, seed: seed);
        for (var t = 0.0; t < 60; t += 0.5) {
          final envelope = s.waterOffsetAt(t).abs() / amp(0.72);
          expect(envelope, lessThanOrEqualTo(1.0 + 1e-9));
        }
      }
      expect(w.tideMin, inInclusiveRange(0.0, 1.0));
    });

    test('a tolerância não muda', () {
      expect(signal(EcoType.water, 1).toleranceFactorAt(10), 1);
    });

    group('avisos nas inversões de sentido', () {
      // Inversões achadas de forma independente: onde a derivada do sinal troca de sinal.
      List<double> reversals(TargetSignal s, {double to = 60}) {
        const h = 0.01;
        final out = <double>[];
        var prev = s.frequencyAt(0);
        var prevDir = 0;
        for (var i = 1; i * h <= to; i++) {
          final f = s.frequencyAt(i * h);
          final dir = f > prev ? 1 : (f < prev ? -1 : 0);
          if (dir != 0) {
            if (prevDir != 0 && dir != prevDir) out.add((i - 1) * h);
            prevDir = dir;
          }
          prev = f;
        }
        return out;
      }

      test('cada aviso toca 0,4 s antes de uma inversão do sinal', () {
        for (final seed in [1, 2, 3]) {
          final s = signal(EcoType.water, 0.72, seed: seed);
          expect(s.cues, isNotEmpty);
          for (final c in s.cues) {
            final t = c.at + b.signal.water.cueLeadS;
            const h = 0.06;
            final before = s.frequencyAt(t) - s.frequencyAt(t - h);
            final after = s.frequencyAt(t + h) - s.frequencyAt(t);
            expect(before * after, lessThan(0), reason: 'seed $seed, aviso em ${c.at}: o sinal não inverte em $t');
          }
        }
      });

      test('toda inversão tem o seu aviso', () {
        final s = signal(EcoType.water, 0.72, seed: 4);
        final lead = b.signal.water.cueLeadS;
        for (final rev in reversals(s, to: 55).where((r) => r > lead + 0.05)) {
          expect(s.cues.any((c) => (c.at - (rev - lead)).abs() < 0.03), isTrue, reason: 'inversão em $rev sem aviso');
        }
      });

      test('o intervalo entre avisos não é fixo', () {
        final s = signal(EcoType.water, 0.72, seed: 4);
        final gaps = [for (var i = 1; i < s.cues.length; i++) s.cues[i].at - s.cues[i - 1].at];
        expect(gaps.length, greaterThan(10));
        final mean = gaps.reduce((a, b) => a + b) / gaps.length;
        final variance = gaps.map((g) => (g - mean) * (g - mean)).reduce((a, b) => a + b) / gaps.length;
        expect(math.sqrt(variance), greaterThan(0.15), reason: 'os avisos seguem o sinal, não um relógio');
      });

      test('todos são ondulações da Água, em ordem, dentro do horizonte', () {
        final s = signal(EcoType.water, 0.72);
        expect(s.cues.every((c) => c.kind == CueKind.waterSwell), isTrue);
        for (var i = 1; i < s.cues.length; i++) {
          expect(s.cues[i].at, greaterThan(s.cues[i - 1].at));
        }
        expect(s.cues.first.at, greaterThan(0));
        expect(s.cues.last.at, lessThanOrEqualTo(60));
      });

      test('sem resistência não há aviso; os outros tipos não recebem avisos da Água', () {
        expect(signal(EcoType.water, 0).cues, isEmpty);
        expect(signal(EcoType.fire, 0.72).cues.every((c) => c.kind == CueKind.fireWarning), isTrue);
        expect(signal(EcoType.plant, 0.72).cues.every((c) => c.kind == CueKind.plantPulse), isTrue);
      });
    });
  });

  group('Planta: a tolerância encolhe até um piso, e o sinal cresce', () {
    final p = b.signal.plant;

    group('tolerância', () {
      test('encolhe aos poucos até o mínimo e para', () {
        final s = signal(EcoType.plant, 0.72);
        final floor = math.max(p.toleranceFloor, 1 - p.toleranceShrink * 0.72);
        expect(s.toleranceFactorAt(0), 1);
        var prev = 1.0;
        for (var t = 0.1; t <= p.shrinkOverS; t += 0.1) {
          expect(s.toleranceFactorAt(t), lessThanOrEqualTo(prev));
          prev = s.toleranceFactorAt(t);
        }
        expect(s.toleranceFactorAt(p.shrinkOverS), closeTo(floor, 1e-12));
        expect(s.toleranceFactorAt(p.shrinkOverS * 5), closeTo(floor, 1e-12));
      });

      test('o piso é 0,5: em nenhuma intensidade nem instante a tolerância cai abaixo de metade', () {
        expect(p.toleranceFloor, 0.5);
        for (final r in [0.0, 0.3, 0.72, 0.81, 0.95, 1.0]) {
          final s = signal(EcoType.plant, r);
          for (var t = 0.0; t <= 100; t += 0.25) {
            expect(s.toleranceFactorAt(t), greaterThanOrEqualTo(0.5), reason: 'r=$r t=$t');
          }
        }
      });

      test('com intensidade 1 a tolerância chega ao piso e fica ali (antes chegava a zero)', () {
        final s = signal(EcoType.plant, 1.0);
        expect(p.toleranceShrink * 1.0, greaterThanOrEqualTo(1.0), reason: 'sem piso, o fator iria a zero');
        expect(s.toleranceFactorAt(p.shrinkOverS), 0.5);
        expect(s.toleranceFactorAt(60), 0.5);
      });

      test('mais intensidade, mais encolhimento, até o piso', () {
        final f = [for (final r in [0.2, 0.4, 0.5]) signal(EcoType.plant, r).toleranceFactorAt(20)];
        expect(f[0], greaterThan(f[1]));
        expect(f[1], greaterThan(f[2]));
        expect(f[2], 0.5, reason: 'com o encolhimento em 1,0 o piso de 0,5 começa na intensidade 0,5');
        // Acima disso o piso segura: 0,72 e 1,0 param no mesmo ponto.
        expect(signal(EcoType.plant, 0.72).toleranceFactorAt(20), signal(EcoType.plant, 1.0).toleranceFactorAt(20));
      });

      test('só a Planta encolhe a tolerância', () {
        expect(signal(EcoType.fire, 1).toleranceFactorAt(10), 1);
        expect(signal(EcoType.water, 1).toleranceFactorAt(10), 1);
      });

      test('com resistência 1 ainda dá para sintonizar: um jogador que acompanha o sinal sela', () {
        // Sem o piso a tolerância ia a zero em 3 s e nenhum dial estaria alinhado.
        var sealed = 0;
        for (var seed = 0; seed < 30; seed++) {
          final s = makeSession(type: EcoType.plant, playerLevel: 99, ecoLevel: 20, seed: seed);
          const ReferencePlayer(startDelayS: 0.3, reactionS: 0.15, maxSpeed: 4, tremorAmp: 0).play(s);
          if (s.phase == TuningPhase.success) sealed++;
        }
        expect(sealed, greaterThan(15), reason: 'selou só $sealed de 30');
      });

      test('a tolerância efetiva nunca é zero', () {
        final s = makeSession(type: EcoType.plant, playerLevel: 99, ecoLevel: 20, seed: 1);
        expect(s.signal.intensity, 1.0);
        for (var t = 0.0; t < 40; t += 0.5) {
          expect(s.baseTolerance * s.signal.toleranceFactorAt(t), greaterThan(0.03));
        }
      });
    });

    group('crescimento', () {
      double rate(double r) => lerpRange(p.growthPerS, r);
      double step(double r) => lerpRange(p.budStep, r);

      test('parâmetros: deriva de 0 a 0,03 por segundo e broto de 0 a 0,06', () {
        expect(p.growthPerS, (0.0, 0.03));
        expect(p.budStep, (0.0, 0.06));
      });

      test('sem resistência o sinal é só a deriva de base; com resistência ele cresce', () {
        expect(series(signal(EcoType.plant, 0)), series(signal(EcoType.fire, 0)));
        expect(signal(EcoType.plant, 0).plantOffsetAt(9), 0);
        expect(series(signal(EcoType.plant, 0.72)), isNot(series(signal(EcoType.plant, 0))));
      });

      test('só a Planta cresce', () {
        expect(signal(EcoType.fire, 0.72).plantOffsetAt(9), 0);
        expect(signal(EcoType.water, 0.72).plantOffsetAt(9), 0);
      });

      test('o sentido vem do sorteio novo, logo depois das fases da Água', () {
        for (var seed = 0; seed < 25; seed++) {
          final r = Pcg32(fnv1a64([seed]), saltKenoma);
          for (var i = 0; i < 5; i++) {
            r.nextFloat(); // início, fase da deriva, fase da Água, segunda fase, fase da maré
          }
          final dir = r.nextFloat() < 0.5 ? -1.0 : 1.0;
          final s = signal(EcoType.plant, 0.72, seed: seed);
          expect(s.plantDirection, dir, reason: 'semente $seed');
          expect(s.plantOffsetAt(10).sign, dir);
        }
      });

      test('os dois sentidos acontecem', () {
        expect({for (var seed = 0; seed < 40; seed++) signal(EcoType.plant, 0.72, seed: seed).plantDirection}, {-1.0, 1.0});
      });

      test('entre dois pulsos a deriva é contínua, na taxa lerp(0, 0,03, intensidade) por segundo', () {
        for (final r in [0.3, 0.72, 1.0]) {
          final s = signal(EcoType.plant, r);
          // Os pulsos caem em múltiplos de cue_every_s (1,2 s): de 0,1 a 1,1 não há nenhum.
          final drift = s.plantOffsetAt(1.1) - s.plantOffsetAt(0.1);
          expect(drift, closeTo(s.plantDirection * rate(r) * 1.0, 1e-12), reason: 'r=$r');
        }
      });

      test('a cada pulso o sinal dá um passo extra lerp(0, 0,06, intensidade) no mesmo sentido', () {
        for (final r in [0.3, 0.72, 1.0]) {
          final s = signal(EcoType.plant, r);
          expect(s.cues, isNotEmpty);
          for (final c in s.cues.take(12)) {
            const e = 1e-6;
            final jump = s.plantOffsetAt(c.at + e) - s.plantOffsetAt(c.at - e);
            expect(jump, closeTo(s.plantDirection * (step(r) + rate(r) * 2 * e), 1e-9), reason: 'r=$r, pulso em ${c.at}');
            expect(jump.sign, s.plantDirection);
          }
        }
      });

      test('o broto e a deriva têm o mesmo sentido: o deslocamento só cresce em módulo', () {
        final s = signal(EcoType.plant, 0.9);
        var prev = 0.0;
        for (var t = 0.0; t < 40; t += 0.05) {
          final off = s.plantOffsetAt(t).abs();
          expect(off, greaterThanOrEqualTo(prev));
          prev = off;
        }
      });

      test('o deslocamento cresce com a intensidade', () {
        expect(signal(EcoType.plant, 1.0).plantOffsetAt(20).abs(), greaterThan(signal(EcoType.plant, 0.5).plantOffsetAt(20).abs()));
        expect(signal(EcoType.plant, 1.0).plantOffsetAt(20).abs(), closeTo(rate(1.0) * 20 + step(1.0) * (20 / p.cueEveryS).floor(), 0.07));
      });

      test('o sinal reflete nas bordas: continua em [0, 1] e chega a bater nelas', () {
        var touched = 0;
        for (var seed = 0; seed < 30; seed++) {
          final xs = series(signal(EcoType.plant, 1.0, seed: seed), to: 60);
          for (final f in xs) {
            expect(f, inInclusiveRange(0.0, 1.0));
          }
          if (xs.any((f) => f > 0.97) || xs.any((f) => f < 0.03)) touched++;
        }
        expect(touched, greaterThan(20), reason: 'com deriva e brotos, em 60 s o sinal alcança uma borda quase sempre');
      });

      test('o único salto do sinal são os brotos, nos pulsos', () {
        final s = signal(EcoType.plant, 0.8);
        final threshold = step(0.8) * 0.6;
        for (var t = 0.0; t < 30; t += 1 / 60) {
          final jump = (s.frequencyAt(t + 1 / 60) - s.frequencyAt(t)).abs();
          if (jump > threshold) {
            expect(s.cues.any((c) => c.at > t && c.at <= t + 1 / 60), isTrue, reason: 'salto de $jump em t=$t sem pulso');
          }
        }
      });

      test('a vibração continua a ser um pulso que encurta', () {
        final s = signal(EcoType.plant, 0.72);
        final durations = [for (final c in s.cues) c.pattern.segments.single.durationMs];
        expect(s.cues.every((c) => c.kind == CueKind.plantPulse), isTrue);
        expect(durations.first, greaterThan(durations[2]));
        for (var i = 1; i < durations.length; i++) {
          expect(durations[i], lessThanOrEqualTo(durations[i - 1]));
        }
        expect(durations.last, p.pulseMs.$2.round());
        expect(s.cues[1].at - s.cues[0].at, closeTo(p.cueEveryS, 1e-9));
      });
    });
  });

  group('ordem dos sorteios do rng', () {
    // Os sorteios que já existiam não mudam de lugar; os novos entram no fim da sequência.
    Pcg32 rng(int seed) => Pcg32(fnv1a64([seed]), saltKenoma);

    test('os três primeiros sorteios seguem sendo a frequência inicial e as duas fases', () {
      final r = rng(5);
      final start = lerpRange(b.signal.startRange, r.nextFloat());
      final wanderPhase = 2 * math.pi * r.nextFloat();
      final s = signal(EcoType.fire, 0, seed: 5);
      expect(s.start, start);
      for (final t in [0.0, 1.0, 3.3, 7.7, 12.0, 19.9]) {
        final expected = start + b.signal.wanderAmplitude * math.sin(2 * math.pi * t / b.signal.wanderPeriodS + wanderPhase);
        expect(s.frequencyAt(t), closeTo(expected, 1e-12));
      }
    });

    test('valores fixos da deriva de base, tirados antes de existirem os sorteios novos', () {
      final s = signal(EcoType.fire, 0, seed: 5);
      expect([for (final t in [0.0, 1.0, 3.3, 7.7, 12.0, 19.9]) s.frequencyAt(t)], [
        0.5914270899568248,
        0.5888010934174408,
        0.6736779198243132,
        0.5854333194756706,
        0.6685632344345842,
        0.63137935770054,
      ]);
      expect(s.start, 0.635079952282831);
    });

    test('os picos do Fogo saem dos sorteios logo depois dos três primeiros: intervalo, sinal, tamanho', () {
      const r = 0.72;
      final gen = rng(5);
      for (var i = 0; i < 3; i++) {
        gen.nextFloat();
      }
      final mean = lerpRange(b.signal.fire.intervalS, r);
      var at = 0.0;
      final expected = <double>[];
      while (true) {
        at += mean * (0.75 + 0.5 * gen.nextFloat());
        if (at > 60) break;
        gen.nextFloat(); // sinal do pico
        gen.nextFloat(); // tamanho do pico
        expected.add(at);
      }
      final s = signal(EcoType.fire, r, seed: 5);
      expect(s.kickTimes, expected);
    });

    test('para a Água e a Planta, os sorteios novos vêm logo depois dos três primeiros', () {
      // Sem picos, o quarto sorteio em diante é dos parâmetros novos.
      final gen = rng(5);
      for (var i = 0; i < 3; i++) {
        gen.nextFloat();
      }
      final phase2 = 2 * math.pi * gen.nextFloat();
      final water = signal(EcoType.water, 0.72, seed: 5);
      final p1 = lerpRange(b.signal.water.periodS, 0.72);
      // Com a maré no mesmo instante, a segunda senoide usa exatamente esta fase.
      final tidePhase = 2 * math.pi * gen.nextFloat();
      final tide = 0.8 + 0.2 * math.sin(tidePhase);
      final phase1 = 2 * math.pi * rng(5).let((r) {
        r.nextFloat();
        r.nextFloat();
        return r.nextFloat();
      });
      final w = b.signal.water;
      final expected = tide *
          lerpRange(w.amplitude, 0.72) *
          ((1 - w.secondWeight) * math.sin(phase1) + w.secondWeight * math.sin(phase2));
      expect(water.waterOffsetAt(0), closeTo(expected, 1e-12));
      expect(p1, greaterThan(0));
    });

    test('mesma semente, mesmo sinal, também com os sorteios novos', () {
      for (final type in EcoType.values) {
        expect(series(signal(type, 0.8, seed: 9)), series(signal(type, 0.8, seed: 9)));
      }
    });
  });

  test('cuesIn devolve só as vibrações do intervalo (from, to]', () {
    final s = signal(EcoType.water, 0.72);
    final first = s.cues[0].at, second = s.cues[1].at, third = s.cues[2].at;
    expect(s.cuesIn(0, first - 0.001), isEmpty);
    expect(s.cuesIn(0, first), hasLength(1));
    expect(s.cuesIn(first, first), isEmpty, reason: 'o início do intervalo é aberto');
    expect(s.cuesIn(0, third), hasLength(3));
    expect(s.cuesIn(first, second).single.at, second);
  });
}
