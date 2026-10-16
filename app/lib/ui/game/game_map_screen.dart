import 'dart:async';

import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/fnv.dart';
import '../../core/pcg32.dart';
import '../../core/tiles.dart';
import '../../core/weather.dart';
import '../../world/weather_source.dart';
import '../chime.dart';
import '../sprites/familiar_sprite.dart';
import '../../data/game_data.dart';
import '../../player/circle.dart';
import '../../player/game_state.dart' show GameState;
import '../../player/mark.dart';
import '../../player/progression.dart' show localDay;
import '../../dev/dev_tools.dart';
import '../../player/game_session.dart';
import '../../save/save_store.dart';
import '../../world/spawn_field.dart';
import '../../world/touch_gesture.dart';
import '../../world/world_view.dart';
import '../sprites/sprite_image.dart';
import '../tuning/vibration_driver.dart';
import '../../data/heading_source.dart';
import 'art_style.dart';
import 'compass_button.dart';
import 'encounter_flow.dart';
import '../../world/location_access.dart';
import '../../world/player_tracker.dart';
import '../../data/geolocator_source.dart';
import '../colors.dart';
import '../map/map_assets.dart';
import '../tuning/tuning_screen.dart' show PixelButton;
import '../menu/phone_menu.dart';
import '../menu/radar_screen.dart';
import '../../story/local_notifier.dart';
import '../../story/notification_plan.dart';
import '../settings/settings_screen.dart';
import 'game_map_game.dart';
import 'moon_hud.dart';
import 'player_hud.dart';
import 'sim_overlay.dart';

/// O mapa do jogo (M5): o Conjurador anda com o GPS e a câmera o segue, com a Aura no chão. A câmera
/// nunca sai do Conjurador: arrastar com um dedo gira o mapa e a pinça dá zoom numa faixa de jogo.
///
/// A posição vem de `tools.source`: o GPS real (pedindo a permissão com uma explicação curta) ou o
/// simulador do menu de debug, que entra no lugar sem o resto do código saber.
class GameMapScreen extends StatefulWidget {
  const GameMapScreen({required this.tools, this.gateway = const GeolocatorGateway(), this.bundle, this.store, this.openStore, this.vibration, this.headingSource, this.notifier, super.key});

  final DevTools tools;

  /// De onde vem a permissão de localização. Por padrão, o geolocator.
  final LocationGateway gateway;

  /// De onde vêm os assets. Por padrão, os do app.
  final AssetBundle? bundle;

  /// Onde o save mora. Sem ele (testes), o jogo vive só na memória.
  final SaveStore? store;

  /// Como abrir o save do disco, se não vier um [store]. Se falhar, o jogo vive só na memória.
  final Future<SaveStore> Function()? openStore;

  /// De onde vem o rumo do celular para o "seguir direção". Por padrão, a bússola do aparelho.
  final HeadingSource? headingSource;

  /// Quem agenda as notificações locais. Por padrão, o sistema do aparelho.
  final Notifier? notifier;

  /// Quem vibra na sintonia. Por padrão, o motor do aparelho.
  final VibrationPlayer? vibration;

  @override
  State<GameMapScreen> createState() => _GameMapScreenState();
}

class _Ready {
  _Ready(this.assets, this.game, this.tracker, this.sub, this.data, this.session, this.world);

  final GameData data;
  final GameSession session;
  final WorldView world;
  final MapAssets assets;
  final GameMapGame game;
  final PlayerTracker tracker;
  final StreamSubscription<PlayerState> sub;
}

class _GameMapScreenState extends State<GameMapScreen> with WidgetsBindingObserver {
  late final Future<Object> _loading = _load();
  _Ready? _ready;
  LocationAccess? _access;
  int _pointers = 0;
  StreamSubscription<double>? _headingSub;
  String? _toastText;
  Timer? _toastTimer;
  bool _busy = false;
  final _touch = TouchGesture();
  Timer? _longTimer;

  DevTools get tools => widget.tools;

  Future<SaveStore> _store() async {
    if (widget.store != null) return widget.store!;
    try {
      return await widget.openStore?.call() ?? MemorySaveStore();
    } catch (_) {
      return MemorySaveStore(); // sem pasta de documentos
    }
  }

  String _version = 'dev';

  WeatherService? _weather;
  Weather _shownWeather = Weather.clear;

  /// O clima determinístico (o da seed) numa posição: o que pesa nos spawns e o que se vê sem a rede.
  Weather _weatherAtLatLon(int seed, GameData data, double lat, double lon, int t) {
    final (cx, cy) = latLonToTile(lat, lon, 20);
    return _weatherOfCell(seed, data, cx, cy, t);
  }

  /// Atualiza o clima que se vê (HUD e chuva): o forçado pelo debug, ou o da rede se ligado, ou o determinístico.
  void _updateWeather() {
    final r = _ready, svc = _weather;
    if (r == null || svc == null) return;
    final now = tools.clock.nowUtc;
    final lat = r.game.playerLat, lon = r.game.playerLon;
    unawaited(svc.refresh(lat, lon, now));
    final next = tools.force.weather ?? svc.shown(lat, lon, now);
    if (next != _shownWeather) setState(() => _shownWeather = next);
  }

  /// A névoa de guerra: revela em volta do caminho andado (o do simulador vai para o conjunto de debug).
  void _revealFog(PlayerState s, GameState state, GameData data) {
    final p = s.position;
    if (p == null) return;
    final (x, y) = latLonToTileFraction(p.lat, p.lon, biomeZoom);
    state.revealFog(x, y, data.street.fogRevealRadiusM, metersPerCell(p.lat), debug: tools.useSimulator);
  }

  /// Um Eco Brilhante apareceu: som curto e aviso.
  void _onShiny(WorldSpawn eco) {
    unawaited(playChime());
    _toast('Um Eco Brilhante apareceu por perto!', seconds: 4);
  }

  /// O clima determinístico de uma célula (o que pesa nos spawns). O debug pode forçá-lo.
  Weather _weatherOfCell(int seed, GameData data, int cx, int cy, int t) {
    final forced = tools.force.weather;
    if (forced != null) return forced;
    // O modelo é o da época ATIVA naquele instante (nunca o da mais nova): o mundo de cada época é só dela.
    final model = data.schedule.select(t).epoch.ecoV2?.weather;
    if (model == null) return Weather.clear;
    final (rx, ry) = weatherRegionOfCell(cx, cy);
    return model.at(seed: seed, tUtc: t, regionX: rx, regionY: ry);
  }
  late final Notifier _notifier = widget.notifier ?? LocalNotifier();

  /// O mapa está sendo trocado por um novo: a tela nova já ligou o wake lock e esta não pode desligá-lo.
  bool _restarting = false;

  Timer? _storyTimer;
  bool _inBackground = false;
  double _walkedM = 0;

  /// O relógio do tutorial do mentor e a virada das diárias: um tique por segundo com o mapa aberto e o jogo à vista.
  void _storyTick() {
    final r = _ready;
    if (r == null || !mounted || _busy || _inBackground) return;
    final now = tools.clock.nowUtc;
    final st = r.session.state;
    st.ensureDaily(r.data.forum, r.data.schedule.select(now).epoch.id, localDay(now));
    st.tickChat(1, now, r.data.mentor);
    if (_weatherIn-- <= 0) {
      _weatherIn = 10;
      _updateWeather();
    }
  }

  int _weatherIn = 0;

  /// A caminhada conta de 10 em 10 metros, para não gravar o save a cada passo.
  void _onWalked(double meters) {
    _walkedM += meters;
    if (_walkedM < 10) return;
    final whole = _walkedM.floor();
    _walkedM -= whole;
    _ready?.session.state.recordEvent('walk_m', '', whole);
  }

  /// Recomeça o mapa com o save que está em disco: um backup importado ou outro grupo mudam a seed e tudo
  /// que depende dela.
  Future<void> _restart() async {
    if (!mounted) return;
    _restarting = true;
    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => GameMapScreen(
        tools: widget.tools,
        gateway: widget.gateway,
        bundle: widget.bundle,
        store: widget.store ?? _ready?.session.store,
        openStore: widget.openStore,
        vibration: widget.vibration,
        headingSource: widget.headingSource,
        notifier: widget.notifier,
      ),
    ));
  }

  SettingsScreen _settings(_Ready r) => SettingsScreen(
        session: r.session,
        data: r.data,
        nowUtc: () => tools.clock.nowUtc,
        realNowUtc: () => tools.clock.realNowUtc,
        appVersion: _version,
        cellSideM: () => 2 * metersPerCell(r.game.playerLat),
        followHeading: () => r.game.rotation.followHeading,
        onFollowHeading: (on) {
          if (r.game.rotation.followHeading != on) r.game.toggleFollowHeading();
        },
        onRestart: _restart,
        notifier: _notifier,
      );

  /// Ao sair do app, agenda os avisos de amanhã (se o jogador ligou): diárias renovadas e descanso cheio.
  void _scheduleNotifications() {
    final st = _ready?.session.state;
    if (st == null || !st.setting('notifications')) return;
    final plan = planNotifications(enabled: true, nowUtc: tools.clock.realNowUtc, progress: st.progress, balance: st.balance);
    unawaited(_notifier.apply(plan).catchError((_) {}));
  }

  /// Liga ou desliga a leitura da bússola do celular, só enquanto o "seguir direção" está ligado.
  void _setFollowHeading(bool on) {
    _ready?.session.state.setSetting('follow_heading', on);
    _headingSub?.cancel();
    _headingSub = null;
    final game = _ready?.game;
    if (!on || game == null) return;
    _headingSub = (widget.headingSource ?? const CompassHeadingSource()).headings.listen(game.setHeading);
  }

  /// Aviso curto no alto da tela ("+1 Pó de Essência de Fogo").
  void _toast(String message, {int seconds = 2}) {
    if (!mounted) return;
    _toastTimer?.cancel();
    setState(() => _toastText = message);
    _toastTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) setState(() => _toastText = null);
    });
  }

  void _pointerGone() {
    if (--_pointers <= 0) {
      _pointers = 0;
      _ready?.game.touchEnd();
    }
  }

  void _onLongTimer() {
    final at = _touch.longPress();
    if (at != null) _onLongPress(at);
  }

  /// Toque longo num Eco dentro da Aura: prende o sinal por alguns minutos. Num Eco já marcado, solta a marcação.
  void _onLongPress(Offset at) {
    final r = _ready;
    if (r == null || _busy) return;
    final eco = r.game.spawnAt(at);
    if (eco == null || !eco.isEco) return;
    final state = r.session.state;
    final now = tools.clock.nowUtc;
    if (state.markOf(eco.uid) != null) {
      state.removeMark(GameState.uidKey(eco.uid));
      _toast('Marcação solta');
    } else if (!r.world.inAura(eco)) {
      _toast('Entre na Aura para prender o sinal');
    } else if (state.addMark(Mark.of(eco, nowUtc: now, durationS: state.balance.markDurationS), now)) {
      HapticFeedback.mediumImpact();
      _toast('Sinal preso por ${state.balance.markDurationS ~/ 60} min');
    } else {
      _toast('Limite de ${state.balance.markMax} marcações. Solte uma com toque longo');
    }
  }

  /// Toque no mapa: o spawn sob o dedo. Material dentro da Aura é coletado; Eco dentro da Aura abre o
  /// encontro; o resto avisa o que falta.
  Future<void> _onTap(Offset at) async {
    final r = _ready;
    if (r == null || _busy) return;
    final spawn = r.game.spawnAt(at);
    if (spawn == null) return;
    switch (r.world.touch(spawn, tools.clock.nowUtc)) {
      case TouchResult.collected:
        break; // o aviso já saiu do WorldView
      case TouchResult.auto:
        _toast(r.world.canReach(spawn) ? 'A Aura pega sozinha' : 'Entre na Aura para pegar a Fagulha');
      case TouchResult.tooFar:
        _toast('Longe demais. Chegue com a Aura até lá (${r.world.distanceM(spawn).round()} m)');
      case TouchResult.encounter:
        await _startEncounter(spawn);
    }
  }

  /// Um Eco agressivo entrou na Aura: o celular vibra uma vez e a folha de preparo abre sozinha (dá para fechar).
  bool _onAggressive(WorldSpawn eco) {
    // Só com o mapa à vista: com o celular, a Bancada ou os Ajustes abertos a folha não pula por cima. A chance não se gasta.
    if (_busy || !mounted || ModalRoute.of(context)?.isCurrent != true) return false;
    HapticFeedback.heavyImpact();
    unawaited(_startEncounter(eco));
    return true;
  }

  /// Abre o encontro com [spawn]: a folha de selo e a sintonia.
  Future<void> _startEncounter(WorldSpawn spawn) async {
    final r = _ready;
    if (r == null || _busy) return;
    _busy = true;
    try {
      await runEncounter(context, eco: spawn, world: r.world, state: r.session.state, data: r.data, nowUtc: () => tools.clock.nowUtc, vibration: widget.vibration, onMessage: _toast);
    } finally {
      _busy = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A tela fica acesa enquanto o mapa está aberto: o jogo anda a pé, com o celular na mão e sem tocar.
    unawaited(WakelockPlus.enable().catchError((_) {})); // sem o plugin (testes) não há o que ligar
    tools.addListener(_rebuild);
    tools.clock.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<Object> _load() async {
    final dpr = View.of(context).devicePixelRatio;
    final result = await loadMapAssets(nowUtc: tools.clock.nowUtc, bundle: widget.bundle, withVisual: true);
    if (result is String) return result;
    final assets = result as MapAssets;
    final GameData data;
    final GameSession session;
    final sprites = <String, ui.Image>{};
    final List<ui.Image> playerFrames;
    final ui.Image familiar;
    try {
      data = await GameData.load(widget.bundle);
      playerFrames = await loadPlayerFramesMap();
      familiar = await loadFamiliarImage();
      for (final s in data.tuning.species) {
        sprites[s.id] = (await EcoSprite.loadMap(s.id)).normal;
      }
      var version = _version;
      try {
        final info = await PackageInfo.fromPlatform();
        version = _version = '${info.version}+${info.buildNumber}';
      } catch (_) {
        // sem o plugin (testes): a versão fica 'dev'
      }
      session = await GameSession.open(
        store: await _store(),
        startInventory: data.startInventory,
        balance: data.progress,
        nowUtc: () => tools.clock.nowUtc,
        seenUtc: () => tools.clock.realNowUtc,
        appVersion: version,
        epochOf: (t) => data.schedule.select(t).epoch.id,
        nextInt: Pcg32(fnv1a64([DateTime.now().microsecondsSinceEpoch]), saltKenoma).nextInt, // só sorteia o código do grupo
      );
    } catch (e) {
      assets.dispose();
      return 'Não consegui ler os dados do jogo: $e';
    }
    tools.clock.raiseFloor(session.state.lastSeenUtc);
    session.onSeen = tools.clock.raiseFloor;
    final world = WorldView(
      field: SpawnField(
        seed: session.state.seed,
        schedule: data.schedule,
        map: assets.map,
        typeOf: (id) => data.species(id)?.type.name,
        weatherAt: (cx, cy, t) => _weatherOfCell(session.state.seed, data, cx, cy, t),
      ),
      state: session.state,
      street: data.street,
      force: tools.force,
      typeOf: (id) => data.species(id)?.type.name,
      auraM: assets.balance.auraM,
      viewM: assets.balance.viewM,
      trackerM: assets.balance.trackerM,
      abilities: () => abilitiesOf(session.state, data),
      itemName: data.itemName,
      onMessage: _toast,
    );
    final game = GameMapGame(
      renderer: assets.makeRenderer(),
      visual: assets.visual!,
      style: ArtStyle(assets.biomes),
      balance: assets.balance,
      playerFrames: playerFrames,
      overlayBiomes: () => tools.showBiomeGrid,
      overlayGrid20: () => tools.showGrid20,
      auraM: assets.balance.auraM,
      defaultWidthM: assets.balance.defaultWidthM,
      minWidthM: assets.balance.cameraMinWidthM,
      maxWidthM: assets.balance.cameraMaxWidthM,
      sparkSizeM: assets.balance.sparkSizeM,
      trackerM: assets.balance.trackerM,
      trackerMax: assets.balance.trackerMax,
      declinationDeg: assets.balance.compassDeclinationDeg,
      dpr: dpr,
      worldView: world,
      streetNames: () => session.state.setting('street_names'),
      veilTraffic: () => session.state.settingOr('veil_traffic', true),
      rainFx: () => session.state.settingOr('rain_fx', true),
      weatherShown: () => _shownWeather,
      variantTint: (s) => data.variantInfo(biome: s.variant, shiny: s.shiny)?.tint,
      familiarImage: familiar,
      rainDrops: data.street.rainParticles,
      familiarOffsetM: data.street.familiarFollowOffsetM,
      sprites: sprites,
      typeOf: (id) => data.species(id)?.type,
      nowUtc: () => tools.clock.nowUtc,
    );
    final tracker = PlayerTracker(source: tools.source);
    final sub = tracker.states.listen((s) {
      game.onPlayerState(s);
      _revealFog(s, session.state, data);
      _rebuild();
    });
    game.onFollowHeading = _setFollowHeading;
    game.onWalked = _onWalked;
    world.onAggressive = _onAggressive;
    world.onShiny = _onShiny;
    _weather = WeatherService(
      deterministic: (lat, lon, t) => _weatherAtLatLon(session.state.seed, data, lat, lon, t),
      source: OpenMeteoSource(),
      online: () => session.state.setting('weather_online'),
    );
    session.state.onNotice = _toast;
    session.state.ensureDaily(data.forum, data.schedule.select(tools.clock.nowUtc).epoch.id, localDay(tools.clock.nowUtc));
    _storyTimer = Timer.periodic(const Duration(seconds: 1), (_) => _storyTick());
    if (session.state.setting('follow_heading')) {
      game.rotation.toggleFollowHeading(); // volta ao modo que o jogador deixou ligado
      WidgetsBinding.instance.addPostFrameCallback((_) => _setFollowHeading(true));
    }
    _ready = _Ready(assets, game, tracker, sub, data, session, world);
    // O acesso é pedido depois do primeiro quadro: o diálogo precisa de uma tela montada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final note = session.loadNote;
      if (note != null) _toast(note, seconds: 8);
      _ensureAccess();
    });
    return _ready!;
  }

  /// Garante a permissão (explicando antes) e liga a fonte. O simulador não precisa de permissão.
  Future<void> _ensureAccess() async {
    final ready = _ready;
    if (ready == null || !mounted) return;
    if (tools.useSimulator) {
      setState(() => _access = LocationAccess.granted);
      await ready.tracker.start();
      return;
    }
    final access = await LocationAccessFlow(widget.gateway).ensure(explain: _explain);
    if (!mounted) return;
    setState(() => _access = access);
    if (access == LocationAccess.granted) await ready.tracker.start();
  }

  Future<bool> _explain() async {
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: kPanel,
        shape: const RoundedRectangleBorder(side: BorderSide(color: kVeil, width: 3)),
        title: const Text('LOCALIZAÇÃO', style: TextStyle(fontSize: 16, color: kVeil)),
        content: const Text(kLocationRationale, style: TextStyle(fontSize: 8, color: kText, height: 1.8)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('AGORA NÃO', style: TextStyle(fontSize: 8, color: kDim))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('CONTINUAR', style: TextStyle(fontSize: 8, color: kSignal))),
        ],
      ),
    );
    return go ?? false;
  }

  /// Troca entre o GPS real e o simulador com o mapa aberto: o marcador some até a primeira leitura boa
  /// da nova fonte, e o acesso é conferido de novo.
  Future<void> _switchSource(bool simulator) async {
    final ready = _ready;
    if (ready == null) return;
    await ready.tracker.stop();
    await tools.setUseSimulator(simulator);
    ready.tracker.reset();
    ready.game.clearPlayer();
    await _ensureAccess();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ready = _ready;
    if (ready == null) return;
    _inBackground = state != AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused) _scheduleNotifications();
    if (state == AppLifecycleState.paused) {
      _headingSub?.cancel(); // a bússola também só com o app aberto
      _headingSub = null;
      ready.tracker.stop(); // só com o app aberto
    } else if (state == AppLifecycleState.resumed) {
      _ensureAccess(); // o jogador pode ter mexido nos ajustes
      if (ready.game.rotation.followHeading) _setFollowHeading(true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_restarting) unawaited(WakelockPlus.disable().catchError((_) {}));
    tools.removeListener(_rebuild);
    tools.clock.removeListener(_rebuild);
    final r = _ready;
    if (r != null) {
      r.sub.cancel();
      r.tracker.dispose();
      r.assets.dispose();
      r.session.dispose();
    }
    _toastTimer?.cancel();
    _longTimer?.cancel();
    _storyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOutline,
      body: FutureBuilder<Object>(
        future: _loading,
        builder: (context, snap) {
          if (snap.hasError) return _ErrorPanel(message: 'Erro ao abrir o mapa: ${snap.error}');
          final data = snap.data;
          if (data == null) return const Center(child: Text('Carregando mapa...', style: TextStyle(fontSize: 16, color: kDim)));
          if (data is String) return _ErrorPanel(message: data);
          return _view(data as _Ready);
        },
      ),
    );
  }

  Widget _view(_Ready r) {
    final game = r.game;
    game.bottomInset = MediaQuery.paddingOf(context).bottom;
    final blocked = _access != null && _access != LocationAccess.granted && !tools.useSimulator;
    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            if (_pointers++ == 0) game.touchStart();
            _touch.down(e.localPosition, e.timeStamp.inMilliseconds);
            _longTimer?.cancel();
            if (_touch.pendingLongPress) _longTimer = Timer(Duration(milliseconds: _touch.longPressMs), _onLongTimer);
          },
          onPointerMove: (e) {
            final turn = _touch.move(e.localPosition, center: game.screenCenter);
            if (turn != 0) game.dragRotate(turn);
            if (_touch.dragging) _longTimer?.cancel();
          },
          onPointerUp: (e) {
            _longTimer?.cancel();
            final tap = _touch.up(e.localPosition, e.timeStamp.inMilliseconds);
            if (tap != null) _onTap(tap);
            _pointerGone();
          },
          onPointerCancel: (_) {
            _longTimer?.cancel();
            _touch.cancel();
            _pointerGone();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => game.gestureStart(),
            onScaleUpdate: (d) {
              if (d.pointerCount >= 2) game.pinch(d.scale);
            },
            child: GameWidget(game: game),
          ),
        ),
        SafeArea(
          child: Stack(
            children: [
              Padding(padding: const EdgeInsets.only(bottom: 90), child: _StatusHud(state: r.tracker.state, tools: tools, stale: r.assets.stale)),
              if (tools.useSimulator) SimOverlay(tools: tools),
              Positioned(
                left: 0,
                top: 0,
                width: 48,
                height: 48,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: const Center(child: Text('<', style: TextStyle(fontSize: 24, color: kText))),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _switchSource(!tools.useSimulator),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.85), border: Border.all(color: kSignal, width: 2)),
                    child: Text(tools.useSimulator ? 'SIMULADOR' : 'GPS REAL', style: const TextStyle(fontSize: 8, color: kSignal)),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 56,
                child: MoonHud(nowUtc: () => tools.clock.nowUtc, lat: () => game.playerLat, weather: () => _shownWeather),
              ),
              Positioned(
                left: 8,
                top: 56,
                child: MarkChips(
                  state: r.session.state,
                  nowUtc: () => tools.clock.nowUtc,
                  sprites: game.sprites,
                  onTap: (m) => _startEncounter(m.toSpawn()),
                ),
              ),
              Positioned(left: 8, bottom: 8, child: PortraitHud(state: r.session.state, frame: game.playerFrames.isEmpty ? null : game.playerFrames.first)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Center(
                  child: ListenableBuilder(
                    listenable: r.session.state,
                    builder: (context, _) => PhoneButton(
                      alert: phoneHasAlert(r.session.state),
                      onTap: () => showPhoneMenu(
                        context,
                        state: r.session.state,
                        data: r.data,
                        settings: () => _settings(r),
                        radar: () => RadarScreen(
                          state: r.session.state,
                          street: r.data.street,
                          nowUtc: () => tools.clock.nowUtc,
                          onSweep: () => r.world.radar(tools.clock.nowUtc),
                        ),
                        nowUtc: () => tools.clock.nowUtc,
                        epochId: () => r.data.schedule.select(tools.clock.nowUtc).epoch.id,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 56,
                left: 0,
                right: 0,
                child: Center(
                  child: ValueListenableBuilder(
                    valueListenable: game.compass,
                    builder: (context, c, _) => c.visible
                        ? CompassButton(angle: c.angle, follow: c.follow, onNorth: game.goNorth, onToggleFollow: game.toggleFollowHeading)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              if (_toastText != null)
                Positioned(
                  left: 56,
                  right: 120,
                  top: 12,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.9), border: Border.all(color: kEssence, width: 2)),
                      child: Text(_toastText!.toUpperCase(), style: const TextStyle(fontSize: 8, color: kText, height: 1.6)),
                    ),
                  ),
                ),
              if (blocked) _AccessPanel(access: _access!, gateway: widget.gateway, onRetry: _ensureAccess, onSimulator: () => _switchSource(true)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('MAPA INDISPONÍVEL', style: TextStyle(fontSize: 24, color: kEssence)),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
              const SizedBox(height: 24),
              PixelButton(label: 'Voltar', color: kVeil, onTap: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      );
}

/// Painel quando a localização não está liberada: diz o que houve e o que fazer.
class _AccessPanel extends StatelessWidget {
  const _AccessPanel({required this.access, required this.gateway, required this.onRetry, required this.onSimulator});

  final LocationAccess access;
  final LocationGateway gateway;
  final VoidCallback onRetry;
  final VoidCallback onSimulator;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.94), border: Border.all(color: kEssence, width: 3)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('SEM LOCALIZAÇÃO', style: TextStyle(fontSize: 16, color: kEssence)),
            const SizedBox(height: 12),
            Text(locationAccessMessage(access), style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
            const SizedBox(height: 16),
            switch (access) {
              LocationAccess.deniedForever => PixelButton(label: 'Abrir ajustes', color: kSignal, onTap: gateway.openAppSettings),
              LocationAccess.serviceOff => PixelButton(label: 'Ligar GPS', color: kSignal, onTap: gateway.openLocationSettings),
              _ => PixelButton(label: 'Tentar de novo', color: kSignal, onTap: onRetry),
            },
            const SizedBox(height: 8),
            PixelButton(label: 'Usar simulador', color: kVeil, onTap: onSimulator),
          ],
        ),
      ),
    );
  }
}

/// O que o jogador vê embaixo: de onde vem a posição, como está o sinal e as coordenadas.
class _StatusHud extends StatelessWidget {
  const _StatusHud({required this.state, required this.tools, required this.stale});

  final PlayerState state;
  final DevTools tools;
  final bool stale;

  String _line() {
    final p = state.position;
    switch (state.status) {
      case TrackingStatus.searching:
        return 'PROCURANDO ${tools.useSimulator ? 'SIMULADOR' : 'GPS'}...';
      case TrackingStatus.poorAccuracy:
        final raw = state.lastRaw?.accuracyM.toStringAsFixed(0) ?? '?';
        return 'PRECISÃO RUIM ±$raw M · PRECISA DE 50 M OU MENOS';
      case TrackingStatus.tracking:
        return 'SEGUINDO · ±${p!.accuracyM.toStringAsFixed(0)} M${p.moving ? ' · ANDANDO' : ''}';
    }
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 8, color: kText, height: 1.6);
    final p = state.position;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.88), border: Border.all(color: kPanelLine, width: 2)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stale) const Text('MUNDO DESATUALIZADO', style: TextStyle(fontSize: 8, color: kEssence, height: 1.6)),
            if (tools.clock.overridden)
              Text('RELÓGIO UTC ${_utc(tools.clock.now)} (OVERRIDE)', style: const TextStyle(fontSize: 8, color: kEssence, height: 1.6)),
            Text(_line(), style: style.copyWith(color: state.status == TrackingStatus.tracking ? kSignal : kDim)),
            if (p != null) Text('${p.lat.toStringAsFixed(5)}, ${p.lon.toStringAsFixed(5)}', style: style),
          ],
        ),
      ),
    );
  }

  static String _utc(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
