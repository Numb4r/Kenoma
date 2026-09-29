import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/overlevel.dart';
import 'package:kenoma/capture/resistance.dart';
import 'package:kenoma/capture/session.dart';
import 'package:kenoma/capture/tuning_setup.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/pcg32.dart';

import '../support/reference_player.dart';

/// Sobrenível: cada eixo (tolerância, progresso, fuga) é testado sozinho. As constantes vêm de
/// balance.json, porque são calibradas com jogadores simulados.
void main() {
  final b = loadTuningBalance();
  const dt = 1 / 60;

  group('gap e sobrenível g', () {
    test('o gap é Eco menos Conjurador, e pode ser negativo', () {
      expect(levelGap(playerLevel: 10, ecoLevel: 17), 7);
      expect(levelGap(playerLevel: 10, ecoLevel: 10), 0);
      expect(levelGap(playerLevel: 10, ecoLevel: 3), -7);
    });

    test('g é 0 até overlevel_free níveis e cresce um por nível depois', () {
      final free = b.overlevelFree;
      for (var gap = -5; gap <= free; gap++) {
        expect(overlevelOf(playerLevel: 10, ecoLevel: 10 + gap, balance: b), 0, reason: 'gap $gap');
      }
      for (var extra = 1; extra <= 15; extra++) {
        expect(overlevelOf(playerLevel: 10, ecoLevel: 10 + free + extra, balance: b), extra, reason: 'gap ${free + extra}');
      }
    });

    test('a preparação da sintonia expõe o gap e o g', () {
      final seal = sealById('item.seal.simple');
      TuningSetup setup(int player, int eco) =>
          TuningSetup(type: EcoType.fire, ecoLevel: eco, playerLevel: player, seal: seal);
      expect(setup(10, 10).gap, 0);
      expect(setup(10, 20).gap, 10);
      expect(setup(10, 20).overlevel(b), 5);
      expect(setup(10, 15).overlevel(b), 0);
      expect(setup(10, 3).gap, -7);
      expect(setup(10, 3).overlevel(b), 0);
    });

    test('a sessão nasce com o g da preparação', () {
      expect(makeSession(type: EcoType.fire, playerLevel: 10, ecoLevel: 25, seed: 1).overlevel, 10);
      expect(makeSession(type: EcoType.fire, playerLevel: 10, ecoLevel: 12, seed: 1).overlevel, 0);
    });

    test('o sobrenível não depende do teto de 1,0 da intensidade', () {
      // Conjurador 30 com Eco 60: a intensidade já está no teto, mas g = 30 − 5 = 25.
      final seal = sealById('item.seal.simple');
      final setup = TuningSetup(type: EcoType.fire, ecoLevel: 60, playerLevel: 30, seal: seal);
      expect(setup.intensity(b), 1.0);
      expect(setup.overlevel(b), 25);
      final s = setup.start(b, Pcg32(fnv1a64([1]), saltKenoma));
      expect(s.overlevel, 25);
      expect(s.tolerance, closeTo(0.08 * overlevelToleranceFactor(25, b), 1e-12));
      expect(s.tolerance, lessThan(0.08), reason: 'o sobrenível vale mesmo com a intensidade no teto');
    });

    test('a intensidade não cresce com o sobrenível: só o gap até overlevel_free conta', () {
      double r(int eco) => resistanceIntensity(playerLevel: 10, ecoLevel: eco, balance: b);
      expect(r(10 + b.overlevelFree), r(10 + b.overlevelFree + 10));
    });
  });

  group('eixo 1: tolerância', () {
    test('multiplicador: 1 sem sobrenível, fator^g depois, com piso', () {
      expect(overlevelToleranceFactor(0, b), 1.0);
      expect(overlevelToleranceFactor(-3, b), 1.0);
      for (var g = 1; g <= 40; g++) {
        final expected = math.max(b.overlevelTolFloor, math.pow(b.overlevelTolFactor, g).toDouble());
        expect(overlevelToleranceFactor(g, b), closeTo(expected, 1e-12), reason: 'g=$g');
      }
    });

    test('só diminui com g e nunca passa do piso', () {
      var prev = 1.0;
      for (var g = 1; g <= 60; g++) {
        final f = overlevelToleranceFactor(g, b);
        expect(f, lessThanOrEqualTo(prev));
        expect(f, greaterThanOrEqualTo(b.overlevelTolFloor));
        prev = f;
      }
      expect(overlevelToleranceFactor(60, b), b.overlevelTolFloor, reason: 'chega ao piso e fica');
    });

    test('a tolerância da sessão é a do selo vezes o multiplicador', () {
      for (final eco in [10, 15, 17, 20, 25, 40]) {
        final s = makeSession(type: EcoType.fire, playerLevel: 10, ecoLevel: eco, seed: 1);
        final g = math.max(0, eco - 10 - b.overlevelFree);
        expect(s.tolerance, closeTo(0.08 * overlevelToleranceFactor(g, b), 1e-12), reason: 'eco $eco');
      }
    });

    test('com sobrenível o mesmo desvio do dial deixa de contar como alinhado', () {
      // No instante 0 o alvo é o mesmo, seja qual for a intensidade.
      final free = makeSession(type: EcoType.fire, playerLevel: 10, ecoLevel: 10, seed: 3);
      final over = makeSession(type: EcoType.fire, playerLevel: 10, ecoLevel: 20, seed: 3);
      expect(over.targetFrequency, free.targetFrequency);
      // Um desvio entre as duas tolerâncias: dentro da cheia, fora da que tem sobrenível.
      final offset = (free.tolerance + over.tolerance) / 2;
      expect(over.tolerance, lessThan(free.tolerance));
      expect(offset, greaterThan(over.tolerance));
      expect(offset, lessThan(free.tolerance));
      free.dial = free.targetFrequency + offset;
      over.dial = over.targetFrequency + offset;
      expect(free.aligned, isTrue);
      expect(over.aligned, isFalse);
    });

    test('vale depois do piso da Planta: passa de baixo de metade do selo', () {
      // Planta com resistência 1 e tempo de sobra: o fator da Planta está no piso (0,5).
      final s = makeSession(type: EcoType.plant, playerLevel: 30, ecoLevel: 45, seed: 2);
      expect(s.overlevel, 10);
      s.t = 30;
      final plantFloor = b.signal.plant.toleranceFloor;
      expect(s.signal.toleranceFactorAt(30), plantFloor);
      final g = s.overlevel;
      expect(s.tolerance, closeTo(0.08 * plantFloor * overlevelToleranceFactor(g, b), 1e-12));
      expect(s.tolerance, lessThan(0.08 * plantFloor), reason: 'o sobrenível não fica preso ao piso da Planta');
    });

    test('o piso do sobrenível também vale por cima da Planta', () {
      // Um Eco tão acima que o fator^g já passou do piso, seja qual for o fator calibrado.
      var g = 1;
      while (overlevelToleranceFactor(g, b) > b.overlevelTolFloor) {
        g++;
      }
      final s = makeSession(type: EcoType.plant, playerLevel: 30, ecoLevel: 30 + b.overlevelFree + g + 5, seed: 2);
      s.t = 30;
      expect(s.tolerance, closeTo(0.08 * b.signal.plant.toleranceFloor * b.overlevelTolFloor, 1e-12));
    });

    test('só a tolerância muda: fogo e água não têm o fator da Planta, então é só o do sobrenível', () {
      for (final type in [EcoType.fire, EcoType.water]) {
        final s = makeSession(type: type, playerLevel: 10, ecoLevel: 22, seed: 4);
        s.t = 15;
        expect(s.tolerance, closeTo(0.08 * overlevelToleranceFactor(7, b), 1e-12), reason: type.name);
      }
    });

    test('selo reforçado e bônus de tipo multiplicam a tolerância base, e o sobrenível vem depois', () {
      final s = makeSession(type: EcoType.plant, playerLevel: 10, ecoLevel: 20, seed: 1, sealId: 'item.seal.fire');
      // Selo de Fogo contra Planta: 0,08 × 1,4. Sobrenível g = 5.
      expect(s.baseTolerance, closeTo(0.08 * 1.4, 1e-12));
      s.t = 0;
      expect(s.tolerance, closeTo(0.08 * 1.4 * overlevelToleranceFactor(5, b), 1e-12));
    });
  });

  group('eixo 2: progresso cai mais rápido', () {
    test('multiplicador: 1 sem sobrenível e 1 + k × g depois', () {
      expect(overlevelProgressDownFactor(0, b), 1.0);
      expect(overlevelProgressDownFactor(-2, b), 1.0);
      for (final g in [1, 5, 10, 15, 20]) {
        expect(overlevelProgressDownFactor(g, b), closeTo(1 + b.overlevelDownPerLevel * g, 1e-12), reason: 'g=$g');
      }
    });

    /// Progresso depois de [seconds] com o dial longe do alvo, partindo de [from].
    double fall(int eco, {double from = 0.9, double seconds = 1.0}) {
      final s = makeSession(type: EcoType.fire, playerLevel: 10, ecoLevel: eco, seed: 5);
      s.progress = from;
      for (var i = 0; i < (seconds / dt).round(); i++) {
        s.step(dt, dial: s.targetFrequency > 0.5 ? 0.0 : 1.0);
      }
      expect(s.aligned, isFalse);
      return s.progress;
    }

    test('sem sobrenível cai à taxa normal', () {
      expect(fall(10), closeTo(0.9 - b.progressDownPerS * 1.0, 1e-9));
      expect(fall(15), closeTo(0.9 - b.progressDownPerS * 1.0, 1e-9), reason: 'gap 5 ainda não tem sobrenível');
    });

    test('com sobrenível cai (1 + k g) vezes mais rápido', () {
      for (final eco in [17, 20, 25]) {
        final g = eco - 10 - b.overlevelFree;
        final expected = 0.9 - b.progressDownPerS * (1 + b.overlevelDownPerLevel * g);
        expect(fall(eco), closeTo(expected, 1e-9), reason: 'eco $eco, g=$g');
      }
    });

    test('quanto maior o g, mais rápido', () {
      expect(fall(20), lessThan(fall(17)));
      expect(fall(25), lessThan(fall(20)));
    });

    test('a subida não muda: alinhado o progresso sobe à taxa normal, com ou sem sobrenível', () {
      for (final eco in [10, 25]) {
        final s = makeSession(type: EcoType.fire, playerLevel: 10, ecoLevel: eco, seed: 6);
        for (var i = 0; i < 30; i++) {
          s.step(dt, dial: s.signal.frequencyAt(s.t + dt));
        }
        expect(s.progress, closeTo(b.progressUpPerS * 30 * dt, 1e-9), reason: 'eco $eco');
      }
    });

    test('o progresso continua parando em 0', () {
      final s = makeSession(type: EcoType.fire, playerLevel: 10, ecoLevel: 30, seed: 5);
      s.progress = 0.05;
      for (var i = 0; i < 60; i++) {
        s.step(dt, dial: s.targetFrequency > 0.5 ? 0.0 : 1.0);
      }
      expect(s.progress, 0);
    });
  });

  group('eixo 3: chance de fuga na falha', () {
    test('base sem sobrenível, sobe k por g e para no teto', () {
      expect(fleeChanceOnFail(0, b), b.fleeChanceOnFail);
      expect(fleeChanceOnFail(-4, b), b.fleeChanceOnFail);
      for (var g = 1; g <= 40; g++) {
        final expected = math.min(b.overlevelFleeMax, b.fleeChanceOnFail + b.overlevelFleePerLevel * g);
        expect(fleeChanceOnFail(g, b), closeTo(expected, 1e-12), reason: 'g=$g');
      }
    });

    test('nunca passa do teto (0,95), por mais nível que haja', () {
      expect(b.overlevelFleeMax, 0.95);
      for (final g in [20, 50, 500]) {
        expect(fleeChanceOnFail(g, b), b.overlevelFleeMax);
      }
    });

    test('só sobe, nunca cai', () {
      var prev = 0.0;
      for (var g = 0; g <= 30; g++) {
        expect(fleeChanceOnFail(g, b), greaterThanOrEqualTo(prev));
        prev = fleeChanceOnFail(g, b);
      }
    });

    /// Fração de fugas em 3000 falhas de uma sintonia com o Eco no nível [eco].
    double fledShare(int eco) {
      final s = makeSession(type: EcoType.fire, playerLevel: 10, ecoLevel: eco, seed: 7);
      while (s.running) {
        s.step(0.05, dial: s.targetFrequency > 0.5 ? 0.0 : 1.0);
      }
      expect(s.phase, TuningPhase.failed);
      var fled = 0;
      const n = 3000;
      for (var seed = 0; seed < n; seed++) {
        if (resolveTuning(s, Pcg32(fnv1a64([seed]), saltKenoma)).fled) fled++;
      }
      return fled / n;
    }

    test('a fuga acontece na proporção pedida: sem sobrenível, com g = 5 e no teto', () {
      expect(fledShare(10), closeTo(fleeChanceOnFail(0, b), 0.03));
      expect(fledShare(20), closeTo(fleeChanceOnFail(5, b), 0.03));
      expect(fledShare(35), closeTo(b.overlevelFleeMax, 0.02));
    });

    test('o sucesso não tem fuga nem muda com o sobrenível: rende 1 ou 2 de Ectoplasma', () {
      final s = makeSession(type: EcoType.fire, playerLevel: 10, ecoLevel: 25, seed: 8);
      while (s.running) {
        s.step(dt, dial: s.signal.frequencyAt(s.t + dt));
      }
      expect(s.phase, TuningPhase.success);
      final seen = <int>{};
      for (var seed = 0; seed < 100; seed++) {
        final o = resolveTuning(s, Pcg32(fnv1a64([seed]), saltKenoma));
        expect(o.fled, isFalse);
        seen.add(o.ectoplasm);
      }
      expect(seen, {1, 2});
    });
  });
}
