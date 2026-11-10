/// O Modo Viagem no mapa: a rota, o destino e o carro da corrida. Quem decide onde tudo está é `travel/travel_session.dart`;
/// aqui só se projeta e se pinta.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/tiles.dart';
import '../../travel/travel_path.dart';
import '../../travel/travel_session.dart';
import '../../world/map_camera.dart';
import '../../world/player_avatar.dart';
import '../../world/player_tracker.dart';
import '../colors.dart';
import '../game/ghost_sprites.dart';

/// Repassa a posição filtrada à viagem, com a velocidade e a direção do marcador suavizado.
void noteTravelPosition(TravelSession travel, PlayerState s, PlayerAvatar avatar) {
  final p = s.position;
  if (p == null) return;
  final (x, y) = latLonToTileFraction(p.lat, p.lon, biomeZoom);
  travel.onPosition(
    x: x,
    y: y,
    mpc: metersPerCell(p.lat),
    speedMps: avatar.speedMps,
    heading: avatar.moving ? math.atan2(avatar.velocityY, avatar.velocityX) : null,
  );
}

class TravelLayer {
  TravelLayer(this.session, {required this.carM});

  final TravelSession session;

  /// O comprimento do carro, em metros (`ghost_car_m`): o mesmo dos fantasmas.
  final double carM;

  /// O carro faz o papel do avatar: o mapa não desenha o Conjurador.
  bool hidesPlayer = false;

  double _heading = 0;
  final Map<(String, int), ui.Picture> _cars = {};
  final ui.Paint _line = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 3
    ..isAntiAlias = false;
  final ui.Paint _fill = ui.Paint()..isAntiAlias = false;

  void paintGround(ui.Canvas canvas, ui.Size view, MapCamera cam, double mpc, {required double utc, required PlayerAvatar avatar}) {
    hidesPlayer = session.hidesPlayerAt(utc);
    final dx = session.destX, dy = session.destY;
    if (dx == null || dy == null) return;
    final route = session.route;
    if (route != null) {
      _paintRoute(canvas, view, cam, route);
    } else if (avatar.hasPosition) {
      _paintDashes(canvas, view, cam, avatar.x, avatar.y, dx, dy);
    }
    final (sx, sy) = cam.cellToScreen(dx, dy, view.width, view.height);
    _fill.color = kOutline;
    canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset(sx, sy), width: 14, height: 14), _fill);
    _fill.color = kSignal;
    canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset(sx, sy), width: 8, height: 8), _fill);
  }

  /// A rota pelas ruas; fora dos dados, do [TravelPath.dashFrom] em diante, a reta tracejada até o destino.
  void _paintRoute(ui.Canvas canvas, ui.Size view, MapCamera cam, TravelPath route) {
    _line.color = kSignal.withValues(alpha: 0.85);
    final area = (ui.Offset.zero & view).inflate(8);
    final xy = route.xy;
    final solidEnd = 2 * (route.dashFrom ?? route.pointCount - 1);
    var (ax, ay) = cam.cellToScreen(xy[0], xy[1], view.width, view.height);
    for (var i = 2; i <= solidEnd; i += 2) {
      final (bx, by) = cam.cellToScreen(xy[i], xy[i + 1], view.width, view.height);
      final box = ui.Rect.fromPoints(ui.Offset(ax, ay), ui.Offset(bx, by));
      if (box.overlaps(area)) canvas.drawLine(ui.Offset(ax, ay), ui.Offset(bx, by), _line);
      ax = bx;
      ay = by;
    }
    if (route.dashFrom != null) _paintDashes(canvas, view, cam, xy[solidEnd], xy[solidEnd + 1], xy[xy.length - 2], xy[xy.length - 1]);
  }

  /// Sem rota: a reta tracejada até o destino, só no pedaço que cabe na tela.
  void _paintDashes(ui.Canvas canvas, ui.Size view, MapCamera cam, double x0, double y0, double x1, double y1) {
    _line.color = kVeil.withValues(alpha: 0.85);
    final (ax, ay) = cam.cellToScreen(x0, y0, view.width, view.height);
    final (bx, by) = cam.cellToScreen(x1, y1, view.width, view.height);
    final len = math.sqrt(math.pow(bx - ax, 2) + math.pow(by - ay, 2));
    if (len < 1) return;
    final ux = (bx - ax) / len, uy = (by - ay) / len;
    final reach = math.min(len, view.longestSide);
    for (var s = 0.0; s < reach; s += 20) {
      canvas.drawLine(ui.Offset(ax + ux * s, ay + uy * s), ui.Offset(ax + ux * (s + 10), ay + uy * (s + 10)), _line);
    }
  }

  void paintCar(ui.Canvas canvas, ui.Size view, MapCamera cam, double mpc, {required double utc, required PlayerAvatar avatar}) {
    final ride = session.ride;
    if (ride == null) return;
    if (avatar.moving) {
      final target = math.atan2(avatar.velocityY, avatar.velocityX);
      final turn = math.atan2(math.sin(target - _heading), math.cos(target - _heading));
      _heading += turn * 0.15;
    }
    final car = session.carPose(utc, avatar.x, avatar.y, _heading);
    if (car == null) return;
    final type = ride.carType ?? session.patterns.defaultType;
    final color = ride.carColor ?? session.patterns.defaultColor;
    final rows = rideCarRows(type);
    final pic = _cars[(type, color)] ??= recordSprite(rows, rideCarPalette(ui.Color(color)));
    final unit = math.max(1.0, carM * cam.pixelsPerCell / mpc / carRefPx);
    final w = rows.first.length * unit, h = rows.length * unit;
    final (sx, sy) = cam.cellToScreen(car.x, car.y, view.width, view.height);
    canvas.save();
    canvas.translate(sx, sy);
    canvas.rotate(car.heading + cam.rotation);
    canvas.translate(-w / 2, -h / 2);
    canvas.scale(unit);
    canvas.drawPicture(pic);
    canvas.restore();
    final seam = session.boardingAt(utc) ?? session.alightingAt(utc);
    if (seam != null) _seam(canvas, sx, sy, w, unit, seam);
  }

  /// A costura do Véu em volta do carro: o jogador entra e sai por ela.
  void _seam(ui.Canvas canvas, double sx, double sy, double w, double unit, double t) {
    _fill.color = kVeil.withValues(alpha: 0.85 * (1 - t));
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final r = w * (0.4 + 0.5 * t);
      canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset(sx + math.cos(a) * r, sy + math.sin(a) * r), width: 2 * unit, height: 2 * unit), _fill);
    }
  }
}
