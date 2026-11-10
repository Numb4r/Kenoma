import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/pcg32.dart';
import 'package:kenoma/data/map_sources.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/travel/travel_path.dart';
import 'package:kenoma/world/fallback/osm_rules.dart' show accessMask;
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
    fromX: nx(a.$1), fromY: ny(a.$2), toX: nx(b.$1), toY: ny(b.$2), rules: RouteRules(motorized ? RouteProfile.motor : RouteProfile.foot), mpc: mpc, snapM: 100, maxNodes: maxNodes);

class _NoWalk implements NoWalkSource {
  _NoWalk(this.segments);

  final List<double> segments;

  @override
  List<double> near(int cx, int cy) => segments;
}

class _Access implements RouteAccessSource {
  _Access(this.segments);

  final List<double> segments;

  @override
  List<double> accessNear(int cx, int cy) => segments;
}

/// Um grafo com as linhas [byTile] (em unidades de tile), com ou sem o corte nas esquinas.
TrafficGraph lines(Map<(int, int), List<VisualLine>> byTile, {bool stitch = true, bool Function(double, double)? noCrossingAt}) => TrafficGraph(
    loadTile: (x, y) => byTile[(x - tx0, y - ty0)] == null ? null : VisualTile(lines: byTile[(x - tx0, y - ty0)]!, areas: const []),
    cellsPerTile: 64,
    extent: 4096,
    stitch: stitch,
    noCrossingAt: noCrossingAt);

VisualLine road(List<int> xy) => VisualLine(RoadClass.local, Int32List.fromList(xy));

/// A rota entre duas posições em células relativas ao canto do tile de teste.
TravelPath? cellsRoute(TrafficGraph g, (double, double) a, (double, double) b, {RouteRules rules = const RouteRules(RouteProfile.motor)}) => findRoute(g,
    fromX: tx0 * 64 + a.$1, fromY: ty0 * 64 + a.$2, toX: tx0 * 64 + b.$1, toY: ty0 * 64 + b.$2, rules: rules, mpc: mpc, snapM: 100, maxNodes: 100000);

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
      final rules = RouteRules(RouteProfile.foot, highway: highwayTest(rodovia, 1));
      final g = grid();
      final aPe = findRoute(g, fromX: nx(3), fromY: ny(3), toX: nx(5), toY: ny(3), rules: rules, mpc: mpc, snapM: 100, maxNodes: 100000)!;
      expect(aPe.lengthM, closeTo(4 * block, 1e-6), reason: 'sai da rodovia e volta pela paralela');
      expect(route(g, (3, 3), (5, 3))!.lengthM, closeTo(2 * block, 1e-6));
    });

    test('motorizado fica fora do caminho de pedestre', () {
      expect(route(grid(), (3, 7), (5, 7), motorized: false)!.lengthM, closeTo(2 * block, 1e-6));
      expect(route(grid(), (3, 7), (5, 7))!.lengthM, closeTo(4 * block, 1e-6), reason: 'sobe, anda pela rua e desce');
    });

    test('sem grafo ou passando do teto: sem rota', () {
      expect(route(grid(empty: true), (1, 1), (5, 3)), isNull);
      expect(route(grid(), (1, 1), (6, 6), maxNodes: 3), isNull);
    });

    test('destino fora dos dados: pelas ruas até a beira e reta tracejada até ele', () {
      final r = findRoute(grid(), fromX: nx(1), fromY: ny(1), toX: nx(1) + 5000, toY: ny(1), rules: const RouteRules(RouteProfile.motor), mpc: mpc, snapM: 100, maxNodes: 100000)!;
      expect(r.offData, isTrue);
      final i = r.dashFrom!;
      expect(r.xy[2 * i], nx(7), reason: 'a beira dos dados na direção do destino é a última vertical');
      expect(r.xy[2 * i + 1], closeTo(ny(1), 1e-9));
      expect(r.xy[r.xy.length - 2], nx(1) + 5000);
    });

    test('em fatias dá o mesmo resultado', () async {
      final r = await findRouteAsync(grid(), fromX: nx(1), fromY: ny(1), toX: nx(5), toY: ny(3), rules: const RouteRules(RouteProfile.motor), mpc: mpc, snapM: 100, maxNodes: 100000, sliceNodes: 2);
      expect(r!.lengthM, closeTo(6 * block, 1e-6));
    });
  });

  group('esquinas sem vértice comum (o pacote simplifica e corta nos tiles)', () {
    // Uma rua reta de um trecho só, de (0, 8) a (16, 8) células, e outras que encostam ou cruzam no meio dela.
    final main = road([0, 512, 1024, 512]);

    test('em T: a ponta de uma rua no meio do trecho da outra', () {
      final t = {(0, 0): [main, road([512, 512, 512, 2048])]};
      expect(cellsRoute(lines(t, stitch: false), (0, 8), (8, 32)), isNull, reason: 'sem o corte só há as pontas');
      expect(cellsRoute(lines(t), (0, 8), (8, 32))!.lengthM, closeTo(32 * mpc, 1e-6));
    });

    test('em X: dois trechos que se cruzam no meio; no viaduto, não', () {
      final t = {(0, 0): [main, road([512, 0, 512, 1024])]};
      expect(cellsRoute(lines(t, stitch: false), (0, 8), (8, 0)), isNull);
      expect(cellsRoute(lines(t), (0, 8), (8, 0))!.lengthM, closeTo(16 * mpc, 1e-6));
      expect(cellsRoute(lines(t, noCrossingAt: (x, y) => true), (0, 8), (8, 0)), isNull, reason: 'um passa por cima do outro');
    });

    test('na emenda de dois tiles: os pedaços da mesma rua se sobrepõem na sobra, sem ponta em comum', () {
      final t = {
        (0, 0): [road([2048, 2048, 4096 + 41, 2048])],
        (1, 0): [road([-41, 2048, 2048, 2048])],
      };
      expect(cellsRoute(lines(t, stitch: false), (32, 32), (96, 32)), isNull);
      expect(cellsRoute(lines(t), (32, 32), (96, 32))!.lengthM, closeTo(64 * mpc, 1e-6));
      expect(cellsRoute(lines(t), (96, 32), (32, 32))!.lengthM, closeTo(64 * mpc, 1e-6), reason: 'e de volta');
    });

    test('a origem e o destino entram no meio do trecho, não no vértice mais perto', () {
      final r = cellsRoute(lines({(0, 0): [main]}), (5, 9), (11, 7))!;
      expect(r.lengthM, closeTo((1 + 6 + 1) * mpc, 1e-6), reason: 'desce na rua, anda 6 e sobe');
    });
  });

  group('perfis e o arquivo de rota', () {
    // A horizontal y = 3 entre os nós 3 e 4: [bits] no arquivo de rota.
    RouteRules closed(RouteProfile p, int bits) => RouteRules(p, access: accessTest(_Access([nx(3), ny(3), nx(4), ny(3), bits.toDouble()]), 0.5));
    TravelPath? r(RouteProfile p, int bits) =>
        findRoute(grid(), fromX: nx(3), fromY: ny(3), toX: nx(4), toY: ny(3), rules: closed(p, bits), mpc: mpc, snapM: 100, maxNodes: 100000);

    test('a via fechada fica fora só do perfil fechado', () {
      expect(r(RouteProfile.motor, kAccessMotor)!.lengthM, closeTo(3 * block, 1e-6), reason: 'carro dá a volta na quadra');
      expect(r(RouteProfile.foot, kAccessMotor)!.lengthM, closeTo(block, 1e-6), reason: 'a pé passa');
      expect(r(RouteProfile.foot, kAccessFoot | kAccessBike | kAccessMotor)!.lengthM, closeTo(3 * block, 1e-6), reason: 'access=private');
      expect(r(RouteProfile.bike, kAccessBike)!.lengthM, closeTo(3 * block, 1e-6), reason: 'escada');
      expect(r(RouteProfile.motor, kAccessBridge)!.lengthM, closeTo(block, 1e-6), reason: 'viaduto não fecha nada');
    });

    test('só a via inteira fecha: a rua que cruza uma via fechada continua aberta', () {
      // A via fechada cruza a horizontal y = 3 no meio, na vertical.
      final rules = RouteRules(RouteProfile.motor, access: accessTest(_Access([nx(3) + 4, ny(2), nx(3) + 4, ny(4), kAccessMotor.toDouble()]), 0.5));
      expect(findRoute(grid(), fromX: nx(3), fromY: ny(3), toX: nx(4), toY: ny(3), rules: rules, mpc: mpc, snapM: 100, maxNodes: 100000)!.lengthM, closeTo(block, 1e-6));
    });

    test('bicicleta respeita a mão; a pé, não', () {
      TravelPath? go(RouteProfile p) => findRoute(grid(), fromX: nx(2), fromY: ny(5), toX: nx(2), toY: ny(2), rules: RouteRules(p), mpc: mpc, snapM: 100, maxNodes: 100000);
      expect(go(RouteProfile.bike)!.lengthM, closeTo(5 * block, 1e-6));
      expect(go(RouteProfile.foot)!.lengthM, closeTo(3 * block, 1e-6));
    });

    test('os bits de acesso seguem a regra do pipeline', () {
      expect(accessMask({'highway': 'service', 'access': 'private'}), kAccessFoot | kAccessBike | kAccessMotor);
      expect(accessMask({'highway': 'residential', 'access': 'private', 'foot': 'yes'}), kAccessBike | kAccessMotor);
      expect(accessMask({'highway': 'pedestrian', 'access': 'no', 'bicycle': 'designated'}), kAccessFoot | kAccessMotor);
      expect(accessMask({'highway': 'steps'}), kAccessBike);
      expect(accessMask({'highway': 'footway', 'bicycle': 'yes'}), 0);
      expect(accessMask({'highway': 'cycleway'}), 0);
      expect(accessMask({'highway': 'residential', 'motor_vehicle': 'no'}), kAccessMotor);
      expect(accessMask({'highway': 'primary', 'bridge': 'yes'}), kAccessBridge);
      expect(accessMask({'highway': 'primary', 'bridge': 'no', 'access': 'destination'}), 0);
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
