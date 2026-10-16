/// A animação da fusão (2 s, `fusion.anim_s`): os cinco Ecos giram em círculo e se juntam, as costuras violeta se fecham
/// e o Espírito se forma. Desenhada por código, com os sprites em pixels (sem filtro). Um toque pula.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../tema.dart';

class FusionAnimation extends StatefulWidget {
  const FusionAnimation({required this.eco, required this.spirit, required this.durationS, required this.onDone, this.count = 5, super.key});

  /// Os sprites do Eco e do Espírito (`null` desenha um quadrado na cor do Véu, como o placeholder).
  final ui.Image? eco;
  final ui.Image? spirit;
  final double durationS;
  final int count;

  /// Chamado uma vez, quando a animação acaba ou o jogador toca para pular.
  final VoidCallback onDone;

  @override
  State<FusionAnimation> createState() => _FusionAnimationState();
}

class _FusionAnimationState extends State<FusionAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: (widget.durationS * 1000).round()))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    })
    ..forward();
  bool _done = false;

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('fusion-skip'),
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: ColoredBox(
          color: KCores.fundo,
          child: Stack(children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) => CustomPaint(painter: FusionPainter(t: _c.value, eco: widget.eco, spirit: widget.spirit, count: widget.count)),
              ),
            ),
            const Positioned(left: 0, right: 0, bottom: KEspaco.s4, child: Center(child: Text('TOQUE PARA PULAR', style: KTexto.rotulo))),
          ]),
        ),
      );
}

double _ease(double x) => x * x * (3 - 2 * x);
double _span(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

/// O quadro da fusão em [t] (0 a 1): 0 a 0,65 os Ecos giram e fecham o círculo; 0,35 a 0,85 as costuras se fecham; a
/// partir de 0,7 o Espírito se forma no meio.
class FusionPainter extends CustomPainter {
  const FusionPainter({required this.t, required this.eco, required this.spirit, this.count = 5});

  final double t;
  final ui.Image? eco;
  final ui.Image? spirit;
  final int count;

  static final _flat = ui.Paint()..isAntiAlias = false;

  void _sprite(Canvas canvas, ui.Image? img, Offset c, double side, double alpha) {
    final dst = Rect.fromCenter(center: c, width: side, height: side);
    if (img == null) {
      canvas.drawRect(dst.deflate(side * 0.2), _flat..color = KCores.veuVioleta.withValues(alpha: alpha));
      return;
    }
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      ui.Paint()..filterQuality = ui.FilterQuality.none..isAntiAlias = false..color = Color.fromRGBO(255, 255, 255, alpha),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * 0.34;
    final side = math.min(size.width, size.height) * 0.22;
    final orbit = _ease(_span(t, 0, 0.65));
    final fade = 1 - _span(t, 0.55, 0.78);
    // Os Ecos: giram e se aproximam do centro.
    for (var i = 0; i < count && fade > 0; i++) {
      final a = i * 2 * math.pi / count + 3 * math.pi * orbit;
      final radius = r * (1 - 0.8 * orbit);
      _sprite(canvas, eco, c + Offset(math.cos(a), math.sin(a)) * radius, side, fade);
    }
    // As costuras: duas barras violeta (vertical e horizontal) que se fecham sobre o centro.
    final seam = _span(t, 0.35, 0.85);
    if (seam > 0 && seam < 1) {
      final gap = r * 1.1 * (1 - _ease(seam));
      final w = kContornoDp;
      final len = r * 1.4;
      _flat.color = KCores.veuVioleta;
      for (final d in [-gap, gap]) {
        canvas.drawRect(Rect.fromCenter(center: c + Offset(d, 0), width: w, height: len), _flat);
        canvas.drawRect(Rect.fromCenter(center: c + Offset(0, d), width: len, height: w), _flat);
      }
    }
    // O Espírito: aparece no centro dentro do brilho suave do Véu.
    final form = _ease(_span(t, 0.7, 1));
    if (form > 0) {
      final big = side * (1.4 + 0.5 * form);
      canvas.drawCircle(
        c,
        big * 0.95,
        ui.Paint()..shader = ui.Gradient.radial(c, big * 0.95, [KCores.veuVioleta.withValues(alpha: 0.5 * form), KCores.veuVioleta.withValues(alpha: 0)])..isAntiAlias = true,
      );
      _sprite(canvas, spirit, c, big, form);
    }
  }

  @override
  bool shouldRepaint(FusionPainter old) => old.t != t || old.eco != eco || old.spirit != spirit;
}
