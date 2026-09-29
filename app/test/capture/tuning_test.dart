import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/resistance.dart';
import 'package:kenoma/capture/seal.dart';
import 'package:kenoma/capture/session.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/pcg32.dart';

import '../support/reference_player.dart';

void main() {
  final b = loadTuningBalance();

  group('tolerância', () {
    test('selo simples 0,08 e reforçado 0,11', () {
      expect(tuningTolerance(seal: sealById('item.seal.simple'), target: EcoType.fire, balance: b), 0.08);
      expect(tuningTolerance(seal: sealById('item.seal.reinforced'), target: EcoType.fire, balance: b), 0.11);
    });

    test('selo de tipo vale como simples e ×1,4 contra o tipo que vence', () {
      final fire = sealById('item.seal.fire'); // Fogo vence Planta
      expect(tuningTolerance(seal: fire, target: EcoType.plant, balance: b), closeTo(0.08 * 1.4, 1e-12));
      expect(tuningTolerance(seal: fire, target: EcoType.fire, balance: b), 0.08);
      expect(tuningTolerance(seal: fire, target: EcoType.water, balance: b), 0.08);
      expect(tuningTolerance(seal: sealById('item.seal.plant'), target: EcoType.water, balance: b), closeTo(0.112, 1e-12));
      expect(tuningTolerance(seal: sealById('item.seal.water'), target: EcoType.fire, balance: b), closeTo(0.112, 1e-12));
    });

    test('Círculo: ×1,1 por criatura forte, até 3', () {
      final s = sealById('item.seal.simple');
      double tol(int n) => tuningTolerance(seal: s, target: EcoType.fire, balance: b, circleStrong: n);
      expect(tol(0), 0.08);
      expect(tol(1), closeTo(0.08 * 1.1, 1e-12));
      expect(tol(3), closeTo(0.08 * 1.1 * 1.1 * 1.1, 1e-12));
      expect(tol(5), tol(3), reason: 'o máximo é 3');
    });

    test('bônus de tipo e do Círculo se multiplicam', () {
      final t = tuningTolerance(seal: sealById('item.seal.fire'), target: EcoType.plant, balance: b, circleStrong: 2);
      expect(t, closeTo(0.08 * 1.4 * 1.1 * 1.1, 1e-12));
    });
  });

  group('intensidade da resistência', () {
    double r(int player, [int? eco]) =>
        resistanceIntensity(playerLevel: player, ecoLevel: eco ?? player, balance: b);

    test('níveis 1 a 3: 0', () {
      for (final l in [1, 2, 3]) {
        expect(r(l), 0);
      }
    });

    test('níveis 4 a 9: 0,3', () {
      for (final l in [4, 6, 9]) {
        expect(r(l), 0.3);
      }
    });

    test('do nível 10 em diante sobe 0,07 por nível (o nível 10 já vale 0,37)', () {
      expect(r(10), closeTo(0.37, 1e-12));
      expect(r(11), closeTo(0.44, 1e-12));
      expect(r(15), closeTo(0.72, 1e-12));
    });

    test('soma 0,02 por nível do Eco acima do Conjurador; abaixo não conta', () {
      expect(r(1, 3), closeTo(0.04, 1e-12));
      expect(r(6, 8), closeTo(0.34, 1e-12));
      expect(r(15, 17), closeTo(0.76, 1e-12));
      expect(r(6, 4), 0.3);
    });

    test('limitada entre 0 e 1', () {
      expect(r(99, 99), 1.0);
      expect(r(1, 1), 0.0);
    });
  });

  group('progresso, tempo e alinhamento', () {
    // Sinal firme (sem resistência) e dial colocado exatamente sobre ele ou longe dele.
    TuningSession session({bool tonic = false}) =>
        makeSession(type: EcoType.fire, playerLevel: 1, ecoLevel: 1, seed: 1, tonic: tonic)..dial = 0;

    test('alinhado sobe 0,2 por segundo', () {
      final s = session();
      final f = s.signal.frequencyAt(0);
      s.step(0.5, dial: f);
      expect(s.aligned, isTrue);
      expect(s.progress, closeTo(0.1, 1e-9));
    });

    test('desalinhado cai 0,1 por segundo, sem passar de 0', () {
      final s = session();
      final far = s.targetFrequency > 0.5 ? 0.0 : 1.0;
      s.progress = 0.3;
      s.step(1.0, dial: far);
      expect(s.aligned, isFalse);
      expect(s.progress, closeTo(0.2, 1e-9));
      s.step(5.0, dial: far);
      expect(s.progress, 0);
    });

    test('a borda da tolerância conta como alinhado', () {
      final s = session();
      final f = s.signal.frequencyAt(1 / 60);
      s.step(1 / 60, dial: f + s.tolerance - 1e-9);
      expect(s.aligned, isTrue);
      s.step(1 / 60, dial: (s.targetFrequency + s.tolerance + 0.01).clamp(0.0, 1.0));
      // fora da borda (a menos que o dial tenha batido no fim do eixo)
      if (s.targetFrequency + s.tolerance + 0.01 <= 1) expect(s.aligned, isFalse);
    });

    test('progresso 1 sela a criatura, em 5 s de alinhamento contínuo', () {
      final s = session();
      var steps = 0;
      while (s.running) {
        s.step(1 / 60, dial: s.targetFrequency);
        steps++;
      }
      expect(s.phase, TuningPhase.success);
      expect(s.progress, 1);
      expect(s.t, closeTo(5.0, 0.05));
      expect(steps, inInclusiveRange(299, 302));
    });

    test('tempo máximo de 20 s falha; com tônico são 25 s', () {
      double far(double f) => f > 0.5 ? 0.0 : 1.0;
      final s = session();
      while (s.running) {
        s.step(0.05, dial: far(s.targetFrequency));
      }
      expect(s.phase, TuningPhase.failed);
      expect(s.t, closeTo(20, 0.06));

      final t = session(tonic: true);
      while (t.running) {
        t.step(0.05, dial: far(t.targetFrequency));
      }
      expect(t.phase, TuningPhase.failed);
      expect(t.t, closeTo(25, 0.06));
      expect(t.timeLimitS, 25);
    });

    test('tempo restante', () {
      final s = session();
      expect(s.timeRemaining, 20);
      s.step(4, dial: 0);
      expect(s.timeRemaining, closeTo(16, 1e-9));
    });

    test('depois do fim a sessão não avança', () {
      final s = session();
      while (s.running) {
        s.step(1 / 60, dial: s.targetFrequency);
      }
      final t = s.t;
      expect(s.step(1, dial: 0), isEmpty);
      expect(s.t, t);
      expect(s.phase, TuningPhase.success);
    });

    test('o dial fica em [0, 1]', () {
      final s = session();
      s.step(0.1, dial: 7);
      expect(s.dial, 1);
      s.step(0.1, dial: -3);
      expect(s.dial, 0);
    });
  });

  group('resultado', () {
    TuningSession finished({required bool success}) {
      final s = makeSession(type: EcoType.fire, playerLevel: 1, ecoLevel: 1, seed: 3);
      while (s.running) {
        s.step(0.05, dial: success ? s.targetFrequency : (s.targetFrequency > 0.5 ? 0 : 1));
      }
      return s;
    }

    test('sucesso rende 1 ou 2 de Ectoplasma, e os dois valores acontecem', () {
      final seen = <int>{};
      for (var seed = 0; seed < 100; seed++) {
        final o = resolveTuning(finished(success: true), Pcg32(fnv1a64([seed]), saltKenoma));
        expect(o.success, isTrue);
        expect(o.fled, isFalse);
        seen.add(o.ectoplasm);
      }
      expect(seen, {1, 2});
    });

    test('falha: a criatura foge com ~50% de chance', () {
      var fled = 0;
      const n = 1000;
      for (var seed = 0; seed < n; seed++) {
        final o = resolveTuning(finished(success: false), Pcg32(fnv1a64([seed]), saltKenoma));
        expect(o.success, isFalse);
        expect(o.ectoplasm, 0);
        if (o.fled) fled++;
      }
      expect(fled / n, closeTo(0.5, 0.05));
    });
  });
}
