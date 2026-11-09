// A rota do Modo Viagem sobre o pacote visual real de Campinas.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/access_pack.dart';
import 'package:kenoma/data/map_sources.dart';
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
    return findRoute(g, fromX: ax, fromY: ay, toX: bx, toY: by, rules: RouteRules(motorized ? RouteProfile.motor : RouteProfile.foot), mpc: mpc, snapM: 150, maxNodes: 300000);
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

  group('rota pelas ruas com o arquivo de rota', () {
    final access = AccessPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_noaccess.bin').readAsBytesSync()));
    final tol = 3 / mpc;
    final bits = accessTest(access, tol);
    final g = TrafficGraph(
        loadTile: visual.tile, cellsPerTile: visual.cellsPerTile, extent: visual.pack.extent, cacheTiles: 512, stitch: true, noCrossingAt: bridgeTest(access, tol));
    final raw = <(int, int), List<GhostLine>>{};
    List<GhostLine> rawLines(int tx, int ty) => raw[(tx, ty)] ??= switch (visual.tile(tx, ty)) {
          null => const [],
          final t => ghostLinesOfTile(t, tx, ty, cellsPerTile: 64, extent: visual.pack.extent),
        };

    /// Distância (células) do ponto até a linha mais perto do pacote, sem o corte.
    double toPack(double x, double y) {
      var best = double.infinity;
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (final l in rawLines((x / 64).floor() + dx, (y / 64).floor() + dy)) {
            for (var i = 0; i + 3 < l.xy.length; i += 2) {
              final ax = l.xy[i], ay = l.xy[i + 1], ex = l.xy[i + 2] - ax, ey = l.xy[i + 3] - ay;
              final len = ex * ex + ey * ey;
              final t = len <= 0 ? 0.0 : (((x - ax) * ex + (y - ay) * ey) / len).clamp(0.0, 1.0);
              final px = ax + ex * t - x, py = ay + ey * t - y;
              if (px * px + py * py < best * best) best = math.sqrt(px * px + py * py);
            }
          }
        }
      }
      return best;
    }

    RouteSearch search((double, double) a, (double, double) b, RouteProfile p) {
      final (ax, ay) = latLonToTileFraction(a.$1, a.$2, biomeZoom);
      final (bx, by) = latLonToTileFraction(b.$1, b.$2, biomeZoom);
      final s = RouteSearch(g, fromX: ax, fromY: ay, toX: bx, toY: by, rules: RouteRules(p, access: bits), mpc: mpc, snapM: 150, maxNodes: 300000);
      while (!s.step(300000)) {}
      return s;
    }

    for (final (name, a, b) in [('Barão Geraldo (Unicamp) → Centro', unicamp, centro), ('Taquaral → Unicamp', taquaral, unicamp)]) {
      for (final p in RouteProfile.values) {
        test('$name, ${p.name}: nenhum trecho atravessa quarteirão e nenhum passa por via fechada', () {
          final s = search(a, b, p);
          final r = s.result;
          expect(r, isNotNull);
          expect(r!.offData, isFalse);
          expect(r.lengthM, inInclusiveRange(6600, 16000));
          expect(s.vertices.length, greaterThan(50));
          // Entre a primeira e a última ligação (de onde o jogador está até a rua), todo ponto do trecho está sobre uma linha.
          for (var i = 2; i + 5 < r.xy.length; i += 2) {
            for (final f in const [0.25, 0.5, 0.75]) {
              final x = r.xy[i] + (r.xy[i + 2] - r.xy[i]) * f, y = r.xy[i + 1] + (r.xy[i + 3] - r.xy[i + 1]) * f;
              expect(toPack(x, y), lessThan(0.2), reason: 'ponto ${i ~/ 2} fora das ruas: ($x, $y)');
            }
          }
          final v = s.vertices;
          for (var i = 0; i + 1 < v.length; i++) {
            final (l, a0) = v[i];
            final (l1, a1) = v[i + 1];
            if (l.key != l1.key) continue; // a esquina
            expect((a1 - a0).abs(), 1);
            final seg = a0 < a1 ? a0 : a1;
            expect(bits(l, seg) & p.closedBit, 0, reason: 'trecho fechado para ${p.name}');
            if (p == RouteProfile.motor) {
              expect(l.isPedestrian, isFalse, reason: 'carro em caminho de pedestre');
              if (l.oneway == OneWay.forward) expect(a1, a0 + 1, reason: 'contramão');
              if (l.oneway == OneWay.reverse) expect(a1, a0 - 1, reason: 'contramão');
            }
          }
        });
      }
    }

    test('o arquivo de rota de Campinas tem as vias fechadas e os viadutos', () {
      expect(access.lineCount, 11975);
      expect(bits, isNotNull);
      expect(kAccessBridge, 8);
    });
  });
}
