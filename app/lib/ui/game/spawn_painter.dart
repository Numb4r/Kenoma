/// Desenho dos spawns no mapa: Ecos com o sprite da espécie, Fagulhas como faíscas na cor do tipo e
/// pontos de material como caixinhas. Só desenha; quem decide o que existe é `world/`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection;

import '../../capture/eco_type.dart';
import '../../world/map_camera.dart';
import '../../world/spawn_field.dart';
import '../colors.dart';

/// Tipo do Eco por espécie, para a cor do anel. Vem de `creatures.json` pelo mapa.
typedef EcoTypeOf = EcoType? Function(String speciesId);

/// Cor da Fagulha ou do material.
ui.Color spawnColor(WorldSpawn s, EcoTypeOf typeOf) {
  if (s.isEco) return typeColor(typeOf(s.entryId) ?? EcoType.fire);
  return switch (s.entryId) {
    'item.dust.fire' => typeColor(EcoType.fire),
    'item.dust.plant' => typeColor(EcoType.plant),
    'item.dust.water' => typeColor(EcoType.water),
    'item.scrap' => kDim,
    'item.chalk' => kText,
    'item.herbs' => typeColor(EcoType.plant),
    'item.pure_water' => typeColor(EcoType.water),
    _ => kEssence,
  };
}

/// Raio do anel do Eco dentro da Aura, em pixels de tela: fixo, não muda com o zoom.
const double kRingRadiusDp = 22;

/// Raio de toque de um spawn, em pixels. O Eco vale pelo sprite (de [spriteSize] pixels), com um mínimo para
/// dedo; Fagulhas e materiais valem por [sparkSize], também com um mínimo.
double hitRadius(WorldSpawn s, double spriteSize, double sparkSize) =>
    s.isEco ? math.max(26, spriteSize * 0.55) : math.max(28, sparkSize * 1.3);

void paintSpawns(
  ui.Canvas canvas,
  ui.Size view,
  MapCamera cam,
  List<WorldSpawn> spawns, {
  required Map<String, ui.Image> sprites,
  required EcoTypeOf typeOf,
  required bool Function(WorldSpawn) inAura,
  bool Function(WorldSpawn)? marked,
  required double time,
  required ui.Rect avoid,
  required double spriteSize,
  required double sparkSize,
  double dpr = 1,
}) {
  final ordered = [...spawns]..sort((a, b) => a.y.compareTo(b.y));
  for (final s in ordered) {
    final (sx, sy) = cam.cellToScreen(s.x, s.y, view.width, view.height);
    final margin = math.max(spriteSize, 60);
    if (sx < -margin || sy < -margin || sx > view.width + margin || sy > view.height + margin) continue;
    final center = ui.Offset(sx.roundToDouble(), sy.roundToDouble());
    final near = inAura(s);
    if (s.isEco) {
      _eco(canvas, center, s, sprites[s.entryId], spriteSize, typeOf, near, time, avoid);
      if (marked?.call(s) ?? false) _markRing(canvas, center, spriteSize);
    } else if (s.isSpark) {
      _spark(canvas, center, spawnColor(s, typeOf), sparkSize, dpr, near, time + s.uid % 7);
    } else {
      _material(canvas, center, spawnColor(s, typeOf), sparkSize, near);
    }
  }
}

final _flat = ui.Paint()..isAntiAlias = false;

/// Anel violeta quadrado em volta do Eco marcado: o sinal dele está preso.
void _markRing(ui.Canvas canvas, ui.Offset c, double size) {
  final r = ui.Rect.fromCenter(center: c, width: size * 0.9, height: size * 0.9);
  canvas.drawRect(r, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 2..color = kVeil..isAntiAlias = false);
}

void _eco(ui.Canvas canvas, ui.Offset c, WorldSpawn s, ui.Image? sprite, double size, EcoTypeOf typeOf, bool near, double time, ui.Rect avoid) {
  final color = spawnColor(s, typeOf);
  // Sombra no chão.
  canvas.drawOval(
    ui.Rect.fromCenter(center: c.translate(0, size * 0.42), width: size * 0.7, height: size * 0.18),
    ui.Paint()..color = kOutline.withValues(alpha: 0.55)..isAntiAlias = false,
  );
  final bob = near ? (math.sin(time * 3 + s.uid % 5) * 2).roundToDouble() : 0.0;
  final dst = ui.Rect.fromCenter(center: c.translate(0, bob), width: size, height: size);
  if (sprite != null) {
    canvas.drawImageRect(
      sprite,
      ui.Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
      dst,
      ui.Paint()..filterQuality = ui.FilterQuality.none..isAntiAlias = false..color = ui.Color.fromRGBO(255, 255, 255, near ? 1 : 0.55),
    );
  } else {
    canvas.drawRect(dst.deflate(size * 0.2), _flat..color = color);
  }
  if (!near) return;
  // Anel e rótulo têm tamanho fixo de tela. Perto do Conjurador ficam de fora: nada cobre o marcador.
  final ring = ui.Rect.fromCenter(center: c.translate(0, size * 0.42), width: kRingRadiusDp * 2, height: kRingRadiusDp * 2);
  if (!ring.overlaps(avoid)) {
    canvas.drawCircle(
      ring.center,
      kRingRadiusDp,
      ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 2..color = color..isAntiAlias = false,
    );
  }
  final label = TextPainter(
    text: TextSpan(text: 'NV ${s.level}', style: const TextStyle(fontFamily: 'Silkscreen', fontSize: 8, color: kText)),
    textDirection: TextDirection.ltr,
  )..layout();
  final x = c.dx - label.width / 2;
  final above = ui.Rect.fromLTWH(x, c.dy - size * 0.5 - 12, label.width, label.height);
  final below = ui.Rect.fromLTWH(x, c.dy + size * 0.5 + 4, label.width, label.height);
  final spot = !above.overlaps(avoid) ? above : (!below.overlaps(avoid) ? below : null);
  if (spot != null) label.paint(canvas, spot.topLeft);
}

/// Fagulha: uma faísca de [size] pixels de ponta a ponta (cerca de 3 m do mundo).
void _spark(ui.Canvas canvas, ui.Offset c, ui.Color color, double size, double dpr, bool near, double time) {
  final px = math.max(1, (size / 5 * dpr).round()) / dpr; // 5 pixels de ponta a ponta com o braço maior
  final pulse = 0.65 + 0.35 * math.sin(time * 4);
  final arm = (near ? 2 : 1) + (pulse > 0.85 ? 1 : 0);
  void block(double dx, double dy, ui.Color col) =>
      canvas.drawRect(ui.Rect.fromLTWH(c.dx + dx * px - px / 2, c.dy + dy * px - px / 2, px, px), _flat..color = col);
  for (var i = 1; i <= arm; i++) {
    for (final (dx, dy) in [(i, 0), (-i, 0), (0, i), (0, -i)]) {
      block(dx.toDouble(), dy.toDouble(), color.withValues(alpha: 0.9 - i * 0.2));
    }
  }
  block(0, 0, const ui.Color(0xFFFFFFFF));
}

/// Ponto de material: uma caixinha de [size] pixels de lado (cerca de 3 m do mundo).
void _material(ui.Canvas canvas, ui.Offset c, ui.Color color, double size, bool near) {
  final side = math.max(6.0, size);
  final r = ui.Rect.fromCenter(center: c, width: side, height: side);
  canvas.drawRect(r.inflate(2), _flat..color = kOutline);
  canvas.drawRect(r, _flat..color = near ? color : color.withValues(alpha: 0.6));
  canvas.drawRect(ui.Rect.fromLTWH(r.left, r.top, r.width, math.max(1.0, side * 0.2)), _flat..color = kText.withValues(alpha: near ? 0.5 : 0.25));
}
