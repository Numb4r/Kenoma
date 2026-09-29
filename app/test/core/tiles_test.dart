import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';

import '../support/fixtures.dart';

void main() {
  test('vetor da spec: tile z20 e z21', () {
    expect(latLonToTile(vectorLat, vectorLon, 20), (387213, 592857));
    expect(latLonToTile(vectorLat, vectorLon, 21), (774426, 1185714));
  });

  test('spawnCellAt é o tile z20 e o pai do z21', () {
    expect(spawnCellAt(vectorLat, vectorLon), (vectorCellX, vectorCellY));
    expect(parentTile(latLonToTile(vectorLat, vectorLon, 21)), (vectorCellX, vectorCellY));
  });

  test('tile z0 é sempre (0, 0)', () {
    expect(latLonToTile(-22.9, -47.06, 0), (0, 0));
  });

  test('limites do mapa ficam dentro da grade', () {
    expect(latLonToTile(0, 180, 3), (7, 4));
    expect(latLonToTile(0, -180, 3), (0, 4));
    expect(latLonToTile(85.0511, 0, 3).$2, 0);
    expect(latLonToTile(-85.0511, 0, 3).$2, 7);
  });

  test('y cresce para o sul e x cresce para o leste', () {
    final (x0, y0) = latLonToTile(-22.9, -47.06, 21);
    final (x1, y1) = latLonToTile(-22.95, -47.0, 21);
    expect(x1, greaterThan(x0));
    expect(y1, greaterThan(y0));
  });

  test('a célula z20 do ponto contém a célula z21 do ponto', () {
    for (final (lat, lon) in [(-22.81, -47.07), (-22.99, -46.9), (-22.75, -47.2)]) {
      expect(parentTile(latLonToTile(lat, lon, 21)), latLonToTile(lat, lon, 20));
    }
  });
}
