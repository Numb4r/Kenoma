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

/// 0.24.5 (Veículos do Véu): uma camada do veículo montado, `_back` antes do Conjurador e `_front` depois. A tira tem
/// [frames] quadros de largura `w` com o Conjurador (`w/2` × `w/2` pixels) em `(w/4, w/16)` (32 × 24 com ele em (8, 2) na
/// grade de 3 dp; 48 × 36 com ele em (12, 3) na de 2 dp): o quadro sai alinhado ao sprite dele em [center] com [size].
/// [glow] (0 a 1): o brilho da qualidade, um contorno na cor do sinal.
void paintPlayerVehicle(Canvas canvas, Offset center, {required Image strip, required int frame, int frames = 2, required double size, bool mirrored = false, double dpr = 1, double glow = 0}) {
  final fw = strip.width / frames, art = size / (fw / 2);
  final player = Rect.fromLTWH(_snap(center.dx - size / 2, dpr), _snap(center.dy - size / 2, dpr), size, size);
  final dst = Rect.fromLTWH(player.left - fw / 4 * art, player.top - fw / 16 * art, fw * art, strip.height * art);
  final src = Rect.fromLTWH((frame % frames) * fw, 0, fw, strip.height.toDouble());
  canvas.save();
  if (mirrored) {
    canvas.translate(player.center.dx, 0);
    canvas.scale(-1, 1);
    canvas.translate(-player.center.dx, 0);
  }
  if (glow > 0) {
    final halo = Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = ColorFilter.mode(kSignal.withValues(alpha: glow), BlendMode.srcIn);
    for (final (dx, dy) in const [(-1.0, 0.0), (1.0, 0.0), (0.0, -1.0), (0.0, 1.0)]) {
      canvas.drawImageRect(strip, src, dst.shift(Offset(dx * art, dy * art)), halo);
    }
  }
  canvas.drawImageRect(strip, src, dst, Paint()..filterQuality = FilterQuality.none..isAntiAlias = false);
  canvas.restore();
}

/// O rastro de faíscas da qualidade Perfeita: [n] pixels de arte atrás do veículo, que piscam com o tempo [t].
void paintVehicleSparks(Canvas canvas, Offset center, {required double size, required bool mirrored, required double t, int n = 4, int playerPx = 24}) {
  final art = size / playerPx, back = mirrored ? 1.0 : -1.0;
  for (var i = 0; i < n; i++) {
    final phase = (t * 6 + i * 0.37) % 1;
    final x = center.dx + back * (size * 0.55 + (i + phase) * art * 2.5);
    final y = center.dy + size * 0.35 - ((i * 7 + (t * 10).floor()) % 3) * art;
    canvas.drawRect(Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), art, art), Paint()..color = (i.isEven ? kSignal : kEssence).withValues(alpha: 1 - phase));
  }
}
