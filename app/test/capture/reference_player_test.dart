import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/session.dart';

import '../support/reference_player.dart';

/// Os jogadores simulados são a régua do balanceamento: aqui se confere o que eles dizem ser.
void main() {
  group('jogador típico', () {
    test('reação 0,35 s, tremor ±0,02, 10% das correções passam do ponto', () {
      expect(typicalPlayer.reactionS, 0.35);
      expect(typicalPlayer.tremorAmp, 0.02);
      expect(typicalPlayer.overshootChance, 0.1);
    });

    test('é mais lento e menos preciso que o perfeito', () {
      expect(typicalPlayer.reactionS, greaterThan(perfectPlayer.reactionS));
      expect(typicalPlayer.tremorAmp, greaterThan(perfectPlayer.tremorAmp));
      expect(perfectPlayer.overshootChance, 0);
    });

    test('a mesma semente dá a mesma sintonia; sementes diferentes dão sintonias diferentes', () {
      double run(int session, int botSeed) {
        final s = makeSession(type: EcoType.fire, playerLevel: 10, ecoLevel: 15, seed: session);
        return typicalPlayer.play(s, seed: botSeed);
      }

      expect(run(3, 7), run(3, 7));
      expect({for (var seed = 0; seed < 8; seed++) run(3, seed)}.length, greaterThan(1));
    });

    test('o tremor nunca passa de ±0,02 e vai para os dois lados, com fase que muda por semente', () {
      List<double> tremor(int seed) {
        // O jogador só começa a mexer depois de 30 s: o dial fica em 0,5 e sobra só o tremor.
        final s = makeSession(type: EcoType.fire, playerLevel: 1, ecoLevel: 1, seed: 1);
        final out = <double>[];
        ReferencePlayer(
          startDelayS: 30,
          tremorAmp: 0.02,
          tremorRandomPhase: true,
        ).play(s, seed: seed, onStep: (t, dial) => out.add(dial - 0.5));
        return out;
      }

      final a = tremor(1);
      expect(a, isNotEmpty);
      for (final v in a) {
        expect(v.abs(), lessThanOrEqualTo(0.02 + 1e-12));
      }
      expect(a.any((v) => v > 0.005) && a.any((v) => v < -0.005), isTrue);
      expect(tremor(2), isNot(a), reason: 'a fase é sorteada por sintonia');
      expect(tremor(1), a, reason: 'e é a mesma para a mesma semente');
    });
  });

  group('correções que passam do ponto', () {
    /// Quanto o dial passou do alvo (na direção do movimento), no máximo, nos primeiros 1,5 s de uma
    /// sintonia sem resistência: o sinal quase não anda, então o alvo é praticamente fixo.
    double overshoot({required double chance, required double fraction, int seed = 0}) {
      final s = makeSession(type: EcoType.fire, playerLevel: 1, ecoLevel: 1, seed: 2);
      final target = s.signal.frequencyAt(0);
      final up = target > 0.5;
      var beyond = 0.0;
      ReferencePlayer(
        startDelayS: 0.1,
        reactionS: 0.1,
        maxSpeed: 3,
        tremorAmp: 0,
        retargetThreshold: 0.03,
        overshootChance: chance,
        overshootFraction: fraction,
      ).play(s, seed: seed, onStep: (t, dial) {
        if (t < 1.5) beyond = beyond > (up ? dial - target : target - dial) ? beyond : (up ? dial - target : target - dial);
      });
      return beyond;
    }

    test('sem chance de passar do ponto o dial acompanha o alvo, sem ultrapassá-lo', () {
      expect(overshoot(chance: 0, fraction: 0.5), lessThan(0.02));
    });

    test('com chance 1 a primeira correção passa do alvo na fração pedida da distância', () {
      final s = makeSession(type: EcoType.fire, playerLevel: 1, ecoLevel: 1, seed: 2);
      final distance = (s.signal.frequencyAt(0) - 0.5).abs();
      expect(distance, greaterThan(0.06), reason: 'a sintonia do teste precisa de uma correção grande');
      final beyond = overshoot(chance: 1, fraction: 0.5);
      expect(beyond, greaterThan(distance * 0.35));
      expect(beyond, lessThan(distance * 0.65));
    });

    test('passar do ponto é terminar o movimento lá e corrigir de volta: o dial volta ao alvo depois', () {
      // Com um sinal parado só há uma correção: procura uma semente em que ela passa do ponto.
      final seed = [for (var i = 0; i < 100; i++) i].firstWhere((i) => overshoot(chance: 0.5, fraction: 0.5, seed: i) > 0.03);
      final s = makeSession(type: EcoType.fire, playerLevel: 1, ecoLevel: 1, seed: 2);
      final target = s.signal.frequencyAt(0);
      final up = target > 0.5;
      double? peakAt;
      var peak = 0.0;
      var settled = 1.0;
      ReferencePlayer(
        startDelayS: 0.1,
        reactionS: 0.1,
        maxSpeed: 3,
        tremorAmp: 0,
        retargetThreshold: 0.03,
        overshootChance: 0.5,
        overshootFraction: 0.5,
      ).play(s, seed: seed, onStep: (t, dial) {
        final beyond = up ? dial - target : target - dial;
        if (beyond > peak) {
          peak = beyond;
          peakAt = t;
        }
        if (t > 3.0) settled = beyond.abs() < settled ? beyond.abs() : settled;
      });
      expect(peak, greaterThan(0.03));
      expect(peakAt!, lessThan(3.0));
      expect(settled, lessThan(0.03), reason: 'depois de passar, o dial volta para perto do alvo');
    });

    test('a chance é respeitada: com 10%, uma parte das sintonias passa do ponto e a maioria não', () {
      var over = 0;
      const n = 200;
      for (var seed = 0; seed < n; seed++) {
        if (overshoot(chance: 0.1, fraction: 0.5, seed: seed) > 0.02) over++;
      }
      expect(over, inInclusiveRange(8, 45), reason: 'cerca de 10% de $n: passaram $over');
    });

    test('a decisão de passar do ponto é sorteada só quando há uma correção nova, e é a mesma por semente', () {
      expect(overshoot(chance: 0.5, fraction: 0.5, seed: 3), overshoot(chance: 0.5, fraction: 0.5, seed: 3));
    });
  });

  test('o jogador padrão continua acompanhando o sinal o tempo todo (sem limiar de correção)', () {
    const bot = ReferencePlayer();
    expect(bot.retargetThreshold, 0);
    expect(bot.overshootChance, 0);
    expect(bot.tremorRandomPhase, isFalse);
  });

  group('raízes da Planta', () {
    /// Fração dos quadros com o dial dentro de uma raiz, em 50 sintonias fortes.
    double inRoot(ReferencePlayer bot) {
      var inside = 0, total = 0;
      for (var seed = 0; seed < 50; seed++) {
        final s = makeSession(type: EcoType.plant, playerLevel: 15, ecoLevel: 17, seed: seed);
        bot.play(s, seed: seed, onStep: (t, dial) {
          total++;
          if (s.signal.dialInRoot(dial, t)) inside++;
        });
      }
      return inside / total;
    }

    test('o jogador de referência vê as raízes e sai de dentro delas', () {
      const blind = ReferencePlayer(startDelayS: 0.3, reactionS: 0.2, maxSpeed: 3, tremorAmp: 0, avoidsRoots: false);
      expect(perfectPlayer.avoidsRoots, isTrue);
      expect(typicalPlayer.avoidsRoots, isTrue);
      // Mesmo vendo, ele só reage 0,2 s depois de a raiz nascer em cima do sinal (~23% do tempo dentro);
      // sem ver, fica sentado nelas (~52%).
      final aware = inRoot(perfectPlayer);
      final unaware = inRoot(blind);
      expect(aware, lessThan(unaware * 0.6), reason: 'vendo: $aware, sem ver: $unaware');
      expect(aware, lessThan(0.3));
    });

    test('sem raízes (fora da Planta ou sem resistência) o jogador se comporta como sempre', () {
      for (final type in EcoType.values) {
        final a = makeSession(type: type, playerLevel: 1, ecoLevel: 1, seed: 4);
        final b = makeSession(type: type, playerLevel: 1, ecoLevel: 1, seed: 4);
        expect(perfectPlayer.play(a), const ReferencePlayer(startDelayS: 0.3, reactionS: 0.2, maxSpeed: 3, tremorAmp: 0, avoidsRoots: false).play(b));
        expect(a.phase, TuningPhase.success);
      }
    });
  });
}
