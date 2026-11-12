import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/data/traffic_pack.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/sim/traffic_sim.dart';
import 'package:kenoma/world/traffic_graph.dart';

const mpc = 17.6;
const tx0 = 1000, ty0 = 1000, ext = 6400; // 100 unidades por célula

/// Uma cidade em grade: ruas a cada 6 células (~105 m), de 2 a 62; as do meio (32) são avenidas.
TrafficGraph city({bool oneway = false}) {
  final lines = <VisualLine>[];
  for (var k = 2; k <= 62; k += 6) {
    final cls = k == 32 ? RoadClass.principal : RoadClass.local;
    lines.add(VisualLine(cls, Int32List.fromList([200, k * 100, 6200, k * 100]), oneway: oneway && k == 26 ? OneWay.forward : OneWay.twoWay));
    lines.add(VisualLine(cls, Int32List.fromList([k * 100, 200, k * 100, 6200])));
  }
  final tile = VisualTile(lines: lines, areas: const []);
  return TrafficGraph(loadTile: (x, y) => x == tx0 && y == ty0 ? tile : null, cellsPerTile: 64, extent: ext, stitch: true);
}

double gx(double c) => tx0 * 64 + c;
double gy(double c) => ty0 * 64 + c;

TrafficPack signals() => TrafficPack.of([
      (kind: TrafficPointKind.signal, x: gx(32), y: gy(32)),
      (kind: TrafficPointKind.crossing, x: gx(33), y: gy(32)),
      (kind: TrafficPointKind.crossing, x: gx(32), y: gy(33)),
      (kind: TrafficPointKind.entry, x: gx(14), y: gy(14)),
    ]);

TrafficSim sim({TrafficSimConfig config = const TrafficSimConfig(radiusM: 300, warmupS: 20), int seed = 7}) =>
    TrafficSim(graph: city(), seed: seed, config: config, points: signals());

/// A vista: 80 m em volta do centro.
const view = (l: 27.5, t: 27.5, r: 36.5, b: 36.5);

void center(TrafficSim s, {double hour = 18}) => s.center(gx(32), gy(32), mpc, left: gx(view.l), top: gy(view.t), right: gx(view.r), bottom: gy(view.b), hour: hour);

bool inView(double x, double y, [double m = 0]) => x >= gx(view.l) - m && x <= gx(view.r) + m && y >= gy(view.t) - m && y <= gy(view.b) + m;

void main() {
  test('o grafo de faixas tem esquinas, mãos e o semáforo do OSM', () {
    final s = sim();
    center(s);
    final g = s.lanes!;
    final mid = g.nodes.firstWhere((n) => (n.x - gx(32)).abs() < 0.1 && (n.y - gy(32)).abs() < 0.1);
    expect(mid.arms.length, 4);
    expect(mid.signal, isTrue);
    expect(mid.controlled, isTrue);
    expect(mid.incoming.map((k) => k.group).toSet(), {0, 1});
    expect(mid.incoming.first.lanes.length, 2, reason: 'avenida: duas faixas por sentido');
    final other = g.nodes.firstWhere((n) => (n.x - gx(26)).abs() < 0.1 && (n.y - gy(26)).abs() < 0.1);
    expect(other.signal, isFalse);
    expect(other.incoming.every((k) => k.yields), isTrue, reason: 'ruas iguais: todos param');
    final t = g.nodes.firstWhere((n) => (n.x - gx(32)).abs() < 0.1 && (n.y - gy(26)).abs() < 0.1);
    expect(t.incoming.where((k) => k.yields).every((k) => k.roadClass == RoadClass.local), isTrue);
    expect(t.incoming.where((k) => !k.yields).every((k) => k.roadClass == RoadClass.principal), isTrue);
    expect(g.nodes.any((n) => n.border), isTrue);
    expect(g.nodes.any((n) => n.entry), isTrue);
  });

  test('a área já começa povoada, espalhada pelas ruas', () {
    final s = sim();
    center(s);
    expect(s.cars.length, greaterThan(15));
    expect(s.walkers.length, greaterThan(15));
    expect(s.cars.where((c) => inView(c.x, c.y)).isNotEmpty, isTrue);
    final far = s.cars.where((c) => (c.x - gx(32)).abs() > 8 || (c.y - gy(32)).abs() > 8);
    expect(far.isNotEmpty, isTrue);
  });

  test('ninguém nasce nem some dentro da vista', () {
    final s = sim();
    center(s);
    var seen = {for (final c in s.cars) c.id: inView(c.x, c.y), for (final w in s.walkers) w.id: inView(w.x, w.y)};
    for (var i = 0; i < 6000; i++) {
      s.step(0.1, hour: 18);
      final now = {for (final c in s.cars) c.id: (c.x, c.y), for (final w in s.walkers) w.id: (w.x, w.y)};
      for (final e in now.entries) {
        if (!seen.containsKey(e.key)) expect(inView(e.value.$1, e.value.$2, 1), isFalse, reason: 'nasceu na vista no passo $i');
      }
      for (final e in seen.entries) {
        // Quem sumiu estava fora da vista no passo anterior (um passo anda no máximo ~1,5 m).
        if (!now.containsKey(e.key)) expect(e.value, isFalse, reason: 'sumiu na vista no passo $i');
      }
      seen = {for (final e in now.entries) e.key: inView(e.value.$1, e.value.$2, -0.2)};
    }
    expect(s.bornInView, 0);
    expect(s.goneInView, 0);
    expect(s.cars.length, greaterThan(10), reason: 'o tráfego se mantém');
  });

  test('carros não se atravessam e ninguém anda de ré', () {
    final s = sim();
    center(s);
    var moved = 0.0;
    for (var i = 0; i < 4000; i++) {
      s.step(0.1, hour: 18);
      for (final c in s.cars) {
        expect(c.v, greaterThanOrEqualTo(0));
        moved += c.v;
      }
      for (final link in s.lanes!.links) {
        for (final lane in link.cars) {
          for (var k = 1; k < lane.length; k++) {
            expect(lane[k - 1].s - lane[k].s, greaterThan((lane[k - 1].length + lane[k].length) / 2 - 0.05), reason: 'fila sobreposta no passo $i');
          }
        }
      }
      // Em qualquer lugar (inclusive dentro das esquinas), dois carros nunca ficam com os centros a menos de 1,5 m.
      final cs = s.cars;
      for (var a = 0; a < cs.length; a++) {
        for (var b = a + 1; b < cs.length; b++) {
          final dx = (cs[a].x - cs[b].x) * mpc, dy = (cs[a].y - cs[b].y) * mpc;
          if (dx.abs() < 1.5 && dy.abs() < 1.5) expect(math.sqrt(dx * dx + dy * dy), greaterThan(1.5), reason: 'carros ${cs[a].id} e ${cs[b].id} no passo $i');
        }
      }
    }
    expect(moved, greaterThan(0));
  });

  test('carro para no vermelho e anda no verde', () {
    final s = sim();
    center(s);
    final g = s.lanes!;
    final mid = g.nodes.firstWhere((n) => n.signal);
    var crossedRed = 0, crossedGreen = 0, waited = 0;
    // Quem já tinha a vez quando a contagem começa (do aquecimento) não conta.
    final inside = <int>{for (final link in mid.incoming) for (final lane in link.cars) for (final o in lane) if ((o as SimCar).reserved) o.id};
    for (var i = 0; i < 6000; i++) {
      s.step(0.1, hour: 18);
      for (final link in mid.incoming) {
        final light = mid.light(link.group, s.time, s.config);
        for (final lane in link.cars) {
          for (final o in lane) {
            final c = o as SimCar;
            // A vez é decidida ao reservar a esquina (no amarelo, só quem não consegue mais parar).
            if (c.reserved && inside.add(c.id)) light == SignalLight.red ? crossedRed++ : crossedGreen++;
            if (!c.reserved) inside.remove(c.id);
            if (!c.inJunction && light == SignalLight.red && c.v < 0.1 && link.length - c.s < 12) waited++;
          }
        }
      }
    }
    expect(crossedRed, 0);
    expect(crossedGreen, greaterThan(5));
    expect(waited, greaterThan(50), reason: 'alguém esperou parado no vermelho');
  });

  test('passante só atravessa na faixa, e no semáforo só com os carros no vermelho', () {
    final s = sim()..forcedDensity = 2.5;
    center(s);
    final g = s.lanes!;
    var crossings = 0, atSignal = 0;
    for (var i = 0; i < 8000; i++) {
      s.step(0.1, hour: 18);
      for (final w in s.walkers) {
        // Fora das travessias e das viradas de esquina, o passante está sempre na calçada (fora da pista).
        if (w.mode == WalkerMode.walking && !w.edge.isPedestrian) {
          final e = w.edge;
          final onX = (e.ys[0] - e.ys[1]).abs() < 1e-9;
          final d = (onX ? (w.y - e.ys[0]) : (w.x - e.xs[0])).abs() * mpc;
          expect(d, greaterThan(e.halfWidthM + 0.5), reason: 'passante na pista');
        }
        if (w.mode != WalkerMode.crossing || w.tPos > 0.2) continue;
        crossings++;
        final node = w.atA ? w.edge.a : w.edge.b;
        final arm = node.arms[node.armOf(w.edge)];
        expect(arm.crossable, isTrue);
        expect(node.arms.length, greaterThan(2), reason: 'sem faixa mapeada, só na esquina');
        if (node.signal) {
          atSignal++;
          expect(node.light(arm.group, s.time, s.config), SignalLight.red);
        }
      }
    }
    expect(crossings, greaterThan(20));
    expect(atSignal, greaterThan(0));
    final mid = g.nodes.firstWhere((n) => n.signal);
    expect(mid.arms.where((a) => a.crossable).length, 2, reason: 'só as duas ruas com faixa mapeada');
  });

  test('carro espera o passante que atravessa', () {
    final s = sim()..forcedDensity = 2.5;
    center(s);
    for (var i = 0; i < 6000; i++) {
      s.step(0.1, hour: 18);
      for (final w in s.walkers) {
        if (w.mode != WalkerMode.crossing) continue;
        for (final c in s.cars) {
          final dx = (c.x - w.x) * mpc, dy = (c.y - w.y) * mpc;
          expect(dx * dx + dy * dy, greaterThan(1.0), reason: 'carro ${c.id} em cima do passante ${w.id} no passo $i');
        }
      }
    }
  });

  test('Silêncio: sem passo nada se mexe, e depois continua de onde parou', () {
    final s = sim();
    center(s);
    for (var i = 0; i < 300; i++) {
      s.step(0.1, hour: 18);
    }
    final before = {for (final c in s.cars) c.id: (c.x, c.y, c.v)};
    final t = s.time;
    // O Silêncio dura uma hora: o jogo não chama step. Só centra a área de novo, no mesmo lugar.
    center(s);
    expect(s.time, t);
    expect({for (final c in s.cars) c.id: (c.x, c.y, c.v)}, before);
    s.step(0.1, hour: 18);
    for (final c in s.cars) {
      final b = before[c.id];
      if (b == null) continue;
      expect(((c.x - b.$1) * mpc).abs() + ((c.y - b.$2) * mpc).abs(), lessThan(6.0), reason: 'sem salto');
    }
  });

  test('densidade segue a hora e o clima; rua fechada não recebe carro', () {
    final rush = sim()..center(gx(32), gy(32), mpc, hour: 18);
    final night = sim()..center(gx(32), gy(32), mpc, hour: 3.5);
    final storm = sim()..center(gx(32), gy(32), mpc, hour: 18, density: 0.4);
    expect(night.cars.length, lessThan(rush.cars.length ~/ 3));
    expect(storm.cars.length, lessThan(rush.cars.length));
    final s = sim();
    center(s);
    s.lanes!.applyStreets((l) => l.key.$3 == 4, null);
    for (var i = 0; i < 3000; i++) {
      s.step(0.1, hour: 18);
    }
    for (var i = 0; i < 1500; i++) {
      s.step(0.1, hour: 18);
      for (final c in s.cars) {
        if (c.edge.closed) expect(c.odo, greaterThan(0));
      }
    }
    expect(s.cars.where((c) => c.edge.closed && c.s < c.link.length * 0.5 && c.odo > 400).length, lessThan(3), reason: 'quem já estava sai; ninguém novo entra');
  });

  test('andar refaz a área em volta e mantém quem está perto', () {
    final s = sim();
    center(s);
    for (var i = 0; i < 200; i++) {
      s.step(0.1, hour: 18);
    }
    final near = {for (final c in s.cars) if (inView(c.x, c.y)) c.id: (c.x, c.y)};
    final old = s.lanes;
    s.center(gx(32) + 10, gy(32), mpc, left: gx(view.l), top: gy(view.t), right: gx(view.r), bottom: gy(view.b), hour: 18);
    expect(identical(s.lanes, old), isFalse);
    final now = {for (final c in s.cars) c.id: (c.x, c.y)};
    for (final e in near.entries) {
      expect(now[e.key], e.value, reason: 'carro perto sumiu ou pulou ao refazer o grafo');
    }
    for (var i = 0; i < 500; i++) {
      s.step(0.1, hour: 18);
    }
    expect(s.bornInView, 0);
    expect(s.goneInView, 0);
  });

  test('desempenho: 60 carros e 80 passantes abaixo de 2 ms por passo', () {
    final s = sim(config: const TrafficSimConfig(radiusM: 300, warmupS: 20, maxCars: 60, maxWalkers: 80))..forcedDensity = 3;
    center(s);
    for (var i = 0; i < 600; i++) {
      s.step(1 / 60, hour: 18);
    }
    expect(s.cars.length, greaterThan(50));
    expect(s.walkers.length, greaterThan(65));
    final sw = Stopwatch()..start();
    for (var i = 0; i < 600; i++) {
      s.step(1 / 60, hour: 18);
    }
    final us = sw.elapsedMicroseconds / 600;
    // ignore: avoid_print
    print('passo médio: ${us.toStringAsFixed(0)} µs com ${s.cars.length} carros e ${s.walkers.length} passantes; grafo em ${s.lanes!.buildUs} µs');
    expect(us, lessThan(2000));
  });

  test('semáforo de pedestre no meio da quadra: os carros param e o passante atravessa', () {
    // Uma rua comprida com um caminho de pedestre que a cruza no meio, e um semáforo do OSM ali.
    final lines = [
      VisualLine(RoadClass.secondary, Int32List.fromList([200, 3200, 6200, 3200])),
      VisualLine(RoadClass.pedestrian, Int32List.fromList([3200, 2000, 3200, 4400])),
    ];
    final tile = VisualTile(lines: lines, areas: const []);
    final graph = TrafficGraph(loadTile: (x, y) => x == tx0 && y == ty0 ? tile : null, cellsPerTile: 64, extent: ext, stitch: true);
    final s = TrafficSim(graph: graph, seed: 3, config: const TrafficSimConfig(radiusM: 300, warmupS: 10), points: TrafficPack.of([(kind: TrafficPointKind.signal, x: gx(32), y: gy(32))]))..forcedDensity = 3;
    s.center(gx(32), gy(32), mpc, hour: 18);
    final mid = s.lanes!.nodes.firstWhere((n) => (n.x - gx(32)).abs() < 0.1 && (n.y - gy(32)).abs() < 0.1);
    expect(mid.signal, isTrue);
    expect(mid.controlled, isFalse);
    var stopped = 0, crossed = 0, passed = 0;
    for (var i = 0; i < 6000; i++) {
      s.step(0.1, hour: 18);
      final red = mid.light(0, s.time, s.config) == SignalLight.red;
      for (final link in mid.incoming) {
        for (final lane in link.cars) {
          for (final o in lane) {
            final c = o as SimCar;
            if (red && !c.reserved && c.v < 0.1 && link.length - c.s < 12) stopped++;
            if (c.inJunction) passed++;
          }
        }
      }
      for (final w in s.walkers) {
        if (w.mode != WalkerMode.crossing || w.edge.isPedestrian || w.tPos > 0.3) continue;
        crossed++;
        expect(red, isTrue, reason: 'passante começou a atravessar com os carros no verde');
      }
    }
    expect(stopped, greaterThan(20));
    expect(passed, greaterThan(20));
    expect(crossed, greaterThan(0));
  });

  test('quando a chuva começa os passantes correm para a marquise e esperam lá; quando para, seguem', () {
    final s = TrafficSim(graph: city(), seed: 5, config: const TrafficSimConfig(radiusM: 300, warmupS: 20), points: TrafficPack.of([
      (kind: TrafficPointKind.busStop, x: gx(26), y: gy(26)),
      (kind: TrafficPointKind.shop, x: gx(38), y: gy(32)),
      (kind: TrafficPointKind.bar, x: gx(32), y: gy(44)),
    ]))
      ..forcedDensity = 2.5;
    center(s);
    final g = s.lanes!;
    expect(g.nodes.where((n) => n.shelter).length, 3);
    expect(g.nodes.where((n) => n.shelterHops == 1).length, greaterThan(6));
    for (var i = 0; i < 300; i++) {
      s.step(0.1, hour: 18);
    }
    double meanSpeed() => s.walkers.where((w) => w.mode == WalkerMode.walking).fold(0.0, (a, w) => a + w.v) / s.walkers.where((w) => w.mode == WalkerMode.walking).length;
    final dry = meanSpeed();
    expect(s.walkers.where((w) => w.mode == WalkerMode.sheltering), isEmpty);
    s.raining = true;
    final caught = {for (final w in s.walkers) if (w.hurry) w.id};
    expect(caught.length, greaterThan(s.walkers.length ~/ 2));
    for (var i = 0; i < 20; i++) {
      s.step(0.1, hour: 18);
    }
    final running = s.walkers.where((w) => w.hurry && w.mode == WalkerMode.walking && w.v > 0).toList();
    expect(running.length, greaterThan(5));
    expect(running.every((w) => w.v > w.speed * 2), isTrue, reason: 'correndo');
    expect(dry, lessThan(2));
    for (var i = 0; i < 1500; i++) {
      s.step(0.1, hour: 18);
    }
    final sheltered = s.walkers.where((w) => w.mode == WalkerMode.sheltering).toList();
    expect(sheltered.length, greaterThan(5), reason: 'em dois minutos e meio, vários já chegaram');
    for (final w in sheltered) {
      expect((w.atA ? w.edge.a : w.edge.b).shelter, isTrue, reason: 'abrigado num abrigo de verdade');
      expect(w.v, 0);
    }
    final where = {for (final w in sheltered) w.id: (w.x, w.y)};
    for (var i = 0; i < 300; i++) {
      s.step(0.1, hour: 18);
    }
    for (final w in s.walkers) {
      if (where.containsKey(w.id)) expect((w.x, w.y), where[w.id], reason: 'fica parado enquanto chove');
    }
    // Quem nasce durante a chuva (já de guarda-chuva) anda normal.
    expect(s.walkers.where((w) => !caught.contains(w.id)).every((w) => !w.hurry), isTrue);
    s.raining = false;
    for (var i = 0; i < 100; i++) {
      s.step(0.1, hour: 18);
    }
    expect(s.walkers.where((w) => w.mode == WalkerMode.sheltering), isEmpty);
    expect(s.walkers.where((w) => where.containsKey(w.id) && (w.x, w.y) != where[w.id]).length, greaterThan(3), reason: 'voltaram a andar');
    expect(s.goneInView, 0);
  });

  group('vida urbana', () {
    TrafficSim town({TrafficSimConfig config = const TrafficSimConfig(radiusM: 300, warmupS: 10)}) => TrafficSim(graph: city(), seed: 9, config: config, points: TrafficPack.of([
          (kind: TrafficPointKind.shop, x: gx(26), y: gy(26)),
          (kind: TrafficPointKind.bar, x: gx(38), y: gy(26)),
          (kind: TrafficPointKind.school, x: gx(26), y: gy(38)),
          (kind: TrafficPointKind.square, x: gx(38), y: gy(38)),
          (kind: TrafficPointKind.busStop, x: gx(32), y: gy(20)),
          (kind: TrafficPointKind.stadium, x: gx(50), y: gy(32)),
        ]));
    Map<String, int> standing(TrafficSim s) {
      final out = <String, int>{};
      for (final w in s.walkers) {
        if (w.mode == WalkerMode.loitering) out[w.loiter!] = (out[w.loiter!] ?? 0) + 1;
      }
      return out;
    }

    test('comércio cheio de dia, bar à noite, escola na hora da saída, gente sentada na praça', () {
      final day = town()..center(gx(32), gy(32), mpc, hour: 15);
      expect(standing(day)['shop'], 3);
      expect(standing(day)['square'], 2);
      expect(day.walkers.where((w) => w.sitting).length, 2);
      expect(standing(day)['bar'], isNull);
      expect(standing(day)['school'], isNull);
      final night = town()..center(gx(32), gy(32), mpc, hour: 21);
      expect(standing(night)['bar'], 4);
      expect(standing(night)['shop'], isNull);
      expect(standing(night)['square'], isNull);
      final out = town()..center(gx(32), gy(32), mpc, hour: 17.5);
      expect(standing(out)['school'], 6);
      // Parados onde estão, junto do lugar deles.
      final w = day.walkers.firstWhere((w) => w.loiter == 'shop');
      final at = (w.x, w.y);
      for (var i = 0; i < 200; i++) {
        day.step(0.1, hour: 15);
      }
      expect((w.x, w.y), at);
      expect(((w.x - gx(26)).abs() + (w.y - gy(26)).abs()) * mpc, lessThan(20));
      // A hora muda: o comércio esvazia e o bar enche, só fora da vista.
      for (var i = 0; i < 3000; i++) {
        day.step(0.1, hour: 21);
      }
      expect(standing(day)['shop'], isNull);
      expect(standing(day)['bar'], 4);
      expect(day.goneInView, 0);
    });

    test('o ônibus para no ponto e quem esperava embarca', () {
      final s = town(config: const TrafficSimConfig(radiusM: 300, warmupS: 10, busShare: 1))..forcedDensity = 1.5;
      s.center(gx(32), gy(32), mpc, hour: 10);
      expect(s.cars.where((c) => c.bus), isNotEmpty);
      expect(s.cars.where((c) => c.bus).length, lessThanOrEqualTo(3));
      var dwelled = 0, waiting = 0;
      for (var i = 0; i < 12000 && (s.boarded == 0 || dwelled < 40); i++) {
        s.step(0.1, hour: 10);
        if (s.cars.any((c) => c.bus && c.dwell > 0 && c.v < 0.2)) dwelled++;
        waiting = math.max(waiting, standing(s)['bus'] ?? 0);
      }
      expect(waiting, 2, reason: 'gente esperando no ponto');
      expect(dwelled, greaterThan(20), reason: 'o ônibus ficou parado no ponto');
      expect(s.boarded, greaterThan(0));
      final b = s.walkers.where((w) => w.mode == WalkerMode.boarding).toList();
      expect(b, isNotEmpty);
      for (var i = 0; i < 400; i++) {
        s.step(0.1, hour: 10);
      }
      expect(b.every((w) => w.gone), isTrue, reason: 'entraram no ônibus');
    });

    test('dia de jogo: os passantes chegam mais perto do estádio', () {
      double meanHops(TrafficSim s) {
        var sum = 0, n = 0;
        for (final w in s.walkers) {
          if (w.mode == WalkerMode.loitering) continue;
          final h = math.min(w.edge.a.stadiumHops, w.edge.b.stadiumHops);
          if (h >= 0) {
            sum += h;
            n++;
          }
        }
        return sum / n;
      }

      final normal = town()..forcedDensity = 2;
      final match = town()
        ..forcedDensity = 2
        ..matchDay = true;
      for (final s in [normal, match]) {
        s.center(gx(32), gy(32), mpc, hour: 15);
        for (var i = 0; i < 4000; i++) {
          s.step(0.1, hour: 15);
        }
      }
      expect(match.lanes!.nodes.where((n) => n.stadiumHops == 0), isNotEmpty);
      expect(meanHops(match), lessThan(meanHops(normal) - 0.5));
      const c = TrafficSimConfig(matchUtc: [1000000], matchBeforeS: 7200);
      expect((c.matchAt(1000000 - 7200), c.matchAt(999999), c.matchAt(1000000), c.matchAt(1000000 - 7201)), (true, true, false, false));
    });
  });

  test('pacote de pontos: lê o formato TRF1', () {
    expect(() => TrafficPack.parse(Uint8List.fromList([1, 2, 3, 4, 5])), throwsFormatException);
  });
}
