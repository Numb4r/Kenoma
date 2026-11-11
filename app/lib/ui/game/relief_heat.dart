/// Debug: o relevo como mapa de calor por cima do mapa do jogo. Cada célula z21 em quatro por quatro quadrados, do azul
/// (o ponto mais baixo da tela) ao vermelho (o mais alto), com a altura em metros no meio de cada célula.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../data/relief_pack.dart';
import '../../world/map_camera.dart';

const List<int> _ramp = [0xFF2B5BD7, 0xFF2BB7D7, 0xFF3FCB6A, 0xFFE8D33A, 0xFFE8873A, 0xFFD73A2B];

ui.Color reliefColor(double t) {
  final x = t.clamp(0.0, 1.0) * (_ramp.length - 1), i = math.min(x.floor(), _ramp.length - 2);
  return ui.Color.lerp(ui.Color(_ramp[i]), ui.Color(_ramp[i + 1]), x - i)!;
}

void paintReliefHeat(ui.Canvas canvas, ui.Size view, MapCamera cam, ReliefSource relief) {
  final (l, t, r, b) = cam.visibleBounds(view.width, view.height);
  const sub = 4;
  final x0 = l.floor(), y0 = t.floor(), x1 = r.ceil(), y1 = b.ceil();
  if ((x1 - x0) * (y1 - y0) > 4000) return; // zoom aberto demais
  var lo = double.infinity, hi = -double.infinity;
  final hs = <double?>[];
  for (var y = y0 * sub; y < y1 * sub; y++) {
    for (var x = x0 * sub; x < x1 * sub; x++) {
      final h = relief.heightAt((x + 0.5) / sub, (y + 0.5) / sub);
      hs.add(h);
      if (h != null) {
        lo = math.min(lo, h);
        hi = math.max(hi, h);
      }
    }
  }
  if (!lo.isFinite) return;
  final span = math.max(hi - lo, 0.5);
  canvas.save();
  canvas.translate(view.width / 2, view.height / 2);
  canvas.rotate(cam.rotation);
  canvas.scale(cam.pixelsPerCell);
  canvas.translate(-cam.centerX, -cam.centerY);
  final paint = ui.Paint()..isAntiAlias = false;
  var i = 0;
  for (var y = y0 * sub; y < y1 * sub; y++) {
    for (var x = x0 * sub; x < x1 * sub; x++) {
      final h = hs[i++];
      if (h == null) continue;
      canvas.drawRect(ui.Rect.fromLTWH(x / sub, y / sub, 1 / sub + 0.002, 1 / sub + 0.002), paint..color = reliefColor((h - lo) / span).withValues(alpha: 0.55));
    }
  }
  canvas.restore();
  if (cam.pixelsPerCell < 40) return;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final h = relief.heightAt(x + 0.5, y + 0.5);
      if (h == null) continue;
      final (sx, sy) = cam.cellToScreen(x + 0.5, y + 0.5, view.width, view.height);
      final p = (ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center, fontSize: 11))
            ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF), shadows: const [ui.Shadow(color: ui.Color(0xFF1A1424), blurRadius: 2)]))
            ..addText(h.toStringAsFixed(1)))
          .build()
        ..layout(const ui.ParagraphConstraints(width: 60));
      canvas.drawParagraph(p, ui.Offset(sx - 30, sy - 7));
    }
  }
}
