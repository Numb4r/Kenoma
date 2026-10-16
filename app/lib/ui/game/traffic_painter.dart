/// Desenha o tráfego do Véu: carros, motos, passantes e ciclistas fantasmas sobre as ruas, por cima do mapa e da luz
/// do dia. Quem decide onde cada fantasma está é `world/veil_traffic.dart`; aqui só se projeta e se pinta, com um
/// teto de fantasmas por quadro para manter o fps.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/astro.dart' show DayLight;
import '../../world/map_camera.dart';
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
  });

  final VisualMap visual;

  /// O comprimento do carro fantasma e a altura do pedestre fantasma, em metros (`balance.json`).
  final double carM;
  final double pedestrianM;
  final int cacheTiles;
  final int maxGhosts;

  /// Largura das vias por classe (`map.road_width_m`). Sem ela vale o padrão do campo.
  final Map<String, double>? roadWidthM;

  final GhostSprites sprites = GhostSprites();
  TrafficField? _field;
  TrafficGraph? _graph;

  final ui.Paint _fill = ui.Paint()..isAntiAlias = false;
  final ui.Paint _layer = ui.Paint();

  /// Quantos fantasmas foram desenhados no último quadro (para conferir o teto).
  int lastDrawn = 0;

  // Relógio contínuo: o jogo entrega segundos inteiros, e o fantasma anda por quadro.
  final Stopwatch _sw = Stopwatch()..start();
  double _t = -1e18;
  int _lastElapsedUs = 0;

  double _timeFor(int tUtc) {
    final now = _sw.elapsedMicroseconds;
    final dt = ((now - _lastElapsedUs) / 1e6).clamp(0.0, 0.25);
    _lastElapsedUs = now;
    final mid = tUtc + 0.5;
    if ((_t - mid).abs() > 2.5) {
      _t = mid; // primeiro quadro, ou o relógio pulou (debug)
    } else {
      _t += dt + (mid - _t) * 0.02;
    }
    return _t;
  }

  TrafficField _fieldFor(int seed) {
    final graph = _graph ??= TrafficGraph(loadTile: visual.tile, cellsPerTile: visual.cellsPerTile, extent: visual.pack.extent, cacheTiles: cacheTiles);
    final f = _field;
    if (f != null && f.seed == seed) return f;
    final roadWidths = roadWidthM;
    return _field = roadWidths == null ? TrafficField(graph: graph, seed: seed) : TrafficField(graph: graph, seed: seed, roadWidthM: roadWidths);
  }

  /// Desenha o tráfego. A cada quadro: passe `tUtc` (segundos inteiros) e, se tiver, `tUtcExact` (UTC fracionário, de
  /// preferência do relógio do jogo) para o movimento ser contínuo. Não há nada a avisar numa troca de câmera: as
  /// posições não dependem dela. `lonDeg` e `metersPerCell` ficam por compatibilidade: o campo usa a latitude e a
  /// longitude do tile para que o grupo veja a mesma coisa.
  void paint(
    ui.Canvas canvas,
    ui.Size view,
    MapCamera cam, {
    required int seed,
    required int tUtc,
    required double lonDeg,
    required double metersPerCell,
    required DayLight light,
    double? tUtcExact,
  }) {
    lastDrawn = 0;
    if (visual.pack.version < 2) return; // o pacote antigo não tem a mão única
    final t = tUtcExact ?? _timeFor(tUtc);
    final (l, top, r, b) = cam.visibleBounds(view.width, view.height);
    final m = trafficMarginM / metersPerCell;
    final ghosts = _fieldFor(seed).ghostsIn(t, l - m, top - m, r + m, b + m, maxGhosts: maxGhosts);
    final pxPerM = cam.pixelsPerCell / metersPerCell;
    final night = light.night;
    final onScreen = <(Ghost, double, double)>[];
    for (final g in ghosts) {
      final (sx, sy) = cam.cellToScreen(g.x, g.y, view.width, view.height);
      if (sx < -40 || sy < -40 || sx > view.width + 40 || sy > view.height + 40) continue;
      onScreen.add((g, sx, sy));
    }
    // De baixo para cima: carros primeiro, depois quem anda a pé, do mais ao norte ao mais ao sul da tela.
    onScreen.sort((a, b) {
      final k = (a.$1.kind == GhostKind.car ? 0 : 1) - (b.$1.kind == GhostKind.car ? 0 : 1);
      return k != 0 ? k : a.$3.compareTo(b.$3);
    });
    for (final (g, sx, sy) in onScreen) {
      drawGhost(canvas, g, sx, sy, cam.rotation, pxPerM, night);
      lastDrawn++;
    }
  }

  /// Desenha um fantasma na tela em ([sx], [sy]). Os de pé ficam em pé (os pés na posição) e alternam dois quadros
  /// de caminhada; os outros giram com o mapa. [pxPerM] são pixels de tela por metro.
  void drawGhost(ui.Canvas canvas, Ghost g, double sx, double sy, double rotation, double pxPerM, double night) {
    final m = g.model;
    final (cols, rows) = sprites.sizeOf(m);
    final upright = isUpright(m);
    var unit = (m.kind == GhostKind.car ? carM * pxPerM / carRefPx : pedestrianM * pxPerM / pedRefPx);
    if (upright) unit = math.max(1.0, (unit * 2).round() / 2);
    final frame = upright ? (g.travelledM / 0.6).floor() & 1 : 0;
    final pic = sprites.picture(m, g.palette, frame);
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
