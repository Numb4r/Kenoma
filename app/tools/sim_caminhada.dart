// Simulação de densidade da época 2 (docs/densidade-epoca2.md): anda 3 rotas reais de ~800 m de Campinas (uma residencial,
// uma de avenida, uma de parque) a 1,3 m/s e conta o que a Aura de 10 m coleta e o que passa ao alcance de 30 m, e fica
// parado em casa uma hora. Uso, a partir de app/:  dart run tools/sim_caminhada.dart [--epochs 1,2] [--starts 12]
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:kenoma/core/biomes.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/region_pack.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/visual_map.dart';
import 'package:kenoma/world/walk_paths.dart';

const double auraM = 10, touchM = 30, viewM = 120, walkMps = 1.3, routeM = 800;

class Route {
  Route(this.name, this.pts, this.lengthM);
  final String name;

  /// Pontos em células z21 fracionárias.
  final List<(double, double)> pts;
  final double lengthM;

  /// A posição a [d] metros do começo.
  (double, double) at(double d, double mpc) {
    var left = d / mpc;
    for (var i = 1; i < pts.length; i++) {
      final dx = pts[i].$1 - pts[i - 1].$1, dy = pts[i].$2 - pts[i - 1].$2;
      final len = math.sqrt(dx * dx + dy * dy);
      if (left <= len) {
        final t = len == 0 ? 0.0 : left / len;
        return (pts[i - 1].$1 + dx * t, pts[i - 1].$2 + dy * t);
      }
      left -= len;
    }
    return pts.last;
  }
}

/// Segue o grafo de ruas do pacote visual a partir de ([lat], [lon]) por [routeM] metros, indo sempre pelo trecho que menos
/// vira, só pelas classes [allowed].
Route buildRoute(String name, VisualMap vm, double lat, double lon, Set<RoadClass> allowed) {
  final (sx, sy) = latLonToTileFraction(lat, lon, biomeZoom);
  final mpc = metersPerCell(lat);
  final adj = <(int, int), List<(int, int)>>{};
  final pos = <(int, int), (double, double)>{};
  (int, int) key(double x, double y) => ((x * 1000).round(), (y * 1000).round());
  for (final (tx, ty) in vm.tilesIn(sx - 40, sy - 40, sx + 40, sy + 40)) {
    final tile = vm.tile(tx, ty);
    if (tile == null) continue;
    for (final line in tile.lines) {
      if (!allowed.contains(line.roadClass)) continue;
      for (var i = 0; i + 3 < line.xy.length; i += 2) {
        final (ax, ay) = vm.toCell(tx, ty, line.xy[i], line.xy[i + 1]);
        final (bx, by) = vm.toCell(tx, ty, line.xy[i + 2], line.xy[i + 3]);
        final ka = key(ax, ay), kb = key(bx, by);
        if (ka == kb) continue;
        pos[ka] = (ax, ay);
        pos[kb] = (bx, by);
        (adj[ka] ??= []).contains(kb) ? null : adj[ka]!.add(kb);
        (adj[kb] ??= []).contains(ka) ? null : adj[kb]!.add(ka);
      }
    }
  }
  if (pos.isEmpty) throw StateError('$name: nenhuma via das classes pedidas perto de $lat,$lon');
  var cur = pos.keys.reduce((a, b) {
    double d((int, int) k) => math.pow(pos[k]!.$1 - sx, 2).toDouble() + math.pow(pos[k]!.$2 - sy, 2);
    return d(a) <= d(b) ? a : b;
  });
  final pts = <(double, double)>[pos[cur]!];
  (int, int)? prev;
  var total = 0.0;
  while (total < routeM) {
    final here = pos[cur]!;
    var opts = [for (final n in adj[cur]!) if (n != prev) n];
    if (opts.isEmpty && prev != null) opts = [prev]; // beco sem saída: volta pelo mesmo caminho
    if (opts.isEmpty) break;
    // Direção de chegada: a do último trecho (no primeiro, qualquer uma serve: a de maior alcance).
    double heading = prev == null ? 0 : math.atan2(here.$2 - pos[prev]!.$2, here.$1 - pos[prev]!.$1);
    (int, int) next;
    if (prev == null) {
      next = opts.first;
    } else {
      double turn((int, int) n) {
        var a = math.atan2(pos[n]!.$2 - here.$2, pos[n]!.$1 - here.$1) - heading;
        while (a > math.pi) {
          a -= 2 * math.pi;
        }
        while (a < -math.pi) {
          a += 2 * math.pi;
        }
        return a.abs();
      }

      next = opts.reduce((a, b) => turn(a) <= turn(b) ? a : b);
    }
    final p = pos[next]!;
    total += math.sqrt(math.pow(p.$1 - here.$1, 2) + math.pow(p.$2 - here.$2, 2)) * mpc;
    pts.add(p);
    prev = cur;
    cur = next;
  }
  return Route(name, pts, total);
}

class Counts {
  double sparks = 0, materials = 0, ecosIn30 = 0, ecosIn120 = 0;
  void add(Counts o) {
    sparks += o.sparks;
    materials += o.materials;
    ecosIn30 += o.ecosIn30;
    ecosIn120 += o.ecosIn120;
  }

  Counts div(num n) => Counts()
    ..sparks = sparks / n
    ..materials = materials / n
    ..ecosIn30 = ecosIn30 / n
    ..ecosIn120 = ecosIn120 / n;
}

/// Uma caminhada de 10 minutos pela rota a partir de [t0].
Counts walk(SpawnField field, Route r, int t0, {double secondsWalk = 600}) {
  final done = <int>{}, in30 = <int>{}, in120 = <int>{};
  final c = Counts();
  for (var s = 0; s < secondsWalk; s += 1) {
    final dist = math.min(s * walkMps, r.lengthM);
    final (px, py) = r.at(dist, metersPerCell(-22.85));
    final (lat, lon) = tileFractionToLatLon(px, py, biomeZoom);
    final mpc = metersPerCell(lat);
    for (final sp in field.around(lat: lat, lon: lon, tUtc: t0 + s, radiusM: viewM, playerLevel: 1)) {
      final d = sp.distanceM(px, py, mpc);
      if (sp.isEco) {
        if (d <= touchM) in30.add(sp.uid);
        in120.add(sp.uid);
      } else if (d <= auraM && done.add(sp.uid)) {
        if (sp.isSpark) {
          c.sparks++;
        } else {
          c.materials++;
        }
      }
    }
  }
  c.ecosIn30 = in30.length.toDouble();
  c.ecosIn120 = in120.length.toDouble();
  return c;
}

/// Parado em ([lat], [lon]) por uma hora: quantos Ecos diferentes passam a até 30 m.
double idle(SpawnField field, double lat, double lon, int t0) {
  final (px, py) = latLonToTileFraction(lat, lon, biomeZoom);
  final mpc = metersPerCell(lat);
  final seen = <int>{};
  for (var s = 0; s < 3600; s += 20) {
    for (final sp in field.around(lat: lat, lon: lon, tUtc: t0 + s, radiusM: touchM, playerLevel: 1)) {
      if (sp.isEco && sp.distanceM(px, py, mpc) <= touchM) seen.add(sp.uid);
    }
  }
  return seen.length.toDouble();
}

Map<String, dynamic> _json(String p) => jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>;

void main(List<String> args) {
  String arg(String n, String d) {
    final i = args.indexOf('--$n');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : d;
  }

  final epochIds = arg('epochs', '1,2').split(',').map(int.parse).toList();
  final starts = int.parse(arg('starts', '12'));
  final biomes = BiomeSet.fromJson(_json('assets/data/biomes.json'));
  final pack = RegionPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0.bin').readAsBytesSync()));
  final vm = VisualMap(VisualPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync())), cacheTiles: 256);
  final all = EpochSchedule.fromJson(_json('assets/data/epochs.json'));

  // Pontos de partida reais (Campinas): rua residencial no Barão Geraldo, a Av. Barão de Itapura e a trilha do Parque Portugal.
  final routes = [
    buildRoute('residencial', vm, -22.8165, -47.0705, {RoadClass.local, RoadClass.secondary, RoadClass.pedestrian}),
    buildRoute('avenida', vm, -22.9035, -47.0585, {RoadClass.principal, RoadClass.secondary, RoadClass.local}),
    buildRoute('parque', vm, -22.8755, -47.0490, {RoadClass.pedestrian, RoadClass.local}),
  ];
  for (final r in routes) {
    print('rota ${r.name}: ${r.lengthM.round()} m, ${r.pts.length} vértices');
  }
  final homes = [(-22.8165, -47.0705), (-22.9035, -47.0585), (-22.8960, -47.0450)];
  const base = 1792080000;
  print('\n| época | rota | Fagulhas | materiais | Ecos a ≤30 m | Ecos a ≤120 m |\n|---|---|---|---|---|---|');
  for (final id in epochIds) {
    final epoch = all.epochs.firstWhere((e) => e.id == id);
    final field = SpawnField(
      seed: seedGlobal('KENOMA-TESTE'),
      schedule: EpochSchedule([epoch]),
      map: RegionMap(pack: pack, biomes: biomes),
      snapper: epoch.walkable == null ? null : WalkPaths(vm),
    );
    final mean = Counts();
    for (final r in routes) {
      final sum = Counts();
      for (var i = 0; i < starts; i++) {
        sum.add(walk(field, r, base + i * 4321 + 17));
      }
      final m = sum.div(starts);
      mean.add(m);
      print('| $id | ${r.name} | ${m.sparks.toStringAsFixed(1)} | ${m.materials.toStringAsFixed(1)} | ${m.ecosIn30.toStringAsFixed(1)} | ${m.ecosIn120.toStringAsFixed(1)} |');
    }
    final m = mean.div(routes.length);
    print('| $id | **média** | **${m.sparks.toStringAsFixed(1)}** | **${m.materials.toStringAsFixed(1)}** | **${m.ecosIn30.toStringAsFixed(1)}** | **${m.ecosIn120.toStringAsFixed(1)}** |');
    var idleSum = 0.0, n = 0;
    for (final h in homes) {
      for (var i = 0; i < starts; i++) {
        idleSum += idle(field, h.$1, h.$2, base + i * 7919 + 3);
        n++;
      }
    }
    print('|  | parado 1 h em casa | | | ${(idleSum / n).toStringAsFixed(2)} | |');
  }
}
