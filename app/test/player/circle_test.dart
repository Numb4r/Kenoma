import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/player/circle.dart';
import 'package:kenoma/player/game_state.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();
  final b = data.progress;
  GameState state() => GameState(groupCode: 'KENOMA-TESTE', balance: b);
  void give(GameState s, String uid, String species, int level) =>
      s.collection.add(CreatureInstance(uid: uid, speciesId: species, level: level, capturedUtc: 1));

  group('espaços', () {
    test('3 espaços ativos escolhidos da coleção; o quarto não entra; tocar de novo tira', () {
      final s = state();
      for (var i = 0; i < 4; i++) {
        give(s, '$i', 'soot.eco', 1);
      }
      expect([for (var i = 0; i < 4; i++) s.toggleCircle('$i')], [true, true, true, false]);
      expect(s.circle, ['0', '1', '2']);
      expect(s.toggleCircle('1'), isTrue);
      expect(s.circle, ['0', '2']);
      expect(s.toggleCircle('3'), isTrue);
      expect(s.circle, ['0', '2', '3']);
    });

    test('só entra quem está na coleção', () {
      expect(state().toggleCircle('fantasma'), isFalse);
    });
  });

  group('habilidades de mapa por faixa de nível', () {
    MapAbilities of(GameState s) => abilitiesOf(s, data);

    test('sem Círculo, nada muda', () {
      final s = state();
      give(s, 'a', 'soot.eco', 5);
      expect(of(s).auraBonusM, 0);
      expect(of(s).trackerRangeM, 0);
    });

    test('Sootling: Aura +3, +5, +8 m nas faixas 1–9, 10–19 e 20', () {
      for (final (lv, bonus) in [(1, 3.0), (9, 3.0), (10, 5.0), (19, 5.0), (20, 8.0)]) {
        final s = state();
        give(s, 'a', 'soot.eco', lv);
        s.toggleCircle('a');
        expect(of(s).auraBonusM, bonus, reason: 'nível $lv');
      }
    });

    test('Frondling: coleta +3, +5, +8 m; Rillet: rastreador 150, 170, 200 m', () {
      final s = state();
      give(s, 'f', 'frond.eco', 10);
      give(s, 'r', 'rill.eco', 20);
      s.toggleCircle('f');
      s.toggleCircle('r');
      final a = of(s);
      expect((a.pickupBonusM, a.trackerRangeM, a.auraBonusM), (5.0, 200.0, 0.0));
    });

    test('habilidades iguais não se somam: vale a maior', () {
      final s = state();
      give(s, 'a', 'soot.eco', 3);
      give(s, 'b', 'soot.eco', 12);
      give(s, 'c', 'soot.eco', 1);
      for (final u in ['a', 'b', 'c']) {
        s.toggleCircle(u);
      }
      expect(of(s).auraBonusM, 5);
    });

    test('quem está fora do Círculo não aplica nada, e trocar o Círculo muda o efeito', () {
      final s = state();
      give(s, 'a', 'soot.eco', 1);
      give(s, 'r', 'rill.eco', 1);
      s.toggleCircle('a');
      expect(of(s).auraBonusM, 3);
      s.toggleCircle('a');
      s.toggleCircle('r');
      expect((of(s).auraBonusM, of(s).trackerRangeM), (0.0, 150.0));
    });
  });

  group('bônus de tolerância por tipo forte', () {
    test('conta as criaturas do Círculo que vencem o tipo do alvo', () {
      final s = state();
      give(s, 'f', 'soot.eco', 1); // Fogo vence Planta
      give(s, 'g', 'soot.eco', 1);
      give(s, 'w', 'rill.eco', 1); // Água vence Fogo
      for (final u in ['f', 'g', 'w']) {
        s.toggleCircle(u);
      }
      expect(strongInCircle(s, data, EcoType.plant), 2);
      expect(strongInCircle(s, data, EcoType.fire), 1);
      expect(strongInCircle(s, data, EcoType.water), 0);
    });

    test('cada uma multiplica a tolerância por 1,1, até 3', () {
      expect(data.tuning.balance.circleStrongMultiplier, 1.1);
      expect(data.tuning.balance.circleStrongMax, 3);
    });
  });

  group('XP das criaturas do Círculo', () {
    test('10 XP por sintonia, e para ir do nível n ao n+1 são 30 × n', () {
      final c = CreatureInstance(uid: 'a', speciesId: 'soot.eco', level: 1, capturedUtc: 1);
      var x = withCreatureXp(c, b);
      expect((x.level, x.xp), (1, 10));
      x = withCreatureXp(withCreatureXp(x, b), b); // 30 no total: sobe
      expect((x.level, x.xp), (2, 0));
      x = withCreatureXp(x, b, amount: 70); // 60 por n=2: sobe e sobram 10
      expect((x.level, x.xp), (3, 10));
    });

    test('o teto é o nível 20', () {
      final c = CreatureInstance(uid: 'a', speciesId: 'soot.eco', level: 20, capturedUtc: 1);
      final x = withCreatureXp(c, b, amount: 5000);
      expect((x.level, x.xp), (20, 0));
    });

    test('só quem está no Círculo ganha, e o estado guarda', () {
      final s = state();
      give(s, 'in', 'soot.eco', 1);
      give(s, 'out', 'soot.eco', 1);
      s.toggleCircle('in');
      for (var i = 0; i < 3; i++) {
        awardCircleXp(s);
      }
      expect((s.creature('in')!.level, s.creature('in')!.xp), (2, 0));
      expect(s.creature('out')!.xp, 0);
    });
  });
}
