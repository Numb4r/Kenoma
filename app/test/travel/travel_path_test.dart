import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/pcg32.dart';
import 'package:kenoma/data/map_sources.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/travel/travel_path.dart';
import 'package:kenoma/world/traffic_graph.dart';

const int tx0 = 12100, ty0 = 18500;
const double mpc = 17;

/// A célula do nó `(i, j)` da grade: nós a cada 8 células.
double nx(int i) => tx0 * 64.0 + i * 8;
double ny(int j) => ty0 * 64.0 + j * 8;

/// Grade 7×7 de ruas de um trecho por quadra. A vertical `x = 2` é mão única para baixo e a horizontal `y = 7` é de pedestre.
TrafficGraph grid({bool empty = false}) {
  final lines = <VisualLine>[];
  for (var k = 1; k <= 7; k++) {
    for (var j = 1; j < 7; j++) {
      lines.add(VisualLine(k == 7 ? RoadClass.pedestrian : RoadClass.local, Int32List.fromList([j * 512, k * 512, (j + 1) * 512, k * 512])));
      lines.add(VisualLine(RoadClass.local, Int32List.fromList([k * 512, j * 512, k * 512, (j + 1) * 512]), oneway: k == 2 ? OneWay.forward : OneWay.twoWay));
    }
  }
  final t = VisualTile(lines: lines, areas: const []);
  return TrafficGraph(loadTile: (x, y) => !empty && x == tx0 && y == ty0 ? t : null, cellsPerTile: 64, extent: 4096);
}

TravelPath? route(TrafficGraph g, (int, int) a, (int, int) b, {bool motorized = true, int maxNodes = 100000}) => findRoute(g,
    fromX: nx(a.$1), fromY: ny(a.$2), toX: nx(b.$1), toY: ny(b.$2), rules: RouteRules(motorized: motorized), mpc: mpc, snapM: 100, maxNodes: maxNodes);

class _NoWalk implements NoWalkSource {
  _NoWalk(this.segments);

  final List<double> segments;

  @override
  List<double> near(int cx, int cy) => segments;
}

void main() {
  const block = 8 * mpc; // uma quadra, em metros

  group('A* no grafo de ruas', () {
    test('acha o caminho mais curto pela grade', () {
      final r = route(grid(), (1, 1), (5, 3))!;
      expect(r.lengthM, closeTo(6 * block, 1e-6));
      expect(r.at(0).x, nx(1));
      expect(r.at(1e9).x, nx(5));
      expect(r.at(1e9).y, ny(3));
    });

    test('origem e destino iguais dão caminho sem comprimento', () {
      expect(route(grid(), (3, 3), (3, 3))!.lengthM, closeTo(0, 1e-6));
    });

    test('motorizado respeita a mão única; a pé, não', () {
      expect(route(grid(), (2, 5), (2, 2), motorized: false)!.lengthM, closeTo(3 * block, 1e-6));
      expect(route(grid(), (2, 5), (2, 2))!.lengthM, closeTo(5 * block, 1e-6), reason: 'desvia pela paralela');
      expect(route(grid(), (2, 2), (2, 5))!.lengthM, closeTo(3 * block, 1e-6), reason: 'a favor da mão vai reto');
    });

    test('a pé e de bicicleta a rota desvia de rodovia; de carro passa por ela', () {
      // A horizontal y=3 entre os nós 2 e 6 é rodovia.
      final rodovia = _NoWalk([nx(2), ny(3), nx(6), ny(3)]);
      final rules = RouteRules(motorized: false, highway: highwayTest(rodovia, 1));
      final g = grid();
      final aPe = findRoute(g, fromX: nx(3), fromY: ny(3), toX: nx(5), toY: ny(3), rules: rules, mpc: mpc, snapM: 100, maxNodes: 100000)!;
      expect(aPe.lengthM, closeTo(4 * block, 1e-6), reason: 'sai da rodovia e volta pela paralela');
      expect(route(g, (3, 3), (5, 3))!.lengthM, closeTo(2 * block, 1e-6));
    });

    test('motorizado fica fora do caminho de pedestre', () {
      expect(route(grid(), (3, 7), (5, 7), motorized: false)!.lengthM, closeTo(2 * block, 1e-6));
      expect(route(grid(), (3, 7), (5, 7))!.lengthM, closeTo(4 * block, 1e-6), reason: 'sobe, anda pela rua e desce');
    });

    test('sem grafo, destino longe de qualquer rua ou passando do teto: sem rota', () {
      expect(route(grid(empty: true), (1, 1), (5, 3)), isNull);
      expect(findRoute(grid(), fromX: nx(1), fromY: ny(1), toX: nx(1) + 5000, toY: ny(1), rules: const RouteRules(motorized: true), mpc: mpc, snapM: 100, maxNodes: 100000), isNull);
      expect(route(grid(), (1, 1), (6, 6), maxNodes: 3), isNull);
    });

    test('em fatias dá o mesmo resultado', () async {
      final r = await findRouteAsync(grid(), fromX: nx(1), fromY: ny(1), toX: nx(5), toY: ny(3), rules: const RouteRules(motorized: true), mpc: mpc, snapM: 100, maxNodes: 100000, sliceNodes: 2);
      expect(r!.lengthM, closeTo(6 * block, 1e-6));
    });
  });

  group('TravelPath', () {
    test('distância de um ponto até a linha', () {
      final p = TravelPath.straight(0, 0, 10, 0, 2);
      expect(p.lengthM, 20);
      expect(p.distanceToM(5, 3), closeTo(6, 1e-9));
      expect(p.distanceToM(13, 0), closeTo(6, 1e-9));
    });
  });

  group('o carro da corrida', () {
    Future<TravelPath> go(TrafficGraph g, int seed) => approachPath(g, Pcg32(seed, 7), px: nx(4), py: ny(4), distM: 3 * block, mpc: mpc, snapM: 100, maxNodes: 100000, sliceNodes: 100, tries: 8);

    test('vem pelas ruas até o jogador, e a mesma seed dá o mesmo caminho', () async {
      final a = await go(grid(), 42), b = await go(grid(), 42);
      expect(a.xy, b.xy);
      expect(a.pointCount, greaterThan(2));
      final end = a.at(a.lengthM);
      expect((end.x, end.y), (nx(4), ny(4)));
    });

    test('sem grafo aparece em linha reta', () async {
      final p = await go(grid(empty: true), 42);
      expect(p.pointCount, 2);
      expect(p.lengthM, closeTo(3 * block, 1e-6));
    });
  });

  group('o carro indo embora', () {
    test('segue pela rua, na direção em que vinha', () {
      final p = leavePath(grid(), nx(3), ny(3), 0, 2 * block, mpc: mpc, snapM: 100);
      expect(p.lengthM, greaterThanOrEqualTo(2 * block - 1e-6));
      expect(p.at(p.lengthM).y, closeTo(ny(3), 1e-6));
      expect(p.at(p.lengthM).x, greaterThan(nx(4)));
    });

    test('sem grafo vai em linha reta', () {
      final p = leavePath(grid(empty: true), nx(3), ny(3), 0, 100, mpc: mpc, snapM: 100);
      expect(p.pointCount, 2);
      expect(p.lengthM, closeTo(100, 1e-6));
    });
  });
}
