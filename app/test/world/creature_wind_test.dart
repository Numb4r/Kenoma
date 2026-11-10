import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/data/climate_catalog.dart';
import 'package:kenoma/world/creature_wind.dart';
import 'package:kenoma/world/spawn_field.dart';

WorldSpawn spawn(String kind, String id, {int? level, int uid = 7}) =>
    WorldSpawn(uid: uid, kind: kind, entryId: id, quantity: 1, x: 10, y: 10, cellX: 5, cellY: 5, window: 0, level: level);

void main() {
  final climas = ClimateCatalog.fromJson(jsonDecode(File('assets/data/clima.json').readAsStringSync()) as Map<String, dynamic>);
  final b = ClimateBalance.fromJson((jsonDecode(File('assets/data/balance.json').readAsStringSync()) as Map<String, dynamic>)['climate'] as Map<String, dynamic>).creatureWind;

  test('Vento, Vendaval, Tornado e Furacão sopram, cada um mais forte; os outros climas não', () {
    double f(String id) => climas.climates[id]!.windForce;
    expect(f('wind'), greaterThan(0));
    expect(f('gale'), greaterThan(f('wind')));
    expect(f('tornado'), greaterThan(f('gale')));
    expect(f('hurricane'), greaterThan(f('tornado')));
    expect(f('rain'), 0);
    expect(f('clear'), 0);
  });

  test('os leves são empurrados alguns metros e voltam devagar quando o vento cai; os pesados só se inclinam', () {
    final w = CreatureWind(b);
    final spark = spawn('spark', 'item.dust.fire'), light = spawn('eco', 'soot.eco', level: 2), heavy = spawn('eco', 'soot.eco', level: 20);
    final spirit = spawn('eco', 'ialprg.spirit', level: 1), material = spawn('material', 'item.chalk');
    expect(w.pushM(spark, 0), 0, reason: 'sem vento, nada');
    expect(w.lean(1, 0), 0);
    for (var i = 0; i < 60; i++) {
      w.update(0.5, 1); // 30 s de Furacão
    }
    expect(w.force, closeTo(1, 0.01));
    expect(w.pushM(spark, 3), inInclusiveRange(b.pushM * 0.7, b.pushM));
    expect(w.pushM(light, 3), greaterThan(2));
    for (final s in [heavy, spirit, material]) {
      expect(w.pushM(s, 3), 0, reason: s.entryId);
    }
    expect(w.lean(heavy.uid, 3), greaterThan(0), reason: 'todos se inclinam');
    expect(w.lean(heavy.uid, 3), lessThanOrEqualTo(b.leanDeg * 3.1416 / 180));
    expect(w.motes(light.uid, 3).length, b.motes);
    // O vento cai: depois de 10 s o empurrão ainda está lá, e some aos poucos.
    final last = w.pushM(spark, 3);
    for (var i = 0; i < 20; i++) {
      w.update(0.5, 0);
    }
    final after10 = w.pushM(spark, 3);
    expect(after10, greaterThan(last * 0.8), reason: 'volta devagar');
    expect(after10, lessThan(last));
    for (var i = 0; i < 2000; i++) {
      w.update(0.5, 0);
    }
    expect(w.pushM(spark, 3), 0);
    expect(w.motes(light.uid, 3), isEmpty);
  });

  test('partículas e balanço só dependem do tempo e do uid', () {
    final a = CreatureWind(b)..force = 0.6, c = CreatureWind(b)..force = 0.6;
    expect(a.motes(99, 12.5), c.motes(99, 12.5));
    expect(a.lean(99, 12.5), c.lean(99, 12.5));
    for (final m in a.motes(99, 12.5)) {
      expect(m.along, inInclusiveRange(0, 1));
      expect(m.side.abs(), lessThanOrEqualTo(1));
    }
  });
}
