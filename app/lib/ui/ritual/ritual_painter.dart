/// O círculo de ritual e o sigilo que se fecha, desenhados por código em pixel de arte de 3 dp (sem imagem). Só desenho:
/// as regras do ritual estão em `crafting/ritual.dart`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema.dart';

const double _px = 3;

void _dot(Canvas canvas, Paint paint, double x, double y) {
  canvas.drawRect(Rect.fromLTWH((x / _px).floorToDouble() * _px, (y / _px).floorToDouble() * _px, _px, _px), paint);
}

/// Uma linha de pixels entre [a] e [b].
void _line(Canvas canvas, Paint paint, Offset a, Offset b) {
  final steps = ((b - a).distance / _px).ceil().clamp(1, 400);
  for (var i = 0; i <= steps; i++) {
    final p = Offset.lerp(a, b, i / steps)!;
    _dot(canvas, paint, p.dx, p.dy);
  }
}

/// Um anel de pixels de raio [r]; com [gap] o anel tem vãos (a cada [gap] pixels pula um).
void _ring(Canvas canvas, Paint paint, Offset c, double r, {int gap = 0, double rotation = 0}) {
  final n = (2 * math.pi * r / _px * 1.3).ceil();
  for (var i = 0; i < n; i++) {
    if (gap > 0 && (i ~/ gap).isOdd) continue;
    final a = rotation + i * 2 * math.pi / n;
    _dot(canvas, paint, c.dx + r * math.cos(a), c.dy + r * math.sin(a));
  }
}

/// O círculo em repouso ([seal] = 0) ou se fechando ([seal] de 0 a 1): o anel externo encolhe, o polígono vai sendo traçado
/// ponta a ponta e, no fim, o centro acende em ciano. [broken] pinta o círculo de falha (anel partido, sem fechar).
class RitualCirclePainter extends CustomPainter {
  RitualCirclePainter({this.seal = 0, this.broken = false});

  final double seal;
  final bool broken;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - 6;
    final t = Curves.easeInOut.transform(seal.clamp(0.0, 1.0));
    final line = Paint()..color = broken ? KCores.falha : KCores.veuVioleta;
    final soft = Paint()..color = broken ? KCores.falha.withValues(alpha: 0.5) : KCores.veuClaro;
    final r = outer * (1 - 0.3 * t);
    _ring(canvas, line, c, r, gap: broken ? 7 : 0, rotation: t * math.pi);
    _ring(canvas, soft, c, r * 0.78, gap: 3, rotation: -t * math.pi * 1.5);
    // O polígono de seis pontas: cada lado aparece quando o sigilo chega nele.
    const sides = 6;
    final pr = r * 0.78;
    final pts = [for (var i = 0; i < sides; i++) c + Offset(math.cos(-math.pi / 2 + i * 2 * math.pi / sides), math.sin(-math.pi / 2 + i * 2 * math.pi / sides)) * pr];
    final shown = seal == 0 ? sides : (t * sides * 1.2).floor().clamp(0, sides);
    for (var i = 0; i < shown; i++) {
      _line(canvas, soft, pts[i], pts[(i + 2) % sides]); // estrela de seis pontas
    }
    if (seal >= 1) {
      final glow = Paint()..color = KCores.sinalCiano;
      _ring(canvas, glow, c, r * 0.4);
      _ring(canvas, glow, c, r * 0.2);
    }
  }

  @override
  bool shouldRepaint(RitualCirclePainter old) => old.seal != seal || old.broken != broken;
}
