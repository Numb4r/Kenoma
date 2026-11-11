import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/climate.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/climate_catalog.dart';
import 'package:kenoma/ui/game/climate_ground.dart';
import 'package:kenoma/ui/game/draw_order.dart';
import 'package:kenoma/world/climate_world.dart';
import 'package:kenoma/world/map_camera.dart';

import '../support/fixtures.dart';

void main() {
  test('a ordem das camadas é a do pedido, de baixo para cima', () {
    expect([for (final l in MapLayer.values) l.name], [
      'base', // ruas, verde, água
      'climateGround', // marcas do clima no chão
      'shadows',
      'creatures',
      'sparks',
      'materials',
      'walkers',
      'cars',
      'player', // avatar e Familiar
      'air', // arco-íris, olho do furacão, figuras altas
      'climateScreen', // gotas, flocos, tom
      'hud',
    ]);
  });

  test('paintLayers pinta na ordem fixa, não na ordem em que os pintores chegam', () {
    final calls = <MapLayer>[], drawn = <MapLayer>[];
    paintLayers({for (final l in MapLayer.values.reversed) l: () => calls.add(l)}, drawn: drawn);
    expect(calls, MapLayer.values);
    expect(drawn, MapLayer.values);
    calls.clear();
    paintLayers({MapLayer.cars: () => calls.add(MapLayer.cars), MapLayer.climateGround: () => calls.add(MapLayer.climateGround)});
    expect(calls, [MapLayer.climateGround, MapLayer.cars], reason: 'a marca do chão nunca vem depois do carro');
  });

  test('o mapa do jogo pinta toda camada por paintLayers, uma vez cada', () {
    final src = File('lib/ui/game/game_map_game.dart').readAsStringSync();
    final render = src.substring(src.indexOf('void render(Canvas canvas)'), src.indexOf('final lastLayers'));
    for (final l in MapLayer.values) {
      expect('MapLayer.${l.name}:'.allMatches(render).length, 1, reason: l.name);
    }
    // Nada do clima é pintado fora das camadas dele.
    expect('climateGround.paint('.allMatches(src).length, 1);
    expect(render.indexOf('_climate.paint('), greaterThan(render.indexOf('MapLayer.climateScreen:')));
    expect(render.indexOf('_paintClimateGround('), lessThan(render.indexOf('MapLayer.shadows:')));
  });

  group('a camada do mapa do clima se divide em chão, sombras e ar', () {
    final catalog = ClimateCatalog.fromJson(loadJson('assets/data/clima.json'));
    final e7 = loadEpochs().epochs.firstWhere((e) => e.id == 7).climate!;
    final mpc = metersPerCell(-22.8174);
    const view = ui.Size(200, 300), x = 1548400.5, y = 2370520.25, t = 1900000000;
    const cam = MapCamera(centerX: x, centerY: y, pixelsPerCell: 16);
    ZonePiece zoneOf(String climate, String name) => e7.def(climate)!.pieces.whereType<ZonePiece>().firstWhere((p) => p.name == name);
    ClimateZone zone(ZonePiece p, int uid) => ClimateZone(piece: p, pieceIndex: 0, index: 0, x0: x + 1, y0: y + 1, headingRad: 0, startUtc: t - 600, endUtc: t + 600, slots: const [], uidBase: uid);

    test('marcas no chão em paint; olho do furacão e Procissão só em paintAir', () {
      final meteor = e7.def('meteor_shower')!.pieces.whereType<DropPiece>().single;
      final g = ClimateGround(catalog: catalog)
        ..marks = [ClimateDrop(piece: meteor, pieceIndex: 0, index: 0, tUtc: t, x: x, y: y, spawnRoll: 1, itemRoll: 1, pick: 0, uid: 1)]
        ..zones = [zone(zoneOf('hurricane', 'hurricane_eye'), 2), zone(zoneOf('fog_procession', 'procession'), 3), zone(zoneOf('veil_ash', 'veil_ash_zone'), 4)];
      final canvas = ui.Canvas(ui.PictureRecorder());
      g.paint(canvas, view, cam, mpc: mpc, exactUtc: t + 60.0, seed: 7, shown: catalog.of('clear'), playerX: x, playerY: y, layered: true);
      final ground = {for (final p in g.placed) p.kind};
      expect(ground, containsAll(['crater_glow', 'zone_veil_ash_zone']));
      expect(ground.where((k) => k.contains('hurricane_eye') || k.contains('procession')), isEmpty, reason: 'o que é do ar não entra na camada do chão');
      g.paintShadows();
      expect({for (final p in g.placed) p.kind}, ground, reason: 'sem Lua Dupla, a camada de sombras não tem nada');
      g.paintAir();
      final all = {for (final p in g.placed) p.kind};
      expect(all, containsAll(['zone_hurricane_eye', 'procession']));
    });

    test('todo estilo de zona tem camada: ar ou chão', () {
      expect(groundStyles.containsAll(airZoneStyles), isTrue);
      expect(airZoneStyles, {'eye', 'whirl', 'ghost'});
    });
  });
}
