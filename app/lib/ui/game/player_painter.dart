/// Desenho do Conjurador e da Aura no chão. O marcador é um placeholder em pixel art, na paleta fixa do
/// jogo (violeta do Véu, ciano do sinal, contorno ameixa): arte nunca bloqueia código.
library;

import 'dart:math' as math;
import 'dart:ui';

import '../colors.dart';

/// O Conjurador visto de cima: capuz e manto, com o brilho ciano do celular no rosto.
/// `V` violeta (contorno), `O` manto, `C` ciano.
const List<String> _marker = [
  '..VVV..',
  '.VOOOV.',
  '.VOCOV.',
  '.VOOOV.',
  'VOOOOOV',
  'VOOOOOV',
  '.VOOOV.',
  '.VVVVV.',
  '..V.V..',
];

/// Desenha o círculo da Aura: violeta tracejado, com um preenchimento leve. [radiusPx] já vem na escala
/// da câmera (`auraRadiusPx`).
void paintAura(Canvas canvas, Offset center, double radiusPx) {
  if (radiusPx < 2) return;
  canvas.drawCircle(
    center,
    radiusPx,
    Paint()
      ..color = kVeil.withValues(alpha: 0.10)
      ..isAntiAlias = false,
  );
  final dash = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.butt
    ..isAntiAlias = false
    ..color = kVeil;
  // Um traço por ~12 px de arco, para o tracejado parecer o mesmo em qualquer zoom.
  final dashes = math.max(12, (2 * math.pi * radiusPx / 12).round() ~/ 2 * 2);
  final sweep = 2 * math.pi / dashes;
  final rect = Rect.fromCircle(center: center, radius: radiusPx);
  for (var i = 0; i < dashes; i += 2) {
    canvas.drawArc(rect, i * sweep, sweep, false, dash);
  }
}

/// Desenha o marcador do Conjurador em [center]. O pixel do sprite cresce com a escala do mapa.
void paintPlayerMarker(Canvas canvas, Offset center, double pixelsPerCell) {
  final px = math.max(2, (pixelsPerCell / 5).floor()).toDouble();
  final w = _marker.first.length * px, h = _marker.length * px;
  final origin = Offset((center.dx - w / 2).roundToDouble(), (center.dy - h / 2).roundToDouble());
  final fill = Paint()..isAntiAlias = false;
  for (var r = 0; r < _marker.length; r++) {
    for (var c = 0; c < _marker[r].length; c++) {
      final color = switch (_marker[r][c]) {
        'V' => kVeil,
        'O' => kPanel,
        'C' => kSignal,
        _ => null,
      };
      if (color == null) continue;
      canvas.drawRect(Rect.fromLTWH(origin.dx + c * px, origin.dy + r * px, px, px), fill..color = color);
    }
  }
  // Contorno ameixa por baixo, na base do manto: assenta o marcador no chão.
  canvas.drawRect(
    Rect.fromLTWH(origin.dx + px, origin.dy + h, w - 2 * px, px / 2),
    Paint()
      ..color = kOutline
      ..isAntiAlias = false,
  );
}
