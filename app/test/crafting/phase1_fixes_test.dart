import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/crafting/bag.dart';
import 'package:kenoma/crafting/collectors.dart';
import 'package:kenoma/crafting/conditions.dart';
import 'package:kenoma/crafting/crafting_state.dart';
import 'package:kenoma/crafting/grimoire.dart';
import 'package:kenoma/crafting/loadout.dart';
import 'package:kenoma/crafting/quality.dart';
import 'package:kenoma/crafting/tutorial.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/ui/craft/bag_screen.dart' show plantedLabel, vesselValidity;
import 'package:kenoma/ui/craft/loadout_screen.dart' show effectText;

import '../support/fixtures.dart';

/// As correções da 0.24.1: a bolsa nunca passa do limite, os caminhos de um item são uma linha só, a quest que ensina o
/// crafting, a validade com o verbo de cada conteúdo, a concordância e os plurais.
void main() {
  final data = loadGameData();
  final book = data.craft;
  const t0 = 1795446000;
  GameState state([Map<String, int> inv = const {}]) => GameState(groupCode: 'KENOMA-TESTE', balance: data.progress, inventory: inv);
  Here here({String climate = 'clear'}) => Here(utc: t0, lat: -22.9, lon: -47.06, sunAltDeg: 40, climate: climate);

  /// O guarda do mapa: o que não cabe é recusado (e contado).
  GameState guarded(Map<String, int> inv, List<int> refused) {
    final s = state(inv);
    s.accept = (key, n) {
      final ok = acceptable(s, book, t0, key, n);
      if (ok < n) refused.add(n - ok);
      return ok;
    };
    return s;
  }

  group('a bolsa nunca passa do limite', () {
    test('acceptableCount: completa a pilha aberta e só abre pilhas novas onde há espaço', () {
      expect(acceptableCount(inventory: {'a': 98}, vesselsInBag: 0, stack: 99, cap: 1, key: 'a', n: 5), 1);
      expect(acceptableCount(inventory: {'a': 98}, vesselsInBag: 0, stack: 99, cap: 2, key: 'a', n: 5), 5);
      expect(acceptableCount(inventory: {'a': 1}, vesselsInBag: 1, stack: 99, cap: 2, key: 'b', n: 5), 0, reason: 'o recipiente guardado ocupa o outro espaço');
      expect(acceptableCount(inventory: {for (var i = 0; i < 63; i++) 'x$i': 1}, vesselsInBag: 0, stack: 99, cap: 40, key: 'y', n: 1), 0, reason: 'save já acima do limite: nada novo entra');
    });

    test('pegar além do limite é recusado com aviso; o que cabe entra', () {
      final refused = <int>[];
      final s = guarded({for (var i = 0; i < 39; i++) 'item.essence.trait.x$i': 1}, refused);
      expect(s.add('item.chalk', 120), 99, reason: 'um espaço livre: uma pilha de 99');
      expect(slotsUsed(s, book), 40);
      expect(s.add('item.herbs', 1), 0);
      expect(refused, [21, 1]);
    });

    test('tirar do loadout, do cinto ou colher não passa do limite: fica onde está', () {
      final refused = <int>[];
      final s = guarded({'item.bag.satchel': 1, 'item.vessel.glass': 2}, refused);
      expect(equip(s, book, LoadoutSlot.bag, 'item.bag.satchel'), isTrue);
      expect(toBelt(s, 'item.vessel.glass', book, t0), isTrue);
      final v = plant(s, 'item.vessel.glass', here(), 1, 2.2, book)!;
      // Enche a bolsa de 60 até o fim.
      for (var i = 0; s.add('item.essence.trait.f$i', 1) == 1; i++) {}
      expect(slotsUsed(s, book), bagCapacity(s, book, t0));
      expect(unequip(s, LoadoutSlot.bag), isFalse, reason: 'sem a bolsa grande o que está nela não caberia');
      expect(s.crafting.equipped[LoadoutSlot.bag], 'item.bag.satchel');
      final belt = s.crafting.at(VesselPlace.belt).single;
      expect(fromBelt(s, belt, book, t0), isFalse);
      expect(belt.place, VesselPlace.belt);
      // Cinto cheio (3) e bolsa cheia: o plantado fica plantado.
      s.crafting.vessels.addAll([Vessel(uid: 90, kind: 'item.vessel.glass', place: VesselPlace.belt), Vessel(uid: 91, kind: 'item.vessel.glass', place: VesselPlace.belt)]);
      expect(harvest(s, v, 5, 30, book, t0), isFalse);
      expect(v.place, VesselPlace.planted);
    });
  });

  test('os caminhos de um mesmo item (.alt) aparecem uma vez só, no melhor grupo', () {
    final s = state({'item.ectoplasm': 4, 'item.essence.fire': 2, 'item.herbs': 1, 'item.pure_water': 1});
    s.crafting.known.addAll(data.recipes.keys);
    s.crafting.pages.addAll(book.pages.keys);
    s.levelOverride = 20;
    final g = groupRecipes(s, data.recipes.values, book, here(), bench: false);
    final outs = [...g.now.map((e) => e.$1.outId), ...g.waiting.map((e) => e.$1.outId), ...g.missing.map((r) => r.outId)];
    expect(outs.toSet().length, outs.length, reason: 'nenhum resultado duas vezes');
    expect(outs.where((o) => o == 'item.amulet.summer.thunder'), hasLength(1));
    final tonic = g.now.where((e) => e.$1.outId == 'item.tonic.focus').single.$1;
    expect(alternativesOf(s, data.recipes.values, tonic).map((r) => r.id), containsAll(['recipe.tonic.focus', 'recipe.tonic.focus.rain']));
  });

  group('a quest que ensina o crafting', () {
    test('começa conhecendo só a garrafa, o frasco escuro, o selo simples e o tônico da chuva; a garrafa é 2 Sucata', () {
      final s = state();
      expect({for (final r in data.recipes.values) if (isKnown(s, r)) r.id}, {'recipe.vessel.glass', 'recipe.vessel.dark', 'recipe.seal.simple', 'recipe.tonic.focus.rain'});
      expect(data.recipes['recipe.vessel.glass']!.inputs, {'item.scrap': 2});
      final withScrap = state({'item.scrap': 2});
      final g = groupRecipes(withScrap, data.recipes.values, book, here(), bench: false);
      expect(g.now.map((e) => e.$1.id), contains('recipe.vessel.glass'), reason: 'com Sucata, a garrafa está em "pode fazer agora"');
    });

    test('a primeira Sucata liga a quest; cada passo solta a mensagem do mentor, em ordem, e a quest acaba', () {
      final s = state();
      expect(currentStep(s), isNull);
      s.add('item.scrap', 2);
      expect((s.crafting.tutorial, s.story.count('craft_tut_start')), (CraftTutorial.on, 1));
      expect(currentStep(s), TutStep.bottle);
      expect(craftAt(s, data.recipes['recipe.vessel.glass']!, book, here()), Quality.common);
      syncTutorial(s);
      expect((currentStep(s), s.story.count('craft_tut_bottle')), (TutStep.belt, 1));
      expect(toBelt(s, 'item.vessel.glass', book, t0), isTrue);
      syncTutorial(s);
      expect(currentStep(s), TutStep.fill);
      tickBelt(s, here(climate: 'rain'), 400, book);
      s.recordEvent('vessel_filled', 'item.rain_water', 1); // o passo do mapa conta isso (collector_tick)
      syncTutorial(s);
      expect(currentStep(s), TutStep.use);
      s.add('item.herbs', 1);
      expect(craftAt(s, data.recipes['recipe.tonic.focus.rain']!, book, here()), isNotNull);
      syncTutorial(s);
      expect((s.crafting.tutorial, currentStep(s), s.story.count('craft_tut_done')), (CraftTutorial.done, null, 1));
      expect(s.crafting.at(VesselPlace.belt).single.empty, isTrue, reason: 'a garrafa continua no cinto, vazia');
    });

    test('plantar vale como o passo de encher quando não chove', () {
      final s = state()..add('item.scrap', 2);
      craftAt(s, data.recipes['recipe.vessel.glass']!, book, here());
      plant(s, 'item.vessel.glass', here(), 1, 2.2, book);
      expect(currentStep(s), TutStep.use);
    });

    test('o mentor dá a primeira garrafa a quem abre Condições sem nenhuma, uma vez, e liga a quest', () {
      final s = state();
      expect(giveFirstBottle(s, t0), isTrue);
      expect((s.count('item.vessel.glass'), s.crafting.gift, s.crafting.tutorial), (1, true, CraftTutorial.on));
      expect(s.story.chat.delivered.last.id, 'craft_tut_gift');
      expect(currentStep(s), TutStep.belt, reason: 'o presente vale como o passo da garrafa');
      s.spend({'item.vessel.glass': 1});
      expect(giveFirstBottle(s, t0), isFalse, reason: 'uma vez só');
      final has = state({'item.vessel.dark': 1});
      expect(giveFirstBottle(has, t0), isFalse, reason: 'quem tem recipiente não ganha');
    });
  });

  test('a validade diz o verbo de cada conteúdo, e o que não estraga diz isso', () {
    final snow = Vessel(uid: 1, kind: 'item.vessel.glass', place: VesselPlace.bag, content: 'item.snow', filledUtc: t0);
    final thermal = Vessel(uid: 2, kind: 'item.vessel.thermal', place: VesselPlace.bag, content: 'item.snow', filledUtc: t0);
    final rain = Vessel(uid: 3, kind: 'item.vessel.glass', place: VesselPlace.bag, content: 'item.rain_water', filledUtc: t0);
    expect(vesselValidity(snow, book, t0 + 3600)!.text, startsWith('DERRETE EM'));
    expect(vesselValidity(snow, book, t0 + 60 * 3600), (text: 'DERRETE EM 12 H', soon: true));
    expect(vesselValidity(thermal, book, t0)!.text, 'NÃO DERRETE');
    expect(vesselValidity(rain, book, t0), (text: 'NÃO ESTRAGA', soon: false));
  });

  test('concordância e plurais', () {
    expect(Quality.values.map((q) => q.phrase), ['qualidade comum', 'qualidade boa', 'qualidade perfeita']);
    expect(plantedLabel(PlantedState.full, book.items['item.vessel.glass']), 'CHEIA');
    expect(plantedLabel(PlantedState.full, book.items['item.vessel.dark']), 'CHEIO');
    final v = Vessel(uid: 1, kind: 'item.vessel.glass', place: VesselPlace.belt, content: 'item.rain_water', quality: Quality.good);
    expect(vesselFullText(v, book), 'Garrafa de vidro cheia: Água de chuva, qualidade boa');
    expect(effectText('belt_slots', 1), '+1 garrafa no cinto');
    expect(effectText('belt_slots', 2), '+2 garrafas no cinto');
    expect(effectText('planted_slots', 1), '+1 coletor plantado');
    expect(effectText('bag_slots', 20), '+20 espaços na bolsa');
  });
}
