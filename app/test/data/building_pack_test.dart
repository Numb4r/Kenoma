import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/building_pack.dart';

/// 0.22.0: o arquivo de prédios de Campinas (`pipeline/build_buildings.py`), só cenário do estilo Completo.
void main() {
  final pack = BuildingPack.parse(File('assets/regions/campinas_e0_bldg.bin').readAsBytesSync());

  test('lê os 32.116 prédios e as 1.760 árvores do extrato da época 0', () {
    expect(pack.buildings.length, 32116);
    expect(pack.treeCount, 1760);
    expect(pack.buildings.every((b) => b.length >= 3), isTrue);
  });

  test('a busca por retângulo devolve os prédios do Centro e só os que caem nele', () {
    final (x, y) = latLonToTileFraction(-22.9056, -47.0608, biomeZoom); // Centro de Campinas
    final got = pack.buildingsIn(x - 4, y - 4, x + 4, y + 4, margin: 0).toList();
    expect(got, isNotEmpty);
    for (final b in got) {
      expect((b.centroid.$1 - x).abs(), lessThanOrEqualTo(4));
      expect((b.centroid.$2 - y).abs(), lessThanOrEqualTo(4));
    }
    final brute = pack.buildings.where((b) => (b.centroid.$1 - x).abs() <= 4 && (b.centroid.$2 - y).abs() <= 4).length;
    expect(got.length, brute);
  });

  test('magic errado é recusado', () {
    expect(() => BuildingPack.parse(File('assets/regions/campinas_e0_cycle.bin').readAsBytesSync()), throwsFormatException);
  });
}
