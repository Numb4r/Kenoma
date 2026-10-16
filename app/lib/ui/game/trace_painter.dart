/// Os rastros do Radar: pegadas no mapa que apontam, com um erro de até 30°, para os Ecos raros por perto. No nível 2
/// do scanner a pegada leva a cor do tipo do Eco; as do Brilhante são douradas. Quem decide a direção é `world/radar.dart`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../world/map_camera.dart';
import '../../world/radar.dart';
import '../../world/spawn_field.dart';
import '../colors.dart';
import '../../capture/eco_type.dart';

class TracePainter {
  /// Quantas pegadas por rastro e a distância (m) entre elas, a partir de [startM].
  static const int prints = 4;
  static const double startM = 30, stepM = 9;

  final ui.Paint _paint = ui.Paint()..isAntiAlias = false;

  void paint(
    ui.Canvas canvas,
    ui.Size view,
    MapCamera cam, {
    required List<Trace> traces,
    required List<WorldSpawn> ecos,
    required double playerX,
    required double playerY,
    required double metersPerCell,
    required int nowUtc,
  }) {
    for (final t in traces) {
      final eco = ecos.where((e) => e.uid == t.uid).firstOrNull;
      if (eco == null) continue;
      final bearing = traceBearing(t, playerX: playerX, playerY: playerY, ecoX: eco.x, ecoY: eco.y);
      final dist = math.sqrt((eco.x - playerX) * (eco.x - playerX) + (eco.y - playerY) * (eco.y - playerY)) * metersPerCell;
      final base = t.shiny ? const ui.Color(0xFFFFE9A8) : (t.typeId == null ? kText : typeColor(EcoType.parse(t.typeId!)));
      final fadeOut = ((t.untilUtc - nowUtc) / 20).clamp(0.0, 1.0); // some nos últimos 20 s
      for (var i = 0; i < prints; i++) {
        final d = startM + i * stepM;
        if (d > dist - 4) break; // não passa do Eco
        final side = (i.isEven ? 1 : -1) * 1.5; // metros para o lado: um pé, depois o outro
        final dx = math.cos(bearing), dy = math.sin(bearing);
        final px = playerX + (dx * d - dy * side) / metersPerCell, py = playerY + (dy * d + dx * side) / metersPerCell;
        final (sx, sy) = cam.cellToScreen(px, py, view.width, view.height);
        final a = (0.9 - i * 0.16) * fadeOut;
        _paint.color = base.withValues(alpha: a);
        canvas.save();
        canvas.translate(sx, sy);
        canvas.rotate(bearing + cam.rotation + math.pi / 2); // a ponta da pegada para o Eco
        canvas.drawRect(const ui.Rect.fromLTWH(-2.5, -2, 5, 6), _paint); // o pé
        canvas.drawRect(const ui.Rect.fromLTWH(-2.5, -5, 1.5, 2.5), _paint); // os dedos
        canvas.drawRect(const ui.Rect.fromLTWH(-0.75, -6, 1.5, 3), _paint);
        canvas.drawRect(const ui.Rect.fromLTWH(1, -5, 1.5, 2.5), _paint);
        canvas.restore();
      }
    }
  }
}
