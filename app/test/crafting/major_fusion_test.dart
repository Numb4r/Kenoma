import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/crafting/major_fusion.dart';
import 'package:kenoma/player/attributes.dart';
import 'package:kenoma/player/game_state.dart';

import '../support/fixtures.dart';

/// 0.27.0: a fusão da Entidade Maior: 3 Espíritos da família e a criatura de ritual dela como oferenda.
void main() {
  final data = loadGameData();
  const now = 1790040000;

  /// Um jogo no nível [level] com três Espíritos do Soot (`s0`..`s2`, níveis [levels]), um Kilnshade (`r0`) e, de
  /// propósito, um Espírito de outra família (`x0`) e um Eco do Soot (`e0`).
  GameState make({int level = 12, List<int> levels = const [20, 22, 24], Map<String, int> inv = const {'item.essence.fire': 12}}) {
    final s = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress, inventory: inv)..levelOverride = level;
    for (var i = 0; i < levels.length; i++) {
      s.collection.add(CreatureInstance(uid: 's$i', speciesId: 'soot.spirit', level: levels[i], capturedUtc: now, traits: i == 1 ? const ['shiny'] : const []));
    }
    s.collection
      ..add(const CreatureInstance(uid: 'r0', speciesId: 'soot.ritual', level: 15, capturedUtc: now, variant: 'urban'))
      ..add(const CreatureInstance(uid: 'x0', speciesId: 'rill.spirit', level: 20, capturedUtc: now))
      ..add(const CreatureInstance(uid: 'e0', speciesId: 'soot.eco', level: 20, capturedUtc: now));
    return s;
  }

  const three = ['s0', 's1', 's2'];

  test('os números da camada vêm do balance.json: teto 40 e 3 traços na Entidade, 50 e 4 no Arquétipo, Poder em escada', () {
    final cb = make().cb;
    expect((cb.majorFusionLevel, cb.majorSpiritCount, cb.majorEssenceCost, cb.majorLevelCap, cb.majorTraitsMax, cb.archetypeLevelCap, cb.archetypeTraitsMax), (12, 3, 10, 40, 3, 50, 4));
    expect([for (final t in ['eco', 'spirit', 'major', 'archetype']) cb.power(t, 1)], [12, 43, 104, 225]);
    expect(data.progress.levelCapFor('soot.major'), 40);
    expect(data.progress.traitCapFor('soot.archetype'), 4);
  });

  test('funde: consome os três Espíritos, a oferenda e a Essência, e mais nada; a Entidade entra na coleção e no Bestiário', () {
    final s = make(inv: {'item.essence.fire': 12, 'item.essence.water': 3});
    final major = fuseMajor(s, data, 'soot', three, 'r0', nowUtc: now)!;
    expect(major.speciesId, 'soot.major');
    expect(s.collection.map((c) => c.uid).toSet(), {'x0', 'e0', major.uid}, reason: 'o Espírito de outra família e o Eco ficam');
    expect(s.count('item.essence.fire'), 2);
    expect(s.count('item.essence.water'), 3);
    expect(s.hasCaptured('soot.major'), isTrue);
    expect((s.story.count('fusion_major'), s.story.count('major_seen_soot')), (1, 1));
    expect(powerOf(major, data), greaterThan(100));
  });

  test('o nível é a média dos Espíritos (a oferenda não conta); os traços vêm de todas as peças, o Brilhante primeiro', () {
    final plan = majorPlan(make(levels: [20, 22, 25]), data, 'soot', three, 'r0')!;
    expect(plan.level, 22, reason: '67/3 = 22,3; o Kilnshade no 15 não puxa para baixo');
    expect(plan.traits, ['shiny', 'urban']);
    expect(majorPlan(make(levels: [40, 40, 40]), data, 'soot', three, 'r0')!.level, 40, reason: 'no teto da Entidade');
  });

  test('peças erradas, nível baixo e falta de Essência bloqueiam sem gastar nada', () {
    expect(majorBlocker(make(level: 11), data, 'soot', three, 'r0'), MajorBlocker.locked);
    expect(majorBlocker(make(), data, 'soot', ['s0', 's1'], 'r0'), MajorBlocker.wrongCount);
    expect(majorBlocker(make(), data, 'soot', three, null), MajorBlocker.wrongCount, reason: 'sem oferenda');
    expect(majorBlocker(make(), data, 'soot', ['s0', 's1', 'x0'], 'r0'), MajorBlocker.invalidPiece, reason: 'Espírito de outra família');
    expect(majorBlocker(make(), data, 'soot', three, 'e0'), MajorBlocker.invalidPiece, reason: 'a oferenda é a criatura de ritual');
    expect(majorBlocker(make(), data, 'soot', ['s0', 's0', 's1'], 'r0'), MajorBlocker.invalidPiece, reason: 'repetido');
    final poor = make(inv: {'item.essence.fire': 9});
    expect(majorBlocker(poor, data, 'soot', three, 'r0'), MajorBlocker.missingEssence);
    expect(fuseMajor(poor, data, 'soot', three, 'r0', nowUtc: now), isNull);
    expect(poor.collection, hasLength(6));
    final circled = make()..circle.add('r0');
    expect(majorBlocker(circled, data, 'soot', three, 'r0'), MajorBlocker.needsCircleConfirm);
    expect(fuseMajor(circled, data, 'soot', three, 'r0', nowUtc: now, confirmCircle: true), isNotNull);
    expect(circled.circle, isNot(contains('r0')));
  });

  test('a receita mostra ??? no que o jogador ainda não viu', () {
    final s = make();
    expect([for (final slot in majorRecipe(s, 'soot')) slot.known], [false, false, false]);
    s.markSeen('soot.spirit');
    s.markSeen('soot.ritual');
    expect([for (final slot in majorRecipe(s, 'soot')) (slot.speciesId, slot.count, slot.known)], [('soot.spirit', 3, true), ('soot.ritual', 1, true), ('soot.major', 1, false)]);
  });
}
