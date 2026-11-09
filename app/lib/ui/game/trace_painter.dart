/// O Radar no chão do mapa (camada do mundo: gira, anda e dá zoom com o mapa): a onda ciano do pulso, as pegadas dos
/// rastros, que surgem quando a onda passa por elas, e as distorções dos Ocultos. No nível 2 do scanner a pegada leva a cor
/// do tipo do Eco; as do Brilhante são douradas. Quem decide direção e largura é `world/radar.dart`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../capture/eco_type.dart';
import '../../world/map_camera.dart';
import '../../world/radar.dart';
import '../../world/world_view.dart';
import '../colors.dart';

class TracePainter {
  /// Quantas pegadas por rastro e a distância (m) entre elas, a partir de [startM].
  static const int prints = 4;
  static const double startM = 30, stepM = 9;

  /// Raio da distorção no chão, em metros.
  static const double distortionM = 5;

  final ui.Paint _paint = ui.Paint()..isAntiAlias = false;

  void paint(ui.Canvas canvas, ui.Size view, MapCamera cam, {required WorldView world, required double playerX, required double playerY, required double metersPerCell, required double exactUtc}) {
    final b = world.street;
    final pulse = world.pulse;
    final waveM = pulse == null ? double.infinity : (exactUtc - pulse.t) * b.pulseSpeedMps;
    final ppm = cam.pixelsPerCell / metersPerCell;
    if (pulse != null && waveM <= b.traceRangeM) {
      final (sx, sy) = cam.cellToScreen(pulse.x, pulse.y, view.width, view.height);
      final fade = 1 - waveM / b.traceRangeM;
      final ring = ui.Paint()..style = ui.PaintingStyle.stroke..isAntiAlias = false;
      canvas.drawCircle(ui.Offset(sx, sy), waveM * ppm, ring..strokeWidth = 3..color = kSignal.withValues(alpha: 0.8 * fade));
      canvas.drawCircle(ui.Offset(sx, sy), math.max(0, waveM - 6) * ppm, ring..strokeWidth = 1.5..color = kSignal.withValues(alpha: 0.35 * fade));
    }
    final byUid = {for (final e in world.allEcos) e.uid: e};
    for (final t in world.traces) {
      final eco = byUid[t.uid];
      if (eco == null) continue;
      final arc = traceArc(t, playerX: playerX, playerY: playerY, ecoX: eco.x, ecoY: eco.y, metersPerCell: metersPerCell, balance: b);
      final base = t.shiny ? const ui.Color(0xFFFFE9A8) : (t.typeId == null ? kText : typeColor(EcoType.parse(t.typeId!)));
      final fadeOut = ((t.untilUtc - exactUtc) / 20).clamp(0.0, 1.0); // some nos últimos 20 s
      final dx = math.cos(arc.angleRad), dy = math.sin(arc.angleRad);
      for (var i = 0; i < prints; i++) {
        final d = startM + i * stepM;
        if (d > arc.distanceM - 4) break; // não passa do Eco
        if (d > waveM) break; // a onda ainda não chegou aqui
        final side = (i.isEven ? 1 : -1) * 1.5; // metros para o lado: um pé, depois o outro
        final px = playerX + (dx * d - dy * side) / metersPerCell, py = playerY + (dy * d + dx * side) / metersPerCell;
        final (sx, sy) = cam.cellToScreen(px, py, view.width, view.height);
        _paint.color = base.withValues(alpha: (0.9 - i * 0.16) * fadeOut);
        canvas.save();
        canvas.translate(sx, sy);
        canvas.rotate(arc.angleRad + cam.rotation + math.pi / 2); // a ponta da pegada para o Eco
        canvas.drawRect(const ui.Rect.fromLTWH(-2.5, -2, 5, 6), _paint); // o pé
        canvas.drawRect(const ui.Rect.fromLTWH(-2.5, -5, 1.5, 2.5), _paint); // os dedos
        canvas.drawRect(const ui.Rect.fromLTWH(-0.75, -6, 1.5, 3), _paint);
        canvas.drawRect(const ui.Rect.fromLTWH(1, -5, 1.5, 2.5), _paint);
        canvas.restore();
      }
    }
    for (final d in world.distortions) {
      if (d.eco.distanceM(pulse?.x ?? playerX, pulse?.y ?? playerY, metersPerCell) > waveM) continue;
      paintDistortion(canvas, cam.cellToScreen(d.eco.x, d.eco.y, view.width, view.height), distortionM * ppm, exactUtc, _paint);
    }
  }
}

/// A distorção de um Oculto: anéis quebrados de pixels que tremem, em violeta e ciano. [r] é o raio em pixels.
void paintDistortion(ui.Canvas canvas, (double, double) at, double r, double t, ui.Paint p) {
  final (cx, cy) = at;
  for (var k = 0; k < 3; k++) {
    final rr = r * (0.45 + 0.3 * k) + math.sin(t * 3 + k) * 1.5;
    p.color = (k.isEven ? kVeil : kSignal).withValues(alpha: 0.75 - 0.18 * k);
    for (var i = 0; i < 10; i++) {
      if ((i + k + (t * 4).floor()) % 3 == 0) continue; // o anel falha
      final a = i * math.pi / 5 + k * 0.4;
      canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset(cx + math.cos(a) * rr, cy + math.sin(a) * rr), width: 3, height: 3), p);
    }
  }
}
