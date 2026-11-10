import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/climate.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/climate_catalog.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/ui/game/climate_fx.dart';
import 'package:kenoma/ui/game/rainbow_painter.dart';
import 'package:kenoma/world/climate_world.dart';
import 'package:kenoma/world/dew_prism.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/visual_map.dart';
import 'package:kenoma/world/walk_paths.dart';

import '../support/fixtures.dart';

void main() {
  final seed = seedGlobal('KENOMA-TESTE');
  final data = loadGameData();
  final catalog = ClimateCatalog.fromJson(loadJson('assets/data/clima.json'));
  final e8 = loadEpochs().epochs.firstWhere((e) => e.id == 8);
  final visual = VisualMap(VisualPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync())), cacheTiles: 32);
  final (ux, uy) = latLonToTileFraction(-22.8174, -47.0697, 21); // Unicamp
  final rx = ux.floor() >>> 9, ry = uy.floor() >>> 9;
  final (clat, clon) = tileFractionToLatLon(rx + 0.5, ry + 0.5, 12);
  final (cx, cy) = latLonToTileFraction(clat, clon, 21); // centro da região do clima
  final mpc = metersPerCell(clat);
  const windowS = 10800;
  final w0 = (e8.startsUtc + 10 * 86400) ~/ windowS;

  /// Chuva nas janelas pares e céu limpo nas ímpares, a partir de [w0]: 40 fins de chuva.
  final rainy = [
    for (var k = 0; k < 80; k++) ClimateEvent(climate: k.isEven ? 'rain' : 'clear', startsUtc: (w0 + k) * windowS, endsUtc: (w0 + k + 1) * windowS),
  ];

  ClimateWorld device({String? forced, List<ClimateEvent> events = const []}) => ClimateWorld(
        seed: seed,
        schedule: loadEpochs(),
        speciesOfType: data.ecoOfType,
        itemExists: data.itemNames.containsKey,
        itemSince: (id) => data.itemSinceEpoch[id],
        snapper: WalkPaths(visual),
        forced: () => forced,
      )..events = events;

  double distM(double x, double y) => math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) * mpc;

  group('arco-íris', () {
    test('nasce depois da chuva com a chance da época, fixo num ponto a até 400 m do centro da região, igual em dois aparelhos', () {
      final a = device(events: rainy), b = device(events: rainy);
      final arcs = <RainbowArc>[];
      for (var k = 1; k < 80; k += 2) {
        final t = (w0 + k) * windowS + 60;
        final arc = a.rainbowIn(rx, ry, t);
        expect(a.rainbowIn(rx, ry, (w0 + k - 1) * windowS + 60), isNull, reason: 'chovendo, não há arco');
        if (arc == null) continue;
        arcs.add(arc);
        final other = b.rainbowIn(rx, ry, t)!;
        expect((other.footX, other.footY, other.startUtc, other.endUtc, other.headingRad), (arc.footX, arc.footY, arc.startUtc, arc.endUtc, arc.headingRad));
        expect(arc.startUtc, (w0 + k) * windowS, reason: 'nasce quando a chuva para');
        expect(arc.endUtc - arc.startUtc, inInclusiveRange(1200, 2400));
        expect(distM(arc.footX, arc.footY), lessThanOrEqualTo(400 + 35), reason: 'até 400 m do centro, levado à rua');
        // Fixo: o mesmo ponto até o fim, e some depois.
        final late = a.rainbowIn(rx, ry, arc.endUtc - 1)!;
        expect((late.footX, late.footY), (arc.footX, arc.footY));
        expect(a.rainbowIn(rx, ry, arc.endUtc), isNull);
        expect(a.rainbowsNear(arc.footX + 3, arc.footY, 10, t).single.uid, arc.uid);
      }
      expect(arcs.length, inInclusiveRange(4, 20), reason: '25% de 40 fins de chuva');
      expect({for (final x in arcs) x.footX}.length, arcs.length, reason: 'cada arco num ponto');
      // Sem chuva antes, nada.
      expect(device(events: [ClimateEvent(climate: 'clear', startsUtc: w0 * windowS, endsUtc: (w0 + 80) * windowS)]).rainbowIn(rx, ry, (w0 + 1) * windowS + 60), isNull);
    });

    test('o pé dá o Fragmento de luz na época 8; o mesmo arco do debug antes dela dá Ectoplasma, como antes', () {
      final a = device(events: rainy);
      RainbowArc? arc;
      for (var k = 1; arc == null; k += 2) {
        arc = a.rainbowIn(rx, ry, (w0 + k) * windowS + 60);
      }
      final t = arc.startUtc + 120;
      final born = a.extras(x21: arc.footX, y21: arc.footY, radiusM: 30, t: t, metersPerCell21: mpc, levelOf: (id, add, uid) => 3);
      expect(born.map((s) => s.entryId), contains('item.prism_shard'));
      expect(born.where((s) => s.isEco), isEmpty, reason: 'Feérico ainda não tem espécie: sem efeito');
      final e7 = loadEpochs().epochs.firstWhere((e) => e.id == 7);
      final dbg = device();
      final t7 = e7.startsUtc + 3600;
      expect(dbg.debugTrigger('rainbow', ux, uy, t7), isTrue);
      expect(dbg.rainbowsNear(ux, uy, 5, t7 + 10), hasLength(1), reason: 'o arco do debug fica no ponto tocado');
      expect(dbg.extras(x21: ux, y21: uy, radiusM: 30, t: t7 + 10, metersPerCell21: mpc, levelOf: (id, add, uid) => 3).map((s) => s.entryId), contains('item.ectoplasm'));
    });

    test('forçado pelo debug, o arco vale a janela inteira, só neste aparelho', () {
      final t = (w0 + 2) * windowS + 4000;
      final arc = device(forced: 'rainbow').rainbowIn(rx, ry, t)!;
      expect((arc.startUtc, arc.endUtc), ((w0 + 2) * windowS, (w0 + 3) * windowS));
      expect(device().rainbowIn(rx, ry, t), isNull);
    });

    test('o Prisma de orvalho aponta a direção e a distância do pé e só se gasta com arco ativo', () {
      final a = device(events: rainy);
      RainbowArc? arc;
      for (var k = 1; arc == null; k += 2) {
        arc = a.rainbowIn(rx, ry, (w0 + k) * windowS + 60);
      }
      final t = arc.startUtc + 300;
      var taken = 0;
      bool take() => ++taken > 0;
      // 200 m a leste e 150 m ao sul do pé: o pé fica a 250 m, para noroeste (306,87°).
      final px = arc.footX + 200 / mpc, py = arc.footY + 150 / mpc;
      final r = useDewPrism(world: a, take: take, x21: px, y21: py, t: t, metersPerCell21: mpc, searchM: data.climateBalance.prismSearchM)!;
      expect(r.distanceM, closeTo(250, 0.01));
      expect(r.bearingDeg, closeTo(306.87, 0.01));
      expect(compassPoint(r.bearingDeg), 'noroeste');
      expect(taken, 1);
      expect(useDewPrism(world: a, take: take, x21: px, y21: py, t: arc.endUtc + 10, metersPerCell21: mpc, searchM: data.climateBalance.prismSearchM), isNull);
      expect(taken, 1, reason: 'sem arco ativo, o prisma não se gasta');
      expect(prismReading(arc, arc.footX, arc.footY - 100 / mpc, mpc).bearingDeg, closeTo(180, 1e-9), reason: 'o pé ao sul');
    });

    test('desenhado de pé no mapa: o pé fica no ponto do mundo e o arco gira com a câmera, sempre subindo na tela', () {
      final arc = RainbowArc(piece: e8.climate!.rainbow!.$2, startUtc: 0, endUtc: 2000, headingRad: math.pi / 2, spots: [(ux, uy)], slot: (dx: 0, dy: 0, roll: 0, roll2: 0, pick: 0), uid: 1);
      const view = Size(412, 915);
      for (final rot in [0.0, math.pi / 3, math.pi, 4.4]) {
        final cam = MapCamera(centerX: ux + 2, centerY: uy - 1, pixelsPerCell: 6, rotation: rot);
        final pts = rainbowScreenPoints(arc, cam, view, outerM: 90, metersPerCell21: mpc);
        final (fx, fy) = cam.cellToScreen(ux, uy, view.width, view.height);
        expect((pts.first - Offset(fx, fy)).distance, lessThan(1e-6), reason: 'o pé no ponto do mundo');
        final (ex, ey) = cam.cellToScreen(ux + 2 * 90 / mpc, uy, view.width, view.height);
        expect((pts.last - Offset(ex, ey)).distance, lessThan(1e-6), reason: 'o outro pé, a leste, gira com o mapa');
        final top = pts[pts.length ~/ 2], mid = Offset((fx + ex) / 2, (fy + ey) / 2);
        expect(top.dy, lessThan(mid.dy - 10), reason: 'de pé: o alto do arco sobe na tela');
        expect((top.dx - mid.dx).abs(), lessThan(1e-6));
      }
      expect(rainbowFade(arc, 1000, fadeInS: 90, fadeOutS: 300), 1);
      expect(rainbowFade(arc, 1850, fadeInS: 90, fadeOutS: 300), closeTo(0.5, 1e-9), reason: 'some aos poucos no fim');
      expect(rainbowFade(arc, 2000, fadeInS: 90, fadeOutS: 300), 0);
    });
  });

  group('raio do debug', () {
    test('cai no ponto tocado, do lado do jogador, com traço, clarão, trovão, marca e o Eco carregado, sem aviso', () {
      final a = device();
      final t = e8.startsUtc + 7200;
      expect(a.debugTrigger('lightning', ux, uy, t), isTrue);
      final drop = a.dropsNear(ux, uy, 2, t - 2, t).single;
      expect((drop.x, drop.y), (ux, uy));
      final fx = ClimateFx(catalog: catalog, balance: const ClimateBalance());
      double? thunder;
      fx.onThunder = (d) => thunder = d;
      fx.observe(a, px: ux, py: uy, metersPerCell21: mpc, exactUtc: t + 0.9); // o jogador em cima do ponto, quase 1 s depois
      expect(fx.animating, 1, reason: 'o raio do debug anima mesmo a menos do mínimo de distância');
      expect(fx.flash, greaterThan(0));
      expect(thunder, closeTo(0, 1e-9));
      expect(catalog.piece('lightning').mark, 'burn');
      final eco = a.extras(x21: ux, y21: uy, radiusM: 30, t: t + 5, metersPerCell21: mpc, levelOf: (id, add, uid) => 3).where((s) => s.tag == 'charged').single;
      expect((eco.x, eco.y), (ux, uy));
    });
  });
}
