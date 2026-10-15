import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/veil_traffic.dart';

const seed = 0x6ebe19ac6345175f;
const mpc = 17.6; // metros por célula z21 em Campinas
const noon = 1790035200 + 15 * 3600; // 2026-09-22 15:00 UTC = 12:00 em Campinas

/// Uma rua reta de [cells] células para o leste, no tile (3, 4) (cellsPerTile = 64, extent = 4096).
GhostLine straight({RoadClass c = RoadClass.principal, OneWay oneway = OneWay.twoWay, double cells = 20, int idx = 0, int tx = 3}) {
  final tile = VisualTile(lines: [
    for (var i = 0; i <= idx; i++)
      VisualLine(c, Int32List.fromList([0, 100, (cells * 64).round(), 100]), oneway: oneway),
  ], areas: const []);
  return ghostLinesOfTile(tile, tx, 4, cellsPerTile: 64, extent: 4096)[idx];
}

List<Ghost> at(GhostLine l, int t, {double hour = 12}) => ghostsOn(l, seed: seed, tUtc: t, hour: hour, metersPerCell: mpc);

void main() {
  group('linhas de tráfego', () {
    test('converte o tile em células z21 e acumula o comprimento', () {
      final l = straight(cells: 10);
      expect(l.xy.first, closeTo(3 * 64, 1e-9));
      expect(l.xy[1], closeTo(4 * 64 + 100 / 64, 1e-9));
      expect(l.lengthCells, closeTo(10, 1e-9));
    });

    test('linhas com menos de dois pontos ficam de fora', () {
      final t = VisualTile(lines: [VisualLine(RoadClass.local, Int32List.fromList([5, 5]))], areas: const []);
      expect(ghostLinesOfTile(t, 0, 0, cellsPerTile: 64, extent: 4096), isEmpty);
    });
  });

  group('hora real e densidade', () {
    test('a hora local é a média solar do lugar, sem usar o fuso do aparelho', () {
      expect(localHour(15 * 3600, -45), closeTo(12, 1e-9));
      expect(localHour(2 * 3600, -47.0697), closeTo(22.86, 0.01), reason: '02:00 UTC em Campinas');
      expect(localHour(0, 0), 0);
      expect(localHour(0, -180), closeTo(12, 1e-9));
    });

    test('cheio no rush, vazio de madrugada, meio-termo à tarde', () {
      expect(carDensity(8), greaterThan(0.8));
      expect(carDensity(18), greaterThan(0.8));
      expect(carDensity(3), lessThan(0.1));
      expect(carDensity(13), inInclusiveRange(0.3, 0.7));
      expect(carDensity(3), lessThan(carDensity(13)));
      expect(carDensity(13), lessThan(carDensity(18)));
      for (var h = 0.0; h < 24; h += 0.25) {
        expect(carDensity(h), inInclusiveRange(0.05, 1.0));
        expect(pedestrianDensity(h), inInclusiveRange(0.03, 1.0));
      }
    });

    test('a densidade é contínua na virada do dia', () {
      expect((carDensity(23.99) - carDensity(0.0)).abs(), lessThan(0.02));
    });

    test('mais fantasmas no rush que de madrugada, somando muitas ruas e janelas', () {
      int total(double hour) {
        var n = 0;
        for (var w = 0; w < 30; w++) {
          for (var i = 0; i < 12; i++) {
            n += ghostCount(straight(idx: i, cells: 30), seed, 1000 + w, hour, mpc);
          }
        }
        return n;
      }

      final rush = total(8), night = total(3);
      expect(rush, greaterThan(night * 6));
      expect(night, greaterThan(0), reason: 'madrugada vazia, mas não morta');
    });

    test('avenida enche mais que rua local, e rua local mais que nada', () {
      int total(RoadClass c) => [for (var w = 0; w < 60; w++) ghostCount(straight(c: c, cells: 8), seed, w, 8, mpc)].reduce((a, b) => a + b);
      expect(total(RoadClass.principal), greaterThan(total(RoadClass.secondary)));
      expect(total(RoadClass.secondary), greaterThan(total(RoadClass.local)));
    });
  });

  group('determinismo', () {
    test('a mesma seed, rua, janela e instante dão os mesmos fantasmas, e outra seed dá outros', () {
      final l = straight(cells: 40);
      final a = at(l, noon + 100), b = at(l, noon + 100);
      expect(a, isNotEmpty);
      expect([for (final g in a) (g.x, g.y, g.heading, g.alpha, g.seed)], [for (final g in b) (g.x, g.y, g.heading, g.alpha, g.seed)]);
      final other = ghostsOn(l, seed: seed + 1, tUtc: noon + 100, hour: 12, metersPerCell: mpc);
      expect([for (final g in other) g.x], isNot([for (final g in a) g.x]));
    });

    test('ruas diferentes têm tráfego diferente', () {
      final a = at(straight(idx: 0, cells: 40), noon + 100), b = at(straight(idx: 1, cells: 40), noon + 100);
      expect([for (final g in a) g.seed], isNot([for (final g in b) g.seed]));
    });

    test('os fantasmas andam com o tempo, na velocidade da classe', () {
      final l = straight(cells: 60, oneway: OneWay.forward, c: RoadClass.secondary);
      final t = noon + 300;
      final before = at(l, t), after = at(l, t + 2);
      final moved = <double>[];
      for (final a in before) {
        for (final b in after) {
          if (a.seed == b.seed) moved.add((b.x - a.x) * mpc / 2); // m/s
        }
      }
      expect(moved, isNotEmpty);
      for (final v in moved) {
        expect(v, inInclusiveRange(5.9, 10.1), reason: 'secundária: 6 a 10 m/s');
      }
    });

    test('o fantasma segue o mesmo caminho em instantes diferentes: sempre em cima da rua', () {
      final l = straight(cells: 50, oneway: OneWay.forward);
      for (var s = 0; s < 1000; s += 37) {
        for (final g in at(l, noon + s)) {
          expect(g.y, closeTo(4 * 64 + 100 / 64, 1e-9));
          expect(g.x, inInclusiveRange(3 * 64 - 1e-9, 3 * 64 + 50 + 1e-9));
        }
      }
    });
  });

  group('mão de direção', () {
    test('mão única para a frente: todos vão para o leste; para trás: todos para o oeste', () {
      final fwd = straight(cells: 60, oneway: OneWay.forward);
      final rev = straight(cells: 60, oneway: OneWay.reverse);
      var seen = 0;
      for (var s = 0; s < 3000; s += 111) {
        for (final g in at(fwd, noon + s, hour: 8)) {
          expect(math.cos(g.heading), closeTo(1, 1e-9));
          seen++;
        }
        for (final g in at(rev, noon + s, hour: 8)) {
          expect(math.cos(g.heading), closeTo(-1, 1e-9));
          seen++;
        }
      }
      expect(seen, greaterThan(20));
    });

    test('mão dupla: vão nos dois sentidos, e cada um anda pela direita', () {
      final l = straight(cells: 60);
      final base = 4 + 100 / 64 / 64; // y do eixo da rua em células, dividido do tile
      final axisY = 4 * 64 + 100 / 64;
      expect(base, isNotNull);
      var east = 0, west = 0;
      for (var w = 0; w < 40; w++) {
        for (final g in at(l, noon + w * trafficWindowS + 200, hour: 8)) {
          if (math.cos(g.heading) > 0) {
            east++;
            expect(g.y, greaterThan(axisY), reason: 'indo a leste, a direita é o sul (y maior)');
          } else {
            west++;
            expect(g.y, lessThan(axisY), reason: 'indo a oeste, a direita é o norte (y menor)');
          }
        }
      }
      expect(east, greaterThan(10));
      expect(west, greaterThan(10));
    });

    test('pedestres não têm mão de direção nem mão única', () {
      final l = straight(c: RoadClass.pedestrian, cells: 60);
      var east = 0, west = 0;
      for (var w = 0; w < 60; w++) {
        for (final g in at(l, noon + w * trafficWindowS + 200, hour: 12)) {
          expect(g.kind, GhostKind.pedestrian);
          math.cos(g.heading) > 0 ? east++ : west++;
        }
      }
      expect(east, greaterThan(5));
      expect(west, greaterThan(5));
    });
  });

  group('aparecer e sumir suave', () {
    test('no começo e no fim da janela o fantasma está apagado, e no meio, inteiro', () {
      final l = straight(cells: 80, oneway: OneWay.forward, c: RoadClass.principal);
      final w0 = (noon ~/ trafficWindowS) * trafficWindowS;
      double maxAlpha(int t) => at(l, t, hour: 8).fold(0.0, (m, g) => math.max(m, g.alpha));
      expect(maxAlpha(w0 + 1), lessThan(0.2));
      expect(maxAlpha(w0 + trafficWindowS - 1), lessThan(0.2));
      expect(maxAlpha(w0 + 600), greaterThan(0.9));
    });

    test('perto das pontas da rua o fantasma some, para a volta não aparecer como um salto', () {
      final l = straight(cells: 40, oneway: OneWay.forward);
      for (var s = 0; s < 1200; s += 13) {
        for (final g in at(l, (noon ~/ trafficWindowS) * trafficWindowS + 300 + s % 600)) {
          final dEnd = math.min((g.x - l.xy.first) * mpc, (l.xy[l.xy.length - 2] - g.x) * mpc);
          if (dEnd < 3) expect(g.alpha, lessThan(0.3));
        }
      }
    });
  });
}
