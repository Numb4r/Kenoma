import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/resistance.dart';
import 'package:kenoma/capture/session.dart';

import '../support/reference_player.dart';

/// Critérios de duração do M3 (docs/marcos.md e spec, seção 5), medidos com bots de test/support:
/// 100 sintonias com sementes fixas por cenário, então o resultado é sempre o mesmo.
///
/// - Sem resistência: 5 a 8 s, com o jogador de referência (hesita 0,8 s e a mão treme um pouco).
/// - Resistência forte (Conjurador 15 contra Eco 17): 10 a 15 s, com o jogador perfeito
///   ([perfectPlayer]): sem tremor, 0,2 s para reagir, dial rápido, sem prever. Um humano leva mais.
///
/// O balanceamento final vem de jogar no celular. Estes testes só impedem que uma mudança em
/// balance.json tire a sintonia dos alvos sem ninguém perceber.
List<double> durations(EcoType type, int player, int eco,
    {ReferencePlayer bot = const ReferencePlayer(), int n = 100, String seal = 'item.seal.simple'}) {
  final out = <double>[];
  for (var seed = 0; seed < n; seed++) {
    final s = makeSession(type: type, playerLevel: player, ecoLevel: eco, seed: seed, sealId: seal);
    bot.play(s);
    out.add(s.phase == TuningPhase.success ? s.t : double.infinity);
  }
  return out..sort();
}

double median(List<double> sorted) => sorted[sorted.length ~/ 2];

void main() {
  final b = loadTuningBalance();

  test('o cenário forte é Conjurador 15 contra Eco 17: resistência 0,81', () {
    expect(resistanceIntensity(playerLevel: 15, ecoLevel: 17, balance: b), closeTo(0.81, 1e-12));
  });

  for (final type in EcoType.values) {
    test('${type.name}, sem resistência: todas as sintonias levam de 5 a 8 s', () {
      final d = durations(type, 1, 1);
      expect(d.first, greaterThanOrEqualTo(5.0));
      expect(d.last, lessThanOrEqualTo(8.0));
    });

    test('${type.name}, resistência forte, jogador perfeito: mediana de 10 a 15 s, dentro do teto de 20 s', () {
      final d = durations(type, 15, 17, bot: perfectPlayer);
      expect(median(d), inInclusiveRange(10.0, 15.0), reason: 'mediana ${median(d)} s');
      expect(d.where((x) => x > b.timeLimitS).length, lessThanOrEqualTo(5), reason: 'no máximo 5% estouram o teto');
      expect(d.first, greaterThanOrEqualTo(5.0), reason: 'nunca antes dos 5 s de alinhamento');
    });

    test('${type.name}, a resistência forte pesa mais que a média e a média mais que nenhuma', () {
      final none = median(durations(type, 1, 1, bot: perfectPlayer));
      final mid = median(durations(type, 9, 9, bot: perfectPlayer));
      final strong = median(durations(type, 15, 17, bot: perfectPlayer));
      expect(mid, greaterThanOrEqualTo(none));
      expect(strong, greaterThan(mid + 2));
    });

    test('${type.name}, um jogador de mão tremida e mais lento demora mais que o perfeito', () {
      final perfect = median(durations(type, 15, 17, bot: perfectPlayer));
      final human = median(durations(type, 15, 17));
      expect(human, greaterThanOrEqualTo(perfect));
    });
  }

  test('selo reforçado deixa a resistência forte mais curta que o simples', () {
    for (final type in EcoType.values) {
      final simple = median(durations(type, 15, 17, bot: perfectPlayer));
      final reinforced = median(durations(type, 15, 17, bot: perfectPlayer, seal: 'item.seal.reinforced'));
      expect(reinforced, lessThan(simple), reason: type.name);
    }
  });

  test('selo de tipo contra o tipo que vence encurta a sintonia forte', () {
    final plain = median(durations(EcoType.plant, 15, 17, bot: perfectPlayer));
    final typed = median(durations(EcoType.plant, 15, 17, bot: perfectPlayer, seal: 'item.seal.fire'));
    expect(typed, lessThan(plain));
  });

  test('o tônico dá tempo: com resistência muito forte, mais sintonias fecham em 25 s que em 20 s', () {
    int successes(bool tonic) {
      const bot = ReferencePlayer(startDelayS: 3, tremorAmp: 0.05);
      var ok = 0;
      for (var seed = 0; seed < 100; seed++) {
        final s = makeSession(type: EcoType.fire, playerLevel: 15, ecoLevel: 20, seed: seed, tonic: tonic);
        bot.play(s);
        if (s.phase == TuningPhase.success) ok++;
      }
      return ok;
    }

    expect(successes(true), greaterThanOrEqualTo(successes(false)));
  });
}
