/// O que as simulações do mundo mostram no mapa (época 9 em diante): o véu da neblina preso ao chão, mais denso nas
/// baixadas, e os redemoinhos das Correntes do Véu, pontos de brilho para onde as Fagulhas correm. Só desenho: quem decide
/// a densidade e onde fica cada redemoinho é o mundo (`ClimateWorld.fogAt`, `MotionModel.vortexOf`).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/epochs.dart';
import '../../world/climate_world.dart';
import '../../world/map_camera.dart';
import '../colors.dart';

final ui.Paint _fill = ui.Paint()..isAntiAlias = false;

/// O véu da neblina: cada célula z21 em dois por dois quadrados brancos, com a opacidade da densidade no lugar. Gira e dá
/// zoom com o mapa. Nada se o clima [climateId] não é de neblina na época ou não há relevo.
void paintFogVeil(ui.Canvas canvas, ui.Size view, MapCamera cam, ClimateWorld world, Epoch epoch, String climateId, int t) {
  if (epoch.fog == null || !epoch.fog!.climates.contains(climateId)) return;
  final (l, top, r, b) = cam.visibleBounds(view.width, view.height);
  const sub = 2;
  final x0 = l.floor(), y0 = top.floor(), x1 = r.ceil(), y1 = b.ceil();
  if ((x1 - x0) * (y1 - y0) > 1500) return;
  canvas.save();
  canvas.translate(view.width / 2, view.height / 2);
  canvas.rotate(cam.rotation);
  canvas.scale(cam.pixelsPerCell);
  canvas.translate(-cam.centerX, -cam.centerY);
  for (var y = y0 * sub; y < y1 * sub; y++) {
    for (var x = x0 * sub; x < x1 * sub; x++) {
      final f = world.fogAt((x + 0.5) / sub, (y + 0.5) / sub, t, epoch, climateId);
      if (f == null || f.density <= 0.02) continue;
      // Em degraus (pixel art): quatro tons de véu.
      final a = (f.density * 4).ceil() / 4 * 0.42;
      canvas.drawRect(ui.Rect.fromLTWH(x / sub, y / sub, 1 / sub + 0.003, 1 / sub + 0.003), _fill..color = ui.Color.fromRGBO(232, 228, 244, a));
    }
  }
  canvas.restore();
}

/// Os redemoinhos das Correntes do Véu à vista: um ponto de brilho que pulsa e quatro pixels que giram em volta.
void paintVortices(ui.Canvas canvas, ui.Size view, MapCamera cam, int seed, Epoch epoch, double t, double mpc, double artPx) {
  final m = epoch.motion;
  if (m == null) return;
  final (l, top, r, b) = cam.visibleBounds(view.width, view.height);
  if ((r - l) * (b - top) > 6000) return;
  final ring = m.vortexOrbitM / mpc * cam.pixelsPerCell;
  for (var cy = top.floor() >>> 3; cy <= b.floor() >>> 3; cy++) {
    for (var cx = l.floor() >>> 3; cx <= r.floor() >>> 3; cx++) {
      final v = m.vortexOf(seed, epoch.id, cx, cy);
      if (v == null) continue;
      final (sx, sy) = cam.cellToScreen(v.$1, v.$2, view.width, view.height);
      if (sx < -20 || sy < -20 || sx > view.width + 20 || sy > view.height + 20) continue;
      final pulse = 0.5 + 0.5 * math.sin(t * 2.2 + cx * 1.7 + cy);
      canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset(sx, sy), width: artPx * 2, height: artPx * 2), _fill..color = kVeil.withValues(alpha: 0.35 + 0.4 * pulse));
      canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset(sx, sy), width: artPx, height: artPx), _fill..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.5 + 0.4 * pulse));
      for (var k = 0; k < 4; k++) {
        final a = t * 2 * math.pi / m.vortexPeriodS + k * math.pi / 2;
        canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset(sx + math.cos(a) * ring, sy + math.sin(a) * ring), width: artPx, height: artPx), _fill..color = kVeil.withValues(alpha: 0.55));
      }
    }
  }
}
