import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/crafting/crafting.dart';
import 'package:kenoma/player/game_state.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();
  GameState state([Map<String, int> inv = const {}]) => GameState(groupCode: 'KENOMA-TESTE', balance: data.progress, inventory: inv);
  final r = data.recipes;

  test('as quatro receitas existem: simples, reforçado, selos de tipo e tônico', () {
    expect(r.keys.toSet(), {
      'recipe.seal.simple', 'recipe.seal.reinforced', 'recipe.seal.fire', 'recipe.seal.plant', 'recipe.seal.water', 'recipe.tonic.focus',
    });
    expect(r['recipe.seal.reinforced']!.anyEssence, 2);
    expect(r['recipe.seal.reinforced']!.inputs, {'item.seal.simple': 1});
  });

  group('fabricar', () {
    test('selo simples: Giz + Ectoplasma', () {
      final s = state({'item.chalk': 1, 'item.ectoplasm': 1});
      expect(craftRecipe(s, r['recipe.seal.simple']!), isTrue);
      expect((s.count('item.seal.simple'), s.count('item.chalk'), s.count('item.ectoplasm')), (1, 0, 0));
    });

    test('falta ingrediente: nada é gasto', () {
      final s = state({'item.chalk': 1});
      expect(canCraft(s, r['recipe.seal.simple']!), isFalse);
      expect(craftRecipe(s, r['recipe.seal.simple']!), isFalse);
      expect(s.count('item.chalk'), 1);
    });

    test('selo de tipo: selo simples + 3 Pó de Essência do tipo', () {
      final s = state({'item.seal.simple': 1, 'item.dust.fire': 3, 'item.dust.water': 5});
      expect(craftRecipe(s, r['recipe.seal.fire']!), isTrue);
      expect((s.count('item.seal.fire'), s.count('item.seal.simple'), s.count('item.dust.fire'), s.count('item.dust.water')), (1, 0, 0, 5));
      expect(craftRecipe(s, r['recipe.seal.water']!), isFalse, reason: 'sem selo simples');
    });

    test('tônico: Ervas + Água pura', () {
      final s = state({'item.herbs': 1, 'item.pure_water': 1});
      expect(craftRecipe(s, r['recipe.tonic.focus']!), isTrue);
      expect(s.count('item.tonic.focus'), 1);
    });

    test('selo reforçado: gasta 2 Essências de qualquer tipo, da pilha maior primeiro, misturadas ou não', () {
      final s = state({'item.seal.simple': 1, 'item.essence.fire': 1, 'item.essence.water': 4});
      expect(craftRecipe(s, r['recipe.seal.reinforced']!), isTrue);
      expect((s.count('item.essence.fire'), s.count('item.essence.water')), (1, 2));
      expect(s.count('item.seal.reinforced'), 1);

      final m = state({'item.seal.simple': 1, 'item.essence.fire': 1, 'item.essence.plant': 1});
      expect(craftRecipe(m, r['recipe.seal.reinforced']!), isTrue, reason: 'misturadas');
      expect(essenceTotal(m), 0);
    });

    test('selo reforçado sem Essência suficiente ou sem selo simples não fabrica', () {
      expect(canCraft(state({'item.seal.simple': 1, 'item.essence.fire': 1}), r['recipe.seal.reinforced']!), isFalse);
      expect(canCraft(state({'item.essence.fire': 2}), r['recipe.seal.reinforced']!), isFalse);
    });
  });

  group('destilar', () {
    GameState withEco(String uid, int level, {bool circle = false}) {
      final s = state()..collection.add(CreatureInstance(uid: uid, speciesId: 'rill.eco', level: level, capturedUtc: 1));
      if (circle) s.toggleCircle(uid);
      return s;
    }

    test('rende 3 do nível 1 ao 7, 4 do 8 ao 14 e 5 do 15 ao 20', () {
      for (final (lv, qty) in [(1, 3), (7, 3), (8, 4), (14, 4), (15, 5), (20, 5)]) {
        expect(distillYield(lv, data.progress), qty, reason: 'nível $lv');
      }
    });

    test('o Eco sai da coleção e vira Essência do tipo dele', () {
      final s = withEco('a', 9);
      final got = distill(s, 'a', data)!;
      expect((got.itemId, got.qty), ('item.essence.water', 4));
      expect(s.count('item.essence.water'), 4);
      expect(s.collection, isEmpty);
    });

    test('Ecos no Círculo não podem ser destilados', () {
      final s = withEco('a', 9, circle: true);
      expect(distillBlocker(s, 'a'), isNotNull);
      expect(distill(s, 'a', data), isNull);
      expect(s.collection, hasLength(1));
      expect(s.count('item.essence.water'), 0);
    });

    test('uid que não existe não faz nada', () {
      expect(distill(state(), 'x', data), isNull);
    });
  });
}
