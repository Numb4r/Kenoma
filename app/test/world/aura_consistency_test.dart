import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/world/aura.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/world_view.dart';

import '../support/fixtures.dart';

/// O raio lógico (coleta) tem que ser o do círculo desenhado: um ponto a 9,9 m fica dentro nos dois, a 10,1 m fora nos dois,
/// em qualquer latitude, direção e rotação do mapa.
void main() {
  WorldView viewAt() => WorldView(
        field: SpawnField(seed: seedGlobal('KENOMA-TESTE'), schedule: loadEpochs(), map: RegionMap(pack: loadCampinasPack(), biomes: loadBiomes())),
        state: GameState.fresh(groupCode: 'KENOMA-TESTE', startInventory: {}, balance: loadProgressBalance()),
        auraM: 10,
        viewM: 120,
        itemName: (id) => id,
        street: loadStreetBalance(),
      );

  test('lógica e círculo desenhado concordam a 0,1 m de cada lado do raio (10 m de base + 2 m do Familiar)', () {
    const w = 400.0, h = 800.0;
    for (final lat in [-23.0, 0.0, 40.0, 60.0]) {
      for (final rot in [0.0, 0.7, math.pi / 2, 2.4, -1.9]) {
        for (final bearing in [0.0, 1.1, 2.3, 4.0, 5.5]) {
          for (final ppc in [8.0, 16.0, 31.0]) {
            final view = viewAt()..refresh(lat: lat, lon: -47.0, tUtc: 1790035200 + 86400);
            final (px, py) = latLonToTileFraction(lat, -47.0, biomeZoom);
            final mpc = metersPerCell(lat);
            final cam = MapCamera(centerX: px, centerY: py, pixelsPerCell: ppc, rotation: rot);
            final radiusPx = auraRadiusPx(auraM: view.auraRadiusM, lat: lat, pixelsPerCell: ppc);
            for (final (d, inside) in [(view.auraRadiusM - 0.1, true), (view.auraRadiusM + 0.1, false)]) {
              final spawn = WorldSpawn(
                uid: 1,
                kind: 'spark',
                entryId: 'spark',
                quantity: 1,
                x: px + math.cos(bearing) * d / mpc,
                y: py + math.sin(bearing) * d / mpc,
                cellX: 0,
                cellY: 0,
                window: 0,
              );
              final (sx, sy) = cam.cellToScreen(spawn.x, spawn.y, w, h);
              final drawnInside = math.sqrt(math.pow(sx - w / 2, 2) + math.pow(sy - h / 2, 2)) <= radiusPx;
              final reason = 'lat $lat rot $rot rumo $bearing ppc $ppc d $d';
              expect(view.inAura(spawn), inside, reason: reason);
              expect(drawnInside, inside, reason: reason);
            }
          }
        }
      }
    }
  });
}
