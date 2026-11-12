/// Desenha o tráfego do Véu: carros, motos, passantes e ciclistas fantasmas sobre as ruas, por cima do mapa e da luz
/// do dia. Quem decide onde cada fantasma está é `world/veil_traffic.dart`; aqui só se projeta e se pinta, com um
/// teto de fantasmas por quadro para manter o fps.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/astro.dart' show DayLight;
import '../../data/cycle_pack.dart';
import '../../data/traffic_pack.dart';
import '../../world/map_camera.dart';
import '../../world/sim/birds.dart';
import '../../world/sim/cyclists.dart';
import '../../world/sim/traffic_sim.dart';
import '../../world/sim/wind_field.dart';
import '../../world/street_cover.dart' show StreetState;
import '../../world/veil_traffic.dart';
import '../../world/visual_map.dart';
import '../colors.dart';
import 'ghost_sprites.dart';

/// Margem além da tela dentro da qual os fantasmas existem, em metros: quem nasce ou morre aí já está fora da vista.
const double trafficMarginM = 20;

class TrafficPainter {
  TrafficPainter(
    this.visual, {
    required this.carM,
    required this.pedestrianM,
    this.cacheTiles = 96,
    this.maxGhosts = 160,
    this.roadWidthM,
    this.config = const TrafficSimConfig(),
    this.points,
    this.noCrossingAt,
    this.cycleways,
  });

  final VisualMap visual;

  /// O comprimento do carro fantasma e a altura do pedestre fantasma, em metros (`balance.json`).
  final double carM;
  final double pedestrianM;
  final int cacheTiles;
  final int maxGhosts;

  /// Largura das vias por classe (`map.road_width_m`). Sem ela vale o padrão do campo.
  final Map<String, double>? roadWidthM;

  /// Os números da simulação (`balance.json`, `traffic_sim`), os pontos do OSM (semáforos, faixas, entradas) e onde dois
  /// trechos se cruzam sem esquina (viaduto).
  final TrafficSimConfig config;
  final TrafficPointSource? points;
  final bool Function(double x, double y)? noCrossingAt;

  /// As ciclovias do OSM: com elas, os ciclistas pedalam nelas e saem dos caminhos de pedestre.
  final CyclePack? cycleways;
  late final Cyclists cyclists = Cyclists(pack: cycleways);

  /// Os jogos do `events.json` assinado (inícios, UTC).
  List<int> matchUtc = const [];

  final GhostSprites sprites = GhostSprites();
  TrafficSim? _sim;
  int _revision = 0;

  /// A simulação local (debug e testes). `null` antes do primeiro quadro.
  TrafficSim? get sim => _sim;

  final ui.Paint _fill = ui.Paint()..isAntiAlias = false;
  final ui.Paint _layer = ui.Paint();

  /// Quantos fantasmas foram desenhados no último quadro (para conferir o teto).
  int lastDrawn = 0;

  Object? _coverKey;
  LaneGraph? _coverLanes;
  double _coverAt = 0;

  /// Quantos carros viraram barco no último quadro (testes do Dilúvio).
  int lastBoats = 0;

  TrafficGraph _graph() => TrafficGraph(loadTile: visual.tile, cellsPerTile: visual.cellsPerTile, extent: visual.pack.extent, cacheTiles: cacheTiles, stitch: true, noCrossingAt: noCrossingAt);

  TrafficSim _simFor(int seed) {
    final old = _sim;
    if (old != null && old.seed == seed) {
      if (visual.pack.revision != _revision) {
        _revision = visual.pack.revision; // chegou bloco ou região: o grafo guarda tiles antigos
        old.regraph(_graph());
      }
      return old;
    }
    _revision = visual.pack.revision;
    return _sim = TrafficSim(graph: _graph(), seed: seed, config: config, points: points, roadWidthM: roadWidthM ?? const {'principal': 12, 'secondary': 9, 'local': 6, 'pedestrian': 2}, carLengthM: carM);
  }

  // O quadro preparado por [prepare]: quem está na tela, já ordenado, e o que o desenho precisa.
  final _walkers = <(Ghost, double, double)>[], _cars = <(Ghost, double, double)>[];
  ({double rotation, double pxPerM, double night, double t, StreetState Function(GhostLine, double)? streetState, bool skid, String? outfit})? _frame;

  /// Avança a simulação local [dt] segundos em volta do jogador ([px], [py], células z21) e calcula quem aparece neste
  /// quadro. O desenho vem depois, em duas camadas da ordem fixa (`draw_order.dart`): [paintWalkers] e, por cima,
  /// [paintCars]. Com [paused] (o Silêncio), ninguém se mexe e depois todos continuam de onde pararam. [speedMult] e
  /// [walkMult] são o clima: mais devagar e com menos gente na rua.
  void prepare(
    ui.Size view,
    MapCamera cam, {
    required int seed,
    required int tUtc,
    required double lonDeg,
    required double metersPerCell,
    required DayLight light,
    required double px,
    required double py,
    double dt = 1 / 60,
    bool paused = false,
    double speedMult = 1,
    double walkMult = 1,
    double? tUtcExact,
    StreetState Function(GhostLine line, double tUtc)? streetState,
    Object? coverKey,
    bool skid = false,
    String? outfit,
    String? climateId,
    double windRad = 0,
    double? forcedDensity,
  }) {
    lastDrawn = 0;
    lastBoats = 0;
    _walkers.clear();
    _cars.clear();
    _frame = null;
    _birdFrame = null;
    if (visual.pack.version < 2) return; // o pacote antigo não tem a mão única
    final t = tUtcExact ?? tUtc.toDouble();
    final (l, top, r, b) = cam.visibleBounds(view.width, view.height);
    final sim = _simFor(seed)
      ..footpathCyclists = cycleways == null
      ..forcedDensity = forcedDensity; // antes de povoar: a primeira leva já vem na densidade do debug
    final hour = localHour(tUtc, lonDeg);
    final density = sim.config.carDensityIn(speedMult);
    sim.center(px, py, metersPerCell, left: l, top: top, right: r, bottom: b, hour: hour, density: density);
    final lanes = sim.lanes!;
    // O clima das ruas mudou, o grafo foi refeito, ou passou meio minuto (a água sobe, a duna cresce, a neve afunda).
    if (!identical(lanes, _coverLanes) || coverKey != _coverKey || (streetState != null && sim.time - _coverAt > 30)) {
      _coverLanes = lanes;
      _coverKey = coverKey;
      _coverAt = sim.time;
      lanes.applyStreets(streetState == null ? null : (line) => streetState(line, t) == StreetState.blocked, streetState == null ? null : (line) => streetState(line, t) == StreetState.flooded);
    }
    sim.raining = outfit == 'rain'; // os climas de chuva: quem está na rua corre para a marquise
    sim.matchDay = config.matchAt(tUtc, matchUtc);
    if (!paused) sim.step(dt.clamp(0.0, 0.1), hour: hour, density: density, speedMult: speedMult, walkMult: walkMult);
    final lifeSw = Stopwatch()..start();
    if (!paused) {
      birds.update(dt.clamp(0.0, 0.1), px, py, metersPerCell, (x, y) => x >= l - 1 && x <= r + 1 && y >= top - 1 && y <= b + 1);
      birds.updateCritters(dt.clamp(0.0, 0.1), sim.time, hour, px, py, metersPerCell, l, top, r, b);
    }
    _birdFrame = (view: view, cam: cam, pxPerM: cam.pixelsPerCell / metersPerCell);
    _birdT = sim.time;
    // O vento local: só nos climas de vento, na força de cada um.
    final wind = config.windMps[climateId] ?? 0;
    if (climateId != _windId) {
      _windId = climateId;
      leaves.start(sim.time);
    }
    if (!paused) {
      cyclists.update(dt.clamp(0.0, 0.1), px, py, metersPerCell, (forcedDensity ?? pedestrianDensity(hour) * sim.config.walkerDensityIn(walkMult)).clamp(0.0, 1.5), (x, y) => x >= l - 1 && x <= r + 1 && y >= top - 1 && y <= b + 1);
    }
    for (final rd in cyclists.riders) {
      if (rd.x < l - 1 || rd.x > r + 1 || rd.y < top - 1 || rd.y > b + 1) continue;
      final (sx, sy) = cam.cellToScreen(rd.x, rd.y, view.width, view.height);
      _walkers.add((Ghost(id: rd.id, model: GhostModel.cyclist, palette: rd.palette, x: rd.x, y: rd.y, heading: rd.heading, speedMps: rd.speed, phase: GhostPhase.alive, phaseT: 1, travelledM: rd.odo), sx, sy));
    }
    leaves.style = config.windStyle[climateId] ?? 'leaf';
    if (!paused) leaves.update(dt.clamp(0.0, 0.1), lanes, windRad, wind, sim.time, metersPerCell, l, top, r, b);
    lifeUs = lifeUs * 0.95 + lifeSw.elapsedMicroseconds * 0.05;
    _refreshWear(sim);
    final m = trafficMarginM / metersPerCell;
    for (final c in sim.cars) {
      if (c.x < l - m || c.x > r + m || c.y < top - m || c.y > b + m) continue;
      final (sx, sy) = cam.cellToScreen(c.x, c.y, view.width, view.height);
      if (sx < -40 || sy < -40 || sx > view.width + 40 || sy > view.height + 40) continue;
      _cars.add((Ghost(id: c.id, model: c.model, palette: c.palette, x: c.x, y: c.y, heading: c.yaw, speedMps: c.v, phase: GhostPhase.alive, phaseT: 1, travelledM: c.odo, line: c.edge.line, bus: c.bus), sx, sy));
    }
    for (final w in sim.walkers) {
      if (w.x < l - m || w.x > r + m || w.y < top - m || w.y > b + m) continue;
      final (sx, sy) = cam.cellToScreen(w.x, w.y, view.width, view.height);
      if (sx < -40 || sy < -40 || sx > view.width + 40 || sy > view.height + 40) continue;
      _walkers.add((Ghost(id: w.id, model: w.model, palette: w.palette, x: w.x, y: w.y, heading: w.heading, speedMps: w.v, phase: GhostPhase.alive, phaseT: 1, travelledM: w.odo, line: w.edge.line, sitting: w.sitting, dog: w.loiter == null && w.model == GhostModel.adult && w.id % 13 == 0), sx, sy));
    }
    // Dentro de cada camada, do mais ao norte ao mais ao sul da tela.
    _walkers.sort((a, b) => a.$3.compareTo(b.$3));
    _cars.sort((a, b) => a.$3.compareTo(b.$3));
    _frame = (rotation: cam.rotation, pxPerM: cam.pixelsPerCell / metersPerCell, night: light.night, t: t, streetState: streetState, skid: skid, outfit: outfit);
  }

  // As trilhas na neve: quanto os carros deste aparelho já gastaram cada rua (0 a 1, em quatro degraus), revisto de
  // tempos em tempos. O carimbo muda quando algum degrau muda, e a cobertura refaz os blocos.
  Map<(int, int, int), double> _wear = const {};
  double _wearAt = -1e9;
  int wearStamp = 0;

  double wearOf((int, int, int) key) => _wear[key] ?? 0;

  void _refreshWear(TrafficSim sim) {
    if (sim.time - _wearAt < 20) return;
    _wearAt = sim.time;
    final next = <(int, int, int), double>{};
    for (final e in sim.lanes!.edges) {
      if (e.wear < 3) continue;
      final k = (e.key.$1, e.key.$2, e.key.$3), v = math.min(3, e.wear ~/ 3) / 3;
      if (v > (next[k] ?? 0)) next[k] = v;
    }
    if (next.length == _wear.length && next.entries.every((e) => _wear[e.key] == e.value)) return;
    _wear = next;
    wearStamp++;
  }

  /// O ônibus fantasma: comprido, com a faixa de janelas, visto de cima e girando com a rua.
  void _bus(ui.Canvas canvas, Ghost g, double sx, double sy, double rotation, double pxPerM, double night) {
    final len = carM * 2.2 * pxPerM, wid = 2.6 * pxPerM, u = math.max(2.0, (pxPerM * 0.3).roundToDouble());
    canvas.save();
    canvas.translate(sx, sy);
    canvas.rotate(g.heading + rotation);
    canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset.zero, width: len + u, height: wid + u), _fill..color = kOutline);
    canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset.zero, width: len, height: wid), _fill..color = const ui.Color(0xFF5B4BA8));
    canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset.zero, width: len - 2 * u, height: wid - 2 * u), _fill..color = const ui.Color(0xFF7B6BD0));
    for (var x = -len / 2 + 2 * u; x < len / 2 - 3 * u; x += 3 * u) {
      canvas.drawRect(ui.Rect.fromLTWH(x, -wid / 2 + u, 2 * u, u), _fill..color = kSignal.withValues(alpha: night > 0.5 ? 0.95 : 0.6));
      canvas.drawRect(ui.Rect.fromLTWH(x, wid / 2 - 2 * u, 2 * u, u), _fill);
    }
    canvas.drawRect(ui.Rect.fromLTWH(len / 2 - 2 * u, -wid / 2 + u, u, wid - 2 * u), _fill..color = const ui.Color(0xFFE8E4F4).withValues(alpha: 0.8));
    canvas.restore();
    if (night > 0.5) {
      final a = g.heading + rotation;
      canvas.drawCircle(ui.Offset(sx + math.cos(a) * len * 0.55, sy + math.sin(a) * len * 0.55), u * 2, _fill..color = kSignal.withValues(alpha: 0.35));
    }
  }

  /// O cachorro do passeio: um corpinho de quatro pixels atrás do dono, do lado para onde ele anda, com a guia.
  void _dog(ui.Canvas canvas, Ghost g, double sx, double sy, double rotation, double pxPerM) {
    final u = math.max(2.0, (pxPerM * 0.2).roundToDouble()), a = g.heading + rotation;
    final dx = (sx - math.cos(a) * pxPerM * 1.1 - math.sin(a) * pxPerM * 0.5).roundToDouble(), dy = (sy - math.sin(a) * pxPerM * 1.1 + math.cos(a) * pxPerM * 0.5).roundToDouble();
    final step = (g.travelledM / 0.3).floor().isEven ? 0.0 : u, right = math.cos(a) >= 0;
    canvas.drawLine(ui.Offset(sx, sy - pedestrianM * pxPerM * 0.45), ui.Offset(dx, dy - u * 2), ui.Paint()..color = kOutline.withValues(alpha: 0.6)..strokeWidth = 1);
    canvas.drawRect(ui.Rect.fromLTWH(dx - u * 1.5, dy - u * 2, u * 3, u), _fill..color = const ui.Color(0xFFB8875A));
    canvas.drawRect(ui.Rect.fromLTWH(dx + (right ? u * 1.5 : -u * 2.5), dy - u * 3, u, u * 2), _fill);
    canvas.drawRect(ui.Rect.fromLTWH(dx - u * 1.5 + step, dy - u, u, u), _fill..color = const ui.Color(0xFF7A5536));
    canvas.drawRect(ui.Rect.fromLTWH(dx + u * 0.5 - step, dy - u, u, u), _fill);
  }

  /// O custo médio dos bichos e do vento por quadro (atualizar e desenhar), em microssegundos.
  double lifeUs = 0;

  /// As folhas e os papéis que o vento local leva pelo chão (cenário).
  late final WindLeaves leaves = WindLeaves(count: config.leaves);
  String? _windId;

  void paintLeaves(ui.Canvas canvas) {
    final f = _birdFrame;
    if (f == null || leaves.leaves.isEmpty) return;
    final u = math.max(2.0, (f.pxPerM * 0.14).roundToDouble());
    const leaf = [0xFF6FA35A, 0xFFD08A3C, 0xFFE8E4F4, 0xFF8A6A4A], smoke = [0xFF8E8A9A, 0xFFA9A5B5, 0xFF75717F, 0xFF9B97A8];
    const soot = [0xFF1A1424, 0xFF2A2236, 0xFF1A1424, 0xFF3A3248], sand = [0xFFE0C27A, 0xFFF2DCA4, 0xFFC9A862, 0xFFE0C27A];
    final style = leaves.style;
    final colors = switch (style) { 'smoke' => smoke, 'soot' => soot, 'sand' => sand, _ => leaf };
    for (final lf in leaves.leaves) {
      final (sx, sy) = f.cam.cellToScreen(lf.x, lf.y, f.view.width, f.view.height);
      if (sx < -10 || sy < -10 || sx > f.view.width + 10 || sy > f.view.height + 10) continue;
      final flat = (lf.spin).floor().isEven; // gira: ora de lado, ora de frente
      final x = sx.roundToDouble(), y = sy.roundToDouble(), c = ui.Color(colors[lf.kind]);
      switch (style) {
        case 'smoke': // um tufo: três pixels grandes que se abrem enquanto somem
          final a = (lf.life / 8).clamp(0.0, 0.5);
          canvas.drawRect(ui.Rect.fromLTWH(x, y, u * 3, u * 2), _fill..color = c.withValues(alpha: a));
          canvas.drawRect(ui.Rect.fromLTWH(x + u, y - u, u * 2, u), _fill);
        case 'soot':
          canvas.drawRect(ui.Rect.fromLTWH(x, y, u, u), _fill..color = c.withValues(alpha: 0.8));
        case 'sand':
          canvas.drawRect(ui.Rect.fromLTWH(x, y, flat ? u * 3 : u * 2, u), _fill..color = c.withValues(alpha: 0.7));
        default:
          canvas.drawRect(ui.Rect.fromLTWH(x, y, flat ? u * 2 : u, u), _fill..color = c.withValues(alpha: 0.85));
      }
    }
  }

  /// Os pombos das praças (cenário local).
  late final BirdFlocks birds = BirdFlocks(points: points);
  ({ui.Size view, MapCamera cam, double pxPerM})? _birdFrame;
  double _birdT = 0;

  /// Os pombos do quadro preparado: no chão, um corpinho cinza que cisca; no ar, as asas batendo e a sombra embaixo.
  void paintBirds(ui.Canvas canvas) {
    final f = _birdFrame;
    if (f == null) return;
    final sw = Stopwatch()..start();
    final u = math.max(4.0, (f.pxPerM * 0.5).roundToDouble()); // bem maior que o pombo de verdade: senão some no chão
    bool off(double sx, double sy) => sx < -40 || sy < -40 || sx > f.view.width + 40 || sy > f.view.height + 40;
    void bird(Bird b, int body, int wing, double unit, {bool always = false}) {
      final (sx, sy) = f.cam.cellToScreen(b.x, b.y, f.view.width, f.view.height);
      if (off(sx, sy)) return;
      final lift = b.height * unit * 7, x = sx.roundToDouble(), y = (sy - lift).roundToDouble();
      // A sombra fica no chão: embaixo do bicho parado, para trás e menor quando ele sobe.
      canvas.drawRect(ui.Rect.fromLTWH(x - unit, sy.roundToDouble(), unit * (b.height > 0.5 ? 1.5 : 2), unit * 0.5), _fill..color = kOutline.withValues(alpha: 0.3));
      if (b.height > 0 || always) {
        // Bater de asas: três quadros (para cima, abertas, para baixo).
        final k = (b.phase * 12).floor() % 3, wy = k == 0 ? -unit : (k == 1 ? 0.0 : unit * 0.5);
        canvas.drawRect(ui.Rect.fromLTWH(x - unit * 2, y - unit + wy, unit, unit), _fill..color = ui.Color(wing));
        canvas.drawRect(ui.Rect.fromLTWH(x + unit, y - unit + wy, unit, unit), _fill);
        if (k == 1) {
          canvas.drawRect(ui.Rect.fromLTWH(x - unit * 3, y - unit, unit, unit * 0.5), _fill);
          canvas.drawRect(ui.Rect.fromLTWH(x + unit * 2, y - unit, unit, unit * 0.5), _fill);
        }
      }
      final peck = b.height == 0 && (b.phase * 3).floor() % 4 == 0;
      canvas.drawRect(ui.Rect.fromLTWH(x - unit, y - unit, unit * 2, unit), _fill..color = ui.Color(body));
      canvas.drawRect(ui.Rect.fromLTWH(x + (b.left ? -unit * 2 : unit), y - (peck ? unit : unit * 2), unit, unit), _fill..color = const ui.Color(0xFF5E6478));
    }

    for (final flock in birds.flocks.values) {
      for (final b in flock.birds) {
        bird(b, 0xFFC9CEDD, 0xFFFFFFFF, u);
      }
    }
    // Maritacas: verdes, sempre batendo asa, mais alto.
    for (final p in birds.parrots) {
      bird(p, 0xFF4FA83A, 0xFF7ED957, u * 0.8, always: true);
    }
    // Gatos: sentados, com as orelhas e o rabo que balança de vez em quando.
    for (final c in birds.cats.entries) {
      final (sx, sy) = f.cam.cellToScreen(c.value.$1, c.value.$2, f.view.width, f.view.height);
      if (off(sx, sy)) continue;
      final x = sx.roundToDouble(), y = sy.roundToDouble(), k = c.key.$1 & 3, flick = ((f.pxPerM + (_birdT * 1.3 + k)).floor() % 5 == 0) ? -u : 0.0;
      final fur = const [0xFF2A2236, 0xFFD08A3C, 0xFFE8E4F4, 0xFF75717F][k];
      canvas.drawRect(ui.Rect.fromLTWH(x - u, y, u * 2.5, u * 0.5), _fill..color = kOutline.withValues(alpha: 0.3));
      canvas.drawRect(ui.Rect.fromLTWH(x - u, y - u * 2, u * 2, u * 2), _fill..color = ui.Color(fur));
      canvas.drawRect(ui.Rect.fromLTWH(x - u, y - u * 3, u * 0.7, u), _fill);
      canvas.drawRect(ui.Rect.fromLTWH(x + u * 0.3, y - u * 3, u * 0.7, u), _fill);
      canvas.drawRect(ui.Rect.fromLTWH(x + u, y - u + flick, u, u * 0.6), _fill);
      canvas.drawRect(ui.Rect.fromLTWH(x - u * 0.6, y - u * 1.6, u * 0.4, u * 0.4), _fill..color = kSignal);
    }
    // Morcegos: um V escuro que abre e fecha.
    for (final (i, m) in birds.bats.indexed) {
      final (sx, sy) = f.cam.cellToScreen(m.$1, m.$2, f.view.width, f.view.height);
      if (off(sx, sy)) continue;
      final x = sx.roundToDouble(), y = sy.roundToDouble(), open = ((_birdT * 10).floor() + i).isEven, w = u * 0.8;
      canvas.drawRect(ui.Rect.fromLTWH(x - w * 0.5, y, w, w), _fill..color = const ui.Color(0xFF1A1424));
      canvas.drawRect(ui.Rect.fromLTWH(x - w * (open ? 2.5 : 1.5), y - (open ? w : 0), w * (open ? 2 : 1), w * 0.6), _fill);
      canvas.drawRect(ui.Rect.fromLTWH(x + w * 0.5, y - (open ? w : 0), w * (open ? 2 : 1), w * 0.6), _fill);
    }
    lifeUs += sw.elapsedMicroseconds * 0.05;
  }

  /// Debug: o raio simulado, as bordas, as entradas e a luz de cada semáforo (um ponto por acesso, na cor da fase).
  void paintDebug(ui.Canvas canvas, ui.Size view, MapCamera cam, double metersPerCell) {
    final sim = _sim, g = sim?.lanes;
    if (sim == null || g == null) return;
    final (cx, cy) = cam.cellToScreen(g.cx, g.cy, view.width, view.height);
    final ring = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = kVeil;
    canvas.drawCircle(ui.Offset(cx, cy), g.radiusM / metersPerCell * cam.pixelsPerCell, ring);
    final dot = cam.pixelsPerCell / metersPerCell * 1.2;
    for (final n in g.nodes) {
      final (sx, sy) = cam.cellToScreen(n.x, n.y, view.width, view.height);
      if (sx < -20 || sy < -20 || sx > view.width + 20 || sy > view.height + 20) continue;
      if (n.entry) canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset(sx, sy), width: dot * 2, height: dot * 2), _fill..color = kSignal);
      if (!n.signal) continue;
      for (final k in n.incoming) {
        final tr = k.lanes[0], i = tr.xs.length - 1;
        final (lx, ly) = cam.cellToScreen(tr.xs[i], tr.ys[i], view.width, view.height);
        final light = n.light(k.group, sim.time, sim.config);
        canvas.drawCircle(ui.Offset(lx, ly), dot, _fill..color = switch (light) { SignalLight.green => const ui.Color(0xFF4CD964), SignalLight.yellow => const ui.Color(0xFFFFD60A), SignalLight.red => const ui.Color(0xFFFF453A) });
      }
    }
  }

  /// Os passantes do quadro preparado.
  void paintWalkers(ui.Canvas canvas) => _paintGhosts(canvas, _walkers);

  /// Os carros (e barcos) do quadro preparado, por cima dos passantes.
  void paintCars(ui.Canvas canvas) => _paintGhosts(canvas, _cars);

  void _paintGhosts(ui.Canvas canvas, List<(Ghost, double, double)> list) {
    final f = _frame;
    if (f == null) return;
    for (final (g, sx, sy) in list) {
      final line = g.line, state = f.streetState;
      if (state != null && g.kind == GhostKind.car && line != null && state(line, f.t) == StreetState.flooded) {
        drawBoat(canvas, g, sx, sy, f.rotation, f.pxPerM, f.t);
        lastBoats++;
      } else {
        // Gelo (Chuva congelante): o carro derrapa, balançando a frente.
        final wobble = f.skid && g.kind == GhostKind.car ? math.sin(f.t * 2.3 + (g.id & 0xff)) * 0.35 : 0.0;
        if (g.bus) {
          _bus(canvas, g, sx, sy, f.rotation, f.pxPerM, f.night);
        } else if (g.sitting) {
          // Sentado: só o tronco aparece, mais baixo, com o banco embaixo.
          final u = math.max(2.0, f.pxPerM * 0.25);
          canvas.drawRect(ui.Rect.fromLTWH(sx - u * 2.5, sy - u, u * 5, u), _fill..color = kOutline.withValues(alpha: 0.5));
          canvas.save();
          canvas.clipRect(ui.Rect.fromLTWH(sx - 60, sy - 200, 120, 200 - u));
          drawGhost(canvas, g, sx, sy + pedestrianM * f.pxPerM * 0.3, f.rotation, f.pxPerM, f.night, outfit: f.outfit);
          canvas.restore();
        } else {
          drawGhost(canvas, g, sx, sy, f.rotation + wobble, f.pxPerM, f.night, outfit: f.outfit);
          if (g.dog) _dog(canvas, g, sx, sy, f.rotation, f.pxPerM);
        }
      }
      lastDrawn++;
    }
  }

  /// O barco (ou canoa) fantasma na rua alagada, com a esteira atrás.
  void drawBoat(ui.Canvas canvas, Ghost g, double sx, double sy, double rotation, double pxPerM, double t) {
    final rows = boatRowsOf(g.model);
    final unit = carM * pxPerM / carRefPx;
    final w = rows.first.length * unit, h = rows.length * unit;
    final a = g.heading + rotation;
    _fill.color = const ui.Color(0xFFE8E4F4).withValues(alpha: 0.35 * g.alpha);
    for (var i = 1; i <= 3; i++) {
      final back = w / 2 + i * unit * 2, side = (i.isEven ? 1 : -1) * unit * (1 + math.sin(t * 4 + i));
      canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset(sx - math.cos(a) * back - math.sin(a) * side, sy - math.sin(a) * back + math.cos(a) * side), width: unit, height: unit), _fill);
    }
    canvas.save();
    canvas.translate(sx, sy);
    canvas.rotate(a + math.sin(t * 1.7 + (g.id & 0xff)) * 0.06); // balança na água
    canvas.translate(-w / 2, -h / 2);
    canvas.scale(unit);
    canvas.drawPicture(sprites.boat(g.model, g.palette));
    canvas.restore();
  }

  /// Desenha um fantasma na tela em ([sx], [sy]). Os de pé ficam em pé (os pés na posição) e alternam dois quadros
  /// de caminhada; os outros giram com o mapa. [pxPerM] são pixels de tela por metro. Com [outfit] (o grupo de roupa do
  /// clima, `clima.json`), cada passante de pé veste a peça que a identidade dele sorteia.
  void drawGhost(ui.Canvas canvas, Ghost g, double sx, double sy, double rotation, double pxPerM, double night, {String? outfit}) {
    final m = g.model;
    final upright = isUpright(m);
    final dress = upright ? ghostOutfit(outfit, g.id) : GhostOutfit.none;
    final (cols, rows) = sprites.sizeOf(m, dress);
    var unit = (m.kind == GhostKind.car ? carM * pxPerM / carRefPx : pedestrianM * pxPerM / pedRefPx);
    if (upright) unit = math.max(1.0, (unit * 2).round() / 2);
    final frame = upright ? (g.travelledM / 0.6).floor() & 1 : 0;
    final pic = sprites.picture(m, g.palette, frame, dress);
    final fading = g.phase != GhostPhase.alive;
    final w = cols * unit, h = rows * unit;
    if (fading) {
      final pad = 2 * unit;
      canvas.saveLayer(ui.Rect.fromCenter(center: ui.Offset(sx, sy), width: 2 * (math.max(w, h) + pad), height: 2 * (math.max(w, h) + pad)), _layer..color = ui.Color.fromARGB((g.alpha * 255).round(), 255, 255, 255));
    }
    canvas.save();
    if (upright) {
      _fill.color = kOutline.withValues(alpha: 0.28);
      canvas.drawRect(ui.Rect.fromLTWH(sx - w * 0.45, sy - unit, w * 0.9, unit * 1.6), _fill);
      canvas.translate(sx - w / 2, sy - h);
    } else {
      canvas.translate(sx, sy);
      canvas.rotate(g.heading + rotation);
      canvas.translate(-w / 2, -h / 2);
    }
    canvas.scale(unit);
    canvas.drawPicture(pic);
    canvas.restore();
    if (night > 0.5 && m.kind == GhostKind.car) {
      final a = g.heading + rotation;
      _fill.color = kSignal.withValues(alpha: 0.35 * g.alpha);
      canvas.drawCircle(ui.Offset(sx + math.cos(a) * w * 0.62, sy + math.sin(a) * w * 0.62), unit * 1.6, _fill);
    }
    if (fading) {
      canvas.restore();
      _seam(canvas, g, sx, sy, upright ? w : math.max(w, h), upright ? h : math.max(w, h) * 0.6, unit, upright);
    }
  }

  /// A costura do Véu: pixels violeta que se soltam ao redor de quem se forma ou se desfaz.
  void _seam(ui.Canvas canvas, Ghost g, double sx, double sy, double w, double h, double unit, bool upright) {
    final fade = 1 - g.alpha;
    if (fade <= 0.02) return;
    final cy = upright ? sy - h / 2 : sy;
    for (var i = 0; i < 7; i++) {
      final hv = (g.id >>> (i * 7)) & 0x7f;
      final dx = ((hv & 0xf) / 15 - 0.5) * (w + 2 * unit), dy = ((hv >>> 4) / 7 - 0.5) * (h + 2 * unit);
      _fill.color = kVeil.withValues(alpha: 0.85 * fade);
      canvas.drawRect(ui.Rect.fromLTWH(sx + dx, cy + dy, unit, unit), _fill);
    }
  }
}
