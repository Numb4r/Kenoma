/// O rastreador no canto inferior direito: a silhueta de cada Eco fora da tela, uma seta para onde ele
/// está e a distância. Só desenha; quem escolhe os Ecos é `world/tracker.dart`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection;

import '../../world/tracker.dart';
import '../colors.dart';
import 'spawn_painter.dart';

const double _cell = 48; // lado de cada entrada, em dp
const double _sil = 32; // silhueta

void paintTracker(
  ui.Canvas canvas,
  ui.Size view,
  List<TrackedEco> entries, {
  required Map<String, ui.Image> sprites,
  required EcoTypeOf typeOf,
  double margin = 8,
  double bottomInset = 0,
  double rotation = 0,
}) {
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    final color = spawnColor(e.spawn, typeOf);
    final box = ui.Rect.fromLTWH(view.width - margin - _cell, view.height - bottomInset - margin - (i + 1) * (_cell + 14), _cell, _cell);
    canvas.drawRect(box, ui.Paint()..color = kOutline.withValues(alpha: 0.85)..isAntiAlias = false);
    canvas.drawRect(box, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 2..color = kPanelLine..isAntiAlias = false);
    final sprite = sprites[e.spawn.entryId];
    if (sprite != null) {
      canvas.drawImageRect(
        sprite,
        ui.Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        ui.Rect.fromCenter(center: box.center, width: _sil, height: _sil),
        ui.Paint()
          ..filterQuality = ui.FilterQuality.none
          ..isAntiAlias = false
          ..colorFilter = ui.ColorFilter.mode(color.withValues(alpha: 0.85), ui.BlendMode.srcIn),
      );
    }
    // Seta na borda da caixa, para onde o Eco está.
    final angle = e.angle + rotation; // a direção no mundo, vista com o mapa girado
    final tip = box.center + ui.Offset(math.cos(angle), math.sin(angle)) * (_cell / 2 - 2);
    final back = angle + math.pi;
    final a = tip + ui.Offset(math.cos(back + 0.5), math.sin(back + 0.5)) * 9;
    final b = tip + ui.Offset(math.cos(back - 0.5), math.sin(back - 0.5)) * 9;
    canvas.drawPath(
      ui.Path()..moveTo(tip.dx, tip.dy)..lineTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..close(),
      ui.Paint()..color = kEssence..isAntiAlias = false,
    );
    final label = TextPainter(
      text: TextSpan(text: '${e.distanceM.round()} M', style: const TextStyle(fontFamily: 'Silkscreen', fontSize: 8, color: kText)),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, ui.Offset(box.center.dx - label.width / 2, box.bottom + 2));
  }
}
