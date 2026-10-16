import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/veil_traffic.dart';
import 'package:kenoma/world/visual_map.dart';

const seed = 0x6ebe19ac6345175f;
const rush = 1790035200 + 21 * 3600; // 2026-09-22 21:00 UTC = 18:00 em Campinas
const widths = {'principal': 12.0, 'secondary': 9.0, 'local': 6.0, 'pedestrian': 2.0};
const tx0 = 12100, ty0 = 18500;

/// Uma grade de ruas num tile z15: nós a cada 512 unidades (8 células, ~140 m), ruas partidas nos nós como no OSM.
VisualTile gridTile() {
  final lines = <VisualLine>[];
  for (var k = 1; k <= 7; k++) {
    final h = k == 7 ? RoadClass.pedestrian : (k == 3 ? RoadClass.principal : (k == 5 ? RoadClass.secondary : RoadClass.local));
    final v = k == 4 ? RoadClass.secondary : RoadClass.local;
    for (var j = 1; j < 7; j++) {
      lines.add(VisualLine(h, Int32List.fromList([j * 512, k * 512, (j + 1) * 512, k * 512])));
      lines.add(VisualLine(v, Int32List.fromList([k * 512, j * 512, k * 512, (j + 1) * 512]), oneway: k == 2 ? OneWay.forward : (k == 6 ? OneWay.reverse : OneWay.twoWay)));
    }
  }
  return VisualTile(lines: lines, areas: const []);
}

TrafficGraph gridGraph() {
  final t = gridTile();
  return TrafficGraph(loadTile: (x, y) => x == tx0 && y == ty0 ? t : null, cellsPerTile: 64, extent: 4096);
}

TrafficField gridField({int s = seed}) => TrafficField(graph: gridGraph(), seed: s, roadWidthM: widths);

double get gridMpc => metersPerCell(tileFractionToLatLon(tx0 * 64 + 32, ty0 * 64 + 32, 21).$1);

/// O centro do nó (4, 4) da grade, em células.
(double, double) get gridCenter => (tx0 * 64 + 32.0, ty0 * 64 + 32.0);

/// Um retângulo de câmera de [widthM] metros de largura (celular 360×780), com a margem de 20 m.
(double, double, double, double) viewRect(double cx, double cy, double mpc, {double widthM = 50, double rot = 0, double margin = 20}) {
  final cam = MapCamera(centerX: cx, centerY: cy, pixelsPerCell: 360 * mpc / widthM, rotation: rot);
  final (l, t, r, b) = cam.visibleBounds(360, 780);
  final m = margin / mpc;
  return (l - m, t - m, r + m, b + m);
}

String sig(List<Ghost> g) => [for (final x in g) '${x.id}:${x.model.name}:${x.palette}:${x.x.toStringAsFixed(6)}:${x.y.toStringAsFixed(6)}:${x.heading.toStringAsFixed(6)}:${x.phase.name}'].join('|');

void main() {
  final realBytes = File('assets/regions/campinas_e0_vis.bin').readAsBytesSync();
  TrafficField realField({int s = seed}) {
    final visual = VisualMap(VisualPack.parse(Uint8List.fromList(realBytes)), cacheTiles: 16);
    return TrafficField(graph: TrafficGraph(loadTile: visual.tile, cellsPerTile: visual.cellsPerTile, extent: visual.pack.extent), seed: s, roadWidthM: widths);
  }

  const realCenter = (12092 * 64.0 + 32, 18513 * 64.0 + 32);

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
      for (var h = 0.0; h < 24; h += 0.25) {
        expect(carDensity(h), inInclusiveRange(0.05, 1.0));
        expect(pedestrianDensity(h), inInclusiveRange(0.03, 1.0));
      }
      expect((carDensity(23.99) - carDensity(0.0)).abs(), lessThan(0.02));
    });

    test('mais fantasmas no rush que de madrugada, na mesma grade', () {
      int total(int t0) {
        final f = gridField();
        var n = 0;
        for (var k = 0; k < 20; k++) {
          n += f.ghostsIn(t0 + k * 61.0, tx0 * 64.0, ty0 * 64.0, tx0 * 64.0 + 64, ty0 * 64.0 + 64, maxGhosts: 100000).length;
        }
        return n;
      }

      final night = total(1790035200 + 6 * 3600); // 03:00 em Campinas
      final peak = total(rush);
      expect(peak, greaterThan(night * 4));
      expect(night, greaterThan(0), reason: 'madrugada vazia, mas não morta');
    });
  });

  group('determinismo', () {
    test('dois aparelhos com a mesma seed veem os mesmos fantasmas nas mesmas posições; outra seed muda', () {
      for (final mk in [gridField, realField]) {
        final (cx, cy) = mk == gridField ? gridCenter : realCenter;
        final a = mk(), b = mk(), c = mk(s: seed + 1);
        final (l, t, r, bt) = viewRect(cx, cy, gridMpc, widthM: 80);
        var seen = 0;
        for (var k = 0; k < 40; k++) {
          final tt = rush + 37.25 * k;
          final ga = a.ghostsIn(tt, l, t, r, bt);
          // b é consultado em outra ordem de tempo e com outra janela antes: o cache não pode mudar o resultado
          if (k == 0) b.ghostsIn(tt + 500, l - 50, t - 50, r + 50, bt + 50);
          expect(sig(b.ghostsIn(tt, l, t, r, bt)), sig(ga), reason: 'quadro $k');
          seen += ga.length;
          if (ga.isNotEmpty) expect(sig(c.ghostsIn(tt, l, t, r, bt)), isNot(sig(ga)));
        }
        expect(seen, greaterThan(10));
      }
    });

    test('há todos os modelos de carro e de passante, com paletas variadas', () {
      final f = gridField();
      final models = <GhostModel>{};
      final palettes = <GhostModel, Set<int>>{};
      final (cx, cy) = gridCenter;
      final (l, t, r, b) = viewRect(cx, cy, gridMpc, widthM: 400);
      for (var k = 0; k < 400; k++) {
        for (final g in f.ghostsIn(rush + 7.0 * k, l, t, r, b, maxGhosts: 100000)) {
          models.add(g.model);
          (palettes[g.model] ??= {}).add(g.palette);
          expect(g.palette, lessThan(g.model.paletteCount));
        }
      }
      expect(models, containsAll(GhostModel.values));
      for (final m in GhostModel.values) {
        expect(m.paletteCount, inInclusiveRange(4, 6));
        expect(palettes[m]!.length, greaterThanOrEqualTo(3), reason: '${m.name} usa várias paletas');
      }
    });
  });

  group('pista e calçada', () {
    test('pedestre nunca a menos de meia largura + 1 m do eixo da via (fora dos cruzamentos), carro sempre na pista pela direita', () {
      final graph = gridGraph();
      final f = TrafficField(graph: graph, seed: seed, roadWidthM: widths);
      final mpc = gridMpc;
      final lines = graph.linesOfTile(tx0, ty0);
      final (cx, cy) = gridCenter;
      final (l, t, r, b) = viewRect(cx, cy, mpc, widthM: 500);
      double half(GhostLine ln) => widths[ln.roadClass.name]! / 2;
      var cars = 0, walkers = 0, nearAxisWalkers = 0;
      for (var k = 0; k < 300; k++) {
        for (final g in f.ghostsIn(rush + 5.3 * k, l, t, r, b, maxGhosts: 100000)) {
          // a rua e o ponto mais perto, em metros
          GhostLine? nearest;
          var best = double.infinity, lat = 0.0;
          var minToNode = double.infinity;
          for (final ln in lines) {
            for (var i = 0; i < ln.vertexCount; i++) {
              minToNode = math.min(minToNode, math.sqrt(math.pow(ln.xy[2 * i] - g.x, 2) + math.pow(ln.xy[2 * i + 1] - g.y, 2)) * mpc);
            }
            if (ln.isPedestrian) continue;
            final ax = ln.xy[0], ay = ln.xy[1];
            final dx = ln.xy[2] - ax, dy = ln.xy[3] - ay, len2 = dx * dx + dy * dy;
            final u = (((g.x - ax) * dx + (g.y - ay) * dy) / len2).clamp(0.0, 1.0);
            final px = ax + dx * u, py = ay + dy * u;
            final d = math.sqrt(math.pow(g.x - px, 2) + math.pow(g.y - py, 2)) * mpc;
            if (d - half(ln) < best) {
              best = d - half(ln); // folga até a borda da via (negativo = dentro)
              nearest = ln;
              final nx = -math.sin(g.heading), ny = math.cos(g.heading); // direita de quem anda
              lat = ((g.x - px) * nx + (g.y - py) * ny) * mpc;
            }
          }
          if (g.model.kind == GhostKind.car) {
            cars++;
            expect(best, lessThanOrEqualTo(0.05), reason: 'carro fora da pista: ${g.model.name}');
            if (minToNode > 40 && nearest!.oneway == OneWay.twoWay) expect(lat, greaterThan(0.5), reason: 'mão dupla: pela direita');
            if (minToNode > 40 && nearest!.oneway != OneWay.twoWay) expect(lat.abs(), lessThan(0.3), reason: 'mão única: no eixo da pista');
          } else if (g.model != GhostModel.cyclist) {
            walkers++;
            if (best < 1 - 0.05) {
              nearAxisWalkers++;
              // só se vale no meio de um cruzamento: perto de um nó (a travessia da via)
              expect(minToNode, lessThan(widths['principal']! / 2 + 1.5 + 3), reason: 'pedestre no meio da pista: ${best.toStringAsFixed(2)} m da borda');
            }
          }
        }
      }
      expect(cars, greaterThan(50));
      expect(walkers, greaterThan(50));
      expect(nearAxisWalkers, lessThan(walkers * 0.2), reason: 'travessia é exceção');
    });

    test('ciclista só anda em caminho de pedestre', () {
      final graph = gridGraph();
      final f = TrafficField(graph: graph, seed: seed, roadWidthM: widths);
      final mpc = gridMpc;
      final peds = [for (final ln in graph.linesOfTile(tx0, ty0)) if (ln.isPedestrian) ln];
      final (cx, cy) = gridCenter;
      final (l, t, r, b) = viewRect(cx, cy, mpc, widthM: 500);
      var bikes = 0;
      for (var k = 0; k < 500; k++) {
        for (final g in f.ghostsIn(rush + 6.1 * k, l, t, r, b, maxGhosts: 100000)) {
          if (g.model != GhostModel.cyclist) continue;
          bikes++;
          final d = peds.map((ln) => (g.y - ln.xy[1]).abs() * mpc).reduce(math.min);
          expect(d, lessThan(1.0), reason: 'ciclista fora do caminho');
        }
      }
      expect(bikes, greaterThan(3));
    });
  });

  group('continuidade', () {
    /// Varre [seconds] s a 20 quadros/s com a câmera [camAt] e confere o contrato de nascer e morrer só com a costura.
    void sweep(TrafficField f, (double, double) Function(double sec) camAt, {double widthM = 50, double Function(double)? rotAt, double Function(double)? widthAt, double seconds = 30, double mpc = 17.6}) {
      const dt = 0.05;
      var prev = <int, Ghost>{};
      var inView = 0, moved = 0;
      for (var k = 0; k <= seconds / dt; k++) {
        final sec = k * dt, tt = rush + 3.0 + sec;
        final (cx, cy) = camAt(sec);
        final (l, t, r, b) = viewRect(cx, cy, mpc, widthM: widthAt?.call(sec) ?? widthM, rot: rotAt?.call(sec) ?? 0);
        // o "universo": tudo o que existe até 3 células (~50 m) além da vista, sem teto. Quem é novo no universo nasce
        // na borda dele, longe da vista, então só os nascimentos dentro da vista valem como pop.
        final all = {for (final g in f.ghostsIn(tt, l - 3, t - 3, r + 3, b + 3, maxGhosts: 1000000)) g.id: g};
        final view = f.ghostsIn(tt, l, t, r, b, maxGhosts: 1000000);
        inView += view.length;
        bool inside(Ghost g) => g.x >= l && g.x <= r && g.y >= t && g.y <= b;
        for (final g in view) {
          expect(all.containsKey(g.id), isTrue);
          expect(all[g.id]!.x, g.x);
        }
        if (k > 0) {
          for (final g in all.values) {
            final p = prev[g.id];
            if (p == null) {
              if (inside(g)) {
                expect(g.phase, GhostPhase.fadeIn, reason: 'criado à vista sem costura: ${g.model.name} t=$sec');
              }
              continue;
            }
            final d = math.sqrt(math.pow(g.x - p.x, 2) + math.pow(g.y - p.y, 2)) * mpc;
            expect(d, lessThanOrEqualTo(maxGhostSpeedMps * dt + 1e-6), reason: 'salto de ${d.toStringAsFixed(2)} m em ${dt}s (${g.model.name})');
            moved++;
          }
          for (final p in prev.values) {
            if (!all.containsKey(p.id) && p.x >= l && p.x <= r && p.y >= t && p.y <= b) {
              expect(p.phase, GhostPhase.fadeOut, reason: 'removido à vista sem costura: ${p.model.name}');
            }
          }
        }
        prev = all;
      }
      expect(inView, greaterThan(0), reason: 'a câmera viu fantasmas');
      expect(moved, greaterThan(100));
    }

    test('grade sintética: tela parada, 30 s a 20 quadros/s', () {
      sweep(gridField(), (_) => gridCenter, mpc: gridMpc);
    });

    test('grade sintética: andando a 1,4 m/s com giro e zoom de 40 a 80 m', () {
      final mpc = gridMpc;
      sweep(gridField(), (s) => (gridCenter.$1 + 1.4 * s / mpc, gridCenter.$2), mpc: mpc, rotAt: (s) => s * 0.08, widthAt: (s) => 40 + 40 * (0.5 + 0.5 * math.sin(s * 0.3)));
    });

    test('Campinas real: parado e andando', () {
      final mpc = metersPerCell(tileFractionToLatLon(realCenter.$1, realCenter.$2, 21).$1);
      sweep(realField(), (_) => realCenter, mpc: mpc, seconds: 20);
      sweep(realField(), (s) => (realCenter.$1 + 1.4 * s / mpc, realCenter.$2 + 0.7 * s / mpc), mpc: mpc, seconds: 20, rotAt: (s) => s * 0.05);
    });

    test('a fase é fadeIn só nos primeiros 300 ms e fadeOut só nos últimos', () {
      final f = gridField();
      final (cx, cy) = gridCenter;
      final (l, t, r, b) = viewRect(cx, cy, gridMpc, widthM: 500);
      var ins = 0, outs = 0;
      for (var k = 0; k < 3000; k++) {
        for (final g in f.ghostsIn(rush + 0.1 * k, l, t, r, b, maxGhosts: 100000)) {
          expect(g.phaseT, inInclusiveRange(0, 1));
          if (g.phase == GhostPhase.fadeIn) ins++;
          if (g.phase == GhostPhase.fadeOut) outs++;
          expect(g.alpha, inInclusiveRange(0, 1));
        }
      }
      expect(ins, greaterThan(0));
      expect(outs, greaterThan(0));
    });

    test('o teto de fantasmas fica com os de menor id e respeita o limite', () {
      final f = gridField();
      final (cx, cy) = gridCenter;
      final (l, t, r, b) = viewRect(cx, cy, gridMpc, widthM: 500);
      final all = f.ghostsIn(rush + 400, l, t, r, b, maxGhosts: 100000);
      final top = f.ghostsIn(rush + 400, l, t, r, b, maxGhosts: 10);
      expect(all.length, greaterThan(10));
      expect(top.length, 10);
      final ids = all.map((g) => g.id).toList()..sort();
      expect(top.map((g) => g.id).toSet(), ids.take(10).toSet());
    });
  });

  group('curvas', () {
    test('o caminho é suave: nenhuma quina sem arredondar e a velocidade cai nas curvas fechadas', () {
      final f = gridField();
      final (cx, cy) = gridCenter;
      final (l, t, r, b) = viewRect(cx, cy, gridMpc, widthM: 500);
      final last = <int, Ghost>{};
      var worstTurn = 0.0;
      var slow = 0, fast = 0;
      const dt = 0.1;
      for (var k = 0; k < 3000; k++) {
        final now = <int, Ghost>{};
        for (final g in f.ghostsIn(rush + dt * k, l, t, r, b, maxGhosts: 100000)) {
          now[g.id] = g;
          if (g.model.kind != GhostKind.car) continue;
          final p = last[g.id];
          if (p != null && g.travelledM - p.travelledM < 3) {
            var d = (g.heading - p.heading).abs() % (2 * math.pi);
            if (d > math.pi) d = 2 * math.pi - d;
            worstTurn = math.max(worstTurn, d);
          }
          g.speedMps < 5 ? slow++ : fast++;
        }
        last
          ..clear()
          ..addAll(now);
      }
      // a quina de 90° é arredondada em passos de ~18° por vértice; nunca a virada seca de 90° de uma vez
      expect(worstTurn, lessThan(0.7));
      expect(slow, greaterThan(0));
      expect(fast, greaterThan(slow));
    });
  });
}
