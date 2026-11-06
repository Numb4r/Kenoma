/// Porte da curva de offset do GEOS 3.13.1 (`BufferCurveSetBuilder`, `OffsetCurveBuilder`, `OffsetSegmentGenerator`,
/// `BufferInputLineSimplifier`), a versão instalada no pipeline, com os parâmetros padrão do shapely (quad_segs=16, cap e
/// join redondos). O pipeline rasteriza o polígono do buffer pelo centro da célula; aqui a curva crua basta: o polígono
/// do GEOS é a região de profundidade >= 1 das curvas (`BufferBuilder::depthDelta`, `findResultEdges`), e o noding só
/// acrescenta vértices sobre as mesmas arestas. Dart puro.
library;

import 'dart:math' as math;

class Pt {
  const Pt(this.x, this.y);

  final double x, y;

  double distance(Pt o) {
    final dx = x - o.x, dy = y - o.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  bool same(Pt o) => x == o.x && y == o.y;
}

/// Uma curva crua fechada. `interiorRight`: o interior fica à direita do sentido da curva (esquerda EXTERIOR, direita
/// INTERIOR no GEOS); senão fica à esquerda.
class OffsetCurve {
  const OffsetCurve(this.pts, {required this.interiorRight});

  final List<Pt> pts;
  final bool interiorRight;
}

const int _cw = -1, _ccw = 1, _left = 1, _right = 2;
const int _quadSegs = 16;
const double _piOver2 = math.pi / 2, _twoPi = 2 * math.pi;
const double _simplifyFactor = 100.0;
const double _curveVertexSnap = 1e-4, _offsetSeparation = 1e-3, _insideTurnSnap = 1e-3;
const int _closingSegLenFactor = 80;
const int _maxInvertedRingSize = 9, _invertedCurveVertexFactor = 4;
const double _nearnessFactor = 0.99;

/// As curvas do buffer de uma linha sem pontos repetidos, com ao menos dois pontos.
List<OffsetCurve> bufferCurves(List<Pt> line, double distance) {
  if (_isRing(line)) return _ringCurves(line, distance);
  return [OffsetCurve(_lineCurve(line, distance), interiorRight: true)];
}

bool _isRing(List<Pt> c) => c.length >= 4 && c.first.same(c.last);

List<Pt> _lineCurve(List<Pt> pts, double distance) {
  final seg = _SegmentGenerator(distance);
  final tol = distance / _simplifyFactor;
  final simp1 = _simplify(pts, tol);
  final n1 = simp1.length - 1;
  seg.initSideSegments(simp1[0], simp1[1], _left);
  for (var i = 2; i <= n1; i++) {
    seg.addNextSegment(simp1[i], true);
  }
  seg.addLastSegment();
  seg.addLineEndCap(simp1[n1 - 1], simp1[n1]);

  final simp2 = _simplify(pts, -tol);
  final n2 = simp2.length - 1;
  seg.initSideSegments(simp2[n2], simp2[n2 - 1], _left);
  for (var i = n2 - 1; i > 0; i--) {
    seg.addNextSegment(simp2[i - 1], true);
  }
  seg.addLastSegment();
  seg.addLineEndCap(simp2[1], simp2[0]);
  seg.closeRing();
  return seg.out;
}

List<OffsetCurve> _ringCurves(List<Pt> coord, double distance) {
  final curves = <OffsetCurve>[];
  final isHoleComputed = !_isRingFullyEroded(coord, distance);
  final isCcw = _signedArea(coord) < 0;
  void side(int s, bool interiorRight) {
    final curve = _ringCurve(coord, s, distance);
    if (!_isRingCurveInverted(coord, distance, curve)) curves.add(OffsetCurve(curve, interiorRight: interiorRight));
  }

  if (!isCcw || isHoleComputed) side(_left, true);
  if (isCcw || isHoleComputed) side(_right, false);
  return curves;
}

List<Pt> _ringCurve(List<Pt> pts, int side, double distance) {
  final seg = _SegmentGenerator(distance);
  var tol = distance / _simplifyFactor;
  if (side == _right) tol = -tol;
  final simp = _simplify(pts, tol);
  final n = simp.length - 1;
  seg.initSideSegments(simp[n - 1], simp[0], side);
  for (var i = 1; i <= n; i++) {
    seg.addNextSegment(simp[i], i != 1);
  }
  seg.closeRing();
  return seg.out;
}

/// `Area::ofRingSigned`: positivo em sentido horário.
double _signedArea(List<Pt> ring) {
  final n = ring.length;
  if (n < 3) return 0;
  final x0 = ring[0].x;
  var sum = 0.0;
  for (var i = 1; i < n - 1; i++) {
    sum += (ring[i].x - x0) * (ring[i - 1].y - ring[i + 1].y);
  }
  return sum / 2;
}

bool _isRingFullyEroded(List<Pt> ring, double distance) {
  if (ring.length < 4) return true;
  if (ring.length == 4) {
    final p0 = ring[0], p1 = ring[1], p2 = ring[2];
    final len0 = p1.distance(p2), len1 = p0.distance(p2), len2 = p0.distance(p1);
    final circum = len0 + len1 + len2;
    final c = Pt((len0 * p0.x + len1 * p1.x + len2 * p2.x) / circum, (len0 * p0.y + len1 * p1.y + len2 * p2.y) / circum);
    return _pointToSegment(c, p0, p1) < distance;
  }
  var minX = ring[0].x, maxX = minX, minY = ring[0].y, maxY = minY;
  for (final p in ring) {
    minX = math.min(minX, p.x);
    maxX = math.max(maxX, p.x);
    minY = math.min(minY, p.y);
    maxY = math.max(maxY, p.y);
  }
  return 2 * distance > math.min(maxY - minY, maxX - minX);
}

bool _isRingCurveInverted(List<Pt> input, double dist, List<Pt> curve) {
  if (input.length <= 3 || input.length >= _maxInvertedRingSize) return false;
  if (curve.length > _invertedCurveVertexFactor * input.length) return false;
  final tol = _nearnessFactor * dist;
  double toRing(Pt p) {
    var best = double.infinity;
    for (var i = 0; i + 1 < input.length; i++) {
      best = math.min(best, _pointToSegment(p, input[i], input[i + 1]));
    }
    return best;
  }

  for (var i = 0; i < curve.length; i++) {
    final v = curve[i], next = curve[i < curve.length - 1 ? i + 1 : 0];
    if (toRing(v) > tol) return false;
    if (toRing(Pt((v.x + next.x) / 2, (v.y + next.y) / 2)) > tol) return false;
  }
  return true;
}

double _pointToSegment(Pt p, Pt a, Pt b) {
  if (a.same(b)) return p.distance(a);
  final abx = b.x - a.x, aby = b.y - a.y, len2 = abx * abx + aby * aby;
  final r = ((p.x - a.x) * abx + (p.y - a.y) * aby) / len2;
  if (r <= 0) return p.distance(a);
  if (r >= 1) return p.distance(b);
  final s = ((a.y - p.y) * abx - (a.x - p.x) * aby) / len2;
  return s.abs() * math.sqrt(len2);
}

// BufferInputLineSimplifier

List<Pt> _simplify(List<Pt> input, double signedTol) {
  final tol = signedTol.abs();
  final angleOrientation = signedTol < 0 ? _cw : _ccw;
  final deleted = List<bool>.filled(input.length, false);
  int next(int i) {
    var n = i + 1;
    while (n < input.length && deleted[n]) {
      n++;
    }
    return n;
  }

  bool shallow(Pt p0, Pt p1, Pt p2) => _pointToSegment(p1, p0, p2) < tol;
  bool deletable(int i0, int i1, int i2) {
    final p0 = input[i0], p1 = input[i1], p2 = input[i2];
    if (orientationIndex(p0, p1, p2) != angleOrientation) return false;
    if (!shallow(p0, p1, p2)) return false;
    // `isShallowSampled`: o GEOS passa p1 no lugar de p2, e o porte mantém.
    var inc = (i2 - i0) ~/ 10;
    if (inc <= 0) inc = 1;
    for (var i = i0; i < i2; i += inc) {
      if (!shallow(p0, p1, input[i])) return false;
    }
    return true;
  }

  bool changed;
  do {
    changed = false;
    var index = 1;
    var mid = next(index), last = next(mid);
    while (last < input.length) {
      var midDeleted = false;
      if (deletable(index, mid, last)) {
        deleted[mid] = true;
        midDeleted = true;
        changed = true;
      }
      index = midDeleted ? last : mid;
      mid = next(index);
      last = next(mid);
    }
  } while (changed);
  return [for (var i = 0; i < input.length; i++) if (!deleted[i]) input[i]];
}

// OffsetSegmentGenerator e OffsetSegmentString

class _Seg {
  const _Seg(this.p0, this.p1);

  final Pt p0, p1;
}

class _SegmentGenerator {
  _SegmentGenerator(this.distance)
      : _quantum = _piOver2 / _quadSegs,
        _minVertexDistance = distance * _curveVertexSnap;

  final double distance;
  final double _quantum, _minVertexDistance;
  final List<Pt> out = [];
  late Pt s0, s1, s2;
  late _Seg offset0, offset1;
  int side = _left;

  void _add(Pt p) {
    if (out.isNotEmpty && p.distance(out.last) < _minVertexDistance) return;
    out.add(p);
  }

  void closeRing() {
    if (out.isNotEmpty && !out.first.same(out.last)) out.add(out.first);
  }

  _Seg _offset(Pt a, Pt b, int side) {
    final sign = side == _left ? 1 : -1;
    final dx = b.x - a.x, dy = b.y - a.y;
    final len = math.sqrt(dx * dx + dy * dy);
    final ux = sign * distance * dx / len, uy = sign * distance * dy / len;
    return _Seg(Pt(a.x - uy, a.y + ux), Pt(b.x - uy, b.y + ux));
  }

  void initSideSegments(Pt a, Pt b, int s) {
    s1 = a;
    s2 = b;
    side = s;
    offset1 = _offset(s1, s2, side);
  }

  void addLastSegment() => _add(offset1.p1);

  void addNextSegment(Pt p, bool addStartPoint) {
    if (s2.same(p)) return;
    s0 = s1;
    s1 = s2;
    s2 = p;
    offset0 = _offset(s0, s1, side);
    offset1 = _offset(s1, s2, side);
    final orientation = orientationIndex(s0, s1, s2);
    final outside = (orientation == _cw && side == _left) || (orientation == _ccw && side == _right);
    if (orientation == 0) {
      _addCollinear();
    } else if (outside) {
      _addOutsideTurn(orientation, addStartPoint);
    } else {
      _addInsideTurn();
    }
  }

  void addLineEndCap(Pt p0, Pt p1) {
    final l = _offset(p0, p1, _left), r = _offset(p0, p1, _right);
    final angle = math.atan2(p1.y - p0.y, p1.x - p0.x);
    _add(l.p1);
    _fillet(p1, angle + _piOver2, angle - _piOver2, _cw);
    _add(r.p1);
  }

  void _filletPoints(Pt p, Pt p0, Pt p1, int direction) {
    var start = math.atan2(p0.y - p.y, p0.x - p.x);
    final end = math.atan2(p1.y - p.y, p1.x - p.x);
    if (direction == _cw) {
      if (start <= end) start += _twoPi;
    } else {
      if (start >= end) start -= _twoPi;
    }
    _add(p0);
    _fillet(p, start, end, direction);
    _add(p1);
  }

  void _fillet(Pt p, double start, double end, int direction) {
    final factor = direction == _cw ? -1 : 1;
    final total = (start - end).abs();
    final nSegs = (total / _quantum + 0.5).toInt();
    if (nSegs < 1) return;
    final inc = total / nSegs;
    for (var i = 0; i < nSegs; i++) {
      final a = start + factor * i * inc;
      var sn = math.sin(a), cs = math.cos(a);
      if (sn.abs() < 5e-16) sn = 0;
      if (cs.abs() < 5e-16) cs = 0;
      _add(Pt(p.x + distance * cs, p.y + distance * sn));
    }
  }

  void _addCollinear() {
    final li = lineIntersection(s0, s1, s1, s2);
    if (li.count >= 2) _filletPoints(s1, offset0.p1, offset1.p0, _cw);
  }

  void _addOutsideTurn(int orientation, bool addStartPoint) {
    if (offset0.p1.distance(offset1.p0) < distance * _offsetSeparation) {
      _add(offset0.p1);
      return;
    }
    if (addStartPoint) _add(offset0.p1);
    _filletPoints(s1, offset0.p1, offset1.p0, orientation);
    _add(offset1.p0);
  }

  void _addInsideTurn() {
    final li = lineIntersection(offset0.p0, offset0.p1, offset1.p0, offset1.p1);
    if (li.count > 0) {
      _add(li.point!);
      return;
    }
    if (offset0.p1.distance(offset1.p0) < distance * _insideTurnSnap) {
      _add(offset0.p1);
      return;
    }
    _add(offset0.p1);
    const f = _closingSegLenFactor;
    _add(Pt((f * offset0.p1.x + s1.x) / (f + 1), (f * offset0.p1.y + s1.y) / (f + 1)));
    _add(Pt((f * offset1.p0.x + s1.x) / (f + 1), (f * offset1.p0.y + s1.y) / (f + 1)));
    _add(offset1.p0);
  }
}

// LineIntersector

class LineHit {
  const LineHit(this.count, this.point);

  /// 0 sem interseção, 1 num ponto, 2 colinear.
  final int count;
  final Pt? point;
}

bool _inEnv(Pt a, Pt b, Pt q) =>
    q.x >= math.min(a.x, b.x) && q.x <= math.max(a.x, b.x) && q.y >= math.min(a.y, b.y) && q.y <= math.max(a.y, b.y);

LineHit lineIntersection(Pt p1, Pt p2, Pt q1, Pt q2) {
  if (math.min(p1.x, p2.x) > math.max(q1.x, q2.x) || math.max(p1.x, p2.x) < math.min(q1.x, q2.x)) return const LineHit(0, null);
  if (math.min(p1.y, p2.y) > math.max(q1.y, q2.y) || math.max(p1.y, p2.y) < math.min(q1.y, q2.y)) return const LineHit(0, null);
  final pq1 = orientationIndex(p1, p2, q1), pq2 = orientationIndex(p1, p2, q2);
  if ((pq1 > 0 && pq2 > 0) || (pq1 < 0 && pq2 < 0)) return const LineHit(0, null);
  final qp1 = orientationIndex(q1, q2, p1), qp2 = orientationIndex(q1, q2, p2);
  if ((qp1 > 0 && qp2 > 0) || (qp1 < 0 && qp2 < 0)) return const LineHit(0, null);
  if (pq1 == 0 && pq2 == 0 && qp1 == 0 && qp2 == 0) return _collinear(p1, p2, q1, q2);
  if (pq1 == 0 || pq2 == 0 || qp1 == 0 || qp2 == 0) {
    if (p1.same(q1) || p1.same(q2)) return LineHit(1, p1);
    if (p2.same(q1) || p2.same(q2)) return LineHit(1, p2);
    if (pq1 == 0) return LineHit(1, q1);
    if (pq2 == 0) return LineHit(1, q2);
    if (qp1 == 0) return LineHit(1, p1);
    return LineHit(1, p2);
  }
  var pt = _intersection(p1, p2, q1, q2) ?? _nearestEndpoint(p1, p2, q1, q2);
  if (!(_inEnv(p1, p2, pt) && _inEnv(q1, q2, pt))) pt = _nearestEndpoint(p1, p2, q1, q2);
  return LineHit(1, pt);
}

LineHit _collinear(Pt p1, Pt p2, Pt q1, Pt q2) {
  final q1inP = _inEnv(p1, p2, q1), q2inP = _inEnv(p1, p2, q2), p1inQ = _inEnv(q1, q2, p1), p2inQ = _inEnv(q1, q2, p2);
  if (q1inP && q2inP) return LineHit(2, q1);
  if (p1inQ && p2inQ) return LineHit(2, p1);
  if (q1inP && p1inQ) return LineHit(q1.same(p1) && !q2inP && !p2inQ ? 1 : 2, q1);
  if (q1inP && p2inQ) return LineHit(q1.same(p2) && !q2inP && !p1inQ ? 1 : 2, q1);
  if (q2inP && p1inQ) return LineHit(q2.same(p1) && !q1inP && !p2inQ ? 1 : 2, q2);
  if (q2inP && p2inQ) return LineHit(q2.same(p2) && !q1inP && !p1inQ ? 1 : 2, q2);
  return const LineHit(0, null);
}

Pt _nearestEndpoint(Pt p1, Pt p2, Pt q1, Pt q2) {
  var nearest = p1;
  var min = _pointToSegment(p1, q1, q2);
  void check(Pt p, double d) {
    if (d < min) {
      min = d;
      nearest = p;
    }
  }

  check(p2, _pointToSegment(p2, q1, q2));
  check(q1, _pointToSegment(q1, p1, p2));
  check(q2, _pointToSegment(q2, p1, p2));
  return nearest;
}

// Double-double (`geos::math::DD`), só para os predicados e a interseção.

typedef _DD = (double, double);

const double _split = 134217729.0;

_DD _add2(_DD x, _DD y) {
  final (hi, lo) = x;
  final (yhi, ylo) = y;
  final s0 = hi + yhi, t0 = lo + ylo;
  var e = s0 - hi;
  final f = t0 - lo;
  var s = s0 - e, t = t0 - f;
  s = (yhi - e) + (hi - s);
  t = (ylo - f) + (lo - t);
  e = s + t0;
  final h0 = s0 + e;
  final h1 = e + (s0 - h0);
  e = t + h1;
  final z = h0 + e;
  return (z, e + (h0 - z));
}

_DD _neg(_DD x) => (-x.$1, -x.$2);
_DD _sub(_DD x, _DD y) => _add2(x, _neg(y));

_DD _mul(_DD x, _DD y) {
  final (hi, lo) = x;
  final (yhi, ylo) = y;
  var cc = _split * hi;
  var hx = cc - hi;
  var c = _split * yhi;
  hx = cc - hx;
  final tx = hi - hx;
  var hy = c - yhi;
  cc = hi * yhi;
  hy = c - hy;
  final ty = yhi - hy;
  c = ((((hx * hy - cc) + hx * ty) + tx * hy) + tx * ty) + (hi * ylo + lo * yhi);
  final z = cc + c;
  return (z, c + (cc - z));
}

_DD _div(_DD x, _DD y) {
  final (hi, lo) = x;
  final (yhi, ylo) = y;
  final cc = hi / yhi;
  var c = _split * cc;
  var hc = c - cc;
  var u = _split * yhi;
  hc = c - hc;
  final tc = cc - hc;
  var hy = u - yhi;
  final uu = cc * yhi;
  hy = u - hy;
  final ty = yhi - hy;
  u = (((hc * hy - uu) + hc * ty) + tc * hy) + tc * ty;
  c = (((hi - uu) - u) + lo - cc * ylo) / yhi;
  u = cc + c;
  return (u, (cc - u) + c);
}

/// `Orientation::index`: 1 anti-horário, -1 horário, 0 colinear.
int orientationIndex(Pt p1, Pt p2, Pt q) {
  final detLeft = (p1.x - q.x) * (p2.y - q.y), detRight = (p1.y - q.y) * (p2.x - q.x);
  final det = detLeft - detRight;
  double detSum;
  if (detLeft > 0) {
    if (detRight <= 0) return det.sign.toInt();
    detSum = detLeft + detRight;
  } else if (detLeft < 0) {
    if (detRight >= 0) return det.sign.toInt();
    detSum = -detLeft - detRight;
  } else {
    return det.sign.toInt();
  }
  final err = 1e-15 * detSum;
  if (det >= err || -det >= err) return det.sign.toInt();
  final dx1 = _add2((p2.x, 0), (-p1.x, 0)), dy1 = _add2((p2.y, 0), (-p1.y, 0));
  final dx2 = _add2((q.x, 0), (-p2.x, 0)), dy2 = _add2((q.y, 0), (-p2.y, 0));
  final d = _sub(_mul(dx1, dy2), _mul(dy1, dx2));
  if (d.$1 > 0 || (d.$1 == 0 && d.$2 > 0)) return 1;
  if (d.$1 < 0 || (d.$1 == 0 && d.$2 < 0)) return -1;
  return 0;
}

Pt? _intersection(Pt p1, Pt p2, Pt q1, Pt q2) {
  _DD dd(double v) => (v, 0.0);
  final p1x = dd(p1.x), p1y = dd(p1.y), p2x = dd(p2.x), p2y = dd(p2.y);
  final q1x = dd(q1.x), q1y = dd(q1.y), q2x = dd(q2.x), q2y = dd(q2.y);
  final px = _sub(p1y, p2y), py = _sub(p2x, p1x), pw = _sub(_mul(p1x, p2y), _mul(p2x, p1y));
  final qx = _sub(q1y, q2y), qy = _sub(q2x, q1x), qw = _sub(_mul(q1x, q2y), _mul(q2x, q1y));
  final x = _sub(_mul(py, qw), _mul(qy, pw));
  final y = _sub(_mul(qx, pw), _mul(px, qw));
  final w = _sub(_mul(px, qy), _mul(qx, py));
  final rx = _div(x, w), ry = _div(y, w);
  final ix = rx.$1 + rx.$2, iy = ry.$1 + ry.$2;
  if (!ix.isFinite || !iy.isFinite) return null;
  return Pt(ix, iy);
}
