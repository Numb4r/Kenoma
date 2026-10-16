import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/school_tests.dart';

import '../support/fixtures.dart';

void main() {
  final b = SchoolTestsBalance(loadJson('assets/data/balance.json')['school_tests'] as Map<String, dynamic>);

  group('Tecnomante: fração do tempo com o sinal na faixa', () {
    double run(TechnoTest t, double Function(TechnoTest) dial, {void Function(TechnoTest)? each}) {
      while (!t.done) {
        each?.call(t);
        t.step(0.05, dial(t));
      }
      return t.score.toDouble();
    }

    test('seguir o sinal dá nota alta (com o atraso de um quadro); ficar parado no meio dá pouco', () {
      expect(run(TechnoTest(b.techno), (t) => t.target), greaterThanOrEqualTo(75));
      expect(run(TechnoTest(b.techno), (_) => 0.5), lessThan(55));
    });

    test('é determinístico: o mesmo jogo dá a mesma nota', () {
      double go() => run(TechnoTest(b.techno), (t) => 0.5 + 0.1 * math.sin(t.t));
      expect(go(), go());
    });

    test('estabilizar zera o ruído (rampa) e tem cargas e espera', () {
      final t = TechnoTest(b.techno);
      expect(t.charges, b.techno.stabilizeCharges);
      expect(t.stabilize(), isTrue);
      expect(t.stabilize(), isFalse, reason: 'em espera');
      expect(t.charges, b.techno.stabilizeCharges - 1);
      for (var i = 0; i < 20; i++) {
        t.step(0.05, 0.5); // 1 s: a rampa de 0,25 s já acabou
      }
      expect(t.noise, 0);
      final wander = 0.5 + b.techno.wanderAmp * math.sin(2 * math.pi * t.t / b.techno.wanderPeriodS);
      expect(t.target, closeTo(wander, 1e-9));
      for (var i = 0; i < 110; i++) {
        t.step(0.05, 0.5); // passam os 2 s e a espera de 4 s
      }
      expect(t.canStabilize, isTrue);
    });

    test('estabilizar na hora certa ajuda: quem usa as 3 cargas vai melhor com o mesmo dedo lento', () {
      // Um dedo que só segue a parte lenta do sinal (sem o ruído): o ruído tira o jogador da faixa, a estabilização o devolve.
      double slow(TechnoTest t) => 0.5 + b.techno.wanderAmp * math.sin(2 * math.pi * t.t / b.techno.wanderPeriodS);
      final without = run(TechnoTest(b.techno), slow);
      final with_ = run(TechnoTest(b.techno), slow, each: (t) {
        if (t.canStabilize) t.stabilize();
      });
      expect(with_, greaterThan(without));
    });
  });

  group('Xamã Urbano: devagar e rápido', () {
    ShamanTest play(double Function(double t) speedMps) {
      final t = ShamanTest(b.shaman);
      while (!t.done) {
        t.step(0.1, speedMps(t.t) / b.shaman.maxSpeedMps);
      }
      return t;
    }

    test('passo calmo chega, o Eco para sem se assustar e a nota é 100', () {
      final t = play((_) => b.shaman.calmSpeedMps * 0.99);
      expect(t.stopped, isTrue);
      expect(t.spooks, 0);
      expect(t.score, 100);
    });

    test('correr assusta o Eco o tempo todo: não chega e a nota fica no teto de quem não terminou', () {
      final t = play((_) => b.shaman.maxSpeedMps);
      expect(t.stopped, isFalse);
      expect(t.spooks, greaterThan(10));
      expect(t.score, lessThanOrEqualTo(b.shaman.timeoutCap.round()));
    });

    test('cada susto custa pontos; demorar além do par também', () {
      // Dois sustos no começo e depois calmo.
      final spooked = play((t) => t < 2 ? b.shaman.maxSpeedMps : b.shaman.calmSpeedMps * 0.99);
      expect(spooked.stopped, isTrue);
      expect(spooked.spooks, greaterThanOrEqualTo(1));
      expect(spooked.score, lessThan(100));
      expect(spooked.score, greaterThan(0));
      final slower = play((_) => b.shaman.calmSpeedMps * 0.5);
      expect(slower.stopped, isTrue);
      expect(slower.score, lessThan(100), reason: 'passou do tempo de par');
    });

    test('parado, o tempo acaba com nota 0', () {
      final t = play((_) => 0);
      expect(t.stopped, isFalse);
      expect(t.score, 0);
    });
  });

  group('Selador: o traço em volta do Eco', () {
    List<(double, double)> circle({double r = 1, double turns = 1, double start = 0, int n = 80, double wobble = 0, double cx = 0, double cy = 0, double endRadiusScale = 1}) {
      final rnd = math.Random(7); // só o ruído do teste; a pontuação em si não sorteia nada
      return [
        for (var i = 0; i <= n; i++)
          () {
            final a = start + 2 * math.pi * turns * i / n;
            final rr = r * (1 + (i / n) * (endRadiusScale - 1)) * (1 + wobble * (rnd.nextDouble() * 2 - 1));
            return (cx + rr * math.cos(a), cy + rr * math.sin(a));
          }(),
      ];
    }

    test('um círculo fechado em volta do Eco dá nota alta', () {
      expect(sealerScore(circle(), b.sealer), greaterThanOrEqualTo(95));
      expect(sealerScore(circle(start: 2, turns: -1.02), b.sealer), greaterThanOrEqualTo(90), reason: 'sentido anti-horário e um pouco além de uma volta');
    });

    test('mão tremida ainda passa', () {
      expect(sealerScore(circle(wobble: 0.08), b.sealer), greaterThanOrEqualTo(70));
    });

    test('traços que não são o sigilo ficam abaixo', () {
      final good = sealerScore(circle(), b.sealer);
      expect(sealerScore([for (var i = 0; i < 40; i++) (-1.0 + i * 0.05, 1.0)], b.sealer), lessThan(10), reason: 'reta');
      expect(sealerScore(circle(turns: 0.5), b.sealer), lessThan(good ~/ 2), reason: 'meia volta');
      expect(sealerScore(circle(cx: 1.6), b.sealer), lessThan(good ~/ 2), reason: 'círculo ao lado, sem pegar o Eco');
      expect(sealerScore(circle(r: 0.2), b.sealer), lessThan(10), reason: 'pequeno demais, colado no Eco');
      expect(sealerScore(circle(r: 3), b.sealer), lessThan(10), reason: 'grande demais');
      expect(sealerScore(circle(endRadiusScale: 0.3), b.sealer), lessThan(good ~/ 2), reason: 'espiral que não fecha');
      expect(sealerScore(circle().take(5).toList(), b.sealer), 0, reason: 'poucos pontos');
    });
  });
}
