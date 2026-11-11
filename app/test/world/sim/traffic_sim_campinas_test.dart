import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/traffic_pack.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/sim/traffic_sim.dart';
import 'package:kenoma/world/traffic_graph.dart';
import 'package:kenoma/world/visual_map.dart';

/// A simulação nas ruas de verdade do pacote embarcado: centro de Campinas (Glicério com Moraes Salles) e um bairro.
void main() {
  final vm = VisualMap(VisualPack.parse(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync()), cacheTiles: 128);
  final pack = TrafficPack.parse(File('assets/regions/campinas_e0_traffic.bin').readAsBytesSync());

  for (final (name, lat, lon) in [('centro', -22.9056, -47.0608), ('Taquaral', -22.8745, -47.0500), ('Barão Geraldo', -22.8170, -47.0810), ('entroncamento', 0.0, 0.0)]) {
    test('Campinas, $name: o tráfego flui, sem sobreposição, e cabe no orçamento', () {
      // O entroncamento da Norte-Sul no Taquaral: ruas que se juntam em ângulo raso, picadas em pedaços curtos.
      final (x, y) = lat == 0 ? (774506.0, 1185523.0) : latLonToTileFraction(lat, lon, 21);
      final mpc = metersPerCell(lat == 0 ? -22.87 : lat);
      final graph = TrafficGraph(loadTile: vm.tile, cellsPerTile: vm.cellsPerTile, extent: vm.pack.extent, cacheTiles: 128, stitch: true);
      final s = TrafficSim(graph: graph, seed: 42, points: pack);
      final view = 110 / mpc; // a tela no zoom aberto: ~220 m
      final sw = Stopwatch()..start();
      s.center(x, y, mpc, left: x - view, top: y - view * 2, right: x + view, bottom: y + view * 2, hour: 18);
      final first = sw.elapsedMilliseconds;
      final g = s.lanes!;
      expect(g.nodes.where((n) => n.signal).length, greaterThan(name == 'centro' ? 5 : 0));
      expect(s.cars.length, greaterThan(30));
      s.forcedDensity = lat == 0 ? 2.5 : null;
      var overlaps = 0, moving = 0.0, samples = 0;
      sw.reset();
      for (var i = 0; i < 3600; i++) {
        s.step(1 / 30, hour: 18);
        if (i % 10 != 0) continue;
        // Só perto da tela: longe dela os carros andam em passo maior e sem a rede de segurança.
        final cs = [for (final c in s.cars) if ((c.x - x).abs() < view && (c.y - y).abs() < view * 2) c];
        for (var a = 0; a < cs.length; a++) {
          moving += cs[a].v;
          samples++;
          for (var b = a + 1; b < cs.length; b++) {
            final dx = (cs[a].x - cs[b].x) * mpc, dy = (cs[a].y - cs[b].y) * mpc;
            if (dx.abs() < 1.5 && dy.abs() < 1.5 && math.sqrt(dx * dx + dy * dy) < 1.5) {
              overlaps++;
            }
          }
        }
      }
      final us = sw.elapsedMicroseconds / 3600;
      final stuck = s.cars.where((c) => c.waitS > 60).length;
      // ignore: avoid_print
      print('$name: ${g.nodes.length} nós, ${g.edges.length} trechos, ${g.nodes.where((n) => n.signal).length} semáforos, ${g.nodes.where((n) => n.entry).length} entradas; '
          'grafo ${g.buildUs ~/ 1000} ms, abrir $first ms; ${s.cars.length} carros, ${s.walkers.length} passantes, passo ${us.toStringAsFixed(0)} µs, '
          'velocidade média ${(moving / samples).toStringAsFixed(1)} m/s, presos $stuck, sobrepostos $overlaps');
      expect(overlaps, 0);
      expect(moving / samples, greaterThan(1.0), reason: 'a cidade não travou');
      expect(stuck, lessThan(s.cars.length ~/ 5));
      expect(s.bornInView, 0);
      expect(s.goneInView, 0);
      expect(us, lessThan(4000), reason: 'o orçamento de verdade é medido no celular; aqui é só um teto folgado');
    });
  }
}
