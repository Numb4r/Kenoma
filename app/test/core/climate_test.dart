import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/climate.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/spawn.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/ui/game/climate_fx.dart' show strikeVisibleFor;
import 'package:kenoma/world/climate_world.dart';
import 'package:kenoma/world/spawn_field.dart';

import '../support/fixtures.dart';

void main() {
  final seed = seedGlobal('KENOMA-TESTE');
  final data = loadGameData();

  /// Um aparelho: lê o epochs.json do zero (nada compartilhado na memória com o outro).
  ClimateWorld device({String? forced, String? Function(String, double)? species}) => ClimateWorld(
        seed: seed,
        schedule: loadEpochs(),
        speciesOfType: species ?? data.ecoOfType,
        itemExists: data.itemNames.containsKey,
        forced: () => forced,
      );

  final e6 = loadEpochs().epochs.firstWhere((e) => e.id == 6);
  final model = e6.climate!;
  final t0 = e6.startsUtc + 7 * 86400; // janeiro de 2030: verão
  final (cx20, cy20) = latLonToTile(-22.8174, -47.0697, 20); // Unicamp
  final natives = {for (final d in model.defs.values) if (d.category == ClimateCategory.native) d.id};

  group('sorteio do clima', () {
    test('é o mesmo em dois aparelhos com a mesma seed, por janela de 3 h e região', () {
      final a = device(), b = device();
      for (var k = 0; k < 400; k++) {
        final t = t0 + k * 3600;
        expect(a.idAt(cx20 + k % 3 * 300, cy20, t), b.idAt(cx20 + k % 3 * 300, cy20, t));
      }
      final other = ClimateWorld(seed: seed + 1, schedule: loadEpochs(), speciesOfType: data.ecoOfType, itemExists: (_) => true);
      expect([for (var k = 0; k < 200; k++) other.idAt(cx20, cy20, t0 + k * 10800)], isNot([for (var k = 0; k < 200; k++) a.idAt(cx20, cy20, t0 + k * 10800)]));
    });

    test('só sorteia nativos, o ano inteiro', () {
      final w = device();
      for (var k = 0; k < 365 * 8; k += 3) {
        expect(natives, contains(w.idAt(cx20, cy20, t0 + k * 10800)));
      }
      expect(natives.length, 14);
    });

    test('segue as estações de Campinas pela hora local de Brasília (offset fixo em dado)', () {
      int count(Iterable<String> xs, Set<String> want) => xs.where(want.contains).length;
      // Verão (janeiro), janela das 15 h às 18 h local = 18 h às 21 h UTC.
      final summerWindows = [for (var d = 0; d < 400; d++) ((t0 - t0 % 86400) + d % 60 * 86400 + 18 * 3600) ~/ 10800];
      final stormsSummer = count([for (var i = 0; i < 400; i++) model.drawn(seed, summerWindows[i], 100 + i, 200)], {'storm', 'rain'});
      // Inverno (julho), janela das 6 h às 9 h local = 9 h às 12 h UTC.
      final july = DateTime.utc(2030, 7, 1).millisecondsSinceEpoch ~/ 1000;
      final winterWindows = [for (var d = 0; d < 400; d++) (july + d % 60 * 86400 + 9 * 3600) ~/ 10800];
      final winterDraws = [for (var i = 0; i < 400; i++) model.drawn(seed, winterWindows[i], 100 + i, 200)];
      expect(stormsSummer, greaterThan(120), reason: 'verão de tarde: tempestade e chuva');
      expect(count(winterDraws, {'fog', 'cold'}), greaterThan(160), reason: 'inverno de manhã: neblina e frio');
      expect(count(winterDraws, {'storm'}), 0);
      expect(model.localMonthHour(winterWindows.first), (7, 7), reason: 'meio da janela das 9 h às 12 h UTC = 7 h30 em Brasília');
    });

    test('o arco-íris só sai logo depois de chuva, garoa, tempestade ou granizo', () {
      var seen = 0;
      for (var w = t0 ~/ 10800; w < t0 ~/ 10800 + 4000; w++) {
        if (model.drawn(seed, w, 7, 9) != 'rainbow') continue;
        seen++;
        expect({'rain', 'storm', 'drizzle', 'hail'}, contains(model.drawn(seed, w - 1, 7, 9)));
      }
      expect(seen, greaterThan(0));
    });

    test('evento do feed assinado força qualquer clima (inclusive místico); entrada antiga ou quebrada é ignorada', () {
      final w = device();
      final start = DateTime.fromMillisecondsSinceEpoch(t0 * 1000, isUtc: true);
      final ev = [
        {'id': 'antigo', 'name': 'Evento do formato antigo'},
        {'kind': 'climate', 'climate': 'spark_rain', 'starts_utc': 'quebrado', 'ends_utc': 'x'},
        {'kind': 'climate', 'climate': 'spark_rain', 'starts_utc': start.toIso8601String(), 'ends_utc': start.add(const Duration(hours: 6)).toIso8601String()},
      ];
      w.events = [for (final e in ev) ?ClimateEvent.tryParse(e)];
      expect(w.events.length, 1);
      expect(w.idAt(cx20, cy20, t0 + 3600), 'spark_rain');
      expect(natives, contains(w.idAt(cx20, cy20, t0 + 9 * 3600)), reason: 'depois do evento volta o sorteio');
    });

    test('antes da época 6 vale o modelo antigo de quatro estados, igual ao de antes', () {
      final w = device();
      final e5 = loadEpochs().epochs.firstWhere((e) => e.id == 5);
      final t = e5.startsUtc + 3600;
      final legacy = e5.ecoV2!.weather.at(seed: seed, tUtc: t, regionX: cx20 ~/ 256, regionY: cy20 ~/ 256).id;
      expect(w.idAt(cx20, cy20, t), legacy);
      expect(w.dropsNear(cx20 * 2.0, cy20 * 2.0, 100, t - 3600, t), isEmpty, reason: 'sem peças antes da época 6');
    });
  });

  group('raios', () {
    final x21 = cx20 * 2.0 + 1, y21 = cy20 * 2.0 + 1;
    final mpc = metersPerCell(-22.8174);

    test('caem a cada 20 a 60 s por célula z17, no mesmo ponto para dois aparelhos em lugares diferentes', () {
      final a = device(forced: 'storm'), b = device(forced: 'storm');
      final da = a.dropsNear(x21, y21, 2, t0, t0 + 1800);
      final db = b.dropsNear(x21 + 9, y21 - 7, 2, t0, t0 + 1800); // o outro está a ~200 m, olhando a mesma célula
      final common = {for (final d in db) d.uid: d};
      final shared = [for (final d in da) if (common.containsKey(d.uid)) (d, common[d.uid]!)];
      expect(shared, isNotEmpty);
      for (final (p, q) in shared) {
        expect((p.tUtc, p.x, p.y), (q.tUtc, q.x, q.y));
      }
      final cell = [for (final d in da) if ((d.x ~/ 16, d.y ~/ 16) == (x21 ~/ 16, y21 ~/ 16)) d.tUtc]..sort();
      for (var i = 1; i < cell.length; i++) {
        expect(cell[i] - cell[i - 1], inInclusiveRange(20, 60));
      }
    });

    test('nunca aparecem a menos de 15 m do jogador; o ponto do raio não depende de quem olha', () {
      final w = device(forced: 'storm');
      final strike = w.dropsNear(x21, y21, 2, t0, t0 + 600).first;
      const minM = 15.0;
      final near = (strike.x + 10 / mpc, strike.y); // a 10 m
      final far = (strike.x + 80 / mpc, strike.y); // a 80 m
      expect(strikeVisibleFor(strike, near.$1, near.$2, mpc, minM), isFalse);
      expect(strikeVisibleFor(strike, far.$1, far.$2, mpc, minM), isTrue);
      final again = device(forced: 'storm').dropsNear(near.$1, near.$2, 2, t0, t0 + 600).firstWhere((d) => d.uid == strike.uid);
      expect((again.x, again.y, again.tUtc), (strike.x, strike.y, strike.tUtc), reason: 'quem está perto não muda onde o raio cai');
      // Com a regra dos 15 m: dos raios de meia hora em volta, nenhum que aparece está a menos de 15 m.
      for (final d in w.dropsNear(x21, y21, 40, t0, t0 + 1800)) {
        if (strikeVisibleFor(d, x21, y21, mpc, minM)) {
          expect(math.sqrt((d.x - x21) * (d.x - x21) + (d.y - y21) * (d.y - y21)) * mpc, greaterThanOrEqualTo(minM));
        }
      }
    });

    test('às vezes nasce um Eco no ponto do raio: hoje um Sootling carregado (provisório), igual nos dois aparelhos', () {
      List<WorldSpawn> ecos(ClimateWorld w, int t) => [
            for (final s in w.extras(x21: x21, y21: y21, radiusM: 600, t: t, metersPerCell21: mpc, levelOf: (id, add, uid) => 5 + add))
              if (s.isEco) s,
          ];
      final a = device(forced: 'storm'), b = device(forced: 'storm');
      var found = 0;
      for (var t = t0; t < t0 + 3 * 3600 && found < 3; t += 300) {
        final ea = ecos(a, t), eb = ecos(b, t);
        expect([for (final e in ea) (e.uid, e.x, e.y, e.entryId)], [for (final e in eb) (e.uid, e.x, e.y, e.entryId)]);
        for (final e in ea) {
          expect((e.entryId, e.tag), ('soot.eco', 'charged'));
          found++;
        }
      }
      expect(found, greaterThan(0), reason: 'chance de 8% por raio em 3 h de tempestade');
      // Quando existir a espécie Elétrica, o dado escolhe por tipo e o fallback deixa de valer.
      final future = device(forced: 'storm', species: (type, pick) => type == 'electric' ? 'volt.eco' : data.ecoOfType(type, pick));
      final some = [for (var t = t0; t < t0 + 3 * 3600; t += 300) ...ecos(future, t)];
      expect(some.map((e) => e.entryId).toSet(), {'volt.eco'});
    });
  });

  group('outras peças', () {
    final mpc = metersPerCell(-22.8174);

    test('Onda de calor: a Fagulha some 2 min depois de nascer; Vento: deriva até o limite, igual para todos', () {
      final hot = device(forced: 'heat_wave'), windy = device(forced: 'wind'), windy2 = device(forced: 'wind');
      final spark = WorldSpawn(uid: 1, kind: 'spark', entryId: 'item.dust.fire', quantity: 1, x: cx20 * 2.0 + 1, y: cy20 * 2.0 + 1, cellX: cx20, cellY: cy20, window: 0);
      expect(hot.adjustSpark(spark, t0, t0 + 60, mpc), isNotNull);
      expect(hot.adjustSpark(spark, t0, t0 + 121, mpc), isNull);
      final moved = windy.adjustSpark(spark, t0, t0 + 1000, mpc)!;
      final moved2 = windy2.adjustSpark(spark, t0, t0 + 1000, mpc)!;
      expect((moved.x, moved.y), (moved2.x, moved2.y));
      final dm = math.sqrt(math.pow(moved.x - spark.x, 2) + math.pow(moved.y - spark.y, 2)) * mpc;
      expect(dm, closeTo(12, 0.01), reason: 'drift_max_m do vento');
    });

    test('Chuva: poças fazem nascer Ecos de Água e água pura; Garoa Prismática dobra a chance de Brilhante', () {
      final w = device(forced: 'rain');
      final x21 = cx20 * 2.0, y21 = cy20 * 2.0;
      final found = <String>{};
      for (var t = t0; t < t0 + 3 * 3600; t += 600) {
        for (final s in w.extras(x21: x21, y21: y21, radiusM: 800, t: t, metersPerCell21: mpc, levelOf: (id, add, uid) => 3)) {
          found.add(s.entryId);
        }
      }
      expect(found, containsAll(['rill.eco', 'item.pure_water']));
      expect(found.difference({'rill.eco', 'item.pure_water'}), isEmpty);
      int shinies(double mult) => [
            for (var i = 0; i < 20000; i++)
              generateCell(seed: seed, epoch: e6, cellX: 387000 + i % 200, cellY: 592000 + i ~/ 200, window: 1491667, biomeKey: 'green', shinyMult: mult).first,
          ].where((s) => s.shiny).length;
      expect(model.def('prismatic_drizzle')!.modifier!.shinyMult, 2);
      expect(shinies(2), greaterThan(shinies(1)));
    });

    test('Neblina e Nevasca cortam a visão; Estática dá ruído, menos ao Tecnomante; Silêncio acalma', () {
      final x21 = cx20 * 2.0, y21 = cy20 * 2.0;
      expect(device(forced: 'fog').modsAt(x21, y21, t0).viewMaxM, 60);
      final bl = device(forced: 'blizzard').modsAt(x21, y21, t0);
      expect((bl.viewMaxM, bl.auraAddM), (40, -2));
      final st = device(forced: 'static').modsAt(x21, y21, t0);
      expect((st.wanderFor(null), st.wanderFor('technomancer')), (1.6, 1));
      expect(device(forced: 'silence').modsAt(x21, y21, t0).calm, isTrue);
      expect(device(forced: 'aurora').modsAt(x21, y21, t0).toleranceMult, 1.25);
    });

    test('o debug dispara raio, granizo, redemoinho e meteoro num ponto tocado, só neste aparelho', () {
      final w = device(), other = device();
      final x21 = cx20 * 2.0, y21 = cy20 * 2.0;
      for (final name in ['lightning', 'hail', 'dust_devil', 'meteor']) {
        expect(w.debugTrigger(name, x21, y21, t0), isTrue, reason: name);
      }
      expect(w.debugTrigger('nada', x21, y21, t0), isFalse);
      expect(w.dropsNear(x21, y21, 1, t0, t0).where((d) => d.pieceIndex == -1).length, 3);
      expect(w.zonesNear(x21, y21, 1, t0 + 1).where((z) => z.pieceIndex == -1).length, 1);
      expect(other.debugDrops, isEmpty);
      final born = w.extras(x21: x21, y21: y21, radiusM: 30, t: t0 + 1, metersPerCell21: mpc, levelOf: (id, add, uid) => 3);
      expect(born.where((s) => s.tag == 'charged'), hasLength(1), reason: 'o raio do debug sempre deixa o Eco carregado');
    });
  });
}
