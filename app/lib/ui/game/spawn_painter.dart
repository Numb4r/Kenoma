/// Desenho dos spawns no mapa: Ecos com o sprite da espécie, Fagulhas como faíscas na cor do tipo e
/// pontos de material como caixinhas. Só desenha; quem decide o que existe é `world/`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection;

import '../../capture/eco_type.dart';
import '../../core/behavior.dart';
import '../../core/species_ids.dart';
import '../../world/creature_wind.dart';
import '../../world/map_camera.dart';
import '../../world/spawn_field.dart';
import '../colors.dart';
import '../sprites/sprite_image.dart' show provisionalArt, mapArchetypePx, mapMajorPx, mapSpiritPx;
import '../sprites/variant_art.dart' show shinyPulse;
import '../sprites/material_sprites.dart';
import 'creature_anim.dart';
import 'creature_art.dart';
import 'spawn_trigger.dart';
import 'traffic_art.dart' show SparkArt;

/// Tipo do Eco por espécie, para a cor do anel. Vem de `creatures.json` pelo mapa.
typedef EcoTypeOf = EcoType? Function(String speciesId);

/// A cor da paleta de uma variante ou Brilhante (0xAARRGGBB), ou `null` se o Eco é comum.
typedef VariantTintOf = int? Function(WorldSpawn spawn);

/// Cor da Fagulha ou do material.
ui.Color spawnColor(WorldSpawn s, EcoTypeOf typeOf) {
  if (s.isEco) return typeColor(typeOf(s.entryId) ?? EcoType.fire);
  // A Fagulha tem a cor do tipo dela (`item.dust.<tipo>`).
  if (s.entryId.startsWith('item.dust.')) {
    final name = s.entryId.substring('item.dust.'.length);
    for (final t in EcoType.values) {
      if (t.name == name) return typeColor(t);
    }
  }
  return switch (s.entryId) {
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
    s.isEco ? math.max(26, ecoDrawSize(s, spriteSize, spiritSize) * 0.55) : math.max(28, sparkSize * 1.3);

/// O spawn é de um Espírito ou de camada mais alta (0.27.0: a Entidade Maior e o Arquétipo): maior no mapa e com a aura
/// do Véu.
bool isSpiritSpawn(WorldSpawn s) => s.isEco && tierOfId(s.entryId) != SpeciesTier.eco;

/// O lado desenhado de um Eco no mapa: o do Eco, o do Espírito, e a Entidade (48 px) e o Arquétipo (64 px) na mesma
/// escala do Espírito.
double ecoDrawSize(WorldSpawn s, double spriteSize, double? spiritSize) => switch (tierOfId(s.entryId)) {
      SpeciesTier.eco => spriteSize,
      SpeciesTier.spirit => spiritSize ?? spriteSize,
      SpeciesTier.major => (spiritSize ?? spriteSize) * mapMajorPx / mapSpiritPx,
      SpeciesTier.archetype => (spiritSize ?? spriteSize) * mapArchetypePx / mapSpiritPx,
    };

void paintSpawns(
  ui.Canvas canvas,
  ui.Size view,
  MapCamera cam,
  List<WorldSpawn> spawns, {
  required Map<String, ui.Image> sprites,
  required EcoTypeOf typeOf,
  required bool Function(WorldSpawn) inAura,
  bool Function(WorldSpawn)? marked,
  bool Function(WorldSpawn)? pinned,
  VariantTintOf? tintOf,
  double Function(int uid)? hopOf,
  double Function(int uid)? appearOf,
  required double time,
  required ui.Rect avoid,
  required double spriteSize,
  required double sparkSize,
  double? spiritSize,
  double dpr = 1,
  CreatureWind? wind,
  ui.Offset windDir = ui.Offset.zero,
  ui.Offset Function(WorldSpawn s)? localWind,
  double pxPerM = 0,
  double artPixelDp = 3,
  bool Function(int uid)? facingLeftOf,
  Map<int, ui.Offset>? anchors,
  bool Function(int uid)? movingOf,
  (SpawnTrigger, ui.Offset?)? Function(WorldSpawn s)? triggerOf,
  ui.Color? bodyTone,
  List<void Function()>? emissive,
}) {
  final ordered = [...spawns]..sort((a, b) => a.y.compareTo(b.y));
  final climateWind = windDir;
  final blow = wind != null && !wind.calm && windDir != ui.Offset.zero;
  for (final s in ordered) {
    var (sx, sy) = cam.cellToScreen(s.x, s.y, view.width, view.height);
    var lean = 0.0;
    // O vento no lugar da criatura (canalizado pela rua, fraco atrás das quadras), ou o do clima se não há o local.
    final windDir = localWind?.call(s) ?? climateWind;
    if (blow) {
      // Só desenho: o empurrão dos leves e a inclinação; o ponto de coleta continua em (s.x, s.y).
      final push = windDir * (wind.pushM(s, time) * pxPerM);
      sx += push.dx;
      sy += push.dy;
      lean = wind.lean(s.uid, time) * windDir.dx;
    }
    final margin = math.max(spriteSize, 60);
    if (sx < -margin || sy < -margin || sx > view.width + margin || sy > view.height + margin) continue;
    final center = ui.Offset(sx.roundToDouble(), sy.roundToDouble());
    anchors?[s.uid] = center; // 0.25.0: o ponto de ancoragem desenhado (com o vento): os efeitos na criatura se centram nele
    final near = inAura(s);
    if (s.isEco) {
      final size = ecoDrawSize(s, spriteSize, spiritSize);
      final tint = tintOf?.call(s);
      final appear = appearOf?.call(s.uid) ?? 1.0;
      final hop = hopOf?.call(s.uid) ?? 0.0;
      // 0.25.0: a criatura com arte animada (o Humoth) desenha a animação do estado, com o corpo no tom da noite e o que
      // brilha na camada emissiva, depois do clima.
      final anim = CreatureArt.of(s.entryId);
      if (anim != null) {
        _animatedEco(canvas, center.translate(0, hop), s, anim, size, near, time, appear: appear, moving: movingOf?.call(s.uid) ?? false, flip: facingLeftOf?.call(s.uid) ?? false, tone: bodyTone, emissive: emissive, lean: lean, trigger: appear < 1 ? triggerOf?.call(s) : null);
        if (marked?.call(s) ?? false) _markRing(canvas, center, size);
        if (pinned?.call(s) ?? false) _pinMarker(canvas, center, size, time);
        if (near) _touchRingOf(canvas, center, s, size, avoid, spawnColor(s, typeOf));
        continue;
      }
      // 0.26.2: na release o sprite provisório nunca aparece; sem a arte do Aseprite (ainda carregando) o Eco não se desenha.
      if (!provisionalArt) continue;
      if (appear < 1) {
        // A costura abre do centro para fora e o Eco aparece dentro dela.
        canvas.save();
        canvas.clipRect(ui.Rect.fromCenter(center: center, width: size * appear + 1, height: size * 2));
        _eco(canvas, center.translate(0, hop), s, _spriteOf(sprites, s), size, typeOf, near, time, avoid, tint: _hasVariantArt(sprites, s) ? null : tint, lean: lean, glow: sprites['${s.entryId}@lit#glow'], flip: facingLeftOf?.call(s.uid) ?? false);
        canvas.restore();
        paintSeam(canvas, center, size, appear);
      } else {
        _eco(canvas, center.translate(0, hop), s, _spriteOf(sprites, s), size, typeOf, near, time, avoid, tint: _hasVariantArt(sprites, s) ? null : tint, lean: lean, glow: sprites['${s.entryId}@lit#glow'], flip: facingLeftOf?.call(s.uid) ?? false);
      }
      if (blow) _motes(canvas, center, wind.motes(s.uid, time), windDir, size, _moteColor(s, typeOf));
      if (s.behavior != EcoBehavior.passive) _behaviorIcon(canvas, center, s.behavior, size);
      if (s.tag == 'charged') _chargedSparks(canvas, center, size, time + s.uid % 5);
      if (marked?.call(s) ?? false) _markRing(canvas, center, size);
      if (pinned?.call(s) ?? false) _pinMarker(canvas, center, size, time);
    } else if (s.isSpark) {
      final art = SparkArt.current, strip = art?.strips[s.entryId.startsWith('item.dust.') ? s.entryId.substring(10) : ''];
      if (art != null && strip != null) {
        // 0.25.1: a Fagulha do Aseprite (a forma do tipo, pulsando), com o brilho aceso por cima da noite.
        _leaning(canvas, center.translate(0, sparkSize / 2), lean, () => _sparkArt(canvas, center, art, strip, sparkSize, dpr, near, time, s.uid, emissive: bodyTone == null ? null : emissive));
      } else {
        _leaning(canvas, center.translate(0, sparkSize / 2), lean, () => _spark(canvas, center, spawnColor(s, typeOf), sparkSize, dpr, near, time + s.uid % 7));
      }
      if (blow) _motes(canvas, center, wind.motes(s.uid, time), windDir, sparkSize * 1.5, spawnColor(s, typeOf));
    } else if (_materialImage(s.entryId) case final img?) {
      _materialSprite(canvas, center, img, artPixelDp, near);
    } else {
      _material(canvas, center, spawnColor(s, typeOf), sparkSize, near);
    }
  }
}

final _flat = ui.Paint()..isAntiAlias = false;

/// Desenha [draw] inclinado [lean] radianos em volta de [feet] (o vento: o topo vai para o lado, os pés ficam).
void _leaning(ui.Canvas canvas, ui.Offset feet, double lean, void Function() draw) {
  if (lean.abs() < 1e-3) return draw();
  canvas.save();
  canvas.translate(feet.dx, feet.dy);
  canvas.skew(-math.tan(lean), 0);
  canvas.translate(-feet.dx, -feet.dy);
  draw();
  canvas.restore();
}

/// O que se solta do sprite com o vento: brasas do Fogo, folhas da Planta, fiapos da Água.
ui.Color _moteColor(WorldSpawn s, EcoTypeOf typeOf) => switch (typeOf(s.entryId)) {
      EcoType.fire => kEssence,
      EcoType.plant => const ui.Color(0xFF6BD36A),
      _ => kText,
    };

/// As partículas soltas, saindo de [c] na direção [dir] do vento (pixels de tela), um pixel de arte cada.
void _motes(ui.Canvas canvas, ui.Offset c, List<WindMote> motes, ui.Offset dir, double size, ui.Color color) {
  if (motes.isEmpty) return;
  final px = math.max(1.0, (size / 16).roundToDouble());
  final side = ui.Offset(-dir.dy, dir.dx);
  for (final m in motes) {
    final p = c + dir * (size * 0.3 + m.along * size * 1.6) + side * (m.side * size * 0.35);
    canvas.drawRect(ui.Rect.fromLTWH(p.dx.roundToDouble(), p.dy.roundToDouble(), px, px), _flat..color = color.withValues(alpha: m.alpha.clamp(0.0, 1.0)));
  }
}

/// O ícone do comportamento, pequeno, no canto de cima à direita do Eco: um olho (Oculto revelado).
void _behaviorIcon(ui.Canvas canvas, ui.Offset c, EcoBehavior b, double size) {
  final o = c.translate(size * 0.42, -size * 0.5);
  final box = ui.Rect.fromCenter(center: o, width: 13, height: 13);
  canvas.drawRect(box.inflate(1.5), _flat..color = kOutline);
  canvas.drawRect(box, _flat..color = kPanel);
  switch (b) {
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

/// A faísca em volta do Eco carregado do raio: três pontos ciano girando e piscando. É o único aviso dele.
void _chargedSparks(ui.Canvas canvas, ui.Offset c, double size, double time) {
  for (var i = 0; i < 3; i++) {
    final a = time * 2.4 + i * 2.094;
    if (math.sin(time * 9 + i * 1.7) < -0.3) continue; // pisca
    final p = c.translate(math.cos(a) * size * 0.5, math.sin(a) * size * 0.3 - size * 0.15);
    canvas.drawRect(ui.Rect.fromCenter(center: p, width: 3, height: 3), _flat..color = kSignal);
    canvas.drawRect(ui.Rect.fromCenter(center: p, width: 1, height: 5), _flat..color = kText);
  }
}

/// Anel violeta quadrado em volta do Eco marcado: o sinal dele está preso.
void _markRing(ui.Canvas canvas, ui.Offset c, double size) {
  final r = ui.Rect.fromCenter(center: c, width: size * 0.9, height: size * 0.9);
  canvas.drawRect(r, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 2..color = kVeil..isAntiAlias = false);
}

/// Espécie marcada no Bestiário: cantos em ciano do sinal em volta do Eco e uma seta acima, pulsando.
void _pinMarker(ui.Canvas canvas, ui.Offset c, double size, double time) {
  final pulse = 0.6 + 0.4 * math.sin(time * 5);
  final h = size * 0.62, k = size * 0.22;
  final line = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 3
    ..isAntiAlias = false;
  for (final (sx, sy) in const [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)]) {
    final corner = ui.Path()
      ..moveTo(c.dx + sx * h, c.dy + sy * (h - k))
      ..lineTo(c.dx + sx * h, c.dy + sy * h)
      ..lineTo(c.dx + sx * (h - k), c.dy + sy * h);
    canvas.drawPath(corner, line..color = kOutline);
    canvas.drawPath(corner, line..strokeWidth = 2..color = kSignal.withValues(alpha: pulse));
    line.strokeWidth = 3;
  }
  final top = c.dy - h - 6 - 3 * pulse;
  final arrow = ui.Path()..moveTo(c.dx - 6, top - 6)..lineTo(c.dx + 6, top - 6)..lineTo(c.dx, top)..close();
  canvas.drawPath(arrow, ui.Paint()..color = kSignal..isAntiAlias = false);
  canvas.drawPath(arrow, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 1..color = kOutline..isAntiAlias = false);
}

/// Se a criatura [speciesId] tem a sombra oval no chão. O Shade não tem: o traço dele é a sombra que não acompanha o corpo,
/// desenhada no próprio sprite (docs/art/conceitos/shade.md), e uma segunda sombra no chão a desmentiria.
bool castsGroundShadow(String speciesId) => familyOfId(speciesId) != 'shade';

/// As variantes com arte própria no mapa (`variant_art.dart`): valor e acessório, legíveis em cinza.
const List<String> mapVariantKeys = ['urban', 'green', 'water', 'residential', 'lit', 'sacred', 'crimson', 'shiny'];

/// A chave da arte da variante do Eco (o Brilhante ganha da variante de bioma), ou `null` no comum.
String? _variantKey(WorldSpawn s) => s.shiny ? 'shiny' : s.variant;

bool _hasVariantArt(Map<String, ui.Image> sprites, WorldSpawn s) => _variantKey(s) != null && sprites.containsKey('${s.entryId}@${_variantKey(s)}');

ui.Image? _spriteOf(Map<String, ui.Image> sprites, WorldSpawn s) => (_variantKey(s) == null ? null : sprites['${s.entryId}@${_variantKey(s)}']) ?? sprites[s.entryId];

void _eco(ui.Canvas canvas, ui.Offset c, WorldSpawn s, ui.Image? sprite, double size, EcoTypeOf typeOf, bool near, double time, ui.Rect avoid, {int? tint, double lean = 0, ui.Image? glow, bool flip = false}) {
  final color = spawnColor(s, typeOf);
  // Sombra no chão.
  if (castsGroundShadow(s.entryId)) {
    canvas.drawOval(
      ui.Rect.fromCenter(center: c.translate(0, size * 0.42), width: size * 0.7, height: size * 0.18),
      ui.Paint()..color = kOutline.withValues(alpha: 0.55)..isAntiAlias = false,
    );
  }
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
    // O Brilhante: um halo que pulsa com o lampejo de `variant_art.dart`. É a única variante com brilho animado.
    final pulse = shinyPulse(time + s.uid % 9 * 0.3);
    final r = size * 0.85;
    canvas.drawCircle(
      dst.center,
      r,
      ui.Paint()
        ..shader = ui.Gradient.radial(dst.center, r, [const ui.Color(0xFFFFE9A8).withValues(alpha: 0.45 * pulse), const ui.Color(0x00FFE9A8)])
        ..isAntiAlias = true,
    );
  }
  final leaning = lean.abs() >= 1e-3;
  if (leaning) {
    // O vento inclina a silhueta em volta dos pés (a sombra fica no chão).
    canvas.save();
    canvas.translate(dst.center.dx, dst.bottom);
    canvas.skew(-math.tan(lean), 0);
    canvas.translate(-dst.center.dx, -dst.bottom);
  }
  if (flip) {
    // 0.24.2: o Eco que se virou para o Conjurador (a onda na poça) aparece espelhado.
    canvas.save();
    canvas.translate(dst.center.dx, 0);
    canvas.scale(-1, 1);
    canvas.translate(-dst.center.dx, 0);
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
  if (glow != null && s.variant == 'lit' && !s.shiny) {
    // A Iluminada: o contorno de luz neon por baixo da silhueta, fixo (não pisca).
    canvas.drawImageRect(glow, ui.Rect.fromLTWH(0, 0, glow.width.toDouble(), glow.height.toDouble()), dst, ui.Paint()..filterQuality = ui.FilterQuality.none..color = ui.Color.fromRGBO(255, 255, 255, near ? 0.9 : 0.6));
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
  if (flip) canvas.restore();
  if (leaning) canvas.restore();
  if (near) _touchRingOf(canvas, c, s, size, avoid, color);
}

/// A Fagulha e o material fora do mapa (o efeito de coleta os reaproveita).
void paintSparkIcon(ui.Canvas canvas, ui.Offset c, ui.Color color, double size, double dpr) => _spark(canvas, c, color, size, dpr, true, 0);
void paintMaterialIcon(ui.Canvas canvas, ui.Offset c, ui.Color color, double size) => _material(canvas, c, color, size, true);

/// Fagulha: uma faísca de [size] pixels de ponta a ponta (cerca de 3 m do mundo).
void _sparkArt(ui.Canvas canvas, ui.Offset c, SparkArt art, (ui.Image, ui.Image?) strip, double size, double dpr, bool near, double time, int uid, {List<void Function()>? emissive}) {
  final f = art.frame.toDouble(), px = math.max(1, (size / f * dpr).round()) / dpr, side = f * px;
  final frame = loopFrame(time, art.frames, art.fps, uid: uid);
  final src = ui.Rect.fromLTWH(frame * f, 0, f, f);
  final dst = ui.Rect.fromCenter(center: c, width: side, height: side);
  canvas.drawImageRect(strip.$1, src, dst, ui.Paint()..filterQuality = ui.FilterQuality.none..color = ui.Color.fromRGBO(255, 255, 255, near ? 1 : 0.7));
  final glow = strip.$2;
  if (glow != null && emissive != null) {
    // Como o das criaturas: a camada emissiva já leva o tremor do impacto; a inclinação do vento fica de fora.
    emissive.add(() => canvas.drawImageRect(glow, src, dst, ui.Paint()..filterQuality = ui.FilterQuality.none));
  }
}

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
/// 0.23.1: o sprite de cada material (`material_sprites.dart`), montado uma vez. `null`: o item não tem sprite (vale a caixa).
final _materialImages = <String, ui.Image?>{};

ui.Image? _materialImage(String id) => _materialImages.putIfAbsent(id, () {
      final rows = materialSprites[id];
      if (rows == null) return null;
      final legend = materialSpriteLegend[id] ?? const {};
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      var w = 1;
      for (final (y, row) in rows.indexed) {
        if (row.length > w) w = row.length;
        for (var x = 0; x < row.length; x++) {
          if (row[x] == '.') continue;
          c.drawRect(ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), ui.Paint()..isAntiAlias = false..color = ui.Color(materialPalette[legend[row[x]] ?? 'outline'] ?? materialPalette['outline']!));
        }
      }
      return rec.endRecording().toImageSync(w, rows.length);
    });

/// O material de pé: 1 pixel do sprite é 1 pixel de arte ([px] dp), sem giro, com a base no ponto do spawn; fora da Aura, 60%.
void _materialSprite(ui.Canvas canvas, ui.Offset c, ui.Image img, double px, bool near) {
  final w = img.width * px, h = img.height * px;
  final dst = ui.Rect.fromLTWH((c.dx - w / 2).roundToDouble(), (c.dy - h).roundToDouble(), w, h);
  canvas.drawImageRect(img, ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, ui.Paint()
    ..filterQuality = ui.FilterQuality.none
    ..color = ui.Color.fromRGBO(255, 255, 255, near ? 1 : 0.6));
}

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

/// 0.25.0: o retângulo de um efeito de [size] centrado no ponto de ancoragem [anchor] de uma criatura (o centro do sprite
/// como ele foi desenhado), em pixels inteiros. Todo efeito ancorado em criatura usa isto, não o canto nem a posição crua.
ui.Rect anchoredRect(ui.Offset anchor, double size) =>
    ui.Rect.fromLTWH((anchor.dx - size / 2).roundToDouble(), (anchor.dy - size / 2).roundToDouble(), size.roundToDouble(), size.roundToDouble());


/// 0.25.0: a criatura com arte animada (docs/art/estilo-criaturas.md). O corpo recebe o tom da noite ([tone], multiplicado)
/// e o contorno de alcance; os ocelos (piscando como letreiro com mau contato, fixos no alerta), os veios e o brilho do
/// Brilhante vão para [emissive], que o mapa desenha depois do clima.
void _animatedEco(ui.Canvas canvas, ui.Offset c, WorldSpawn s, CreatureArt art, double size, bool near, double time,
    {required double appear, required bool moving, required bool flip, ui.Color? tone, List<void Function()>? emissive, double lean = 0, (SpawnTrigger, ui.Offset?)? trigger}) {
  // 0.25.1: o gatilho de nascer (só durante a abertura): a poça e o chão por baixo do corpo; o raio, as faíscas do poste e
  // a neblina por cima, acesos depois do tom.
  if (trigger != null) paintSpawnTrigger(canvas, trigger.$1, c, appear, size, s.uid, origin: trigger.$2, behind: true);
  final kind = animOf(appear: appear, alert: near, moving: moving);
  final strip = art.anims[kind] ?? art.anims[CreatureAnim.idle]!;
  final frame = kind == CreatureAnim.spawn ? onceFrame(appear, strip.frames) : loopFrame(time, strip.frames, strip.fps, uid: s.uid);
  final f = art.frame.toDouble();
  final src = ui.Rect.fromLTWH(frame * f, 0, f, f);
  final dst = ui.Rect.fromCenter(center: c, width: size, height: size);
  // A variante ainda sendo montada (0.26.2, sob demanda): a criatura aparece no próximo quadro, nunca com as cores erradas.
  final body = art.bodyOf(kind, s.shiny ? null : s.variant);
  if (body == null) return;
  if (castsGroundShadow(s.entryId)) {
    canvas.drawOval(
      ui.Rect.fromCenter(center: c.translate(0, size * 0.42), width: size * 0.55, height: size * 0.14),
      ui.Paint()..color = kOutline.withValues(alpha: 0.45)..isAntiAlias = false,
    );
  }
  final alpha = near ? 1.0 : 0.8;
  void flipped(ui.Canvas cv, void Function() draw) {
    final leaning = lean.abs() >= 1e-3;
    if (leaning) {
      cv.save();
      cv.translate(dst.center.dx, dst.bottom);
      cv.skew(-math.tan(lean), 0);
      cv.translate(-dst.center.dx, -dst.bottom);
    }
    if (flip) {
      cv.save();
      cv.translate(dst.center.dx, 0);
      cv.scale(-1, 1);
      cv.translate(-dst.center.dx, 0);
    }
    draw();
    if (flip) cv.restore();
    if (leaning) cv.restore();
  }

  flipped(canvas, () {
    if (near) {
      final px = size / f;
      final pulse = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(time * 4.5 + s.uid % 7));
      final outline = ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..colorFilter = ui.ColorFilter.mode(kVeil.withValues(alpha: pulse), ui.BlendMode.srcIn);
      for (final (dx, dy) in [(px, 0.0), (-px, 0.0), (0.0, px), (0.0, -px)]) {
        canvas.drawImageRect(body, src, dst.shift(ui.Offset(dx, dy)), outline);
      }
    }
    canvas.drawImageRect(body, src, dst, ui.Paint()
      ..filterQuality = ui.FilterQuality.none
      ..color = ui.Color.fromRGBO(255, 255, 255, alpha)
      ..colorFilter = tone == null ? null : ui.ColorFilter.mode(tone, ui.BlendMode.modulate));
  });
  final leds = strip.leds, glow = strip.glow;
  final lit = ledLit(s.uid, time, fixed: kind == CreatureAnim.alert);
  void light() => flipped(canvas, () {
        final p = ui.Paint()..filterQuality = ui.FilterQuality.none;
        if (glow != null) canvas.drawImageRect(glow, src, dst, p);
        if (leds != null && lit) canvas.drawImageRect(leds, src, dst, p);
        if (s.shiny) {
          // O Brilhante: uma faixa de luz que passa pelo corpo (o único brilho animado).
          final k = creatureShine(s.uid, time);
          if (k > 0) {
            canvas.drawImageRect(body, src, dst, ui.Paint()
              ..filterQuality = ui.FilterQuality.none
              ..colorFilter = ui.ColorFilter.mode(const ui.Color(0xFFFFF4C8).withValues(alpha: 0.55 * k), ui.BlendMode.srcIn));
          }
        }
      });
  emissive == null ? light() : emissive.add(light);
  if (trigger != null) {
    void lit() => paintSpawnTrigger(canvas, trigger.$1, c, appear, size, s.uid, origin: trigger.$2, behind: false);
    emissive == null ? lit() : emissive.add(lit);
  }
}

/// O anel de alcance e o rótulo de nível (tamanho fixo de tela). Perto do Conjurador ficam de fora: nada cobre o marcador.
void _touchRingOf(ui.Canvas canvas, ui.Offset c, WorldSpawn s, double size, ui.Rect avoid, ui.Color color) {
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
