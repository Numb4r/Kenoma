// Acha, para o workbench, um lugar de cada bioma perto do Centro (o centro de um bloco de 9x9 células z21 todo do bioma, no
// pacote da época 11), para a captura do bioma no emulador. Fica fora de `test/`.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/region_pack.dart';

import '../test/support/fixtures.dart';

void main() {
  test('lugares dos biomas', () {
    final pack = RegionPack.parse(Uint8List.fromList(File('assets/regions/campinas_e11.bin').readAsBytesSync()));
    final biomes = loadBiomes();
    final (x0, y0) = latLonToTileFraction(-22.9056, -47.0608, 21);
    final (cx, cy) = (x0.floor(), y0.floor());
    final out = <String, List<double>>{};
    for (var r = 0; r < 2500 && out.length < 7; r += 3) {
      for (var dy = -r; dy <= r; dy += 3) {
        for (var dx = -r; dx <= r; dx += 3) {
          if (dx.abs() != r && dy.abs() != r) continue;
          final x = cx + dx, y = cy + dy;
          final id = pack.biomeAt(x, y);
          final key = biomes.byId(id).key;
          if (out.containsKey(key)) continue;
          var solid = true;
          for (var k = -4; k <= 4 && solid; k++) {
            for (var m = -4; m <= 4 && solid; m++) {
              if (pack.biomeAt(x + k, y + m) != id) solid = false;
            }
          }
          if (solid) {
            final (lat, lon) = tileFractionToLatLon(x + 0.5, y + 0.5, 21);
            out[key] = [lat, lon];
          }
        }
      }
    }
    File('../workbench/catalog/biomas_lugares.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
  });
}
