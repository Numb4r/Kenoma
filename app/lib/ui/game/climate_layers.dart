/// As camadas do clima que não são partículas, cada uma um desenho curto no espaço da tela. O tipo vem do `clima.json`
/// (`layer`), os números também. Só visual: posições de enfeite saem de um embaralhador local, nunca do mundo.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../data/climate_catalog.dart';

final _p = ui.Paint()..isAntiAlias = false;

/// Um número em `[0, 1)` fixo para (i, j): posições de enfeite que não pulam de um quadro para o outro.
double _h(int i, int j) {
  var x = (i * 73856093) ^ (j * 19349663) ^ 0x5bd1e995;
  x = (x * 1103515245 + 12345) & 0x7fffffff;
  x = (x * 1103515245 + 12345) & 0x7fffffff;
  return x / 0x7fffffff;
}

ui.Color _c(int argb, double a) => ui.Color(argb).withValues(alpha: a.clamp(0.0, 1.0));

/// Desenha a camada [l] com opacidade [a] no instante [t] (segundos de jogo). [player] é o Conjurador na tela.
void paintClimateLayer(ui.Canvas canvas, ui.Size view, ClimateLayer l, double a, double t, {required ui.Offset player, bool reduceFlashes = false}) {
  final w = view.width, h = view.height, rect = ui.Offset.zero & view;
  switch (l.kind) {
    case 'tint':
      canvas.drawRect(rect, ui.Paint()
        ..color = _c(l.color(), a)
        ..blendMode = l.str('blend') == 'multiply' ? ui.BlendMode.multiply : ui.BlendMode.srcOver);
    case 'vignette':
      canvas.drawRect(
        rect,
        ui.Paint()..shader = ui.Gradient.radial(view.center(ui.Offset.zero), math.sqrt(w * w + h * h) / 2, [_c(l.color(), 0), _c(l.color(), a)], [0.45, 1.0]),
      );
    case 'desaturate':
      canvas.drawRect(rect, ui.Paint()
        ..color = ui.Color.fromRGBO(128, 128, 128, a.clamp(0.0, 1.0))
        ..blendMode = ui.BlendMode.saturation);
    case 'shimmer':
      final n = l.count('bands', 7);
      for (var i = 0; i < n; i++) {
        final y = ((i + (t * 0.15) % 1) / n) * h;
        final k = 0.5 + 0.5 * math.sin(t * 2.4 + i * 1.7);
        canvas.drawRect(ui.Rect.fromLTWH(0, y, w, 3), _p..color = _c(l.color(), a * k));
      }
    case 'shadows':
      final n = l.count('count', 3), speed = l.val('speed', 10);
      for (var i = 0; i < n; i++) {
        final r = w * (0.35 + 0.25 * _h(i, 1));
        final x = ((_h(i, 2) * (w + 2 * r) + t * speed) % (w + 2 * r)) - r;
        final y = _h(i, 3) * h;
        canvas.drawOval(ui.Rect.fromCenter(center: ui.Offset(x, y), width: r * 2, height: r * 1.2), ui.Paint()..color = _c(l.color(), a));
      }
    case 'sheen':
      final n = l.count('count', 12), tick = (t * 1.5).floor();
      for (var i = 0; i < n; i++) {
        final k = _h(i, tick);
        if (k < 0.5) continue;
        canvas.drawRect(ui.Rect.fromLTWH(_h(i * 3, tick) * w, _h(i * 5, tick) * h, 3, 1), _p..color = _c(l.color(), a * (k - 0.5) * 2));
      }
    case 'arc':
      const colors = [0xFFFF5A36, 0xFFFF7A45, 0xFFFFE9A8, 0xFF6BD36A, 0xFF4AA8FF, 0xFF9B7BFF];
      final c = ui.Offset(w * 0.5, h * 0.62), r0 = w * 0.78;
      for (var i = 0; i < colors.length; i++) {
        canvas.drawArc(ui.Rect.fromCircle(center: c, radius: r0 - i * 5), math.pi, math.pi, false, ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = _c(colors[i], a));
      }
    case 'aurora':
      final cs = l.colors.isEmpty ? [0xFF6BD36A, 0xFF9B7BFF] : l.colors;
      for (var i = 0; i < cs.length; i++) {
        final path = ui.Path()..moveTo(0, 0);
        for (var x = 0.0; x <= w; x += 12) {
          path.lineTo(x, h * (0.12 + 0.05 * i) + math.sin(x / w * 6 + t * 0.6 + i) * 16);
        }
        path
          ..lineTo(w, 0)
          ..close();
        canvas.drawPath(path, ui.Paint()..color = _c(cs[i], a * 0.7));
      }
    case 'glitch':
      // Reduzir clarões: troca devagar e fraco, sem piscar.
      final rate = reduceFlashes ? 1.5 : 10.0, tick = (t * rate).floor();
      final cs = l.colors.isEmpty ? [l.color()] : l.colors;
      final n = l.count('count', 8);
      for (var i = 0; i < n; i++) {
        if (_h(i, tick) < 0.4) continue;
        final r = ui.Rect.fromLTWH(_h(i, tick + 1) * w, _h(i, tick + 2) * h, 8 + _h(i, tick + 3) * 60, 2 + _h(i, tick + 4) * 6);
        canvas.drawRect(r, _p..color = _c(cs[i % cs.length], a * (reduceFlashes ? 0.5 : 1)));
      }
    case 'ripple':
      final n = l.count('bands', 6);
      for (var i = 0; i < n; i++) {
        final y = (i / n * h + t * 14) % h;
        final dx = math.sin(t * 0.8 + i) * 18;
        canvas.drawRect(ui.Rect.fromLTWH(dx - 20, y, w + 40, h / n * 0.4), ui.Paint()..color = _c(l.color(), a));
      }
    case 'funnel':
      final x = ((t * 26) % (w + 240)) - 120, top = h * 0.05;
      for (var i = 0; i < 14; i++) {
        final y = top + i * h * 0.06;
        final half = 70 - i * 4.2 + math.sin(t * 5 + i) * 4;
        canvas.drawRect(ui.Rect.fromLTWH(x - half + math.sin(t * 2 + i * 0.5) * 10, y, half * 2, h * 0.05), _p..color = _c(l.color(), a));
      }
    case 'figures':
      final n = l.count('count', 3), line = l.flag('line');
      for (var i = 0; i < n; i++) {
        final x = line ? ((t * 12 + i * 34) % (w + 60)) - 30 : (_h(i, 7) < 0.5 ? 12 + _h(i, 8) * 30 : w - 42 + _h(i, 8) * 30) + math.sin(t * 0.4 + i) * 6;
        final y = line ? h * 0.42 : h * (0.2 + 0.6 * _h(i, 9));
        final k = line ? 1.0 : 0.5 + 0.5 * math.sin(t * 0.5 + i * 2);
        canvas.drawRect(ui.Rect.fromLTWH(x, y, 6, 16), _p..color = _c(l.color(), a * k));
        canvas.drawRect(ui.Rect.fromLTWH(x + 1, y - 5, 4, 4), _p..color = _c(l.color(), a * k));
      }
    case 'cracks':
      for (var i = 0; i < 4; i++) {
        final path = ui.Path()..moveTo(_h(i, 11) * w, 0);
        var x = _h(i, 11) * w, y = 0.0;
        for (var j = 0; j < 6; j++) {
          x += (_h(i, j) - 0.5) * 40;
          y += h * 0.035;
          path.lineTo(x, y);
        }
        canvas.drawPath(path, ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _c(l.color(), a * (0.7 + 0.3 * math.sin(t * 1.3 + i))));
      }
    case 'meteors':
      final every = l.val('every_s', 2.5), k = (t / every).floor(), u = (t % every) / every;
      if (u < 0.3) {
        final s = u / 0.3;
        final x0 = _h(k, 1) * w * 0.8, y0 = _h(k, 2) * h * 0.25;
        final x = x0 + s * w * 0.3, y = y0 + s * h * 0.12;
        canvas.drawLine(ui.Offset(x - 26, y - 10), ui.Offset(x, y), ui.Paint()
          ..strokeWidth = 2
          ..color = _c(l.color(), a * (1 - s)));
      }
    case 'breath':
      final u = (t % 3.0) / 3.0;
      if (u < 0.5) {
        final s = u / 0.5;
        canvas.drawCircle(player.translate(6 + s * 6, -26 - s * 10), 2 + s * 4, ui.Paint()..color = _c(l.color(), a * (1 - s)));
      }
  }
}
