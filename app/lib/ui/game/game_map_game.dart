import 'dart:ui';

import 'package:flame/game.dart';

import '../../core/tiles.dart';
import '../../world/aura.dart';
import '../../world/follow_camera.dart';
import '../../world/places.dart';
import '../../world/player_avatar.dart';
import '../../world/player_tracker.dart';
import '../map/map_renderer.dart';
import 'player_painter.dart';

/// O mapa do jogo em Flame: segue o Conjurador, desenha o marcador e a Aura e repassa os toques para a
/// câmera. As regras (suavização, espiar e voltar, limites de zoom) estão em `world/`.
class GameMapGame extends FlameGame {
  GameMapGame({required this.renderer, required this.auraM, (double, double) fallbackCenter = kUnicamp}) {
    final (x, y) = latLonToTileFraction(fallbackCenter.$1, fallbackCenter.$2, biomeZoom);
    follow = FollowCamera(x: x, y: y);
  }

  final MapRenderer renderer;

  /// Raio da Aura, em metros, do `balance.json`.
  final double auraM;

  /// A câmera de jogo.
  late final FollowCamera follow;

  /// O marcador suavizado.
  final avatar = PlayerAvatar();

  double _lat = kUnicamp.$1;
  double _scaleAtStart = FollowCamera.defaultScale;

  @override
  Color backgroundColor() => const Color(0xFF1A1424);

  /// O jogador mudou de posição ou de estado. Só a posição filtrada move o marcador.
  void onPlayerState(PlayerState s) {
    final p = s.position;
    if (p == null) return;
    final (x, y) = latLonToTileFraction(p.lat, p.lon, biomeZoom);
    final first = !avatar.hasPosition;
    avatar.setTarget(x, y);
    _lat = p.lat;
    follow.setTarget(x, y);
    if (first) follow.snapToTarget(); // a primeira posição não desliza de lugar nenhum
  }

  /// Esquece a posição (trocou de fonte): o marcador some até a próxima leitura boa.
  void clearPlayer() {
    avatar.clear();
  }

  void touchStart() {
    _scaleAtStart = follow.pixelsPerCell;
    follow.touchStart();
  }

  void touchEnd() => follow.touchEnd();

  /// Arrasto de [dx], [dy] pixels (espiar) e pinça com [scale] acumulado desde o início do gesto.
  void gesture({required double dx, required double dy, required double scale}) {
    if (scale != 1.0) follow.setScale(_scaleAtStart * scale);
    if (dx != 0 || dy != 0) follow.dragBy(dx, dy);
  }

  @override
  void update(double dt) {
    super.update(dt);
    avatar.update(dt);
    if (avatar.hasPosition) follow.setTarget(avatar.x, avatar.y);
    follow.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0 || size.y <= 0) return;
    final view = Size(size.x, size.y);
    final cam = follow.camera;
    renderer.paint(canvas, view, camera: cam, crosshair: false);
    if (!avatar.hasPosition) return;
    final (sx, sy) = cam.cellToScreen(avatar.x, avatar.y, view.width, view.height);
    final center = Offset(sx, sy);
    paintAura(canvas, center, auraRadiusPx(auraM: auraM, lat: _lat, pixelsPerCell: cam.pixelsPerCell));
    paintPlayerMarker(canvas, center, cam.pixelsPerCell);
  }
}
