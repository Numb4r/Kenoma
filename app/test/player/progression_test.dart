import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/progress_balance.dart';
import 'package:kenoma/player/progression.dart';

import '../support/fixtures.dart';

void main() {
  final b = loadProgressBalance();
  const noon = 1790035200 + 43200; // 2026-09-22 12:00 UTC
  const utcOnly = Duration.zero; // o teste não depende do fuso da máquina
  const day = 86400;

  PlayerProgress fresh() => PlayerProgress(balance: b);

  test('a curva da spec: 60 × n^1,25 arredondado para dezenas', () {
    expect([for (final n in [1, 2, 3, 4, 5, 10, 14]) xpToNext(n, b)], [60, 140, 240, 340, 450, 1070, 1620]);
  });

  test('o dia local muda à meia-noite local, não à UTC', () {
    const t = 1790035200 + 2 * 3600; // 02:00 UTC
    expect(localDay(t, offset: const Duration(hours: -3)), localDay(t - day, offset: utcOnly), reason: 'em UTC-3 ainda é o dia anterior');
    expect(localDay(t, offset: utcOnly), localDay(t - day, offset: utcOnly) + 1);
  });

  group('descanso', () {
    test('o primeiro dia dá 350 de XP que rendem o dobro, e o saldo gasta', () {
      final p = fresh();
      expect(p.gain(100, noon, offset: utcOnly), 2, reason: '100 + 100 de bônus = 200 = 60 + 140: sobe do 1 ao 3');
      expect(p.restBalance, 250);
      expect((p.level, p.xp), (3, 0));
    });

    test('acima do saldo só a parte do saldo dobra', () {
      final p = fresh()..restBalance = 50;
      p.gain(80, noon, offset: utcOnly);
      // 80 brutos + 50 de bônus = 130: nível 2 (60) e sobram 70.
      expect((p.level, p.xp, p.restBalance), (2, 70, 0));
    });

    test('o que não é usado acumula a cada dia, até 1050', () {
      final p = fresh();
      p.refreshRest(noon, offset: utcOnly);
      expect(p.restBalance, 350);
      p.refreshRest(noon + day, offset: utcOnly);
      expect(p.restBalance, 700);
      p.refreshRest(noon + 2 * day, offset: utcOnly);
      expect(p.restBalance, 1050);
      p.refreshRest(noon + 30 * day, offset: utcOnly);
      expect(p.restBalance, 1050, reason: 'o teto é 1050');
    });

    test('vários dias parados somam todos de uma vez', () {
      final p = fresh()..restBalance = 0;
      p.refreshRest(noon, offset: utcOnly);
      p.refreshRest(noon + 2 * day, offset: utcOnly);
      expect(p.restBalance, 700);
    });

    test('o mesmo dia não soma de novo, e o relógio que volta não tira nem põe nada', () {
      final p = fresh();
      p.refreshRest(noon, offset: utcOnly);
      p.refreshRest(noon + 3600, offset: utcOnly);
      p.refreshRest(noon - 5 * day, offset: utcOnly);
      expect(p.restBalance, 350);
      expect(p.restDay, localDay(noon, offset: utcOnly));
    });
  });

  group('nível e teto', () {
    test('sobe vários níveis de uma vez e guarda o resto', () {
      final p = fresh()..restBalance = 0;
      expect(p.gain(60 + 140 + 240 + 5, noon, offset: utcOnly), 3);
      expect((p.level, p.xp), (4, 5));
      expect(p.fraction, closeTo(5 / 340, 1e-9));
    });

    test('o teto é 15: o XP além dele fica guardado, e o nível não passa', () {
      final p = fresh()..restBalance = 0;
      p.gain(11000, noon, offset: utcOnly); // 10930 chegam ao 15
      expect(p.level, 15);
      expect(p.atCap, isTrue);
      expect((p.xp, p.bankedXp), (0, 70));
      p.gain(500, noon, offset: utcOnly);
      expect(p.bankedXp, 570);
      expect(p.level, 15);
    });

    test('com o teto mais alto, o XP guardado entra', () {
      final p = fresh()..restBalance = 0;
      p.gain(11000, noon, offset: utcOnly);
      final raised = {...loadJson('assets/data/balance.json')};
      raised['xp'] = {...(raised['xp'] as Map<String, dynamic>), 'player_level_cap': 16};
      final q = PlayerProgress(level: p.level, xp: p.xp, bankedXp: p.bankedXp, restBalance: 0, balance: ProgressBalance(raised));
      expect(q.settleBanked(), 0, reason: '70 não chega aos ${xpToNext(15, ProgressBalance(raised))} do nível 15');
      expect((q.level, q.xp, q.bankedXp), (15, 70, 0));
    });

    test('ganhar zero ou menos não faz nada', () {
      final p = fresh();
      expect(p.gain(0, noon, offset: utcOnly), 0);
      expect(p.gain(-5, noon, offset: utcOnly), 0);
      expect((p.level, p.xp, p.restDay), (1, 0, null));
    });
  });

  test('XP da sintonia: 20 + 2 × nível do Eco, com teto de 60', () {
    expect([for (final l in [1, 5, 10, 20, 25]) tuningXp(l, b)], [22, 30, 40, 60, 60]);
  });

  test('vai e volta no JSON, e um save sem o bloco começa no nível 1', () {
    final p = fresh()..restBalance = 0;
    p.gain(100, noon, offset: utcOnly);
    final again = PlayerProgress.fromJson(p.toJson(), b);
    expect(again.toJson(), p.toJson());
    expect(PlayerProgress.fromJson(null, b).level, 1);
  });
}
