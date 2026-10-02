import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/world/region_map.dart';

import '../support/fixtures.dart';

void main() {
  final map = RegionMap(pack: loadCampinasPack(), biomes: loadBiomes());
  final pack = map.pack;

  group('conversões fracionárias de tile', () {
    test('a parte inteira é o tile de latLonToTile, em vários zooms', () {
      for (final z in [15, 20, 21]) {
        final (fx, fy) = latLonToTileFraction(vectorLat, vectorLon, z);
        final (x, y) = latLonToTile(vectorLat, vectorLon, z);
        expect((fx.floor(), fy.floor()), (x, y), reason: 'z$z');
      }
    });

    test('o vetor da spec cai na célula z21 do vetor', () {
      final (fx, fy) = latLonToTileFraction(vectorLat, vectorLon, 20);
      expect((fx.floor(), fy.floor()), (vectorCellX, vectorCellY));
    });

    test('ida e volta devolve a mesma coordenada (Unicamp, centro, extremos da região)', () {
      for (final (lat, lon) in [(-22.8174, -47.0697), (vectorLat, vectorLon), (-23.10, -47.25), (-22.72, -46.85), (0.0, 0.0)]) {
        final (x, y) = latLonToTileFraction(lat, lon, 21);
        final (la, lo) = tileFractionToLatLon(x, y, 21);
        expect(la, closeTo(lat, 1e-9));
        expect(lo, closeTo(lon, 1e-9));
      }
    });

    test('um passo de uma célula z21 em Campinas vale ~17,6 m (19,1 m no equador vezes cos 22,8°)', () {
      final (x, y) = latLonToTileFraction(-22.8174, -47.0697, 21);
      final (lat0, lon0) = tileFractionToLatLon(x, y, 21);
      final (lat1, lon1) = tileFractionToLatLon(x + 1, y, 21);
      expect((lat1 - lat0).abs(), lessThan(1e-9), reason: 'leste não muda a latitude');
      // 1 grau de longitude em -22,8 ≈ 102,6 km
      expect((lon1 - lon0) * 102600, closeTo(17.6, 0.2));
    });
  });

  group('RegionMap', () {
    test('bioma de uma célula z21 dentro do pacote é o do pacote', () {
      for (var i = 0; i < 40; i++) {
        final x = pack.x0 + (i * 53) % pack.width;
        final y = pack.y0 + (i * 97) % pack.height;
        expect(map.biomeAtCell(x, y), pack.biomeAt(x, y));
        expect(map.containsCell(x, y), isTrue);
      }
    });

    test('fora da bbox do pacote vale Vazio, em células e em lat/lon', () {
      expect(map.biomeAtCell(0, 0), voidBiomeId);
      expect(map.containsCell(0, 0), isFalse);
      expect(map.biomeAtCell(pack.x0 - 5, pack.y0 + 10), voidBiomeId);
      expect(map.biomeAtCell(pack.x0 + pack.width + 100, pack.y0), voidBiomeId);
      for (final (lat, lon) in [(0.0, 0.0), (-23.5, -46.6), (-22.0, -47.5), (51.5, -0.12), (-89.0, 179.0), (85.0, -179.9)]) {
        expect(map.biomeAtLatLon(lat, lon), voidBiomeId, reason: '$lat,$lon');
      }
    });

    test('lat/lon e célula dão o mesmo bioma', () {
      for (final (lat, lon) in [(-22.8174, -47.0697), (vectorLat, vectorLon), (-22.95, -47.1), (-22.8, -46.95)]) {
        final (x, y) = latLonToTile(lat, lon, biomeZoom);
        expect(map.biomeAtLatLon(lat, lon), map.biomeAtCell(x, y));
      }
    });

    test('Campinas tem de tudo e a maior parte da bbox da região é mapeada', () {
      final seen = <int>{};
      for (var y = pack.y0; y < pack.y0 + pack.height; y += 11) {
        for (var x = pack.x0; x < pack.x0 + pack.width; x += 11) {
          seen.add(map.biomeAtCell(x, y));
        }
      }
      expect(seen.length, 5);
    });

    test('bioma de spawn z20 é a moda das quatro células z21, com a maior prioridade no empate', () {
      for (var i = 0; i < 200; i++) {
        final x = pack.x0 ~/ 2 + (i * 31) % (pack.width ~/ 2);
        final y = pack.y0 ~/ 2 + (i * 57) % (pack.height ~/ 2);
        expect(map.spawnBiomeAtCell(x, y), map.biomes.spawnCellBiome(pack.quadOf(x, y)));
      }
      expect(map.spawnBiomeAtLatLon(0.0, 0.0), voidBiomeId, reason: 'fora do pacote as quatro são Vazio');
      final (cx, cy) = spawnCellAt(vectorLat, vectorLon);
      expect(map.spawnBiomeAtLatLon(vectorLat, vectorLon), map.spawnBiomeAtCell(cx, cy));
    });
  });
}
