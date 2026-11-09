/// Classifica um bloco de 1 km a partir da resposta da Overpass, com as mesmas regras de `pipeline/build_region.py`,
/// `build_visual.py` e `build_nowalk.py`. Dart puro: chamável dentro de um Isolate. O oráculo é `campinas_e0.bin`
/// (`test/world/fallback/oracle_test.dart`).
library;

import 'dart:convert' show jsonDecode;
import 'dart:math' as math;
import 'dart:typed_data';

import '../../data/visual_pack.dart';
import 'block.dart';
import 'geos_buffer.dart';
import 'osm_area.dart';
import 'osm_rules.dart';
import 'utm.dart';

export 'osm_rules.dart' show OsmRules, overpassQuery;

const int _cellZoom = 21;
const int _extent = 4096;
const double _visualMargin = 0.01; // em tiles, como `MARGIN` de build_visual.py
const double _noWalkMarginCells = 4;
const double _lineTolM = 1, _polyTolM = 2;
const double _earthCircumference = 40075016.686;
const int _biomeGreen = 2, _biomeWater = 3;
const Set<String> _skipService = {'driveway', 'parking_aisle', 'drive-through'};
const Set<String> _noWalkHighways = {'motorway', 'motorway_link', 'trunk', 'trunk_link'};

double _tileX(double lon, int zoom) => (lon + 180) / 360 * (1 << zoom);

double _tileY(double lat, int zoom) => (1 - asinh(math.tan(lat * math.pi / 180)) / math.pi) / 2 * (1 << zoom);

/// Geometria de um elemento da Overpass, em inteiros de 1e-7 grau: `x0, y0, x1, y1...` (`null` se falta um nó).
List<int>? _geometry(Object? raw) {
  if (raw is! List) return null;
  final out = <int>[];
  for (final p in raw) {
    if (p == null) return null;
    final m = p as Map<String, dynamic>;
    out.add(((m['lon'] as num) * 1e7).round());
    out.add(((m['lat'] as num) * 1e7).round());
  }
  return out;
}

/// `highway_class` de build_visual.py.
int? highwayClass(Map<String, dynamic> tags) {
  final highway = tags['highway'];
  final cls = highwayClasses[highway ?? ''];
  if (cls == null) return null;
  final tunnel = tags['tunnel'];
  if ((tunnel != null && tunnel != 'no') || tags['area'] == 'yes') return null;
  if (highway == 'service' && _skipService.contains(tags['service'])) return null;
  final indoor = tags['indoor'];
  if ((indoor != null && indoor != '') || (tags['access'] == 'private' && cls == 3)) return null;
  return cls;
}

/// `oneway_of` de build_visual.py.
OneWay onewayOf(Map<String, dynamic> tags, int cls) {
  if (cls == 3) return OneWay.twoWay;
  final v = tags['oneway'];
  if (v == '-1' || v == 'reverse') return OneWay.reverse;
  if (v == 'yes' || v == 'true' || v == '1') return OneWay.forward;
  if (v == 'no' || v == 'false' || v == '0') return OneWay.twoWay;
  final junction = tags['junction'], highway = tags['highway'];
  if (junction == 'roundabout' || junction == 'circular' || highway == 'motorway' || highway == 'motorway_link') return OneWay.forward;
  return OneWay.twoWay;
}

class _Builder {
  _Builder(this.tx, this.ty, this.rules)
      : originX = (tx * blockCells).toDouble(),
        originY = (ty * blockCells).toDouble() {
    final centerLon = (tx + 0.5) / (1 << blockZoom) * 360 - 180;
    final centerLat = math.atan(sinh(math.pi * (1 - 2 * (ty + 0.5) / (1 << blockZoom)))) * 180 / math.pi;
    utm = Utm.zone(Utm.zoneOf(centerLon), south: centerLat < 0);
    cos = math.cos(centerLat * math.pi / 180);
    tileM = _earthCircumference * cos / (1 << blockZoom);
  }

  final int tx, ty;
  final OsmRules rules;
  final double originX, originY;
  late final Utm utm;
  late final double cos, tileM;

  final Map<int, Uint8List> masks = {};
  final List<VisualLine> lines = [];
  final List<VisualArea> areas = [];
  final List<double> noWalk = [];
  final List<double> access = [];

  double get cellM => tileM / blockCells;

  Uint8List mask(int biome) => masks[biome] ??= Uint8List(blockCells * blockCells);

  void paint(Uint8List m, int row, int from, int to) {
    final a = from < 0 ? 0 : from, b = to >= blockCells ? blockCells - 1 : to;
    for (var x = a; x <= b; x++) {
      m[row * blockCells + x] = 1;
    }
  }

  double cellX(double lon) => _tileX(lon, _cellZoom) - originX;

  double cellY(double lat) => _tileY(lat, _cellZoom) - originY;

  void addWay(Map<String, dynamic> element) {
    final tags = (element['tags'] as Map<String, dynamic>?) ?? const {};
    final xy = _geometry(element['geometry']);
    if (xy == null) return;
    final unique = _unique(xy);
    if (unique.length >= 4) {
      _addLine(tags, unique);
      _addRoad(tags, unique);
      _addNoWalk(tags, unique);
      _addAccess(tags, unique);
    }
    // `after_way` do MultipolygonManager: mais de 3 nós, pontas na mesma posição, sem `area=no`.
    final n = xy.length;
    if (n > 6 && xy[0] == xy[n - 2] && xy[1] == xy[n - 1] && tags['area'] != 'no') {
      final matches = rules.matches(tags, isArea: true);
      if (matches.isNotEmpty) {
        final segs = <AreaSegment>[];
        addSegments(segs, xy);
        _addArea(matches, segs);
      }
    }
  }

  void addRelation(Map<String, dynamic> element) {
    final tags = (element['tags'] as Map<String, dynamic>?) ?? const {};
    final type = tags['type'];
    if (type != 'multipolygon' && type != 'boundary') return;
    final matches = rules.matches(tags, isArea: true);
    if (matches.isEmpty) return;
    final segs = <AreaSegment>[];
    final seen = <int>{};
    for (final raw in (element['members'] as List?) ?? const []) {
      final member = raw as Map<String, dynamic>;
      if (member['type'] != 'way') continue;
      if (!seen.add(member['ref'] as int)) continue;
      final xy = _geometry(member['geometry']);
      if (xy == null) return; // relation incompleta: o libosmium nunca a monta
      addSegments(segs, xy);
    }
    if (seen.isEmpty) return;
    _addArea(matches, segs);
  }

  /// Sem pontos repetidos, como `create_linestring`.
  List<int> _unique(List<int> xy) {
    final out = <int>[];
    for (var i = 0; i + 1 < xy.length; i += 2) {
      if (out.isEmpty || xy[i] != out[out.length - 2] || xy[i + 1] != out[out.length - 1]) {
        out
          ..add(xy[i])
          ..add(xy[i + 1]);
      }
    }
    return out;
  }

  void _addArea(List<OsmMatch> matches, List<AreaSegment> segs) {
    final area = assembleArea(segs);
    if (area == null) return;
    final edges = <double>[];
    for (final s in area) {
      edges
        ..add(cellX(s.x0 / 1e7))
        ..add(cellY(s.y0 / 1e7))
        ..add(cellX(s.x1 / 1e7))
        ..add(cellY(s.y1 / 1e7));
    }
    for (final m in matches) {
      final target = mask(m.biomeId);
      fillEvenOdd(edges, blockCells, (row, from, to) => paint(target, row, from, to));
    }
    final visual = matches.where((m) => m.biomeId == _biomeGreen || m.biomeId == _biomeWater);
    if (visual.isNotEmpty) {
      final rings = [
        for (final ring in ringsOf(area)) [for (final (x, y) in ring) Pt(_tileX(x / 1e7, blockZoom) - tx, _tileY(y / 1e7, blockZoom) - ty)]
      ];
      _addPolygons(visual.first.biomeId, rings);
    }
  }

  void _addLine(Map<String, dynamic> tags, List<int> xy) {
    final matches = rules.matches(tags, isArea: false);
    if (matches.isEmpty) return;
    var minX = double.infinity, maxX = -minX, minY = minX, maxY = -minX;
    for (var i = 0; i + 1 < xy.length; i += 2) {
      final x = cellX(xy[i] / 1e7), y = cellY(xy[i + 1] / 1e7);
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    List<Pt>? metric;
    for (final m in matches) {
      final reach = m.bufferM / cellM + 2;
      if (maxX < -reach || minX > blockCells + reach || maxY < -reach || minY > blockCells + reach) continue;
      metric ??= [
        for (var i = 0; i + 1 < xy.length; i += 2)
          () {
            final (e, n) = utm.forward(xy[i] / 1e7, xy[i + 1] / 1e7);
            return Pt(e, n);
          }()
      ];
      final edges = <double>[];
      for (final curve in bufferCurves(metric, m.bufferM)) {
        final delta = curve.interiorRight ? -1.0 : 1.0;
        double? px, py;
        for (final p in curve.pts) {
          final (lon, lat) = utm.inverse(p.x, p.y);
          final x = cellX(lon), y = cellY(lat);
          if (px != null) {
            edges
              ..add(px)
              ..add(py!)
              ..add(x)
              ..add(y)
              ..add(delta);
          }
          px = x;
          py = y;
        }
      }
      final target = mask(m.biomeId);
      fillDepth(edges, blockCells, (row, from, to) => paint(target, row, from, to));
    }
    // Rios e córregos desenhados: largura total igual ao buffer do bioma. Ruas ficam só com as linhas.
    if (tags.containsKey('highway')) return;
    final visual = matches.where((m) => m.biomeId == _biomeGreen || m.biomeId == _biomeWater);
    if (visual.isEmpty) return;
    final pts = [for (var i = 0; i + 1 < xy.length; i += 2) Pt(_tileX(xy[i] / 1e7, blockZoom) - tx, _tileY(xy[i + 1] / 1e7, blockZoom) - ty)];
    _addPolygons(visual.first.biomeId, [for (final c in bufferCurves(pts, visual.first.bufferM / tileM / 2)) c.pts]);
  }

  /// Agrupa anéis fechados em contorno e buracos pelo aninhamento, simplifica e guarda os que tocam o bloco.
  void _addPolygons(int biome, List<List<Pt>> rings) {
    final bySize = [...rings]..sort((a, b) => _absArea(b).compareTo(_absArea(a)));
    final depth = <int>[];
    final parent = <int>[];
    final groups = <int, List<List<Pt>>>{};
    for (var i = 0; i < bySize.length; i++) {
      var p = -1;
      for (var j = i - 1; j >= 0 && p < 0; j--) {
        if (_contains(bySize[j], bySize[i].first)) p = j;
      }
      parent.add(p);
      depth.add(p < 0 ? 0 : depth[p] + 1);
      if (depth[i].isEven) {
        groups[i] = [bySize[i]];
      } else {
        groups[p]!.add(bySize[i]);
      }
    }
    final kind = biome == _biomeWater ? AreaKind.water : AreaKind.green;
    final tol = _polyTolM / tileM;
    for (final group in groups.values) {
      if (!_touchesTile(group.first)) continue;
      final out = <Int32List>[];
      for (final ring in group) {
        final q = _quantize(_douglasPeucker(ring, tol), closed: true);
        if (q.length >= 6) out.add(q);
      }
      if (out.isNotEmpty) areas.add(VisualArea(kind, out));
    }
  }

  bool _touchesTile(List<Pt> ring) {
    var minX = double.infinity, maxX = -minX, minY = minX, maxY = -minX;
    for (final p in ring) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    return maxX >= -_visualMargin && minX <= 1 + _visualMargin && maxY >= -_visualMargin && minY <= 1 + _visualMargin;
  }

  void _addRoad(Map<String, dynamic> tags, List<int> xy) {
    if (!tags.containsKey('highway')) return;
    final cls = highwayClass(tags);
    if (cls == null) return;
    final pts = [for (var i = 0; i + 1 < xy.length; i += 2) Pt(_tileX(xy[i] / 1e7, blockZoom) - tx, _tileY(xy[i + 1] / 1e7, blockZoom) - ty)];
    final name = cls <= 1 ? ((tags['name'] as String?) ?? '').trim() : '';
    final oneway = onewayOf(tags, cls);
    for (final piece in _clip(_douglasPeucker(pts, _lineTolM / tileM), -_visualMargin, 1 + _visualMargin)) {
      final q = _quantize(piece, closed: false);
      if (q.length >= 4) {
        lines.add(VisualLine(RoadClass.values[cls], q, oneway: oneway, name: name.isEmpty ? null : name));
      }
    }
  }

  void _addNoWalk(Map<String, dynamic> tags, List<int> xy) {
    if (!_noWalkHighways.contains(tags['highway'])) return;
    final tunnel = tags['tunnel'];
    if (tunnel != null && tunnel != 'no') return;
    final pts = [for (var i = 0; i + 1 < xy.length; i += 2) Pt(cellX(xy[i] / 1e7), cellY(xy[i + 1] / 1e7))];
    for (final piece in _clip(_douglasPeucker(pts, _lineTolM / cellM), -_noWalkMarginCells, blockCells + _noWalkMarginCells)) {
      for (var i = 0; i + 1 < piece.length; i++) {
        noWalk
          ..add(piece[i].x + originX)
          ..add(piece[i].y + originY)
          ..add(piece[i + 1].x + originX)
          ..add(piece[i + 1].y + originY);
      }
    }
  }

  /// `build_noaccess.py`: as vias do desenho com algum bit de rota, na mesma geometria do noWalk.
  void _addAccess(Map<String, dynamic> tags, List<int> xy) {
    if (!tags.containsKey('highway') || highwayClass(tags) == null) return;
    final mask = accessMask(tags);
    if (mask == 0) return;
    final pts = [for (var i = 0; i + 1 < xy.length; i += 2) Pt(cellX(xy[i] / 1e7), cellY(xy[i + 1] / 1e7))];
    for (final piece in _clip(_douglasPeucker(pts, _lineTolM / cellM), -_noWalkMarginCells, blockCells + _noWalkMarginCells)) {
      for (var i = 0; i + 1 < piece.length; i++) {
        access.addAll([piece[i].x + originX, piece[i].y + originY, piece[i + 1].x + originX, piece[i + 1].y + originY, mask.toDouble()]);
      }
    }
  }

  Int32List _quantize(List<Pt> pts, {required bool closed}) {
    final n = closed ? pts.length - 1 : pts.length; // o anel do pacote não repete o primeiro ponto
    final out = <int>[];
    for (var i = 0; i < n; i++) {
      final x = (pts[i].x * _extent).round(), y = (pts[i].y * _extent).round();
      if (out.isEmpty || x != out[out.length - 2] || y != out[out.length - 1]) {
        out
          ..add(x)
          ..add(y);
      }
    }
    return Int32List.fromList(out);
  }

  Uint8List cells() {
    final out = Uint8List(blockCells * blockCells);
    for (final biome in rules.biomesByPriority) {
      final m = masks[biome];
      if (m == null) continue;
      for (var i = 0; i < out.length; i++) {
        if (m[i] != 0) out[i] = biome;
      }
    }
    return out;
  }
}

double _absArea(List<Pt> ring) {
  var sum = 0.0;
  for (var i = 0; i + 1 < ring.length; i++) {
    sum += ring[i].x * ring[i + 1].y - ring[i + 1].x * ring[i].y;
  }
  return sum.abs() / 2;
}

bool _contains(List<Pt> ring, Pt p) {
  var inside = false;
  for (var i = 0; i + 1 < ring.length; i++) {
    final a = ring[i], b = ring[i + 1];
    if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) inside = !inside;
  }
  return inside;
}

double _segmentDistance(Pt p, Pt a, Pt b) {
  final dx = b.x - a.x, dy = b.y - a.y, len2 = dx * dx + dy * dy;
  if (len2 == 0) return p.distance(a);
  final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamp(0.0, 1.0);
  return p.distance(Pt(a.x + t * dx, a.y + t * dy));
}

/// Douglas-Peucker sem recursão. Num anel fechado as pontas coincidem e o ponto mais distante divide o anel.
List<Pt> _douglasPeucker(List<Pt> pts, double tol) {
  if (pts.length < 3) return pts;
  final keep = List<bool>.filled(pts.length, false);
  keep[0] = keep[pts.length - 1] = true;
  final stack = [(0, pts.length - 1)];
  while (stack.isNotEmpty) {
    final (a, b) = stack.removeLast();
    var best = -1.0, at = -1;
    for (var i = a + 1; i < b; i++) {
      final d = _segmentDistance(pts[i], pts[a], pts[b]);
      if (d > best) {
        best = d;
        at = i;
      }
    }
    if (at >= 0 && best > tol) {
      keep[at] = true;
      stack
        ..add((a, at))
        ..add((at, b));
    }
  }
  return [for (var i = 0; i < pts.length; i++) if (keep[i]) pts[i]];
}

/// Os trechos de uma polilinha dentro do quadrado `[lo, hi]` (Liang-Barsky).
List<List<Pt>> _clip(List<Pt> pts, double lo, double hi) {
  final out = <List<Pt>>[];
  List<Pt>? piece;
  for (var i = 0; i + 1 < pts.length; i++) {
    final a = pts[i], b = pts[i + 1];
    final dx = b.x - a.x, dy = b.y - a.y;
    var t0 = 0.0, t1 = 1.0;
    var inside = true;
    for (final (p, q) in [(-dx, a.x - lo), (dx, hi - a.x), (-dy, a.y - lo), (dy, hi - a.y)]) {
      if (p == 0) {
        if (q < 0) inside = false;
        continue;
      }
      final r = q / p;
      if (p < 0) {
        if (r > t1) inside = false;
        if (r > t0) t0 = r;
      } else {
        if (r < t0) inside = false;
        if (r < t1) t1 = r;
      }
    }
    if (!inside || t0 > t1) {
      piece = null;
      continue;
    }
    final start = Pt(a.x + t0 * dx, a.y + t0 * dy), end = Pt(a.x + t1 * dx, a.y + t1 * dy);
    if (piece == null || t0 > 0) {
      piece = [start];
      out.add(piece);
    }
    piece.add(end);
    if (t1 < 1) piece = null;
  }
  return out;
}

/// O bloco `(tx, ty)` a partir do JSON de `overpassQuery`. [epochId] é a época cuja data fixou a consulta.
FallbackBlock buildBlock({required String overpassJson, required int tx, required int ty, required int epochId, required OsmRules rules}) {
  final doc = jsonDecode(overpassJson) as Map<String, dynamic>;
  // Timeout e falta de memória chegam com HTTP 200, `remark` e a lista cortada: um bloco assim não pode ir para o cache.
  if (doc['remark'] != null) throw FormatException('Overpass: ${doc['remark']}');
  final builder = _Builder(tx, ty, rules);
  final seen = <(String, int)>{};
  for (final raw in doc['elements'] as List) {
    final element = raw as Map<String, dynamic>;
    final type = element['type'] as String;
    if (!seen.add((type, element['id'] as int))) continue;
    if (type == 'way') {
      builder.addWay(element);
    } else if (type == 'relation') {
      builder.addRelation(element);
    }
  }
  return FallbackBlock(
    tx: tx,
    ty: ty,
    epochId: epochId,
    cells: builder.cells(),
    visual: VisualTile(lines: builder.lines, areas: builder.areas),
    noWalk: builder.noWalk,
    access: builder.access,
  );
}
