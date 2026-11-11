import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/behavior.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/relief_pack.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/climate_world.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/street_dirs.dart';
import 'package:kenoma/world/visual_map.dart';
import 'package:kenoma/world/walk_paths.dart';
import 'package:kenoma/world/water_field.dart';

import '../support/fixtures.dart';

int utc(int y, int m, int d, [int h = 0]) => DateTime.utc(y, m, d, h).millisecondsSinceEpoch ~/ 1000;

/// A época 9: relevo, água que escorre, neblina nas baixadas e movimento de Ecos e Fagulhas. Tudo o que muda o jogo tem de
/// sair igual em dois aparelhos.
void main() {
  final seed = seedGlobal('KENOMA-TESTE');
  final data = loadGameData();
  final e9 = loadEpochs().epochs.firstWhere((e) => e.id == 9);
  const lat = -22.9056, lon = -47.0608; // Centro
  final (x21, y21) = latLonToTileFraction(lat, lon, 21);
  final mpc = metersPerCell(lat);

  /// Um aparelho: lê tudo do zero (nada compartilhado na memória com o outro).
  ClimateWorld device({String? forced, int? upTo = 9}) {
    final visual = VisualMap(VisualPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync())), cacheTiles: 64);
    final relief = ReliefPack.parse(File('assets/regions/campinas_e9_relief.bin').readAsBytesSync());
    final fields = <int, WaterField>{};
    return ClimateWorld(
      seed: seed,
      schedule: upTo == null ? loadEpochs() : loadEpochsUpTo(upTo),
      speciesOfType: data.ecoOfType,
      itemExists: data.itemNames.containsKey,
      itemSince: (id) => data.itemSinceEpoch[id],
      snapper: WalkPaths(visual),
      relief: relief,
      water: (e) => e.water == null ? null : fields[e.id] ??= WaterField(relief: relief, visual: visual, model: e.water!),
      typeOf: (id) => data.species(id)?.type.name,
      streets: StreetDirs(visual),
      forced: () => forced,
    );
  }

  final t0 = utc(2026, 12, 1, 15);

  test('a época 9 fixa o relevo e traz a água, a neblina e o movimento', () {
    expect(e9.reliefPacks['campinas']!.sha256, '1bb9c5acd6f6e09f49af449b7bd7f026cc30d237fa167bf4ac209278481e7d86');
    expect(e9.water, isNotNull);
    expect(e9.fog!.climates, contains('fog'));
    expect(e9.motion!.wanderM, 3.5);
    final e8 = loadEpochs().epochs.firstWhere((e) => e.id == 8);
    expect((e8.water, e8.fog, e8.motion), (null, null, null), reason: 'a época 8 continua como era');
    expect(e8.reliefPacks, isEmpty);
  });

  test('poças: onde a água se junta, iguais em dois aparelhos, mais baixas que a vizinhança', () {
    final a = device(forced: 'rain'), b = device(forced: 'rain');
    final pa = a.puddlesNear(x21, y21, 40, t0 + 3000), pb = b.puddlesNear(x21, y21, 40, t0 + 3000);
    expect(pa, isNotEmpty);
    expect([for (final p in pa) (p.x, p.y, p.radiusM, p.rolls.uid)], [for (final p in pb) (p.x, p.y, p.radiusM, p.rolls.uid)]);
    final relief = ReliefPack.parse(File('assets/regions/campinas_e9_relief.bin').readAsBytesSync());
    var lower = 0;
    for (final p in pa) {
      final h = relief.heightAt(p.x, p.y)!;
      var sum = 0.0;
      for (final (dx, dy) in [(6, 0), (-6, 0), (0, 6), (0, -6)]) {
        sum += relief.heightAt(p.x + dx, p.y + dy)!;
      }
      if (h <= sum / 4 + 0.3) lower++;
    }
    expect(lower / pa.length, greaterThan(0.6), reason: 'a maioria fica abaixo (ou no nível) do terreno a 100 m em volta');
  });

  test('Eco Passivo anda devagar perto de onde nasceu; Fagulha desliza para o redemoinho; iguais em dois aparelhos', () {
    final a = device(), b = device();
    WorldSpawn eco(double x, double y, {EcoBehavior behavior = EcoBehavior.passive, String id = 'soot.eco'}) =>
        WorldSpawn(uid: 4242, kind: 'eco', entryId: id, quantity: 1, x: x, y: y, cellX: x.floor() >>> 1, cellY: y.floor() >>> 1, window: 0, level: 3, behavior: behavior);
    final e = eco(x21, y21);
    var prev = a.move(e, t0, t0, mpc), far = 0.0, path = 0.0;
    for (var t = t0 + 1; t < t0 + 300; t++) {
      final p = a.move(e, t0, t, mpc), q = b.move(e, t0, t, mpc);
      expect((p.x, p.y), (q.x, q.y));
      final step = math.sqrt(math.pow((p.x - prev.x) * mpc, 2) + math.pow((p.y - prev.y) * mpc, 2));
      expect(step, lessThan(0.6));
      path += step;
      far = math.max(far, e.distanceM(p.x, p.y, mpc));
      prev = p;
    }
    expect(far, inInclusiveRange(1.5, 3.5 + 1e-6));
    expect(path, greaterThan(10));
    // Arisco, Agressivo e Oculto ficam onde nasceram (têm o comportamento deles).
    for (final bh in [EcoBehavior.skittish, EcoBehavior.aggressive, EcoBehavior.hidden]) {
      final s = eco(x21, y21, behavior: bh);
      expect(a.move(s, t0, t0 + 77, mpc).x, s.x);
    }
    // Na época 8 ninguém se move.
    final old = utc(2026, 11, 11, 0);
    expect(a.move(e, old, old + 50, mpc).x, e.x);
    // Fagulha.
    final spark = WorldSpawn(uid: 99, kind: 'spark', entryId: 'spark', quantity: 1, x: x21, y: y21, cellX: x21.floor() >>> 1, cellY: y21.floor() >>> 1, window: 0);
    final s0 = a.move(spark, t0, t0, mpc), s1 = a.move(spark, t0, t0 + 600, mpc);
    expect((s0.x, s0.y), (spark.x, spark.y), reason: 'nasce onde nasceu');
    final v = e9.motion!.vortexFor(seed, 9, x21, y21, mpc);
    if (v != null) {
      double d(WorldSpawn s) => math.sqrt(math.pow((s.x - v.$1) * mpc, 2) + math.pow((s.y - v.$2) * mpc, 2));
      expect(d(s1), lessThan(d(s0)), reason: 'chega mais perto do redemoinho');
      expect((s1.x, s1.y), (b.move(spark, t0, t0 + 600, mpc).x, b.move(spark, t0, t0 + 600, mpc).y));
    }
  });

  test('Eco de Água ronda a poça mais próxima', () {
    final a = device();
    final w = a.water!(e9)!;
    // Um ponto onde a água se junta perto do Centro, e um Eco de Água a 10 m dele.
    final spot = [
      for (var dy = -2; dy <= 2; dy++)
        for (var dx = -2; dx <= 2; dx++) ...?w.spots((x21.floor() >>> 4) + dx, (y21.floor() >>> 4) + dy, 5),
    ].first;
    final water = data.ecoOfType('water', 0.1)!;
    final s = WorldSpawn(uid: 7, kind: 'eco', entryId: water, quantity: 1, x: spot.x + 10 / mpc, y: spot.y, cellX: 0, cellY: 0, window: 0, level: 3);
    for (var t = t0; t < t0 + 120; t += 7) {
      final p = a.move(s, t0, t, mpc);
      final d = math.sqrt(math.pow((p.x - spot.x) * mpc, 2) + math.pow((p.y - spot.y) * mpc, 2));
      expect(d, closeTo(e9.motion!.waterOrbitM, 1e-6), reason: 'num círculo em volta da poça');
    }
  });

  group('época 10', () {
    final e10 = loadEpochs().epochs.firstWhere((e) => e.id == 10);
    final t10 = utc(2026, 12, 1, 15);

    test('lista o relevo de São Paulo e os números novos; a 9 continua como era', () {
      expect(e10.reliefPacks.keys, containsAll(['campinas', 'sao_paulo']));
      expect((e10.water!.poolMin, e10.water!.spotSpacing, e10.water!.wetPerCell), (2048, 3, 2));
      expect(e10.wind, isNotNull);
      expect((e9.water!.poolMin, e9.water!.spotSpacing, e9.water!.wetPerCell, e9.wind), (1100, 0, 0, null));
    });

    test('poças: de 2 a 3 por célula z17 em média (antes 1,3), iguais em dois aparelhos', () {
      final visual = VisualMap(VisualPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync())), cacheTiles: 64);
      final relief = ReliefPack.parse(File('assets/regions/campinas_e9_relief.bin').readAsBytesSync());
      double mean(WaterModel m) {
        final w = WaterField(relief: relief, visual: visual, model: m);
        var n = 0, cells = 0;
        for (var dy = -6; dy <= 6; dy++) {
          for (var dx = -6; dx <= 6; dx++) {
            n += w.spots((x21.floor() >>> 4) + dx, (y21.floor() >>> 4) + dy, 5)!.length;
            cells++;
          }
        }
        return n / cells;
      }

      final before = mean(e9.water!), after = mean(e10.water!);
      // ignore: avoid_print
      print('poças por célula z17 no Centro (teto 5): época 9 ${before.toStringAsFixed(2)}, época 10 ${after.toStringAsFixed(2)}');
      expect(before, lessThan(1.6));
      expect(after, inInclusiveRange(2.0, 3.0));
      final a = device(forced: 'rain', upTo: null), b = device(forced: 'rain', upTo: null);
      expect([for (final p in a.puddlesNear(x21, y21, 40, t10 + 3000)) (p.x, p.y, p.rolls.uid)], [for (final p in b.puddlesNear(x21, y21, 40, t10 + 3000)) (p.x, p.y, p.rolls.uid)]);
    });

    test('na chuva, trecho de rua molhado gera Eco de Água mesmo sem poça; fora da chuva não', () {
      final rain = device(forced: 'rain', upTo: null), dry = device(forced: 'clear', upTo: null), old = device(forced: 'rain');
      List<WorldSpawn> ecos(ClimateWorld w) => [for (final s in w.extras(x21: x21, y21: y21, radiusM: 400, t: t10, metersPerCell21: mpc, levelOf: (id, add, uid) => 5)) if (s.isEco) s];
      final puddles = rain.puddlesNear(x21, y21, 400 / mpc, t10);
      final wet = [for (final s in ecos(rain)) if (puddles.every((p) => s.distanceM(p.x, p.y, mpc) > 1)) s];
      expect(wet.length, greaterThan(3), reason: 'Ecos longe de qualquer poça');
      expect(wet.every((s) => data.species(s.entryId)?.type.name == 'water'), isTrue);
      expect(ecos(dry), isEmpty);
      expect(ecos(old).length, lessThan(ecos(rain).length), reason: 'na época 9 só as poças geram');
      final again = device(forced: 'rain', upTo: null);
      expect([for (final s in ecos(again)) s.uid], [for (final s in ecos(rain)) s.uid], reason: 'igual em dois aparelhos');
    });

    test('a deriva das Fagulhas segue o vento local: canalizada pela rua, menor atrás da quadra', () {
      final a = device(forced: 'gale', upTo: null), b = device(forced: 'gale', upTo: null), old = device(forced: 'gale');
      final streets = a.streets!;
      // Uma célula de rua e uma fora de rua perto do Centro.
      (int, int)? on, off;
      for (var dy = -30; dy <= 30 && (on == null || off == null); dy++) {
        for (var dx = -30; dx <= 30; dx++) {
          final cx = (x21.floor() >>> 1) + dx, cy = (y21.floor() >>> 1) + dy;
          final hit = streets.at(cx * 2 + 1, cy * 2 + 1) ?? streets.at(cx * 2, cy * 2);
          if (hit != null) {
            on ??= (cx, cy);
          } else {
            off ??= (cx, cy);
          }
        }
      }
      WorldSpawn spark((int, int) c) => WorldSpawn(uid: 5, kind: 'spark', entryId: 'spark', quantity: 1, x: c.$1 * 2 + 1.0, y: c.$2 * 2 + 1.0, cellX: c.$1, cellY: c.$2, window: 0);
      double moved(ClimateWorld w, (int, int) c) {
        final s = spark(c), m = w.adjustSpark(s, t10 - 600, t10, mpc);
        return m == null ? -1 : s.distanceM(m.x, m.y, mpc);
      }

      final straight = moved(old, off!);
      expect(straight, greaterThan(1), reason: 'o Vendaval leva as Fagulhas');
      expect(moved(a, off), closeTo(straight * 0.5, 0.05), reason: 'atrás da quadra: metade');
      expect(moved(a, on!), isNot(closeTo(straight, 0.01)), reason: 'na rua a deriva é a do eixo da rua');
      final ma = a.adjustSpark(spark(on), t10 - 600, t10, mpc)!, mb = b.adjustSpark(spark(on), t10 - 600, t10, mpc)!;
      expect((ma.x, ma.y), (mb.x, mb.y));
      // A deriva na rua é paralela ao eixo dela (mais os 15% do vento original).
      final d = streets.at(on.$1 * 2 + 1, on.$2 * 2 + 1) ?? streets.at(on.$1 * 2, on.$2 * 2)!;
      final vx = ma.x - spark(on).x, vy = ma.y - spark(on).y, len = math.sqrt(vx * vx + vy * vy);
      if (len > 0.05) expect((vx * d.$1 + vy * d.$2).abs() / len, greaterThan(0.5));
    });

    test('neve derretida vira poça que cresce e depois seca; poça rasa congela de madrugada no Frio', () {
      // Clima forçado: o de antes era Nevasca e acabou há pouco.
      ForcedPhase phase(double sinceEnd, {String prev = 'blizzard'}) => (ageS: sinceEnd, prevId: prev, prevFormedS: 3600, prevSinceEndS: sinceEnd);
      var since = 60.0;
      final w = ClimateWorld(
        seed: seed,
        schedule: loadEpochs(),
        speciesOfType: data.ecoOfType,
        itemExists: data.itemNames.containsKey,
        relief: ReliefPack.parse(File('assets/regions/campinas_e9_relief.bin').readAsBytesSync()),
        water: device(upTo: null).water,
        forced: () => 'cold',
        forcedPhase: () => phase(since),
      );
      double total() => w.puddlesNear(x21, y21, 40, t10).fold(0.0, (a, p) => a + p.size);
      final early = total();
      since = 500;
      final peak = total();
      since = 1500;
      final late = total();
      expect(early, greaterThan(0), reason: 'a neve começa a derreter');
      expect(peak, greaterThan(early));
      expect(late, lessThan(peak), reason: 'depois seca');
      since = 1800 * 1.6; // as mais fundas duram até 50% a mais
      expect(total(), 0);
      // De madrugada (4 h locais) no Frio, a poça já rasa é de gelo; à tarde, água.
      since = 1300;
      final dawn = utc(2026, 12, 2, 7), noon = utc(2026, 12, 2, 16);
      final iced = w.puddlesNear(x21, y21, 40, dawn), wet = w.puddlesNear(x21, y21, 40, noon);
      expect(iced.where((p) => p.size <= 0.5), isNotEmpty);
      expect(iced.where((p) => p.size <= 0.5).every((p) => p.frozen), isTrue);
      expect(iced.where((p) => p.size > 0.5).every((p) => !p.frozen), isTrue);
      expect(wet.every((p) => !p.frozen), isTrue);
      expect([for (final p in iced) (p.x, p.y)], [for (final p in wet) (p.x, p.y)], reason: 'no mesmo lugar');
    });
  });

  test('neblina: no vale enxerga menos que no morro, e o sol da manhã a desfaz', () {
    final a = device(forced: 'fog'), b = device(forced: 'fog');
    final relief = ReliefPack.parse(File('assets/regions/campinas_e9_relief.bin').readAsBytesSync());
    // O ponto mais baixo e o mais alto num quadrado de 1,5 km em volta do Centro.
    var lo = (x21, y21), hi = (x21, y21);
    for (var dy = -40.0; dy <= 40; dy += 4) {
      for (var dx = -40.0; dx <= 40; dx += 4) {
        final h = relief.heightAt(x21 + dx, y21 + dy)!;
        if (h < relief.heightAt(lo.$1, lo.$2)!) lo = (x21 + dx, y21 + dy);
        if (h > relief.heightAt(hi.$1, hi.$2)!) hi = (x21 + dx, y21 + dy);
      }
    }
    final night = utc(2026, 12, 1, 6); // 3 h locais: sem sol
    final valley = a.modsAt(lo.$1, lo.$2, night).viewMaxM!, hill = a.modsAt(hi.$1, hi.$2, night).viewMaxM!;
    expect(valley, lessThan(hill));
    expect(valley, inInclusiveRange(36 - 1e-6, 60));
    expect(hill, inInclusiveRange(60, 96 + 1e-6));
    expect(b.modsAt(lo.$1, lo.$2, night).viewMaxM, valley, reason: 'igual em dois aparelhos');
    expect(a.fogAt(lo.$1, lo.$2, night, e9, 'fog')!.density, greaterThan(a.fogAt(hi.$1, hi.$2, night, e9, 'fog')!.density));
    final noon = utc(2026, 12, 1, 15); // meio-dia local: sol alto
    expect(a.modsAt(lo.$1, lo.$2, noon).viewMaxM!, greaterThan(valley * 2), reason: 'com o sol alto a neblina se desfez');
    expect(a.fogAt(lo.$1, lo.$2, noon, e9, 'fog')!.density, 0);
    expect(a.fogAt(lo.$1, lo.$2, night, e9, 'rain'), isNull, reason: 'só nos climas de neblina');
  });
}
