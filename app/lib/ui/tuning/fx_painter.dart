/// Desenho dos efeitos da onda temática e do dial. Só pinta o que `capture/fx/` decidiu:
/// onde e quando cada efeito aparece não é calculado aqui.
library;

import 'dart:math' as math;
import 'dart:ui';

import '../../capture/fx/dial_fx.dart';
import '../../capture/fx/fire_fx.dart';
import '../../capture/fx/plant_fx.dart';
import '../../capture/fx/water_fx.dart';
import '../../capture/fx/wave_geometry.dart';
import '../colors.dart';
import 'tuning_layout.dart';

/// Estado dos efeitos no instante de desenhar. Os efeitos do tipo ficam vazios no modo oculto.
class TuningFx {
  const TuningFx({
    this.fire = FireFxState.none,
    this.foam = const [],
    this.plant = PlantFxState.none,
    required this.dial,
    required this.dialColor,
  });

  final FireFxState fire;
  final List<FoamFx> foam;
  final PlantFxState plant;
  final DialFx dial;

  /// Cor do dial alinhado: a do tipo, ou o ciano no modo oculto.
  final Color dialColor;
}

const Color _ember = Color(0xFFFF5A36);
const Color _flameMid = Color(0xFFFFB347);
const Color _flameCore = Color(0xFFFFF1C2);
const Color _leaf = Color(0xFF6BD36A);
const Color _leafDark = Color(0xFF3E8F4A);
const Color _root = Color(0xFF9A7B4F);
const Color _foam = Color(0xFFDDF4FF);

final Paint _p = Paint()..isAntiAlias = false;

Paint _fill(Color c) => _p
  ..style = PaintingStyle.fill
  ..color = c;

Paint _stroke(Color c, double w) => _p
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..color = c;

/// Onde a onda do sinal está no ponto [u]: x e y do painel [r].
Offset waveAt(Rect r, double f, double u, double scroll, double Function(double) shape) {
  final amp = r.height * 0.34;
  return Offset(r.left + r.width * u, r.center.dy - amp * waveEnvelope(u) * shape(waveTheta(f, u, scroll)));
}

/// A onda no ponto [u] do painel [r], com a fase [theta].
Offset waveAtTheta(Rect r, double u, double theta, double Function(double) shape) {
  final amp = r.height * 0.34;
  return Offset(r.left + r.width * u, r.center.dy - amp * waveEnvelope(u) * shape(theta));
}

/// Efeitos do Fogo, da Água e da Planta sobre a onda. [f] é a frequência do sinal na tela.
void paintWaveFx(Canvas canvas, Rect r, double f, double scroll, TuningFx fx) {
  final amp = r.height * 0.34;
  // Depois da primeira queima a onda real é a do trecho da direita, presa à fronteira.
  final real = fx.fire.split?.real;
  double theta(double u) => real?.thetaAt(u) ?? waveTheta(f, u, scroll);
  Offset onWave(double u) => waveAtTheta(r, u, theta(u), triShape);
  for (final e in fx.fire.embers) {
    final at = onWave(e.u);
    final radius = 3 + 6 * e.glow;
    canvas.drawCircle(at, radius + 3, _fill(_ember.withValues(alpha: 0.25 * e.glow)));
    canvas.drawCircle(at, radius, _fill(_ember));
    canvas.drawCircle(at, radius * 0.45, _fill(_flameCore));
  }
  for (final fl in fx.fire.flames) {
    _flame(canvas, onWave(fl.u), fl.height * amp, fl.halfWidth * r.width);
  }
  for (final a in fx.fire.ashes) {
    final base = onWave(a.u);
    for (final p in a.particles) {
      final s = 2 + 3 * p.size;
      canvas.drawRect(
        Rect.fromLTWH(base.dx + p.x * r.width, base.dy - p.y * amp - s, s, s),
        _fill(kDim.withValues(alpha: p.alpha.clamp(0.0, 1.0))),
      );
    }
  }
  for (final fm in fx.foam) {
    final crest = waveAt(r, f, fm.u, scroll, triShape);
    for (final p in fm.particles) {
      final s = 2 + 3 * p.size;
      canvas.drawRect(
        Rect.fromLTWH(crest.dx + p.x * r.width, crest.dy - p.y * amp - s, s, s),
        _fill(_foam.withValues(alpha: p.alpha.clamp(0.0, 1.0))),
      );
    }
  }
  for (final l in fx.plant.leaves) {
    _leafShape(canvas, waveAt(r, f, l.u, scroll, triShape), l.size, l.side, r.height);
  }
}

/// Chama em três camadas, de [height] px de altura e [halfWidth] px de meia largura, com a base em [at].
void _flame(Canvas canvas, Offset at, double height, double halfWidth) {
  if (height <= 1) return;
  void layer(Color c, double k) {
    final h = height * k;
    final w = halfWidth * k;
    final path = Path()
      ..moveTo(at.dx - w, at.dy)
      ..lineTo(at.dx - w * 0.6, at.dy - h * 0.5)
      ..lineTo(at.dx - w * 0.15, at.dy - h * 0.75)
      ..lineTo(at.dx, at.dy - h)
      ..lineTo(at.dx + w * 0.3, at.dy - h * 0.6)
      ..lineTo(at.dx + w * 0.7, at.dy - h * 0.45)
      ..lineTo(at.dx + w, at.dy)
      ..close();
    canvas.drawPath(path, _fill(c));
  }

  layer(_ember, 1);
  layer(_flameMid, 0.7);
  layer(_flameCore, 0.4);
}

/// Folha de [size] (0 a 1) que nasce em [at], inclinada para o lado [side]. [panelH] dá a escala.
void _leafShape(Canvas canvas, Offset at, double size, double side, double panelH) {
  if (size <= 0) return;
  final len = panelH * 0.2 * size;
  final tip = at + Offset(side * len * 0.7, -len * 0.7);
  final mid = Offset.lerp(at, tip, 0.5)!;
  final nx = -(tip.dy - at.dy) * 0.28;
  final ny = (tip.dx - at.dx) * 0.28;
  final path = Path()
    ..moveTo(at.dx, at.dy)
    ..lineTo(mid.dx + nx, mid.dy + ny)
    ..lineTo(tip.dx, tip.dy)
    ..lineTo(mid.dx - nx, mid.dy - ny)
    ..close();
  canvas.drawPath(path, _fill(_leaf));
  canvas.drawLine(at, tip, _stroke(_leafDark, 2));
}

/// Raízes da Planta fincadas no dial, cada uma na faixa fixa dela. O dial dentro de uma raiz não alinha.
void paintRoots(Canvas canvas, TuningLayout l, PlantFxState plant) {
  final c = l.dialCenter;
  final rad = l.dialRadius;
  for (final root in plant.roots) {
    final a0 = dialAngle(root.lo);
    final a1 = dialAngle(root.hi);
    final main = Rect.fromCircle(center: c, radius: rad - 4);
    canvas.drawArc(main, a0, a1 - a0, false, _stroke(_root.withValues(alpha: 0.35), 12));
    canvas.drawArc(main, a0, a1 - a0, false, _stroke(_root, 3));
    for (final b in root.branches) {
      final a = a0 + (a1 - a0) * b.along;
      final dir = Offset(math.cos(a), math.sin(a));
      final tangent = Offset(-dir.dy, dir.dx) * b.side * 0.5;
      final from = c + dir * (rad - 4);
      canvas.drawLine(from, from - (dir - tangent) * ((6 + 14 * b.length) * root.growth), _stroke(_root, 2));
    }
  }
}

/// Botão e haste do dial. Violeta fora do alinhamento. Alinhado, a cor vira a do tipo ao longo de
/// ~150 ms e o dial engrossa, ganha um halo e solta partículas: não depende só da cor.
void paintDialKnob(Canvas canvas, TuningLayout l, double dial, TuningFx fx) {
  final c = l.dialCenter;
  final rad = l.dialRadius;
  final d = fx.dial;
  final color = Color.lerp(kVeil, fx.dialColor, d.blend)!;
  final thick = d.thickness;
  final a = dialAngle(dial);
  final dir = Offset(math.cos(a), math.sin(a));
  final tip = c + dir * (rad - 16);

  if (d.glow > 0) {
    canvas.drawCircle(tip, 9 * thick + 10 * d.glow, _fill(color.withValues(alpha: 0.18 * d.glow)));
    canvas.drawCircle(tip, 9 * thick + 4 * d.glow, _fill(color.withValues(alpha: 0.30 * d.glow)));
    canvas.drawLine(c, c + dir * (rad - 10), _stroke(color.withValues(alpha: 0.3 * d.glow), 6 * thick + 8));
  }
  canvas.drawLine(c, c + dir * (rad - 10), _stroke(color, 6 * thick));
  canvas.drawCircle(tip, 9 * thick, _fill(color));
  canvas.drawCircle(tip, 4 * thick, _fill(kOutline));
  canvas.drawCircle(c, 12, _fill(kOutline));
  canvas.drawCircle(c, 12, _stroke(color, 3 * thick));

  for (final p in d.particles) {
    final pa = p.angle + p.drift * p.age;
    final at = c + Offset(math.cos(pa), math.sin(pa)) * (rad * p.radius);
    final s = 3 + 3 * (1 - p.life);
    canvas.drawRect(Rect.fromCenter(center: at, width: s, height: s), _fill(color.withValues(alpha: p.alpha)));
  }
}
