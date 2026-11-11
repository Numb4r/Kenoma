/// O grafo de faixas da simulação local do tráfego (docs/GDD.md, "Tráfego do Véu" e "Simulações do mundo"): do grafo de
/// ruas da rota ([TrafficGraph] com corte nas esquinas), cada trecho entre duas esquinas vira uma via com mão de direção,
/// faixas pela classe, as duas calçadas e, em cada esquina, o controle do OSM (semáforo, pare, dê a preferência, faixa de
/// pedestre). Dart puro. Só cenário: nada aqui decide spawn, coleta nem Aura, e pode diferir entre aparelhos.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../../data/traffic_pack.dart';
import '../../data/visual_pack.dart';
import '../traffic_graph.dart';
import 'traffic_sim_config.dart';

/// Uma polilinha percorrida por metro: a faixa de um sentido ou uma calçada. Pontos em células z21, distância em metros.
class Track {
  Track(this.xs, this.ys, this.cum);

  final Float64List xs, ys, cum;

  double get length => cum[cum.length - 1];

  /// Põe em [out] a posição (células) e a direção (rad) a [s] metros do começo. [hint] é o trecho da última consulta;
  /// devolve o trecho de agora.
  int at(double s, int hint, Float64List out) {
    final n = cum.length;
    var i = hint < 0 ? 0 : (hint > n - 2 ? n - 2 : hint);
    while (i > 0 && cum[i] > s) {
      i--;
    }
    while (i < n - 2 && cum[i + 1] < s) {
      i++;
    }
    final seg = cum[i + 1] - cum[i];
    final t = seg <= 0 ? 0.0 : ((s - cum[i]) / seg).clamp(0.0, 1.0);
    final dx = xs[i + 1] - xs[i], dy = ys[i + 1] - ys[i];
    out[0] = xs[i] + dx * t;
    out[1] = ys[i] + dy * t;
    out[2] = math.atan2(dy, dx);
    return i;
  }
}

/// O trecho de [from] a [to] metros da linha central ([xs], [ys] em células, [cum] em metros), deslocado [offsetM] para a
/// direita do sentido dos pontos (quinas em meia-esquadria) e, com [reversed], percorrido de trás para a frente.
Track offsetTrack(Float64List xs, Float64List ys, Float64List cum, double mpc, double from, double to, double offsetM, {bool reversed = false}) {
  final total = cum[cum.length - 1];
  var a = from.clamp(0.0, total), b = to.clamp(0.0, total);
  if (b - a < 0.2) {
    final mid = (a + b) / 2;
    a = math.max(0, mid - 0.1);
    b = math.min(total, mid + 0.1);
  }
  final px = <double>[], py = <double>[];
  void put(double s, int i) {
    final seg = cum[i + 1] - cum[i], t = seg <= 0 ? 0.0 : (s - cum[i]) / seg;
    px.add(xs[i] + (xs[i + 1] - xs[i]) * t);
    py.add(ys[i] + (ys[i + 1] - ys[i]) * t);
  }

  var i = 0;
  while (i < cum.length - 2 && cum[i + 1] <= a) {
    i++;
  }
  put(a, i);
  for (var k = i + 1; k < cum.length - 1 && cum[k] < b; k++) {
    if (cum[k] > a + 0.05 && cum[k] < b - 0.05) {
      px.add(xs[k]);
      py.add(ys[k]);
    }
    i = k;
  }
  while (i < cum.length - 2 && cum[i + 1] < b) {
    i++;
  }
  put(b, i);
  final n = px.length, off = offsetM / mpc;
  final ox = Float64List(n), oy = Float64List(n);
  for (var k = 0; k < n; k++) {
    // Direção de entrada e de saída do vértice; a normal é a média, esticada para manter a largura na quina.
    var ix = 0.0, iy = 0.0, jx = 0.0, jy = 0.0;
    if (k > 0) {
      ix = px[k] - px[k - 1];
      iy = py[k] - py[k - 1];
    }
    if (k < n - 1) {
      jx = px[k + 1] - px[k];
      jy = py[k + 1] - py[k];
    }
    final il = math.sqrt(ix * ix + iy * iy), jl = math.sqrt(jx * jx + jy * jy);
    if (il > 0) {
      ix /= il;
      iy /= il;
    }
    if (jl > 0) {
      jx /= jl;
      jy /= jl;
    }
    if (il <= 0) {
      ix = jx;
      iy = jy;
    }
    if (jl <= 0) {
      jx = ix;
      jy = iy;
    }
    var mx = ix + jx, my = iy + jy;
    final ml = math.sqrt(mx * mx + my * my);
    if (ml < 1e-6) {
      mx = ix;
      my = iy;
    } else {
      mx /= ml;
      my /= ml;
    }
    final cosHalf = math.max(0.5, mx * ix + my * iy); // quina fechada: no máximo o dobro
    ox[k] = px[k] - my * off / cosHalf;
    oy[k] = py[k] + mx * off / cosHalf;
  }
  final rx = Float64List(n), ry = Float64List(n), rc = Float64List(n);
  for (var k = 0; k < n; k++) {
    final s = reversed ? n - 1 - k : k;
    rx[k] = ox[s];
    ry[k] = oy[s];
    if (k > 0) {
      final dx = rx[k] - rx[k - 1], dy = ry[k] - ry[k - 1];
      rc[k] = rc[k - 1] + math.sqrt(dx * dx + dy * dy) * mpc;
    }
  }
  if (rc[n - 1] <= 0) rc[n - 1] = 0.01;
  return Track(rx, ry, rc);
}

/// Um trecho de rua entre duas esquinas ([a] e [b]), com as calçadas dos dois lados.
class SimEdge {
  SimEdge(this.key, this.line, this.xs, this.ys, this.cum, this.a, this.b, this.halfWidthM);

  /// Estável enquanto o pacote visual for o mesmo: tile, linha e o vértice onde o trecho começa.
  final (int, int, int, int) key;
  final GhostLine line;

  /// A linha central, de [a] para [b]: células e metros acumulados.
  final Float64List xs, ys, cum;
  final SimNode a, b;
  final double halfWidthM;

  double get lengthM => cum[cum.length - 1];
  RoadClass get roadClass => line.roadClass;
  bool get isPedestrian => line.isPedestrian;

  /// Os sentidos em que anda carro (`null`: contramão ou caminho de pedestre).
  SimLink? fwd, rev;

  /// As calçadas de [a] para [b]: a da direita desse sentido e a da esquerda.
  late Track walkRight, walkLeft;

  Track walk(int side) => side > 0 ? walkRight : walkLeft;

  double minX = 0, minY = 0, maxX = 0, maxY = 0;

  /// O clima: rua fechada (duna, neve funda) não recebe carro; alagada não recebe passante.
  bool closed = false, flooded = false;

  /// Passantes atravessando a rua em cada ponta: os carros esperam.
  int crossingA = 0, crossingB = 0;

  /// Quantos carros já passaram por aqui (as trilhas na neve).
  int wear = 0;

  bool touches(double l, double t, double r, double b, double m) => maxX + m >= l && minX - m <= r && maxY + m >= t && minY - m <= b;
}

/// Um sentido de um trecho, com as faixas (a 0 é a mais perto do meio da rua).
class SimLink {
  SimLink(this.edge, this.forward, this.lanes) : cars = [for (final _ in lanes) <SimCarRef>[]];

  final SimEdge edge;
  final bool forward;
  final List<Track> lanes;

  /// Os carros de cada faixa, o da frente primeiro. Quem está na esquina (além do fim da faixa) continua aqui até sair.
  final List<List<SimCarRef>> cars;

  SimNode get from => forward ? edge.a : edge.b;
  SimNode get to => forward ? edge.b : edge.a;
  RoadClass get roadClass => edge.roadClass;
  double get length => lanes[0].length;
  SimLink? get reverse => forward ? edge.rev : edge.fwd;

  /// Direção (rad) chegando na esquina e saindo dela.
  double headingIn = 0, headingOut = 0;

  /// O grupo do semáforo (0 ou 1) e se este acesso cede a vez numa esquina sem semáforo.
  int group = 0;
  bool yields = false;

  /// Só leva a ruas sem saída: ninguém escolhe, a não ser que não haja outra.
  bool deadEnd = false;

  /// Passantes atravessando no fim deste sentido (antes da esquina) e no começo (depois dela).
  int get crossingAtEnd => forward ? edge.crossingB : edge.crossingA;
  int get crossingAtStart => forward ? edge.crossingA : edge.crossingB;
}

/// O que a faixa precisa saber de um carro (o resto mora em `traffic_sim.dart`).
abstract class SimCarRef {
  double s = 0, v = 0, length = 4;
}

/// Uma rua que chega numa esquina, vista da esquina.
class SimArm {
  SimArm(this.edge, this.atA, this.angle);

  final SimEdge edge;

  /// A esquina é a ponta `a` do trecho.
  final bool atA;

  /// Direção saindo da esquina (rad, x leste, y sul).
  final double angle;

  /// Passante pode atravessar esta rua aqui.
  bool crossable = true;
  int group = 0;

  SimLink? get incoming => atA ? edge.rev : edge.fwd;
  SimLink? get outgoing => atA ? edge.fwd : edge.rev;

  /// O lado da calçada (em relação a `a` para `b`) que fica à direita de quem sai da esquina.
  int get rightSide => atA ? 1 : -1;
}

enum SignalLight { green, yellow, red }

class SimNode {
  SimNode(this.id, this.x, this.y);

  final int id;
  final double x, y;

  /// As ruas em volta, na ordem crescente do ângulo.
  final List<SimArm> arms = [];
  final List<SimLink> incoming = [], outgoing = [];

  /// Fora do raio simulado: aqui o tráfego entra e sai do mundo.
  bool border = false;

  /// Perto de um estacionamento ou garagem do OSM: entrada e saída fora da vista.
  bool entry = false;

  /// Esquina de verdade (três ou mais ruas de carro): só entra um movimento por vez.
  bool controlled = false;
  bool signal = false;
  double offsetS = 0, green0 = 25, green1 = 20;

  // Quem está dentro (ou já reservou a vez): acesso, faixa, se vai reto, e quantos.
  final List<SimLink> holdLink = [];
  final List<int> holdLane = [], holdCount = [];
  final List<bool> holdStraight = [];

  /// Para onde vai quem ocupa (`null`: carros da mesma faixa indo para ruas diferentes).
  final List<SimLink?> holdNext = [];

  int armOf(SimEdge e) {
    for (var i = 0; i < arms.length; i++) {
      if (identical(arms[i].edge, e)) return i;
    }
    return -1;
  }

  /// A luz do grupo [group] no instante [t] da simulação.
  SignalLight light(int group, double t, TrafficSimConfig c) {
    final cycle = green0 + green1 + 2 * (c.yellowS + c.allRedS);
    var p = (t + offsetS) % cycle;
    if (group == 1) p = (p - green0 - c.yellowS - c.allRedS) % cycle;
    if (p < 0) p += cycle;
    final g = group == 0 ? green0 : green1;
    return p < g ? SignalLight.green : p < g + c.yellowS ? SignalLight.yellow : SignalLight.red;
  }
}

double _angDiff(double a, double b) {
  var d = (a - b) % (2 * math.pi);
  if (d > math.pi) d -= 2 * math.pi;
  if (d < -math.pi) d += 2 * math.pi;
  return d;
}

/// A diferença de direção entre chegar por [a] e sair por [b], em rad (0: reto; positivo: para a direita na tela).
double turnAngle(SimLink a, SimLink b) => _angDiff(b.headingOut, a.headingIn);

int _rank(RoadClass c) => switch (c) { RoadClass.principal => 3, RoadClass.secondary => 2, RoadClass.local => 1, RoadClass.pedestrian => 0 };

class LaneGraph {
  LaneGraph._(this.cx, this.cy, this.mpc, this.radiusM);

  /// O centro (células), os metros por célula e o raio com que o grafo foi montado.
  final double cx, cy, mpc, radiusM;

  final List<SimNode> nodes = [];
  final List<SimEdge> edges = [];
  final List<SimLink> links = [];
  final Map<(int, int, int, int), SimEdge> byKey = {};

  /// Quanto tempo levou para montar, em microssegundos.
  int buildUs = 0;

  /// Monta o grafo das ruas a até [TrafficSimConfig.radiusM] (mais uma folga) de ([cx], [cy]). [graph] precisa cortar as
  /// esquinas (`stitch`). Sem [points], as esquinas de avenidas ganham semáforo e as outras cedem a vez pela classe.
  factory LaneGraph.build(TrafficGraph graph, {required double cx, required double cy, required double mpc, required int seed, required TrafficSimConfig config, TrafficPointSource? points, Map<String, double> roadWidthM = const {'principal': 12, 'secondary': 9, 'local': 6, 'pedestrian': 2}}) {
    final sw = Stopwatch()..start();
    final g = LaneGraph._(cx, cy, mpc, config.radiusM);
    final reach = (config.radiusM + config.borderM) / mpc;
    final n = graph.cellsPerTile;
    final l = cx - reach, t = cy - reach, r = cx + reach, b = cy + reach;
    // Primeiro os pedaços entre esquinas, com nós provisórios; depois os nós a menos de [mergeM] um do outro (ligados por um
    // trecho curto) viram uma esquina só: os entroncamentos picados em pedacinhos funcionam como um cruzamento.
    final px = <double>[], py = <double>[], parent = <int>[];
    final buckets = <int, List<int>>{};
    int nodeAt(double x, double y) {
      final bx = x.floor(), by = y.floor();
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (final k in buckets[(bx + dx) * 4194304 + by + dy] ?? const <int>[]) {
            if ((px[k] - x) * (px[k] - x) + (py[k] - y) * (py[k] - y) <= 0.35 * 0.35) return k;
          }
        }
      }
      px.add(x);
      py.add(y);
      parent.add(px.length - 1);
      (buckets[bx * 4194304 + by] ??= []).add(px.length - 1);
      return px.length - 1;
    }

    int root(int k) {
      while (parent[k] != k) {
        k = parent[k] = parent[parent[k]];
      }
      return k;
    }

    final pieces = <(GhostLine, int, int, int, int)>[];
    for (var ty = (t / n).floor(); ty <= (b / n).floor(); ty++) {
      for (var tx = (l / n).floor(); tx <= (r / n).floor(); tx++) {
        for (final line in graph.linesOfTile(tx, ty)) {
          if (line.maxX < l || line.minX > r || line.maxY < t || line.minY > b) continue;
          final vc = line.vertexCount;
          var start = 0;
          for (var i = 1; i < vc; i++) {
            final x = line.xy[2 * i], y = line.xy[2 * i + 1];
            if (i < vc - 1 && graph.joinsAt(x, y, exclude: line).isEmpty) continue;
            final s = start;
            start = i;
            // Os dois nós fora do quadrado: o trecho não entra.
            final ax = line.xy[2 * s], ay = line.xy[2 * s + 1];
            if ((ax < l || ax > r || ay < t || ay > b) && (x < l || x > r || y < t || y > b)) continue;
            final na = nodeAt(ax, ay), nb = nodeAt(x, y);
            if (na == nb) continue;
            pieces.add((line, s, i, na, nb));
            if ((line.cum[i] - line.cum[s]) * mpc < config.mergeM) parent[root(na)] = root(nb);
          }
        }
      }
    }
    final made = <int, SimNode>{};
    SimNode nodeOf(int k) => made[root(k)] ??= () {
          final rt = root(k);
          var sx = 0.0, sy = 0.0, cnt = 0;
          for (var j = 0; j < px.length; j++) {
            if (root(j) == rt) {
              sx += px[j];
              sy += py[j];
              cnt++;
            }
          }
          final nd = SimNode(g.nodes.length, sx / cnt, sy / cnt);
          g.nodes.add(nd);
          return nd;
        }();
    final seenPair = <(int, int), List<double>>{};
    for (final (line, s, i, na, nb) in pieces) {
      if (root(na) == root(nb)) continue;
      final lenM = (line.cum[i] - line.cum[s]) * mpc;
      final a = nodeOf(na), bn = nodeOf(nb);
      // A sobra de dois tiles traz o mesmo trecho duas vezes: fica o primeiro.
      final pair = a.id < bn.id ? (a.id, bn.id) : (bn.id, a.id);
      final same = seenPair[pair] ??= [];
      if (same.any((m) => (m - lenM).abs() <= 0.15 * lenM + 2)) continue;
      same.add(lenM);
      final cnt = i - s + 1;
      final xs = Float64List(cnt), ys = Float64List(cnt), cum = Float64List(cnt);
      for (var k = 0; k < cnt; k++) {
        xs[k] = line.xy[2 * (s + k)];
        ys[k] = line.xy[2 * (s + k) + 1];
        cum[k] = (line.cum[s + k] - line.cum[s]) * mpc;
      }
      final e = SimEdge((line.key.$1, line.key.$2, line.key.$3, s), line, xs, ys, cum, a, bn, (roadWidthM[line.roadClass.name] ?? 6) / 2);
      g.edges.add(e);
      g.byKey[e.key] = e;
    }
    g._finish(seed, config, points);
    g.buildUs = sw.elapsedMicroseconds;
    return g;
  }

  void _finish(int seed, TrafficSimConfig c, TrafficPointSource? points) {
    final rCells = radiusM / mpc;
    for (final nd in nodes) {
      final dx = nd.x - cx, dy = nd.y - cy;
      nd.border = dx * dx + dy * dy > rCells * rCells;
    }
    for (final e in edges) {
      final last = e.xs.length - 1;
      e.a.arms.add(SimArm(e, true, math.atan2(e.ys[1] - e.ys[0], e.xs[1] - e.xs[0])));
      e.b.arms.add(SimArm(e, false, math.atan2(e.ys[last - 1] - e.ys[last], e.xs[last - 1] - e.xs[last])));
      var x0 = double.infinity, y0 = double.infinity, x1 = -double.infinity, y1 = -double.infinity;
      for (var i = 0; i <= last; i++) {
        x0 = math.min(x0, e.xs[i]);
        x1 = math.max(x1, e.xs[i]);
        y0 = math.min(y0, e.ys[i]);
        y1 = math.max(y1, e.ys[i]);
      }
      e
        ..minX = x0
        ..minY = y0
        ..maxX = x1
        ..maxY = y1;
    }
    // O recuo de cada esquina: a meia largura da rua mais larga que chega nela.
    final setback = Float64List(nodes.length);
    for (final nd in nodes) {
      nd.arms.sort((p, q) => p.angle.compareTo(q.angle));
      final carArms = nd.arms.where((a) => !a.edge.isPedestrian).length;
      nd.controlled = carArms >= 3;
      var w = 0.0;
      for (final a in nd.arms) {
        if (!a.edge.isPedestrian) w = math.max(w, a.edge.halfWidthM);
      }
      setback[nd.id] = nd.arms.length >= 3 ? w + c.cornerExtraM : (nd.arms.length == 1 ? 0.3 : 0.6);
    }
    // Duas ruas que se juntam em ângulo raso se sobrepõem por muitos metros: o recuo vai até onde elas se separam.
    double armSetback(SimNode nd, SimEdge e) {
      var sb = setback[nd.id];
      if (e.isPedestrian || nd.arms.length < 3) return sb;
      final me = nd.arms[nd.armOf(e)];
      for (final o in nd.arms) {
        if (identical(o, me) || o.edge.isPedestrian) continue;
        final th = _angDiff(o.angle, me.angle).abs();
        if (th < 1.4) sb = math.max(sb, math.min(45, ((e.halfWidthM + o.edge.halfWidthM) / 2 + 1) / (2 * math.sin(math.max(th, 0.1) / 2))));
      }
      return sb;
    }

    for (final e in edges) {
      final len = e.lengthM;
      final sa = math.min(armSetback(e.a, e), len * 0.42), sb = math.min(armSetback(e.b, e), len * 0.42);
      final side = e.isPedestrian ? e.halfWidthM * 0.5 : e.halfWidthM + c.sidewalkM;
      e.walkRight = offsetTrack(e.xs, e.ys, e.cum, mpc, sa, len - sb, side);
      e.walkLeft = offsetTrack(e.xs, e.ys, e.cum, mpc, sa, len - sb, -side);
      if (e.isPedestrian) continue;
      final lanes = c.lanesOf(e.roadClass);
      final ow = e.line.oneway;
      List<Track> tracks(bool fwd) {
        if (ow == OneWay.twoWay) {
          final w = e.halfWidthM / lanes;
          return [for (var k = 0; k < lanes; k++) offsetTrack(e.xs, e.ys, e.cum, mpc, sa, len - sb, (fwd ? 1 : -1) * (k + 0.5) * w, reversed: !fwd)];
        }
        final w = 2 * e.halfWidthM / (lanes + 1); // mão única: as faixas no meio, com folga dos dois lados
        return [for (var k = 0; k < lanes; k++) offsetTrack(e.xs, e.ys, e.cum, mpc, sa, len - sb, (fwd ? 1 : -1) * (k - (lanes - 1) / 2) * w, reversed: !fwd)];
      }

      if (ow != OneWay.reverse) e.fwd = SimLink(e, true, tracks(true));
      if (ow != OneWay.forward) e.rev = SimLink(e, false, tracks(false));
      for (final k in [e.fwd, e.rev]) {
        if (k == null) continue;
        links.add(k);
        k.from.outgoing.add(k);
        k.to.incoming.add(k);
        final tr = k.lanes[0], m = tr.xs.length;
        k.headingOut = math.atan2(tr.ys[1] - tr.ys[0], tr.xs[1] - tr.xs[0]);
        k.headingIn = math.atan2(tr.ys[m - 1] - tr.ys[m - 2], tr.xs[m - 1] - tr.xs[m - 2]);
      }
    }
    _control(seed, c, points);
    _deadEnds();
  }

  void _control(int seed, TrafficSimConfig c, TrafficPointSource? points) {
    final reach = (radiusM + c.borderM) / mpc;
    final pts = points?.pointsIn(cx - reach, cy - reach, cx + reach, cy + reach) ?? const <TrafficPoint>[];
    // Sem nenhum ponto em volta (fora da região do arquivo): vale a regra pela classe das ruas.
    final mapped = pts.isNotEmpty;
    final near = c.controlNearM / mpc;
    double d2(TrafficPoint p, SimNode n) => (p.x - n.x) * (p.x - n.x) + (p.y - n.y) * (p.y - n.y);
    bool onEdge(TrafficPoint p, SimEdge e) {
      final tol = (e.halfWidthM + 2) / mpc;
      for (var i = 0; i + 1 < e.xs.length; i++) {
        final ax = e.xs[i], ay = e.ys[i], ex = e.xs[i + 1] - ax, ey = e.ys[i + 1] - ay;
        final len = ex * ex + ey * ey;
        final u = len <= 0 ? 0.0 : (((p.x - ax) * ex + (p.y - ay) * ey) / len).clamp(0.0, 1.0);
        final qx = ax + ex * u - p.x, qy = ay + ey * u - p.y;
        if (qx * qx + qy * qy <= tol * tol) return true;
      }
      return false;
    }

    for (final nd in nodes) {
      final here = [for (final p in pts) if (d2(p, nd) <= near * near) p];
      nd.entry = here.any((p) => p.kind == TrafficPointKind.entry) || pts.any((p) => p.kind == TrafficPointKind.entry && d2(p, nd) <= math.pow(c.entryNearM / mpc, 2));
      final crossings = [for (final p in here) if (p.kind == TrafficPointKind.crossing) p];
      for (final a in nd.arms) {
        // Com faixa mapeada por perto, só se atravessa nela; sem nenhuma, nas esquinas (e nunca no meio do quarteirão).
        a.crossable = a.edge.isPedestrian || (crossings.isEmpty ? nd.arms.length != 2 : crossings.any((p) => onEdge(p, a.edge)));
      }
      if (!nd.controlled) continue;
      final top = nd.arms.fold(0, (m, a) => math.max(m, _rank(a.edge.roadClass)));
      final big = nd.arms.where((a) => _rank(a.edge.roadClass) >= 2).length;
      nd.signal = !mapped ? (top == 3 && big >= 3) : here.any((p) => p.kind == TrafficPointKind.signal);
      // O eixo principal é o da rua mais larga; quem chega atravessado a ele é o grupo 1.
      final ref = nd.arms.reduce((p, q) => _rank(q.edge.roadClass) > _rank(p.edge.roadClass) ? q : p);
      for (final a in nd.arms) {
        final d = _angDiff(a.angle, ref.angle).abs();
        a.group = (d < math.pi / 4 || d > 3 * math.pi / 4) ? 0 : 1;
        a.incoming?.group = a.group;
      }
      final h = (seed ^ (nd.x * 64).round() * 0x9E3779B1 ^ (nd.y * 64).round() * 0x85EBCA6B) & 0x7fffffff;
      nd.green0 = c.greenS * (top == 3 ? 1.2 : 1);
      nd.green1 = c.greenS * 0.8;
      nd.offsetS = (h % 1000) / 1000 * (nd.green0 + nd.green1 + 2 * (c.yellowS + c.allRedS));
      if (nd.signal) continue;
      final signs = [for (final p in here) if (p.kind == TrafficPointKind.stop || p.kind == TrafficPointKind.giveWay) p];
      for (final a in nd.arms) {
        final inc = a.incoming;
        if (inc == null) continue;
        final signed = signs.any((p) => onEdge(p, a.edge));
        // Sem placa: cede quem vem da rua menor; entre iguais, todos param e entra quem chegou primeiro.
        inc.yields = signs.any((p) => nd.arms.any((o) => onEdge(p, o.edge))) ? signed : (_rank(a.edge.roadClass) < top || nd.arms.every((o) => o.edge.isPedestrian || _rank(o.edge.roadClass) == top));
      }
    }
  }

  /// Marca os sentidos que só levam a rua sem saída (o fim não tem para onde ir a não ser voltar).
  void _deadEnds() {
    var changed = true;
    while (changed) {
      changed = false;
      for (final k in links) {
        if (k.deadEnd || k.to.border) continue;
        if (k.to.outgoing.every((o) => o.deadEnd || identical(o, k.reverse))) {
          k.deadEnd = true;
          changed = true;
        }
      }
    }
  }

  /// Aplica o clima das ruas: [state] diz se a rua fechou ou alagou.
  void applyStreets(bool Function(GhostLine)? closed, bool Function(GhostLine)? flooded) {
    for (final e in edges) {
      e.closed = closed?.call(e.line) ?? false;
      e.flooded = flooded?.call(e.line) ?? false;
    }
  }
}
