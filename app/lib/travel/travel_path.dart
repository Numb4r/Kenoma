/// A rota do Modo Viagem: A* sobre o grafo de ruas do pacote visual, no aparelho. Só desenho e bônus individual: nada aqui
/// decide o que existe no mundo. Dart puro.
library;

import 'dart:math' as math;

import '../core/pcg32.dart';
import '../data/visual_pack.dart' show OneWay;
import '../world/traffic_graph.dart';

/// Uma linha no mundo, em células z21, com a distância acumulada em metros.
class TravelPath {
  TravelPath(this.xy, double mpc) : cum = _cumulative(xy, mpc), _mpc = mpc;

  /// A reta entre dois pontos: o que sobra quando não há rua.
  factory TravelPath.straight(double x0, double y0, double x1, double y1, double mpc) => TravelPath([x0, y0, x1, y1], mpc);

  /// Pontos `x0, y0, x1, y1, ...` em células.
  final List<double> xy;

  /// Metros acumulados até cada ponto.
  final List<double> cum;
  final double _mpc;

  double get lengthM => cum.last;
  int get pointCount => xy.length ~/ 2;

  static List<double> _cumulative(List<double> xy, double mpc) {
    final out = <double>[0];
    for (var i = 2; i < xy.length; i += 2) {
      out.add(out.last + _hypot(xy[i] - xy[i - 2], xy[i + 1] - xy[i - 1]) * mpc);
    }
    return out;
  }

  /// Posição (células) e direção (rad) a [s] metros do começo. Depois do fim, para no fim.
  ({double x, double y, double heading}) at(double s) {
    final c = s.clamp(0.0, lengthM);
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
    final ax = xy[2 * lo], ay = xy[2 * lo + 1], bx = xy[2 * hi], by = xy[2 * hi + 1];
    return (x: ax + (bx - ax) * t, y: ay + (by - ay) * t, heading: math.atan2(by - ay, bx - ax));
  }

  /// Metros de ([x], [y]) até o ponto mais perto da linha.
  double distanceToM(double x, double y) {
    var best = double.infinity;
    for (var i = 0; i + 3 < xy.length; i += 2) {
      final ax = xy[i], ay = xy[i + 1], dx = xy[i + 2] - ax, dy = xy[i + 3] - ay;
      final len = dx * dx + dy * dy;
      final t = len <= 0 ? 0.0 : (((x - ax) * dx + (y - ay) * dy) / len).clamp(0.0, 1.0);
      best = math.min(best, _hypot(ax + dx * t - x, ay + dy * t - y));
    }
    return best * _mpc;
  }
}

double _hypot(double a, double b) => math.sqrt(a * a + b * b);

/// Quem pode passar por onde.
class RouteRules {
  const RouteRules({required this.motorized});

  /// Motorizado respeita a mão única e fica fora dos caminhos de pedestre. A pé e de bicicleta vale tudo.
  final bool motorized;

  bool allows(GhostLine l) => !motorized || !l.isPedestrian;
  bool forward(GhostLine l) => !motorized || l.oneway != OneWay.reverse;
  bool backward(GhostLine l) => !motorized || l.oneway != OneWay.forward;
}

typedef _Key = (int, int, int, int);

class _Node {
  _Node(this.x, this.y, this.g, this.parent, this.line, this.v);

  final double x, y;
  double g;
  _Key? parent;
  final GhostLine line;
  final int v;
  bool closed = false;
}

/// Fila de prioridade (heap binário) por `f`.
class _Open {
  final _f = <double>[];
  final _k = <_Key>[];

  bool get isEmpty => _f.isEmpty;

  void push(double f, _Key k) {
    _f.add(f);
    _k.add(k);
    var i = _f.length - 1;
    while (i > 0) {
      final p = (i - 1) ~/ 2;
      if (_f[p] <= _f[i]) break;
      _swap(i, p);
      i = p;
    }
  }

  _Key pop() {
    final top = _k.first;
    final lastF = _f.removeLast(), lastK = _k.removeLast();
    if (_f.isNotEmpty) {
      _f[0] = lastF;
      _k[0] = lastK;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < _f.length && _f[l] < _f[m]) m = l;
        if (r < _f.length && _f[r] < _f[m]) m = r;
        if (m == i) break;
        _swap(i, m);
        i = m;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final f = _f[a], k = _k[a];
    _f[a] = _f[b];
    _k[a] = _k[b];
    _f[b] = f;
    _k[b] = k;
  }
}

/// A rua mais perto de ([x], [y]) a até [maxCells]: o vértice e a linha.
LineVertex? nearestVertex(TrafficGraph g, double x, double y, double maxCells, RouteRules rules) {
  final n = g.cellsPerTile;
  LineVertex? best;
  var bestD = maxCells;
  for (var tx = ((x - maxCells) / n).floor(); tx <= ((x + maxCells) / n).floor(); tx++) {
    for (var ty = ((y - maxCells) / n).floor(); ty <= ((y + maxCells) / n).floor(); ty++) {
      for (final l in g.linesOfTile(tx, ty)) {
        if (!rules.allows(l)) continue;
        for (var v = 0; v < l.vertexCount; v++) {
          final d = _hypot(l.xy[2 * v] - x, l.xy[2 * v + 1] - y);
          if (d < bestD) {
            bestD = d;
            best = (l, v);
          }
        }
      }
    }
  }
  return best;
}

/// Uma busca A* que anda em fatias, para a rota longa não travar a tela. Sem caminho, sem rua perto das pontas ou
/// passando do teto de nós, [result] fica `null`: quem chama desenha a reta.
class RouteSearch {
  RouteSearch(this.graph, {required this.fromX, required this.fromY, required this.toX, required this.toY, required this.rules, required this.mpc, required this.snapM, required this.maxNodes}) {
    final snap = snapM / mpc;
    final a = nearestVertex(graph, fromX, fromY, snap, rules);
    final b = nearestVertex(graph, toX, toY, snap, rules);
    if (a == null || b == null) {
      done = true;
      return;
    }
    _goal = _key(b.$1, b.$2);
    _gx = b.$1.xy[2 * b.$2];
    _gy = b.$1.xy[2 * b.$2 + 1];
    final k = _key(a.$1, a.$2);
    final n = _Node(a.$1.xy[2 * a.$2], a.$1.xy[2 * a.$2 + 1], 0, null, a.$1, a.$2);
    _nodes[k] = n;
    _open.push(_h(n.x, n.y), k);
  }

  final TrafficGraph graph;
  final double fromX, fromY, toX, toY;
  final RouteRules rules;
  final double mpc;
  final double snapM;
  final int maxNodes;

  bool done = false;
  TravelPath? result;

  final _nodes = <_Key, _Node>{};
  final _open = _Open();
  late final _Key _goal;
  double _gx = 0, _gy = 0;
  int _expanded = 0;

  static _Key _key(GhostLine l, int v) => (l.key.$1, l.key.$2, l.key.$3, v);

  double _h(double x, double y) => _hypot(x - _gx, y - _gy) * mpc;

  /// Expande até [budget] nós. Devolve `true` quando a busca acabou.
  bool step(int budget) {
    for (var i = 0; i < budget && !done; i++) {
      if (_open.isEmpty || _expanded >= maxNodes) {
        done = true;
        break;
      }
      final k = _open.pop();
      final n = _nodes[k]!;
      if (n.closed) continue;
      n.closed = true;
      _expanded++;
      if (k == _goal) {
        result = _build(k);
        done = true;
        break;
      }
      _expand(k, n);
    }
    return done;
  }

  void _relax(_Key from, _Node n, GhostLine l, int v) {
    final x = l.xy[2 * v], y = l.xy[2 * v + 1];
    final g = n.g + _hypot(x - n.x, y - n.y) * mpc;
    final k = _key(l, v);
    final old = _nodes[k];
    if (old != null) {
      if (old.closed || g >= old.g) return;
      old
        ..g = g
        ..parent = from;
    } else {
      _nodes[k] = _Node(x, y, g, from, l, v);
    }
    _open.push(g + _h(x, y), k);
  }

  void _expand(_Key k, _Node n) {
    final l = n.line, v = n.v;
    if (v + 1 < l.vertexCount && rules.forward(l)) _relax(k, n, l, v + 1);
    if (v > 0 && rules.backward(l)) _relax(k, n, l, v - 1);
    for (final (other, i) in graph.joinsAt(n.x, n.y, exclude: l)) {
      if (rules.allows(other)) _relax(k, n, other, i);
    }
  }

  TravelPath _build(_Key end) {
    final back = <double>[toX, toY];
    _Key? k = end;
    while (k != null) {
      final n = _nodes[k]!;
      back
        ..add(n.x)
        ..add(n.y);
      k = n.parent;
    }
    back
      ..add(fromX)
      ..add(fromY);
    final xy = <double>[];
    for (var i = back.length - 2; i >= 0; i -= 2) {
      xy
        ..add(back[i])
        ..add(back[i + 1]);
    }
    return TravelPath(xy, mpc);
  }
}

/// A rota de uma vez (testes e caminhos curtos). `null`: sem rota.
TravelPath? findRoute(
  TrafficGraph graph, {
  required double fromX,
  required double fromY,
  required double toX,
  required double toY,
  required RouteRules rules,
  required double mpc,
  required double snapM,
  required int maxNodes,
}) {
  final s = RouteSearch(graph, fromX: fromX, fromY: fromY, toX: toX, toY: toY, rules: rules, mpc: mpc, snapM: snapM, maxNodes: maxNodes);
  while (!s.step(maxNodes)) {}
  return s.result;
}

/// A mesma rota em fatias de [sliceNodes] nós, devolvendo o controle ao laço de eventos entre elas.
Future<TravelPath?> findRouteAsync(
  TrafficGraph graph, {
  required double fromX,
  required double fromY,
  required double toX,
  required double toY,
  required RouteRules rules,
  required double mpc,
  required double snapM,
  required int maxNodes,
  required int sliceNodes,
}) async {
  final s = RouteSearch(graph, fromX: fromX, fromY: fromY, toX: toX, toY: toY, rules: rules, mpc: mpc, snapM: snapM, maxNodes: maxNodes);
  while (!s.step(sliceNodes)) {
    await Future<void>.delayed(Duration.zero);
  }
  return s.result;
}

/// O caminho do carro da corrida até o jogador: um ponto a [distM] metros, numa direção tirada de [rng], e a rota de lá até
/// ([px], [py]). Tenta [tries] direções; sem rua em nenhuma, a reta da primeira.
Future<TravelPath> approachPath(
  TrafficGraph graph,
  Pcg32 rng, {
  required double px,
  required double py,
  required double distM,
  required double mpc,
  required double snapM,
  required int maxNodes,
  required int sliceNodes,
  required int tries,
}) async {
  TravelPath? fallback;
  for (var i = 0; i < tries; i++) {
    final a = rng.nextFloat() * 2 * math.pi;
    final sx = px + math.cos(a) * distM / mpc, sy = py + math.sin(a) * distM / mpc;
    fallback ??= TravelPath.straight(sx, sy, px, py, mpc);
    final r = await findRouteAsync(graph, fromX: sx, fromY: sy, toX: px, toY: py, rules: const RouteRules(motorized: true), mpc: mpc, snapM: snapM, maxNodes: maxNodes, sliceNodes: sliceNodes);
    if (r != null) return r;
  }
  return fallback!;
}

/// O caminho de quem vai embora de ([x], [y]) na direção [heading]: segue a rua mais alinhada até passar de [lengthM]. Sem
/// rua por perto, a reta.
TravelPath leavePath(TrafficGraph graph, double x, double y, double heading, double lengthM, {required double mpc, required double snapM}) {
  const rules = RouteRules(motorized: true);
  final hx = math.cos(heading), hy = math.sin(heading);
  TravelPath straight() => TravelPath.straight(x, y, x + hx * lengthM / mpc, y + hy * lengthM / mpc, mpc);
  final start = nearestVertex(graph, x, y, snapM / mpc, rules);
  if (start == null) return straight();
  final xy = <double>[x, y];
  var walked = 0.0;
  var dirX = hx, dirY = hy;
  var line = start.$1, v = start.$2;
  for (var hop = 0; hop < 32 && walked < lengthM; hop++) {
    final step = _bestStep(line, v, dirX, dirY, rules, graph);
    if (step == null) break;
    line = step.$1;
    v = step.$2;
    final fwd = step.$3;
    for (var i = v; fwd ? i < line.vertexCount : i >= 0; i += fwd ? 1 : -1) {
      final px = line.xy[2 * i], py = line.xy[2 * i + 1];
      final d = _hypot(px - xy[xy.length - 2], py - xy[xy.length - 1]);
      if (d <= 0) continue;
      dirX = (px - xy[xy.length - 2]) / d;
      dirY = (py - xy[xy.length - 1]) / d;
      xy
        ..add(px)
        ..add(py);
      walked += d * mpc;
      v = i;
      if (walked >= lengthM) break;
    }
  }
  return xy.length < 4 ? straight() : TravelPath(xy, mpc);
}

/// Das ruas que passam pelo vértice, a mais alinhada com a direção de agora: linha, vértice e se vai para a frente.
(GhostLine, int, bool)? _bestStep(GhostLine line, int v, double dx, double dy, RouteRules rules, TrafficGraph graph) {
  final px = line.xy[2 * v], py = line.xy[2 * v + 1];
  (GhostLine, int, bool)? best;
  var bestCos = -0.2; // nada de voltar pelo mesmo caminho
  void consider(GhostLine l, int i) {
    if (!rules.allows(l)) return;
    if (i + 1 < l.vertexCount && rules.forward(l)) {
      final c = _cos(l, i, i + 1, dx, dy);
      if (c > bestCos) {
        bestCos = c;
        best = (l, i, true);
      }
    }
    if (i > 0 && rules.backward(l)) {
      final c = _cos(l, i, i - 1, dx, dy);
      if (c > bestCos) {
        bestCos = c;
        best = (l, i, false);
      }
    }
  }

  consider(line, v);
  for (final (l, i) in graph.joinsAt(px, py, exclude: line)) {
    consider(l, i);
  }
  return best;
}

double _cos(GhostLine l, int a, int b, double dx, double dy) {
  final x = l.xy[2 * b] - l.xy[2 * a], y = l.xy[2 * b + 1] - l.xy[2 * a + 1];
  final d = _hypot(x, y);
  return d <= 0 ? -1 : (x * dx + y * dy) / d;
}
