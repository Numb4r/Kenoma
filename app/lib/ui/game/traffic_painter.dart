/// Desenha o tráfego do Véu: carros, motos, passantes e ciclistas fantasmas sobre as ruas, por cima do mapa e da luz
/// do dia. Quem decide onde cada fantasma está é `world/veil_traffic.dart`; aqui só se projeta e se pinta, com um
/// teto de fantasmas por quadro para manter o fps.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/astro.dart' show DayLight;
import '../../data/traffic_pack.dart';
import '../../world/map_camera.dart';
import '../../world/sim/traffic_sim.dart';
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
  }) {
    lastDrawn = 0;
    lastBoats = 0;
    _walkers.clear();
    _cars.clear();
    _frame = null;
    if (visual.pack.version < 2) return; // o pacote antigo não tem a mão única
    final t = tUtcExact ?? tUtc.toDouble();
    final (l, top, r, b) = cam.visibleBounds(view.width, view.height);
    final sim = _simFor(seed);
    final hour = localHour(tUtc, lonDeg);
    final density = sim.config.carDensityIn(speedMult);
    sim.center(px, py, metersPerCell, left: l, top: top, right: r, bottom: b, hour: hour, density: density);
    final lanes = sim.lanes!;
    if (!identical(lanes, _coverLanes) || coverKey != _coverKey) {
      _coverLanes = lanes; // o clima das ruas mudou, ou o grafo foi refeito
      _coverKey = coverKey;
      lanes.applyStreets(streetState == null ? null : (line) => streetState(line, t) == StreetState.blocked, streetState == null ? null : (line) => streetState(line, t) == StreetState.flooded);
    }
    if (!paused) sim.step(dt.clamp(0.0, 0.1), hour: hour, density: density, speedMult: speedMult, walkMult: walkMult);
    final m = trafficMarginM / metersPerCell;
    for (final c in sim.cars) {
      if (c.x < l - m || c.x > r + m || c.y < top - m || c.y > b + m) continue;
      final (sx, sy) = cam.cellToScreen(c.x, c.y, view.width, view.height);
      if (sx < -40 || sy < -40 || sx > view.width + 40 || sy > view.height + 40) continue;
      _cars.add((Ghost(id: c.id, model: c.model, palette: c.palette, x: c.x, y: c.y, heading: c.yaw, speedMps: c.v, phase: GhostPhase.alive, phaseT: 1, travelledM: c.odo, line: c.edge.line), sx, sy));
    }
    for (final w in sim.walkers) {
      if (w.x < l - m || w.x > r + m || w.y < top - m || w.y > b + m) continue;
      final (sx, sy) = cam.cellToScreen(w.x, w.y, view.width, view.height);
      if (sx < -40 || sy < -40 || sx > view.width + 40 || sy > view.height + 40) continue;
      _walkers.add((Ghost(id: w.id, model: w.model, palette: w.palette, x: w.x, y: w.y, heading: w.heading, speedMps: w.v, phase: GhostPhase.alive, phaseT: 1, travelledM: w.odo, line: w.edge.line), sx, sy));
    }
    // Dentro de cada camada, do mais ao norte ao mais ao sul da tela.
    _walkers.sort((a, b) => a.$3.compareTo(b.$3));
    _cars.sort((a, b) => a.$3.compareTo(b.$3));
    _frame = (rotation: cam.rotation, pxPerM: cam.pixelsPerCell / metersPerCell, night: light.night, t: t, streetState: streetState, skid: skid, outfit: outfit);
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
        drawGhost(canvas, g, sx, sy, f.rotation + wobble, f.pxPerM, f.night, outfit: f.outfit);
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
