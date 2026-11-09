/// O grafo de ruas do Tráfego do Véu: as polilinhas do pacote visual em células z21, com a ligação entre ruas que se
/// encostam (inclusive de um tile para o vizinho). Dart puro. Só desenho: nada aqui decide spawn nem coleta.
library;

import 'dart:collection';
import 'dart:math' as math;

import '../data/visual_pack.dart';

/// Uma polilinha do pacote visual pronta para o tráfego: pontos em células z21 e o comprimento acumulado.
class GhostLine {
  GhostLine({required this.key, required this.roadClass, required this.oneway, required this.xy, required this.cum})
      : lengthCells = cum.last {
    var x0 = double.infinity, y0 = double.infinity, x1 = -double.infinity, y1 = -double.infinity;
    for (var i = 0; i < xy.length; i += 2) {
      x0 = math.min(x0, xy[i]);
      x1 = math.max(x1, xy[i]);
      y0 = math.min(y0, xy[i + 1]);
      y1 = math.max(y1, xy[i + 1]);
    }
    minX = x0;
    minY = y0;
    maxX = x1;
    maxY = y1;
  }

  /// Retângulo que contém a rua, em células.
  late final double minX, minY, maxX, maxY;

  /// Identifica a rua: tile e índice da linha dentro dele.
  final (int, int, int) key;
  final RoadClass roadClass;
  final OneWay oneway;

  /// Pontos `x0, y0, x1, y1, ...` em células z21 fracionárias.
  final List<double> xy;

  /// Comprimento acumulado até cada ponto, em células.
  final List<double> cum;
  final double lengthCells;

  int get vertexCount => xy.length ~/ 2;
  bool get isPedestrian => roadClass == RoadClass.pedestrian;
}

/// As linhas de tráfego de um tile: cada polilinha com duas ou mais pontas distintas.
List<GhostLine> ghostLinesOfTile(VisualTile tile, int tx, int ty, {required int cellsPerTile, required int extent}) {
  final unit = cellsPerTile / extent;
  final out = <GhostLine>[];
  for (var i = 0; i < tile.lines.length; i++) {
    final l = tile.lines[i];
    final n = l.xy.length ~/ 2;
    if (n < 2) continue;
    final xy = <double>[], cum = <double>[0.0];
    for (var k = 0; k < n; k++) {
      xy
        ..add(tx * cellsPerTile + l.xy[2 * k] * unit)
        ..add(ty * cellsPerTile + l.xy[2 * k + 1] * unit);
      if (k > 0) {
        final dx = xy[2 * k] - xy[2 * k - 2], dy = xy[2 * k + 1] - xy[2 * k - 1];
        cum.add(cum.last + math.sqrt(dx * dx + dy * dy));
      }
    }
    if (cum.last <= 0) continue;
    out.add(GhostLine(key: (tx, ty, i), roadClass: l.roadClass, oneway: l.oneway, xy: xy, cum: cum));
  }
  return out;
}

/// Um vértice de uma rua: onde outra rua pode se ligar.
typedef LineVertex = (GhostLine, int);

/// Distância em células abaixo da qual dois vértices são o mesmo cruzamento (o pacote arredonda em 1/64 de célula).
const double _joinCells = 0.35;

class _TileData {
  _TileData(this.lines, this.vertices);

  final List<GhostLine> lines;

  /// Vértices por balde de 1 célula.
  final Map<int, List<LineVertex>> vertices;
}

/// Até esta distância (células) de um trecho, o vértice de outra rua é uma esquina: a simplificação de 1 m do pacote mais
/// o arredondamento de 1/64 de célula.
const double _stitchCells = 0.12;

/// Cortes mais perto que isto (células) no mesmo trecho são um só.
const double _cutMergeCells = 0.05;

int _bucket(int bx, int by) => bx * 4194304 + by;

/// As linhas [own] de um tile cortadas onde outra rua (delas ou de [near], as dos vizinhos) encosta ou cruza sem vértice
/// comum. O pacote visual simplifica cada via sozinha (a esquina no meio de uma rua reta some) e corta as linhas nos tiles
/// z15 com sobra, então a ponta de um pedaço cai no meio do trecho do vizinho. Sem o corte, o grafo só liga vértice com
/// vértice e a rota não acha caminho. [noCrossingAt] veta o corte de dois trechos que se cruzam (viaduto). A ordem e o
/// sentido dos pontos não mudam.
List<GhostLine> stitchLines(List<GhostLine> own, List<GhostLine> near, {bool Function(double x, double y)? noCrossingAt}) {
  final all = [...own, ...near];
  // Cada trecho entra nos baldes de 1 célula por onde passa, amostrado a cada meia célula.
  final index = <int, List<(int, int)>>{};
  final segBuckets = <(int, int), Set<int>>{};
  for (var li = 0; li < all.length; li++) {
    final l = all[li];
    for (var s = 0; s + 1 < l.vertexCount; s++) {
      final ax = l.xy[2 * s], ay = l.xy[2 * s + 1], bx = l.xy[2 * s + 2], by = l.xy[2 * s + 3];
      final n = (math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay)) / 0.5).ceil();
      final seen = <int>{};
      for (var k = 0; k <= n; k++) {
        final t = n == 0 ? 0.0 : k / n;
        seen.add(_bucket((ax + (bx - ax) * t).floor(), (ay + (by - ay) * t).floor()));
      }
      for (final b in seen) {
        (index[b] ??= []).add((li, s));
      }
      if (li < own.length) segBuckets[(li, s)] = seen;
    }
  }
  final cuts = [for (var i = 0; i < own.length; i++) <(int, double)>[]];
  const tol2 = _stitchCells * _stitchCells, join2 = _joinCells * _joinCells;
  double d2(double x0, double y0, double x1, double y1) => (x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0);
  void cut(int li, int s, double t) {
    final l = own[li];
    final ax = l.xy[2 * s], ay = l.xy[2 * s + 1], bx = l.xy[2 * s + 2], by = l.xy[2 * s + 3];
    final x = ax + (bx - ax) * t, y = ay + (by - ay) * t;
    if (d2(x, y, ax, ay) <= join2 || d2(x, y, bx, by) <= join2) return; // o vértice que já existe faz a esquina
    cuts[li].add((s, t));
  }

  // A ponta (ou o vértice) de outra rua em cima de um trecho: esquina em T.
  for (var oi = 0; oi < all.length; oi++) {
    final o = all[oi];
    for (var v = 0; v < o.vertexCount; v++) {
      final px = o.xy[2 * v], py = o.xy[2 * v + 1];
      final cx = px.floor(), cy = py.floor();
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (final (li, s) in index[_bucket(cx + dx, cy + dy)] ?? const <(int, int)>[]) {
            if (li >= own.length || li == oi) continue;
            final l = own[li];
            final ax = l.xy[2 * s], ay = l.xy[2 * s + 1], ex = l.xy[2 * s + 2] - ax, ey = l.xy[2 * s + 3] - ay;
            final len = ex * ex + ey * ey;
            if (len <= 0) continue;
            final t = ((px - ax) * ex + (py - ay) * ey) / len;
            if (t <= 0 || t >= 1 || d2(ax + ex * t, ay + ey * t, px, py) > tol2) continue;
            cut(li, s, t);
          }
        }
      }
    }
  }
  // Dois trechos que se cruzam no meio: esquina em X, fora dos viadutos.
  for (final MapEntry(key: (li, s), value: buckets) in segBuckets.entries) {
    final l = own[li];
    final ax = l.xy[2 * s], ay = l.xy[2 * s + 1], ex = l.xy[2 * s + 2] - ax, ey = l.xy[2 * s + 3] - ay;
    final tried = <(int, int)>{};
    for (final b in buckets) {
      for (final (oj, u) in index[b] ?? const <(int, int)>[]) {
        if (oj == li || !tried.add((oj, u))) continue;
        final o = all[oj];
        final cx = o.xy[2 * u], cy = o.xy[2 * u + 1], fx = o.xy[2 * u + 2] - cx, fy = o.xy[2 * u + 3] - cy;
        final den = ex * fy - ey * fx;
        if (den.abs() < 1e-12) continue; // paralelos: a sobra de dois tiles, ou ruas lado a lado
        final t = ((cx - ax) * fy - (cy - ay) * fx) / den, w = ((cx - ax) * ey - (cy - ay) * ex) / den;
        if (t <= 0 || t >= 1 || w <= 0 || w >= 1) continue;
        if (noCrossingAt != null && noCrossingAt(ax + ex * t, ay + ey * t)) continue;
        cut(li, s, t);
      }
    }
  }
  return [
    for (var li = 0; li < own.length; li++) cuts[li].isEmpty ? own[li] : _withCuts(own[li], cuts[li]),
  ];
}

GhostLine _withCuts(GhostLine l, List<(int, double)> cuts) {
  cuts.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  final xy = <double>[l.xy[0], l.xy[1]];
  var c = 0;
  for (var s = 0; s + 1 < l.vertexCount; s++) {
    final ax = l.xy[2 * s], ay = l.xy[2 * s + 1], bx = l.xy[2 * s + 2], by = l.xy[2 * s + 3];
    for (; c < cuts.length && cuts[c].$1 == s; c++) {
      final x = ax + (bx - ax) * cuts[c].$2, y = ay + (by - ay) * cuts[c].$2;
      final px = xy[xy.length - 2], py = xy[xy.length - 1];
      if ((x - px) * (x - px) + (y - py) * (y - py) <= _cutMergeCells * _cutMergeCells) continue;
      xy
        ..add(x)
        ..add(y);
    }
    xy
      ..add(bx)
      ..add(by);
  }
  final cum = <double>[0.0];
  for (var i = 2; i < xy.length; i += 2) {
    cum.add(cum.last + math.sqrt(math.pow(xy[i] - xy[i - 2], 2) + math.pow(xy[i + 1] - xy[i - 1], 2)));
  }
  return GhostLine(key: l.key, roadClass: l.roadClass, oneway: l.oneway, xy: xy, cum: cum);
}

class TrafficGraph {
  TrafficGraph({required this.loadTile, required this.cellsPerTile, required this.extent, this.cacheTiles = 96, this.stitch = false, this.noCrossingAt});

  /// Quem entrega o tile do pacote visual (`null` se não há nada nele).
  final VisualTile? Function(int tx, int ty) loadTile;
  final int cellsPerTile;
  final int extent;
  final int cacheTiles;

  /// Rota: corta as linhas nas esquinas sem vértice comum ([stitchLines]) e liga os vértices na sobra entre dois tiles. O
  /// Tráfego do Véu usa o grafo sem isso, como sempre.
  final bool stitch;

  /// Onde um cruzamento sem vértice comum não vira esquina (viaduto). Só com [stitch].
  final bool Function(double x, double y)? noCrossingAt;

  final LinkedHashMap<(int, int), _TileData> _tiles = LinkedHashMap();
  final LinkedHashMap<(int, int), List<GhostLine>> _raw = LinkedHashMap();

  List<GhostLine> _rawLines(int tx, int ty) {
    final key = (tx, ty);
    final cached = _raw.remove(key);
    if (cached != null) return _raw[key] = cached;
    final tile = loadTile(tx, ty);
    final lines = tile == null ? const <GhostLine>[] : ghostLinesOfTile(tile, tx, ty, cellsPerTile: cellsPerTile, extent: extent);
    _raw[key] = lines;
    while (_raw.length > 32) {
      _raw.remove(_raw.keys.first);
    }
    return lines;
  }

  List<GhostLine> _stitched(int tx, int ty) {
    final own = _rawLines(tx, ty);
    if (own.isEmpty) return own;
    final x0 = tx * cellsPerTile - 1.0, y0 = ty * cellsPerTile - 1.0, x1 = (tx + 1) * cellsPerTile + 1.0, y1 = (ty + 1) * cellsPerTile + 1.0;
    final near = [
      for (var dx = -1; dx <= 1; dx++)
        for (var dy = -1; dy <= 1; dy++)
          if (dx != 0 || dy != 0)
            for (final l in _rawLines(tx + dx, ty + dy))
              if (l.maxX >= x0 && l.minX <= x1 && l.maxY >= y0 && l.minY <= y1) l,
    ];
    return stitchLines(own, near, noCrossingAt: noCrossingAt);
  }

  _TileData _data(int tx, int ty) {
    final key = (tx, ty);
    final cached = _tiles.remove(key);
    if (cached != null) {
      _tiles[key] = cached;
      return cached;
    }
    final List<GhostLine> lines;
    if (stitch) {
      lines = _stitched(tx, ty);
    } else {
      final tile = loadTile(tx, ty);
      lines = tile == null ? const <GhostLine>[] : ghostLinesOfTile(tile, tx, ty, cellsPerTile: cellsPerTile, extent: extent);
    }
    final vertices = <int, List<LineVertex>>{};
    for (final l in lines) {
      for (var i = 0; i < l.vertexCount; i++) {
        (vertices[_bucket(l.xy[2 * i].floor(), l.xy[2 * i + 1].floor())] ??= []).add((l, i));
      }
    }
    final d = _TileData(lines, vertices);
    _tiles[key] = d;
    while (_tiles.length > cacheTiles) {
      _tiles.remove(_tiles.keys.first);
    }
    return d;
  }

  List<GhostLine> linesOfTile(int tx, int ty) => _data(tx, ty).lines;

  /// Os vértices de outras ruas que caem em [x], [y] (a menos de [_joinCells]), fora [exclude]. A ordem é fixa
  /// (baldes na ordem de varredura, depois a ordem do pacote): dois aparelhos escolhem igual.
  List<LineVertex> joinsAt(double x, double y, {GhostLine? exclude}) {
    final out = <LineVertex>[];
    final bx = x.floor(), by = y.floor();
    int tileOf(int c) => c ~/ cellsPerTile - (c < 0 && c % cellsPerTile != 0 ? 1 : 0);
    // Com o corte, a sobra de um tile (vértices fora da área dele) também conta: os vizinhos da vizinhança de 3x3.
    final tiles = stitch
        ? {for (var dx = -1; dx <= 1; dx++) for (var dy = -1; dy <= 1; dy++) (tileOf(bx + dx), tileOf(by + dy))}
        : const <(int, int)>{};
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final cx = bx + dx, cy = by + dy;
        for (final t in stitch ? tiles : {(cx ~/ cellsPerTile - (cx < 0 ? 1 : 0), cy ~/ cellsPerTile - (cy < 0 ? 1 : 0))}) {
          final list = _data(t.$1, t.$2).vertices[_bucket(cx, cy)];
          if (list == null) continue;
          for (final v in list) {
            if (identical(v.$1, exclude) || (stitch && v.$1.key == exclude?.key)) continue; // o tile pode ter sido relido
            final ddx = v.$1.xy[2 * v.$2] - x, ddy = v.$1.xy[2 * v.$2 + 1] - y;
            if (ddx * ddx + ddy * ddy <= _joinCells * _joinCells) out.add(v);
          }
        }
      }
    }
    return out;
  }
}
