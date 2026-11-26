import 'fx.dart';
import '../../crafting/crafting_state.dart';
import '../../crafting/loadout.dart' show avatarGear, RideBand, vehicleLook;
import '../../crafting/quality.dart' show Quality, parseStack;
import '../../world/city_scene.dart' show CityTile;
import '../../world/sim/birds.dart' show BirdFlocks;
import '../craft/ui_art.dart';
import 'touch_fx.dart';
import 'veil_painter.dart';
import '../../world/veilbreakers.dart' show VeilbreakerField, Veilbreaker;
import '../../world/map_touch.dart' show TouchBalance;
import '../../core/features.dart';
import 'dart:ui';
import 'dart:ui' as ui;

import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../capture/eco_type.dart';
import '../colors.dart' show kCycleway, kDim, kEssence, kOutline, kSignal, kVeil;
import '../../core/astro.dart';
import '../../core/weather.dart';
import '../../world/companion.dart';
import '../../world/creature_wind.dart';
import '../../world/debug_creatures.dart' show isDebugUid;
import '../../core/tiles.dart';
import '../../world/climate_world.dart' show Puddle;
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
import 'spawn_trigger.dart';
import 'climate_fx.dart';
import 'climate_ground.dart';
import 'draw_order.dart';
import 'climate_painter.dart';
import 'creature_art.dart';
import 'rainbow_painter.dart';
import '../../data/climate_catalog.dart';
import 'street_label_painter.dart';
import 'trace_painter.dart';
import 'traffic_painter.dart';
import 'relief_heat.dart';
import 'world_fx.dart';
import '../../data/relief_pack.dart';
import '../../data/cycle_pack.dart';
import '../../data/traffic_pack.dart';
import '../../world/sim/traffic_sim.dart' show TrafficSim, TrafficSimConfig;
import '../travel/travel_layer.dart';
import 'tracker_painter.dart';
import 'player_painter.dart';
import '../../data/building_pack.dart';
import '../../world/style_advisor.dart';
import '../city/city_renderer.dart';
import '../city/city_sources.dart';
import '../city/turn_category.dart';
import '../../world/city_scene.dart' show roadClassKey;
import '../../data/visual_pack.dart' show RoadClass;
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection;
import '../lab/lab_art.dart';
import '../../data/ground_pack.dart';

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
    this.overlayPuddles = _off,
    required this.auraM,
    required this.defaultWidthM,
    required this.minWidthM,
    required this.maxWidthM,
    required this.sparkSizeM,
    this.declinationDeg = 0,
    this.dpr = 1,
    this.worldView,
    this.streetNames = _off,
    this.veilTraffic = _off,
    this.trafficSim = const TrafficSimConfig(),
    this.trafficPoints,
    this.noCrossingAt,
    this.overlayTraffic = _off,
    this.overlayRelief = _off,
    this.cycleways,
    this.ground,
    this.relief,
    this.trafficDensity = _noDensity,
    this.rainFx = _off,
    this.climateShown = _clearInfo,
    this.climateCatalog = const ClimateCatalog(),
    this.climateBalance = const ClimateBalance(),
    this.reduceFlashes = _off,
    this.variantTint,
    this.familiarImage,
    this.familiarOffsetM = 6,
    this.sprites = const {},
    this.typeOf = _noType,
    this.nowUtc = _zero,
    this.floorTile,
    this.floorGridCells = 2,
    this.buildings,
    this.simpleStyle = _off,
    (double, double) fallbackCenter = kUnicamp,
  }) {
    final (x, y) = latLonToTileFraction(fallbackCenter.$1, fallbackCenter.$2, biomeZoom);
    // O marcador já vem suavizado: a câmera só o acompanha de perto.
    follow = FollowCamera(x: x, y: y, followTauS: 0.06);
  }

  /// A grade de biomas: só aparece como sobreposição do menu de debug.
  final MapRenderer renderer;

  /// 0.22.0: os prédios e as árvores do estilo Completo (`null`: sem o arquivo) e se o mapa está no estilo Simplificado
  /// (Ajustes, lido a cada quadro). Os dois estilos usam a mesma lógica e a mesma máscara de ruas.
  final BuildingSource? buildings;
  final bool Function() simpleStyle;
  /// O estilo deste quadro: o Completo, a menos que os Ajustes peçam o Simplificado, o mapa seja o de Rotas (0.22.2: sempre
  /// Simplificado) ou o zoom passe de 120 m (volta ao Completo abaixo de 112 m).
  bool get fullStyle => !simpleStyle() && !routesView && !_autoSimple;
  bool _autoSimple = false;

  /// O mapa de Rotas (escolher destino ou a viagem) está aberto: tela larga do Modo Viagem.
  bool get routesView => _travelViewM != null;

  /// Nível de detalhe de longe (0.22.2): sem tráfego, passantes, bichos e partículas; as ruas finas somem antes.
  bool get farView => routesView || widthM > kAutoSimpleM;

  /// "Zoom ampliado" nos Ajustes (lido a cada quadro): a pinça abre até 250 m.
  bool Function() wideZoom = () => false;

  /// Debug: a largura pedida pelo menu (sem pinça), aplicada uma vez a cada pedido novo.
  double? Function() forcedWidthM = () => null;
  double? _forcedWidth;

  late final MapCityTiles cityTiles = MapCityTiles(visual: visual, grid: renderer.map.pack, biomes: renderer.map.biomes, buildings: buildings, points: trafficPoints, ground: ground);
  LabArt? _cityArt;
  CityRenderer? _city;

  /// 0.22.2: os carimbos do Aseprite (`assets/art/map/`, carregados pela tela) e o debug que troca a arte em código por eles.
  Map<String, ui.Image> asepriteStamps = const {};
  bool Function() asepriteArt = () => false;
  bool? _cityAse;

  /// O renderizador do Completo, montado no primeiro quadro em que o estilo é usado (e de novo quando a arte troca).
  CityRenderer get city {
    final ase = asepriteArt() && asepriteStamps.isNotEmpty;
    if (_city != null && _cityAse != ase) {
      _city!.dispose();
      _cityArt?.dispose();
      _city = null;
      _cityArt = null;
    }
    _cityAse = ase;
    return _city ??= CityRenderer(art: _cityArt ??= LabArt.build(overrides: ase ? asepriteStamps : const {}), tileAt: cityTiles.tileAt, biomeAt: cityTiles.biomeAt, cellsPerTile: visual.cellsPerTile);
  }
  int _cityRevision = -1;
  bool? _wasFull;

  /// O sol de agora no lugar do jogador (graus), relido a cada 5 s com a luz do dia.
  double sunAltDeg = 45, sunAzDeg = 0;

  /// Sugere uma vez o Simplificado quando o Completo fica lento (`StyleAdvisor`). A tela grava e mostra o aviso.
  final styleAdvisor = StyleAdvisor();
  void Function()? onSuggestSimple;

  /// As geometrias do pacote visual e as cores: o mapa de jogo é desenhado em pixels de arte.
  final VisualMap visual;
  final ArtStyle style;
  final MapBalance balance;

  /// Tile z15 sem dado nenhum: o desenho marca o piso (`ArtRenderer.floorTile`).
  final bool Function(int tx, int ty)? floorTile;
  final int floorGridCells;
  /// Os quadros do Conjurador: parado e os dois do passo.
  final List<ui.Image> playerFrames;

  /// Sobreposições de debug, lidas a cada quadro: a grade de biomas e a grade das células de spawn (z20).
  final bool Function() overlayBiomes;
  final bool Function() overlayGrid20;

  /// Debug: desenha por cima o raio lógico da coleta (laranja) e o alcance de toque dos Ecos (ciano).
  final bool Function() overlayRadii;

  /// Debug: marca as poças (as do Rill em laranja, as do mundo em ciano).
  final bool Function() overlayPuddles;
  late final ArtRenderer _art = ArtRenderer(visual: visual, style: style, balance: balance, floorTile: floorTile, floorGridCells: floorGridCells);
  late final StreetLabelPainter _labels = StreetLabelPainter(visual);
  late final TrafficPainter _traffic = TrafficPainter(visual, carM: balance.ghostCarM, pedestrianM: balance.ghostPedestrianM, roadWidthM: balance.roadWidthM, config: trafficSim, points: trafficPoints, noCrossingAt: noCrossingAt, cycleways: cycleways);
  final TracePainter _trace = TracePainter();
  late final ClimatePainter _climate = ClimatePainter(cap: climateBalance.particleCap, pocketRate: climateBalance.pocketRate);

  /// O clima em duas camadas: no céu (traço do raio, meteoro, clarão, tremor, trovão) e no chão do mapa (poças, crateras,
  /// zonas, ruas cobertas, pegadas), que gira, move e dá zoom com o mapa.
  late final ClimateFx climateFx = ClimateFx(catalog: climateCatalog, balance: climateBalance);
  late final ClimateGround climateGround = ClimateGround(
      catalog: climateCatalog, visual: visual, roadWidthM: balance.roadWidthM, artPixelDp: balance.artPixelDp, asphalt: style.asphalt.toARGB32(), figureM: balance.ghostPedestrianM);

  /// O arco-íris de pé no mapa (época 8), entre o chão e os spawns: gira com o mapa.
  late final RainbowPainter rainbow = RainbowPainter(climateCatalog.rainbowArc);
  double _climateIn = 0;

  /// O vento nas criaturas (só desenho): inclina, balança e empurra os leves; cai devagar quando o vento passa.
  late final CreatureWind creatureWind = CreatureWind(climateBalance.creatureWind);

  /// Modo bolso: o clima desenha bem menos partículas (o agente da Patrulha liga).
  void setPocket(bool on) => _climate.setPocket(on);

  /// O Familiar que anda ao lado do Conjurador.
  final companion = Companion();
  bool _familiarFacingLeft = false;

  /// Se os nomes de rua estão ligados nos Ajustes (lido a cada quadro).
  final bool Function() streetNames;

  /// O clima no mapa está ligado nos Ajustes, e o clima que se vê agora (o que o HUD mostra).
  final bool Function() rainFx;
  final ClimateInfo Function() climateShown;
  final ClimateCatalog climateCatalog;
  final ClimateBalance climateBalance;

  /// "Reduzir clarões" nos Ajustes: o clarão do raio vira um escurecimento leve.
  final bool Function() reduceFlashes;

  /// A paleta da variante ou do Brilhante (0xAARRGGBB), ou `null`; o sprite do Familiar e a que distância (m) o Familiar
  /// anda ao lado do Conjurador.
  final VariantTintOf? variantTint;
  ui.Image? familiarImage;
  final double familiarOffsetM;

  /// O custo de rasterizar o mapa no estilo Simplificado (média móvel, ms).
  double get artRasterMs => _art.rasterMs;

  /// Quantas partículas de clima foram desenhadas no último quadro.
  int get rainCount => _climate.count;

  /// Onde estão as partículas de clima na tela (testes de cobertura).
  Iterable<Offset> get climatePositions => _climate.positions;

  /// Quantos fantasmas do tráfego foram desenhados no último quadro.
  int get ghostsDrawn => _traffic.lastDrawn;

  /// Se o tráfego do Véu está ligado nos Ajustes (lido a cada quadro).
  final bool Function() veilTraffic;

  /// A simulação local do tráfego: os números (`balance.json`), os pontos do OSM e os viadutos.
  final TrafficSimConfig trafficSim;
  final TrafficPointSource? trafficPoints;
  final CyclePack? cycleways;

  /// 0.23.1: o uso do solo da região embutida (o chão do Completo).
  final GroundPack? ground;

  /// A revisão da água no relevo (sobe quando um tile chega do cálculo de fundo). A tela liga.
  int Function() waterRevision = () => 0;
  final bool Function(double x, double y)? noCrossingAt;

  /// Debug: desenha a área simulada e a fase dos semáforos; e força a densidade (`null`: a da hora e do clima).
  final bool Function() overlayTraffic;

  /// O relevo (`null`: terreno plano) e o debug que o desenha como mapa de calor.
  final ReliefSource? relief;
  final bool Function() overlayRelief;
  final double? Function() trafficDensity;
  static double? _noDensity() => null;

  /// A simulação do tráfego (debug: contador de agentes e custo do passo). `null` antes do primeiro quadro com tráfego.
  TrafficSim? get trafficSimState => _traffic.sim;
  double _frameDt = 1 / 60;

  /// Os jogos do feed (dia de jogo no cenário).
  set matchUtc(List<int> v) => _traffic.matchUtc = v;

  /// O custo médio por quadro do véu da neblina e dos bichos e do vento (debug), em microssegundos.
  double fogUs = 0;
  double get lifeUs => _traffic.lifeUs;

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
  double maxWidthM;

  /// O Modo Viagem desenha por aqui: rota, destino e carro da corrida.
  TravelLayer? travelLayer;
  double? _travelViewM;
  late final double _normalMaxWidthM = maxWidthM;

  /// O Modo Viagem pede uma tela mais larga que a da pinça. `null` volta ao normal.
  void setTravelView(double? m) {
    if (m == _travelViewM) return;
    final normal = _normalMaxWidthM;
    _travelViewM = m;
    maxWidthM = m ?? normal;
    widthM = m ?? defaultWidthM;
  }

  /// A célula z21 sob um ponto da tela.
  (double, double) cellAt(Offset screen) => follow.camera.screenToCell(screen.dx, screen.dy, size.x, size.y);

  /// Altura do Conjurador e dos Ecos, e tamanho das Fagulhas e dos materiais, em metros do mundo.
  final double sparkSizeM;


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
    _frameDt = dt;
    if (_travelViewM == null) {
      maxWidthM = wideZoom() ? kWideZoomMaxM : _normalMaxWidthM;
      if (widthM > maxWidthM) widthM = maxWidthM;
    }
    final fw = forcedWidthM();
    if (fw != _forcedWidth) {
      _forcedWidth = fw;
      if (fw != null) widthM = fw.clamp(minWidthM, maxWidthM).toDouble();
    }
    _autoSimple = autoSimple(widthM: widthM, wasAuto: _autoSimple);
    final full = fullStyle;
    if (full != _wasFull) {
      _wasFull = full;
      styleAdvisor.reset();
      // O Simplificado dos Ajustes não usa os blocos: a memória volta. No automático (zoom, Rotas) os blocos ficam para a
      // volta ao Completo não ter tranco.
      if (!full && simpleStyle()) _city?.clear();
    }
    if (full && styleAdvisor.add(dt)) onSuggestSimple?.call();
    avatar.update(dt);
    _animate(dt);
    if (avatar.hasPosition) {
      companion.update(dt, ax: avatar.x, ay: avatar.y, vx: avatar.velocityX, vy: avatar.velocityY, offsetCells: familiarOffsetM / metersPerCell(_lat));
    } else {
      companion.clear();
    }
    if (size.x > 0) _updateClimate(dt);
    _lightIn -= dt;
    if (_lightIn <= 0 && _hasFix) {
      _lightIn = 5;
      light = dayLightAt(_lat, _lon, nowUtc());
      sunAltDeg = sunAltitudeDeg(_lat, _lon, nowUtc());
      sunAzDeg = sunAzimuthDeg(_lat, _lon, nowUtc());
    }
    _time += dt;
    fx.update(dt);
    _refreshIn -= dt;
    if (_hasFix && worldView != null && _refreshIn <= 0) {
      _refreshIn = 0.25;
      worldView!.field.climate?.motionTime = _exactUtc(); // o movimento de Ecos e Fagulhas, contínuo entre dois segundos
      // A lógica lê a MESMA posição que o desenho (o marcador suavizado), não a leitura crua do GPS: assim o que o círculo
      // mostra dentro é o que a coleta pega.
      final (lat, lon) = avatar.hasPosition ? tileFractionToLatLon(avatar.x, avatar.y, biomeZoom) : (_lat, _lon);
      worldView!.refresh(lat: lat, lon: lon, tUtc: nowUtc());
      fx.observe(worldView!.spawns);
    }
    final piece = followPiece() ? _movingPiece() : null;
    if (piece != null) {
      follow.setTarget(piece.$1, piece.$2);
    } else if (avatar.hasPosition) {
      follow.setTarget(avatar.x, avatar.y);
    }
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
    final wv = worldView;
    final mpc = metersPerCell(_lat);
    final far = farView;
    final traffic = veilTraffic() && _hasFix && wv != null && !far;
    final full = fullStyle;
    _climate
      ..reduction = far ? 0.0 : (full ? 1.0 : 0.5)
      ..halfRes = true
      ..dpr = dpr;
    if (traffic) {
      final tc = rainFx() ? climateGround.trafficCover(wv.field.seed, climateShown(), wv.climate) : null; // barcos, dunas, gelo
      final mult = wv.climate.trafficMult <= 0 ? 1.0 : wv.climate.trafficMult; // 0 é o Silêncio: pausa, não lentidão
      _traffic.prepare(view, cam, seed: wv.field.seed, tUtc: nowUtc(), tUtcExact: _exactUtc(), lonDeg: _lon, metersPerCell: mpc, light: light, px: avatar.x, py: avatar.y, dt: _frameDt, paused: _trafficPaused(), speedMult: mult, walkMult: mult * wv.climate.walkerMult, streetState: tc?.state, coverKey: tc?.key, skid: tc?.skid ?? false, outfit: climateShown().outfit, climateId: rainFx() ? climateShown().id : null, windRad: wv.climate.windHeadingRad, forcedDensity: trafficDensity());
    _traffic.sim?.busShareOverride = manyBuses() ? 1 : null;
      climateGround.cover
        ?..wearOf = _traffic.wearOf
        ..wearStamp = _traffic.wearStamp;
      climateGround.cover?.waterStamp = waterRevision();
    } else {
      _traffic.lastDrawn = 0;
    }
    final here = avatar.hasPosition;
    final (ax, ay) = cam.cellToScreen(avatar.x, avatar.y, view.width, view.height);
    final center = Offset(ax, ay);
    canvas.save();
    canvas.translate(climateFx.shakeOffset.dx, climateFx.shakeOffset.dy); // o impacto do meteoro treme o mundo, não o HUD
    // A ordem é a de MapLayer (draw_order.dart), não a deste mapa.
    paintLayers({
      MapLayer.base: () {
        if (full) {
          _paintCityGround(canvas, view, cam, mpc);
        } else {
          final hide = hiddenRoadClasses(widthM);
          _art.paint(canvas, view, cam, dpr: dpr, metersPerCell: mpc, coarse: coarse, hideRoads: {for (final c in RoadClass.values) if (hide.contains(roadClassKey(c))) c});
        }
        _paintCycleways(canvas, view, cam);
        if (!full) _paintLight(canvas, view);
        travelLayer?.paintGround(canvas, view, cam, mpc, utc: _exactUtc(), avatar: avatar);
        if (streetNames()) _labels.paint(canvas, view, cam);
        if (overlayBiomes() || overlayGrid20()) _paintLogicalOverlay(canvas, view, cam);
        if (overlayRelief() && relief != null) paintReliefHeat(canvas, view, cam, relief!);
      },
      if (wv != null && _hasFix) MapLayer.climateGround: () => _paintClimateGround(canvas, view, cam, wv),
      MapLayer.shadows: climateGround.paintShadows,
      if (here && wv != null) ...{
        MapLayer.creatures: () {
          // 0.24.5: o Ônibus Espectral (cena do mundo, igual para o grupo) e os Outros Veilbreakers, com a sintonia.
          if (ecoAnchors.length > 600) ecoAnchors.clear();
          _trackEcoMotion(wv, cam);
          _emissive.clear();
          paintSpectralBuses(canvas, view, cam, visibleTiles(view, cam), _exactUtc(), seed: wv.field.seed, b: touchBalance, pxPerM: cam.pixelsPerCell / mpc, mpc: mpc, carM: balance.ghostCarM, figure: playerSizePx);
          _paintSpawns(canvas, view, cam, wv, center, (s) => s.isEco);
          final v = veil;
          if (v != null) {
            final t = _exactUtc();
            visibleVeilbreakers = v.around(avatar.x, avatar.y, t.floor(), view.longestSide / cam.pixelsPerCell * mpc);
            paintVeilbreakers(canvas, view, cam, visibleVeilbreakers, t, size: playerSizePx, fallback: playerFrames, anchorOf: (uid) => ecoAnchors[uid], ecoSize: ecoSizePx);
          }
        },
        MapLayer.sparks: () {
          // Os redemoinhos das Correntes do Véu ficam por baixo das Fagulhas que giram neles.
          final cw = wv.field.climate;
          if (cw != null) paintVortices(canvas, view, cam, wv.field.seed, cw.schedule.select(nowUtc()).epoch, _exactUtc(), mpc, balance.artPixelDp);
          _paintSpawns(canvas, view, cam, wv, center, (s) => s.isSpark);
        },
        MapLayer.materials: () {
          _paintSpawns(canvas, view, cam, wv, center, (s) => !s.isEco && !s.isSpark);
          _paintCollectors(canvas, view, cam, wv);
        },
      },
      if (traffic) ...{
        MapLayer.walkers: () {
          _traffic.paintLeaves(canvas); // no chão, por baixo de quem anda
          _traffic.paintWalkers(canvas);
        },
        MapLayer.cars: () {
          _traffic.paintCars(canvas);
          // O pombo que pousa dentro de um prédio fica no telhado (só no estilo Completo, que desenha os telhados).
          _traffic.birds.roofAt = full ? city.roofHeightAt : null;
          _traffic.paintBirds(canvas); // os do chão; os do ar vão na camada do ar
          if (overlayTraffic()) _traffic.paintDebug(canvas, view, cam, mpc);
        },
      },
      if (full) MapLayer.buildings: () => _paintCityUpright(canvas, view, cam, mpc, here ? center : null, wv),
      if (here) MapLayer.reach: () => _paintAura(canvas, view, cam, center),
      if (here) MapLayer.player: () => _paintPlayer(canvas, view, cam, center),
      MapLayer.air: () {
        // 0.24.2: o pássaro voando, o pousado no telhado, as maritacas e os morcegos ficam por cima dos telhados e árvores.
        // As reações ao toque (pena, folha, onda, clarão, coração): presas ao mapa, por cima de tudo que é do mundo.
        touchFx.paint(canvas, view, cam, _time, playerSizePx / mapPlayerPx);
        if (traffic) {
          _traffic.paintLeaves(canvas, air: true);
          _traffic.paintBirds(canvas, air: true);
        }
        if (_hasFix) rainbow.paint(canvas, view, cam, metersPerCell21: mpc, exactUtc: _exactUtc());
        climateGround.paintAir();
        // A neblina presa ao mapa, mais densa nas baixadas (a camada leve da tela vem depois).
        final cw = wv?.field.climate;
        if (cw != null && _hasFix && rainFx()) {
          final sw = Stopwatch()..start();
          paintFogVeil(canvas, view, cam, cw, cw.schedule.select(nowUtc()).epoch, climateShown().id, nowUtc());
          fogUs = fogUs * 0.95 + sw.elapsedMicroseconds * 0.05;
        }
        canvas.restore(); // fim do tremor: daqui para cima é tela
      },
      // O clima da tela por cima do mapa e de quem está nele, por igual, e por baixo do HUD: cobre a tela toda.
      MapLayer.climateScreen: () {
        climateFx.paintSky(canvas, view, cam);
        _climate.paint(canvas, view, player: here ? center : null, sky: skyRects);
      },
      // 0.25.0: o que brilha nas criaturas (ocelos, veios, faíscas), depois do tom da noite e do clima.
      MapLayer.emissive: () {
        // Presa ao mundo: o mesmo tremor do impacto que o corpo levou.
        canvas.save();
        canvas.translate(climateFx.shakeOffset.dx, climateFx.shakeOffset.dy);
        for (final light in _emissive) {
          light();
        }
        canvas.restore();
        _emissive.clear();
      },
      if (wv != null && here && (wv.pulse != null || wv.state.pins.isNotEmpty))
        MapLayer.hud: () {
          final off = ecoSizePx / 2;
          final marks = wv.edgeMarksAt(_exactUtc(), onScreen: (s) {
            final (x, y) = cam.cellToScreen(s.x, s.y, view.width, view.height);
            return x >= -off && y >= -off && x <= view.width + off && y <= view.height + off;
          });
          paintEdgeMarks(canvas, view, center, marks, rotation: cam.rotation);
        },
    }, drawn: lastLayers..clear());
    if (turnLabels()) paintTurnLabels(canvas, view, cam);
  }

  /// Debug (0.22.2): o tipo e a categoria de giro de cada objeto à vista.
  bool Function() turnLabels = () => false;

  /// O que o modo "Giro dos objetos" escreveu no último quadro (teste).
  final turnLabelsDrawn = <String>[];

  void paintTurnLabels(Canvas canvas, Size view, MapCamera cam) {
    final items = <(String, Offset)>[];
    bool inView(double x, double y) => x >= 0 && y >= 0 && x <= view.width && y <= view.height;
    void add(String kind, double cx, double cy) {
      final (x, y) = cam.cellToScreen(cx, cy, view.width, view.height);
      if (inView(x, y)) items.add((kind, Offset(x, y)));
    }

    final (l, t, r, b) = cam.visibleBounds(view.width, view.height);
    final cpt = visual.cellsPerTile;
    var roads = 0;
    for (var ty = (t / cpt).floor(); ty <= (b / cpt).floor(); ty++) {
      for (var tx = (l / cpt).floor(); tx <= (r / cpt).floor(); tx++) {
        final tile = cityTiles.tileAt(tx, ty);
        if (fullStyle) {
          for (final bd in tile.buildings) {
            add('telhado', bd.centroid.$1, bd.centroid.$2);
          }
          for (final p in tile.props) {
            add(propKindName(p.kind), p.x, p.y);
          }
        }
        for (final rd in tile.roads) {
          if (roads > 8 || rd.xy.length < 4) continue;
          final m = rd.xy.length ~/ 4 * 2;
          final (x, y) = cam.cellToScreen(rd.xy[m], rd.xy[m + 1], view.width, view.height);
          if (inView(x, y)) {
            items.add(('rua', Offset(x, y)));
            roads++;
          }
        }
      }
    }
    for (final (k, x, y) in _traffic.debugObjects) {
      if (inView(x, y)) items.add((k, Offset(x, y)));
    }
    for (final s in worldView?.spawns ?? const <WorldSpawn>[]) {
      add(s.isEco ? 'Eco' : (s.isSpark ? 'Fagulha' : 'material'), s.x, s.y);
    }
    if (avatar.hasPosition) add('Conjurador', avatar.x, avatar.y);
    turnLabelsDrawn
      ..clear()
      ..addAll(items.map((e) => turnLabel(e.$1)));
    // Um rótulo por casa de 56 × 20 px: o resto some para dar para ler.
    final taken = <(int, int)>{};
    for (final (kind, at) in items) {
      if (!taken.add(((at.dx / 56).floor(), (at.dy / 20).floor()))) continue;
      final turn = objectTurn[kind] ?? Turn.upright;
      final color = switch (turn) { Turn.ground => const Color(0xFF8BE08B), Turn.upright => const Color(0xFFFFFFFF), Turn.heading => const Color(0xFFFFB060) };
      final tp = TextPainter(text: TextSpan(text: turnLabel(kind), style: TextStyle(fontSize: 8, color: color)), textDirection: TextDirection.ltr)..layout();
      final box = Rect.fromLTWH(at.dx - tp.width / 2 - 2, at.dy - tp.height - 4, tp.width + 4, tp.height + 2);
      canvas.drawRect(box, Paint()..color = const Color(0xCC1A1424));
      tp.paint(canvas, box.topLeft + const Offset(2, 1));
      canvas.drawCircle(at, 2, Paint()..color = color);
    }
  }

  static const _wetClimates = {'drizzle', 'rain', 'storm', 'deluge', 'acid_rain', 'freezing_rain', 'hail', 'hurricane'};
  static const _snowClimates = {'snow', 'blizzard', 'veil_snow', 'frost', 'freezing_rain'};

  /// O clima de base que se vê agora (o primeiro da pilha), ou `clear` com o clima desligado nos Ajustes.
  String get _baseClimate => rainFx() ? climateShown().id.split('+').first : 'clear';

  void _paintCityGround(Canvas canvas, Size view, MapCamera cam, double mpc) {
    if (cityTiles.revision != _cityRevision) {
      _cityRevision = cityTiles.revision; // chegou bloco ou região: os blocos de chão saem de novo
      city.clear();
    }
    cityTiles.mpc = mpc;
    final cpt = visual.cellsPerTile;
    for (final (tx, ty) in cityTiles.takeRefreshed()) {
      city.invalidateArea(tx * cpt + 0.0, ty * cpt + 0.0, (tx + 1) * cpt + 0.0, (ty + 1) * cpt + 0.0); // chegaram os prédios do tile
    }
    city.paintGround(canvas, view, cam, dpr: dpr, artPixelDp: balance.artPixelDp, mpc: mpc, sunAltDeg: sunAltDeg, sunAzDeg: sunAzDeg, wet: _wetClimates.contains(_baseClimate), touching: follow.touching);
  }

  /// Prédios, árvores, postes e props de pé, e a faixa do céu. O telhado ou a copa sobre o Conjurador, um Eco, uma Fagulha ou
  /// um material fica translúcido (o jogo nunca some embaixo do cenário).
  void _paintCityUpright(Canvas canvas, Size view, MapCamera cam, double mpc, Offset? player, WorldView? wv) {
    final items = <Offset>[?player];
    if (wv != null && player != null) {
      for (final s in wv.spawns) {
        final (x, y) = cam.cellToScreen(s.x, s.y, view.width, view.height);
        if (x >= -20 && y >= -20 && x <= view.width + 20 && y <= view.height + 20) items.add(Offset(x, y));
      }
    }
    final local = DateTime.fromMillisecondsSinceEpoch((nowUtc() - 3 * 3600) * 1000, isUtc: true); // o fuso fixo do clima
    final base = _baseClimate;
    treeSways.removeWhere((_, t0) => _time - t0 >= kTreeSwayS);
    city.paintUpright(canvas, view, cam,
        dpr: dpr,
        artPixelDp: balance.artPixelDp,
        mpc: mpc,
        sunAltDeg: sunAltDeg,
        sunAzDeg: sunAzDeg,
        localHour: local.hour,
        month: local.month,
        snowRoofs: _snowClimates.contains(base),
        items: items,
        skyFraction: 0.06,
        skyClimate: base,
        sway: treeSways.isEmpty ? null : (x, y) => switch (treeSways[(x, y)]) { final t0? => treeSwayPx(_time - t0), null => 0.0 });
  }

  /// As árvores tocadas (0.24.3): o pé (células z21, o do prop) e quando, para a copa balançar. Só desenho.
  final treeSways = <(double, double), double>{};

  void swayTree(double x, double y) => treeSways[(x, y)] = _time;

  /// Debug (0.22.0): a câmera segue a peça do clima que anda.
  bool Function() followPiece = () => false;

  /// O centro da peça do clima ativa que anda mais perto do Conjurador (a que tem velocidade; senão a Procissão, o olhar ou
  /// o prédio da Maré), em células z21. `null`: nenhuma.
  (double, double)? _movingPiece() {
    if (!avatar.hasPosition) return null;
    final t = _exactUtc(), mpc = metersPerCell(_lat);
    (double, double)? best;
    var bestScore = double.infinity;
    for (final z in climateGround.zones) {
      if (!z.activeAt(t.floor())) continue;
      final style = climateCatalog.piece(z.piece.name).style;
      if (z.piece.speedMps <= 0 && !const {'figures', 'ghost', 'gaze'}.contains(style)) continue;
      final (x, y) = z.centerAt(t, mpc);
      final d = (x - avatar.x) * (x - avatar.x) + (y - avatar.y) * (y - avatar.y) + (z.piece.speedMps > 0 ? 0 : 1e4);
      if (d < bestScore) (best, bestScore) = ((x, y), d);
    }
    return best;
  }

  /// As camadas pintadas no último quadro, na ordem (debug e teste).
  final lastLayers = <MapLayer>[];

  /// O clima de agora: as camadas da tela (o que se vê) e, a cada meio segundo, os acontecimentos das peças em volta.
  void _updateClimate(double dt) {
    final reduce = reduceFlashes();
    _climate.reduceFlashes = reduce;
    climateFx.reduceFlashes = reduce;
    final c = worldView?.climate;
    final cam = follow.camera;
    if (c != null && avatar.hasPosition) {
      // O vento do mundo visto na tela: gira com o mapa.
      final (x0, y0) = cam.cellToScreen(avatar.x, avatar.y, 2, 2);
      final (x1, y1) = cam.cellToScreen(avatar.x + math.sin(c.windHeadingRad), avatar.y - math.cos(c.windHeadingRad), 2, 2);
      final d = math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
      if (d > 1e-9) _climate.wind = Offset((x1 - x0) / d, (y1 - y0) / d);
    }
    _climate.localHour = DateTime.fromMillisecondsSinceEpoch(nowUtc() * 1000).hour; // só desenho (a geada da manhã)
    _climate.update(dt, Size(size.x, size.y), climateShown(), enabled: rainFx());
    creatureWind.update(dt, rainFx() ? climateShown().windForce : 0);
    climateFx.update(dt);
    final cw = worldView?.field.climate;
    _climateIn -= dt;
    if (cw != null && _hasFix && avatar.hasPosition && _climateIn <= 0) {
      _climateIn = 0.5;
      final mpc = metersPerCell(_lat);
      climateFx.observe(cw, px: avatar.x, py: avatar.y, metersPerCell21: mpc, exactUtc: _exactUtc());
      climateGround.observe(cw, px: avatar.x, py: avatar.y, radius21: math.sqrt(size.x * size.x + size.y * size.y) / follow.pixelsPerCell, mpc: mpc, t: nowUtc());
      rainbow.observe(cw, px: avatar.x, py: avatar.y, radius21: math.sqrt(size.x * size.x + size.y * size.y) / follow.pixelsPerCell, metersPerCell21: mpc, t: nowUtc());
      if (c?.playerTrails ?? false) climateFx.noteStep(avatar.x, avatar.y, mpc);
    }
  }

  /// A camada do mapa do clima (ver `climate_ground.dart`), entre as ruas e os spawns.
  void _paintClimateGround(Canvas canvas, Size view, MapCamera cam, WorldView wv) => climateGround.paint(
        canvas,
        view,
        cam,
        mpc: metersPerCell(_lat),
        exactUtc: _exactUtc(),
        seed: wv.field.seed,
        shown: climateShown(),
        c: wv.climate,
        ecos: wv.spawns.where((s) => s.isEco).toList(),
        steps: climateFx.steps,
        playerX: avatar.x,
        playerY: avatar.y,
        night: light.night,
        localHour: _climate.localHour,
        sprites: sprites,
        ecoSizePx: ecoSizePx,
        decor: rainFx(),
        layered: true,
      );

  /// O Silêncio (clima de `traffic_mult` 0) vale aqui e agora: a simulação do tráfego não anda, e quando ele acaba todos
  /// continuam de onde pararam. Com o clima forçado pelo debug, a parada começa no instante em que ele foi forçado.
  bool _trafficPaused() {
    final t = _exactUtc(), cw = worldView?.field.climate;
    if (cw == null || !avatar.hasPosition) return false;
    final f = cw.forced();
    if (f != _forcedId) {
      _forcedId = f;
      _forcedAt = t;
    }
    final stop = cw.trafficStopAt(avatar.x, avatar.y, t, sinceUtc: f == null ? null : _forcedAt);
    return stop != null && t >= stop.s && t < stop.e;
  }

  String? _forcedId;
  double _forcedAt = 0;

  /// A Aura, o alcance de toque e os rastros: no chão, por baixo das criaturas.
  void _paintAura(Canvas canvas, Size view, MapCamera cam, Offset center) {
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
    if (overlayPuddles()) paintPuddleMarkers(canvas, view, cam, climateGround.puddles);
    if (w != null && (w.traces.isNotEmpty || w.distortions.isNotEmpty || w.pulse != null)) {
      _trace.paint(canvas, view, cam, world: w, playerX: avatar.x, playerY: avatar.y, metersPerCell: metersPerCell(_lat), exactUtc: _exactUtc());
    }
  }

  /// Os spawns de uma camada ([only]): criaturas, Fagulhas ou materiais.
  void _paintSpawns(Canvas canvas, Size view, MapCamera cam, WorldView w, Offset center, bool Function(WorldSpawn) only) => paintSpawns(
        canvas,
        view,
        cam,
        [for (final s in w.spawns) if (only(s)) _walked(s)],
        sprites: sprites,
        typeOf: typeOf,
        inAura: w.canReach,
        marked: (s) => w.state.markOf(s.uid) != null,
        pinned: w.isPinned,
        tintOf: variantTint,
        hopOf: (uid) => fx.hopOffset(uid, 8),
        appearOf: fx.appear,
        time: _time,
        avoid: markerRect(center, playerSizePx).inflate(6),
        spriteSize: ecoSizePx,
        spiritSize: spiritSizePx,
        sparkSize: sparkSizePx,
        dpr: dpr,
        artPixelDp: balance.artPixelDp,
        facingLeftOf: (uid) => (ecoFacing[uid]?.$1 ?? -1) > _time ? ecoFacing[uid]!.$2 : (_ecoMotion[uid]?.left ?? false),
        anchors: ecoAnchors,
        movingOf: (uid) => _ecoMotion[uid]?.moving ?? false,
        triggerOf: (s) => _triggerOf(s, cam, view),
        bodyTone: light.night > 0.004 ? Color.lerp(const Color(0xFFFFFFFF), const Color(0xFF3F4A8C), light.night) : null,
        emissive: _emissive,
        wind: creatureWind,
        windDir: _climate.wind,
        localWind: _localWindOf,
        pxPerM: cam.pixelsPerCell / metersPerCell(_lat),
      );

  /// O Familiar, o Conjurador (ou o carro do Modo Viagem) e o retorno visual.
  void _paintPlayer(Canvas canvas, Size view, MapCamera cam, Offset center) {
    final playerSize = playerSizePx;
    if (travelLayer?.hidesPlayer != true) {
      if (streetLifeEnabled) _paintFamiliar(canvas, cam, view);
      // Parado, o Conjurador respira: dois quadros, o segundo um pixel de arte mais alto.
      final breath = avatar.moving || ((_time / 0.7).floor() % 2 == 0) ? 0.0 : -balance.artPixelDp;
      // 0.24.5: na faixa de bicicleta ou de carro, o veículo equipado dela (só aparência), em volta do Conjurador parado.
      final veh = _vehicleStrips();
      final vframe = avatar.moving ? (_stepClock / (_stepS / 2)).floor() % 2 : 0;
      if (veh != null) paintPlayerVehicle(canvas, center, strip: veh.back, frame: vframe, size: playerSize, mirrored: _facingLeft, dpr: dpr, glow: veh.glow);
      paintPlayerMarker(canvas, veh == null ? center.translate(0, breath) : center, sprite: veh == null ? _playerFrame : playerFrames.firstOrNull, size: playerSize, mirrored: _facingLeft, dpr: dpr);
      if (veh != null) {
        paintPlayerVehicle(canvas, center, strip: veh.front, frame: vframe, size: playerSize, mirrored: _facingLeft, dpr: dpr, glow: veh.glow);
        if (veh.sparks && avatar.moving) paintVehicleSparks(canvas, center, size: playerSize, mirrored: _facingLeft, t: _time);
      }
      // O equipamento que lê no tamanho do sprite: a bolsa, as garrafas do cinto e o brilho do amuleto (Loadout).
      final art = UiArt.instance;
      final st = worldView?.state;
      if (art != null && st != null) {
        final g = avatarGear(st);
        paintPlayerGear(canvas, center.translate(0, breath), size: playerSize, mirrored: _facingLeft, dpr: dpr, layers: [
          if (g.bag)
            if (art.image('gear_bag') case final b?) (b, 0),
          for (var i = 0; i < g.bottles; i++)
            if (art.image('gear_bottle') case final b?) (b, b.width ~/ 8 * i), // 2 px na grade de 16, 3 px na de 24
          if (g.amuletGlow)
            if (art.image('gear_amulet_glow') case final b?) (b, 0),
        ]);
      }
    }
    travelLayer?.paintCar(canvas, view, cam, metersPerCell(_lat), utc: _exactUtc(), avatar: avatar);
    fx.paint(canvas, view, cam, avatar: center, playerSize: playerSize, sparkSize: sparkSizePx, dpr: dpr, anchorOf: (uid) => ecoAnchors[uid], ecoSize: ecoSizePx, emissive: _emissive, tone: light.night > 0.004 ? Color.lerp(const Color(0xFFFFFFFF), const Color(0xFF3F4A8C), light.night) : null);
  }

  /// 0.24.5: a faixa do modo trânsito agora (quem monta o mapa preenche). `null`: sempre a pé.
  RideBand Function()? rideBand;
  RideBand _band = RideBand.foot, _bandWant = RideBand.foot;
  double _bandWantSince = 0;

  /// As duas camadas do veículo da faixa de agora, ou `null` (a pé, nada equipado, escondido ou sem a arte). A faixa só
  /// troca depois de 1,5 s na faixa nova, para o GPS que oscila na borda não ficar trocando o desenho.
  ({ui.Image back, ui.Image front, double glow, bool sparks})? _vehicleStrips() {
    final want = rideBand?.call() ?? RideBand.foot;
    if (want != _bandWant) {
      _bandWant = want;
      _bandWantSince = _time;
    }
    if (want != _band && _time - _bandWantSince >= 1.5) _band = want;
    final st = worldView?.state, art = UiArt.instance;
    final key = st == null ? null : vehicleLook(st, _band);
    if (key == null || art == null) return null;
    final p = parseStack(key), name = 'veh_${p.id.split('.').last}';
    final back = art.image('${name}_back'), front = art.image('${name}_front');
    if (back == null || front == null) return null;
    return (back: back, front: front, glow: switch (p.q) { Quality.common => 0.0, Quality.good => 0.35, Quality.perfect => 0.6 }, sparks: p.q == Quality.perfect);
  }

  /// A luz do dia sobre o desenho do mapa: à noite escurece e esfria (multiplica por um azul profundo), no nascer e
  /// no pôr do sol esquenta um pouco. Cobre só o mapa; Aura, spawns e Conjurador vêm depois, sem escurecer.
  /// As ciclovias do arquivo `<região>_e0_cycle.bin` (fora das épocas e do pacote visual): uma linha fina e discreta, de um
  /// pixel de arte, na cor da paleta. A ciclofaixa numa rua fica mais apagada que a ciclovia própria.
  void _paintCycleways(Canvas canvas, Size view, MapCamera cam) {
    final pack = cycleways;
    if (pack == null) return;
    final (l, t, r, b) = cam.visibleBounds(view.width, view.height);
    final own = Path(), lane = Path();
    for (final line in pack.linesIn(l, t, r, b)) {
      final path = line.onRoad ? lane : own;
      for (var i = 0; i + 1 < line.xy.length; i += 2) {
        final (x, y) = cam.cellToScreen(line.xy[i], line.xy[i + 1], view.width, view.height);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = balance.artPixelDp
      ..isAntiAlias = false;
    canvas.drawPath(lane, paint..color = kCycleway.withValues(alpha: 0.3));
    canvas.drawPath(own, paint..color = kCycleway.withValues(alpha: 0.55));
  }

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
    // Sem a referência: o getter `city` (o debug ainda pode chamá-lo depois) não descarta as imagens uma segunda vez.
    _city?.dispose();
    _cityArt?.dispose();
    _city = null;
    _cityArt = null;
    compass.dispose();
    super.onRemove();
  }

  /// As vagas dos elementos do céu (lua, segunda lua, Sol Negro) no HUD (`HudLayout.sky`): fora de todas as zonas.
  Map<String, Rect> skyRects = const {};

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

  /// O vento na tela no lugar do spawn [s]: o do clima canalizado pela rua (época 10 em diante), ou o do clima.
  Offset _localWindOf(WorldSpawn s) {
    final wv = worldView, f = wv?.field.climate?.windFactorAt(s.x, s.y, nowUtc(), wv.climate.windHeadingRad);
    if (f == null || _climate.wind == Offset.zero) return _climate.wind;
    final r = follow.camera.rotation, c = math.cos(r), sn = math.sin(r);
    return Offset(f.$1 * c - f.$2 * sn, f.$1 * sn + f.$2 * c);
  }

  /// O spawn sob o toque em [screen], se houver: o mais perto dentro do raio de toque.
  /// Os coletores plantados (camada pessoal: só o dono vê), menores que o Conjurador (0.24.1): o sprite de mapa do
  /// recipiente (9 × 10 pixels de arte, base no ponto) sobre uma base de 9 pixels com o estado, cheio no ciano do sinal,
  /// enchendo no violeta do Véu, esperando apagado.
  void _paintCollectors(Canvas canvas, Size view, MapCamera cam, WorldView wv) {
    final planted = wv.state.crafting.at(VesselPlace.planted);
    if (planted.isEmpty) return;
    final px = playerSizePx / mapPlayerPx; // o pixel do Conjurador: 10 pixels de altura contra os 16 dele
    final plain = Paint()..filterQuality = FilterQuality.none;
    for (final v in planted) {
      final (cx, cy) = latLonToTileFraction(v.lat, v.lon, biomeZoom);
      final (sx, sy) = cam.cellToScreen(cx, cy, view.width, view.height);
      final x = (sx / px).roundToDouble() * px, y = (sy / px).roundToDouble() * px;
      final ring = Paint()..color = (v.content != null ? kSignal : (v.progressS > 0 ? kVeil : kDim)).withValues(alpha: 0.8);
      // A base: linhas de 7, 9 e 7 pixels, centrada no ponto.
      for (final (row, w) in [(-1, 7), (0, 9), (1, 7)]) {
        canvas.drawRect(Rect.fromLTWH(x - w * px / 2, y + row * px, w * px, px), ring);
      }
      final img = UiArt.instance?.image('map_${v.kind.replaceFirst('item.', '').replaceAll('.', '_')}');
      if (img == null) {
        canvas.drawRect(Rect.fromLTWH(x - 2 * px, y - 8 * px, 4 * px, 8 * px), plain..color = kSignal);
        continue;
      }
      // A última linha do sprite cai na linha do meio da base.
      final dst = Rect.fromLTWH(x - img.width * px / 2, y + px - img.height * px, img.width * px, img.height * px);
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, plain);
    }
  }

  /// As reações ao toque no mapa (0.24.2).
  final touchFx = TouchFxLayer();

  /// O relógio das animações (segundos desde que o mapa abriu).
  double get gameTime => _time;

  /// O jogador em células z21.
  double get playerX => latLonToTileFraction(_lat, _lon, biomeZoom).$1;
  double get playerY => latLonToTileFraction(_lat, _lon, biomeZoom).$2;

  /// Ecos virados para o Conjurador até um instante (a onda na poça): uid -> (até, olhando para a esquerda).
  final ecoFacing = <int, (double, bool)>{};

  /// Os bandos e gatos do tráfego (o toque espanta o bando e faz carinho no gato).
  BirdFlocks get flocks => _traffic.birds;

  /// 0.25.0: a camada emissiva das criaturas deste quadro (o pintor dos spawns junta, a camada `emissive` desenha).
  final _emissive = <void Function()>[];

  /// 0.25.0: se cada Eco está andando (a deriva) e para que lado olha na tela, pela posição dos últimos quadros.
  final _ecoMotion = <int, ({double x, double y, double t, bool moving, bool left})>{};

  /// 0.25.1: o gatilho de nascer de cada Eco, escolhido uma vez quando ele começa a aparecer (o clima e o poste daquele
  /// instante; o efeito não troca no meio).
  final _triggers = <int, SpawnTrigger?>{};

  (SpawnTrigger, Offset?)? _triggerOf(WorldSpawn s, MapCamera cam, Size view) {
    final spec = CreatureArt.of(s.entryId)?.spawn;
    if (spec == null) return null;
    if (_triggers.length > 300) _triggers.clear();
    final t = _triggers.putIfAbsent(
      s.uid,
      () => resolveSpawnTrigger(spec,
          climateId: climateShown().id,
          night: light.night > 0.5,
          climates: CreatureArt.triggerClimates,
          lamp: spec == 'lightning_lamp' ? _nearestProp(s.x, s.y, const {'lamp'}) : null,
          sign: spec == 'static_sign' ? _nearestProp(s.x, s.y, const {'street_sign', 'newsstand', 'bus_stop'}) : null,
          rainbow: rainbow.arcs.isNotEmpty,
          twilight: sunAltDeg.abs() < 6),
    );
    if (t == null) return null;
    final o = t.origin;
    if (o == null) return (t, null);
    final (x, y) = cam.cellToScreen(o.$1, o.$2, view.width, view.height);
    return (t, Offset(x, y - 4 * ecoSizePx / mapEcoPx)); // a cabeça do poste
  }

  /// O poste (ou o letreiro, a placa, a banca: [kinds]) mais perto de ([x], [y]) (células z21) até `lamp_m` do `index.json`.
  (double, double)? _nearestProp(double x, double y, Set<String> kinds) {
    final n = city.cellsPerTile, tx = (x / n).floor(), ty = (y / n).floor();
    return nearestPoint([
      for (var j = ty - 1; j <= ty + 1; j++)
        for (var i = tx - 1; i <= tx + 1; i++)
          for (final p in city.tileAt(i, j).props)
            if (kinds.contains(p.kind)) (p.x, p.y),
    ], x, y, CreatureArt.lampM / metersPerCell(_lat));
  }

  /// Para que lado o Eco [uid] olha agora na tela (a saída animada continua para o mesmo lado).
  bool facingLeftOfEco(int uid) => _ecoMotion[uid]?.left ?? false;

  /// 0.25.1: as criaturas do "Criar criatura" que andam (`walk`), no ponto do instante exato. Debug, só no desenho.
  (double, double)? Function(WorldSpawn s, double t, double metersPerCell21)? debugWalkAt;

  WorldSpawn _walked(WorldSpawn s) {
    if (debugWalkAt == null || !isDebugUid(s.uid)) return s;
    final p = debugWalkAt!(s, _exactUtc(), metersPerCell(_lat));
    return p == null ? s : s.movedTo(p.$1, p.$2);
  }

  void _trackEcoMotion(WorldView wv, MapCamera cam) {
    if (_ecoMotion.length > 600) _ecoMotion.clear();
    final r = cam.rotation, c = math.cos(r), s = math.sin(r);
    for (final e in wv.spawns.map(_walked)) {
      if (!e.isEco) continue;
      final last = _ecoMotion[e.uid];
      if (last == null) {
        _ecoMotion[e.uid] = (x: e.x, y: e.y, t: _time, moving: false, left: false);
        continue;
      }
      final dt = _time - last.t;
      if (dt < 0.25) continue;
      final dx = e.x - last.x, dy = e.y - last.y, moved = math.sqrt(dx * dx + dy * dy) * metersPerCell(_lat) / dt;
      final screenDx = dx * c - dy * s;
      _ecoMotion[e.uid] = (x: e.x, y: e.y, t: _time, moving: moved > 0.15, left: moved > 0.15 ? screenDx < 0 : last.left);
    }
  }

  /// 0.25.0: onde cada Eco foi desenhado por último (o centro do sprite, com o vento): os efeitos ancorados nele (anel da
  /// sintonia do NPC, o desfazer da fuga) se centram aqui.
  final ecoAnchors = <int, Offset>{};

  /// Debug (0.24.5): quase todo carro novo de avenida vira ônibus.
  bool Function() manyBuses = () => false;

  /// 0.24.5: os Outros Veilbreakers (quem monta o mapa preenche) e os números do Ônibus Espectral (`map_touch`).
  VeilbreakerField? veil;
  TouchBalance touchBalance = const TouchBalance();

  /// Os NPCs desenhados no último quadro (o toque procura neles).
  List<Veilbreaker> visibleVeilbreakers = const [];

  /// Os tiles z15 que a tela toca.
  List<CityTile> visibleTiles(Size view, MapCamera cam) {
    final corners = [for (final (x, y) in [(0.0, 0.0), (view.width, 0.0), (0.0, view.height), (view.width, view.height)]) cam.screenToCell(x, y, view.width, view.height)];
    final n = visual.cellsPerTile;
    final xs = corners.map((c) => c.$1), ys = corners.map((c) => c.$2);
    return [
      for (var ty = (ys.reduce(math.min) / n).floor(); ty <= (ys.reduce(math.max) / n).floor(); ty++)
        for (var tx = (xs.reduce(math.min) / n).floor(); tx <= (xs.reduce(math.max) / n).floor(); tx++) cityTiles.tileAt(tx, ty),
    ];
  }

  /// 0.24.5: o NPC desenhado sob [screen] (a até 36 px do corpo), ou `null`.
  Veilbreaker? npcAt(Offset screen) {
    if (size.x <= 0) return null;
    final cam = follow.camera, t = _exactUtc();
    Veilbreaker? best;
    var bd = 36.0;
    for (final n in visibleVeilbreakers) {
      if (!n.presentAt(t)) continue;
      final p = n.at(t);
      final (sx, sy) = cam.cellToScreen(p.x, p.y, size.x, size.y);
      final d = (Offset(sx, sy - playerSizePx / 2) - screen).distance;
      if (d < bd) (best, bd) = (n, d);
    }
    return best;
  }

  /// O objeto do mapa sob [screen] (ponto de ônibus, banca, árvore, poste, placa, bando, gato ou poça), ou `null`.
  TouchHit? touchAt(Offset screen, {Iterable<(double, double)> puddles = const []}) {
    if (size.x <= 0) return null;
    final view = Size(size.x, size.y);
    final cam = follow.camera;
    final corners = [for (final (x, y) in [(0.0, 0.0), (view.width, 0.0), (0.0, view.height), (view.width, view.height)]) cam.screenToCell(x, y, view.width, view.height)];
    final n = city.cellsPerTile;
    final xs = corners.map((c) => c.$1), ys = corners.map((c) => c.$2);
    final tiles = <CityTile>[
      for (var ty = (ys.reduce(math.min) / n).floor(); ty <= (ys.reduce(math.max) / n).floor(); ty++)
        for (var tx = (xs.reduce(math.min) / n).floor(); tx <= (xs.reduce(math.max) / n).floor(); tx++) city.tileAt(tx, ty),
    ];
    return touchHitAt(screen, view, cam, tiles: tiles, birds: _traffic.birds, puddles: puddles);
  }

  /// O coletor plantado desenhado em [screen], ou `null`.
  Vessel? collectorAt(Offset screen) {
    final w = worldView;
    if (w == null || size.x <= 0) return null;
    final cam = follow.camera;
    for (final v in w.state.crafting.at(VesselPlace.planted)) {
      final (cx, cy) = latLonToTileFraction(v.lat, v.lon, biomeZoom);
      final (sx, sy) = cam.cellToScreen(cx, cy, size.x, size.y);
      final px = playerSizePx / mapPlayerPx;
      if ((Offset(sx, sy - 4 * px) - screen).distance <= 8 * px + 12) return v; // sprite pequeno: folga de dedo
    }
    return null;
  }

  WorldSpawn? spawnAt(Offset screen) {
    final w = worldView;
    if (w == null || size.x <= 0) return null;
    final cam = follow.camera;
    WorldSpawn? best;
    var bestD = double.infinity;
    for (final s in w.spawns) {
      final (sx, sy) = cam.cellToScreen(s.x, s.y, size.x, size.y);
      // O toque vale onde o spawn está desenhado (o vento empurra os leves só no desenho).
      final push = _localWindOf(s) * (creatureWind.pushM(s, _time) * follow.pixelsPerCell / metersPerCell(_lat));
      final d = (Offset(sx, sy) + push - screen).distance;
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
ClimateInfo _clearInfo() => ClimateInfo.legacy(Weather.clear);

/// Debug: um alvo em cada poça na tela. Laranja: as da camada pessoal (Rill). Ciano: as do mundo (água do relevo, ou o
/// sorteio pela seed onde não há relevo). Devolve quantos alvos desenhou.
int paintPuddleMarkers(Canvas canvas, Size view, MapCamera cam, List<Puddle> puddles) {
  var n = 0;
  final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = 3..isAntiAlias = false;
  final fill = Paint()..isAntiAlias = false;
  for (final p in puddles) {
    final (x, y) = cam.cellToScreen(p.x, p.y, view.width, view.height);
    if (x < -20 || y < -20 || x > view.width + 20 || y > view.height + 20) continue;
    final c = Offset(x, y), color = p.personal ? kEssence : kSignal;
    canvas.drawCircle(c, 14, ring..color = kOutline..strokeWidth = 5);
    canvas.drawCircle(c, 14, ring..color = color..strokeWidth = 3);
    canvas.drawRect(Rect.fromCenter(center: c, width: 6, height: 6), fill..color = color);
    canvas.drawRect(Rect.fromLTWH(c.dx - 1.5, c.dy - 34, 3, 18), fill..color = color);
    n++;
  }
  return n;
}
