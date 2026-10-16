/// Desenha o tráfego do Véu: carros e pedestres fantasmas sobre as ruas, por cima do mapa e da luz do dia. Quem
/// decide onde cada fantasma está é `world/veil_traffic.dart`; aqui só se projeta e se pinta, com um teto de
/// fantasmas por quadro para manter o fps.
library;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/astro.dart' show DayLight;
import '../../world/map_camera.dart';
import '../../world/veil_traffic.dart';
import '../../world/visual_map.dart';
import '../colors.dart';

class TrafficPainter {
  TrafficPainter(this.visual, {required this.carM, required this.pedestrianM, this.cacheTiles = 96, this.maxGhosts = 160});

  final VisualMap visual;

  /// O comprimento do carro fantasma e a altura do pedestre fantasma, em metros (`balance.json`).
  final double carM;
  final double pedestrianM;
  final int cacheTiles;
  final int maxGhosts;

  final LinkedHashMap<(int, int), List<GhostLine>> _lines = LinkedHashMap();
  final ui.Paint _fill = ui.Paint()..isAntiAlias = false;
  final ui.Paint _glow = ui.Paint()..isAntiAlias = false;

  /// Quantos fantasmas foram desenhados no último quadro (para conferir o teto).
  int lastDrawn = 0;

  List<GhostLine> _linesOf(int tx, int ty) {
    final key = (tx, ty);
    final cached = _lines.remove(key);
    if (cached != null) {
      _lines[key] = cached;
      return cached;
    }
    final tile = visual.tile(tx, ty);
    final out = tile == null ? const <GhostLine>[] : ghostLinesOfTile(tile, tx, ty, cellsPerTile: visual.cellsPerTile, extent: visual.pack.extent);
    _lines[key] = out;
    while (_lines.length > cacheTiles) {
      _lines.remove(_lines.keys.first);
    }
    return out;
  }

  void paint(
    ui.Canvas canvas,
    ui.Size view,
    MapCamera cam, {
    required int seed,
    required int tUtc,
    required double lonDeg,
    required double metersPerCell,
    required DayLight light,
  }) {
    lastDrawn = 0;
    if (visual.pack.version < 2) return; // o pacote antigo não tem a mão única
    final (l, t, r, b) = cam.visibleBounds(view.width, view.height);
    const pad = 4.0; // células de folga: o fantasma tem corpo e a rua passa da borda
    final hour = localHour(tUtc, lonDeg);
    final pxPerM = cam.pixelsPerCell / metersPerCell;
    final night = light.night;
    for (final id in visual.tilesIn(l, t, r, b, marginCells: pad)) {
      for (final line in _linesOf(id.$1, id.$2)) {
        if (line.maxX < l - pad || line.minX > r + pad || line.maxY < t - pad || line.minY > b + pad) continue;
        for (final g in ghostsOn(line, seed: seed, tUtc: tUtc, hour: hour, metersPerCell: metersPerCell)) {
          if (lastDrawn >= maxGhosts) return;
          final (sx, sy) = cam.cellToScreen(g.x, g.y, view.width, view.height);
          if (sx < -20 || sy < -20 || sx > view.width + 20 || sy > view.height + 20) continue;
          lastDrawn++;
          _draw(canvas, g, sx, sy, cam.rotation, pxPerM, night);
        }
      }
    }
  }

  void _draw(ui.Canvas canvas, Ghost g, double sx, double sy, double rotation, double pxPerM, double night) {
    final tone = night > 0.5 ? kSignal : kVeil;
    if (g.kind == GhostKind.pedestrian) {
      // Um boneco de pixels de 13 de altura: cabeça, tronco e duas pernas que se alternam com a posição. A altura em
      // metros vem do balanceamento; o "pixel" do boneco é essa altura dividida por 13.
      final u = math.max(1.0, pedestrianM * pxPerM / 13);
      final swing = (math.sin((sx + sy) * 0.35 + g.seed % 7) > 0) ? 1.0 : -1.0;
      _fill.color = (night > 0.5 ? kSignal : kText).withValues(alpha: 0.55 * g.alpha);
      final left = sx - 1.5 * u, top = sy - 6.5 * u;
      canvas.drawRect(ui.Rect.fromLTWH(left, top, 3 * u, 3 * u), _fill); // cabeça
      canvas.drawRect(ui.Rect.fromLTWH(left - 0.5 * u, top + 3.5 * u, 4 * u, 5 * u), _fill); // tronco
      canvas.drawRect(ui.Rect.fromLTWH(left + (swing > 0 ? 0 : 1.5 * u), top + 8.5 * u, 1.5 * u, 4.5 * u), _fill); // pernas
      canvas.drawRect(ui.Rect.fromLTWH(left + (swing > 0 ? 1.5 * u : 0), top + 8.5 * u, 1.5 * u, 3.5 * u), _fill);
      return;
    }
    // O carro: um retângulo de [carM] de comprimento e ~45% disso de largura, girado com o mapa. De dia é um vulto
    // violeta; à noite brilha em ciano.
    final len = math.max(5.0, carM * pxPerM) / 2, wid = math.max(2.4, carM * 0.45 * pxPerM) / 2;
    final a = g.heading + rotation, ca = math.cos(a), sa = math.sin(a);
    ui.Offset p(double u, double v) => ui.Offset(sx + u * ca - v * sa, sy + u * sa + v * ca);
    final body = ui.Path()
      ..moveTo(p(-len, -wid).dx, p(-len, -wid).dy)
      ..lineTo(p(len, -wid).dx, p(len, -wid).dy)
      ..lineTo(p(len, wid).dx, p(len, wid).dy)
      ..lineTo(p(-len, wid).dx, p(-len, wid).dy)
      ..close();
    _fill.color = tone.withValues(alpha: (0.45 + 0.3 * night) * g.alpha);
    canvas.drawPath(body, _fill);
    final head = p(len * 0.8, 0); // um ponto claro na frente, para se ler o sentido
    _glow.color = kText.withValues(alpha: 0.7 * g.alpha);
    canvas.drawCircle(head, math.max(1.0, wid * 0.45), _glow);
  }
}
