import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flame/game.dart';

import 'dart:math' as math;

import '../../capture/eco_type.dart';
import '../../core/tiles.dart';
import '../../world/aura.dart';
import '../../world/follow_camera.dart';
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
/// câmera. As regras (suavização, espiar e voltar, limites de zoom) estão em `world/`.
class GameMapGame extends FlameGame {
  GameMapGame({
    required this.renderer,
    required this.visual,
    required this.style,
    required this.balance,
    this.playerSprite,
    this.overlayBiomes = _off,
    this.overlayGrid20 = _off,
    required this.auraM,
    required this.defaultWidthM,
    required this.minWidthM,
    required this.maxWidthM,
    required this.playerHeightFraction,
    required this.trackerM,
    required this.trackerMax,
    this.dpr = 1,
    this.worldView,
    this.sprites = const {},
    this.typeOf = _noType,
    this.nowUtc = _zero,
    (double, double) fallbackCenter = kUnicamp,
  }) {
    final (x, y) = latLonToTileFraction(fallbackCenter.$1, fallbackCenter.$2, biomeZoom);
    follow = FollowCamera(x: x, y: y);
  }

  /// A grade de biomas: só aparece como sobreposição do menu de debug.
  final MapRenderer renderer;

  /// As geometrias do pacote visual e as cores: o mapa de jogo é desenhado em pixels de arte.
  final VisualMap visual;
  final ArtStyle style;
  final MapBalance balance;
  final ui.Image? playerSprite;

  /// Sobreposições de debug, lidas a cada quadro: a grade de biomas e a grade das células de spawn (z20).
  final bool Function() overlayBiomes;
  final bool Function() overlayGrid20;
  ArtRenderer? _art;

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

  /// O Conjurador e os Ecos ocupam esta fração da altura da tela.
  final double playerHeightFraction;

  /// Alcance do rastreador, em metros, e quantos Ecos ele mostra.
  final double trackerM;
  final int trackerMax;

  /// Pixels físicos por pixel lógico: o marcador e os Ecos têm tamanho fixo na tela, em pixels inteiros.
  final double dpr;

  /// Quantos metros cabem na largura da tela agora. A pinça muda isto.
  late double widthM = defaultWidthM;

  /// A câmera de jogo.
  late final FollowCamera follow;

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
    _widthAtStart = widthM;
    follow.touchStart();
  }

  void touchEnd() => follow.touchEnd();

  /// Arrasto de [dx], [dy] pixels (espiar) e pinça com [scale] acumulado desde o início do gesto.
  void gesture({required double dx, required double dy, required double scale}) {
    if (scale != 1.0) widthM = (_widthAtStart / scale).clamp(minWidthM, maxWidthM).toDouble();
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
    if (size.x > 0) {
      // A escala vem dos metros visíveis: segue a largura da tela e a latitude.
      double ppc(double w) => pixelsPerCellFor(widthM: w, viewWidthPx: size.x, lat: _lat);
      follow.limitScale(ppc(maxWidthM), ppc(minWidthM));
      follow.setScale(ppc(widthM), resetIdle: false);
    }
    follow.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0 || size.y <= 0) return;
    final view = Size(size.x, size.y);
    final cam = follow.camera;
    _artRenderer(view).paint(canvas, view, cam, dpr: dpr);
    if (overlayBiomes() || overlayGrid20()) {
      // Sobreposição de debug: a grade lógica por cima do desenho, translúcida.
      canvas.saveLayer(Offset.zero & view, Paint()..color = const Color(0x99FFFFFF));
      renderer.paint(canvas, view, camera: cam, crosshair: false, grid20: overlayGrid20());
      canvas.restore();
    }
    if (!avatar.hasPosition) return;
    final (sx, sy) = cam.cellToScreen(avatar.x, avatar.y, view.width, view.height);
    final center = Offset(sx, sy);
    // De baixo para cima: Aura no chão, spawns, Conjurador por cima de tudo.
    paintAura(canvas, center, auraRadiusPx(auraM: auraM, lat: _lat, pixelsPerCell: cam.pixelsPerCell));
    final w = worldView;
    if (w != null) {
      paintSpawns(
        canvas,
        view,
        cam,
        w.spawns,
        sprites: sprites,
        typeOf: typeOf,
        inAura: w.inAura,
        time: _time,
        avoid: markerRect(center, dpr, heightDp).inflate(6),
        heightDp: heightDp,
        dpr: dpr,
      );
    }
    paintPlayerMarker(canvas, center, sprite: playerSprite, heightDp: heightDp, dpr: dpr);
    if (w != null) {
      final off = heightDp / 2;
      final tracked = w.tracked(
        trackerM: trackerM,
        max: trackerMax,
        offScreen: (s) {
          final (x, y) = cam.cellToScreen(s.x, s.y, view.width, view.height);
          return x < -off || y < -off || x > view.width + off || y > view.height + off;
        },
      );
      paintTracker(canvas, view, tracked, sprites: sprites, typeOf: typeOf, bottomInset: bottomInset);
    }
  }

  /// O renderizador em pixels de arte. O pixel de arte tem um tamanho fixo em metros, escolhido para que no
  /// zoom padrão a ampliação seja inteira em pixels físicos; refeito se a tela mudar de tamanho.
  ArtRenderer _artRenderer(Size view) {
    final key = (view.width, view.height);
    if (_art != null && _artKey == key) return _art!;
    _art?.dispose();
    final k = math.max(1, (balance.artPixelDp * dpr).round()); // pixels físicos por pixel de arte
    final artM = defaultWidthM * k / (view.width * dpr);
    final mpc = metersPerCell(_lat);
    _artKey = key;
    return _art = ArtRenderer(
      visual: visual,
      style: style,
      balance: balance,
      artCells: artM / mpc,
      metersPerArtPx: artM,
    );
  }

  (double, double)? _artKey;

  @override
  void onRemove() {
    _art?.dispose();
    super.onRemove();
  }

  /// Barra de navegação do sistema embaixo, em pixels lógicos: o rastreador fica acima dela.
  double bottomInset = 0;

  /// Altura do Conjurador e dos Ecos na tela, em pixels lógicos.
  double get heightDp => size.y * playerHeightFraction;

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
      if (d <= hitRadius(s, dpr, heightDp) && d < bestD) {
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
