import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/spawn.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/core/windows.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';

import '../support/fixtures.dart';

void main() {
  final schedule = loadEpochs();
  final map = RegionMap(pack: loadCampinasPack(), biomes: loadBiomes());
  final seed = seedGlobal('KENOMA-TESTE');
  const t0 = 1790035200 + 86400; // um dia depois do começo da época 0
  SpawnField field([int s = 0]) => SpawnField(seed: s == 0 ? seed : s, schedule: schedule, map: map);
  final (lat, lon) = kCentroCampinas;

  List<WorldSpawn> look(SpawnField f, int t, {int level = 1, double radius = 120}) =>
      f.around(lat: lat, lon: lon, tUtc: t, radiusM: radius, playerLevel: level);

  test('dois aparelhos com a mesma seed, época e hora veem os mesmos spawns', () {
    final a = look(field(), t0), b = look(field(), t0);
    expect(a, isNotEmpty);
    expect([for (final s in a) (s.uid, s.entryId, s.x, s.y, s.quantity, s.level)],
        [for (final s in b) (s.uid, s.entryId, s.x, s.y, s.quantity, s.level)]);
  });

  test('outra seed muda o mundo', () {
    final a = {for (final s in look(field(), t0)) s.uid};
    final b = {for (final s in look(field(seedGlobal('OUTRO-GRUPO')), t0)) s.uid};
    expect(a.intersection(b), isEmpty);
  });

  test('uid bate com a spec e é único na área', () {
    final spawns = look(field(), t0);
    expect({for (final s in spawns) s.uid}.length, spawns.length);
    final s = spawns.first;
    expect(s.uid, spawnUid(seed, 0, s.cellX, s.cellY, s.window, _indexOf(s.kind, s.uid, s.cellX, s.cellY, s.window)));
  });

  test('tudo fica dentro do raio pedido e dentro da célula de origem', () {
    final (px, py) = latLonToTileFraction(lat, lon, biomeZoom);
    final mpc = metersPerCell(lat);
    for (final s in look(field(), t0, radius: 60)) {
      expect(s.distanceM(px, py, mpc), lessThanOrEqualTo(60));
      expect((s.x / 2).floor(), s.cellX);
      expect((s.y / 2).floor(), s.cellY);
    }
    expect(look(field(), t0, radius: 120).length, greaterThanOrEqualTo(look(field(), t0, radius: 60).length));
  });

  test('a janela vira por célula: o entorno se renova aos poucos, não tudo de uma vez', () {
    final f = field();
    final before = {for (final s in look(f, t0, radius: 300)) s.uid};
    final after = {for (final s in look(f, t0 + 300, radius: 300)) s.uid}; // 5 min depois
    final kept = before.intersection(after).length;
    expect(kept, greaterThan(before.length ~/ 2), reason: 'a maioria das células ainda está na mesma janela');
    expect(kept, lessThan(before.length), reason: 'algumas já viraram');
    final later = {for (final s in look(f, t0 + windowSeconds, radius: 300)) s.uid};
    expect(before.intersection(later), isEmpty, reason: 'depois de 20 min todas viraram: o uid inclui a janela');
  });

  test('o nível do Eco é o do Conjurador mais o delta, entre 1 e 20, e fica guardado pelo uid', () {
    final f = field();
    for (final s in look(f, t0, level: 15, radius: 400).where((s) => s.isEco)) {
      expect(s.level, inInclusiveRange(13, 17));
    }
    final first = {for (final s in look(f, t0, level: 15, radius: 400).where((s) => s.isEco)) s.uid: s.level};
    final again = {for (final s in look(f, t0, level: 5, radius: 400).where((s) => s.isEco)) s.uid: s.level};
    expect(again, first, reason: 'subir de nível não muda um Eco que já foi visto');
    for (final s in look(field(), t0, level: 1, radius: 400).where((s) => s.isEco)) {
      expect(s.level, inInclusiveRange(1, 3));
    }
  });

  test('só Ecos têm nível; os três tipos de item aparecem num trecho grande', () {
    final all = look(field(), t0, radius: 600);
    expect(all.where((s) => !s.isEco).every((s) => s.level == null), isTrue);
    expect({for (final s in all) s.kind}, {'eco', 'spark', 'material'});
  });

  test('o relógio manda: a mesma hora dá o mesmo mundo, em qualquer sequência de consultas', () {
    final f = field();
    final a = look(f, t0);
    look(f, t0 + 7200);
    final b = look(f, t0);
    expect([for (final s in a) s.uid], [for (final s in b) s.uid]);
  });
}

/// Descobre o índice do item (0 a 3) cujo uid bate, para conferir a fórmula da spec.
int _indexOf(String kind, int uid, int cx, int cy, int window) {
  for (var i = 0; i < 4; i++) {
    if (spawnUid(seedGlobal('KENOMA-TESTE'), 0, cx, cy, window, i) == uid) return i;
  }
  throw StateError('uid sem índice');
}
