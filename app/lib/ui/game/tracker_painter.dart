/// As marcas finas na borda da tela depois de um pulso do Radar: um traço curto em ciano (violeta na distorção, dourado no
/// Brilhante) onde a direção do achado cruza a borda, apontando para ele. Só desenha; quem escolhe é `world/tracker.dart`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../world/tracker.dart';
import '../colors.dart';

const double _inset = 6; // da borda até a ponta da marca, em dp
const double _len = 16; // comprimento do traço

/// Desenha [marks] vistas do Conjurador em [from] (pixels da tela), com o mapa girado [rotation].
void paintEdgeMarks(ui.Canvas canvas, ui.Size view, ui.Offset from, List<EdgeMark> marks, {double rotation = 0}) {
  final line = ui.Paint()..strokeWidth = 2..isAntiAlias = false..strokeCap = ui.StrokeCap.square;
  for (final m in marks) {
    final a = m.angle + rotation;
    final (x, y) = edgePoint(from.dx, from.dy, a, view.width, view.height, inset: _inset);
    final tip = ui.Offset(x, y);
    final back = tip - ui.Offset(math.cos(a), math.sin(a)) * _len;
    final color = m.shiny ? const ui.Color(0xFFFFE9A8) : (m.distortion ? kVeil : kSignal);
    canvas.drawLine(back, tip, line..color = kOutline.withValues(alpha: 0.6 * m.alpha)..strokeWidth = 4);
    canvas.drawLine(back, tip, line..color = color.withValues(alpha: m.alpha)..strokeWidth = 2);
    if (m.pinned) {
      // A espécie marcada: uma ponta de seta no fim da marca.
      final n = ui.Offset(-math.sin(a), math.cos(a)) * 6, head = tip - ui.Offset(math.cos(a), math.sin(a)) * 8;
      final arrow = ui.Path()..moveTo(tip.dx, tip.dy)..lineTo(head.dx + n.dx, head.dy + n.dy)..lineTo(head.dx - n.dx, head.dy - n.dy)..close();
      canvas.drawPath(arrow, ui.Paint()..color = kSignal..isAntiAlias = false);
      canvas.drawPath(arrow, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 1..color = kOutline..isAntiAlias = false);
    }
  }
}
