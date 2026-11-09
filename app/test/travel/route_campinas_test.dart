// A rota do Modo Viagem sobre o pacote visual real de Campinas.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/travel/travel_path.dart';
import 'package:kenoma/world/traffic_graph.dart';
import 'package:kenoma/world/visual_map.dart';

const unicamp = (-22.8184, -47.0647), centro = (-22.9056, -47.0608), taquaral = (-22.8755, -47.0525);

void main() {
  final visual = VisualMap(VisualPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync())), cacheTiles: 64);
  final mpc = metersPerCell(-22.86);
  TrafficGraph graph({bool stitch = true}) =>
      TrafficGraph(loadTile: visual.tile, cellsPerTile: visual.cellsPerTile, extent: visual.pack.extent, cacheTiles: 512, stitch: stitch);

  TravelPath? route(TrafficGraph g, (double, double) a, (double, double) b, {required bool motorized}) {
    final (ax, ay) = latLonToTileFraction(a.$1, a.$2, biomeZoom);
    final (bx, by) = latLonToTileFraction(b.$1, b.$2, biomeZoom);
    return findRoute(g, fromX: ax, fromY: ay, toX: bx, toY: by, rules: RouteRules(motorized: motorized), mpc: mpc, snapM: 150, maxNodes: 300000);
  }

  group('causa da rota reta', () {
    test('sem cortar as linhas nas esquinas o grafo não liga os tiles nem as esquinas em T: de carro não há rota', () {
      // O pacote simplifica cada via sozinha e corta as linhas nos tiles z15 com sobra: a ponta de uma rua cai no meio do
      // trecho da outra, sem vértice comum. Sem rota, o mapa desenhava a reta.
      expect(route(graph(stitch: false), unicamp, centro, motorized: true), isNull);
      expect(route(graph(stitch: false), taquaral, unicamp, motorized: true), isNull);
    });

    test('com o corte, Barão Geraldo → Centro e Taquaral → Unicamp saem pelas ruas, de carro e a pé', () {
      final g = graph();
      for (final (a, b, crow) in [(unicamp, centro, 9700.0), (taquaral, unicamp, 6600.0)]) {
        for (final motorized in [true, false]) {
          final r = route(g, a, b, motorized: motorized);
          expect(r, isNotNull, reason: 'motorizado: $motorized');
          expect(r!.lengthM, inInclusiveRange(crow, crow * 1.6), reason: 'motorizado: $motorized');
          expect(r.pointCount, greaterThan(50), reason: 'segue as ruas, não a reta');
        }
      }
    });
  });
}
