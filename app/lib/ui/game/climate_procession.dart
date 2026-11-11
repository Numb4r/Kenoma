/// O desenho da Procissão na névoa: as figuras encapuzadas em pé na tela (tamanho de passante, contraste alto, vela com luz
/// fraca na mão) e as velas acesas no chão por onde a fila passou. As posições vêm de `world/procession.dart`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/fnv.dart';
import '../../world/procession.dart';
import 'climate_ground.dart' show PlacedMark;
import 'climate_puddle.dart';

ui.Color _c(int argb, double a) => ui.Color(argb).withValues(alpha: a.clamp(0.0, 1.0));

const int _outline = 0xFF1A1424, _flame = 0xFFFFB35A, _flameCore = 0xFFFFF1C2, _wax = 0xFFF2E8D0;

final _fill = ui.Paint()..isAntiAlias = false;
final _glow = ui.Paint();

/// Meia largura da túnica em cada uma das linhas (em pixels de arte): capuz em cima, a túnica abrindo para baixo.
const _halfWidth = [1.0, 1.5, 2, 2, 2, 2, 2.5, 2.5, 3, 3];
const _rows = 10;

/// Uma figura encapuzada com os pés em ([sx], [sy]) (pontos de tela), de [heightPx] de altura. [screenHeading] é a direção
/// em que ela anda na tela: a vela vai na mão da frente.
void paintHoodedFigure(ui.Canvas canvas, double sx, double sy, {required double heightPx, required double artPx, required int robe, required int glow, required double alpha, required double flicker, required double screenHeading}) {
  // Um pixel da figura é um pixel de arte enquanto ela cabe na altura de um passante; de longe (zoom), encolhe junto.
  final u = math.min(artPx, heightPx / _rows);
  final h = _rows * u;
  final side = math.cos(screenHeading) >= 0 ? 1.0 : -1.0;
  final top = sy - h;
  // A luz fraca da vela, por baixo de tudo.
  final hand = ui.Offset(sx + side * 3.5 * u, top + 6 * u);
  _glow
    ..color = _c(glow, 0.22 * alpha * (0.85 + 0.15 * flicker))
    ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 3 * u);
  canvas.drawCircle(hand.translate(0, -u), 4 * u, _glow);
  // Contorno e túnica.
  for (var r = 0; r < _rows; r++) {
    final hw = _halfWidth[r] * u;
    canvas.drawRect(ui.Rect.fromLTRB(sx - hw - u, top + r * u - (r == 0 ? u : 0), sx + hw + u, top + (r + 1) * u + (r == _rows - 1 ? u : 0)), _fill..color = _c(_outline, alpha));
  }
  for (var r = 0; r < _rows; r++) {
    final hw = _halfWidth[r] * u;
    final shade = r >= 1 && r <= 3 ? 0.8 : (r % 3 == 2 ? 0.9 : 1.0); // o capuz e as dobras da túnica
    final col = ui.Color.lerp(const ui.Color(_outline), ui.Color(robe), shade)!;
    canvas.drawRect(ui.Rect.fromLTRB(sx - hw, top + r * u, sx + hw, top + (r + 1) * u), _fill..color = col.withValues(alpha: alpha));
  }
  // O rosto escuro dentro do capuz, virado para onde ela anda.
  canvas.drawRect(ui.Rect.fromLTWH(sx + (side > 0 ? 0 : -u), top + 2 * u, u, 2 * u), _fill..color = _c(_outline, alpha));
  // A vela na mão.
  canvas.drawRect(ui.Rect.fromLTWH(hand.dx - u / 2, hand.dy - u, u, 2 * u), _fill..color = _c(_wax, alpha));
  canvas.drawRect(ui.Rect.fromLTWH(hand.dx - u / 2, hand.dy - 2 * u - (flicker > 0.6 ? u : 0), u, u), _fill..color = _c(_flame, alpha));
  canvas.drawRect(ui.Rect.fromLTWH(hand.dx - u / 2, hand.dy - 2 * u, u, u), _fill..color = _c(_flameCore, alpha * 0.9));
}

/// As velas no chão (o canvas já está na câmera, células z21; [q] é o pixel de arte em células). Nos últimos 2 min, a chama
/// diminui e se apaga.
void paintCandles(
  ui.Canvas canvas,
  List<ProcessionCandle> candles, {
  required double t,
  required double q,
  required double candleS,
  required bool Function(double x, double y, double m) inView,
  required ui.Offset Function(double, double) at,
  required List<PlacedMark> placed,
}) {
  for (final c in candles) {
    if (!inView(c.x, c.y, 2)) continue;
    final age = t - c.litUtc;
    final life = (1 - (age - (candleS - 120)) / 120).clamp(0.0, 1.0);
    final o = at(c.x, c.y);
    final k = 0.8 + 0.2 * math.sin(t * 8 + c.x * 13);
    _glow
      ..color = _c(_flame, 0.2 * life * k)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 2 * q);
    canvas.drawCircle(o, 3 * q, _glow);
    // Cada vela é uma: a cera derretida em volta com o seu contorno, o toco mais alto ou mais baixo, às vezes torto.
    final h = fnv1a64Of3((c.x * 256).round(), (c.y * 256).round(), 0xCE7A);
    final tall = (h & 3) == 0 ? 2 : 1, lean = ((h >>> 2) % 3 - 1) * q / 2;
    paintBlobRows(canvas, o.translate(-q / 2, 0), blobRows(h, 1 + ((h >>> 4) & 1)), q, _c(_outline, 0.8));
    paintBlobRows(canvas, o.translate(-q / 2, 0), blobRows(h ^ 0x51, 1), q, _c(_wax, 0.45));
    canvas.drawRect(ui.Rect.fromLTWH(o.dx - q / 2, o.dy - tall * q, q, tall * q), _fill..color = _c(_wax, 0.9));
    if (life > 0) canvas.drawRect(ui.Rect.fromLTWH(o.dx - q / 2 + lean, o.dy - (tall + 1) * q, q, q), _fill..color = _c(_flame, life * k));
    placed.add((kind: 'candle', x: c.x, y: c.y));
  }
}
