/// A rota do Modo Viagem: A* sobre o grafo de ruas do pacote visual, no aparelho. Só desenho e bônus individual: nada aqui
/// decide o que existe no mundo. Dart puro.
library;

import 'dart:math' as math;

import '../core/pcg32.dart';
import '../data/map_sources.dart' show NoWalkSource, RouteAccessSource, kAccessBike, kAccessBridge, kAccessFoot, kAccessMotor;
import '../data/visual_pack.dart' show OneWay;
import '../world/traffic_graph.dart';

/// Uma linha no mundo, em células z21, com a distância acumulada em metros.
class TravelPath {
  TravelPath(this.xy, double mpc, {this.dashFrom}) : cum = _cumulative(xy, mpc), _mpc = mpc;

  /// A reta entre dois pontos: o que sobra quando não há rua.
  factory TravelPath.straight(double x0, double y0, double x1, double y1, double mpc) => TravelPath([x0, y0, x1, y1], mpc);

  /// Pontos `x0, y0, x1, y1, ...` em células.
  final List<double> xy;

  /// Metros acumulados até cada ponto.
  final List<double> cum;
  final double _mpc;

  /// O destino está fora dos dados: do ponto deste índice em diante a linha é reta, tracejada, e a tela avisa. `null`:
  /// pelas ruas até o fim.
  final int? dashFrom;

  bool get offData => dashFrom != null;

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
  double distanceToM(double x, double y) => locate(x, y).offM;

  /// O ponto da linha mais perto de ([x], [y]): a quantos metros do começo ele fica e a quantos metros dele está o ponto.
  ({double alongM, double offM}) locate(double x, double y) {
    var best = double.infinity, along = 0.0;
    for (var i = 0; i + 3 < xy.length; i += 2) {
      final ax = xy[i], ay = xy[i + 1], dx = xy[i + 2] - ax, dy = xy[i + 3] - ay;
      final len = dx * dx + dy * dy;
      final t = len <= 0 ? 0.0 : (((x - ax) * dx + (y - ay) * dy) / len).clamp(0.0, 1.0);
      final d = _hypot(ax + dx * t - x, ay + dy * t - y);
      if (d < best) {
        best = d;
        along = cum[i ~/ 2] + (cum[i ~/ 2 + 1] - cum[i ~/ 2]) * t;
      }
    }
    return (alongM: along, offM: best * _mpc);
  }
}

double _hypot(double a, double b) => math.sqrt(a * a + b * b);

/// Quem anda, para a rota: a pé (calçadas, caminhos e escadas; ignora a mão), de bicicleta (ciclovias e ruas; respeita a
/// mão, fora das rodovias, das escadas e das calçadas sem `bicycle`) ou motorizado (moto, carro e ônibus: respeita a mão,
/// fora dos caminhos de pedestre). O bit é o de fechado no arquivo de rota.
enum RouteProfile {
  foot(kAccessFoot),
  bike(kAccessBike),
  motor(kAccessMotor);

  const RouteProfile(this.closedBit);

  final int closedBit;
}

/// Quem pode passar por onde.
class RouteRules {
  const RouteRules(this.profile, {this.highway, this.access});

  final RouteProfile profile;

  /// Se a linha é rodovia ou via expressa. `null`: não há dado, nenhuma é.
  final bool Function(GhostLine)? highway;

  /// Os bits de acesso do trecho que vai do vértice `seg` ao seguinte (`accessTest`). `null`: sem o arquivo de rota, tudo
  /// aberto.
  final int Function(GhostLine l, int seg)? access;

  bool get motorized => profile == RouteProfile.motor;

  bool allows(GhostLine l) => motorized ? !l.isPedestrian : !(highway?.call(l) ?? false);

  bool _open(GhostLine l, int seg) => ((access?.call(l, seg) ?? 0) & profile.closedBit) == 0;

  /// Do vértice [v] para o seguinte.
  bool forward(GhostLine l, int v) => (profile == RouteProfile.foot || l.oneway != OneWay.reverse) && _open(l, v);

  /// Do vértice [v] para o anterior.
  bool backward(GhostLine l, int v) => (profile == RouteProfile.foot || l.oneway != OneWay.forward) && _open(l, v - 1);
}

/// Os bits de acesso de cada trecho, com memória: os de fechado valem se os três pontos de dentro do trecho (a um quarto, na
/// metade e a três quartos) estão a até [tolCells] de uma via com aquele bit. Três pontos, para a rua que só cruza uma via
/// fechada (ou passa por baixo de um viaduto) não fechar junto.
int Function(GhostLine, int) accessTest(RouteAccessSource source, double tolCells) {
  final memo = <(int, int, int, int), int>{};
  return (l, seg) => memo[(l.key.$1, l.key.$2, l.key.$3, seg)] ??= _segmentBits(l, seg, source, tolCells);
}

/// Onde dois trechos que se cruzam sem vértice comum não viram esquina: perto de um viaduto (`TrafficGraph.noCrossingAt`).
bool Function(double x, double y) bridgeTest(RouteAccessSource source, double tolCells) =>
    (x, y) => _bitsAt(x, y, source, tolCells) & kAccessBridge != 0;

int _segmentBits(GhostLine l, int seg, RouteAccessSource source, double tol) {
  final ax = l.xy[2 * seg], ay = l.xy[2 * seg + 1], bx = l.xy[2 * seg + 2], by = l.xy[2 * seg + 3];
  var bits = -1;
  for (final t in const [0.25, 0.5, 0.75]) {
    bits &= _bitsAt(ax + (bx - ax) * t, ay + (by - ay) * t, source, tol);
    if (bits == 0) break;
  }
  return bits & ~kAccessBridge;
}

int _bitsAt(double x, double y, RouteAccessSource source, double tol) {
  final near = source.accessNear((x / 2).floor(), (y / 2).floor());
  var bits = 0;
  for (var k = 0; k + 4 < near.length; k += 5) {
    final ax = near[k], ay = near[k + 1], dx = near[k + 2] - ax, dy = near[k + 3] - ay;
    final len = dx * dx + dy * dy;
    final t = len <= 0 ? 0.0 : (((x - ax) * dx + (y - ay) * dy) / len).clamp(0.0, 1.0);
    if (_hypot(ax + dx * t - x, ay + dy * t - y) <= tol) bits |= near[k + 4].toInt();
  }
  return bits;
}

/// Devolve o teste de rodovia sobre [source], com memória por linha: o meio de algum trecho da linha a até [tolCells] de
/// uma via bloqueada. A mesma regra de `WalkPaths`, que tira esses trechos dos caminhos andáveis.
bool Function(GhostLine) highwayTest(NoWalkSource source, double tolCells) {
  final memo = <(int, int, int), bool>{};
  return (l) => memo[l.key] ??= _nearBlocked(l, source, tolCells);
}

bool _nearBlocked(GhostLine l, NoWalkSource source, double tol) {
  for (var i = 0; i + 3 < l.xy.length; i += 2) {
    final mx = (l.xy[i] + l.xy[i + 2]) / 2, my = (l.xy[i + 1] + l.xy[i + 3]) / 2;
    final near = source.near((mx / 2).floor(), (my / 2).floor());
    for (var k = 0; k + 3 < near.length; k += 4) {
      final ax = near[k], ay = near[k + 1], dx = near[k + 2] - ax, dy = near[k + 3] - ay;
      final len = dx * dx + dy * dy;
      final t = len <= 0 ? 0.0 : (((mx - ax) * dx + (my - ay) * dy) / len).clamp(0.0, 1.0);
      if (_hypot(ax + dx * t - mx, ay + dy * t - my) <= tol) return true;
    }
  }
  return false;
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

/// Um ponto em cima de uma rua: a linha, o trecho (do vértice `seg` ao seguinte), a fração dele e a posição em células.
typedef StreetPoint = ({GhostLine line, int seg, double t, double x, double y});

/// O ponto de rua mais perto de ([x], [y]) a até [maxCells], num trecho que [rules] deixa andar em algum sentido.
StreetPoint? nearestStreetPoint(TrafficGraph g, double x, double y, double maxCells, RouteRules rules) {
  final n = g.cellsPerTile;
  StreetPoint? best;
  var bestD = maxCells;
  for (var tx = ((x - maxCells) / n).floor(); tx <= ((x + maxCells) / n).floor(); tx++) {
    for (var ty = ((y - maxCells) / n).floor(); ty <= ((y + maxCells) / n).floor(); ty++) {
      for (final l in g.linesOfTile(tx, ty)) {
        if (!rules.allows(l) || l.minX > x + bestD || l.maxX < x - bestD || l.minY > y + bestD || l.maxY < y - bestD) continue;
        for (var s = 0; s + 1 < l.vertexCount; s++) {
          final ax = l.xy[2 * s], ay = l.xy[2 * s + 1], dx = l.xy[2 * s + 2] - ax, dy = l.xy[2 * s + 3] - ay;
          final len = dx * dx + dy * dy;
          final t = len <= 0 ? 0.0 : (((x - ax) * dx + (y - ay) * dy) / len).clamp(0.0, 1.0);
          final px = ax + dx * t, py = ay + dy * t;
          final d = _hypot(px - x, py - y);
          if (d >= bestD || !(rules.forward(l, s) || rules.backward(l, s + 1))) continue;
          bestD = d;
          best = (line: l, seg: s, t: t, x: px, y: py);
        }
      }
    }
  }
  return best;
}

/// O destino está fora dos dados: o ponto de rua mais perto dele, procurado da beira do destino para a origem, de
/// [stepCells] em [stepCells]. `null`: não há rua no caminho todo.
StreetPoint? dataEdgeToward(TrafficGraph g, double fromX, double fromY, double toX, double toY, double snapCells, RouteRules rules, {double stepCells = 8}) {
  final d = _hypot(toX - fromX, toY - fromY);
  final steps = (d / stepCells).ceil();
  for (var i = 1; i <= steps; i++) {
    final f = math.min(1.0, i * stepCells / d);
    final p = nearestStreetPoint(g, toX + (fromX - toX) * f, toY + (fromY - toY) * f, snapCells, rules);
    if (p != null) return p;
  }
  return null;
}

typedef _Key = (int, int, int, int);

/// As pontas da busca: o ponto de rua da origem e o do destino, fora dos vértices do grafo.
const _Key _startKey = (-1, -1, -1, 0), _goalKey = (-1, -1, -1, 1);

class _Node {
  _Node(this.x, this.y, this.g, this.parent, this.line, this.v);

  final double x, y;
  double g;
  _Key? parent;
  final GhostLine line;

  /// O vértice na linha; `-1` nas pontas.
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

/// Uma busca A* que anda em fatias, para a rota longa não travar a tela. A origem e o destino entram no ponto de rua mais
/// perto (a até [snapM]), no meio do trecho. Destino sem rua perto: a rota vai até a beira dos dados na direção dele
/// ([dataEdgeToward]) e o resto é reta ([TravelPath.dashFrom]). Sem caminho, sem rua perto da origem ou passando do teto de
/// nós, [result] fica `null`: quem chama desenha a reta.
class RouteSearch {
  RouteSearch(this.graph, {required this.fromX, required this.fromY, required this.toX, required this.toY, required this.rules, required this.mpc, required this.snapM, required this.maxNodes}) {
    final snap = snapM / mpc;
    final a = nearestStreetPoint(graph, fromX, fromY, snap, rules);
    var b = nearestStreetPoint(graph, toX, toY, snap, rules);
    if (a != null && b == null) {
      b = dataEdgeToward(graph, fromX, fromY, toX, toY, snap, rules);
      offData = b != null;
    }
    if (a == null || b == null) {
      done = true;
      return;
    }
    _goal = b;
    _gx = b.x;
    _gy = b.y;
    final n = _Node(a.x, a.y, 0, null, a.line, -1);
    _nodes[_startKey] = n;
    _open.push(_h(n.x, n.y), _startKey);
    _start = a;
  }

  final TrafficGraph graph;
  final double fromX, fromY, toX, toY;
  final RouteRules rules;
  final double mpc;
  final double snapM;
  final int maxNodes;

  bool done = false;
  TravelPath? result;

  /// O destino não tem rua perto: a rota acaba na beira dos dados.
  bool offData = false;

  /// Os vértices da rota, em ordem, sem as pontas: dois seguidos na mesma linha são um trecho dela; em linhas diferentes,
  /// a esquina.
  final List<LineVertex> vertices = [];

  final _nodes = <_Key, _Node>{};
  final _open = _Open();
  late final StreetPoint _goal;
  late final StreetPoint _start;
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
      if (k == _goalKey) {
        result = _build();
        done = true;
        break;
      }
      _expand(k, n);
    }
    return done;
  }

  void _relaxTo(_Key from, _Node n, _Key k, double x, double y, GhostLine l, int v) {
    final g = n.g + _hypot(x - n.x, y - n.y) * mpc;
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

  void _relax(_Key from, _Node n, GhostLine l, int v) => _relaxTo(from, n, _key(l, v), l.xy[2 * v], l.xy[2 * v + 1], l, v);

  void _relaxGoal(_Key from, _Node n) => _relaxTo(from, n, _goalKey, _goal.x, _goal.y, _goal.line, -1);

  bool _onGoalLine(GhostLine l) => l.key == _goal.line.key;

  void _expand(_Key k, _Node n) {
    if (k == _startKey) {
      final a = _start;
      if (a.line.key == _goal.line.key && a.seg == _goal.seg && (_goal.t >= a.t ? rules.forward(a.line, a.seg) : rules.backward(a.line, a.seg + 1))) {
        _relaxGoal(k, n); // o destino no mesmo trecho, no sentido que vale
      }
      if (rules.forward(a.line, a.seg)) _relax(k, n, a.line, a.seg + 1);
      if (rules.backward(a.line, a.seg + 1)) _relax(k, n, a.line, a.seg);
      return;
    }
    final l = n.line, v = n.v;
    if (_onGoalLine(l)) {
      if (v == _goal.seg && rules.forward(l, v)) _relaxGoal(k, n);
      if (v == _goal.seg + 1 && rules.backward(l, v)) _relaxGoal(k, n);
    }
    if (v + 1 < l.vertexCount && rules.forward(l, v)) _relax(k, n, l, v + 1);
    if (v > 0 && rules.backward(l, v)) _relax(k, n, l, v - 1);
    for (final (other, i) in graph.joinsAt(n.x, n.y, exclude: l)) {
      if (rules.allows(other)) _relax(k, n, other, i);
    }
  }

  TravelPath _build() {
    final back = <double>[toX, toY];
    _Key? k = _goalKey;
    while (k != null) {
      final n = _nodes[k]!;
      if (n.v >= 0) vertices.add((n.line, n.v));
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
    final rev = vertices.reversed.toList();
    vertices
      ..clear()
      ..addAll(rev);
    return TravelPath(xy, mpc, dashFrom: offData ? xy.length ~/ 2 - 2 : null);
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
    final r = await findRouteAsync(graph, fromX: sx, fromY: sy, toX: px, toY: py, rules: const RouteRules(RouteProfile.motor), mpc: mpc, snapM: snapM, maxNodes: maxNodes, sliceNodes: sliceNodes);
    if (r != null) return r;
  }
  return fallback!;
}

/// O caminho de quem vai embora de ([x], [y]) na direção [heading]: segue a rua mais alinhada até passar de [lengthM]. Sem
/// rua por perto, a reta.
TravelPath leavePath(TrafficGraph graph, double x, double y, double heading, double lengthM, {required double mpc, required double snapM}) {
  const rules = RouteRules(RouteProfile.motor);
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
    if (i + 1 < l.vertexCount && rules.forward(l, i)) {
      final c = _cos(l, i, i + 1, dx, dy);
      if (c > bestCos) {
        bestCos = c;
        best = (l, i, true);
      }
    }
    if (i > 0 && rules.backward(l, i)) {
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
