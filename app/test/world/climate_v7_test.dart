import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/astro.dart';
import 'package:kenoma/core/climate.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/climate_catalog.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/climate_outlook.dart';
import 'package:kenoma/world/climate_world.dart';
import 'package:kenoma/world/sky_outlook.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/street_cover.dart';
import 'package:kenoma/world/visual_map.dart';
import 'package:kenoma/world/walk_paths.dart';

import '../support/fixtures.dart';

int utc(int y, int m, int d, [int h = 0]) => DateTime.utc(y, m, d, h).millisecondsSinceEpoch ~/ 1000;

/// O que a época 6 do clima gera: o sorteio por janela e região e as quedas e zonas de cada peça em algumas células.
int climateFingerprint(ClimateModel m, int seed, int epochId) {
  final parts = <int>[];
  final w0 = utc(2026, 11, 10) ~/ m.windowS;
  for (var k = 0; k < 2920; k += 7) {
    for (final (rx, ry) in [(1514, 2315), (1515, 2315), (1514, 2316)]) {
      parts.add(fnv1a64Bytes(utf8.encode(m.drawn(seed, w0 + k, rx, ry))));
    }
  }
  for (final def in m.defs.values) {
    for (final (i, p) in def.pieces.indexed) {
      for (final (cx, cy) in [(48451, 74082), (48452, 74083)]) {
        if (p is DropPiece) {
          for (final d in m.drops(seed, epochId, cx, cy, w0 + 3, i, p)) {
            parts.addAll([d.tUtc, (d.x * 1e6).round(), (d.y * 1e6).round(), (d.spawnRoll * 1e9).round(), (d.itemRoll * 1e9).round(), (d.pick * 1e9).round(), d.uid]);
          }
        }
        if (p is ZonePiece) {
          for (final z in m.zones(seed, epochId, cx, cy, w0 + 3, i, p)) {
            parts.addAll([z.startUtc, z.endUtc, (z.x0 * 1e6).round(), (z.y0 * 1e6).round(), (z.headingRad * 1e9).round(), z.uidBase, for (final s in z.slots) (s.roll * 1e9).round()]);
          }
        }
      }
    }
  }
  return fnv1a64(parts);
}

void main() {
  final seed = seedGlobal('KENOMA-TESTE');
  final data = loadGameData();
  final catalog = ClimateCatalog.fromJson(loadJson('assets/data/clima.json'));
  final e7 = loadEpochs().epochs.firstWhere((e) => e.id == 7);
  final (cx20, cy20) = latLonToTile(-22.8174, -47.0697, 20); // Unicamp
  final x21 = cx20 * 2.0 + 1, y21 = cy20 * 2.0 + 1;
  final mpc = metersPerCell(-22.8174);
  final visual = VisualMap(VisualPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync())), cacheTiles: 32);

  /// Um aparelho: lê o epochs.json do zero e monta os próprios caminhos.
  ClimateWorld device({String? forced, List<ClimateEvent> events = const []}) => ClimateWorld(
        seed: seed,
        schedule: loadEpochs(),
        speciesOfType: data.ecoOfType,
        itemExists: data.itemNames.containsKey,
        itemSince: (id) => data.itemSinceEpoch[id],
        snapper: WalkPaths(visual),
        forced: () => forced,
      )..events = events;

  group('épocas travadas', () {
    test('o clima da época 6 gera exatamente o mesmo de antes da 0.17.0 (dado e comportamento)', () {
      final json = (epochsJson()['epochs'] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere((e) => e['id'] == 6);
      expect(fnv1a64Bytes(utf8.encode(jsonEncode(json['climate']))), _e6ClimateJson);
      final e6 = loadEpochs().epochs.firstWhere((e) => e.id == 6);
      expect(climateFingerprint(e6.climate!, seed, 6), _e6ClimateBehavior);
      expect(e6.climate!.calendar, isEmpty, reason: 'a época 6 não tem calendário nem astronomia');
      expect(e6.climate!.astro, isEmpty);
    });

    test('o clima da época 7 gera exatamente o mesmo de antes da 0.17.1: dado, peças e um ano de calendário, eclipses e astronomia', () {
      final json = (epochsJson()['epochs'] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere((e) => e['id'] == 7);
      expect(fnv1a64Bytes(utf8.encode(jsonEncode(json['climate']))), _e7ClimateJson);
      final m = e7.climate!;
      expect(climateFingerprint(m, seed, 7), _e7ClimateBehavior);
      final year = [
        for (var w = utc(2026, 11, 10) ~/ m.windowS; w < utc(2027, 11, 10) ~/ m.windowS; w++)
          for (final (rx, ry) in [(1514, 2315), (1515, 2316)])
            fnv1a64Bytes(utf8.encode(() {
              final c = m.resolve(seed: seed, tUtc: w * m.windowS, rx: rx, ry: ry);
              return '${c.climate}/${c.source.name}/${c.event}/${c.maxUtc}';
            }())),
      ];
      expect(fnv1a64(year), _e7ResolveYear);
    });

    test('a época 7 copia a 6 (pacotes, spawns, caminhos) e só muda o clima; começa depois da 6', () {
      final all = (epochsJson()['epochs'] as List<dynamic>).cast<Map<String, dynamic>>();
      final j6 = all.firstWhere((e) => e['id'] == 6), j7 = all.firstWhere((e) => e['id'] == 7);
      for (final k in j6.keys) {
        if (const {'id', 'starts_utc', 'valid_until_utc', 'climate'}.contains(k)) continue;
        expect(jsonEncode(j7[k]), jsonEncode(j6[k]), reason: k);
      }
      expect(DateTime.parse(j7['starts_utc'] as String).isAfter(DateTime.parse(j6['starts_utc'] as String)), isTrue);
    });
  });

  group('poças', () {
    final w = (e7.startsUtc + 20 * 86400) ~/ 10800;
    final rain = w * 10800;
    List<ClimateEvent> rainOnce() => [
          ClimateEvent(climate: 'clear', startsUtc: rain - 10800, endsUtc: rain),
          ClimateEvent(climate: 'rain', startsUtc: rain, endsUtc: rain + 10800),
          ClimateEvent(climate: 'clear', startsUtc: rain + 10800, endsUtc: rain + 2 * 10800),
        ];

    test('ficam nos mesmos pontos das ruas em dois aparelhos, crescem na chuva e secam em até 1 h depois', () {
      final a = device(events: rainOnce()), b = device(events: rainOnce());
      final pa = a.puddlesNear(x21, y21, 60, rain + 900), pb = b.puddlesNear(x21 + 20, y21 - 15, 60, rain + 900);
      final common = {for (final p in pb) p.rolls.uid: p};
      final shared = [for (final p in pa) if (common.containsKey(p.rolls.uid)) (p, common[p.rolls.uid]!)];
      expect(shared.length, greaterThan(10));
      for (final (p, q) in shared) {
        expect((p.x, p.y, p.radiusM, p.size), (q.x, q.y, q.radiusM, q.size));
      }
      // Sobre a rua: levar a poça de novo ao caminho não a move.
      final paths = WalkPaths(visual);
      for (final p in pa.take(20)) {
        final c20x = p.x.floor() >>> 1, c20y = p.y.floor() >>> 1;
        final s = paths.snap(c20x, c20y, p.x / 2 - c20x, p.y / 2 - c20y)!;
        expect(((c20x + s.px) * 2 - p.x).abs() * mpc, lessThan(0.01));
      }
      double size(int t) => a.puddlesNear(x21, y21, 40, t).first.size;
      expect(size(rain + 600), closeTo(600 / 1800, 1e-9), reason: 'crescendo');
      expect(size(rain + 3600), 1, reason: 'cheia depois de 30 min');
      expect(size(rain + 10800 + 1800), closeTo(0.5, 1e-9), reason: 'meia hora depois da chuva, pela metade');
      expect(a.puddlesNear(x21, y21, 40, rain + 10800 + 1800).every((p) => !p.wet), isTrue);
      expect(a.puddlesNear(x21, y21, 40, rain + 10800 + 3600), isEmpty, reason: 'secou');
      expect(a.puddlesNear(x21, y21, 40, rain - 60), isEmpty);
      final again = device(events: rainOnce()).puddlesNear(x21, y21, 60, rain + 900);
      expect([for (final p in again) (p.x, p.y)], [for (final p in pa) (p.x, p.y)], reason: 'os pontos baixos são fixos');
    });

    test('dão água pura enquanto têm água e fazem nascer Ecos de Água enquanto chove', () {
      final a = device(events: rainOnce());
      Set<String> born(int t) => {for (final s in a.extras(x21: x21, y21: y21, radiusM: 400, t: t, metersPerCell21: mpc, levelOf: (id, add, uid) => 3)) s.entryId};
      expect(born(rain + 1800), containsAll(['item.pure_water', 'rill.eco']));
      final drying = born(rain + 10800 + 600);
      expect(drying, contains('item.pure_water'));
      expect(drying, isNot(contains('rill.eco')), reason: 'secando, não nasce Eco');
      expect(born(rain + 10800 + 3000), isNot(contains('item.pure_water')), reason: 'quase seca: sem água');
    });

    test('na Geada forte as poças viram gelo inteiro, com cristal (na época 7 o cristal ainda não existe: água pura)', () {
      final a = device(forced: 'hard_frost');
      final t = e7.startsUtc + 30 * 86400;
      final ps = a.puddlesNear(x21, y21, 40, t);
      expect(ps, isNotEmpty);
      expect(ps.every((p) => p.frozen && p.size == 1), isTrue);
      expect(data.itemSinceEpoch['item.ice_crystal'], 8, reason: 'o cristal nasceu na 0.17.1, com a época 8');
      final items = {for (final s in a.extras(x21: x21, y21: y21, radiusM: 400, t: t, metersPerCell21: mpc, levelOf: (id, add, uid) => 3)) s.entryId};
      expect(items, contains('item.pure_water'));
      expect(a.modsAt(x21, y21, t).walkerMult, 0.6, reason: 'passantes mais lentos no gelo');
    });

    test('na Chuva Carmim as poças dão Essência carmesim, de toque', () {
      expect(data.itemName('item.essence.crimson'), 'Essência carmesim');
      final a = device(forced: 'crimson_rain');
      final t = e7.startsUtc + 30 * 86400 + 1800;
      final items = [for (final s in a.extras(x21: x21, y21: y21, radiusM: 400, t: t, metersPerCell21: mpc, levelOf: (id, add, uid) => 3)) if (!s.isEco) s];
      expect(items, isNotEmpty);
      expect(items.every((s) => s.entryId == 'item.essence.crimson' && !s.isSpark), isTrue);
    });

    test('na Chuva de Runas a runa é Giz com o bônus do próximo ritual', () {
      final a = device(forced: 'rune_rain');
      final t = e7.startsUtc + 30 * 86400;
      final runes = [
        for (var k = 0; k < 10800; k += 600)
          for (final s in a.extras(x21: x21, y21: y21, radiusM: 1500, t: t - t % 10800 + k, metersPerCell21: mpc, levelOf: (id, add, uid) => 3)) if (s.tag == 'rune_bonus') s,
      ];
      expect(runes, isNotEmpty);
      expect(runes.every((s) => s.entryId == 'item.chalk' && !s.isSpark), isTrue);
    });
  });

  group('meteoros', () {
    test('a cratera tem material raro por 2 h, chance de Dracônico sem espécie, e o mesmo ponto em dois aparelhos', () {
      final t0 = e7.startsUtc + 40 * 86400;
      final a = device(forced: 'meteor_shower'), b = device(forced: 'meteor_shower');
      final drops = a.dropsNear(x21, y21, 40, t0, t0 + 10800);
      expect(drops, isNotEmpty);
      final other = {for (final d in b.dropsNear(x21 + 30, y21, 40, t0, t0 + 10800)) d.uid: d};
      final d = drops.firstWhere((d) => other.containsKey(d.uid) && d.itemRoll < 0.6);
      expect((d.x, d.y, d.tUtc), (other[d.uid]!.x, other[d.uid]!.y, other[d.uid]!.tUtc));
      List<WorldSpawn> at(int t) => [for (final s in a.extras(x21: d.x, y21: d.y, radiusM: 30, t: t, metersPerCell21: mpc, levelOf: (id, add, uid) => 3)) if (s.uid == fnv1a64([d.uid, 3])) s];
      expect(at(d.tUtc + 60).single.entryId, 'item.ectoplasm', reason: 'sem item.meteorite: o fallback');
      expect(at(d.tUtc + 7100), hasLength(1));
      expect(at(d.tUtc + 7300), isEmpty, reason: 'o brilho (e o material) dura 2 h');
      expect(a.extras(x21: d.x, y21: d.y, radiusM: 30, t: d.tUtc + 60, metersPerCell21: mpc, levelOf: (id, add, uid) => 3).where((s) => s.isEco), isEmpty, reason: 'Dracônico ainda não tem espécie');
      final crater = catalog.piece('meteor');
      expect((crater.mark, crater.glowS, crater.markS), ('crater', 7200, 10800));
    });
  });

  group('eventos que forçam clima', () {
    final m = e7.climate!;
    ClimateCause at(int t) => m.resolve(seed: seed, tUtc: t, rx: cx20 >>> 8, ry: cy20 >>> 8);

    test('Finados traz a Procissão, São João a Chuva de Fagulhas; fora deles, o sorteio da estação', () {
      final fin = at(utc(2030, 11, 2, 15));
      expect((fin.climate, fin.source, fin.event), ('fog_procession', ClimateSource.calendar, 'finados'));
      final sj = at(utc(2030, 6, 23, 22)); // 19 h em Brasília
      expect((sj.climate, sj.event), ('spark_rain', 'sao_joao'));
      expect(at(utc(2030, 11, 5, 15)).source, ClimateSource.season);
    });

    test('as Geminídeas trazem meteoros de madrugada, por chance; o eclipse do sol traz o Sol Negro', () {
      final nights = [for (final d in [13, 14, 15]) for (final h in [3, 6]) at(utc(2030, 12, d, h) + 1800)];
      expect(nights.where((c) => c.climate == 'meteor_shower' && c.event == 'geminids'), isNotEmpty);
      expect(nights.every((c) => c.climate == 'meteor_shower' || c.source == ClimateSource.season), isTrue);
      final ecl = at(utc(2027, 2, 6, 16));
      expect((ecl.climate, ecl.event), ('black_sun', 'solar_eclipse'));
    });

    test('o eclipse só força o clima onde é visível do centro da região z12, e o Céu dá a hora local do máximo', () {
      ClimateCause atPlace(double lat, double lon, int t) {
        final (x, y) = latLonToTile(lat, lon, 12);
        return m.resolve(seed: seed, tUtc: t, rx: x, ry: y);
      }

      // 2027-02-06: parcial em Campinas das 14h32 às 18h00 UT, nada em Bogotá.
      expect([for (final h in [13, 15, 17]) atPlace(-22.9056, -47.0608, utc(2027, 2, 6, h)).climate], everyElement('black_sun'));
      // O 4º contato (18h00min03 UT) ainda pega a janela das 18h; a das 21h já é da estação.
      expect(atPlace(-22.9056, -47.0608, utc(2027, 2, 6, 19)).event, 'solar_eclipse');
      expect(atPlace(-22.9056, -47.0608, utc(2027, 2, 6, 22)).event, isNot('solar_eclipse'));
      expect(atPlace(4.71, -74.07, utc(2027, 2, 6, 16)).event, isNot('solar_eclipse'));
      // Lua Carmim: o total de 2029-06-26 é visto de Campinas; o de 2028-12-31 acontece com a Lua abaixo do horizonte.
      final crimson = atPlace(-22.9056, -47.0608, utc(2029, 6, 26, 3));
      expect((crimson.climate, crimson.event, crimson.source), ('crimson_rain', 'crimson_moon', ClimateSource.astro));
      expect(atPlace(-22.9056, -47.0608, utc(2028, 12, 31, 17)).event, isNot('crimson_moon'));
      expect(atPlace(35.68, 139.69, utc(2028, 12, 31, 17)).climate, 'crimson_rain', reason: 'em Tóquio a Lua está no céu');
      final o = climateOutlook(world: device(), catalog: catalog, lat: -22.9056, lon: -47.0608, nowUtc: utc(2027, 2, 6, 16));
      expect(o.now.reason, '${catalog.events['solar_eclipse']!.reason} Máximo às 13h22.');
    });

    test('a lua cheia no perigeu traz a Lua Dupla, rara; a lua cheia no apogeu não', () {
      // 14/11/2016: a lua cheia mais perto da Terra desde 1948 (356.509 km às 11h23 UTC).
      expect(moonDistanceKm(utc(2016, 11, 14, 11) + 1380), closeTo(356509, 900));
      expect(moonDistanceKm(utc(2016, 4, 22, 5)), greaterThan(400000), reason: 'lua cheia de abril de 2016, perto do apogeu');
      final near = [for (var h = -36; h <= 36; h += 3) at(utc(2016, 11, 14, 12) + h * 3600)];
      expect(near.where((c) => c.climate == 'double_moon' && c.source == ClimateSource.astro), isNotEmpty);
      final far = [for (var h = -36; h <= 36; h += 3) at(utc(2016, 4, 22, 5) + h * 3600)];
      expect(far.where((c) => c.climate == 'double_moon'), isEmpty);
      var hits = 0;
      for (var t = utc(2030, 1, 1); t < utc(2031, 1, 1); t += 10800) {
        if (at(t).climate == 'double_moon') hits++;
      }
      expect(hits, lessThan(20), reason: 'rara: poucas janelas por ano');
    });

    test('o feed assinado vem antes do calendário e traz o motivo; o app Céu mostra a frase', () {
      final t = utc(2030, 11, 2, 15);
      final start = DateTime.fromMillisecondsSinceEpoch((t - 3600) * 1000, isUtc: true);
      final ev = ClimateEvent.tryParse({
        'kind': 'climate', 'climate': 'vigil', 'event': 'listeners', 'reason': 'Os Que Escutam pousaram o olhar em Campinas.',
        'starts_utc': start.toIso8601String(), 'ends_utc': start.add(const Duration(hours: 6)).toIso8601String(),
      })!;
      final w = device(events: [ev]);
      final o = climateOutlook(world: w, catalog: catalog, lat: -22.8174, lon: -47.0697, nowUtc: t);
      expect((o.now.climate, o.now.source, o.now.eventName, o.now.reason), ('vigil', ClimateSource.feed, 'Os Que Escutam', 'Os Que Escutam pousaram o olhar em Campinas.'));
      expect(o.event, isNotNull);
      expect(o.next, hasLength(4));
      for (var k = 0; k < 4; k++) {
        expect(o.next[k].startUtc, o.now.startUtc + (k + 1) * 10800);
      }
      final fin = climateOutlook(world: device(), catalog: catalog, lat: -22.8174, lon: -47.0697, nowUtc: utc(2030, 11, 2, 15));
      expect(fin.now.reason, 'É Finados: a Procissão anda na névoa.');
      expect(fin.effects['fog_procession'], catalog.of('fog_procession').hud);
      final plain = climateOutlook(world: device(), catalog: catalog, lat: -22.8174, lon: -47.0697, nowUtc: utc(2030, 11, 6, 15));
      expect((plain.event, plain.now.reason), (null, catalog.reasons['season']));
      final sky = cellSkyOutlook(device(), lat: () => -22.8174, lon: () => -47.0697, catalog: catalog)(utc(2030, 11, 2, 15), 3);
      expect((sky.first.climateId, sky.first.reason), ('fog_procession', 'É Finados: a Procissão anda na névoa.'), reason: 'o app Céu');
      expect(cellSkyOutlook(device(), lat: () => -22.8174, lon: () => -47.0697, catalog: catalog)(utc(2030, 11, 6, 15), 2).first.reason, isNull);
      final dbg = climateOutlook(world: device(forced: 'aurora'), catalog: catalog, lat: -22.8174, lon: -47.0697, nowUtc: utc(2030, 11, 6, 15));
      expect((dbg.now.climate, dbg.now.source), ('aurora', ClimateSource.debug));
    });
  });

  group('ruas', () {
    test('ruas baixas: fixas pela seed, a fração da classe, nunca nas calçadas altas; dunas mudam a cada janela', () {
      final flood = streetCoverOf(catalog.of('deluge'))!, sand = streetCoverOf(catalog.of('sandstorm'))!;
      double share(RoadClass c) => [for (var i = 0; i < 4000; i++) flood.level(seed, (12092, 18513, i), c, 0, 1)].where((l) => l > 0).length / 4000;
      expect(share(RoadClass.local), closeTo(0.65, 0.03));
      expect(share(RoadClass.principal), closeTo(0.35, 0.03));
      expect(share(RoadClass.pedestrian), 0);
      expect(flood.level(seed, (1, 2, 3), RoadClass.local, 5, 1), flood.level(seed, (1, 2, 3), RoadClass.local, 9, 1), reason: 'não muda de janela');
      final w1 = [for (var i = 0; i < 400; i++) sand.level(seed, (1, 2, i), RoadClass.local, 1, 1)];
      final w2 = [for (var i = 0; i < 400; i++) sand.level(seed, (1, 2, i), RoadClass.local, 2, 1)];
      expect(w1, isNot(w2));
      expect(sand.stateOf(seed, (1, 2, w1.indexOf(1)), RoadClass.local, 1, 1e6), StreetState.blocked);
      expect(sand.stateOf(seed, (1, 2, w1.indexOf(1)), RoadClass.local, 1, 0), StreetState.normal, reason: 'a duna ainda não subiu');
    });

    test('a neve cobre primeiro as ruas pouco usadas e por último as avenidas', () {
      final snow = streetCoverOf(catalog.of('snow'))!;
      double at(RoadClass c, double s) => snow.level(seed, (0, 0, 0), c, 0, snow.amountAt(s));
      final mid = snow.growS * 0.7;
      expect(at(RoadClass.local, mid), greaterThan(at(RoadClass.principal, mid)));
      expect(at(RoadClass.pedestrian, mid), greaterThan(at(RoadClass.local, mid)));
      expect(at(RoadClass.pedestrian, snow.growS * 0.3), 0, reason: 'antes das ruas, o chão e os telhados');
      expect(at(RoadClass.principal, 4 * 3600), 1);
      expect(snow.tracks, isTrue);
    });
  });

  group('outras peças da época 7', () {
    final t = e7.startsUtc + 50 * 86400 + 5400; // meio da janela: as zonas já começaram

    test('Lua Dupla dobra a chance de variante; Silêncio para o tráfego; Procissão deixa um Eco no fim do rastro', () {
      expect(e7.climate!.def('double_moon')!.modifier!.variantMult, 2);
      expect(device(forced: 'silence').modsAt(x21, y21, t).trafficMult, 0);
      final w = device(forced: 'fog_procession');
      final zones = w.zonesNear(x21, y21, 60, t);
      final ecos = <WorldSpawn>[];
      for (var k = 0; k < 10800; k += 600) {
        ecos.addAll(w.extras(x21: x21, y21: y21, radiusM: 1500, t: t - t % 10800 + k, metersPerCell21: mpc, levelOf: (id, add, uid) => 3 + add).where((s) => s.isEco));
      }
      expect(zones.length + ecos.length, greaterThan(0));
      expect(ecos.where((e) => e.level! >= 5), isNotEmpty, reason: 'Eco forte (nível +2 a +4)');
    });

    test('a duna esconde o material até o jogador chegar perto; o tornado deixa destroços pela trilha', () {
      final sand = device(forced: 'sandstorm');
      final all = sand.zonesNear(x21, y21, 80, t);
      final dunes = all.where((z) => z.piece.name == 'dune').toList();
      expect(dunes, isNotEmpty);
      final z = dunes.first;
      List<WorldSpawn> from(double x, double y) => [for (final s in sand.extras(x21: x, y21: y, radiusM: 300, t: t, metersPerCell21: mpc, levelOf: (id, add, uid) => 3)) if (s.uid == fnv1a64([z.uidBase, 0, 2])) s];
      if (z.slots.first.roll2 < 0.5) {
        expect(from(z.x0, z.y0), hasLength(1), reason: 'em cima da duna');
        expect(from(z.x0 + 100 / mpc, z.y0), isEmpty, reason: 'a 100 m não aparece');
      }
      final tornado = device(forced: 'tornado');
      final debris = <String>{};
      for (var k = 0; k < 10800; k += 900) {
        for (final s in tornado.extras(x21: x21, y21: y21, radiusM: 1500, t: t - t % 10800 + k, metersPerCell21: mpc, levelOf: (id, add, uid) => 3)) {
          debris.add(s.entryId);
        }
      }
      expect(debris.intersection({'item.scrap', 'item.herbs'}), isNotEmpty);
    });

    test('no debug, os climas e efeitos da época 7 já funcionam antes dela começar, só neste aparelho', () {
      final t6 = loadEpochs().epochs.firstWhere((e) => e.id == 6).startsUtc + 86400 + 5400;
      final w = device(forced: 'vigil');
      expect(w.modsAt(x21, y21, t6).id, 'vigil');
      expect(w.zonesNear(x21, y21, 200, t6).where((z) => z.piece.name == 'gaze'), isNotEmpty);
      final d = device();
      for (final name in ['dry_bolt', 'gaze', 'rune', 'puddle', 'hurricane_eye', 'branch', 'lightning']) {
        expect(d.debugTrigger(name, x21, y21, t6), isTrue, reason: name);
      }
      expect(device().idAt(cx20, cy20, t6), isNot('vigil'), reason: 'o mundo dos outros não muda');
    });

    test('Trovoada seca: o raio deixa brasa com Fagulhas de Fogo por 5 min', () {
      final w = device(forced: 'dry_thunder');
      final d = w.dropsNear(x21, y21, 20, t, t + 3600).first;
      List<WorldSpawn> sparks(int at) => [for (final s in w.extras(x21: d.x, y21: d.y, radiusM: 20, t: at, metersPerCell21: mpc, levelOf: (id, add, uid) => 3)) if (s.uid == fnv1a64([d.uid, 2])) s];
      expect(sparks(d.tUtc + 10).single.entryId, 'item.dust.fire');
      expect(sparks(d.tUtc + 10).single.isSpark, isTrue);
      expect(sparks(d.tUtc + 301), isEmpty);
      expect(math.max(1, catalog.piece('dry_bolt').glowS), 300);
    });
  });
}

/// Tirados com o bloco `climate` da época 6 publicado na 0.16.0 (commit 42df7d0); o comportamento foi conferido também com
/// o `climate.dart` da 0.16.0.
const int _e6ClimateJson = -7022951198357737936;
const int _e6ClimateBehavior = -784045845125105133;

/// Tirados com o bloco `climate` da época 7 publicado na 0.17.0 (commit f24155a), com o `climate.dart` dessa versão.
const int _e7ClimateJson = 7839597196110545926;
const int _e7ClimateBehavior = -4745010646301111484;
const int _e7ResolveYear = 1956781955064653655;
