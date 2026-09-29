import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/signal.dart';
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

  group('Água: deriva lenta e contínua', () {
    test('sem saltos, e a oscilação cresce com a intensidade', () {
      final weak = series(signal(EcoType.water, 0.3));
      final strong = series(signal(EcoType.water, 0.72));
      expect(maxJump(strong), lessThan(0.01), reason: 'contínua: nada de picos');
      double spread(List<double> xs) => xs.reduce(math.max) - xs.reduce(math.min);
      expect(spread(strong), greaterThan(spread(weak)));
      expect(spread(strong), greaterThan(0.25));
    });

    test('a deriva é periódica, sem picos, e a vibração é uma ondulação a cada cue_every_s', () {
      final s = signal(EcoType.water, 0.72);
      expect(s.kickTimes, isEmpty);
      expect(s.trembleAt(3), 0);
      expect(s.cues.every((c) => c.kind == CueKind.waterSwell), isTrue);
      expect(s.cues.first.at, closeTo(b.signal.water.cueEveryS, 1e-9));
      expect(s.cues[1].at - s.cues[0].at, closeTo(b.signal.water.cueEveryS, 1e-9));
    });

    test('a tolerância não muda', () {
      expect(signal(EcoType.water, 1).toleranceFactorAt(10), 1);
    });
  });

  group('Planta: a tolerância encolhe', () {
    test('o sinal fica firme, igual ao de quem não tem resistência', () {
      expect(series(signal(EcoType.plant, 0.72)), series(signal(EcoType.plant, 0)));
    });

    test('encolhe aos poucos até o mínimo e para', () {
      final s = signal(EcoType.plant, 0.72);
      final over = b.signal.plant.shrinkOverS;
      final floor = 1 - b.signal.plant.toleranceShrink * 0.72;
      expect(s.toleranceFactorAt(0), 1);
      var prev = 1.0;
      for (var t = 0.1; t <= over; t += 0.1) {
        expect(s.toleranceFactorAt(t), lessThanOrEqualTo(prev));
        prev = s.toleranceFactorAt(t);
      }
      expect(s.toleranceFactorAt(over), closeTo(floor, 1e-12));
      expect(s.toleranceFactorAt(over * 5), closeTo(floor, 1e-12));
    });

    test('mais intensidade, mais encolhimento', () {
      expect(signal(EcoType.plant, 1).toleranceFactorAt(20), lessThan(signal(EcoType.plant, 0.3).toleranceFactorAt(20)));
    });

    test('pulsos cada vez mais curtos, até o mínimo', () {
      final s = signal(EcoType.plant, 0.72);
      final durations = [for (final c in s.cues) c.pattern.segments.single.durationMs];
      expect(s.cues.every((c) => c.kind == CueKind.plantPulse), isTrue);
      expect(durations.first, greaterThan(durations[2]));
      for (var i = 1; i < durations.length; i++) {
        expect(durations[i], lessThanOrEqualTo(durations[i - 1]));
      }
      expect(durations.last, b.signal.plant.pulseMs.$2.round());
    });
  });

  test('cuesIn devolve só as vibrações do intervalo (from, to]', () {
    final s = signal(EcoType.water, 0.72);
    final every = b.signal.water.cueEveryS;
    expect(s.cuesIn(0, every - 0.001), isEmpty);
    expect(s.cuesIn(0, every), hasLength(1));
    expect(s.cuesIn(every, every), isEmpty, reason: 'o início do intervalo é aberto');
    expect(s.cuesIn(0, every * 3), hasLength(3));
  });
}
