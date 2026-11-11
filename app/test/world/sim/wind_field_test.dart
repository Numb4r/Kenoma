import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/sim/lane_graph.dart';
import 'package:kenoma/world/sim/traffic_sim_config.dart';
import 'package:kenoma/world/sim/wind_field.dart';
import 'package:kenoma/world/traffic_graph.dart';

void main() {
  // Uma rua leste-oeste e uma norte-sul que se cruzam no meio do tile.
  final tile = VisualTile(lines: [
    VisualLine(RoadClass.principal, Int32List.fromList([200, 3200, 6200, 3200])),
    VisualLine(RoadClass.local, Int32List.fromList([3200, 200, 3200, 6200])),
  ], areas: const []);
  final graph = TrafficGraph(loadTile: (x, y) => x == 1000 && y == 1000 ? tile : null, cellsPerTile: 64, extent: 6400, stitch: true);
  final g = LaneGraph.build(graph, cx: 64032, cy: 64032, mpc: 17.6, seed: 1, config: const TrafficSimConfig(radiusM: 500));
  double speed((double, double) v) => math.sqrt(v.$1 * v.$1 + v.$2 * v.$2);
  // A média no tempo (as rajadas sobem e descem).
  (double, double) mean(double x, double y, double heading) {
    var sx = 0.0, sy = 0.0;
    for (var t = 0.0; t < 400; t += 0.5) {
      final v = localWind(g, x, y, heading, 5, t);
      sx += v.$1;
      sy += v.$2;
    }
    return (sx / 800, sy / 800);
  }

  test('o grafo sabe a direção da rua em cada célula', () {
    final ew = g.streetDir(64010.5, 64032.2)!, ns = g.streetDir(64032.2, 64050.5)!;
    expect(ew.$1.abs(), closeTo(1, 1e-9));
    expect(ns.$2.abs(), closeTo(1, 1e-9));
    expect(g.streetDir(64010.5, 64010.5), isNull, reason: 'no meio do quarteirão');
  });

  test('vento desviado pelas ruas: acelera ao longo da rua, quase some na rua de través, fraco atrás da quadra', () {
    const east = math.pi / 2; // sopra para leste
    final along = mean(64010.5, 64032.2, east), across = mean(64032.2, 64050.5, east), block = mean(64010.5, 64010.5, east);
    expect(along.$1, greaterThan(0), reason: 'para leste');
    expect(speed(along), greaterThan(speed(block) * 2), reason: 'a rua no sentido do vento canaliza');
    expect(speed(across), lessThan(speed(block)), reason: 'na rua de través sobra pouco');
    expect(speed(block), lessThan(5 * 0.6), reason: 'atrás das quadras, abrigado');
    // Vento de nordeste numa rua leste-oeste: vira para o eixo da rua.
    final ne = mean(64010.5, 64032.2, math.pi / 4);
    expect(ne.$1.abs(), greaterThan(ne.$2.abs() * 3), reason: 'desviado para o eixo da rua');
  });

  test('rajadas: a força sobe e desce no tempo, nunca inverte', () {
    var lo = double.infinity, hi = 0.0;
    for (var t = 0.0; t < 200; t += 0.25) {
      final v = localWind(g, 64010.5, 64032.2, math.pi / 2, 5, t);
      expect(v.$1, greaterThan(0));
      lo = math.min(lo, speed(v));
      hi = math.max(hi, speed(v));
    }
    expect(hi / lo, greaterThan(1.8));
  });

  test('folhas: nascem fora da vista, do lado de onde o vento vem, e seguem o vento', () {
    final leaves = WindLeaves(count: 30)..start(-100);
    const l = 64028.0, t = 64028.0, r = 64036.0, b = 64040.0;
    leaves.update(0.1, g, math.pi / 2, 5, 0, 17.6, l, t, r, b);
    expect(leaves.leaves.length, 30);
    for (final lf in leaves.leaves) {
      expect(lf.x < l || lf.y < t || lf.y > b, isTrue, reason: 'nascem fora da tela');
      expect(lf.x, lessThan(r), reason: 'do lado oeste: o vento sopra para leste');
    }
    final x0 = leaves.leaves.fold(0.0, (a, f) => a + f.x) / 30;
    for (var i = 1; i < 50; i++) {
      leaves.update(0.1, g, math.pi / 2, 5, i * 0.1, 17.6, l, t, r, b);
    }
    expect(leaves.leaves.fold(0.0, (a, f) => a + f.x) / leaves.leaves.length, greaterThan(x0), reason: 'foram para leste');
    leaves.update(0.1, g, 0, 0, 6, 17.6, l, t, r, b);
    expect(leaves.leaves, isEmpty, reason: 'sem vento, sem folhas');
  });
}
