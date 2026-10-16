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

  test('escala em metros: 90 m de largura no padrão, pinça de 70 a 120 m, Fagulhas de 3 m e sprites menores que a rua', () {
    final b = MapBalance(loadJson('assets/data/balance.json'));
    expect((b.defaultWidthM, b.cameraMinWidthM, b.cameraMaxWidthM), (90.0, 70.0, 120.0));
    expect((b.sparkSizeM, b.trackerMax), (3.0, 3));
    expect(b.defaultWidthM, inInclusiveRange(b.cameraMinWidthM, b.cameraMaxWidthM));
    expect((b.playerHeightM, b.familiarHeightM, b.ecoHeightM), (8.0, 8.0, 9.0), reason: 'Conjurador e Familiar 8 m, Ecos 9 m');
    expect((b.ghostPedestrianM, b.ghostCarM), (6.0, 7.0), reason: 'pedestre fantasma 6 m, carro fantasma 7 m');
    expect(b.artPixelDp, 2.0, reason: 'o pixel de arte é de 2 dp');
    for (final m in [b.playerHeightM, b.familiarHeightM, b.ecoHeightM, b.ghostCarM]) {
      expect(m, lessThan(b.roadWidthM['principal']!), reason: 'nenhum sprite passa da largura de uma rua principal');
    }
    expect(b.ghostPedestrianM, lessThan(b.playerHeightM), reason: 'o pedestre fantasma é menor que o avatar');
  });

  test('sprites em metros: a proporção com a Aura é a mesma em qualquer zoom, e eles crescem com o zoom', () {
    const lat = -22.8174, w = 411.0;
    final b = MapBalance(loadJson('assets/data/balance.json'));
    double px(double meters, double widthM) => meters / metersPerCell(lat) * pixelsPerCellFor(widthM: widthM, viewWidthPx: w, lat: lat);
    for (final widthM in [b.cameraMinWidthM, b.defaultWidthM, b.cameraMaxWidthM]) {
      expect(px(b.ecoHeightM, widthM) / px(b.auraM * 2, widthM), closeTo(9 / 50, 1e-9), reason: 'largura $widthM m');
      expect(px(b.playerHeightM, widthM) / px(b.ecoHeightM, widthM), closeTo(8 / 9, 1e-9));
    }
    expect(px(b.ecoHeightM, b.defaultWidthM), closeTo(41.1, 0.2), reason: '9 m em 90 m de uma tela de 411 px');
    expect(px(b.playerHeightM, b.defaultWidthM), closeTo(36.6, 0.2), reason: '8 m em 90 m');
    expect(px(b.ecoHeightM, b.cameraMinWidthM), greaterThan(px(b.ecoHeightM, b.cameraMaxWidthM)));
    expect(px(b.ecoHeightM, b.cameraMinWidthM) / px(b.ecoHeightM, b.cameraMaxWidthM), closeTo(120 / 70, 1e-9));
    expect(px(b.sparkSizeM, b.defaultWidthM), closeTo(13.7, 0.1), reason: '3 m em 90 m');
    // O pixel de arte de 2 dp vale ~0,44 m na largura padrão: um sprite de 18 pixels cabe em ~8 m.
    expect(b.artPixelDp / px(1, b.defaultWidthM), closeTo(0.44, 0.02));
    expect(18 * b.artPixelDp / px(1, b.defaultWidthM), closeTo(b.playerHeightM, 0.3));
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
