/// A passagem pela porta do Véu (0.29.0, spec do criativo): uma faixa clara da costura nasce no x da porta e alarga até
/// cobrir a tela; a cena nova aparece por dentro dela. Sair é o inverso (a mesma rota voltando).
library;

import 'package:flutter/material.dart';

const _seamLight = Color(0xFFC9B8FF), _seam = Color(0xFF9B7BFF);

Route<T> seamRoute<T>(Widget screen, {double? originX}) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, _, _) => screen,
      transitionsBuilder: (context, anim, _, child) => AnimatedBuilder(
        animation: anim,
        child: child,
        builder: (context, child) {
          final w = MediaQuery.sizeOf(context).width;
          final x = originX ?? w / 2;
          final t = anim.value;
          // Primeira metade: só a faixa alarga a partir da porta. Segunda: a cena nova por dentro dela.
          final band = Curves.easeIn.transform((t * 2).clamp(0.0, 1.0));
          final reveal = Curves.easeOut.transform(((t - 0.5) * 2).clamp(0.0, 1.0));
          final left = x - band * x, right = x + band * (w - x);
          return Stack(children: [
            if (reveal > 0)
              ClipRect(
                clipper: _Band(x - reveal * x, x + reveal * (w - x)),
                child: child,
              ),
            IgnorePointer(
              child: CustomPaint(size: Size.infinite, painter: _SeamPainter(left, right, 1 - reveal)),
            ),
          ]);
        },
      ),
    );

class _Band extends CustomClipper<Rect> {
  const _Band(this.left, this.right);
  final double left, right;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(left, 0, right, size.height);

  @override
  bool shouldReclip(_Band old) => old.left != left || old.right != right;
}

class _SeamPainter extends CustomPainter {
  const _SeamPainter(this.left, this.right, this.alpha);
  final double left, right, alpha;

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0.01) return;
    canvas.drawRect(Rect.fromLTRB(left, 0, right, size.height), Paint()..color = _seamLight.withValues(alpha: alpha));
    final edge = Paint()..color = _seam.withValues(alpha: alpha);
    canvas.drawRect(Rect.fromLTRB(left - 2, 0, left, size.height), edge);
    canvas.drawRect(Rect.fromLTRB(right, 0, right + 2, size.height), edge);
  }

  @override
  bool shouldRepaint(_SeamPainter old) => old.left != left || old.right != right || old.alpha != alpha;
}
