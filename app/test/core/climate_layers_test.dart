import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/astro.dart';
import 'package:kenoma/core/climate.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/core/spawn.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/climate_catalog.dart';

import '../support/fixtures.dart';

/// 0.21.0 (GDD rev 356): clima e evento em camadas na época 12. O clima é um por janela; até dois eventos por cima, com
/// duração própria; o terceiro espera. Campinas: a região z12 do Centro.
void main() {
  final schedule = loadEpochs();
  final e12 = schedule.epochs.firstWhere((e) => e.id == 12);
  final m = e12.climate!;
  final catalog = ClimateCatalog.fromJson(loadJson('assets/data/clima.json'), loadJson('assets/data/eventos.json'));
  final (x12, y12) = latLonToTileFraction(-22.9056, -47.0608, 12);
  final rx = x12.floor(), ry = y12.floor();
  int utc(int y, int mo, int d, [int h = 0]) => DateTime.utc(y, mo, d, h).millisecondsSinceEpoch ~/ 1000;
  final (lat, lon) = tileFractionToLatLon(rx + 0.5, ry + 0.5, 12);

  test('a época 12 separa os climas dos eventos, e as épocas até a 11 continuam com o evento como clima', () {
    expect(m.layered, isTrue);
    for (final id in ['rainbow', 'tornado', 'aurora', 'static', 'meteor_shower', 'double_moon', 'crimson_moon', 'black_sun', 'vigil', 'silence', 'fog_procession', 'veil_tide', 'rift_wind', 'echo_storm', 'veil_prism']) {
      expect(m.eventDefs.containsKey(id), isTrue, reason: id);
      expect(m.defs.containsKey(id), isFalse, reason: '$id não é mais clima');
    }
    expect(m.defs.containsKey('crimson_rain') || m.defs.containsKey('prismatic_drizzle'), isFalse);
    final e11 = schedule.epochs.firstWhere((e) => e.id == 11).climate!;
    expect((e11.layered, e11.defs.containsKey('vigil'), e11.defs.containsKey('crimson_rain')), (false, true, true));
    for (final id in m.eventDefs.keys) {
      expect(catalog.eventInfos.containsKey(id), isTrue, reason: 'o visual do evento $id');
    }
  });

  test('sexta-feira 13: a Vigília e a Tempestade ficam ativas juntas (antes uma trocava a outra)', () {
    // Procura uma sexta-feira 13 com tempestade sorteada numa janela da tarde.
    for (var seed = 1; seed < 400; seed++) {
      for (var y = 2027; y < 2034; y++) {
        for (var mo = 1; mo <= 12; mo++) {
          if (DateTime.utc(y, mo, 13).weekday != DateTime.friday) continue;
          for (var h = 0; h < 24; h += 3) {
            final t = utc(y, mo, 13, h) + 3 * 3600 + 1800; // hora local h, no meio da janela
            final s = m.stackAt(seed: seed, tUtc: t, rx: rx, ry: ry);
            if (s.climate != 'storm') continue;
            expect(s.events.map((e) => e.id), contains('vigil'));
            expect(s.events.firstWhere((e) => e.id == 'vigil').source, EventSource.calendar);
            expect(s.id, startsWith('storm+'));
            expect(s.combos.map((c) => c.id), contains('vigil_storm'));
            final def = m.def(s.id)!;
            expect(def.pieces.whereType<DropPiece>().map((p) => p.name), contains('lightning_vigil'), reason: 'o raio da Tempestade continua');
            expect(def.pieces.whereType<ZonePiece>().map((p) => p.name), contains('gaze'), reason: 'o olhar da Vigília também');
            // E o modelo antigo (época 11) dava uma coisa só.
            final old = schedule.epochs.firstWhere((e) => e.id == 11).climate!.at(seed: seed, tUtc: t, rx: rx, ry: ry);
            expect(old.contains('+'), isFalse);
            return;
          }
        }
      }
    }
    fail('nenhuma sexta-feira 13 com tempestade');
  });

  test('o arco-íris só nasce na passagem de chuva ou garoa para sol, de dia', () {
    var found = 0;
    for (var seed = 1; seed < 60; seed++) {
      final from = utc(2027, 1, 1), to = utc(2027, 3, 1);
      for (var w = m.windowOf(from); w < m.windowOf(to); w++) {
        final r = m.schedule.rainbowDraw(seed, rx, ry, w, const []);
        final start = w * m.windowS;
        final now = m.resolve(seed: seed, tUtc: start, rx: rx, ry: ry).climate, before = m.resolve(seed: seed, tUtc: start - 1, rx: rx, ry: ry).climate;
        if (r == null) continue;
        found++;
        expect(['clear', 'strong_sun'], contains(now));
        expect(['rain', 'drizzle', 'storm'], contains(before));
        expect(sunAltitudeDeg(lat, lon, start), greaterThan(0));
        final seg = m.schedule.activeAt(seed, start + 60, rx, ry, const []).where((a) => a.id == 'rainbow');
        expect(seg, isNotEmpty, reason: 'entra na agenda (sem outros eventos, a vaga está livre)');
      }
    }
    expect(found, greaterThan(3));
  });

  test('o Tornado só acontece com Tempestade ou Vendaval', () {
    var found = 0;
    for (var seed = 1; seed < 120; seed++) {
      for (final d in [utc(2027, 1, 10), utc(2027, 2, 3), utc(2027, 8, 20)]) {
        for (final a in m.schedule.dayOf(seed, m.schedule.localDay(d), rx, ry, const [])) {
          if (a.id != 'tornado') continue;
          found++;
          for (var t = a.startUtc; t < a.endUtc; t += 300) {
            expect(['storm', 'gale'], contains(m.resolve(seed: seed, tUtc: t, rx: rx, ry: ry).climate));
          }
        }
      }
    }
    expect(found, greaterThan(0));
  });

  test('a Lua Carmim tinge a chuva (Chuva Carmim, poças vermelhas com Carmesins) e com sol fica só no céu', () {
    final rain = m.def('rain+crimson_moon')!, sun = m.def('clear+crimson_moon')!;
    expect(rain.puddles!.name, 'crimson_puddle');
    expect(rain.puddles!.spawn!.variant, 'crimson');
    expect(sun.puddles, isNull);
    final rv = catalog.of('rain+crimson_moon'), sv = catalog.of('clear+crimson_moon');
    expect(rv.name, startsWith('Chuva Carmim'));
    expect(rv.layers.where((l) => l.kind == 'particles').every((l) => l.color() == 0xFFD0344A), isTrue);
    expect(sv.layers.where((l) => l.kind == 'particles'), isEmpty, reason: 'com sol, nada cai do céu');
    expect(sv.layers.where((l) => l.flag('sky')), isNotEmpty, reason: 'só a parte de céu');
    // O eclipse lunar da época vira o evento, com o trecho visível de verdade (não a janela de 3 h).
    final ev = m.eclipses.firstWhere((r) => r.climate == 'crimson_moon');
    expect(ev.events, isNotEmpty);
  });

  test('o terceiro evento espera o fim de um dos dois', () {
    final t0 = utc(2027, 5, 10, 13);
    ClimateEvent feed(String id, int a, int b) => ClimateEvent(climate: id, startsUtc: t0 + a * 60, endsUtc: t0 + b * 60, id: 'listeners');
    final events = [feed('static', 0, 120), feed('silence', 30, 180), feed('vigil', 60, 240)];
    final at = m.schedule.activeAt(1, t0 + 90 * 60, rx, ry, events);
    expect(at.map((e) => e.id).toSet(), {'static', 'silence'});
    final later = m.schedule.activeAt(1, t0 + 130 * 60, rx, ry, events);
    final vigil = later.firstWhere((e) => e.id == 'vigil');
    expect((vigil.startUtc, vigil.endUtc, vigil.waited), (t0 + 120 * 60, t0 + 240 * 60, true));
    expect(m.schedule.activeAt(1, t0 + 100 * 60, rx, ry, events).length, 2);
  });

  test('os modificadores de spawn se somam com teto de +++ por tipo', () {
    final s = m.def('fog+fog_procession')!.spawn;
    expect(s['spectral'], m.spawnCap, reason: '++ e +++ passariam de +++');
    final v = m.def('storm+vigil')!.spawn;
    expect((v['electric'], v['digital'], v['spectral']), (2.0, 2.0, 1.3));
    expect(v['fire'], closeTo(0.4, 1e-9));
    expect(m.def('rain+black_sun')!.spawn['fire'], closeTo(0.6, 1e-9));
  });

  test('as três combinações, e nenhuma outra', () {
    expect({for (final c in m.combos) c.id}, {'vigil_storm', 'crimson_storm', 'aurora_snow'});
    final vs = m.def('storm+vigil')!;
    final bolt = vs.pieces.whereType<DropPiece>().firstWhere((p) => p.impact);
    expect(bolt.atZone, 'gaze');
    expect(vs.pieces.whereType<ZonePiece>().firstWhere((p) => p.name == 'gaze').spawn!.type, 'electric');
    final cs = m.def('storm+crimson_moon')!.pieces.whereType<DropPiece>().firstWhere((p) => p.impact);
    expect((cs.name, cs.spawn!.variant), ('lightning_crimson', 'crimson'));
    expect(m.def('snow+aurora')!.modifier!.shinyTypeMult['spectral'], 3.0);
    expect(m.def('rain+vigil')!.pieces.whereType<DropPiece>(), isEmpty, reason: 'sem Tempestade, sem raio');
    expect(m.def('clear+aurora')!.modifier!.shinyTypeMult, isEmpty, reason: 'sem Neve, sem a combinação');
    expect(catalog.of('storm+vigil').hud, contains('Vigília com Tempestade'));
  });

  test('a mesma pilha dá a mesma camada base, venha o evento do feed ou do calendário', () {
    final vigilFeed = m.def(stackIdOf(m, 'storm', ['vigil']))!;
    final both = stackIdOf(m, 'storm', ['crimson_moon', 'vigil']);
    expect(both, stackIdOf(m, 'storm', ['vigil', 'crimson_moon']), reason: 'a ordem dos dados, não a de chegada');
    Epoch ep() => e12;
    List<String> cell(ClimateDef d) => [
          for (final i in generateCell(seed: 7, epoch: ep(), cellX: 776000, cellY: 581000, window: 9, biomeKey: 'urban', climateMult: d.spawn, shinyMult: d.modifier?.shinyMult ?? 1, variantMult: d.modifier?.variantMult ?? 1))
            '${i.uid}:${i.exists}:${i.entryId}:${i.shiny}:${i.variantBiome}',
        ];
    expect(cell(vigilFeed), cell(m.def('storm+vigil')!));
    expect(identical(m.def('storm+vigil'), vigilFeed), isTrue, reason: 'a pilha montada é guardada');
  });
}
