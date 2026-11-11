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
  ClimateWorld device({String? forced}) {
    final visual = VisualMap(VisualPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync())), cacheTiles: 64);
    final relief = ReliefPack.parse(File('assets/regions/campinas_e9_relief.bin').readAsBytesSync());
    final fields = <int, WaterField>{};
    return ClimateWorld(
      seed: seed,
      schedule: loadEpochs(),
      speciesOfType: data.ecoOfType,
      itemExists: data.itemNames.containsKey,
      itemSince: (id) => data.itemSinceEpoch[id],
      snapper: WalkPaths(visual),
      relief: relief,
      water: (e) => e.water == null ? null : fields[e.id] ??= WaterField(relief: relief, visual: visual, model: e.water!),
      typeOf: (id) => data.species(id)?.type.name,
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
