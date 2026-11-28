import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/astro.dart' show moonPhase;
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/high_tiers_model.dart';
import 'package:kenoma/core/weather.dart';
import 'package:kenoma/crafting/ritual_data.dart';
import 'package:kenoma/world/high_tiers.dart';
import 'package:kenoma/world/climate_world.dart';
import 'package:kenoma/world/high_tiers_driver.dart';

import '../support/fixtures.dart';

/// 0.27.0: a Entidade Maior solta e o Arquétipo no auge dos eventos, num mundo fixo: seed, época, relógio e um clima
/// determinístico de mentira por célula e hora; as condições são as receitas de verdade do `rituals.json`.
void main() {
  final data = loadGameData();
  final model = data.schedule.epochs.last.highTiers!;
  const seed = 0x4b454e4f4d41, epoch = 12, offset = Duration(hours: -3);
  const t0 = 1795000000; // 2026-11-18
  const area = (x0: 776000, y0: 1104000, w: 400, h: 400);
  final families = [for (final id in data.ritual.recipes.keys) if (id.endsWith('.ritual')) id.split('.').first];

  /// O mundo fixo: o bioma pela célula e o clima (com um evento às vezes) pela região de 32 células e a hora.
  WorldCondition worldAt(int cx, int cy, int t) {
    final h = fnv1a64([cx >> 5, cy >> 5, t ~/ 3600]);
    const climates = ['clear', 'cloudy', 'rain', 'storm', 'fog', 'smog', 'dry_dust', 'strong_sun', 'static', 'black_sun', 'meteor_shower', 'fog_procession'];
    final c = climates[hashMod(h, climates.length)];
    const biomes = ['urban', 'green', 'water', 'residential', 'lit', 'sacred'];
    return WorldCondition(
      hour: localHourOf(t, offset: offset),
      biome: biomes[hashMod(fnv1a64([cx, cy]), biomes.length)],
      moon: moonPhase(t),
      weather: Weather.parse(const {'rain': 'rain', 'storm': 'storm', 'cloudy': 'cloudy'}[c] ?? 'clear'),
      climates: {c},
      sunAltDeg: (localHourOf(t, offset: offset) - 12).abs() < 6 ? 40 : (localHourOf(t, offset: offset) == 6 || localHourOf(t, offset: offset) == 18 ? 2 : -30),
    );
  }

  bool holds(String family, int cx, int cy, int t) => data.ritual.of('$family.ritual')!.condition.holds(worldAt(cx, cy, t));

  List<MajorSighting> sightings({int s = seed, String region = 'campinas', FamilyConditionAt? h}) =>
      majorSightings(seed: s, epochId: epoch, m: model, region: region, area: area, families: families, tUtc: t0, holds: h ?? holds);

  test('os números da época: uma por família, região e mês, janela de 20 min, rumor 4 h antes, nível 25', () {
    expect((model.majorPerMonth, model.majorWindowS, model.majorRumorLeadS, model.majorLevel), (1, 1200, 4 * 3600, 25));
    expect(model.archetypeEvents.keys.toSet(), families.toSet(), reason: 'um evento por família');
  });

  test('a Entidade só aparece com a condição do ritual da família valendo, no lugar e na hora dela', () {
    final all = sightings();
    expect(all, isNotEmpty);
    final (from, to) = monthBounds(t0);
    for (final s in all) {
      expect(holds(s.family, s.cx20, s.cy20, s.startUtc), isTrue, reason: '${s.family} em ${s.startUtc}');
      expect((s.startUtc >= from, s.endUtc <= to, s.endUtc - s.startUtc), (true, true, model.majorWindowS));
      expect(s.cx20, inInclusiveRange(area.x0, area.x0 + area.w - 1));
    }
    expect(all.map((s) => s.family).toSet().length, all.length, reason: 'no máximo uma por família');
    expect(sightings(h: (_, _, _, _) => false), isEmpty, reason: 'sem a condição, nenhuma');
  });

  test('é igual para dois jogadores do mesmo grupo (só a seed, a região e o mês decidem) e muda com outra seed', () {
    String key(List<MajorSighting> l) => [for (final s in l) '${s.family}@${s.cx20},${s.cy20}@${s.startUtc}#${s.uid}'].join(';');
    MajorSighting? atA, atB;
    // Dois jogadores em pontos diferentes da mesma região, pelo driver.
    HighTiersDriver driver() => HighTiersDriver(
        seed: seed, epochId: epoch, model: model, families: families, holds: holds,
        regionAt: (_, _) => (id: 'campinas', x0: area.x0, y0: area.y0, w: area.w, h: area.h), eventsAt: (_, _, _) => const []);
    final a = driver().sightingsAround(area.x0 + 10, area.y0 + 10, t0), b = driver().sightingsAround(area.x0 + 300, area.y0 + 250, t0);
    expect(key(a), key(b));
    atA = a.first;
    atB = b.first;
    expect(atA.uid, atB.uid);
    expect(key(sightings()), isNot(key(sightings(s: seed + 1))));
    expect(key(sightings()), isNot(key(sightings(region: 'sao_paulo'))));
  });

  test('o rumor sai horas antes, com o bairro e a faixa de hora, e some quando a janela fecha', () {
    final driver = HighTiersDriver(
      seed: seed,
      epochId: epoch,
      model: model,
      families: families,
      holds: holds,
      regionAt: (_, _) => (id: 'campinas', x0: area.x0, y0: area.y0, w: area.w, h: area.h),
      eventsAt: (_, _, _) => const [],
      bairroAt: (_, _, _) => 'Cambuí',
      rumors: data.rumors,
    );
    final s = driver.sightingsAround(area.x0, area.y0, t0).first;
    expect(s.rumorUtc, s.startUtc - model.majorRumorLeadS);
    List<ForumRumor> at(int t) => [for (final r in driver.rumorsAt(area.x0, area.y0, t, offset: offset)) if (r.sighting.uid == s.uid) r];
    expect(at(s.rumorUtc - 1), isEmpty, reason: 'antes do rumor, nada');
    final r = at(s.rumorUtc).single;
    expect(r.text, allOf(contains('Cambuí'), contains(hourBand(s.startUtc, offset: offset)), contains(data.rumors.signals[s.family]!)));
    expect(r.text, isNot(contains('{')), reason: 'todas as lacunas preenchidas');
    expect(data.forum.users, contains(r.user));
    expect(driver.activeMajors(area.x0, area.y0, s.rumorUtc), isNot(contains(s)), reason: 'o rumor vem antes dela');
    expect(driver.activeMajors(area.x0, area.y0, s.startUtc), contains(s));
    expect(at(s.endUtc), isEmpty);
    expect(driver.activeMajors(area.x0, area.y0, s.endUtc), isNot(contains(s)), reason: 'a janela é curta');
  });

  test('o bairro do rumor é o mais perto na lista da região', () {
    final campinas = data.bairros['campinas']!;
    expect(nearestBairro(campinas, -22.8174, -47.0697), 'Cidade Universitária');
    expect(nearestBairro(campinas, -22.9056, -47.0608), 'Centro');
    expect(data.bairros['sao_paulo'], isNotEmpty);
  });

  test('o Arquétipo: só nas famílias do evento, no terço do meio da ocorrência, raro e igual para todos', () {
    const start = t0, end = t0 + 6 * 3600;
    final hits = <ArchetypeSighting>[];
    for (var y = 0; y < 30; y++) {
      for (var x = 0; x < 30; x++) {
        final a = archetypeIn(seed: seed, epochId: epoch, m: model, eventId: 'black_sun', eventStart: start, eventEnd: end, cx17: 97000 + x, cy17: 138000 + y);
        if (a != null) hits.add(a);
      }
    }
    expect(hits.length, inInclusiveRange(40, 140), reason: '~10% das células');
    for (final a in hits) {
      expect(a.family, 'shade', reason: 'Sol Negro é do Shade');
      expect((a.peakFrom, a.peakTo), (start + 3 * 3600 - 3672, start + 3 * 3600 + 3672));
      expect((a.inPeak(start + 3 * 3600), a.inPeak(start + 3600), a.inPeak(end - 60)), (true, false, false));
    }
    expect(archetypeIn(seed: seed, epochId: epoch, m: model, eventId: 'hail', eventStart: start, eventEnd: end, cx17: hits.first.cx17, cy17: hits.first.cy17)?.family, anyOf(isNull, 'clod'));
    expect(archetypeIn(seed: seed, epochId: epoch, m: model, eventId: 'nao_existe', eventStart: start, eventEnd: end, cx17: hits.first.cx17, cy17: hits.first.cy17), isNull);
    final again = archetypeIn(seed: seed, epochId: epoch, m: model, eventId: 'black_sun', eventStart: start, eventEnd: end, cx17: hits.first.cx17, cy17: hits.first.cy17)!;
    expect((again.uid, again.x21, again.y21), (hits.first.uid, hits.first.x21, hits.first.y21));
  });

  test('o Clod vem no Granizo: o clima da janela conta como ocorrência, do começo ao fim da janela', () {
    expect((model.archetypeEvents['clod'], model.archetypeEvents['rust']), ('hail', 'rift_wind'));
    final c = ClimateWorld(seed: seed, schedule: data.schedule, speciesOfType: data.ecoOfType, itemExists: data.itemNames.containsKey, forced: () => 'hail');
    final m = c.modelAt(t0)!.$2;
    final occ = archetypeOccurrencesAt(c, area.x0, area.y0, t0);
    final hail = occ.singleWhere((o) => o.id == 'hail');
    expect((hail.start, hail.end), (m.windowOf(t0) * m.windowS, (m.windowOf(t0) + 1) * m.windowS));
    final hits = [
      for (var x = 0; x < 20; x++)
        for (var y = 0; y < 20; y++) ?archetypeIn(seed: seed, epochId: epoch, m: model, eventId: hail.id, eventStart: hail.start, eventEnd: hail.end, cx17: 97000 + x, cy17: 138000 + y),
    ];
    expect(hits, isNotEmpty);
    expect(hits.every((a) => a.family == 'clod'), isTrue);
  });

  test('o Arquétipo se mostra uma vez, quando entra na vista, fica os segundos dele e some com aviso', () {
    const start = t0, end = t0 + 6 * 3600, mid = t0 + 3 * 3600;
    final model1 = HighTiersModel(archetypeChance: 1, archetypeStayS: 12, archetypePeakShare: model.archetypePeakShare, archetypeEvents: model.archetypeEvents);
    final driver = HighTiersDriver(
        seed: seed, epochId: epoch, model: model1, families: families, holds: holds, regionAt: (_, _) => null, eventsAt: (_, _, _) => [(id: 'fog_procession', start: start, end: end)]);
    final gone = <String>[];
    var seen = false;
    List<ArchetypeSighting> at(int t) => driver.archetypesAt(776000, 1104000, t, visible: (_) => seen, gone: (a) => gone.add(a.family));
    expect(at(mid), isEmpty, reason: 'fora da vista ainda não começa');
    seen = true;
    final shown = at(mid + 5);
    expect(shown, isNotEmpty);
    expect(shown.every((a) => a.family == 'wisp'), isTrue);
    expect(at(mid + 5 + 11), hasLength(shown.length));
    expect(at(mid + 5 + 12), isEmpty);
    expect(gone, hasLength(shown.length));
    expect(at(mid + 60), isEmpty, reason: 'não volta');
  });
}
