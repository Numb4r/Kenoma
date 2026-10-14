/// A bússola do mapa de jogo: uma agulha que aponta o norte. Aparece quando o mapa não está com o norte
/// para cima. Um toque volta ao norte; dois toques ligam e desligam o "seguir direção" (o mapa gira com a
/// bússola do celular).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../colors.dart';

class CompassButton extends StatelessWidget {
  const CompassButton({required this.angle, required this.follow, required this.onNorth, required this.onToggleFollow, super.key});

  /// Rotação do mapa em radianos: o norte está [angle] à direita do alto da tela.
  final double angle;

  /// O "seguir direção" está ligado.
  final bool follow;
  final VoidCallback onNorth;
  final VoidCallback onToggleFollow;

  static const double size = 52;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onNorth,
        onDoubleTap: onToggleFollow,
        child: SizedBox(width: size, height: size, child: CustomPaint(painter: _CompassPainter(angle, follow))),
      );
}

class _CompassPainter extends CustomPainter {
  _CompassPainter(this.angle, this.follow);

  final double angle;
  final bool follow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    canvas.drawCircle(c, r, Paint()..color = kOutline.withValues(alpha: 0.88)..isAntiAlias = false);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = follow ? kSignal : kVeil
        ..isAntiAlias = false,
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final needle = r * 0.72;
    canvas.drawPath(
      Path()..moveTo(0, -needle)..lineTo(needle * 0.34, 0)..lineTo(-needle * 0.34, 0)..close(),
      Paint()..color = kEssence..isAntiAlias = false,
    );
    canvas.drawPath(
      Path()..moveTo(0, needle)..lineTo(needle * 0.34, 0)..lineTo(-needle * 0.34, 0)..close(),
      Paint()..color = kDim..isAntiAlias = false,
    );
    canvas.restore();
    final n = TextPainter(
      text: TextSpan(text: 'N', style: TextStyle(fontFamily: 'Silkscreen', fontSize: 8, color: follow ? kSignal : kText)),
      textDirection: TextDirection.ltr,
    )..layout();
    // O "N" fica na borda do círculo, do lado do norte.
    final at = c + Offset(math.sin(angle), -math.cos(angle)) * (r - 1);
    n.paint(canvas, at - Offset(n.width / 2, n.height / 2));
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.angle != angle || old.follow != follow;
}
