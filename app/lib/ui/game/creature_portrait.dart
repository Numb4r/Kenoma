/// O retrato animado da criatura no Bestiário (0.25.0): pairando, com os LEDs piscando como letreiro com mau contato. Só
/// para as criaturas com arte animada (`CreatureArt.portrait`).
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'creature_anim.dart';
import 'creature_art.dart';

class CreaturePortrait extends StatefulWidget {
  const CreaturePortrait({required this.art, required this.size, this.variant, super.key});

  final CreatureArt art;
  final double size;

  /// 0.25.1: a variante escolhida no detalhe (`urban`, `crimson`...), pela mesma troca de cores do mapa. `null`: a comum.
  final String? variant;

  @override
  State<CreaturePortrait> createState() => _CreaturePortraitState();
}

class _CreaturePortraitState extends State<CreaturePortrait> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((d) => setState(() => _t = d.inMicroseconds / 1e6));
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(width: widget.size, height: widget.size, child: CustomPaint(painter: _PortraitPainter(widget.art.portrait!, widget.art.portraitOf(widget.variant)!, _t, widget.variant)));
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.strip, this.body, this.t, this.variant);

  final CreatureStrip strip;
  final ui.Image body;
  final double t;
  final String? variant;

  @override
  void paint(Canvas canvas, Size size) {
    final f = strip.body.height.toDouble(), frame = loopFrame(t, strip.frames, strip.fps);
    // O maior múltiplo inteiro do quadro que cabe (nítido); se não cabe nem 1×, o tamanho todo.
    final k = (size.shortestSide / f).floor();
    final side = k >= 1 ? k * f : size.shortestSide;
    final dst = Rect.fromCenter(center: size.center(Offset.zero), width: side, height: side);
    final src = Rect.fromLTWH(frame * f, 0, f, f);
    final px = Paint()..filterQuality = FilterQuality.none;
    canvas.drawImageRect(body, src, dst, px);
    if (strip.glow case final g?) canvas.drawImageRect(g, src, dst, px);
    if (ledLit(0, t) && strip.leds != null) canvas.drawImageRect(strip.leds!, src, dst, px);
  }

  @override
  bool shouldRepaint(_PortraitPainter old) => old.t != t || old.variant != variant;
}
