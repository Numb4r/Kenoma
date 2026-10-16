import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/crafting/fusion.dart';
import 'package:kenoma/player/circle.dart';
import 'package:kenoma/player/game_state.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();
  const now = 1790040000;

  /// Um jogo no nível [level] com Ecos da família `soot` de níveis [levels] (uids `e0`, `e1`...).
  GameState make({int level = 6, List<int> levels = const [4, 5, 6, 7, 8], Map<String, int> inv = const {'item.essence.fire': 5}, List<({String? variant, bool shiny})>? looks}) {
    final s = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress, inventory: inv)..levelOverride = level;
    for (var i = 0; i < levels.length; i++) {
      s.collection.add(CreatureInstance(uid: 'e$i', speciesId: 'soot.eco', level: levels[i], capturedUtc: now, variant: looks?[i].variant, shiny: looks?[i].shiny ?? false));
    }
    return s;
  }

  const five = ['e0', 'e1', 'e2', 'e3', 'e4'];

  test('o custo e as regras vêm do balance.json', () {
    final cb = make().cb;
    expect((cb.fusionLevel, cb.fusionEcoCount, cb.fusionEssenceCost, cb.spiritLevelCap, cb.spiritTraitsMax), (6, 5, 5, 30, 2));
  });

  test('funde: gasta 5 Ecos e 5 Essência exatos e entrega o Espírito', () {
    final s = make(inv: {'item.essence.fire': 7, 'item.essence.water': 9});
    final spirit = fuse(s, data, 'soot', five, nowUtc: now)!;
    expect(spirit.speciesId, 'soot.spirit');
    expect(s.collection.map((c) => c.uid), [spirit.uid]);
    expect(s.count('item.essence.fire'), 2, reason: 'gasta exatamente 5');
    expect(s.count('item.essence.water'), 9, reason: 'Essência de outro tipo não é tocada');
    expect(s.conjurer.fusions, 1);
    expect(s.story.count('fusion'), 1);
    expect(s.hasCaptured('soot.spirit'), isTrue);
  });

  test('o nível é a média arredondada dos Ecos', () {
    expect(fusionPlan(make(levels: [4, 5, 6, 7, 8]), data, 'soot', five)!.level, 6);
    expect(fusionPlan(make(levels: [1, 1, 1, 1, 2]), data, 'soot', five)!.level, 1, reason: '1,2 arredonda para 1');
    expect(fusionPlan(make(levels: [1, 1, 2, 2, 2]), data, 'soot', five)!.level, 2, reason: '8/5 = 1,6 arredonda para 2');
    expect(fusionPlan(make(levels: [20, 20, 20, 20, 19]), data, 'soot', five)!.level, 20, reason: '19,8 arredonda para 20');
  });

  test('os traços: Brilhante primeiro, depois variantes distintas, no máximo 2', () {
    final s = make(looks: [
      (variant: 'urban', shiny: false),
      (variant: 'urban', shiny: false),
      (variant: 'green', shiny: false),
      (variant: 'water', shiny: false),
      (variant: null, shiny: true),
    ]);
    expect(fusionPlan(s, data, 'soot', five)!.traits, ['shiny', 'urban']);
    expect(fuse(s, data, 'soot', five, nowUtc: now)!.traits, ['shiny', 'urban']);
    final plain = make(looks: [
      (variant: 'water', shiny: false),
      (variant: null, shiny: false),
      (variant: 'water', shiny: false),
      (variant: 'green', shiny: false),
      (variant: 'urban', shiny: false),
    ]);
    expect(fusionPlan(plain, data, 'soot', five)!.traits, ['water', 'green'], reason: 'distintas, na ordem, teto 2');
    expect(fusionPlan(make(), data, 'soot', five)!.traits, isEmpty);
  });

  test('antes do nível 6 a fusão está bloqueada e nada é gasto', () {
    final s = make(level: 5);
    expect(fusionBlocker(s, data, 'soot', five), FusionBlocker.locked);
    expect(fuse(s, data, 'soot', five, nowUtc: now), isNull);
    expect((s.collection.length, s.count('item.essence.fire')), (5, 5));
  });

  test('inválida: falta Essência, Eco a menos, Eco repetido, de outra família ou inexistente: nada é gasto', () {
    final poor = make(inv: {'item.essence.fire': 4});
    expect(fusionBlocker(poor, data, 'soot', five), FusionBlocker.missingEssence);
    expect(fuse(poor, data, 'soot', five, nowUtc: now), isNull);
    expect(poor.count('item.essence.fire'), 4);
    expect(poor.collection.length, 5);

    final s = make();
    expect(fusionBlocker(s, data, 'soot', five.take(4).toList()), FusionBlocker.wrongCount);
    expect(fusionBlocker(s, data, 'soot', ['e0', 'e0', 'e1', 'e2', 'e3']), FusionBlocker.invalidEco);
    expect(fusionBlocker(s, data, 'soot', ['e0', 'e1', 'e2', 'e3', 'zz']), FusionBlocker.invalidEco);
    expect(fusionBlocker(s, data, 'frond', five), FusionBlocker.invalidEco, reason: 'Ecos de soot não servem a frond');
    expect(fusionBlocker(s, data, 'nada', five), FusionBlocker.unknownFamily);
    expect(fuse(s, data, 'soot', ['e0', 'e0', 'e1', 'e2', 'e3'], nowUtc: now), isNull);
    expect(s.count('item.essence.fire'), 5);
    expect(s.collection.length, 5);
    expect(s.conjurer.fusions, 0);
  });

  test('Eco no Círculo só é consumido depois da confirmação, e o Círculo perde a vaga', () {
    final s = make();
    s.toggleCircle('e1');
    s.toggleCircle('e2');
    expect(fusionPlan(s, data, 'soot', five)!.circleUids, ['e1', 'e2']);
    expect(fusionBlocker(s, data, 'soot', five), FusionBlocker.needsCircleConfirm);
    expect(fuse(s, data, 'soot', five, nowUtc: now), isNull, reason: 'sem confirmar, nada acontece');
    expect((s.collection.length, s.circle.length, s.count('item.essence.fire')), (5, 2, 5));
    final spirit = fuse(s, data, 'soot', five, nowUtc: now, confirmCircle: true)!;
    expect(s.circle, isEmpty);
    expect(s.collection.map((c) => c.uid), [spirit.uid]);
  });

  test('só Ecos da família entram: outras camadas não contam', () {
    final s = make();
    s.collection.add(CreatureInstance(uid: 'sp', speciesId: 'soot.spirit', level: 9, capturedUtc: now));
    expect(fusibleEcos(s, 'soot'), hasLength(5));
    expect(fusionBlocker(s, data, 'soot', ['e0', 'e1', 'e2', 'e3', 'sp']), FusionBlocker.invalidEco);
  });

  test('fusionPossible: nível 6, cinco Ecos de uma família e a Essência', () {
    expect(fusionPossible(make()), isTrue);
    expect(fusionPossible(make(level: 5)), isFalse);
    expect(fusionPossible(make(inv: {'item.essence.fire': 4})), isFalse);
    expect(fusionPossible(make(levels: [3, 3, 3, 3])), isFalse);
  });

  test('o Espírito para no teto de nível 30 e o Eco no 20', () {
    final b = data.progress;
    expect((b.levelCapFor('soot.eco'), b.levelCapFor('soot.spirit'), b.levelCapFor('rill.ritual')), (20, 30, 30));
    var eco = const CreatureInstance(uid: 'a', speciesId: 'soot.eco', level: 19, capturedUtc: now);
    var spirit = const CreatureInstance(uid: 'b', speciesId: 'soot.spirit', level: 19, capturedUtc: now);
    for (var i = 0; i < 1200; i++) {
      eco = withCreatureXp(eco, b);
      spirit = withCreatureXp(spirit, b);
    }
    expect((eco.level, eco.xp), (20, 0));
    expect((spirit.level, spirit.xp), (30, 0));
  });
}
