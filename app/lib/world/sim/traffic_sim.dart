/// A simulação local do tráfego comum (docs/GDD.md, "Tráfego do Véu"): carros que seguem o da frente (IDM), param no
/// vermelho, cedem a vez e fazem as curvas das esquinas; passantes nas calçadas que só atravessam na faixa (ou na esquina,
/// onde não há faixa), esperam o verde e desviam uns dos outros. Os agentes vivem num raio em volta do jogador e só entram
/// e saem pela borda dele ou por estacionamentos e garagens fora da vista. Dart puro.
///
/// É cenário: não decide spawn, coleta nem Aura, e difere entre aparelhos. Os veículos que importam para o jogo (Procissão e
/// os que vierem: Ônibus Espectral, Van do Mercador, Carroça de Essência, carro fugitivo) continuam saindo da seed, fora
/// daqui.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/pcg32.dart';
import '../../data/traffic_pack.dart';
import '../../data/visual_pack.dart';
import '../traffic_graph.dart';
import '../veil_traffic.dart' show GhostModel, carDensity, pedestrianDensity;
import 'lane_graph.dart';
import 'traffic_sim_config.dart';

export 'lane_graph.dart';
export 'traffic_sim_config.dart';

class SimCar extends SimCarRef {
  SimCar(this.id, this.model, this.palette, this.link, this.lane, this.vFactor);

  final int id;
  final GhostModel model;
  final int palette;
  SimLink link;
  int lane;

  /// Quanto este motorista corre em relação à velocidade da rua.
  final double vFactor;

  /// Para onde vai na próxima esquina (`null`: sai do mundo no fim do trecho) e se já escolheu.
  SimLink? next;
  int nextLane = 0;
  bool chosen = false, straight = true;

  /// Já tem a vez na esquina; [holds]: e ocupa a esquina (as de três ruas ou mais).
  bool reserved = false, holds = false;

  /// Dentro da esquina: a curva (Bézier, em células) e o comprimento dela em metros.
  bool inJunction = false;
  double bx0 = 0, by0 = 0, bx1 = 0, by1 = 0, bx2 = 0, by2 = 0, clen = 0;

  /// Posição (células) e direção (rad) do último passo, e a distância andada desde que nasceu (m).
  double x = 0, y = 0, heading = 0, odo = 0;

  /// A direção desenhada: segue [heading] sem dar tranco nos vértices da rua.
  double yaw = double.nan;
  int seg = 0;
  double waitS = 0;
  bool gone = false;

  /// Outro carro logo à frente fora da fila (ruas que se juntam ou se separam): a folga até ele e a velocidade dele.
  double blockGap = double.infinity, blockV = 0;

  SimEdge get edge => link.edge;
}

enum WalkerMode { walking, waiting, corner, crossing }

class SimWalker {
  SimWalker(this.id, this.model, this.palette, this.edge, this.side, this.dir, this.s, this.speed, this.latBase) : lat = latBase;

  final int id;
  final GhostModel model;
  final int palette;

  /// O trecho, o lado da calçada (+1 à direita de `a` para `b`) e o sentido (+1 para `b`).
  SimEdge edge;
  int side, dir;

  /// Metros ao longo da calçada, velocidade de cruzeiro e o desvio lateral (m, para a direita de `a` para `b`).
  double s;
  final double speed, latBase;
  double lat, latTarget = 0, v = 0;

  WalkerMode mode = WalkerMode.walking;

  /// O que fez por último na esquina: 0 veio andando, 1 virou a esquina, 2 atravessou.
  int last = 0;

  // A travessia ou a virada de esquina em curso: de onde, para onde, e em que trecho e lado termina.
  double fx = 0, fy = 0, tx = 0, ty = 0, tLen = 0, tPos = 0;
  SimEdge? tEdge;
  int tSide = 0;
  bool atA = false;

  double x = 0, y = 0, heading = 0, odo = 0;
  int seg = 0;
  bool gone = false;
}

class TrafficSim {
  TrafficSim({required this.graph, required this.seed, this.config = const TrafficSimConfig(), this.points, this.roadWidthM = const {'principal': 12, 'secondary': 9, 'local': 6, 'pedestrian': 2}, this.carLengthM = 4.2})
      : _rng = Pcg32(seed ^ 0x51ED270B, 0x7A3F);

  /// O grafo de ruas, com corte nas esquinas (`stitch`).
  TrafficGraph graph;
  final int seed;
  final TrafficSimConfig config;
  final TrafficPointSource? points;
  final Map<String, double> roadWidthM;
  final double carLengthM;
  final Pcg32 _rng;

  LaneGraph? lanes;
  final List<SimCar> cars = [];
  final List<SimWalker> walkers = [];

  /// O relógio da simulação, em segundos: só anda em [step] (o Silêncio pausa e depois continua de onde parou).
  double time = 0;

  /// Debug: multiplica a densidade (`null`: a da hora e do clima).
  double? forcedDensity;

  /// Quantos agentes nasceram e sumiram dentro da vista desde o começo (tem de ficar em zero), fora a primeira população.
  int bornInView = 0, goneInView = 0;

  /// Custo do último passo e a média móvel, em microssegundos.
  int lastStepUs = 0;
  double avgStepUs = 0;

  bool _stale = false;

  /// O pacote de ruas mudou (chegou um bloco ou uma região): o grafo de faixas é refeito no próximo [center], e quem está
  /// nas ruas que continuam iguais fica onde está.
  void regraph(TrafficGraph g) {
    graph = g;
    _stale = true;
  }

  int _nextId = 1, _frame = 0;
  double _vl = 0, _vt = 0, _vr = 0, _vb = 0;
  bool _hasView = false;
  double _carCap = 0, _walkCap = 0, _spawnDebt = 0;
  final List<SimLink> _carSources = [];
  final List<(SimEdge, bool)> _walkSources = [];
  final List<SimNode> _entries = [];
  final Float64List _p = Float64List(3);

  double _u() => _rng.nextFloat();

  bool _inView(double x, double y, double marginM) {
    if (!_hasView) return false;
    final m = marginM / lanes!.mpc;
    return x >= _vl - m && x <= _vr + m && y >= _vt - m && y <= _vb + m;
  }

  /// A margem além da tela dentro da qual ninguém nasce nem some, em metros.
  static const double hiddenMarginM = 25;

  /// Centra a área simulada em ([px], [py], células z21): monta o grafo na primeira vez (e já povoa as ruas) e refaz
  /// quando o jogador andou [TrafficSimConfig.rebuildM]. A vista ([left]..[bottom], células) é a tela do momento.
  void center(double px, double py, double mpc, {double? left, double? top, double? right, double? bottom, double hour = 12, double density = 1}) {
    if (left != null) {
      _vl = left;
      _vt = top!;
      _vr = right!;
      _vb = bottom!;
      _hasView = true;
    }
    final g = lanes;
    if (g != null && !_stale) {
      final dx = (px - g.cx) * mpc, dy = (py - g.cy) * mpc;
      if (dx * dx + dy * dy < config.rebuildM * config.rebuildM) return;
    }
    _stale = false;
    final fresh = LaneGraph.build(graph, cx: px, cy: py, mpc: mpc, seed: seed, config: config, points: points, roadWidthM: roadWidthM);
    lanes = fresh;
    if (g != null) {
      for (final e in fresh.edges) {
        e.wear = g.byKey[e.key]?.wear ?? 0; // as trilhas na neve continuam
      }
    }
    _index(fresh);
    if (g == null) {
      _populate(fresh, hour, density, null);
      // Roda um pouco antes do primeiro quadro: as filas dos semáforos já existem quando o app abre.
      final view = _hasView;
      _hasView = false;
      for (var t = 0.0; t < config.warmupS; t += 0.5) {
        step(0.5, hour: hour, density: density, spawn: false);
      }
      _hasView = view;
      bornInView = goneInView = 0;
    } else {
      _remap(g, fresh);
      _populate(fresh, hour, density, g);
    }
  }

  void _index(LaneGraph g) {
    _carSources.clear();
    _walkSources.clear();
    _entries.clear();
    _carCap = _walkCap = 0;
    for (final e in g.edges) {
      _walkCap += e.lengthM / 100 * config.walkConc(e.roadClass);
      if (!e.isPedestrian) _carCap += e.lengthM / 100 * config.carConc(e.roadClass);
      if (e.a.border != e.b.border) _walkSources.add((e, e.a.border));
    }
    for (final k in g.links) {
      if (k.from.border && !k.to.border) _carSources.add(k);
    }
    for (final n in g.nodes) {
      if (n.entry && !n.border && n.outgoing.isNotEmpty) _entries.add(n);
    }
  }

  int carTarget(double hour, double density) => math.min(config.maxCars, (_carCap * (forcedDensity ?? carDensity(hour) * density)).round());
  int walkerTarget(double hour, double density) => math.min(config.maxWalkers, (_walkCap * (forcedDensity ?? pedestrianDensity(hour) * density)).round());

  GhostModel _carModel() {
    final d = _u();
    return d < 0.4 ? GhostModel.hatch : d < 0.7 ? GhostModel.sedan : d < 0.85 ? GhostModel.pickup : GhostModel.moto;
  }

  SimCar _newCar(SimLink link, int lane, double s, double v) {
    final m = _carModel();
    final c = SimCar(_nextId++, m, _rng.nextInt(m.paletteCount), link, lane, 0.85 + 0.25 * _u())
      ..s = s
      ..v = v
      ..length = m == GhostModel.moto ? carLengthM * 0.5 : carLengthM;
    cars.add(c);
    return c;
  }

  SimWalker _newWalker(SimEdge e, int side, int dir, double s) {
    final d = _u();
    final m = e.isPedestrian && d > 0.8 ? GhostModel.cyclist : d < 0.5 ? GhostModel.adult : d < 0.7 ? GhostModel.childPair : GhostModel.elder;
    final base = switch (m) { GhostModel.cyclist => 3.2, GhostModel.elder => 0.65, GhostModel.childPair => 0.8, _ => 1.0 } * config.walkMps;
    final w = SimWalker(_nextId++, m, _rng.nextInt(m.paletteCount), e, side, dir, s, base * (0.85 + 0.3 * _u()), (_u() - 0.5) * 0.6);
    walkers.add(w);
    return w;
  }

  /// Espalha agentes pelas ruas até a meta. Na primeira vez, em toda a área; depois de refazer o grafo, só nos trechos
  /// que entraram agora (a borda nova), que estão longe da vista.
  void _populate(LaneGraph g, double hour, double density, LaneGraph? old) {
    final fresh = [for (final e in g.edges) if (old == null || !old.byKey.containsKey(e.key)) e];
    if (fresh.isEmpty) return;
    var carLen = 0.0, walkLen = 0.0;
    for (final e in fresh) {
      if (e.fwd != null || e.rev != null) carLen += e.lengthM * config.carConc(e.roadClass);
      walkLen += e.lengthM * config.walkConc(e.roadClass);
    }
    final wantCars = old == null ? carTarget(hour, density) : math.min(carTarget(hour, density) - cars.length, (carLen / 100 * (forcedDensity ?? carDensity(hour) * density)).round());
    final wantWalk = old == null ? walkerTarget(hour, density) : math.min(walkerTarget(hour, density) - walkers.length, (walkLen / 100 * (forcedDensity ?? pedestrianDensity(hour) * density)).round());
    for (var i = 0, tries = 0; i < wantCars && tries < wantCars * 8 && carLen > 0; tries++) {
      var pick = _u() * carLen;
      for (final e in fresh) {
        if (e.fwd == null && e.rev == null) continue;
        pick -= e.lengthM * config.carConc(e.roadClass);
        if (pick > 0) continue;
        final link = e.rev == null || (e.fwd != null && _u() < 0.5) ? e.fwd! : e.rev!;
        final lane = _rng.nextInt(link.lanes.length), len = link.lanes[lane].length;
        final s = len * (0.1 + 0.8 * _u());
        final list = link.cars[lane];
        if (len > 12 && !e.closed && list.every((o) => (o.s - s).abs() > 9) && (old == null || !_inView(e.xs[0], e.ys[0], hiddenMarginM + e.lengthM))) {
          final c = _newCar(link, lane, s, config.speedOf(link.roadClass) * 0.6);
          var at = 0;
          while (at < list.length && list[at].s > s) {
            at++;
          }
          list.insert(at, c);
          _place(c);
          i++;
        }
        break;
      }
    }
    for (var i = 0, tries = 0; i < wantWalk && tries < wantWalk * 8 && walkLen > 0; tries++) {
      var pick = _u() * walkLen;
      for (final e in fresh) {
        pick -= e.lengthM * config.walkConc(e.roadClass);
        if (pick > 0) continue;
        if (!e.flooded && (old == null || !_inView(e.xs[0], e.ys[0], hiddenMarginM + e.lengthM))) {
          final side = _u() < 0.5 ? 1 : -1;
          final w = _newWalker(e, side, _u() < 0.5 ? 1 : -1, e.walk(side).length * _u());
          _placeWalker(w);
          i++;
        }
        break;
      }
    }
  }

  /// Passa os agentes do grafo antigo para o novo pelo trecho (a chave é estável); quem ficou de fora some (estava na
  /// borda antiga, longe da vista).
  void _remap(LaneGraph old, LaneGraph g) {
    for (final c in cars) {
      final e = g.byKey[c.edge.key];
      final link = e == null ? null : (c.link.forward ? e.fwd : e.rev);
      final nk = c.next == null ? null : g.byKey[c.next!.edge.key];
      final next = nk == null ? null : (c.next!.forward ? nk.fwd : nk.rev);
      if (link == null || (c.next != null && next == null && c.inJunction)) {
        c.gone = true;
        continue;
      }
      c.link = link;
      c.lane = math.min(c.lane, link.lanes.length - 1);
      if (next == null) {
        c.chosen = c.reserved = c.holds = false;
        c.next = null;
      } else {
        c.next = next;
        c.nextLane = math.min(c.nextLane, next.lanes.length - 1);
      }
      if (!c.inJunction) c.s = math.min(c.s, link.lanes[c.lane].length);
    }
    cars.removeWhere((c) => c.gone);
    for (final c in cars) {
      c.link.cars[c.lane].add(c);
      if (c.holds) {
        if (c.link.to.controlled) {
          _hold(c.link.to, c);
        } else {
          c.holds = false;
        }
      }
    }
    for (final k in g.links) {
      for (final l in k.cars) {
        l.sort((p, q) => q.s.compareTo(p.s));
      }
    }
    for (final w in walkers) {
      final e = g.byKey[w.edge.key], te = w.tEdge == null ? null : g.byKey[w.tEdge!.key];
      if (e == null || (w.tEdge != null && te == null)) {
        w.gone = true;
        continue;
      }
      w.edge = e;
      w.tEdge = te;
      w.s = w.s.clamp(0.0, e.walk(w.side).length);
      if (w.mode == WalkerMode.crossing) w.atA ? e.crossingA++ : e.crossingB++;
    }
    walkers.removeWhere((w) => w.gone);
  }

  // ---------------------------------------------------------------- esquina

  void _hold(SimNode n, SimCar c) {
    for (var i = 0; i < n.holdLink.length; i++) {
      if (identical(n.holdLink[i], c.link) && n.holdLane[i] == c.lane) {
        n.holdCount[i]++;
        if (!c.straight) n.holdStraight[i] = false;
        if (!identical(n.holdNext[i], c.next)) n.holdNext[i] = null;
        return;
      }
    }
    n.holdNext.add(c.next);
    n.holdLink.add(c.link);
    n.holdLane.add(c.lane);
    n.holdStraight.add(c.straight);
    n.holdCount.add(1);
  }

  void _release(SimNode n, SimLink link, int lane) {
    for (var i = 0; i < n.holdLink.length; i++) {
      if (identical(n.holdLink[i], link) && n.holdLane[i] == lane) {
        if (--n.holdCount[i] <= 0) {
          n.holdLink.removeAt(i);
          n.holdLane.removeAt(i);
          n.holdStraight.removeAt(i);
          n.holdNext.removeAt(i);
          n.holdCount.removeAt(i);
        }
        return;
      }
    }
  }

  /// Dois movimentos cabem juntos na esquina: a mesma faixa do mesmo acesso, ou os dois indo reto pelo mesmo eixo.
  bool _compatible(SimNode n, SimCar c) {
    for (var i = 0; i < n.holdLink.length; i++) {
      final h = n.holdLink[i];
      if (identical(h, c.link) && n.holdLane[i] == c.lane) continue;
      if (c.straight && n.holdStraight[i]) {
        // Lado a lado pelo mesmo acesso só se vão para a mesma rua (senão as curvas se cruzam); ou a mão contrária, reto.
        final d = (h.headingIn - c.link.headingIn).abs() % (2 * math.pi);
        if (identical(h, c.link) ? identical(n.holdNext[i], c.next) : (d > 2.6 && d < 2 * math.pi - 2.6)) continue;
      }
      return false;
    }
    return true;
  }

  void _choose(SimCar c) {
    c.chosen = true;
    final link = c.link, node = link.to;
    c.next = null;
    c.straight = true;
    if (node.border) return;
    // Estacionamento ou garagem fora da vista: às vezes o carro entra e some.
    if (node.entry && !_inView(node.x, node.y, hiddenMarginM + 30) && _u() < 0.2) return;
    SimLink? best;
    var total = 0.0;
    for (var pass = 0; pass < 2 && best == null; pass++) {
      for (final o in node.outgoing) {
        if (identical(o, link.reverse) || o.edge.closed || (pass == 0 && o.deadEnd)) continue;
        final turn = turnAngle(link, o).abs();
        final w = (o.roadClass == RoadClass.principal ? 3.0 : o.roadClass == RoadClass.secondary ? 2.0 : 1.0) * (turn < 0.5 ? 2.5 : 1) * (identical(o.roadClass, link.roadClass) ? 1.5 : 1);
        total += w;
        if (_u() * total < w) best = o;
      }
    }
    best ??= link.reverse; // rua sem saída: volta
    if (best == null) return;
    c.next = best;
    final turn = turnAngle(link, best);
    c.straight = turn.abs() < 0.5;
    final n = best.lanes.length;
    c.nextLane = c.straight ? (n > link.lanes.length ? _rng.nextInt(n) : math.min(c.lane, n - 1)) : (turn > 0 ? n - 1 : 0);
  }

  /// O fundo do último carro da faixa [lane] de [link], em metros do começo dela (`infinity` se está vazia).
  double _tailRear(SimLink link, int lane) {
    final l = link.cars[lane];
    return l.isEmpty ? double.infinity : l.last.s - l.last.length / 2;
  }

  bool _mayEnter(SimCar c, double dEnd) {
    final link = c.link, next = c.next!, node = link.to;
    if (link.crossingAtEnd > 0 || next.crossingAtStart > 0 || next.edge.closed && !identical(next, link.reverse)) return false;
    // Não fecha o cruzamento: só entra com lugar do outro lado, contando quem da mesma faixa já está na esquina.
    var pending = 0.0;
    for (final o in link.cars[c.lane]) {
      if (identical(o, c)) break;
      final oc = o as SimCar;
      if (identical(oc.next, next) && oc.nextLane == c.nextLane) pending += oc.length + config.minGapM;
    }
    if (_tailRear(next, c.nextLane) - pending < c.length + config.minGapM) return false;
    if (!node.controlled && !node.signal) return true;
    if (node.signal) {
      final light = node.light(link.group, time, config);
      if (light == SignalLight.red) return false;
      if (light == SignalLight.yellow && c.v * c.v / (2 * 3.0) < dEnd) return false; // dá para parar: para
    } else if (link.yields) {
      if (c.v > config.turnMps + 0.5) return false;
      for (final p in node.incoming) {
        if (p.yields || identical(p, link)) continue;
        for (final lane in p.cars) {
          for (final o in lane) {
            final d = p.length - o.s;
            if (d < 0) continue; // já está na esquina: a vez dela é a trava
            if (d / math.max(o.v, 2) < config.gapS && o.v > 0.5) return false;
            break;
          }
        }
      }
    }
    return !node.controlled || _compatible(node, c);
  }

  void _enterJunction(SimCar c) {
    final link = c.link, next = c.next!, mpc = lanes!.mpc;
    final a = link.lanes[c.lane], b = next.lanes[c.nextLane];
    final n = a.xs.length;
    final x0 = a.xs[n - 1], y0 = a.ys[n - 1], x2 = b.xs[0], y2 = b.ys[0];
    final d0x = math.cos(link.headingIn), d0y = math.sin(link.headingIn), d2x = math.cos(next.headingOut), d2y = math.sin(next.headingOut);
    final den = d0x * d2y - d0y * d2x;
    final chord = math.sqrt((x2 - x0) * (x2 - x0) + (y2 - y0) * (y2 - y0));
    var x1 = (x0 + x2) / 2, y1 = (y0 + y2) / 2;
    if (den.abs() > 0.15) {
      final t = ((x2 - x0) * d2y - (y2 - y0) * d2x) / den, u = ((x2 - x0) * d0y - (y2 - y0) * d0x) / den;
      if (t > 0 && u > 0 && t < chord * 3 && u < chord * 3) {
        x1 = x0 + d0x * t;
        y1 = y0 + d0y * t;
      }
    } else if (d0x * d2x + d0y * d2y < -0.5) {
      // Meia-volta: a curva sai para a frente antes de voltar.
      x1 += d0x * math.max(chord, 3 / mpc);
      y1 += d0y * math.max(chord, 3 / mpc);
    }
    double len(double ax, double ay, double bx, double by) => math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay)) * mpc;
    c
      ..bx0 = x0
      ..by0 = y0
      ..bx1 = x1
      ..by1 = y1
      ..bx2 = x2
      ..by2 = y2
      ..clen = math.max(0.3, (len(x0, y0, x1, y1) + len(x1, y1, x2, y2) + chord * mpc) / 2)
      ..inJunction = true;
  }

  void _removeCar(SimCar c) {
    c.gone = true;
    c.link.cars[c.lane].remove(c);
    if (c.holds) _release(c.link.to, c.link, c.lane);
    if (_inView(c.x, c.y, 0)) goneInView++;
  }

  void _place(SimCar c) {
    if (c.inJunction) {
      final t = ((c.s - c.link.lanes[c.lane].length) / c.clen).clamp(0.0, 1.0), m = 1 - t;
      c.x = m * m * c.bx0 + 2 * m * t * c.bx1 + t * t * c.bx2;
      c.y = m * m * c.by0 + 2 * m * t * c.by1 + t * t * c.by2;
      final dx = 2 * m * (c.bx1 - c.bx0) + 2 * t * (c.bx2 - c.bx1), dy = 2 * m * (c.by1 - c.by0) + 2 * t * (c.by2 - c.by1);
      if (dx != 0 || dy != 0) c.heading = math.atan2(dy, dx);
    } else {
      c.seg = c.link.lanes[c.lane].at(c.s, c.seg, _p);
      c.x = _p[0];
      c.y = _p[1];
      c.heading = _p[2];
    }
    if (c.yaw.isNaN) c.yaw = c.heading;
  }

  void _stepCar(SimCar c, SimCarRef? lead, double dt, double speedMult) {
    final link = c.link, len = link.lanes[c.lane].length;
    var v0 = config.speedOf(link.roadClass) * c.vFactor * speedMult;
    var gap = double.infinity, leadV = 0.0;
    if (lead != null) {
      gap = lead.s - lead.length / 2 - c.s - c.length / 2;
      leadV = lead.v;
    }
    if (!c.inJunction) {
      final dEnd = len - c.s;
      if (!c.chosen) _choose(c);
      final leadInside = lead == null || lead.s > len;
      // Decidiu sumir num estacionamento, mas a esquina entrou na vista: segue viagem.
      if (c.next == null && !link.to.border && dEnd < 40 && _inView(link.to.x, link.to.y, hiddenMarginM)) {
        final e = link.to.entry;
        link.to.entry = false;
        _choose(c);
        link.to.entry = e;
      }
      final next = c.next;
      if (next != null) {
        if (!c.straight || link.yields && !link.to.signal) v0 = math.min(v0, math.sqrt(config.turnMps * config.turnMps + 2 * config.brake * math.max(0, dEnd - 3)));
        if (!c.reserved && leadInside && dEnd <= c.v * c.v / (2 * config.brake) + 9 + c.v * dt && _mayEnter(c, dEnd)) {
          c.reserved = true;
          if (link.to.controlled) {
            c.holds = true;
            _hold(link.to, c);
          }
        }
        if (c.reserved) {
          final g = dEnd + _tailRear(next, c.nextLane) - c.length / 2 + 1;
          if (g < gap) {
            gap = g;
            leadV = next.cars[c.nextLane].last.v;
          }
        } else {
          final g = dEnd - c.length / 2;
          if (g < gap) {
            gap = g;
            leadV = 0;
          }
        }
      }
    } else {
      final g = len + c.clen - c.s + _tailRear(c.next!, c.nextLane) - c.length / 2;
      if (g < gap) {
        gap = g;
        leadV = c.next!.cars[c.nextLane].last.v;
      }
      if (!c.straight) v0 = math.min(v0, config.turnMps);
    }
    if (c.blockGap < gap) {
      gap = c.blockGap;
      leadV = c.blockV;
    }
    c.blockGap = double.infinity;
    v0 = math.max(v0, 0.5);
    // IDM.
    final dv = c.v - leadV;
    final sStar = config.minGapM + math.max(0, c.v * config.headwayS + c.v * dv / (2 * math.sqrt(config.accel * config.brake)));
    final r = c.v / v0, g = math.max(gap, 0.1);
    var acc = config.accel * (1 - r * r * r * r - (gap.isFinite ? (sStar / g) * (sStar / g) : 0));
    if (acc < -7) acc = -7;
    var v = c.v + acc * dt;
    if (v < 0) v = 0;
    var ds = (c.v + v) / 2 * dt;
    final room = gap - 0.4;
    if (ds > room) {
      ds = math.max(0, room);
      v = math.min(v, leadV);
    }
    c.v = v;
    c.s += ds;
    c.odo += ds;
    c.waitS = v < 0.1 ? c.waitS + dt : 0;
    if (!c.inJunction && c.s >= len) {
      if (c.next == null) {
        _removeCar(c);
        return;
      }
      if (c.reserved) {
        _enterJunction(c);
      } else {
        c.s = len;
      }
    }
    if (c.inJunction && c.s >= len + c.clen) {
      final next = c.next!;
      link.cars[c.lane].remove(c);
      if (c.holds) _release(link.to, link, c.lane);
      link.edge.wear++;
      c
        ..s = c.s - len - c.clen
        ..link = next
        ..lane = c.nextLane
        ..seg = 0
        ..inJunction = false
        ..reserved = false
        ..holds = false
        ..chosen = false
        ..next = null;
      // Entra atrás de quem já está na faixa.
      final list = next.cars[c.lane];
      if (list.isNotEmpty) c.s = math.min(c.s, math.max(0, list.last.s - list.last.length / 2 - c.length / 2 - 0.4));
      list.add(c);
    }
    _place(c);
    var d = (c.heading - c.yaw) % (2 * math.pi);
    if (d > math.pi) d -= 2 * math.pi;
    c.yaw += d * math.min(1, dt * 7);
  }

  // ---------------------------------------------------------------- passantes

  void _placeWalker(SimWalker w) {
    final mpc = lanes!.mpc;
    if (w.mode == WalkerMode.corner || w.mode == WalkerMode.crossing) {
      final t = w.tLen <= 0 ? 1.0 : (w.tPos / w.tLen).clamp(0.0, 1.0);
      w.x = w.fx + (w.tx - w.fx) * t;
      w.y = w.fy + (w.ty - w.fy) * t;
      if (w.tLen > 0.05) w.heading = math.atan2(w.ty - w.fy, w.tx - w.fx);
      return;
    }
    w.seg = w.edge.walk(w.side).at(w.s, w.seg, _p);
    final h = _p[2];
    w.x = _p[0] - math.sin(h) * w.lat / mpc;
    w.y = _p[1] + math.cos(h) * w.lat / mpc;
    if (w.mode == WalkerMode.walking) w.heading = w.dir > 0 ? h : h + math.pi;
  }

  void _removeWalker(SimWalker w) {
    w.gone = true;
    if (_inView(w.x, w.y, 0)) goneInView++;
  }

  /// A ponta da calçada ([side]) de [e] na esquina da ponta `a` ([atA]) ou `b`.
  void _walkEnd(SimEdge e, int side, bool atA) {
    final t = e.walk(side);
    final i = atA ? 0 : t.xs.length - 1;
    _p[0] = t.xs[i];
    _p[1] = t.ys[i];
  }

  bool _junctionInto(SimNode n, SimLink? out) {
    if (out == null) return false;
    for (final p in n.incoming) {
      for (final lane in p.cars) {
        for (final o in lane) {
          final c = o as SimCar;
          if (!c.inJunction && !c.reserved) break;
          if (identical(c.next, out)) return true;
        }
      }
    }
    return false;
  }

  /// O passante pode atravessar a rua [arm] na esquina [n] agora: no semáforo, com os carros dela no vermelho; sem
  /// semáforo, quando ninguém vem chegando. Quem já está dentro da esquina indo para ela passa antes.
  bool canCross(SimNode n, SimArm arm) {
    if (arm.edge.isPedestrian) return true;
    if (_junctionInto(n, arm.outgoing)) return false;
    if (n.signal && n.light(arm.group, time, config) != SignalLight.red) return false;
    final out = arm.outgoing;
    if (out != null) {
      for (final lane in out.cars) {
        if (lane.isNotEmpty && lane.last.s < lane.last.length / 2 + 1.5) return false; // a fila parou em cima da faixa
      }
    }
    final inc = arm.incoming;
    if (inc == null) return true;
    for (final lane in inc.cars) {
      for (final o in lane) {
        final d = inc.length - o.s;
        if (d < 0) {
          if (-d < o.length / 2 + 1.5) return false; // ainda em cima da faixa
          continue;
        }
        if ((o as SimCar).reserved || (!n.signal && d < 22 && o.v > 1)) return false;
        break;
      }
    }
    return true;
  }

  void _startTransfer(SimWalker w, SimEdge to, int toSide, bool atA, bool crossing) {
    w
      ..fx = w.x
      ..fy = w.y
      ..tEdge = to
      ..tSide = toSide
      ..atA = atA
      ..tPos = 0
      ..mode = crossing ? WalkerMode.waiting : WalkerMode.corner;
    _walkEnd(to, toSide, atA);
    w
      ..tx = _p[0]
      ..ty = _p[1]
      ..tLen = math.sqrt((w.tx - w.fx) * (w.tx - w.fx) + (w.ty - w.fy) * (w.ty - w.fy)) * lanes!.mpc;
  }

  /// Na ponta da calçada: segue por ela, vira a esquina para a rua vizinha ou atravessa a rua (onde pode).
  void _decide(SimWalker w, bool atA) {
    final e = w.edge, node = atA ? e.a : e.b;
    if (node.border || (w.last == 0 && node.entry && !_inView(w.x, w.y, hiddenMarginM) && _u() < 0.15)) {
      _removeWalker(w);
      return;
    }
    final i = node.armOf(e), n = node.arms.length, arm = node.arms[i];
    final right = w.side == arm.rightSide; // do lado direito de quem sai da esquina
    final adj = node.arms[right ? (i + 1) % n : (i - 1 + n) % n];
    final adjSide = right ? -adj.rightSide : adj.rightSide;
    // Rua alagada: o passante sai dela na primeira esquina e não volta.
    final wet = e.flooded ? 0.01 : 1.0;
    final wA = (w.last == 0 ? 0.05 : 3.0) * wet;
    final wB = w.last == 1 ? 0.0 : (adj.edge.flooded ? 0.01 : (n == 1 ? 1.0 : 3.0));
    final wC = (n > 1 && arm.crossable && w.last != 2 ? (w.last == 1 ? 1.0 : 1.5) : 0.0) * wet;
    final pick = _u() * (wA + wB + wC);
    if (pick < wB) {
      _startTransfer(w, adj.edge, adjSide, adj.atA, false);
    } else if (pick < wB + wC) {
      _startTransfer(w, e, -w.side, atA, true);
    } else {
      w
        ..dir = atA ? 1 : -1
        ..last = 0
        ..mode = WalkerMode.walking;
    }
  }

  void _stepWalker(SimWalker w, double dt, double walkMult) {
    final v = w.speed * walkMult;
    switch (w.mode) {
      case WalkerMode.walking:
        final len = w.edge.walk(w.side).length;
        w.v = v;
        w.s += w.dir * v * dt;
        w.odo += v * dt;
        final d = w.latTarget - w.lat;
        w.lat += d.abs() < 0.8 * dt ? d : d.sign * 0.8 * dt;
        if (w.s >= len || w.s <= 0) {
          final atA = w.s <= 0;
          w.s = atA ? 0 : len;
          _placeWalker(w);
          w.lat = 0; // na ponta, todo mundo passa pelo mesmo canto
          _decide(w, atA);
          return;
        }
      case WalkerMode.waiting:
        w.v = 0;
        final node = w.atA ? w.edge.a : w.edge.b;
        final arm = node.arms[node.armOf(w.edge)];
        if (!canCross(node, arm)) return;
        w.mode = WalkerMode.crossing;
        w.atA ? w.edge.crossingA++ : w.edge.crossingB++;
      case WalkerMode.corner:
      case WalkerMode.crossing:
        w.v = v;
        w.tPos += v * dt;
        w.odo += v * dt;
        if (w.tPos >= w.tLen) {
          final crossed = w.mode == WalkerMode.crossing;
          if (crossed) w.atA ? w.edge.crossingA-- : w.edge.crossingB--;
          final to = w.tEdge!;
          w
            ..x = w.tx
            ..y = w.ty
            ..edge = to
            ..side = w.tSide
            ..s = w.atA ? 0 : to.walk(w.tSide).length
            ..seg = 0
            ..tEdge = null
            ..last = crossed ? 2 : 1
            ..mode = WalkerMode.walking;
          _decide(w, w.atA);
          return;
        }
    }
    _placeWalker(w);
  }

  /// Quem vem de frente na mesma calçada desvia cada um para a sua direita; quem alcança um mais lento passa pela esquerda.
  void _avoid() {
    final near = <SimWalker>[];
    for (final w in walkers) {
      w.latTarget = w.latBase;
      if (w.mode == WalkerMode.walking && _inView(w.x, w.y, 10)) near.add(w);
    }
    for (var i = 0; i < near.length; i++) {
      final a = near[i];
      for (var j = i + 1; j < near.length; j++) {
        final b = near[j];
        if (!identical(a.edge, b.edge) || a.side != b.side) continue;
        final ds = b.s - a.s;
        if (ds.abs() > 2.5 || (a.lat - b.lat).abs() > 0.55) continue;
        if (a.dir != b.dir) {
          if ((ds > 0) == (a.dir > 0)) {
            a.latTarget = 0.45 * a.dir;
            b.latTarget = 0.45 * b.dir;
          }
        } else {
          final behind = (ds > 0) == (a.dir > 0) ? a : b, ahead = identical(behind, a) ? b : a;
          if (behind.speed > ahead.speed) behind.latTarget = -0.45 * behind.dir;
        }
      }
    }
  }

  final List<SimCar> _near = [];

  /// A rede de segurança: perto da tela, quem tem outro carro logo à frente fora da sua fila (ruas que se juntam ou se
  /// separam em ângulo raso, onde as faixas se encostam) trata esse carro como o da frente. Lado a lado, cede o de maior id.
  void _blocks() {
    final mpc = lanes!.mpc;
    _near.clear();
    for (final c in cars) {
      if (_inView(c.x, c.y, config.farM)) _near.add(c);
    }
    for (var i = 0; i < _near.length; i++) {
      final a = _near[i];
      final ca = math.cos(a.heading), sa = math.sin(a.heading);
      for (var j = i + 1; j < _near.length; j++) {
        final b = _near[j];
        final dx = (b.x - a.x) * mpc, dy = (b.y - a.y) * mpc;
        if (dx > 9 || dx < -9 || dy > 9 || dy < -9 || (identical(a.link, b.link) && a.lane == b.lane)) continue;
        final cb = math.cos(b.heading), sb = math.sin(b.heading);
        if (ca * cb + sa * sb < -0.2) continue; // de frente um para o outro: a mão contrária
        final fa = dx * ca + dy * sa, la = dy * ca - dx * sa; // b visto de a: à frente e de lado
        final fb = -(dx * cb + dy * sb), lb = -(dy * cb - dx * sb);
        final half = (a.length + b.length) / 2;
        final aSees = fa > 0 && fa < half + 3 && la.abs() < 1.7, bSees = fb > 0 && fb < half + 3 && lb.abs() < 1.7;
        if (aSees && (!bSees || fa > fb || (fa == fb && a.id > b.id))) {
          if (fa - half < a.blockGap) {
            a.blockGap = fa - half;
            a.blockV = b.v;
          }
        } else if (bSees) {
          if (fb - half < b.blockGap) {
            b.blockGap = fb - half;
            b.blockV = a.v;
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- nascer

  bool _inflowClear(SimLink link) {
    final n = link.from;
    if (n.holdLink.isNotEmpty) return false;
    for (final p in n.incoming) {
      for (final lane in p.cars) {
        if (lane.isNotEmpty && identical((lane.first as SimCar).next, link) && p.length - lane.first.s < 25) return false;
      }
    }
    return true;
  }

  void _spawn(double dt, double hour, double density) {
    _spawnDebt = math.min(_spawnDebt + config.spawnPerS * dt, 4);
    final wantCars = carTarget(hour, density), wantWalk = walkerTarget(hour, density);
    while (_spawnDebt >= 1) {
      _spawnDebt -= 1;
      if (cars.length < wantCars && (_carSources.isNotEmpty || _entries.isNotEmpty)) {
        final fromEntry = _carSources.isEmpty || (_entries.isNotEmpty && _u() < 0.25);
        final SimLink link;
        if (fromEntry) {
          final n = _entries[_rng.nextInt(_entries.length)];
          link = n.outgoing[_rng.nextInt(n.outgoing.length)];
        } else {
          link = _carSources[_rng.nextInt(_carSources.length)];
        }
        final lane = _rng.nextInt(link.lanes.length), t = link.lanes[lane];
        if (!link.edge.closed && link.crossingAtStart == 0 && t.length > 10 && !_inView(t.xs[0], t.ys[0], hiddenMarginM + 5) && _tailRear(link, lane) > 12 && (!fromEntry || _inflowClear(link))) {
          final c = _newCar(link, lane, 0, fromEntry ? 0 : config.speedOf(link.roadClass) * 0.7);
          link.cars[lane].add(c);
          _place(c);
          if (_inView(c.x, c.y, 0)) bornInView++;
        }
      }
      if (walkers.length < wantWalk && (_walkSources.isNotEmpty || _entries.isNotEmpty)) {
        final SimEdge e;
        final bool atA;
        if (_walkSources.isEmpty || (_entries.isNotEmpty && _u() < 0.3)) {
          final n = _entries[_rng.nextInt(_entries.length)], arm = n.arms[_rng.nextInt(n.arms.length)];
          e = arm.edge;
          atA = arm.atA;
        } else {
          (e, atA) = _walkSources[_rng.nextInt(_walkSources.length)];
        }
        final side = _u() < 0.5 ? 1 : -1;
        _walkEnd(e, side, atA);
        if (!e.flooded && !_inView(_p[0], _p[1], hiddenMarginM)) {
          final w = _newWalker(e, side, atA ? 1 : -1, atA ? 0 : e.walk(side).length);
          _placeWalker(w);
          if (_inView(w.x, w.y, 0)) bornInView++;
        }
      }
    }
  }

  // ---------------------------------------------------------------- passo

  /// Avança [dt] segundos. [speedMult] e [walkMult] são o clima (chuva e neve deixam tudo mais lento); [density] multiplica
  /// a densidade da [hour] local. No Silêncio, simplesmente não chame: tudo fica onde está e depois continua.
  void step(double dt, {double hour = 12, double density = 1, double speedMult = 1, double walkMult = 1, bool spawn = true}) {
    final g = lanes;
    if (g == null || dt <= 0) return;
    final sw = Stopwatch()..start();
    time += dt;
    _frame++;
    final every = math.max(1, config.farEvery), far = config.farM;
    if (_hasView) _blocks();
    for (final link in g.links) {
      final near = !_hasView || link.edge.touches(_vl, _vt, _vr, _vb, far / g.mpc);
      // Longe da tela: um passo maior a cada [every] quadros (cada rua no seu quadro, para espalhar o custo).
      if (!near && (link.edge.a.id + _frame) % every != 0) continue;
      final h = near ? dt : dt * every;
      for (final lane in link.cars) {
        for (var i = 0; i < lane.length; i++) {
          final c = lane[i] as SimCar;
          final n = lane.length;
          _stepCar(c, i == 0 ? null : lane[i - 1], h, speedMult);
          if (lane.length < n) i--; // saiu da faixa
        }
      }
    }
    for (var i = cars.length - 1; i >= 0; i--) {
      final c = cars[i];
      // Preso há muito tempo longe da vista (nó de trânsito): some, para a cidade não travar.
      if (!c.gone && c.waitS > 120 && !_inView(c.x, c.y, hiddenMarginM)) _removeCar(c);
      if (c.gone) {
        cars[i] = cars.last;
        cars.removeLast();
      }
    }
    _avoid();
    for (var i = walkers.length - 1; i >= 0; i--) {
      final w = walkers[i];
      final near = !_hasView || _inView(w.x, w.y, far);
      if (near || (w.id + _frame) % (every * 2) == 0) _stepWalker(w, near ? dt : dt * every * 2, walkMult);
      if (w.gone) {
        walkers[i] = walkers.last;
        walkers.removeLast();
      }
    }
    if (spawn) _spawn(dt, hour, density);
    lastStepUs = sw.elapsedMicroseconds;
    avgStepUs = avgStepUs == 0 ? lastStepUs.toDouble() : avgStepUs * 0.95 + lastStepUs * 0.05;
  }
}
