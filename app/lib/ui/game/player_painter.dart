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

/// O retângulo que o Conjurador ocupa em [center], com o sprite de [size] pixels de lado.
Rect markerRect(Offset center, double size) => Rect.fromCenter(center: center, width: size, height: size);

double _snap(double v, double dpr) => (v * dpr).roundToDouble() / dpr;

/// Desenha o Conjurador em [center]. O sprite tem [size] pixels de lado na tela, que é a altura dele em
/// metros do mundo convertida pelo zoom. Com [mirrored] ele aparece espelhado na horizontal (andando para a
/// esquerda). Sem [sprite] (ainda carregando) não desenha nada.
void paintPlayerMarker(Canvas canvas, Offset center, {required Image? sprite, required double size, bool mirrored = false, double dpr = 1}) {
  if (sprite == null) return;
  final dst = Rect.fromLTWH(_snap(center.dx - size / 2, dpr), _snap(center.dy - size / 2, dpr), size, size);
  // Sombra no chão, sob os pés.
  canvas.drawOval(
    Rect.fromCenter(center: dst.bottomCenter.translate(0, -size * 0.04), width: size * 0.62, height: size * 0.14),
    Paint()
      ..color = kOutline.withValues(alpha: 0.5)
      ..isAntiAlias = false,
  );
  canvas.save();
  if (mirrored) {
    canvas.translate(dst.center.dx, 0);
    canvas.scale(-1, 1);
    canvas.translate(-dst.center.dx, 0);
  }
  canvas.drawImageRect(
    sprite,
    Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
    dst,
    Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false,
  );
  canvas.restore();
}

/// O equipamento por cima do Conjurador (0.24.0): cada camada é um quadro do mesmo tamanho do sprite, transparente fora da
/// peça, deslocado [dx] pixels de arte (as garrafas do cinto, uma ao lado da outra). Espelha junto com o sprite.
void paintPlayerGear(Canvas canvas, Offset center, {required List<(Image, int dx)> layers, required double size, bool mirrored = false, double dpr = 1}) {
  if (layers.isEmpty) return;
  final dst = Rect.fromLTWH(_snap(center.dx - size / 2, dpr), _snap(center.dy - size / 2, dpr), size, size);
  final paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  canvas.save();
  if (mirrored) {
    canvas.translate(dst.center.dx, 0);
    canvas.scale(-1, 1);
    canvas.translate(-dst.center.dx, 0);
  }
  for (final (img, dx) in layers) {
    final art = size / img.width;
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst.shift(Offset(dx * art, 0)), paint);
  }
  canvas.restore();
}
