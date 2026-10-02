/// Desenho da tela de sintonia. Só lê o estado e pinta: nenhuma regra do jogo mora aqui.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show TextAlign, TextPainter, TextSpan, TextStyle, TextDirection;

import '../../capture/eco_type.dart';
import '../../capture/fx/fx_params.dart';
import '../../capture/fx/wave_geometry.dart';
import '../colors.dart';
import '../sprites/sprite_image.dart';
import 'fx_painter.dart';
import 'tuning_layout.dart';

/// Foto do estado da sintonia, no instante de desenhar.
class TuningView {
  const TuningView({
    required this.dial,
    required this.target,
    required this.tolerance,
    required this.progress,
    required this.timeRemaining,
    required this.timeLimit,
    required this.aligned,
    required this.clock,
    required this.scroll,
    required this.type,
    required this.sealLabel,
    required this.tonic,
    required this.showTarget,
    this.hidden = false,
    this.fx,
  });

  final double dial;
  final double target;
  final double tolerance;
  final double progress;
  final double timeRemaining;
  final double timeLimit;
  final bool aligned;

  /// Segundos desde a abertura da tela. Só anima.
  final double clock;

  /// Rolagem da onda, a partir do tempo da sintonia (`waveScroll`): a fase da onda e a da queima do
  /// Fogo vêm do mesmo relógio.
  final double scroll;
  final EcoType type;
  final String sealLabel;
  final bool tonic;

  /// Ferramenta de debug: marca o alvo e a tolerância no dial.
  final bool showTarget;

  /// Modo de tipo oculto: a onda do sinal fica cinza e sem efeitos do tipo, para não entregá-lo.
  final bool hidden;

  /// Efeitos da onda temática e do dial. `null` num teste que só confere o resto.
  final TuningFx? fx;
}

const String _font = 'Silkscreen';

void paintTuning(Canvas canvas, Size size, TuningView v, EcoSprite? sprite) {
  final layout = TuningLayout(size);
  canvas.drawRect(Offset.zero & size, Paint()..color = kOutline);
  _hud(canvas, layout, v);
  _creature(canvas, layout, v, sprite);
  _waves(canvas, layout, v);
  _dial(canvas, layout, v);
}

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..isAntiAlias = false;

Paint _fill(Color c) => Paint()
  ..color = c
  ..isAntiAlias = false;

void _text(Canvas canvas, String s, Offset at, {double size = 16, Color color = kText, TextAlign align = TextAlign.left}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontFamily: _font, fontSize: size, color: color, height: 1)),
    textDirection: TextDirection.ltr,
  )..layout();
  final dx = switch (align) {
    TextAlign.right => -tp.width,
    TextAlign.center => -tp.width / 2,
    _ => 0.0,
  };
  tp.paint(canvas, at + Offset(dx, 0));
}

void _hud(Canvas canvas, TuningLayout l, TuningView v) {
  _text(canvas, v.sealLabel, const Offset(TuningLayout.hudLeft, 10), size: 16);
  if (v.tonic) _text(canvas, 'tônico: +tempo', Offset(TuningLayout.hudLeft, 46), size: 8, color: kEssence);
  final low = v.timeRemaining <= v.timeLimit * 0.25;
  _text(canvas, '${v.timeRemaining.toStringAsFixed(1)}s', Offset(l.size.width - 16, 10),
      size: 16, color: low ? kEssence : kText, align: TextAlign.right);
  canvas.drawRect(l.timeBar, _fill(kPanelLine));
  final frac = (v.timeRemaining / v.timeLimit).clamp(0.0, 1.0);
  canvas.drawRect(Rect.fromLTWH(l.timeBar.left, l.timeBar.top, l.timeBar.width * frac, l.timeBar.height),
      _fill(low ? kEssence : kVeil));
}

void _creature(Canvas canvas, TuningLayout l, TuningView v, EcoSprite? sprite) {
  final c = l.creatureCenter;
  // Anel de progresso: a trilha, o avanço em violeta e, alinhado, um aro ciano por fora.
  final ring = Rect.fromCircle(center: c, radius: l.ringRadius);
  canvas.drawArc(ring, 0, 2 * math.pi, false, _stroke(kPanelLine, 6));
  if (v.progress > 0) {
    canvas.drawArc(ring, -math.pi / 2, 2 * math.pi * v.progress, false, _stroke(kVeil, 6));
  }
  if (v.aligned) {
    canvas.drawArc(Rect.fromCircle(center: c, radius: l.ringRadius + 8), 0, 2 * math.pi, false, _stroke(kSignal, 2));
  }
  if (sprite == null) return;
  final s = l.spriteScale;
  final bob = (math.sin(v.clock * 2.2) * 2).round() * s / 2;
  final dst = Rect.fromCenter(center: c + Offset(0, bob), width: 48.0 * s, height: 48.0 * s);
  final src = const Rect.fromLTWH(0, 0, spriteSize * 1.0, spriteSize * 1.0);
  final paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  canvas.drawImageRect(sprite.normal, src, dst, paint);
  // As costuras violeta pulsam: a versão acesa entra e sai por cima.
  final pulse = 0.5 + 0.5 * math.sin(v.clock * 3.0);
  canvas.drawImageRect(sprite.bright, src, dst, paint..color = Color.fromRGBO(255, 255, 255, pulse));
}

void _waves(Canvas canvas, TuningLayout l, TuningView v) {
  final r = l.wavePanel;
  canvas.drawRect(r, _fill(kPanel));
  canvas.drawRect(r, _stroke(v.aligned ? kSignal : kPanelLine, 2));
  canvas.drawLine(Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), _stroke(kPanelLine, 1));

  const n = 120;
  final scroll = v.scroll;

  // Os pontos de [from] a [to] (frações da largura), com os dois extremos exatos. [theta] dá a fase.
  Path wave(double Function(double u) theta, double Function(double) shape, {double from = 0, double to = 1}) {
    final p = Path();
    var pen = false;
    void add(double u) {
      final pt = waveAtTheta(r, u, theta(u), shape);
      if (pen) {
        p.lineTo(pt.dx, pt.dy);
      } else {
        p.moveTo(pt.dx, pt.dy);
        pen = true;
      }
    }

    if (to <= from) return p;
    add(from);
    for (var i = 1; i < n; i++) {
      final u = i / n;
      if (u > from && u < to) add(u);
    }
    add(to);
    return p;
  }

  // O sinal da criatura é serrilhado, com picos. O do jogador é liso.
  final signalColor = v.hidden ? kDim : kSignal;
  final fx = v.fx;
  final split = v.hidden ? null : fx?.fire.split; // a onda partida entregaria o tipo
  if (split == null) {
    canvas.drawPath(wave((u) => waveTheta(v.target, u, scroll), triShape), _stroke(signalColor, 3));
  } else {
    // O Fogo partiu a onda: a real fica à direita da queima e as iscas, cinza desde a queima, à
    // esquerda. A fronteira é uma linha vertical e rola com a onda.
    final gap = fireGapHalfWidth;
    final real = split.real;
    for (final s in split.segments) {
      final from = s.fromU > 0 ? s.fromU + gap : 0.0;
      final to = s.real ? 1.0 : s.toU - gap;
      canvas.drawPath(wave(s.thetaAt, triShape, from: from, to: to), _stroke(s.real ? kSignal : kDim, 3));
      if (!s.real && s.toU > 0) {
        final x = r.left + r.width * s.toU;
        final latest = (s.toU - real.fromU).abs() < 1e-9;
        if (latest) canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), _stroke(kEssence.withValues(alpha: 0.35), 6));
        canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), _stroke(latest ? kEssence : kDim, latest ? 2 : 1));
      }
    }
  }
  canvas.drawPath(wave((u) => waveTheta(v.dial, u, scroll), math.sin), _stroke(kVeil, 3));
  if (fx != null) paintWaveFx(canvas, r, v.target, scroll, fx);
}

void _dial(Canvas canvas, TuningLayout l, TuningView v) {
  final c = l.dialCenter;
  final rad = l.dialRadius;
  canvas.drawCircle(c, rad + 6, _fill(kPanel));
  canvas.drawCircle(c, rad + 6, _stroke(kPanelLine, 3));

  // Marcas de frequência, com um glifo de traço de osciloscópio em cada marca grande.
  const ticks = 40;
  for (var i = 0; i <= ticks; i++) {
    final a = dialAngle(i / ticks);
    final major = i % 10 == 0;
    final len = major ? 14.0 : 7.0;
    final dir = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(c + dir * (rad - len), c + dir * rad, _stroke(major ? kText : kDim, major ? 3 : 2));
    if (major) _glyph(canvas, c + dir * (rad - 34), i ~/ 10, a);
  }

  if (v.showTarget) {
    final lo = dialAngle((v.target - v.tolerance).clamp(0.0, 1.0));
    final hi = dialAngle((v.target + v.tolerance).clamp(0.0, 1.0));
    canvas.drawArc(Rect.fromCircle(center: c, radius: rad + 1), lo, hi - lo, false,
        _stroke(kSignal.withValues(alpha: 0.8), 6));
  }

  final fx = v.fx;
  if (fx != null) {
    paintRoots(canvas, l, fx.plant);
    paintDialKnob(canvas, l, v.dial, fx);
    return;
  }
  // O botão: uma haste violeta do centro até a borda, na frequência do jogador.
  final a = dialAngle(v.dial);
  final dir = Offset(math.cos(a), math.sin(a));
  canvas.drawLine(c, c + dir * (rad - 10), _stroke(kVeil, 6));
  canvas.drawCircle(c + dir * (rad - 16), 9, _fill(kVeil));
  canvas.drawCircle(c + dir * (rad - 16), 4, _fill(kOutline));
  canvas.drawCircle(c, 12, _fill(kOutline));
  canvas.drawCircle(c, 12, _stroke(kVeil, 3));
}

/// Cinco glifos curtos em forma de traço de osciloscópio, um por marca grande.
void _glyph(Canvas canvas, Offset at, int index, double angle) {
  const shapes = [
    [0.0, 0.0, 0.5, -1.0, 0.0, 1.0, 0.5, 0.0], // pulso
    [0.0, 1.0, 0.3, 1.0, 0.3, -1.0, 0.7, -1.0], // degrau
    [0.0, 0.0, 0.25, -1.0, 0.5, 1.0, 0.75, -1.0], // ziguezague
    [0.0, 0.5, 0.25, -0.5, 0.5, 0.5, 0.75, -0.5], // onda
    [0.0, 0.0, 0.3, 0.0, 0.5, -1.0, 0.7, 0.0], // pico
  ];
  final pts = shapes[index % shapes.length];
  final p = Path();
  for (var i = 0; i < pts.length; i += 2) {
    final o = Offset(at.dx + (pts[i] - 0.4) * 22, at.dy + pts[i + 1] * 6);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  canvas.drawPath(p, _stroke(kSignal.withValues(alpha: 0.7), 2));
}
