import 'dart:ui';

import 'package:flame/game.dart';

import '../../capture/eco_type.dart';
import '../../core/tiles.dart';
import '../../world/aura.dart';
import '../../world/follow_camera.dart';
import '../../world/places.dart';
import '../../world/player_avatar.dart';
import '../../world/player_tracker.dart';
import '../../world/spawn_field.dart';
import '../../world/world_view.dart';
import '../map/map_renderer.dart';
import 'spawn_painter.dart';
import 'player_painter.dart';

/// O mapa do jogo em Flame: segue o Conjurador, desenha o marcador e a Aura e repassa os toques para a
/// câmera. As regras (suavização, espiar e voltar, limites de zoom) estão em `world/`.
class GameMapGame extends FlameGame {
  GameMapGame({
    required this.renderer,
    required this.auraM,
    this.worldView,
    this.sprites = const {},
    this.typeOf = _noType,
    this.nowUtc = _zero,
    (double, double) fallbackCenter = kUnicamp,
  }) {
    final (x, y) = latLonToTileFraction(fallbackCenter.$1, fallbackCenter.$2, biomeZoom);
    follow = FollowCamera(x: x, y: y);
  }

  final MapRenderer renderer;

  /// Os spawns e o que o jogador alcança. `null` nos testes que só querem o mapa.
  final WorldView? worldView;

  /// Sprites dos Ecos por espécie.
  final Map<String, Image> sprites;
  final EcoTypeOf typeOf;

  /// Relógio UTC do jogo, em segundos.
  final int Function() nowUtc;

  /// Raio da Aura, em metros, do `balance.json`.
  final double auraM;

  /// A câmera de jogo.
  late final FollowCamera follow;

  /// O marcador suavizado.
  final avatar = PlayerAvatar();

  double _lat = kUnicamp.$1;
  double _lon = kUnicamp.$2;
  bool _hasFix = false;
  double _refreshIn = 0;
  double _time = 0;
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
    _lon = p.lon;
    if (!_hasFix) _refreshIn = 0; // a primeira posição já mostra o mundo
    _hasFix = true;
    follow.setTarget(x, y);
    if (first) follow.snapToTarget(); // a primeira posição não desliza de lugar nenhum
  }

  /// Esquece a posição (trocou de fonte): o marcador some até a próxima leitura boa.
  void clearPlayer() {
    avatar.clear();
    _hasFix = false;
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
    _time += dt;
    _refreshIn -= dt;
    if (_hasFix && worldView != null && _refreshIn <= 0) {
      _refreshIn = 0.5;
      worldView!.refresh(lat: _lat, lon: _lon, tUtc: nowUtc());
    }
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
    final w = worldView;
    if (w != null) {
      paintSpawns(canvas, view, cam, w.spawns, sprites: sprites, typeOf: typeOf, inAura: w.inAura, time: _time);
    }
    final (sx, sy) = cam.cellToScreen(avatar.x, avatar.y, view.width, view.height);
    final center = Offset(sx, sy);
    paintAura(canvas, center, auraRadiusPx(auraM: auraM, lat: _lat, pixelsPerCell: cam.pixelsPerCell));
    paintPlayerMarker(canvas, center, cam.pixelsPerCell);
  }

  /// O spawn sob o toque em [screen], se houver: o mais perto dentro do raio de toque.
  WorldSpawn? spawnAt(Offset screen) {
    final w = worldView;
    if (w == null || size.x <= 0) return null;
    final cam = follow.camera;
    WorldSpawn? best;
    var bestD = double.infinity;
    for (final s in w.spawns) {
      final (sx, sy) = cam.cellToScreen(s.x, s.y, size.x, size.y);
      final d = (Offset(sx, sy) - screen).distance;
      if (d <= hitRadius(s, cam.pixelsPerCell) && d < bestD) {
        best = s;
        bestD = d;
      }
    }
    return best;
  }
}

EcoType? _noType(String _) => null;
int _zero() => 0;
