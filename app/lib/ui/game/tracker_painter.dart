/// O rastreador na borda direita, dentro da zona dele no HUD (`hud_layout.dart`), de baixo para cima: o que o Radar achou
/// (o arco do rastro, na cor do tipo no nível 2, ou a distorção do Oculto) e a silhueta de cada Eco à vista fora da tela,
/// com uma seta para onde ele está e a distância. Só desenha; quem escolhe é `world/tracker.dart`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection;

import '../../capture/eco_type.dart';
import '../../world/tracker.dart';
import '../colors.dart';
import 'spawn_painter.dart';
import 'trace_painter.dart' show paintDistortion;

const double _cell = 48; // lado de cada entrada, em dp
const double _sil = 32; // silhueta

void paintTracker(
  ui.Canvas canvas,
  ui.Rect zone,
  List<TrackedEco> entries, {
  required Map<String, ui.Image> sprites,
  required EcoTypeOf typeOf,
  double rotation = 0,
}) {
  final p = ui.Paint()..isAntiAlias = false;
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    final find = e.find;
    final box = ui.Rect.fromLTWH(zone.left, zone.bottom - (i + 1) * (_cell + 14), _cell, _cell);
    if (box.top < zone.top - 0.5) break;
    canvas.drawRect(box, p..color = kOutline.withValues(alpha: 0.85)..style = ui.PaintingStyle.fill);
    canvas.drawRect(box, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 2..color = find == null ? kPanelLine : kSignal..isAntiAlias = false);
    final angle = e.angle + rotation; // a direção no mundo, vista com o mapa girado
    if (find == null) {
      final sprite = sprites[e.spawn.entryId];
      if (sprite != null) {
        canvas.drawImageRect(
          sprite,
          ui.Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
          ui.Rect.fromCenter(center: box.center, width: _sil, height: _sil),
          ui.Paint()
            ..filterQuality = ui.FilterQuality.none
            ..isAntiAlias = false
            ..colorFilter = ui.ColorFilter.mode(spawnColor(e.spawn, typeOf).withValues(alpha: 0.85), ui.BlendMode.srcIn),
        );
      }
    } else if (find.distortion) {
      paintDistortion(canvas, (box.center.dx, box.center.dy), 12, 0, p..style = ui.PaintingStyle.fill);
    } else {
      // O arco do rastro, da largura que o sonar mostra, aberto para a direção provável.
      final color = find.shiny ? const ui.Color(0xFFFFE9A8) : (find.typeId == null ? kText : typeColor(EcoType.parse(find.typeId!)));
      canvas.drawArc(ui.Rect.fromCenter(center: box.center, width: 30, height: 30), angle - find.widthRad / 2, find.widthRad, false,
          ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 4..color = color..isAntiAlias = false);
    }
    // Seta na borda da caixa, para onde o Eco está.
    final tip = box.center + ui.Offset(math.cos(angle), math.sin(angle)) * (_cell / 2 - 2);
    final back = angle + math.pi;
    final a = tip + ui.Offset(math.cos(back + 0.5), math.sin(back + 0.5)) * 9;
    final b = tip + ui.Offset(math.cos(back - 0.5), math.sin(back - 0.5)) * 9;
    canvas.drawPath(ui.Path()..moveTo(tip.dx, tip.dy)..lineTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..close(), p..color = kEssence..style = ui.PaintingStyle.fill);
    // O rastro dá só a distância aproximada, de 50 em 50 m.
    final text = find != null && !find.distortion ? '~${(e.distanceM / 50).round() * 50} M' : '${e.distanceM.round()} M';
    final label = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(fontFamily: 'Silkscreen', fontSize: 8, color: kText)),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, ui.Offset(box.center.dx - label.width / 2, box.bottom + 2));
  }
}
