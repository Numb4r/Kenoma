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

/// Tamanho do sprite do Eco na tela, em pixels lógicos: tão alto quanto o Conjurador ([heightDp]), com
/// cada pixel de arte ocupando um número inteiro de pixels físicos.
double ecoSize(double dpr, double heightDp) => 48 * math.max(1, (heightDp * dpr / 48).round()) / dpr;

/// Lado do pixel das Fagulhas e dos materiais: pequenos, ~3 dp, em pixels físicos inteiros.
double smallUnit(double dpr) => math.max(1, (3 * dpr).round()) / dpr;

/// Raio de toque de um spawn, em pixels.
double hitRadius(WorldSpawn s, double dpr, double heightDp) => s.isEco ? ecoSize(dpr, heightDp) * 0.6 : 28;

void paintSpawns(
  ui.Canvas canvas,
  ui.Size view,
  MapCamera cam,
  List<WorldSpawn> spawns, {
  required Map<String, ui.Image> sprites,
  required EcoTypeOf typeOf,
  required bool Function(WorldSpawn) inAura,
  required double time,
  required ui.Rect avoid,
  required double heightDp,
  double dpr = 1,
}) {
  final ordered = [...spawns]..sort((a, b) => a.y.compareTo(b.y));
  for (final s in ordered) {
    final (sx, sy) = cam.cellToScreen(s.x, s.y, view.width, view.height);
    if (sx < -60 || sy < -60 || sx > view.width + 60 || sy > view.height + 60) continue;
    final center = ui.Offset(sx.roundToDouble(), sy.roundToDouble());
    final near = inAura(s);
    if (s.isEco) {
      _eco(canvas, center, s, sprites[s.entryId], dpr, heightDp, typeOf, near, time, avoid);
    } else if (s.isSpark) {
      _spark(canvas, center, spawnColor(s, typeOf), dpr, near, time + s.uid % 7);
    } else {
      _material(canvas, center, spawnColor(s, typeOf), dpr, near);
    }
  }
}

final _flat = ui.Paint()..isAntiAlias = false;

void _eco(ui.Canvas canvas, ui.Offset c, WorldSpawn s, ui.Image? sprite, double dpr, double heightDp, EcoTypeOf typeOf, bool near, double time, ui.Rect avoid) {
  final size = ecoSize(dpr, heightDp);
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
  // Perto do Conjurador o anel e o rótulo ficam de fora: nada cobre o marcador.
  final ring = ui.Rect.fromCenter(center: c.translate(0, size * 0.42), width: size * 0.84, height: size * 0.84);
  if (!ring.overlaps(avoid)) {
    canvas.drawCircle(
      ring.center,
      ring.width / 2,
      ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 2..color = color..isAntiAlias = false,
    );
  }
  final label = TextPainter(
    text: TextSpan(text: 'NV ${s.level}', style: const TextStyle(fontFamily: 'Silkscreen', fontSize: 8, color: kText)),
    textDirection: TextDirection.ltr,
  )..layout();
  final x = c.dx - label.width / 2;
  final above = ui.Rect.fromLTWH(x, c.dy - size * 0.62 - 10, label.width, label.height);
  final below = ui.Rect.fromLTWH(x, c.dy + size * 0.62 + 2, label.width, label.height);
  final spot = !above.overlaps(avoid) ? above : (!below.overlaps(avoid) ? below : null);
  if (spot != null) label.paint(canvas, spot.topLeft);
}

void _spark(ui.Canvas canvas, ui.Offset c, ui.Color color, double dpr, bool near, double time) {
  final px = smallUnit(dpr);
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

void _material(ui.Canvas canvas, ui.Offset c, ui.Color color, double dpr, bool near) {
  final px = smallUnit(dpr);
  final r = ui.Rect.fromCenter(center: c, width: px * 4, height: px * 4);
  canvas.drawRect(r.inflate(px / 2), _flat..color = kOutline);
  canvas.drawRect(r, _flat..color = near ? color : color.withValues(alpha: 0.6));
  canvas.drawRect(ui.Rect.fromLTWH(r.left, r.top, r.width, px), _flat..color = kText.withValues(alpha: near ? 0.5 : 0.25));
}
