/// O caminho de um fantasma do Tráfego do Véu: a sequência de ruas que ele percorre, deslocada para a pista ou
/// a calçada, com as quinas arredondadas e um perfil de velocidade que freia antes das curvas fechadas. Dart puro.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../core/fnv.dart';
import '../data/visual_pack.dart';
import 'traffic_graph.dart';

/// Quem anda: o carro (e a moto) na pista; o passante na calçada; o ciclista só em caminho de pedestre.
enum RiderKind { car, walker, bike }

/// Raio das quinas, em metros.
double cornerRadiusM(RiderKind k) => switch (k) { RiderKind.car => 5.0, RiderKind.bike => 2.5, RiderKind.walker => 1.5 };

/// Quanto o passante fica além da borda da via, em metros: a meia largura mais isto é o deslocamento do eixo.
const double sidewalkExtraM = 1.5;

/// Curvas mais fechadas que isto (rad) fazem o carro frear.
const double _slowAngle = 0.5;
const int _maxLegs = 24;

class TrafficPath {
  TrafficPath._(this.xs, this.ys, this.cum, this.ks, this.kv, this.kt, this.length, this.duration);

  /// Pontos em células z21 e distância acumulada em metros.
  final Float64List xs, ys, cum;

  /// Perfil de velocidade linear por trechos: posição (m), velocidade (m/s) e instante (s) de cada nó.
  final Float64List ks, kv, kt;
  final double length;

  /// Quanto tempo o fantasma leva do começo ao fim.
  final double duration;

  /// Distância andada após [tau] segundos de viagem.
  double sAt(double tau) {
    if (tau <= 0) return 0;
    if (tau >= duration) return length;
    final j = _node(tau);
    final dt = tau - kt[j], va = kv[j], a = (kv[j + 1] - va) / (ks[j + 1] - ks[j]);
    if (a.abs() < 1e-9) return ks[j] + va * dt;
    return ks[j] + (va * math.exp(a * dt) - va) / a;
  }

  /// Velocidade (m/s) após [tau] segundos de viagem.
  double vAt(double tau) {
    final t = tau.clamp(0.0, duration);
    final j = _node(t);
    final dt = t - kt[j], va = kv[j], a = (kv[j + 1] - va) / (ks[j + 1] - ks[j]);
    return a.abs() < 1e-9 ? va : va * math.exp(a * dt);
  }

  int _node(double tau) {
    var lo = 0, hi = kt.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (kt[mid] <= tau) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Posição (células) e direção (rad) a [s] metros do começo.
  ({double x, double y, double heading}) at(double s) {
    final c = s.clamp(0.0, length);
    var lo = 0, hi = cum.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (cum[mid] <= c) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final seg = cum[hi] - cum[lo];
    final t = seg <= 0 ? 0.0 : (c - cum[lo]) / seg;
    return (x: xs[lo] + (xs[hi] - xs[lo]) * t, y: ys[lo] + (ys[hi] - ys[lo]) * t, heading: math.atan2(ys[hi] - ys[lo], xs[hi] - xs[lo]));
  }
}

typedef _Leg = ({GhostLine line, bool fwd, int from});

double _rand(int a, int b, int c) => (fnv1a64([a, b, c, saltTraf]) >>> 32) / 4294967296.0;

/// Constrói o caminho que começa em [start] (pela ponta [fromFirst]) e segue por ruas ligadas até passar de
/// [targetM] metros ou morrer num beco. Devolve `null` se o caminho ficou sem comprimento.
///
/// [side] (+1 direita, -1 esquerda) e [jitter] (-1 a 1) definem a calçada e o espalhamento nos caminhos de
/// pedestre. [pick] é o sorteio das bifurcações. [maxLifeS] corta o caminho se ele durar mais que isso.
TrafficPath? buildTrafficPath(
  TrafficGraph graph, {
  required GhostLine start,
  required bool fromFirst,
  required RiderKind kind,
  required double targetM,
  required int side,
  required double jitter,
  required int pick,
  required double speed,
  required double mpc,
  required double Function(RoadClass) widthM,
  required double maxLifeS,
}) {
  // 1. As ruas, em ordem de viagem: vértices e o deslocamento (m, + à direita) de cada trecho.
  final vx = <double>[], vy = <double>[];
  final off = <double>[];
  final legs = <_Leg>[];
  var line = start, fwd = fromFirst, from = fromFirst ? 0 : start.vertexCount - 1;
  var accM = 0.0;
  while (true) {
    legs.add((line: line, fwd: fwd, from: from));
    final n = line.vertexCount;
    final end = fwd ? n - 1 : 0;
    final o = _legOffset(line, kind, side, jitter, widthM);
    for (var i = from; i != end; i += fwd ? 1 : -1) {
      final j = i + (fwd ? 1 : -1);
      if (vx.isEmpty) {
        vx.add(line.xy[2 * i]);
        vy.add(line.xy[2 * i + 1]);
      }
      vx.add(line.xy[2 * j]);
      vy.add(line.xy[2 * j + 1]);
      off.add(o);
    }
    accM += (line.cum[end] - line.cum[from]).abs() * mpc;
    if (accM >= targetM || legs.length >= _maxLegs) break;
    final next = _nextLeg(graph, line, end, kind, pick, legs.length);
    if (next == null) break;
    line = next.line;
    fwd = next.fwd;
    from = next.from;
  }
  if (vx.length < 2) return null;
  // 2. Desloca cada trecho e emenda as quinas pela interseção das paralelas (ou em bisel nas curvas fechadas).
  final px = <double>[], py = <double>[];
  _offsetPolyline(vx, vy, off, mpc, px, py);
  // 3. Arredonda as quinas e anota as curvas fechadas.
  final rx = <double>[], ry = <double>[];
  final corners = <(int, double)>[];
  _round(px, py, cornerRadiusM(kind) / mpc, rx, ry, corners);
  final n = rx.length;
  final xs = Float64List.fromList(rx), ys = Float64List.fromList(ry), cum = Float64List(n);
  for (var i = 1; i < n; i++) {
    cum[i] = cum[i - 1] + math.sqrt(math.pow(xs[i] - xs[i - 1], 2) + math.pow(ys[i] - ys[i - 1], 2)) * mpc;
  }
  if (cum.last < 1) return null;
  return _withSpeed(xs, ys, cum, kind == RiderKind.walker ? const [] : [for (final c in corners) (cum[c.$1], c.$2)], speed, maxLifeS);
}

double _legOffset(GhostLine l, RiderKind kind, int side, double jitter, double Function(RoadClass) widthM) {
  final w = widthM(l.roadClass);
  switch (kind) {
    case RiderKind.car:
      return l.oneway == OneWay.twoWay ? w / 4 : 0;
    case RiderKind.walker:
    case RiderKind.bike:
      return l.isPedestrian ? jitter * 0.4 : side * (w / 2 + sidewalkExtraM);
  }
}

({GhostLine line, bool fwd, int from})? _nextLeg(TrafficGraph graph, GhostLine cur, int endIdx, RiderKind kind, int pick, int step) {
  final px = cur.xy[2 * endIdx], py = cur.xy[2 * endIdx + 1];
  final prev = endIdx == 0 ? 1 : endIdx - 1;
  var hx = px - cur.xy[2 * prev], hy = py - cur.xy[2 * prev + 1];
  final hn = math.sqrt(hx * hx + hy * hy);
  if (hn > 0) {
    hx /= hn;
    hy /= hn;
  }
  ({GhostLine line, bool fwd, int from})? best;
  var bestScore = -1.0, k = 0;
  for (final (l, v) in graph.joinsAt(px, py, exclude: cur)) {
    if (kind == RiderKind.car && l.isPedestrian) continue;
    if (kind == RiderKind.bike && !l.isPedestrian) continue;
    for (final fwd in const [true, false]) {
      if (fwd ? v >= l.vertexCount - 1 : v <= 0) continue;
      if (kind == RiderKind.car && (fwd ? l.oneway == OneWay.reverse : l.oneway == OneWay.forward)) continue;
      final nx = l.xy[2 * (fwd ? v + 1 : v - 1)] - l.xy[2 * v], ny = l.xy[2 * (fwd ? v + 1 : v - 1) + 1] - l.xy[2 * v + 1];
      final nn = math.sqrt(nx * nx + ny * ny);
      if (nn <= 0) continue;
      final cosA = (hx * nx + hy * ny) / nn;
      if (cosA < -0.8) continue; // nada de retorno em cima da própria rua
      final score = 0.5 * _rand(pick, step, k++) + 0.5 * (cosA + 1) / 2;
      if (score > bestScore) {
        bestScore = score;
        best = (line: l, fwd: fwd, from: v);
      }
    }
  }
  return best;
}

void _offsetPolyline(List<double> vx, List<double> vy, List<double> off, double mpc, List<double> px, List<double> py) {
  final m = vx.length - 1; // trechos
  final nx = List<double>.filled(m, 0), ny = List<double>.filled(m, 0);
  for (var i = 0; i < m; i++) {
    final dx = vx[i + 1] - vx[i], dy = vy[i + 1] - vy[i];
    final d = math.sqrt(dx * dx + dy * dy);
    // normal à direita de quem anda (y para baixo): (-dy, dx)
    nx[i] = d > 0 ? -dy / d : 0;
    ny[i] = d > 0 ? dx / d : 0;
  }
  void add(double x, double y) {
    px.add(x);
    py.add(y);
  }

  add(vx[0] + nx[0] * off[0] / mpc, vy[0] + ny[0] * off[0] / mpc);
  for (var i = 1; i < m; i++) {
    final o1 = off[i - 1] / mpc, o2 = off[i] / mpc;
    final det = nx[i - 1] * ny[i] - ny[i - 1] * nx[i];
    final dot = nx[i - 1] * nx[i] + ny[i - 1] * ny[i];
    if (det.abs() < 0.05 && dot > 0) {
      add(vx[i] + (nx[i - 1] * o1 + nx[i] * o2) / 2, vy[i] + (ny[i - 1] * o1 + ny[i] * o2) / 2);
      continue;
    }
    final dx = det.abs() < 1e-9 ? 0.0 : (o1 * ny[i] - o2 * ny[i - 1]) / det;
    final dy = det.abs() < 1e-9 ? 0.0 : (nx[i - 1] * o2 - nx[i] * o1) / det;
    final limit = 1.8 * math.max(o1.abs(), o2.abs()) + 0.5 / mpc;
    if (det.abs() >= 0.05 && math.sqrt(dx * dx + dy * dy) <= limit) {
      add(vx[i] + dx, vy[i] + dy);
    } else {
      add(vx[i] + nx[i - 1] * o1, vy[i] + ny[i - 1] * o1);
      add(vx[i] + nx[i] * o2, vy[i] + ny[i] * o2);
    }
  }
  add(vx[m] + nx[m - 1] * off[m - 1] / mpc, vy[m] + ny[m - 1] * off[m - 1] / mpc);
}

void _round(List<double> px, List<double> py, double r, List<double> ox, List<double> oy, List<(int, double)> corners) {
  ox.add(px[0]);
  oy.add(py[0]);
  for (var i = 1; i < px.length - 1; i++) {
    final ax = px[i] - px[i - 1], ay = py[i] - py[i - 1], bx = px[i + 1] - px[i], by = py[i + 1] - py[i];
    final la = math.sqrt(ax * ax + ay * ay), lb = math.sqrt(bx * bx + by * by);
    if (la < 1e-9 || lb < 1e-9) continue;
    final theta = math.acos(((ax * bx + ay * by) / (la * lb)).clamp(-1.0, 1.0));
    if (theta < 0.12) {
      ox.add(px[i]);
      oy.add(py[i]);
      continue;
    }
    final c = math.min(r, 0.45 * math.min(la, lb));
    final x0 = px[i] - ax / la * c, y0 = py[i] - ay / la * c, x1 = px[i] + bx / lb * c, y1 = py[i] + by / lb * c;
    final steps = (theta / 0.35).ceil().clamp(2, 6);
    for (var j = 0; j <= steps; j++) {
      final t = j / steps, u = 1 - t;
      ox.add(u * u * x0 + 2 * u * t * px[i] + t * t * x1);
      oy.add(u * u * y0 + 2 * u * t * py[i] + t * t * y1);
      if (j == steps ~/ 2 && theta >= _slowAngle) corners.add((ox.length - 1, theta));
    }
  }
  ox.add(px.last);
  oy.add(py.last);
}

TrafficPath _withSpeed(Float64List xs, Float64List ys, Float64List cum, List<(double, double)> corners, double v, double maxLifeS) {
  final ks = <double>[0], kv = <double>[v];
  void knot(double s, double speed) {
    if (s > ks.last + 0.05 && s < cum.last - 0.05) {
      ks.add(s);
      kv.add(speed);
    }
  }

  for (final (sc, theta) in corners) {
    final vc = math.max(math.min(v, 2.0), v * (1 - 0.9 * theta / math.pi));
    knot(sc - 9, v);
    knot(sc, vc);
    knot(sc + 3, v);
  }
  ks.add(cum.last);
  kv.add(v);
  final kt = <double>[0];
  for (var i = 0; i < ks.length - 1; i++) {
    final ds = ks[i + 1] - ks[i], va = kv[i], vb = kv[i + 1];
    kt.add(kt.last + ((vb - va).abs() < 1e-9 ? ds / va : ds * math.log(vb / va) / (vb - va)));
  }
  var path = TrafficPath._(xs, ys, cum, Float64List.fromList(ks), Float64List.fromList(kv), Float64List.fromList(kt), cum.last, kt.last);
  if (path.duration > maxLifeS) {
    // Viagem longa demais para o sorteio de janelas: corta o caminho onde o tempo acaba.
    final cut = path.sAt(maxLifeS);
    path = TrafficPath._(xs, ys, cum, path.ks, path.kv, path.kt, cut, maxLifeS);
  }
  return path;
}
