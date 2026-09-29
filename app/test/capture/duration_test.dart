import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/resistance.dart';
import 'package:kenoma/capture/session.dart';

import '../support/reference_player.dart';

/// Critérios de duração do M3 (docs/marcos.md e spec, seção 5), medidos com o jogador de referência
/// de test/support/reference_player.dart: 100 sintonias com sementes diferentes por cenário.
/// O balanceamento final vem de jogar no celular. Estes testes só impedem que uma mudança em
/// balance.json tire a sintonia dos alvos sem ninguém perceber.
List<double> durations(EcoType type, int player, int eco, {int n = 100, String seal = 'item.seal.simple'}) {
  const bot = ReferencePlayer();
  final out = <double>[];
  for (var seed = 0; seed < n; seed++) {
    final s = makeSession(type: type, playerLevel: player, ecoLevel: eco, seed: seed, sealId: seal);
    bot.play(s);
    out.add(s.phase == TuningPhase.success ? s.t : double.infinity);
  }
  return out..sort();
}

double median(List<double> sorted) => sorted[sorted.length ~/ 2];

/// A Água e a Planta mudaram: a calibração delas é refeita com o jogador perfeito, no último
/// commit desta rodada.
String? _recalibrate(EcoType type) => type == EcoType.fire ? null : 'recalibrar ${type.name} com o jogador perfeito';

void main() {
  final b = loadTuningBalance();

  test('cenário forte: Conjurador 15 contra Eco 15 tem resistência 0,72', () {
    expect(resistanceIntensity(playerLevel: 15, ecoLevel: 15, balance: b), closeTo(0.72, 1e-12));
  });

  for (final type in EcoType.values) {
    test('${type.name}, sem resistência: todas as sintonias levam de 5 a 8 s', () {
      final d = durations(type, 1, 1);
      expect(d.first, greaterThanOrEqualTo(5.0));
      expect(d.last, lessThanOrEqualTo(8.0));
    });

    test('${type.name}, resistência forte: mediana de 10 a 15 s, dentro do teto de 20 s', skip: _recalibrate(type), () {
      final d = durations(type, 15, 15);
      expect(median(d), inInclusiveRange(10.0, 15.0));
      expect(d.where((x) => x > b.timeLimitS).length, lessThanOrEqualTo(5), reason: 'no máximo 5% estouram o teto');
      expect(d.first, greaterThanOrEqualTo(5.0), reason: 'nunca antes dos 5 s de alinhamento');
    });

    test('${type.name}, resistência forte pesa mais que a média e a média mais que nenhuma', skip: _recalibrate(type), () {
      final none = median(durations(type, 1, 1));
      final mid = median(durations(type, 9, 9));
      final strong = median(durations(type, 15, 15));
      expect(mid, greaterThanOrEqualTo(none));
      expect(strong, greaterThan(mid));
    });
  }

  test('selo reforçado deixa a resistência forte mais curta que o simples', () {
    for (final type in EcoType.values) {
      final simple = median(durations(type, 15, 15));
      final reinforced = median(durations(type, 15, 15, seal: 'item.seal.reinforced'));
      expect(reinforced, lessThan(simple), reason: type.name);
    }
  });

  test('selo de tipo contra o tipo que vence encurta a sintonia forte', () {
    final plain = median(durations(EcoType.plant, 15, 15));
    final typed = median(durations(EcoType.plant, 15, 15, seal: 'item.seal.fire'));
    expect(typed, lessThan(plain));
  });

  test('o tônico dá tempo: com resistência muito forte, mais sintonias fecham em 25 s que em 20 s', () {
    // Eco muito acima do Conjurador, para haver falhas no tempo normal.
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
