/// Os caminhos andáveis de cada célula de spawn (ruas, calçadas, ciclovias e trilhas do pacote visual), recortados na
/// célula, e a projeção de um ponto sobre eles. Dart puro. Só usa soma, subtração, multiplicação, divisão e comparação sobre
/// coordenadas inteiras do pacote, para dar o mesmo ponto em qualquer aparelho.
library;

import 'dart:collection';
import 'dart:math' as math;

import '../core/tiles.dart';
import '../core/walkable.dart';
import '../data/nowalk_pack.dart';
import 'visual_map.dart';

class WalkPaths implements PathSnapper {
  WalkPaths(this.map, {this.blocked, this.cacheCells = 512});

  final VisualMap map;

  /// Rodovias e vias expressas: os trechos do pacote visual sobre elas não contam como caminho.
  final NoWalkPack? blocked;

  /// Metros de uma célula z20 na latitude: se a célula tem via no mapa, mas nenhuma andável.
  final _meta = <(int, int), _Meta>{};
  final int cacheCells;

  /// Segmentos recortados por célula, em fração da célula: `x0, y0, x1, y1, ...`. Vazio: nada andável ali.
  final LinkedHashMap<(int, int), List<double>> _cells = LinkedHashMap();

  /// Os segmentos andáveis da célula z20 `(cx, cy)`, recortados no quadrado dela.
  List<double> segments(int cx, int cy) {
    final key = (cx, cy);
    final hit = _cells.remove(key);
    if (hit != null) return _cells[key] = hit;
    final out = _build(cx, cy);
    _cells[key] = out;
    while (_cells.length > cacheCells) {
      _meta.remove(_cells.keys.first);
      _cells.remove(_cells.keys.first);
    }
    return out;
  }

  List<double> _build(int cx, int cy) {
    final pack = map.pack;
    final shift = spawnZoom - pack.tileZoom; // células z20 por lado de um tile z15: 2^5
    final per = 1 << shift;
    final tile = map.tile(cx >>> shift, cy >>> shift);
    if (tile == null) {
      _meta[(cx, cy)] = const _Meta(hadWays: false, lengthFrac: 0);
      return const [];
    }
    final (lat, _) = tileFractionToLatLon(cx + 0.5, cy + 0.5, spawnZoom);
    final blockedNear = blocked?.near(cx, cy) ?? const <double>[];
    final tolFrac = 3 / metersPerCell(lat, zoom: spawnZoom); // 3 m, em frações de célula z20
    var hadWays = false;
    final cell = pack.extent / per; // unidades do tile por célula
    final x0 = (cx & (per - 1)) * cell, y0 = (cy & (per - 1)) * cell;
    final x1 = x0 + cell, y1 = y0 + cell;
    final out = <double>[];
    for (final line in tile.lines) {
      final p = line.xy;
      for (var i = 0; i + 3 < p.length; i += 2) {
        final ax = p[i].toDouble(), ay = p[i + 1].toDouble(), bx = p[i + 2].toDouble(), by = p[i + 3].toDouble();
        if ((ax < x0 && bx < x0) || (ax > x1 && bx > x1) || (ay < y0 && by < y0) || (ay > y1 && by > y1)) continue;
        final c = _clip(ax, ay, bx, by, x0, y0, x1, y1);
        if (c == null) continue;
        hadWays = true;
        final seg = [(c[0] - x0) / cell, (c[1] - y0) / cell, (c[2] - x0) / cell, (c[3] - y0) / cell];
        if (blockedNear.isNotEmpty && _onBlocked(seg, cx, cy, blockedNear, tolFrac)) continue;
        out.addAll(seg);
      }
    }
    var len = 0.0;
    for (var i = 0; i < out.length; i += 4) {
      len += math.sqrt(math.pow(out[i + 2] - out[i], 2) + math.pow(out[i + 3] - out[i + 1], 2));
    }
    _meta[(cx, cy)] = _Meta(hadWays: hadWays, lengthFrac: len);
    return out;
  }

  /// O meio do trecho [seg] (frações da célula z20) está a menos de [tolFrac] de uma via bloqueada.
  static bool _onBlocked(List<double> seg, int cx, int cy, List<double> blocked, double tolFrac) {
    // Frações da célula z20 → células z21 globais: a célula z20 tem 2 células z21 de lado.
    final mx = (cx + (seg[0] + seg[2]) / 2) * 2, my = (cy + (seg[1] + seg[3]) / 2) * 2;
    final tol = tolFrac * 2;
    for (var i = 0; i < blocked.length; i += 4) {
      final ax = blocked[i], ay = blocked[i + 1], dx = blocked[i + 2] - ax, dy = blocked[i + 3] - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : ((mx - ax) * dx + (my - ay) * dy) / len2;
      t = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
      final ex = mx - (ax + t * dx), ey = my - (ay + t * dy);
      if (ex * ex + ey * ey <= tol * tol) return true;
    }
    return false;
  }

  /// Liang-Barsky: o trecho de A→B dentro do retângulo, ou `null` se fica todo fora.
  static List<double>? _clip(double ax, double ay, double bx, double by, double x0, double y0, double x1, double y1) {
    final dx = bx - ax, dy = by - ay;
    var t0 = 0.0, t1 = 1.0;
    for (final (p, q) in [(-dx, ax - x0), (dx, x1 - ax), (-dy, ay - y0), (dy, y1 - ay)]) {
      if (p == 0) {
        if (q < 0) return null;
        continue;
      }
      final r = q / p;
      if (p < 0) {
        if (r > t1) return null;
        if (r > t0) t0 = r;
      } else {
        if (r < t0) return null;
        if (r < t1) t1 = r;
      }
    }
    return [ax + t0 * dx, ay + t0 * dy, ax + t1 * dx, ay + t1 * dy];
  }

  @override
  double? walkLengthM(int cellX, int cellY) {
    segments(cellX, cellY);
    final m = _meta[(cellX, cellY)]!;
    if (!m.hadWays) return null;
    final (lat, _) = tileFractionToLatLon(cellX + 0.5, cellY + 0.5, spawnZoom);
    return m.lengthFrac * metersPerCell(lat, zoom: spawnZoom);
  }

  @override
  Snap? snap(int cellX, int cellY, double px, double py, {double maxOffM = 0, double maxDistM = 35}) {
    final s = segments(cellX, cellY);
    final meta = _meta[(cellX, cellY)]!;
    if (!meta.hadWays) return null;
    if (s.isEmpty) return Snap(px, py, keep: false); // só rodovia por perto
    var best = double.infinity, bx = px, by = py;
    for (var i = 0; i < s.length; i += 4) {
      final ax = s[i], ay = s[i + 1], cx = s[i + 2], cy = s[i + 3];
      final dx = cx - ax, dy = cy - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
      t = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
      final qx = ax + t * dx, qy = ay + t * dy;
      final d2 = (px - qx) * (px - qx) + (py - qy) * (py - qy);
      if (d2 < best) {
        best = d2;
        bx = qx;
        by = qy;
      }
    }
    // Metros por fração de célula z20 na latitude da célula; só compara com tolerâncias (dá o mesmo ponto em qualquer aparelho
    // a menos de um empate de 1e-14 m).
    final (lat, _) = tileFractionToLatLon(cellX + 0.5, cellY + 0.5, spawnZoom);
    final mPerFrac = metersPerCell(lat, zoom: spawnZoom);
    final dM = math.sqrt(best) * mPerFrac;
    if (dM > maxDistM) return Snap(px, py, keep: false);
    if (maxOffM <= 0) return Snap(_in(bx), _in(by));
    if (dM <= maxOffM) return Snap(px, py);
    final k = maxOffM / dM; // fica a maxOffM do caminho, na mesma direção
    return Snap(_in(bx + (px - bx) * k), _in(by + (py - by) * k));
  }

  /// Dentro da célula: `[0, 1)`, sem o erro de arredondamento nas bordas.
  static double _in(double v) => v < 0 ? 0.0 : (v > 0.999999 ? 0.999999 : v);
}

class _Meta {
  const _Meta({required this.hadWays, required this.lengthFrac});

  /// A célula tem via no pacote visual (andável ou não).
  final bool hadWays;

  /// Comprimento andável em frações de célula z20.
  final double lengthFrac;
}
