import 'fx.dart';
import '../../core/features.dart';
import 'dart:ui';
import 'dart:ui' as ui;

import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../capture/eco_type.dart';
import '../../core/astro.dart';
import '../../core/weather.dart';
import '../../world/companion.dart';
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
import '../sprites/sprite_downscale.dart' show snapSpriteSize;
import '../sprites/sprite_image.dart' show mapEcoPx, mapPlayerPx, mapSpiritPx;
import 'art_renderer.dart';
import 'art_style.dart';
import 'spawn_painter.dart';
import 'fog_painter.dart';
import 'rain_painter.dart';
import 'street_label_painter.dart';
import 'trace_painter.dart';
import 'traffic_painter.dart';
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
    this.overlayRadii = _off,
    required this.auraM,
    required this.defaultWidthM,
    required this.minWidthM,
    required this.maxWidthM,
    required this.sparkSizeM,
    required this.trackerM,
    required this.trackerMax,
    this.declinationDeg = 0,
    this.dpr = 1,
    this.worldView,
    this.streetNames = _off,
    this.veilTraffic = _off,
    this.rainFx = _off,
    this.weatherShown = _clear,
    this.variantTint,
    this.familiarImage,
    this.rainDrops = 70,
    this.familiarOffsetM = 6,
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

  /// Debug: desenha por cima o raio lógico da coleta (laranja) e o alcance de toque dos Ecos (ciano).
  final bool Function() overlayRadii;
  late final ArtRenderer _art = ArtRenderer(visual: visual, style: style, balance: balance);
  late final StreetLabelPainter _labels = StreetLabelPainter(visual);
  late final TrafficPainter _traffic = TrafficPainter(visual, carM: balance.ghostCarM, pedestrianM: balance.ghostPedestrianM, roadWidthM: balance.roadWidthM);
  final FogPainter _fog = FogPainter();
  final TracePainter _trace = TracePainter();
  late final RainPainter _rain = RainPainter(maxDrops: rainDrops);

  /// O Familiar que anda ao lado do Conjurador.
  final companion = Companion();
  bool _familiarFacingLeft = false;

  /// Se os nomes de rua estão ligados nos Ajustes (lido a cada quadro).
  final bool Function() streetNames;

  /// A chuva no mapa está ligada nos Ajustes, e o clima que se vê agora (o que o HUD mostra).
  final bool Function() rainFx;
  final Weather Function() weatherShown;

  /// A paleta da variante ou do Brilhante (0xAARRGGBB), ou `null`; o sprite do Familiar; quantas gotas tem a chuva e a
  /// que distância (m) o Familiar anda ao lado do Conjurador.
  final VariantTintOf? variantTint;
  ui.Image? familiarImage;
  final int rainDrops;
  final double familiarOffsetM;

  /// Quantas gotas de chuva e quantas células reveladas (recortes do véu) foram desenhadas no último quadro.
  int get rainCount => _rain.count;
  int get fogCuts => _fog.lastCut;

  /// Quantos fantasmas do tráfego foram desenhados no último quadro.
  int get ghostsDrawn => _traffic.lastDrawn;

  /// Se o tráfego do Véu está ligado nos Ajustes (lido a cada quadro).
  final bool Function() veilTraffic;

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

  /// Quanto o jogador andou entre duas posições aceitas, em metros (para os pedidos de caminhada do fórum).
  void Function(double meters)? onWalked;
  double? _walkLat, _walkLon;

  /// O marcador suavizado.
  final avatar = PlayerAvatar();

  /// Retorno visual: coleta, pulo, costura e fuga dos Ecos.
  final fx = Fx();

  /// Uma Fagulha ou material foi coletado: voa até o Conjurador.
  void onCollected(WorldSpawn s) => fx.collected(s, spawnColor(s, typeOf));

  /// Um Eco arisco fugiu: se desfaz onde estava.
  void onEcoFled(WorldSpawn s) => fx.fled(s, sprites[s.entryId], variantTint?.call(s), ecoSizePx);

  int _utcSecond = -1;
  double _utcAnchor = 0;

  /// O UTC do jogo com fração de segundo: o segundo inteiro vem do relógio do jogo e a fração, do tempo de jogo desde que ele
  /// virou. Dois aparelhos com a mesma hora desenham o tráfego no mesmo ponto (erro de um quadro).
  double _exactUtc() {
    final s = nowUtc();
    if (s != _utcSecond) {
      _utcSecond = s;
      _utcAnchor = _time;
    }
    return s + (_time - _utcAnchor).clamp(0.0, 0.999);
  }

  /// A luz do mapa pela altura do sol em ([_lat], [_lon]) na hora do jogo. Recalculada a cada poucos segundos.
  DayLight light = const DayLight(night: 0, warm: 0);
  double _lightIn = 0;

  /// A longitude de agora (a do último fix).
  double get playerLon => _lon;

  /// A latitude de agora (a do último fix; a da Unicamp antes do primeiro).
  double get playerLat => _lat;

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
    _countWalk(p.lat, p.lon);
    worldView?.noteGps(lat: p.lat, lon: p.lon, tUtc: nowUtc());
    _lat = p.lat;
    _lon = p.lon;
    if (!_hasFix) _refreshIn = 0; // a primeira posição já mostra o mundo
    _hasFix = true;
    if (first) {
      follow.setTarget(avatar.x, avatar.y); // a câmera segue o marcador suavizado, nunca o GPS cru
      follow.snapToTarget(); // a primeira posição não desliza de lugar nenhum
    }
  }

  /// Soma a distância andada desde a última posição, ignorando saltos de mais de 25 m (teleporte, GPS ruim).
  void _countWalk(double lat, double lon) {
    final la = _walkLat, lo = _walkLon;
    _walkLat = lat;
    _walkLon = lon;
    if (la == null || lo == null) return;
    final dy = (lat - la) * 111320.0;
    final dx = (lon - lo) * 111320.0 * math.cos(lat * math.pi / 180);
    final d = math.sqrt(dx * dx + dy * dy);
    if (d >= 0.5 && d <= 25) onWalked?.call(d);
  }

  /// Esquece a posição (trocou de fonte): o marcador some até a próxima leitura boa.
  void clearPlayer() {
    avatar.clear();
    _hasFix = false;
    _walkLat = _walkLon = null;
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
    if (avatar.hasPosition) {
      companion.update(dt, ax: avatar.x, ay: avatar.y, vx: avatar.velocityX, vy: avatar.velocityY, offsetCells: familiarOffsetM / metersPerCell(_lat));
    } else {
      companion.clear();
    }
    if (size.x > 0) {
      final w = weatherShown();
      _rain.update(dt, Size(size.x, size.y), rainFx() ? (w == Weather.storm ? 1.6 : (w == Weather.rain ? 1.0 : 0.0)) : 0.0);
    }
    _lightIn -= dt;
    if (_lightIn <= 0 && _hasFix) {
      _lightIn = 5;
      light = dayLightAt(_lat, _lon, nowUtc());
    }
    _time += dt;
    fx.update(dt);
    _refreshIn -= dt;
    if (_hasFix && worldView != null && _refreshIn <= 0) {
      _refreshIn = 0.25;
      // A lógica lê a MESMA posição que o desenho (o marcador suavizado), não a leitura crua do GPS: assim o que o círculo
      // mostra dentro é o que a coleta pega.
      final (lat, lon) = avatar.hasPosition ? tileFractionToLatLon(avatar.x, avatar.y, biomeZoom) : (_lat, _lon);
      worldView!.refresh(lat: lat, lon: lon, tUtc: nowUtc());
      fx.observe(worldView!.spawns);
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
    _paintLight(canvas, view);
    if (veilTraffic() && _hasFix && worldView != null) {
      _traffic.paint(canvas, view, cam, seed: worldView!.field.seed, tUtc: nowUtc(), tUtcExact: _exactUtc(), lonDeg: _lon, metersPerCell: metersPerCell(_lat), light: light);
    } else {
      _traffic.lastDrawn = 0;
    }
    if (streetNames()) _labels.paint(canvas, view, cam);
    if (streetLifeEnabled && worldView != null && _hasFix) _fog.paint(canvas, view, cam, worldView!.state.fog);
    if (overlayBiomes() || overlayGrid20()) _paintLogicalOverlay(canvas, view, cam);
    if (!avatar.hasPosition) return;
    final (sx, sy) = cam.cellToScreen(avatar.x, avatar.y, view.width, view.height);
    final center = Offset(sx, sy);
    // De baixo para cima: Aura no chão, spawns, Conjurador por cima de tudo.
    final w = worldView;
    paintAura(canvas, center, auraRadiusPx(auraM: w?.auraRadiusM ?? auraM, lat: _lat, pixelsPerCell: cam.pixelsPerCell));
    if (w != null && w.spawns.any((s) => s.isEco && w.distanceM(s) <= balance.touchRingShowM)) {
      // Há Eco a até 40 m: um anel fino e fraco mostra o alcance de toque (30 m), diferente do círculo tracejado da Aura.
      canvas.drawCircle(
        center,
        auraRadiusPx(auraM: w.touchRangeM, lat: _lat, pixelsPerCell: cam.pixelsPerCell),
        Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = const Color(0xFF5FD3C6).withValues(alpha: 0.3)..isAntiAlias = false,
      );
    }
    if (overlayRadii()) {
      final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..isAntiAlias = false;
      final ppc = cam.pixelsPerCell;
      canvas.drawCircle(center, auraRadiusPx(auraM: w?.auraRadiusM ?? auraM, lat: _lat, pixelsPerCell: ppc), ring..color = const Color(0xFFFF7A45));
      canvas.drawCircle(center, auraRadiusPx(auraM: w?.touchRangeM ?? 30, lat: _lat, pixelsPerCell: ppc), ring..color = const Color(0xFF5FD3C6));
    }
    final spriteSize = ecoSizePx, playerSize = playerSizePx, sparkSize = sparkSizePx;
    if (w != null && w.traces.isNotEmpty) {
      _trace.paint(canvas, view, cam, traces: w.traces, ecos: w.allEcos, playerX: avatar.x, playerY: avatar.y, metersPerCell: metersPerCell(_lat), nowUtc: nowUtc());
    }
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
        tintOf: variantTint,
        hopOf: (uid) => fx.hopOffset(uid, 8),
        appearOf: fx.appear,
        time: _time,
        avoid: markerRect(center, playerSize).inflate(6),
        spriteSize: spriteSize,
        spiritSize: spiritSizePx,
        sparkSize: sparkSize,
        dpr: dpr,
      );
    }
    if (streetLifeEnabled) _paintFamiliar(canvas, cam, view);
    // Parado, o Conjurador respira: dois quadros, o segundo um pixel de arte mais alto.
    final breath = avatar.moving || ((_time / 0.7).floor() % 2 == 0) ? 0.0 : -balance.artPixelDp;
    paintPlayerMarker(canvas, center.translate(0, breath), sprite: _playerFrame, size: playerSize, mirrored: _facingLeft, dpr: dpr);
    fx.paint(canvas, view, cam, avatar: center, playerSize: playerSize, sparkSize: sparkSize, dpr: dpr);
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
    _rain.paint(canvas);
  }

  /// A luz do dia sobre o desenho do mapa: à noite escurece e esfria (multiplica por um azul profundo), no nascer e
  /// no pôr do sol esquenta um pouco. Cobre só o mapa; Aura, spawns e Conjurador vêm depois, sem escurecer.
  void _paintLight(Canvas canvas, Size view) {
    final rect = Offset.zero & view;
    if (light.night > 0.004) {
      const nightTint = Color(0xFF3F4A8C);
      canvas.drawRect(rect, Paint()..color = Color.lerp(const Color(0xFFFFFFFF), nightTint, light.night)!..blendMode = BlendMode.multiply);
    }
    if (light.warm > 0.004) {
      canvas.drawRect(rect, Paint()..color = Color.fromRGBO(255, 138, 64, 0.17 * light.warm));
    }
  }

  /// O Familiar, ao lado do Conjurador: o mesmo cuidado do avatar (suavizado, olha para o lado em que anda na tela, com um
  /// leve balanço ao andar).
  void _paintFamiliar(Canvas canvas, MapCamera cam, Size view) {
    if (familiarImage == null || !companion.hasPosition) return;
    final screenVx = math.cos(companion.heading + cam.rotation);
    if (companion.moving && screenVx.abs() > 1e-3) _familiarFacingLeft = screenVx < 0;
    final (sx, sy) = cam.cellToScreen(companion.x, companion.y, view.width, view.height);
    final bob = companion.moving ? (math.sin(_time * 7) * 1.5).roundToDouble() : (math.sin(_time * 2) * 1.0).roundToDouble();
    paintPlayerMarker(canvas, Offset(sx.roundToDouble(), sy.roundToDouble() + bob), sprite: familiarImage, size: familiarSizePx, mirrored: _familiarFacingLeft, dpr: dpr);
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

  /// Alturas na tela, em pixels lógicos: os metros do mundo (`balance.json`) convertidos pelo zoom de agora e ajustados
  /// a um múltiplo inteiro de pixels físicos por pixel do sprite (nada de pixel mais gordo que o vizinho).
  double get ecoSizePx => snapSpriteSize(balance.ecoHeightM / metersPerCell(_lat) * follow.pixelsPerCell, dpr, mapEcoPx);
  double get spiritSizePx => snapSpriteSize((worldView?.state.cb.spiritHeightM ?? balance.ecoHeightM) / metersPerCell(_lat) * follow.pixelsPerCell, dpr, mapSpiritPx);
  double get playerSizePx => snapSpriteSize(balance.playerHeightM / metersPerCell(_lat) * follow.pixelsPerCell, dpr, mapPlayerPx);
  double get familiarSizePx => snapSpriteSize(balance.familiarHeightM / metersPerCell(_lat) * follow.pixelsPerCell, dpr, mapPlayerPx);

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
      if (d <= hitRadius(s, ecoSizePx, sparkSizePx, spiritSize: spiritSizePx) && d < bestD) {
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
Weather _clear() => Weather.clear;
