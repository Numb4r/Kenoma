/// Montagem de áreas do libosmium 2.23.1 (`area::Assembler`, a do pyosmium do pipeline) e rasterização do GDAL
/// (`GDALdllImageFilledPolygon`). A montagem só decide se a área existe: o GDAL faz par/ímpar sobre todos os anéis juntos,
/// então os segmentos que sobram depois de tirar as duplicatas já definem a célula pintada. Os anéis só servem ao desenho.
/// Dart puro.
library;

/// Um segmento de área em inteiros de 1e-7 grau, com `(x0, y0) < (x1, y1)`, como `NodeRefSegment`.
class AreaSegment implements Comparable<AreaSegment> {
  const AreaSegment._(this.x0, this.y0, this.x1, this.y1);

  factory AreaSegment(int ax, int ay, int bx, int by) {
    final swap = ax > bx || (ax == bx && ay > by);
    return swap ? AreaSegment._(bx, by, ax, ay) : AreaSegment._(ax, ay, bx, by);
  }

  final int x0, y0, x1, y1;

  bool sameAs(AreaSegment o) => x0 == o.x0 && y0 == o.y0 && x1 == o.x1 && y1 == o.y1;

  /// Pelo primeiro ponto, depois pelo segundo: basta para a varredura em x e para deixar duplicatas lado a lado.
  @override
  int compareTo(AreaSegment o) {
    if (x0 != o.x0) return x0.compareTo(o.x0);
    if (y0 != o.y0) return y0.compareTo(o.y0);
    if (x1 != o.x1) return x1.compareTo(o.x1);
    return y1.compareTo(o.y1);
  }
}

/// Os segmentos de uma polilinha (`extract_segments_from_way_impl`): pula nós na mesma posição.
void addSegments(List<AreaSegment> into, List<int> xy) {
  for (var i = 2; i + 1 < xy.length; i += 2) {
    if (xy[i] != xy[i - 2] || xy[i + 1] != xy[i - 1]) into.add(AreaSegment(xy[i - 2], xy[i - 1], xy[i], xy[i + 1]));
  }
}

const int _maxSplitLocations = 100;

/// `create_rings`: devolve os segmentos da área, ou `null` se o libosmium recusa (cruzamento, anel aberto, sobra nada).
List<AreaSegment>? assembleArea(List<AreaSegment> input) {
  final sorted = [...input]..sort();
  // `erase_duplicate_segments`: tira de dois em dois; se há três iguais, sobra um.
  final segs = <AreaSegment>[];
  for (final s in sorted) {
    if (segs.isNotEmpty && segs.last.sameAs(s)) {
      segs.removeLast();
    } else {
      segs.add(s);
    }
  }
  if (segs.isEmpty || _hasIntersection(segs)) return null;
  final degree = <(int, int), int>{};
  for (final s in segs) {
    degree[(s.x0, s.y0)] = (degree[(s.x0, s.y0)] ?? 0) + 1;
    degree[(s.x1, s.y1)] = (degree[(s.x1, s.y1)] ?? 0) + 1;
  }
  var splits = 0;
  for (final d in degree.values) {
    if (d.isOdd) return null;
    if (d > 2) splits++;
  }
  if (splits > _maxSplitLocations) return null;
  return segs;
}

bool _hasIntersection(List<AreaSegment> segs) {
  for (var i = 0; i + 1 < segs.length; i++) {
    final s1 = segs[i];
    final minY1 = s1.y0 < s1.y1 ? s1.y0 : s1.y1, maxY1 = s1.y0 < s1.y1 ? s1.y1 : s1.y0;
    for (var j = i + 1; j < segs.length; j++) {
      final s2 = segs[j];
      if (s2.x0 > s1.x1) break;
      final minY2 = s2.y0 < s2.y1 ? s2.y0 : s2.y1, maxY2 = s2.y0 < s2.y1 ? s2.y1 : s2.y0;
      if (minY1 > maxY2 || minY2 > maxY1) continue;
      if (_intersects(s1, s2)) return true;
    }
  }
  return false;
}

/// `calculate_intersection` devolve uma posição válida. Aritmética de int64, igual à do C++.
bool _intersects(AreaSegment a, AreaSegment b) {
  final px = a.x0, py = a.y0, qx = b.x0, qy = b.y0;
  final pdx = a.x1 - px, pdy = a.y1 - py, qdx = b.x1 - qx, qdy = b.y1 - qy;
  final d = pdx * qdy - pdy * qdx;
  if (d != 0) {
    final touch = (px == qx && py == qy) || (px == b.x1 && py == b.y1) || (a.x1 == qx && a.y1 == qy) || (a.x1 == b.x1 && a.y1 == b.y1);
    if (touch) return false;
    final na = qdx * (py - qy) - qdy * (px - qx);
    final nb = pdx * (py - qy) - pdy * (px - qx);
    return (d > 0 && na >= 0 && na <= d && nb >= 0 && nb <= d) || (d < 0 && na <= 0 && na >= d && nb <= 0 && nb >= d);
  }
  if (pdx * (qy - py) - pdy * (qx - px) != 0) return false;
  // Colineares: há sobreposição se os dois menores pontos não são do mesmo segmento e os dois do meio diferem.
  final loc = [(a.x0, a.y0, 0), (a.x1, a.y1, 0), (b.x0, b.y0, 1), (b.x1, b.y1, 1)]
    ..sort((l, r) => l.$1 != r.$1 ? l.$1.compareTo(r.$1) : l.$2.compareTo(r.$2));
  if (loc[1].$1 == loc[2].$1 && loc[1].$2 == loc[2].$2) return false;
  if (loc[0].$3 != loc[1].$3) return true;
  return false;
}

/// Anéis fechados dos segmentos de uma área, para o desenho: cada vértice sai por um segmento ainda livre.
List<List<(int, int)>> ringsOf(List<AreaSegment> segs) {
  final adj = <(int, int), List<int>>{};
  for (var i = 0; i < segs.length; i++) {
    (adj[(segs[i].x0, segs[i].y0)] ??= []).add(i);
    (adj[(segs[i].x1, segs[i].y1)] ??= []).add(i);
  }
  final used = List<bool>.filled(segs.length, false);
  final rings = <List<(int, int)>>[];
  for (var i = 0; i < segs.length; i++) {
    if (used[i]) continue;
    final start = (segs[i].x0, segs[i].y0);
    final ring = [start];
    var at = start;
    var seg = i;
    while (true) {
      used[seg] = true;
      final s = segs[seg];
      at = at == (s.x0, s.y0) ? (s.x1, s.y1) : (s.x0, s.y0);
      if (at == start) break;
      ring.add(at);
      final next = adj[at]!.where((k) => !used[k]);
      if (next.isEmpty) break;
      seg = next.first;
    }
    if (ring.length >= 3) rings.add(ring);
  }
  return rings;
}

/// Chama [span] com os trechos (linha, de, até) de uma grade `side * side`: arestas `x0, y0, x1, y1` em coordenadas de
/// célula, par/ímpar, como o GDAL com `all_touched=False`: varredura em `linha + 0.5`, arestas com `y0 <= y < y1`, de
/// `floor(x0 + 0.5)` a `floor(x1 + 0.5) - 1`. Os trechos podem sair da grade.
void fillEvenOdd(List<double> edges, int side, void Function(int row, int from, int to) span) {
  final rows = List<List<int>?>.filled(side, null);
  for (var i = 0; i + 3 < edges.length; i += 4) {
    _crossings(edges[i], edges[i + 1], edges[i + 2], edges[i + 3], side, (row, x, _) => (rows[row] ??= []).add((x + 0.5).floor()));
  }
  for (var row = 0; row < side; row++) {
    final xs = rows[row];
    if (xs == null) continue;
    xs.sort();
    for (var i = 0; i + 1 < xs.length; i += 2) {
      span(row, xs[i], xs[i + 1] - 1);
    }
  }
}

/// Como [fillEvenOdd], para a região de profundidade >= 1. Arestas `x0, y0, x1, y1, delta`: `delta` é quanto a
/// profundidade muda ao cruzar, de oeste para leste, a aresta percorrida no sentido de y crescente. Fora de todas as
/// curvas a profundidade é zero.
void fillDepth(List<double> edges, int side, void Function(int row, int from, int to) span) {
  final rows = List<List<(double, int)>?>.filled(side, null);
  for (var i = 0; i + 4 < edges.length; i += 5) {
    final delta = edges[i + 4].toInt();
    _crossings(edges[i], edges[i + 1], edges[i + 2], edges[i + 3], side, (row, x, up) => (rows[row] ??= []).add((x, up ? delta : -delta)));
  }
  for (var row = 0; row < side; row++) {
    final xs = rows[row];
    if (xs == null) continue;
    xs.sort((a, b) => a.$1.compareTo(b.$1));
    var depth = 0, from = 0;
    for (final (x, d) in xs) {
      final next = depth + d;
      if (depth <= 0 && next >= 1) from = (x + 0.5).floor();
      if (depth >= 1 && next <= 0) span(row, from, (x + 0.5).floor() - 1);
      depth = next;
    }
  }
}

/// Chama [hit] com `(linha, x, sobe)` em cada linha que a aresta cruza. `sobe`: y cresce do início ao fim.
void _crossings(double x0, double y0, double x1, double y1, int side, void Function(int row, double x, bool up) hit) {
  if (y0 == y1) return;
  final up = y0 < y1;
  final (ax, ay, bx, by) = up ? (x0, y0, x1, y1) : (x1, y1, x0, y0);
  var first = (ay - 0.5).ceil();
  var last = (by - 0.5).ceil() - 1;
  if (first < 0) first = 0;
  if (last >= side) last = side - 1;
  for (var row = first; row <= last; row++) {
    final dy = row + 0.5;
    hit(row, (dy - ay) * (bx - ax) / (by - ay) + ax, up);
  }
}
