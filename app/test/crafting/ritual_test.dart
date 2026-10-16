import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/astro.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/core/weather.dart';
import 'package:kenoma/crafting/ritual.dart';
import 'package:kenoma/crafting/ritual_data.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/story/chat_state.dart';
import 'package:kenoma/story/mentor_script.dart';
import 'package:kenoma/ui/ritual/ritual_text.dart';
import 'package:kenoma/world/debug_force.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/world_view.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();
  final soot = data.ritual.of('soot.ritual')!; // fogo: hora 18 a 23; Círculo de Água nível 5+
  const uid = 4242;
  const now = 1790040000;
  const evening = WorldCondition(hour: 20, biome: 'urban', moon: MoonPhase.newMoon, weather: Weather.clear);

  GameState make({int level = 8, bool give = true}) {
    final s = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress)..levelOverride = level;
    if (give) {
      for (final m in soot.materials) {
        s.add(m.item, m.qty);
      }
    }
    s.collection.addAll([
      CreatureInstance(uid: 'water', speciesId: 'rill.eco', level: 6, capturedUtc: 1),
      CreatureInstance(uid: 'weak', speciesId: 'rill.eco', level: 2, capturedUtc: 1),
      CreatureInstance(uid: 'plant', speciesId: 'frond.eco', level: 9, capturedUtc: 1),
    ]);
    for (final u in ['water', 'weak', 'plant']) {
      s.toggleCircle(u);
    }
    return s;
  }

  List<PlacedMaterial?> right() => [for (final m in soot.materials) PlacedMaterial(m.item, m.qty)];

  RitualOutcome run(GameState s, {List<PlacedMaterial?>? materials, String? circle = 'water', WorldCondition world = evening}) => performRitual(
        state: s,
        data: data,
        recipe: soot,
        attempt: RitualAttempt(materials: materials ?? right(), circleUid: circle, world: world),
        uid: uid,
        level: 9,
        nowUtc: now,
      );

  group('combinação certa', () {
    test('sela: entra na coleção no nível do spawn e no bestiário, gasta os materiais e revela a receita', () {
      final s = make();
      final out = run(s);
      expect(out.status, RitualStatus.success);
      expect(out.misses, isEmpty);
      final c = s.collection.firstWhere((c) => c.speciesId == 'soot.ritual');
      expect((c.level, c.uid), (9, '4242'));
      expect(s.bestiary['soot.ritual']!.captured, isTrue);
      expect(s.isDone(uid), isTrue);
      for (final m in soot.materials) {
        expect(s.count(m.item), 0, reason: m.item);
      }
      expect(s.conjurer.ritualResearch['soot.ritual'], soot.slotCount);
      expect(s.story.count('ritual_done'), 1);
      expect(s.progress.xp > 0 || s.progress.level > 1, isTrue, reason: 'ganha XP de captura');
    });
  });

  group('combinação errada: a criatura foge e os materiais se perdem', () {
    void expectFled(GameState s, RitualOutcome out, Set<RitualMiss> misses) {
      expect(out.status, RitualStatus.wrong);
      expect(out.misses, misses);
      expect(s.collection.any((c) => c.speciesId == 'soot.ritual'), isFalse);
      expect(s.isDone(uid), isTrue, reason: 'a fuga entra no registro de feitos');
      expect(s.hasCaptured('soot.ritual'), isFalse);
      for (final m in soot.materials) {
        expect(s.count(m.item), 0, reason: 'perdeu ${m.item}');
      }
    }

    test('material errado', () {
      final s = make();
      s.add('item.herbs', 1);
      final m = right()..[0] = const PlacedMaterial('item.herbs', 1);
      final out = run(s, materials: m);
      expect(out.misses, {RitualMiss.material});
      expect(out.status, RitualStatus.wrong);
      expect(s.count('item.herbs'), 0);
      expect(s.isDone(uid), isTrue);
      expect(s.count('item.essence.fire'), 0);
    });

    test('espaço vazio conta como material errado (só se perde o que foi colocado)', () {
      final s = make();
      final out = run(s, materials: right()..[2] = null);
      expect(out.misses, {RitualMiss.material});
      expect(out.status, RitualStatus.wrong);
      expect(s.count('item.chalk'), 1);
      expect(s.count('item.scrap'), 0);
      expect(s.isDone(uid), isTrue);
    });

    test('quantidade errada', () {
      final s = make();
      s.add('item.scrap', 1);
      final m = right()..[0] = const PlacedMaterial('item.scrap', 3);
      final out = run(s, materials: m);
      expect(out.misses, {RitualMiss.quantity});
      expect(s.count('item.scrap'), 0);
      expect(s.isDone(uid), isTrue);
    });

    test('condição errada', () {
      final s = make();
      expectFled(s, run(s, world: evening.copyWith(hour: 10)), {RitualMiss.condition});
    });

    test('Círculo errado: tipo fraco, nível baixo ou nenhuma criatura', () {
      var s = make();
      expectFled(s, run(s, circle: 'plant'), {RitualMiss.circle});
      s = make();
      expectFled(s, run(s, circle: 'weak'), {RitualMiss.circle});
      s = make();
      expectFled(s, run(s, circle: null), {RitualMiss.circle});
    });

    test('vários erros juntos aparecem todos (só para teste)', () {
      final s = make();
      expectFled(s, run(s, circle: 'plant', world: evening.copyWith(hour: 3)), {RitualMiss.condition, RitualMiss.circle});
    });
  });

  group('bloqueado: nada é gasto', () {
    test('abaixo do nível 8', () {
      final s = make(level: 7);
      final out = run(s);
      expect(out.status, RitualStatus.blocked);
      expect(out.blockedReason, contains('8'));
      expect(s.count('item.scrap'), 2);
      expect(s.isDone(uid), isFalse);
    });

    test('falta material na Bolsa', () {
      final s = make(give: false);
      s.add('item.scrap', 1);
      final out = run(s);
      expect(out.status, RitualStatus.blocked);
      expect(s.count('item.scrap'), 1);
      expect(s.isDone(uid), isFalse);
    });

    test('criatura que não está no Círculo', () {
      final s = make();
      s.circle.remove('water');
      expect(run(s).status, RitualStatus.blocked);
      expect(s.count('item.scrap'), 2);
    });
  });

  group('condição do mundo com instantes fixos', () {
    test('hora local [de, até) e a virada da meia-noite', () {
      final hour = soot.condition;
      expect([for (final h in [17, 18, 22, 23]) hour.holds(evening.copyWith(hour: h))], [false, true, true, false]);
      const night = RitualCondition(kind: ConditionKind.hour, from: 22, to: 4);
      expect([for (final h in [21, 22, 23, 0, 3, 4]) night.holds(evening.copyWith(hour: h))], [false, true, true, true, true, false]);
    });

    test('hora vem do relógio em UTC e só a exibição converte para o fuso', () {
      final utc = DateTime.utc(2026, 10, 16, 22).millisecondsSinceEpoch ~/ 1000;
      expect(localHourOf(utc, offset: const Duration(hours: -3)), 19);
      expect(localHourOf(utc, offset: Duration.zero), 22);
      expect(localHourOf(utc, offset: const Duration(hours: 3)), 1);
    });

    test('bioma, lua e clima', () {
      const biome = RitualCondition(kind: ConditionKind.biome, value: 'green');
      expect([biome.holds(evening.copyWith(biome: 'green')), biome.holds(evening)], [true, false]);
      final moon = data.ritual.of('rill.ritual')!.condition;
      final full = DateTime.utc(2026, 9, 26, 16, 49).millisecondsSinceEpoch ~/ 1000;
      expect(moon.holds(evening.copyWith(moon: moonPhase(full))), isTrue);
      expect(moon.holds(evening.copyWith(moon: moonPhase(full + 14 * 86400))), isFalse);
      const rain = RitualCondition(kind: ConditionKind.weather, value: 'rain');
      expect([rain.holds(evening.copyWith(weather: Weather.rain)), rain.holds(evening)], [true, false]);
    });

    test('satisfying() monta um mundo que satisfaz a condição', () {
      for (final r in data.ritual.recipes.values) {
        expect(r.condition.holds(r.condition.satisfying(evening)), isTrue, reason: r.speciesId);
      }
    });
  });

  group('pesquisa e espaços ???', () {
    test('cada Eco diferente revela um espaço, na ordem condição, materiais, Círculo; o mesmo Eco não conta duas vezes', () {
      final s = make();
      final seen = <int>{};
      String slot(int i) => ritualSlotText(soot, i, ritualRevealed(s, soot), data.species('soot.ritual')!.type, data.itemName);
      expect([for (var i = 0; i < soot.slotCount; i++) slot(i)], List.filled(soot.slotCount, '???'));
      noteRitualSighting(s, data.ritual, 1, 'soot.ritual', seen);
      noteRitualSighting(s, data.ritual, 1, 'soot.ritual', seen);
      expect(ritualRevealed(s, soot), 1);
      expect(slot(0), 'Entre 18h e 23h');
      expect(slot(1), '???');
      noteRitualSighting(s, data.ritual, 2, 'soot.ritual', seen);
      expect(slot(1), '2× Sucata');
      for (var u = 3; u < 10; u++) {
        noteRitualSighting(s, data.ritual, u, 'soot.ritual', seen);
      }
      expect(ritualRevealed(s, soot), soot.slotCount, reason: 'não passa do total');
      expect(slot(soot.circleIndex), 'Criatura de Água, nível 5+');
    });

    test('o primeiro avistamento da família solta o evento da dica do mentor, uma vez', () {
      final s = make();
      noteRitualSighting(s, data.ritual, 1, 'soot.ritual', {});
      noteRitualSighting(s, data.ritual, 2, 'soot.ritual', {});
      expect(s.story.count('ritual_seen_soot'), 1);
      expect(s.story.count('ritual_seen_frond'), 0);
    });

    test('a bolinha do Bestiário acende ao revelar e apaga ao ver', () {
      final s = make();
      expect(ritualResearchUnseen(s), isFalse);
      noteRitualSighting(s, data.ritual, 1, 'soot.ritual', {});
      expect(ritualResearchUnseen(s), isTrue);
      markRitualViewed(s, 'soot.ritual');
      expect(ritualResearchUnseen(s), isFalse);
    });

    test('syncRitualUnlock solta o evento só a partir do nível 8, uma vez', () {
      final low = make(level: 7);
      syncRitualUnlock(low);
      expect(low.story.count('ritual_unlocked'), 0);
      final s = make();
      syncRitualUnlock(s);
      syncRitualUnlock(s);
      expect(s.story.count('ritual_unlocked'), 1);
    });
  });

  group('mentor', () {
    final script = MentorScript.fromJson(loadJson('assets/data/mentor.json'));

    test('as mensagens ritual_* saem pelo evento, sem esperar a fila do tutorial, do mentor; o Familiar fala no primeiro selo', () {
      final chat = ChatState();
      final events = <String, int>{};
      int count(String e) => events[e] ?? 0;
      expect(chat.deliverEvents(1, script, count), isEmpty);
      events['ritual_unlocked'] = 1;
      events['ritual_seen_frond'] = 1;
      final out = chat.deliverEvents(2, script, count);
      expect(out.map((m) => m.id), ['ritual_teach', 'ritual_hint_frond']);
      expect(out.every((m) => m.from == 'mentor'), isTrue);
      expect(script.familiar.any((m) => m.id.startsWith('ritual_')), isFalse);
      expect(chat.mentorDelivered(script), 0, reason: 'não entram na fila do tutorial');
      events['ritual_done'] = 1;
      final first = chat.deliverEvents(3, script, count).singleWhere((m) => m.id == 'ritual_first');
      expect(first.from, 'familiar');
      expect(first.text, startsWith('*'));
      expect(chat.deliverEvents(4, script, count), isEmpty, reason: 'uma vez cada');
    });

    test('os textos batem com o docs/textos-mentor.md (rode scripts/mentor_md.py)', () {
      final md = File('../docs/textos-mentor.md').readAsStringSync();
      expect(script.events, hasLength(5));
      for (final m in script.events) {
        expect(md, contains(m.text), reason: m.id);
        expect(m.text.length, lessThan(320), reason: m.id);
      }
    });

    test('uma dica por família, cada uma no evento da própria família', () {
      for (final f in ['soot', 'frond', 'rill']) {
        expect(script.byId('ritual_hint_$f')?.requires?.event, 'ritual_seen_$f');
      }
    });
  });

  group('dados consistentes', () {
    final creatures = loadJson('assets/data/creatures.json');
    final items = {for (final i in loadJson('assets/data/items.json')['items'] as List<dynamic>) (i as Map<String, dynamic>)['id'] as String};
    final biomeKeys = {for (final b in loadJson('assets/data/biomes.json')['biomes'] as List<dynamic>) (b as Map<String, dynamic>)['key'] as String};
    final ritualOnly = {for (final s in creatures['species'] as List<dynamic>) if ((s as Map<String, dynamic>)['ritual_only'] == true) s['id'] as String};

    test('toda espécie ritual_only tem uma receita e toda receita é de uma espécie ritual_only', () {
      expect(data.ritual.recipes.keys.toSet(), ritualOnly);
      expect(ritualOnly, isNotEmpty);
    });

    test('todos os ids de itens, biomas, fases e climas existem', () {
      for (final r in data.ritual.recipes.values) {
        for (final m in r.materials) {
          expect(items, contains(m.item), reason: r.speciesId);
          expect(m.qty, inInclusiveRange(1, data.ritual.balance.materialMaxQty));
        }
        switch (r.condition.kind) {
          case ConditionKind.biome:
            expect(biomeKeys, contains(r.condition.value));
          case ConditionKind.moon:
            expect(MoonPhase.values.map((p) => p.name), contains(r.condition.value));
          case ConditionKind.weather:
            expect(Weather.values.map((w) => w.id), contains(r.condition.value));
          case ConditionKind.hour:
            expect(r.condition.from, inInclusiveRange(0, 23));
            expect(r.condition.to, inInclusiveRange(0, 24));
        }
        expect(r.circleMinLevel, inInclusiveRange(1, 20));
      }
    });

    test('cada família tem uma receita diferente e há um espaço só para o Círculo', () {
      final texts = {for (final r in data.ritual.recipes.values) '${r.condition.kind}${r.condition.value}${r.materials.map((m) => m.item)}'};
      expect(texts.length, data.ritual.recipes.length);
      for (final r in data.ritual.recipes.values) {
        expect(r.slotCount, r.materials.length + 2);
        expect(r.circleIndex, r.slotCount - 1);
      }
    });
  });

  group('no mapa (WorldView)', () {
    const t0 = 1790035200 + 86400;
    final (lat, lon) = kCentroCampinas;

    (WorldView, GameState, DebugForce) view() {
      final state = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress)..levelOverride = 8;
      final force = DebugForce();
      final v = WorldView(
        field: SpawnField(seed: seedGlobal('KENOMA-TESTE'), schedule: loadEpochs(), map: RegionMap(pack: loadCampinasPack(), biomes: loadBiomes())),
        state: state,
        auraM: 40,
        viewM: 120,
        itemName: (id) => id,
        street: loadStreetBalance(),
        force: force,
        ritual: data.ritual,
      );
      return (v, state, force);
    }

    test('Eco de ritual a até 30 m: TouchResult.ritual e o gancho; mais longe, não', () {
      final (probe, _, _) = view();
      final eco = probe.field.around(lat: lat, lon: lon, tUtc: t0, radiusM: 400, playerLevel: 8).firstWhere((s) => s.isEco);
      final (la, lo) = tileFractionToLatLon(eco.x, eco.y, biomeZoom);
      final ritualEco = eco.withTraits(behavior: eco.behavior, shiny: false, entryId: 'soot.ritual');
      final (v, _, _) = view();
      final hooked = <int>[];
      v.onRitualTarget = (e) => hooked.add(e.uid);
      v.refresh(lat: la, lon: lo, tUtc: t0);
      expect(v.touch(ritualEco, t0), TouchResult.ritual);
      expect(hooked, [eco.uid]);
      final (v2, _, _) = view();
      v2.refresh(lat: lat, lon: lon, tUtc: t0);
      final far = ritualEco.withTraits(behavior: eco.behavior, shiny: false); // longe do jogador
      if (v2.distanceM(far) > 30) expect(v2.touch(far, t0), TouchResult.tooFar);
    });

    test('o debug força o próximo Eco novo a ser o de ritual, e vê-lo revela um espaço', () {
      final (v, state, force) = view();
      force.set(ritual: true);
      final probe = view().$1.field.around(lat: lat, lon: lon, tUtc: t0, radiusM: 400, playerLevel: 8).firstWhere((s) => s.isEco);
      final (la, lo) = tileFractionToLatLon(probe.x, probe.y, biomeZoom);
      v.refresh(lat: la, lon: lo, tUtc: t0);
      final forced = v.spawns.where((s) => s.entryId.endsWith('.ritual')).toList();
      expect(forced, hasLength(1));
      expect(force.nextRitual, isFalse, reason: 'gasta o pedido');
      expect(state.conjurer.ritualResearch[forced.first.entryId], 1);
    });
  });
}
