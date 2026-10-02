import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/map_probe.dart';
import 'package:kenoma/world/region_map.dart';

import '../support/fixtures.dart';

void main() {
  final map = RegionMap(pack: loadCampinasPack(), biomes: loadBiomes());

  test('a sonda dá a célula z21, a z20 que a contém e a coordenada do ponto', () {
    final (fx, fy) = latLonToTileFraction(-22.8174, -47.0697, 21);
    final p = probeAt(map, fx, fy);
    expect((p.x21, p.y21), (fx.floor(), fy.floor()));
    expect((p.x20, p.y20), (fx.floor() ~/ 2, fy.floor() ~/ 2));
    expect(p.lat, closeTo(-22.8174, 1e-9));
    expect(p.lon, closeTo(-47.0697, 1e-9));
    expect(p.x20, spawnCellAt(-22.8174, -47.0697).$1, reason: 'a mesma célula z20 do núcleo');
    expect(p.y20, spawnCellAt(-22.8174, -47.0697).$2);
  });

  test('o bioma da sonda é o do mapa, e o de spawn é o da regra do núcleo', () {
    for (var i = 0; i < 100; i++) {
      final x = map.pack.x0 + 13.5 + (i * 211) % map.pack.width;
      final y = map.pack.y0 + 7.25 + (i * 389) % map.pack.height;
      final p = probeAt(map, x, y);
      expect(p.biome21, map.biomeAtCell(x.floor(), y.floor()));
      expect(p.spawnBiome20, map.biomes.spawnCellBiome(map.pack.quadOf(p.x20, p.y20)));
    }
  });

  test('fora do pacote a sonda vale Vazio nos dois', () {
    final p = probeAt(map, 100.5, 100.5);
    expect((p.biome21, p.spawnBiome20), (voidBiomeId, voidBiomeId));
  });

  test('o ponto sob o dedo na câmera inicial é a coordenada do centro', () {
    final cam = MapCamera.atLatLon(-22.8174, -47.0697);
    final (cx, cy) = cam.screenToCell(540, 1200, 1080, 2400);
    final p = probeAt(map, cx, cy);
    expect(p.lat, closeTo(-22.8174, 1e-9));
    expect(p.lon, closeTo(-47.0697, 1e-9));
  });
}
