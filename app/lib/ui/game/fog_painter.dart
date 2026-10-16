/// O véu da névoa de guerra: o mapa começa coberto por um véu escuro e translúcido, e as células reveladas (z20, ~35 m)
/// aparecem limpas. Em blocos, no estilo do jogo. Só desenho: quem decide o que está revelado é `world/fog.dart`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../world/fog.dart';
import '../../world/map_camera.dart';
import '../colors.dart';

class FogPainter {
  FogPainter({this.alpha = 0.62});

  /// Quão escuro é o véu (0 a 1).
  final double alpha;

  /// Quantas células reveladas foram recortadas no último quadro (para conferir o custo).
  int lastCut = 0;

  void paint(ui.Canvas canvas, ui.Size view, MapCamera cam, FogState fog) {
    final (l, t, r, b) = cam.visibleBounds(view.width, view.height);
    final x0 = (l / 2).floor() - 1, x1 = (r / 2).floor() + 1, y0 = (t / 2).floor() - 1, y1 = (b / 2).floor() + 1;
    final holes = ui.Path();
    lastCut = 0;
    for (var cy = y0; cy <= y1; cy++) {
      for (var cx = x0; cx <= x1; cx++) {
        if (!fog.isRevealed(cx, cy)) continue;
        lastCut++;
        // Os quatro cantos da célula z20 na tela, um pouco inflados para duas células vizinhas não deixarem fresta.
        final pts = [
          cam.cellToScreen(cx * 2.0, cy * 2.0, view.width, view.height),
          cam.cellToScreen(cx * 2.0 + 2, cy * 2.0, view.width, view.height),
          cam.cellToScreen(cx * 2.0 + 2, cy * 2.0 + 2, view.width, view.height),
          cam.cellToScreen(cx * 2.0, cy * 2.0 + 2, view.width, view.height),
        ];
        final mx = (pts[0].$1 + pts[2].$1) / 2, my = (pts[0].$2 + pts[2].$2) / 2;
        final path = ui.Path();
        for (var i = 0; i < 4; i++) {
          final dx = pts[i].$1 - mx, dy = pts[i].$2 - my;
          final len = (dx * dx + dy * dy);
          final k = len == 0 ? 1.0 : 1 + 1.5 / math.sqrt(len);
          final x = mx + dx * k, y = my + dy * k;
          i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
        }
        path.close();
        holes.addPath(path, ui.Offset.zero);
      }
    }
    final rect = ui.Offset.zero & view;
    canvas.saveLayer(rect, ui.Paint());
    canvas.drawRect(rect, ui.Paint()..color = kOutline.withValues(alpha: alpha)..isAntiAlias = false);
    if (lastCut > 0) canvas.drawPath(holes, ui.Paint()..blendMode = ui.BlendMode.clear..isAntiAlias = false);
    canvas.restore();
  }
}
