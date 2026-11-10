import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/astro.dart' show DayLight;
import 'package:kenoma/core/climate.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/climate_catalog.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/ui/game/climate_ground.dart';
import 'package:kenoma/ui/game/climate_painter.dart';
import 'package:kenoma/ui/game/climate_puddle.dart';
import 'package:kenoma/ui/game/traffic_painter.dart';
import 'package:kenoma/world/climate_world.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/procession.dart';
import 'package:kenoma/world/street_cover.dart';
import 'package:kenoma/world/veil_traffic.dart';
import 'package:kenoma/world/visual_map.dart';

import '../support/fixtures.dart';

void main() {
  final catalog = ClimateCatalog.fromJson(loadJson('assets/data/clima.json'));
  final e7 = loadEpochs().epochs.firstWhere((e) => e.id == 7).climate!;
  const view = ui.Size(200, 300);
  final mpc = metersPerCell(-22.8174);

  group('a camada do mapa gira, move e dá zoom com o mapa', () {
    final meteor = e7.def('meteor_shower')!.pieces.whereType<DropPiece>().single;
    final shadow = e7.def('black_sun')!.pieces.whereType<ZonePiece>().single;
    const x = 1548400.5, y = 2370520.25, t = 1900000000;
    final crater = ClimateDrop(piece: meteor, pieceIndex: 0, index: 0, tUtc: t, x: x, y: y, spawnRoll: 1, itemRoll: 1, pick: 0, uid: 1);
    final zone = ClimateZone(piece: shadow, pieceIndex: 0, index: 0, x0: x - 6, y0: y + 4, headingRad: 0, startUtc: t - 600, endUtc: t + 600, slots: const [], uidBase: 2);

    Future<(Uint8List, List<PlacedMark>)> render(MapCamera cam) async {
      final g = ClimateGround(catalog: catalog)
        ..marks = [crater]
        ..zones = [zone];
      final rec = ui.PictureRecorder();
      g.paint(ui.Canvas(rec), view, cam, mpc: mpc, exactUtc: t + 60.0, seed: 7, shown: catalog.of('meteor_shower'));
      final img = rec.endRecording().toImageSync(view.width.toInt(), view.height.toInt());
      return ((await img.toByteData())!.buffer.asUint8List(), [...g.placed]);
    }

    bool glowAt(Uint8List px, (double, double) p) {
      final i = (p.$2.round() * view.width.toInt() + p.$1.round()) * 4;
      return px[i] > 0xE0 && px[i + 1] > 0xC0 && px[i + 2] > 0x80; // o miolo claro da cratera (#ffe9a8)
    }

    test('a cratera aparece onde a câmera projeta o ponto do mundo, em qualquer rotação, pan e zoom', () async {
      const a = MapCamera(centerX: x + 3, centerY: y - 2, pixelsPerCell: 16);
      const b = MapCamera(centerX: x - 2, centerY: y + 3, pixelsPerCell: 12, rotation: 1.1);
      final (pa, placedA) = await render(a);
      final (pb, placedB) = await render(b);
      final sa = a.cellToScreen(x, y, view.width, view.height), sb = b.cellToScreen(x, y, view.width, view.height);
      expect((sa.$1 - sb.$1).abs() + (sa.$2 - sb.$2).abs(), greaterThan(30), reason: 'em pixels, a posição muda com a câmera');
      expect(glowAt(pa, sa), isTrue);
      expect(glowAt(pb, sb), isTrue);
      expect(glowAt(pb, sa), isFalse, reason: 'não ficou preso à tela');
      expect(placedA, placedB, reason: 'no mundo, a posição não muda');
      expect(placedA.map((m) => m.kind), containsAll(['crater_glow', 'zone_inverted_shadow']));
    });

    test('a cratera brilha 2 h, vira marca que some aos poucos e acaba em 3 h', () {
      PlacedMark? at(double dt) {
        final g = ClimateGround(catalog: catalog)..marks = [crater];
        g.paint(ui.Canvas(ui.PictureRecorder()), view, const MapCamera(centerX: x, centerY: y), mpc: mpc, exactUtc: t + dt, seed: 7, shown: catalog.of('clear'));
        return g.placed.isEmpty ? null : g.placed.single;
      }

      expect(at(60)!.kind, 'crater_glow');
      expect(at(7100)!.kind, 'crater_glow');
      expect(at(7300)!.kind, 'crater');
      expect(at(10900), isNull);
    });
  });

  group('Dilúvio', () {
    final visual = VisualMap(VisualPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync())), cacheTiles: 32);
    const seed = 0x6ebe19ac6345175f, rush = 1790035200 + 21 * 3600;
    const center = (12092 * 64.0 + 32, 18513 * 64.0 + 32);
    final flood = streetCoverOf(catalog.of('deluge'))!;
    StreetState state(GhostLine l, double t) => flood.stateOf(seed, l.key, l.roadClass, 0, 1e6);

    test('carros das ruas baixas viram barcos e canoas; passantes não andam nas ruas alagadas', () {
      final field = TrafficField(graph: TrafficGraph(loadTile: visual.tile, cellsPerTile: visual.cellsPerTile, extent: visual.pack.extent), seed: seed)..streetState = state;
      final ghosts = field.ghostsIn(rush.toDouble(), center.$1 - 40, center.$2 - 40, center.$1 + 40, center.$2 + 40, maxGhosts: 2000);
      final walkers = ghosts.where((g) => g.kind == GhostKind.pedestrian).toList();
      final boats = ghosts.where((g) => g.kind == GhostKind.car && g.line != null && state(g.line!, 0) == StreetState.flooded);
      expect(walkers, isNotEmpty);
      for (final g in walkers) {
        expect(state(g.line!, 0), isNot(StreetState.flooded), reason: 'calçada alta');
      }
      expect(boats, isNotEmpty);
      final dry = TrafficField(graph: TrafficGraph(loadTile: visual.tile, cellsPerTile: visual.cellsPerTile, extent: visual.pack.extent), seed: seed);
      final before = dry.ghostsIn(rush.toDouble(), center.$1 - 40, center.$2 - 40, center.$1 + 40, center.$2 + 40, maxGhosts: 2000);
      expect(before.where((g) => g.kind == GhostKind.pedestrian && state(g.line!, 0) == StreetState.flooded), isNotEmpty, reason: 'sem o Dilúvio, havia passantes ali');

      final painter = TrafficPainter(visual, carM: 4.5, pedestrianM: 1.7);
      final cam = MapCamera(centerX: center.$1, centerY: center.$2, pixelsPerCell: 6);
      painter.paint(ui.Canvas(ui.PictureRecorder()), const ui.Size(400, 800), cam, seed: seed, tUtc: rush, tUtcExact: rush.toDouble(), lonDeg: -47.06, metersPerCell: mpc, light: const DayLight(night: 0, warm: 0), streetState: state, coverKey: 'deluge');
      expect(painter.lastBoats, greaterThan(0));
      painter.paint(ui.Canvas(ui.PictureRecorder()), const ui.Size(400, 800), cam, seed: seed, tUtc: rush, tUtcExact: rush.toDouble(), lonDeg: -47.06, metersPerCell: mpc, light: const DayLight(night: 0, warm: 0));
      expect(painter.lastBoats, 0, reason: 'sem clima, nada de barco');
    });

    test('a água desenhada sobre as ruas baixas é a mesma para a mesma seed', () {
      List<PlacedMark> streets(int s) {
        final g = ClimateGround(catalog: catalog, visual: visual);
        g.paint(ui.Canvas(ui.PictureRecorder()), view, MapCamera(centerX: center.$1, centerY: center.$2, pixelsPerCell: 4), mpc: mpc, exactUtc: 1e9, seed: s, shown: catalog.of('deluge'), c: const PlayerClimate(id: 'deluge'));
        return [for (final m in g.placed) if (m.kind == 'street_flood') m];
      }

      expect(streets(seed), isNotEmpty);
      expect(streets(seed), streets(seed));
      expect(streets(seed + 1), isNot(streets(seed)));
    });
  });

  group('formação no tempo', () {
    final visual = VisualMap(VisualPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync())), cacheTiles: 32);
    const center = (12092 * 64.0 + 32, 18513 * 64.0 + 32), t0 = 1900000000;
    Set<String> kinds(String id, double since, {String? prev, double? sinceEnd}) {
      final g = ClimateGround(catalog: catalog, visual: visual);
      final c = PlayerClimate(id: prev == null ? id : 'clear', runStartUtc: (t0 - since).round(), prevId: prev, prevStartUtc: t0 - 20000, prevEndUtc: (t0 - (sinceEnd ?? 0)).round());
      g.paint(ui.Canvas(ui.PictureRecorder()), view, MapCamera(centerX: center.$1, centerY: center.$2, pixelsPerCell: 40), mpc: mpc, exactUtc: t0.toDouble(), seed: 7, shown: catalog.of(prev == null ? id : 'clear'), c: c);
      return {for (final m in g.placed) m.kind};
    }

    test('a neve: nada no começo, as ruas só no fim; derretendo, as ruas somem primeiro', () {
      expect(kinds('snow', 0), isNot(contains('street_snow')));
      expect(kinds('snow', 600), isNot(contains('street_snow')), reason: 'primeiro o chão e os telhados');
      expect(kinds('snow', 3600), contains('street_snow'));
      expect(kinds('clear', 0, prev: 'snow', sinceEnd: 300), contains('street_snow'), reason: 'derretendo');
      expect(kinds('clear', 0, prev: 'snow', sinceEnd: 3000), isNot(contains('street_snow')));
      expect(kinds('deluge', 60), contains('street_flood'), reason: 'a água começa a subir');
      expect(kinds('clear', 0, prev: 'deluge', sinceEnd: 3700), isNot(contains('street_flood')), reason: 'escoou');
    });

    test('três variantes de poça, de contorno irregular (não é oval), iguais pelo mesmo hash', () {
      final shapes = [for (var v = 0; v < 3; v++) puddleRows(v, 1234, 12)];
      expect(shapes[0], isNot(shapes[1]));
      expect(shapes[1], isNot(shapes[2]));
      expect(puddleRows(2, 1234, 12), shapes[2]);
      // Um oval teria as larguras das linhas simétricas e lisas; o contorno irregular quebra a simetria.
      final rows = shapes[0];
      final widths = [for (final (_, a, b) in rows) b - a];
      expect(widths, isNot(widths.reversed.toList()));
      expect(puddleRows(0, 99, 12), isNot(shapes[0]), reason: 'cada poça com o seu contorno');
    });

    test('a Procissão: 12 a 20 figuras pela rota e velas no chão por onde passou, até 120 m', () {
      final e7 = loadEpochs().epochs.firstWhere((e) => e.id == 7).climate!;
      final piece = e7.def('fog_procession')!.pieces.whereType<ZonePiece>().single;
      final graph = TrafficGraph(loadTile: visual.tile, cellsPerTile: visual.cellsPerTile, extent: visual.pack.extent, stitch: true);
      final z = ClimateZone(piece: piece, pieceIndex: 0, index: 0, x0: center.$1, y0: center.$2, headingRad: 1.0, startUtc: t0 - 600, endUtc: t0 + 600, slots: const [], uidBase: 77);
      final plan = planProcession(graph, z, mpc: mpc)!;
      final head = plan.figuresAt(t0.toDouble()).first;
      final g = ClimateGround(catalog: catalog, visual: visual)
        ..zones = [z]
        ..processionPlans[z.uidBase] = plan;
      final cam = MapCamera(centerX: head.x, centerY: head.y, pixelsPerCell: 40, rotation: 0.7);
      g.paint(ui.Canvas(ui.PictureRecorder()), const ui.Size(411, 914), cam, mpc: mpc, exactUtc: t0.toDouble(), seed: 7, shown: catalog.of('fog_procession'), playerX: head.x, playerY: head.y);
      final figs = g.placed.where((m) => m.kind == 'procession_figure').length;
      expect(figs, inInclusiveRange(12, 20));
      expect(g.placed.where((m) => m.kind == 'candle'), isNotEmpty);
      // Longe (mais de 120 m), a fila não aparece.
      final far = ClimateGround(catalog: catalog, visual: visual)
        ..zones = [z]
        ..processionPlans[z.uidBase] = plan;
      far.paint(ui.Canvas(ui.PictureRecorder()), const ui.Size(411, 914), cam, mpc: mpc, exactUtc: t0.toDouble(), seed: 7, shown: catalog.of('fog_procession'), playerX: head.x + 200 / mpc, playerY: head.y);
      expect(far.placed.where((m) => m.kind == 'procession_figure'), isEmpty);
    });
  });

  test('Neve do Véu: flocos grandes, densos e claros sobre o mapa escuro', () {
    final p = ClimatePainter();
    const size = ui.Size(411, 914);
    for (var i = 0; i < 400; i++) {
      p.update(1 / 30, size, catalog.of('veil_snow'));
    }
    expect(p.count, greaterThanOrEqualTo(150));
    final flakes = catalog.of('veil_snow').layers.firstWhere((l) => l.kind == 'particles');
    expect(flakes.val('size'), greaterThanOrEqualTo(4));
    double contrast(int a, int b) {
      final la = ui.Color(a).computeLuminance(), lb = ui.Color(b).computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
    }

    for (final c in [flakes.color(), ...flakes.colors]) {
      expect(contrast(c, 0xFF1A1424), greaterThan(7), reason: 'contra o fundo do mapa');
    }
  });
}
