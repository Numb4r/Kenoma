/// Os caminhos andáveis de cada célula de spawn (ruas, calçadas, ciclovias e trilhas do pacote visual), recortados na
/// célula, e a projeção de um ponto sobre eles. Dart puro. Só usa soma, subtração, multiplicação, divisão e comparação sobre
/// coordenadas inteiras do pacote, para dar o mesmo ponto em qualquer aparelho.
library;

import 'dart:collection';
import 'dart:math' as math;

import '../core/tiles.dart';
import '../core/walkable.dart';
import 'visual_map.dart';

class WalkPaths implements PathSnapper {
  WalkPaths(this.map, {this.cacheCells = 512});

  final VisualMap map;
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
      _cells.remove(_cells.keys.first);
    }
    return out;
  }

  List<double> _build(int cx, int cy) {
    final pack = map.pack;
    final shift = spawnZoom - pack.tileZoom; // células z20 por lado de um tile z15: 2^5
    final per = 1 << shift;
    final tile = map.tile(cx >>> shift, cy >>> shift);
    if (tile == null) return const [];
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
        out
          ..add((c[0] - x0) / cell)
          ..add((c[1] - y0) / cell)
          ..add((c[2] - x0) / cell)
          ..add((c[3] - y0) / cell);
      }
    }
    return out;
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
  (double, double)? snap(int cellX, int cellY, double px, double py, {double maxOffM = 0}) {
    final s = segments(cellX, cellY);
    if (s.isEmpty) return null;
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
    if (maxOffM <= 0) return (_in(bx), _in(by));
    // Metros por fração de célula z20 na latitude da célula; só compara com a tolerância (dá o mesmo ponto em qualquer aparelho
    // a menos de um empate de 1e-14 m).
    final (lat, _) = tileFractionToLatLon(cellX + 0.5, cellY + 0.5, spawnZoom);
    final mPerFrac = metersPerCell(lat, zoom: spawnZoom);
    final dM = math.sqrt(best) * mPerFrac;
    if (dM <= maxOffM) return (px, py);
    final k = maxOffM / dM; // fica a maxOffM do caminho, na mesma direção
    return (_in(bx + (px - bx) * k), _in(by + (py - by) * k));
  }

  /// Dentro da célula: `[0, 1)`, sem o erro de arredondamento nas bordas.
  static double _in(double v) => v < 0 ? 0.0 : (v > 0.999999 ? 0.999999 : v);
}
