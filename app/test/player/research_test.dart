import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/player/bestiary.dart';
import 'package:kenoma/player/bestiary_view.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/player/research.dart';
import 'package:kenoma/ui/type_label.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();
  GameState state() => GameState(groupCode: 'KENOMA-TESTE', balance: data.progress);
  String label(String type) => typeLabel(EcoType.parse(type));
  const t = 1800000000;

  group('dados', () {
    test('doze famílias, cada uma com Fagulha, Eco e Espírito; texto e cinco tarefas para cada Eco e Espírito', () {
      expect(data.families.map((f) => f.id), ['soot', 'frond', 'rill', 'hum', 'clod', 'rust', 'glare', 'shade', 'wisp', 'bit', 'sprig', 'wyrm']);
      for (final f in data.families) {
        expect(data.itemNames.containsKey(f.sparkItem), isTrue, reason: f.sparkItem);
        expect(f.sparkItem, 'item.dust.${f.type}');
        expect(f.where.keys, containsAll(['biome', 'hour', 'climate', 'moon']), reason: f.id);
        for (final id in [f.ecoId, f.spiritId]) {
          expect(data.species(id), isNotNull, reason: id);
          expect(data.species(id)!.type.name, f.type, reason: id);
          final lore = data.lore[id]!;
          expect(lore.lore, hasLength(3), reason: id);
          expect(lore.about, isNotEmpty);
          expect(lore.research.map((r) => r.unlocks), ['lore1', 'where', 'attributes', 'tolerance', 'lore3'], reason: id);
        }
      }
      expect(data.families.firstWhere((f) => f.id == 'wyrm').minLevel, 10);
      expect(bestiaryForms(data), hasLength(12 * 3 + 3), reason: '36 formas e os três Espíritos de ritual do MVP');
      expect(bestiaryForms(data).map((f) => f.number), [for (var i = 1; i <= 39; i++) i]);
    });

    test('toda habilidade de mapa das espécies tem texto', () {
      for (final s in data.tuning.species) {
        final a = s.ability;
        if (a == null) continue;
        expect(a.bands, hasLength(3), reason: s.id);
        expect(data.lore[s.id], isNotNull);
      }
    });
  });

  group('pesquisa', () {
    test('cada tarefa feita, na ordem, sobe um nível: capturar, ver à noite, dois biomas, variante, cinco capturas', () {
      final s = state();
      final tasks = data.lore['hum.eco']!.research;
      int level() => researchLevel(tasks, 'hum.eco', s.bestiary);
      expect(level(), 0);
      s.markSeen('hum.eco', tags: seenTags(sunAltDeg: 30, climate: 'clear'));
      expect(level(), 0, reason: 'ver não é capturar');
      s.capture(uid: 1, speciesId: 'hum.eco', level: 3, nowUtc: t, biome: 'urban');
      expect(level(), 1);
      expect(researchUnlocks(tasks, 'hum.eco', s.bestiary), {'lore1'});
      s.markSeen('hum.eco', tags: seenTags(sunAltDeg: -30, climate: 'storm'));
      expect(level(), 2, reason: 'vista de noite');
      expect(s.bestiary['hum.eco']!.when, {'day', 'night', 'climate:clear', 'climate:storm'});
      s.capture(uid: 2, speciesId: 'hum.eco', level: 3, nowUtc: t, biome: 'urban');
      expect(taskProgress(tasks[2], 'hum.eco', s.bestiary), 1, reason: 'o mesmo bioma duas vezes conta um');
      s.capture(uid: 3, speciesId: 'hum.eco', level: 3, nowUtc: t, biome: 'lit');
      expect(level(), 3);
      expect(researchUnlocks(tasks, 'hum.eco', s.bestiary), {'lore1', 'where', 'attributes'});
      s.markSeen('hum.eco', variant: 'urban');
      expect(level(), 4);
      expect(data.researchToleranceMult(s.bestiary, 'hum.eco'), 1.05, reason: 'o nível 4 dá o bônus de tolerância');
      expect(data.researchToleranceMult(s.bestiary, 'soot.eco'), 1);
      expect(taskProgress(tasks[4], 'hum.eco', s.bestiary), 3);
      s.capture(uid: 4, speciesId: 'hum.eco', level: 3, nowUtc: t);
      s.capture(uid: 5, speciesId: 'hum.eco', level: 3, nowUtc: t);
      expect(level(), 5);
    });

    test('as tarefas de ver: crepúsculo, neblina, dia e noite, eclipse', () {
      final b = <String, BestiaryEntry>{};
      ResearchTask see(String id) => data.lore[id]!.research[1];
      void seen(String id, Set<String> when) => b[id] = BestiaryEntry(seen: true, when: when);
      seen('sprig.eco', {'day', 'night'});
      expect(taskProgress(see('sprig.eco'), 'sprig.eco', b), 0);
      seen('sprig.eco', {'twilight'});
      expect(taskProgress(see('sprig.eco'), 'sprig.eco', b), 1);
      seen('wisp.eco', {'day', 'climate:rain'});
      expect(taskProgress(see('wisp.eco'), 'wisp.eco', b), 0);
      seen('wisp.eco', {'day', 'climate:fog'});
      expect(taskProgress(see('wisp.eco'), 'wisp.eco', b), 1);
      seen('clod.eco', {'day'});
      expect(taskProgress(see('clod.eco'), 'clod.eco', b), 0, reason: 'precisa dos dois');
      seen('clod.eco', {'day', 'night'});
      expect(taskProgress(see('clod.eco'), 'clod.eco', b), 1);
      seen('wyrm.eco', {'night', 'climate:crimson_rain'});
      expect(taskProgress(see('wyrm.eco'), 'wyrm.eco', b), 1);
      expect(seenTags(sunAltDeg: 5.9), {'twilight'});
      expect(seenTags(sunAltDeg: -5.9), {'twilight'});
      expect(seenTags(sunAltDeg: 6, climate: 'fog'), {'day', 'climate:fog'});
      expect(seenTags(sunAltDeg: -6), {'night'});
    });
  });

  group('estados do Bestiário', () {
    test('capturada, vista e ???; a família fica "???" até a primeira forma aparecer', () {
      final s = state();
      final hum = data.families.firstWhere((f) => f.id == 'hum');
      expect(familyKnown(hum, data, s.bestiary), isFalse);
      expect([for (final f in familyForms(hum, data, 1)) formState(f.id, s.bestiary)], [FormStatus.unknown, FormStatus.unknown, FormStatus.unknown]);
      s.markSeen('hum.spirit');
      expect(familyKnown(hum, data, s.bestiary), isTrue);
      s.add('item.dust.electric', 2);
      s.capture(uid: 1, speciesId: 'hum.eco', level: 2, nowUtc: t);
      expect([for (final f in familyForms(hum, data, 1)) formState(f.id, s.bestiary)], [FormStatus.captured, FormStatus.captured, FormStatus.seen]);
      expect(s.bestiary['item.dust.electric']!.captures, 2, reason: 'a Fagulha coletada entra no Bestiário');
      expect(familyKnown(data.families.firstWhere((f) => f.id == 'wyrm'), data, s.bestiary), isFalse);
    });

    test('as formas de uma família do MVP incluem o Espírito de ritual; as novas têm três', () {
      expect(familyForms(data.families.first, data, 1).map((f) => (f.layer, f.id, f.spriteKey)), [
        (FormLayer.spark, 'item.dust.fire', 'soot.mote'),
        (FormLayer.eco, 'soot.eco', 'soot.eco'),
        (FormLayer.spirit, 'soot.spirit', 'soot.spirit'),
        (FormLayer.ritual, 'soot.ritual', 'soot.ritual'),
      ]);
      expect(familyForms(data.families[3], data, 1).map((f) => f.name), ['Arc Mote', 'Humoth', 'Coilkin']);
    });

    test('a pesquisa em porcentagem: níveis feitos sobre os que existem', () {
      final s = state();
      final hum = data.families.firstWhere((f) => f.id == 'hum');
      expect((familyPercent(hum, data, s.bestiary), bestiaryPercent(data, s.bestiary)), (0, 0));
      s.add('item.dust.electric', 1);
      expect(familyPercent(hum, data, s.bestiary), (100 * 1 / 11).floor());
      s.capture(uid: 1, speciesId: 'hum.eco', level: 2, nowUtc: t);
      expect(familyPercent(hum, data, s.bestiary), (100 * 2 / 11).floor());
      expect(bestiaryPercent(data, s.bestiary), greaterThan(0));
    });
  });

  group('filtro e busca', () {
    final s = state()
      ..capture(uid: 1, speciesId: 'hum.eco', level: 2, nowUtc: t, biome: 'urban')
      ..markSeen('clod.eco')
      ..add('item.dust.fire', 1);
    List<String> ids(BestiaryFilter f) => [for (final x in bestiaryForms(data)) if (f.matches(x, data, s.bestiary, label)) x.id];

    test('sem filtro passa tudo; por tipo, camada e estado', () {
      expect(ids(const BestiaryFilter()), hasLength(39));
      expect(ids(const BestiaryFilter(types: {'electric'})), ['item.dust.electric', 'hum.eco', 'hum.spirit']);
      expect(ids(const BestiaryFilter(types: {'electric', 'earth'}, layers: {FormLayer.eco})), ['hum.eco', 'clod.eco']);
      expect(ids(const BestiaryFilter(states: {FormStatus.captured})), ['item.dust.fire', 'hum.eco']);
      expect(ids(const BestiaryFilter(states: {FormStatus.seen})), ['clod.eco']);
      expect(ids(const BestiaryFilter(states: {FormStatus.unknown}, layers: {FormLayer.spark})), hasLength(11));
      expect(const BestiaryFilter().isEmpty, isTrue);
      expect(const BestiaryFilter(layers: {FormLayer.eco}).isEmpty, isFalse);
    });

    test('só pesquisa incompleta: sai quem já fez tudo', () {
      expect(ids(const BestiaryFilter(incompleteOnly: true, layers: {FormLayer.spark})), isNot(contains('item.dust.fire')));
      expect(ids(const BestiaryFilter(incompleteOnly: true)), contains('hum.eco'));
    });

    test('busca por nome, tipo e lugar, sem ligar para maiúscula ou acento; o que nunca foi visto não se acha pelo nome', () {
      expect(ids(const BestiaryFilter(query: 'humo')), ['hum.eco']);
      expect(ids(const BestiaryFilter(query: 'ELETRICO')), ['hum.eco']);
      expect(ids(const BestiaryFilter(query: 'elétrico')), ['hum.eco']);
      expect(ids(const BestiaryFilter(query: 'morros')), ['clod.eco'], reason: 'o lugar da família Clod');
      expect(ids(const BestiaryFilter(query: 'noite')), ['hum.eco']);
      expect(ids(const BestiaryFilter(query: 'coilkin')), isEmpty, reason: 'o Espírito ainda é ???');
      expect(ids(const BestiaryFilter(query: 'wyrm')), isEmpty);
      expect(ids(const BestiaryFilter(query: 'hum')), ['item.dust.electric', 'hum.eco', 'hum.spirit'], reason: 'o nome da família, já conhecida, acha a linha toda');
      expect(ids(const BestiaryFilter(query: 'fagulha')), ['item.dust.fire']);
    });
  });

  group('bolinhas de variante', () {
    test('a comum, as de bioma, a Brilhante e a Carmesim: capturada, vista ou desconhecida', () {
      final s = state()
        ..markSeen('soot.eco', variant: 'urban')
        ..capture(uid: 5, speciesId: 'soot.eco', level: 3, nowUtc: t, variant: 'green')
        ..markSeen('soot.eco', shiny: true);
      final dots = {for (final d in variantDots('soot.eco', data, s.bestiary)) d.key: d.state};
      expect(dots.keys, ['', 'urban', 'green', 'water', 'residential', 'lit', 'sacred', 'shiny', 'crimson']);
      expect(dots[''], FormStatus.captured);
      expect(dots['urban'], FormStatus.seen);
      expect(dots['green'], FormStatus.captured);
      expect(dots['shiny'], FormStatus.seen);
      expect([dots['water'], dots['residential'], dots['lit'], dots['sacred'], dots['crimson']], everyElement(FormStatus.unknown));
      expect(variantDots('frond.eco', data, s.bestiary).every((d) => d.state == FormStatus.unknown), isTrue);
    });
  });

  test('marcar formas: até 3, a quarta é recusada, marcar de novo desmarca, e vai para o save', () {
    final s = state();
    for (final id in ['hum.eco', 'clod.eco', 'wisp.eco']) {
      expect(s.togglePin(id), isTrue);
    }
    expect(s.togglePin('bit.eco'), isFalse);
    expect(s.pins, ['hum.eco', 'clod.eco', 'wisp.eco']);
    expect(GameState.fromJson(s.toJson(t), data.progress).pins, ['hum.eco', 'clod.eco', 'wisp.eco']);
    expect(s.togglePin('clod.eco'), isTrue);
    expect(s.pins, ['hum.eco', 'wisp.eco']);
    expect(s.togglePin('bit.eco'), isTrue);
    expect(s.isPinned('bit.eco'), isTrue);
  });
}
