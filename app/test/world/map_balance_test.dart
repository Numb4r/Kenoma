import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/world/map_balance.dart';

import '../support/fixtures.dart';

void main() {
  test('os raios vêm do balance.json: Aura de 40 m, spawns e rastreador até 120 m', () {
    final b = MapBalance(loadJson('assets/data/balance.json'));
    expect((b.auraM, b.viewM, b.trackerM), (40.0, 120.0, 120.0));
    expect(b.auraM, lessThan(b.viewM));
  });

  test('um raio diferente no JSON muda o balance sem mexer no código', () {
    final b = MapBalance({'map': {'aura_m': 55, 'view_m': 150.5, 'tracker_m': 90}});
    expect((b.auraM, b.viewM, b.trackerM), (55.0, 150.5, 90.0));
  });

  group('metersPerCell', () {
    test('em Campinas a célula z21 mede ~17,6 m e a de spawn z20 ~35 m', () {
      expect(metersPerCell(-22.8174), closeTo(17.6, 0.1));
      expect(metersPerCell(-22.8174, zoom: 20), closeTo(35.3, 0.1));
      expect(metersPerCell(-22.9056, zoom: 20), closeTo(35.2, 0.2), reason: 'a spec diz cerca de 35 m');
    });

    test('no equador é 19,1 m, cai com a latitude e é simétrico', () {
      expect(metersPerCell(0), closeTo(19.109, 0.001));
      expect(metersPerCell(60), closeTo(19.109 / 2, 0.001));
      expect(metersPerCell(-30), closeTo(metersPerCell(30), 1e-9));
    });

    test('bate com o passo medido na própria projeção', () {
      final (x, y) = latLonToTileFraction(-22.8174, -47.0697, 21);
      final (lat0, lon0) = tileFractionToLatLon(x, y, 21);
      final (lat1, lon1) = tileFractionToLatLon(x + 1, y, 21);
      expect((lon1 - lon0).abs() * 111319.49 * 0.92174, closeTo(metersPerCell(lat0), 0.1));
      expect(lat1, closeTo(lat0, 1e-9));
    });
  });
}
