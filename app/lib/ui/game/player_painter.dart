/// Desenho do Conjurador e da Aura no chão. O marcador é um placeholder em pixel art, na paleta fixa do
/// jogo (violeta do Véu, ciano do sinal, contorno ameixa): arte nunca bloqueia código.
library;

import 'dart:math' as math;
import 'dart:ui';

import '../colors.dart';

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

/// Tamanho do sprite do Conjurador na tela, em pixels lógicos: [heightDp] de altura, com cada pixel de
/// arte do sprite de 48 x 48 ocupando um número inteiro de pixels físicos.
double playerSize(double dpr, double heightDp) => 48 * math.max(1, (heightDp * dpr / 48).round()) / dpr;

/// O retângulo que o Conjurador ocupa em [center].
Rect markerRect(Offset center, double dpr, double heightDp) {
  final s = playerSize(dpr, heightDp);
  return Rect.fromCenter(center: center, width: s, height: s);
}

double _snap(double v, double dpr) => (v * dpr).roundToDouble() / dpr;

/// Desenha o Conjurador em [center], com [heightDp] de altura em qualquer zoom. Sem [sprite] (ainda
/// carregando) não desenha nada.
void paintPlayerMarker(Canvas canvas, Offset center, {required Image? sprite, required double heightDp, double dpr = 1}) {
  if (sprite == null) return;
  final size = playerSize(dpr, heightDp);
  final dst = Rect.fromLTWH(_snap(center.dx - size / 2, dpr), _snap(center.dy - size / 2, dpr), size, size);
  // Sombra no chão, sob os pés.
  canvas.drawOval(
    Rect.fromCenter(center: dst.bottomCenter.translate(0, -size * 0.04), width: size * 0.62, height: size * 0.14),
    Paint()
      ..color = kOutline.withValues(alpha: 0.5)
      ..isAntiAlias = false,
  );
  canvas.drawImageRect(
    sprite,
    Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
    dst,
    Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false,
  );
}
