import 'dart:ui';
import 'dart:ui' as ui;

import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../capture/eco_type.dart';
import '../../core/tiles.dart';
import '../../world/aura.dart';
import '../../world/follow_camera.dart';
import '../../world/map_camera.dart';
import '../../world/map_rotation.dart';
import '../../world/map_scale.dart';
import '../../world/places.dart';
import '../../world/player_avatar.dart';
import '../../world/player_tracker.dart';
import '../../world/spawn_field.dart';
import '../../world/world_view.dart';
import '../../world/map_balance.dart';
import '../../world/visual_map.dart';
import '../map/map_renderer.dart';
import 'art_renderer.dart';
import 'art_style.dart';
import 'spawn_painter.dart';
import 'tracker_painter.dart';
import 'player_painter.dart';

/// O mapa do jogo em Flame: segue o Conjurador, desenha o marcador e a Aura e repassa os toques para a
/// câmera. As regras (suavização, giro, limites de zoom) estão em `world/`.
class GameMapGame extends FlameGame {
  GameMapGame({
    required this.renderer,
    required this.visual,
    required this.style,
    required this.balance,
    this.playerFrames = const [],
    this.overlayBiomes = _off,
    this.overlayGrid20 = _off,
    required this.auraM,
    required this.defaultWidthM,
    required this.minWidthM,
    required this.maxWidthM,
    required this.spriteHeightM,
    required this.sparkSizeM,
    required this.trackerM,
    required this.trackerMax,
    this.declinationDeg = 0,
    this.dpr = 1,
    this.worldView,
    this.sprites = const {},
    this.typeOf = _noType,
    this.nowUtc = _zero,
    (double, double) fallbackCenter = kUnicamp,
  }) {
    final (x, y) = latLonToTileFraction(fallbackCenter.$1, fallbackCenter.$2, biomeZoom);
    // O marcador já vem suavizado: a câmera só o acompanha de perto.
    follow = FollowCamera(x: x, y: y, followTauS: 0.06);
  }

  /// A grade de biomas: só aparece como sobreposição do menu de debug.
  final MapRenderer renderer;

  /// As geometrias do pacote visual e as cores: o mapa de jogo é desenhado em pixels de arte.
  final VisualMap visual;
  final ArtStyle style;
  final MapBalance balance;
  /// Os quadros do Conjurador: parado e os dois do passo.
  final List<ui.Image> playerFrames;

  /// Sobreposições de debug, lidas a cada quadro: a grade de biomas e a grade das células de spawn (z20).
  final bool Function() overlayBiomes;
  final bool Function() overlayGrid20;
  late final ArtRenderer _art = ArtRenderer(visual: visual, style: style, balance: balance);

  /// Os spawns e o que o jogador alcança. `null` nos testes que só querem o mapa.
  final WorldView? worldView;

  /// Sprites dos Ecos por espécie.
  final Map<String, Image> sprites;
  final EcoTypeOf typeOf;

  /// Relógio UTC do jogo, em segundos.
  final int Function() nowUtc;

  /// Raio da Aura, em metros, do `balance.json`.
  final double auraM;

  /// Largura da tela em metros no zoom padrão, e a faixa da pinça (do `balance.json`).
  final double defaultWidthM;
  final double minWidthM;
  final double maxWidthM;

  /// Altura do Conjurador e dos Ecos, e tamanho das Fagulhas e dos materiais, em metros do mundo.
  final double spriteHeightM;
  final double sparkSizeM;

  /// Alcance do rastreador, em metros, e quantos Ecos ele mostra.
  final double trackerM;
  final int trackerMax;

  /// Declinação magnética do lugar, em graus (leste positivo): a bússola do celular lê o norte magnético e o
  /// mapa tem o norte verdadeiro.
  final double declinationDeg;

  /// Pixels físicos por pixel lógico: o marcador e os Ecos têm tamanho fixo na tela, em pixels inteiros.
  final double dpr;

  /// Quantos metros cabem na largura da tela agora. A pinça muda isto.
  late double widthM = defaultWidthM;

  /// A câmera de jogo.
  late final FollowCamera follow;

  /// A rotação do mapa: o arrasto de um dedo, a volta ao norte e o "seguir direção".
  final rotation = MapRotation();

  /// O que a bússola da tela precisa saber: o ângulo, se aparece e se o "seguir direção" está ligado.
  final compass = ValueNotifier<({double angle, bool visible, bool follow})>((angle: 0, visible: false, follow: false));

  /// Pediram para ligar ou desligar a leitura da bússola do celular (o "seguir direção").
  void Function(bool on)? onFollowHeading;

  /// Quanto vale, no gesto, ficar com o pixel de arte maior para segurar o fps (1 = nítido). Só cai para 2
  /// com o dedo na tela e se rasterizar estiver acima de [coarseOverMs].
  int get coarse => follow.touching && _art.rasterMs > coarseOverMs ? 2 : 1;

  /// Acima disto (ms por quadro, média móvel) o gesto rasteriza com o pixel de arte maior.
  static const double coarseOverMs = 9;

  /// O marcador suavizado.
  final avatar = PlayerAvatar();

  double _lat = kUnicamp.$1;
  double _lon = kUnicamp.$2;
  bool _hasFix = false;
  double _refreshIn = 0;
  double _time = 0;
  double _widthAtStart = 0;

  @override
  Color backgroundColor() => const Color(0xFF1A1424);

  /// O jogador mudou de posição ou de estado. Só a posição filtrada move o marcador.
  void onPlayerState(PlayerState s) {
    final p = s.position;
    if (p == null) return;
    final (x, y) = latLonToTileFraction(p.lat, p.lon, biomeZoom);
    final first = !avatar.hasPosition;
    avatar.setTarget(x, y, metersPerCell: metersPerCell(p.lat), timeMs: p.timeMs);
    _lat = p.lat;
    _lon = p.lon;
    if (!_hasFix) _refreshIn = 0; // a primeira posição já mostra o mundo
    _hasFix = true;
    if (first) {
      follow.setTarget(avatar.x, avatar.y); // a câmera segue o marcador suavizado, nunca o GPS cru
      follow.snapToTarget(); // a primeira posição não desliza de lugar nenhum
    }
  }

  /// Esquece a posição (trocou de fonte): o marcador some até a próxima leitura boa.
  void clearPlayer() {
    avatar.clear();
    _hasFix = false;
  }

  void touchStart() {
    _widthAtStart = widthM;
    follow.touchStart();
  }

  void touchEnd() {
    follow.touchEnd();
  }

  /// Os dedos começaram (ou mudaram de número): a pinça conta daqui.
  void gestureStart() => _widthAtStart = widthM;

  /// Pinça com [scale] acumulado desde o início do gesto: só dá zoom.
  void pinch(double scale) {
    if (scale != 1.0) widthM = (_widthAtStart / scale).clamp(minWidthM, maxWidthM).toDouble();
  }

  /// O dedo girou o mapa em [radians] em torno do Conjurador (sentido horário positivo).
  void dragRotate(double radians) {
    if (radians == 0) return;
    rotation.rotateBy(radians);
    onFollowHeading?.call(false);
  }

  /// O centro da tela, onde o Conjurador fica: o eixo do giro.
  Offset get screenCenter => Offset(size.x / 2, size.y / 2);

  /// A bússola do celular leu [magneticDeg] (graus a partir do norte magnético, no sentido horário).
  void setHeading(double magneticDeg) => rotation.setHeading((magneticDeg + declinationDeg) % 360);

  /// Toque na bússola: volta ao norte.
  void goNorth() {
    final was = rotation.followHeading;
    rotation.goNorth();
    if (was) onFollowHeading?.call(false);
  }

  /// Toque duplo na bússola: liga ou desliga o "seguir direção".
  void toggleFollowHeading() {
    rotation.toggleFollowHeading();
    onFollowHeading?.call(rotation.followHeading);
  }

  @override
  void update(double dt) {
    super.update(dt);
    avatar.update(dt);
    _animate(dt);
    _time += dt;
    _refreshIn -= dt;
    if (_hasFix && worldView != null && _refreshIn <= 0) {
      _refreshIn = 0.5;
      worldView!.refresh(lat: _lat, lon: _lon, tUtc: nowUtc());
    }
    if (avatar.hasPosition) follow.setTarget(avatar.x, avatar.y);
    if (size.x > 0) {
      // A escala vem dos metros visíveis: segue a largura da tela e a latitude.
      double ppc(double w) => pixelsPerCellFor(widthM: w, viewWidthPx: size.x, lat: _lat);
      follow.limitScale(ppc(maxWidthM), ppc(minWidthM));
      follow.setScale(ppc(widthM));
    }
    rotation.update(dt);
    follow.setRotation(rotation.angle);
    follow.update(dt);
    final state = (angle: rotation.angle, visible: rotation.showCompass, follow: rotation.followHeading);
    if (state != compass.value) compass.value = state;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0 || size.y <= 0) return;
    final view = Size(size.x, size.y);
    final cam = follow.camera;
    _art.paint(canvas, view, cam, dpr: dpr, metersPerCell: metersPerCell(_lat), coarse: coarse);
    if (overlayBiomes() || overlayGrid20()) _paintLogicalOverlay(canvas, view, cam);
    if (!avatar.hasPosition) return;
    final (sx, sy) = cam.cellToScreen(avatar.x, avatar.y, view.width, view.height);
    final center = Offset(sx, sy);
    // De baixo para cima: Aura no chão, spawns, Conjurador por cima de tudo.
    final w = worldView;
    paintAura(canvas, center, auraRadiusPx(auraM: w?.auraRadiusM ?? auraM, lat: _lat, pixelsPerCell: cam.pixelsPerCell));
    final spriteSize = spriteSizePx, sparkSize = sparkSizePx;
    if (w != null) {
      paintSpawns(
        canvas,
        view,
        cam,
        w.spawns,
        sprites: sprites,
        typeOf: typeOf,
        inAura: w.canReach,
        marked: (s) => w.state.markOf(s.uid) != null,
        time: _time,
        avoid: markerRect(center, spriteSize).inflate(6),
        spriteSize: spriteSize,
        sparkSize: sparkSize,
        dpr: dpr,
      );
    }
    paintPlayerMarker(canvas, center, sprite: _playerFrame, size: spriteSize, mirrored: _facingLeft, dpr: dpr);
    if (w != null) {
      final off = spriteSize / 2;
      final tracked = w.tracked(
        trackerM: w.trackerRangeM,
        max: trackerMax,
        offScreen: (s) {
          final (x, y) = cam.cellToScreen(s.x, s.y, view.width, view.height);
          return x < -off || y < -off || x > view.width + off || y > view.height + off;
        },
      );
      paintTracker(canvas, view, tracked, sprites: sprites, typeOf: typeOf, bottomInset: bottomInset, rotation: cam.rotation);
    }
  }

  /// Sobreposição de debug: a grade de biomas (a camada lógica) e a das células de spawn, translúcidas por
  /// cima do desenho. O renderizador da grade desenha sem rotação, então o canvas gira por ele em torno do
  /// Conjurador, e a câmera sem rotação cobre um quadrado que tem a diagonal da tela.
  void _paintLogicalOverlay(Canvas canvas, Size view, MapCamera cam) {
    final diagonal = math.sqrt(view.width * view.width + view.height * view.height);
    final virtual = Size(diagonal, diagonal);
    final flat = MapCamera(centerX: cam.centerX, centerY: cam.centerY, pixelsPerCell: cam.pixelsPerCell);
    canvas.saveLayer(Offset.zero & view, Paint()..color = const Color(0x99FFFFFF));
    canvas.translate(view.width / 2, view.height / 2);
    canvas.rotate(cam.rotation);
    canvas.translate(-diagonal / 2, -diagonal / 2);
    renderer.paint(canvas, virtual, camera: flat, crosshair: false, grid20: overlayGrid20());
    canvas.restore();
  }

  @override
  void onRemove() {
    _art.dispose();
    compass.dispose();
    super.onRemove();
  }

  /// Barra de navegação do sistema embaixo, em pixels lógicos: o rastreador fica acima dela.
  double bottomInset = 0;

  /// Altura do Conjurador e dos Ecos na tela, em pixels: 12 m do mundo convertidos pelo zoom de agora.
  double get spriteSizePx => spriteHeightM / metersPerCell(_lat) * follow.pixelsPerCell;

  /// Tamanho das Fagulhas e dos materiais na tela, em pixels.
  double get sparkSizePx => sparkSizeM / metersPerCell(_lat) * follow.pixelsPerCell;

  // Animação do Conjurador: parado, ou dois quadros de passo que se alternam enquanto ele anda. O sprite
  // olha para o lado em que anda, vendo o movimento na tela (com o mapa girado).
  static const double _stepS = 0.18;
  double _stepClock = 0;
  bool _facingLeft = false;

  /// Qual quadro do Conjurador desenhar: 0 parado, 1 ou 2 andando.
  int get playerFrameIndex => !avatar.moving ? 0 : 1 + (_stepClock / _stepS).floor() % 2;

  /// Se o sprite está espelhado (olhando para a esquerda da tela).
  bool get facingLeft => _facingLeft;

  ui.Image? get _playerFrame {
    if (playerFrames.isEmpty) return null;
    final i = playerFrameIndex;
    return playerFrames[i < playerFrames.length ? i : 0];
  }

  void _animate(double dt) {
    if (!avatar.moving) {
      _stepClock = 0;
      return;
    }
    _stepClock += dt;
    final r = follow.rotation;
    final screenVx = avatar.velocityX * math.cos(r) - avatar.velocityY * math.sin(r);
    if (screenVx.abs() > 1e-4) _facingLeft = screenVx < 0;
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
      if (d <= hitRadius(s, spriteSizePx, sparkSizePx) && d < bestD) {
        best = s;
        bestD = d;
      }
    }
    return best;
  }
}

EcoType? _noType(String _) => null;
int _zero() => 0;

bool _off() => false;
