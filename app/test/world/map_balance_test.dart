import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/world/aura.dart';
import 'package:kenoma/world/map_balance.dart';
import 'package:kenoma/world/map_scale.dart';

import '../support/fixtures.dart';

void main() {
  test('os raios vêm do balance.json: Aura de 25 m, spawns e rastreador até 120 m', () {
    final b = MapBalance(loadJson('assets/data/balance.json'));
    expect((b.auraM, b.viewM, b.trackerM), (25.0, 120.0, 120.0));
    expect(b.auraM, lessThan(b.viewM));
  });

  test('escala em metros: 90 m de largura no padrão, pinça de 70 a 120 m, sprites de 12 m e Fagulhas de 3 m', () {
    final b = MapBalance(loadJson('assets/data/balance.json'));
    expect((b.defaultWidthM, b.cameraMinWidthM, b.cameraMaxWidthM), (90.0, 70.0, 120.0));
    expect((b.spriteHeightM, b.sparkSizeM, b.trackerMax), (12.0, 3.0, 3));
    expect(b.defaultWidthM, inInclusiveRange(b.cameraMinWidthM, b.cameraMaxWidthM));
    expect(b.spriteHeightM, b.roadWidthM['principal'], reason: 'o sprite tem a largura de uma rua principal');
  });

  test('sprites em metros: a proporção com as ruas é a mesma em qualquer zoom, e eles crescem com o zoom', () {
    const lat = -22.8174, w = 411.0;
    final b = MapBalance(loadJson('assets/data/balance.json'));
    double px(double meters, double widthM) => meters / metersPerCell(lat) * pixelsPerCellFor(widthM: widthM, viewWidthPx: w, lat: lat);
    for (final widthM in [b.cameraMinWidthM, b.defaultWidthM, b.cameraMaxWidthM]) {
      expect(px(b.spriteHeightM, widthM) / px(b.roadWidthM['principal']!, widthM), closeTo(1, 1e-9), reason: 'largura $widthM m');
      expect(px(b.spriteHeightM, widthM) / px(b.auraM * 2, widthM), closeTo(12 / 50, 1e-9), reason: 'e a Aura de 25 m de raio');
    }
    expect(px(b.spriteHeightM, b.defaultWidthM), closeTo(54.8, 0.2), reason: '12 m em 90 m de uma tela de 411 px');
    expect(px(b.spriteHeightM, b.cameraMinWidthM), greaterThan(px(b.spriteHeightM, b.cameraMaxWidthM)));
    expect(px(b.spriteHeightM, b.cameraMinWidthM) / px(b.spriteHeightM, b.cameraMaxWidthM), closeTo(120 / 70, 1e-9));
    expect(px(b.sparkSizeM, b.defaultWidthM), closeTo(13.7, 0.1), reason: '3 m em 90 m');
  });

  test('conversão: metros visíveis e pixels por célula são inversos, e a Aura de 25 m ocupa 50 m dos 90', () {
    const lat = -22.8174, w = 411.0;
    final b = MapBalance(loadJson('assets/data/balance.json'));
    final ppc = pixelsPerCellFor(widthM: b.defaultWidthM, viewWidthPx: w, lat: lat);
    expect(widthMFor(pixelsPerCell: ppc, viewWidthPx: w, lat: lat), closeTo(b.defaultWidthM, 1e-9));
    expect(ppc, closeTo(80.4, 0.1));
    expect(2 * auraRadiusPx(auraM: b.auraM, lat: lat, pixelsPerCell: ppc) / w, closeTo(50 / 90, 1e-9));
    // Mais metros na tela, menos pixels por célula.
    expect(pixelsPerCellFor(widthM: 120, viewWidthPx: w, lat: lat), lessThan(pixelsPerCellFor(widthM: 70, viewWidthPx: w, lat: lat)));
    expect(pixelsPerCellFor(widthM: 70, viewWidthPx: w, lat: lat) / pixelsPerCellFor(widthM: 120, viewWidthPx: w, lat: lat), closeTo(120 / 70, 1e-9));
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
