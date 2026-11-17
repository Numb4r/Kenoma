import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/ground_pack.dart';
import 'package:kenoma/ui/city/city_ground.dart';
import 'package:kenoma/ui/lab/lab_art.dart';
import 'package:kenoma/world/city_scene.dart';

/// 0.23.1: o uso do solo do OSM no chão do Completo. Ladrilho só em área de pedestre e praça; estacionamento, baldio, lote e
/// comércio pelo uso do solo; o resto, o chão neutro do bioma; a calçada portuguesa só na zona do Centro.
void main() {
  final pack = GroundPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_ground.bin').readAsBytesSync()));

  test('o arquivo de Campinas tem as áreas de cada tipo e a zona do Centro', () {
    final all = <GroundArea>{};
    // Os tiles z15 da bbox de Campinas (`pipeline/regions.json`).
    final (x0, y0) = latLonToTileFraction(-22.72, -47.25, biomeZoom);
    final (x1, y1) = latLonToTileFraction(-23.10, -46.85, biomeZoom);
    for (var ty = y0 ~/ 64; ty <= y1 ~/ 64; ty++) {
      for (var tx = x0 ~/ 64; tx <= x1 ~/ 64; tx++) {
        all.addAll(pack.areasIn(tx, ty));
      }
    }
    final by = {for (final k in GroundKind.values) k: all.where((a) => a.kind == k).length};
    expect(by[GroundKind.residential], greaterThan(1000));
    expect(by[GroundKind.parking], greaterThan(300));
    expect(by[GroundKind.paved], greaterThan(20));
    expect(by[GroundKind.mosaic], 1);
    // A Praça Ramos de Azevedo cai na zona do Centro; o Ouro Verde, não.
    final (cx, cy) = latLonToTileFraction(-22.9041, -47.0687, biomeZoom);
    final (ox, oy) = latLonToTileFraction(-22.9733, -47.1368, biomeZoom);
    bool inMosaic(double x, double y) => pack.areasIn(x ~/ 64, y ~/ 64).any((a) => a.kind == GroundKind.mosaic);
    expect(inMosaic(cx, cy), isTrue);
    expect(inMosaic(ox, oy), isFalse);
  });

  testWidgets('o chão do uso do solo cobre o do bioma, e a calçada portuguesa só sai dentro da zona do Centro', (tester) async {
    final art = LabArt.build();
    addTearDown(art.dispose);
    Float64List box(double l, double t, double r, double b) => Float64List.fromList([l, t, r, t, r, b, l, b]);
    final road = CityRoad('principal', Float64List.fromList([0, 2, 8, 2]));
    Future<ByteData> chunk(List<GroundArea> areas) async {
      final tile = CityTile(roads: [road], greens: const [], waters: const [], buildings: const [], props: const [], areas: areas);
      final img = rasterGroundChunk(cx0: 0, cy0: 0, size: 4, f: const CityFrame(angle: 0, kc: 16, ox: 0, oy: 0), key: groundKeyFor(sunAltDeg: -10, sunAzDeg: 0, wet: false, far: false), sunAltDeg: -10, sunAzDeg: 0, mpc: 17.6, art: art, tiles: [tile], biomeAt: (_, _) => 'urban').image;
      return (await tester.runAsync(() => img.toByteData()))!;
    }

    int px(ByteData b, int x, int y) => b.getUint32((y * 66 + x) * 4); // 4 células × 16 px + 1 de cada lado
    final plain = await chunk(const []);
    final parking = await chunk([GroundArea(GroundKind.parking, box(0, 3, 4, 4))]);
    final mosaic = await chunk([GroundArea(GroundKind.mosaic, box(0, 0, 4, 4))]);
    // Embaixo, longe da rua: o estacionamento troca o chão do bioma.
    expect([for (var x = 1; x < 65; x++) px(parking, x, 60)], isNot([for (var x = 1; x < 65; x++) px(plain, x, 60)]));
    // A calçada (a faixa logo acima do asfalto da avenida) só muda com a zona do Centro; fora dela, a de concreto.
    final sidewalkRow = 32 - (14 / 2 + 1.5) * 16 / 17.6 ~/ 1;
    expect([for (var x = 1; x < 65; x++) px(mosaic, x, sidewalkRow)], isNot([for (var x = 1; x < 65; x++) px(plain, x, sidewalkRow)]));
    expect([for (var x = 1; x < 65; x++) px(mosaic, x, 60)], [for (var x = 1; x < 65; x++) px(plain, x, 60)], reason: 'a zona não pinta chão');
  });
}
