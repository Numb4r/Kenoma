/// Desenho dos spawns no mapa: Ecos com o sprite da espécie, Fagulhas como faíscas na cor do tipo e
/// pontos de material como caixinhas. Só desenha; quem decide o que existe é `world/`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection;

import '../../capture/eco_type.dart';
import '../../core/behavior.dart';
import '../../core/species_ids.dart';
import '../../world/map_camera.dart';
import '../../world/spawn_field.dart';
import '../colors.dart';

/// Tipo do Eco por espécie, para a cor do anel. Vem de `creatures.json` pelo mapa.
typedef EcoTypeOf = EcoType? Function(String speciesId);

/// A cor da paleta de uma variante ou Brilhante (0xAARRGGBB), ou `null` se o Eco é comum.
typedef VariantTintOf = int? Function(WorldSpawn spawn);

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
double hitRadius(WorldSpawn s, double spriteSize, double sparkSize, {double? spiritSize}) =>
    s.isEco ? math.max(26, (isSpiritSpawn(s) ? (spiritSize ?? spriteSize) : spriteSize) * 0.55) : math.max(28, sparkSize * 1.3);

/// O spawn é de um Espírito (camada acima do Eco): maior no mapa e com a aura do Véu.
bool isSpiritSpawn(WorldSpawn s) => s.isEco && tierOfId(s.entryId) == SpeciesTier.spirit;

void paintSpawns(
  ui.Canvas canvas,
  ui.Size view,
  MapCamera cam,
  List<WorldSpawn> spawns, {
  required Map<String, ui.Image> sprites,
  required EcoTypeOf typeOf,
  required bool Function(WorldSpawn) inAura,
  bool Function(WorldSpawn)? marked,
  VariantTintOf? tintOf,
  double Function(int uid)? hopOf,
  double Function(int uid)? appearOf,
  required double time,
  required ui.Rect avoid,
  required double spriteSize,
  required double sparkSize,
  double? spiritSize,
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
      final size = isSpiritSpawn(s) ? (spiritSize ?? spriteSize) : spriteSize;
      final tint = tintOf?.call(s);
      final appear = appearOf?.call(s.uid) ?? 1.0;
      final hop = hopOf?.call(s.uid) ?? 0.0;
      if (appear < 1) {
        // A costura abre do centro para fora e o Eco aparece dentro dela.
        canvas.save();
        canvas.clipRect(ui.Rect.fromCenter(center: center, width: size * appear + 1, height: size * 2));
        _eco(canvas, center.translate(0, hop), s, sprites[s.entryId], size, typeOf, near, time, avoid, tint: tint);
        canvas.restore();
        paintSeam(canvas, center, size, appear);
      } else {
        _eco(canvas, center.translate(0, hop), s, sprites[s.entryId], size, typeOf, near, time, avoid, tint: tint);
      }
      if (s.behavior != EcoBehavior.passive) _behaviorIcon(canvas, center, s.behavior, size);
      if (marked?.call(s) ?? false) _markRing(canvas, center, size);
    } else if (s.isSpark) {
      _spark(canvas, center, spawnColor(s, typeOf), sparkSize, dpr, near, time + s.uid % 7);
    } else {
      _material(canvas, center, spawnColor(s, typeOf), sparkSize, near);
    }
  }
}

final _flat = ui.Paint()..isAntiAlias = false;

/// O ícone do comportamento, pequeno, no canto de cima à direita do Eco: dois chevrons (Arisco), um ponto de exclamação
/// (Agressivo) ou um olho (Oculto revelado).
void _behaviorIcon(ui.Canvas canvas, ui.Offset c, EcoBehavior b, double size) {
  final o = c.translate(size * 0.42, -size * 0.5);
  final box = ui.Rect.fromCenter(center: o, width: 13, height: 13);
  canvas.drawRect(box.inflate(1.5), _flat..color = kOutline);
  canvas.drawRect(box, _flat..color = kPanel);
  switch (b) {
    case EcoBehavior.skittish:
      _flat.color = kSignal;
      for (final dx in [-3.0, 1.0]) {
        canvas.drawRect(ui.Rect.fromLTWH(o.dx + dx, o.dy - 4, 2, 2), _flat);
        canvas.drawRect(ui.Rect.fromLTWH(o.dx + dx + 2, o.dy - 2, 2, 2), _flat);
        canvas.drawRect(ui.Rect.fromLTWH(o.dx + dx + 2, o.dy, 2, 2), _flat);
        canvas.drawRect(ui.Rect.fromLTWH(o.dx + dx, o.dy + 2, 2, 2), _flat);
      }
    case EcoBehavior.aggressive:
      _flat.color = kEssence;
      canvas.drawRect(ui.Rect.fromLTWH(o.dx - 1, o.dy - 5, 2, 6), _flat);
      canvas.drawRect(ui.Rect.fromLTWH(o.dx - 1, o.dy + 2, 2, 2), _flat);
    case EcoBehavior.hidden:
      _flat.color = kVeil;
      canvas.drawRect(ui.Rect.fromLTWH(o.dx - 4, o.dy - 1, 8, 2), _flat);
      canvas.drawRect(ui.Rect.fromLTWH(o.dx - 3, o.dy - 3, 6, 2), _flat);
      canvas.drawRect(ui.Rect.fromLTWH(o.dx - 3, o.dy + 1, 6, 2), _flat);
      canvas.drawRect(ui.Rect.fromLTWH(o.dx - 1, o.dy - 1, 2, 2), _flat..color = kText);
    case EcoBehavior.passive:
      break;
  }
}

/// Anel violeta quadrado em volta do Eco marcado: o sinal dele está preso.
void _markRing(ui.Canvas canvas, ui.Offset c, double size) {
  final r = ui.Rect.fromCenter(center: c, width: size * 0.9, height: size * 0.9);
  canvas.drawRect(r, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 2..color = kVeil..isAntiAlias = false);
}

void _eco(ui.Canvas canvas, ui.Offset c, WorldSpawn s, ui.Image? sprite, double size, EcoTypeOf typeOf, bool near, double time, ui.Rect avoid, {int? tint}) {
  final color = spawnColor(s, typeOf);
  // Sombra no chão.
  canvas.drawOval(
    ui.Rect.fromCenter(center: c.translate(0, size * 0.42), width: size * 0.7, height: size * 0.18),
    ui.Paint()..color = kOutline.withValues(alpha: 0.55)..isAntiAlias = false,
  );
  final bob = near ? (math.sin(time * 3 + s.uid % 5) * 2).roundToDouble() : 0.0;
  final dst = ui.Rect.fromCenter(center: c.translate(0, bob), width: size, height: size);
  if (isSpiritSpawn(s)) {
    // A aura do Espírito: um brilho suave do Véu que respira (o único brilho permitido; arte final no backlog).
    final pulse = 0.7 + 0.3 * math.sin(time * 1.6 + s.uid % 9);
    final r = size * 0.95;
    canvas.drawCircle(
      dst.center,
      r,
      ui.Paint()
        ..shader = ui.Gradient.radial(dst.center, r, [kVeil.withValues(alpha: 0.4 * pulse), kVeil.withValues(alpha: 0)])
        ..isAntiAlias = true,
    );
  }
  if (s.shiny) {
    // O Brilhante: um halo suave que pulsa. É o único brilho permitido no estilo.
    final pulse = 0.65 + 0.35 * math.sin(time * 2.4 + s.uid % 9);
    final r = size * 0.85;
    canvas.drawCircle(
      dst.center,
      r,
      ui.Paint()
        ..shader = ui.Gradient.radial(dst.center, r, [const ui.Color(0xFFFFE9A8).withValues(alpha: 0.45 * pulse), const ui.Color(0x00FFE9A8)])
        ..isAntiAlias = true,
    );
  }
  if (sprite != null && near) {
    // Ao alcance de toque (30 m): contorno violeta pulsando em volta da silhueta, um pixel de arte de espessura.
    final px = size / sprite.width;
    final pulse = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(time * 4.5 + s.uid % 7));
    final outline = ui.Paint()
      ..filterQuality = ui.FilterQuality.none
      ..isAntiAlias = false
      ..colorFilter = ui.ColorFilter.mode(kVeil.withValues(alpha: pulse), ui.BlendMode.srcIn);
    for (final (dx, dy) in [(px, 0.0), (-px, 0.0), (0.0, px), (0.0, -px)]) {
      canvas.drawImageRect(sprite, ui.Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()), dst.shift(ui.Offset(dx, dy)), outline);
    }
  }
  if (sprite != null) {
    canvas.drawImageRect(
      sprite,
      ui.Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
      dst,
      ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..isAntiAlias = false
        ..color = ui.Color.fromRGBO(255, 255, 255, near ? 1 : 0.55)
        // A paleta da variante: um tom por cima da silhueta (srcATop), sem arte nova.
        ..colorFilter = tint == null ? null : ui.ColorFilter.mode(ui.Color(tint).withValues(alpha: s.shiny ? 0.55 : 0.4), ui.BlendMode.srcATop),
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

/// A Fagulha e o material fora do mapa (o efeito de coleta os reaproveita).
void paintSparkIcon(ui.Canvas canvas, ui.Offset c, ui.Color color, double size, double dpr) => _spark(canvas, c, color, size, dpr, true, 0);
void paintMaterialIcon(ui.Canvas canvas, ui.Offset c, ui.Color color, double size) => _material(canvas, c, color, size, true);

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

/// A costura do Véu abrindo em volta de um Eco que acaba de aparecer: duas linhas violeta que se afastam do centro. O
/// chamador recorta o sprite à largura aberta ([u] de 0 a 1).
void paintSeam(ui.Canvas canvas, ui.Offset c, double size, double u) {
  final half = size * 0.5 * u;
  final h = size * (0.35 + 0.65 * u);
  for (final sx in [-half, half]) {
    canvas.drawRect(ui.Rect.fromCenter(center: c.translate(sx, 0), width: 2, height: h), ui.Paint()..color = kVeil..isAntiAlias = false);
  }
}
