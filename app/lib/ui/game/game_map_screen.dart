import '../../dev/tap_latency.dart';
import '../../core/features.dart';
import 'dart:async';

import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/fnv.dart';
import '../../core/pcg32.dart';
import '../../core/tiles.dart';
import '../../core/weather.dart';
import '../../core/astro.dart' show moonPhase;
import '../../core/species_ids.dart' show isRitualOnlyId;
import '../../crafting/ritual_data.dart';
import '../ritual/ritual_screen.dart';
import '../../net/region_catalog.dart' show RegionEntry;
import '../../world/climate_form.dart';
import '../../world/layered_world.dart';
import '../../world/map_layers.dart';
import '../../data/climate_catalog.dart';
import '../flashes.dart';
import 'climate_driver.dart';
import '../chime.dart';
import '../sprites/familiar_sprite.dart';
import '../../data/game_data.dart';
import '../../player/game_state.dart' show GameState;
import '../../player/conjurer_balance.dart' show School;
import '../../player/mark.dart';
import '../../player/progression.dart' show localDay;
import '../../dev/dev_tools.dart';
import '../../player/game_session.dart';
import '../../save/fresh_start.dart';
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
import '../menu/phone_shell.dart';
import '../menu/profile_screen.dart';
import '../menu/phone_apps.dart';
import '../menu/radar_screen.dart';
import '../menu/sky_screen.dart';
import '../patrol/patrol_screen.dart';
import '../travel/routes_screen.dart';
import '../../travel/ride.dart' show RideState;
import '../../world/sky_outlook.dart';
import '../../story/local_notifier.dart';
import '../../story/notification_plan.dart';
import '../settings/regions_section.dart' show regionSizeLabel;
import '../../travel/travel_path.dart' show accessTest, bridgeTest, highwayTest;
import '../../travel/system_bridge.dart';
import '../../travel/travel_session.dart';
import '../settings/ride_notifications_screen.dart' show kRideNotifySetting;
import '../travel/travel_layer.dart';
import '../travel/travel_overlay.dart';
import '../settings/settings_screen.dart';
import 'game_map_game.dart';
import 'hud_bar.dart';
import 'hud_layout.dart';
import 'joystick.dart';
import 'player_hud.dart';
import 'pocket_overlay.dart';
import 'sim_overlay.dart';
import '../settings/connectivity_section.dart' show kPocketSetting, kStepsSetting;
import '../../world/device_sensors.dart';
import '../../world/pocket_mode.dart';
import '../../world/steps.dart';
import '../../world/traffic_graph.dart';
import '../../patrol/patrol_controller.dart';
import '../patrol/patrol_hooks.dart';

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
  _Ready(this.assets, this.game, this.tracker, this.sub, this.data, this.session, this.world, this.layers, this.travel);

  final GameData data;
  final GameSession session;
  final WorldView world;
  final MapAssets assets;
  final GameMapGame game;
  final PlayerTracker tracker;
  final StreamSubscription<PlayerState> sub;
  final MapLayers layers;
  final TravelSession travel;
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

  /// O clima: o do mundo (peças, pesos de spawn) e o que se vê (HUD e desenho). Ver `climate_driver.dart`.
  ClimateDriver? _climate;

  /// Atualiza o clima que se vê: o forçado pelo debug, ou o da rede se ligado, ou o determinístico.
  void _updateWeather() {
    final r = _ready, c = _climate;
    if (r == null || c == null) return;
    reduceFlashes.value = r.session.state.setting(kReduceFlashesSetting);
    soundOn.value = r.session.state.settingOr(kSoundSetting, true);
    final u = c.update(r.game.playerLat, r.game.playerLon, tools.clock.nowUtc);
    if (u.changed) setState(() {});
    if (u.notice != null) _toast(u.notice!, seconds: 5);
  }

  /// As células z17 visitadas: só o caminho real, sem o simulador e sem dirigir.
  void _markVisited(PlayerState s, GameState state) {
    final p = s.position;
    if (p == null || tools.useSimulator || (_ready?.travel.driver ?? false)) return;
    final (x, y) = latLonToTile(p.lat, p.lon, visitedZoom);
    state.markVisited(x, y);
  }

  /// O bioma da última posição conhecida, para o contador de passos (só com ele ligado).
  void _rememberBiome(PlayerState s, GameState state, MapAssets assets) {
    final p = s.position;
    if (p == null || !state.setting(kStepsSetting)) return;
    try {
      state.setSetting('last_biome', assets.map.biomes.spawnKey(assets.map.spawnBiomeAtLatLon(p.lat, p.lon)));
    } catch (_) {}
  }

  /// A chave do bioma em (lat, lon), ou `null` fora do pacote.
  String? _biomeKeyAt(MapAssets assets, double lat, double lon) {
    try {
      return assets.map.biomes.spawnKey(assets.map.spawnBiomeAtLatLon(lat, lon));
    } catch (_) {
      return null;
    }
  }

  /// Um Eco Brilhante apareceu: som curto e aviso.
  void _onShiny(WorldSpawn eco) {
    unawaited(playChime());
    _toast('Um Eco Brilhante apareceu por perto!', seconds: 4);
  }

  late final Notifier _notifier = widget.notifier ?? LocalNotifier();

  /// O mapa está sendo trocado por um novo: a tela nova já ligou o wake lock e esta não pode desligá-lo.
  bool _restarting = false;

  Timer? _storyTimer;

  /// Trovões esperando o som chegar (cancelados ao fechar o mapa).
  final _thunders = <Timer>[];

  /// O trovão chega com o atraso do som pela distância.
  void _scheduleThunder(double distanceM) => _thunders
    ..removeWhere((t) => !t.isActive)
    ..add(Timer(thunderDelay(distanceM), () => unawaited(playThunder(distanceM))));
  bool _inBackground = false;
  double _walkedM = 0;

  /// O relógio do tutorial do mentor e a virada das diárias: um tique por segundo com o mapa aberto e o jogo à vista.
  void _storyTick() {
    final r = _ready;
    if (r != null) r.travel.tick(speedMps: r.game.avatar.speedMps);
    if (r == null || !mounted || _busy || _inBackground) return;
    final now = tools.clock.nowUtc;
    final st = r.session.state;
    st.ensureDaily(r.data.forum, r.data.schedule.select(now).epoch.id, localDay(now));
    st.tickChat(1, now, r.data.mentor);
    _tickLayers(r, st);
    _optionalSensors(r, st, now);
    _patrol?.tick();
    _radioTick(r, now);
    if (_weatherIn-- <= 0 || tools.force.simulating) {
      _weatherIn = 10;
      _updateWeather();
      if (tools.force.simulating) setState(() {}); // a fase da simulação nos avisos
    }
  }

  String? _radioSaid;

  /// O Rádio do Véu mora no app Rotas; no mapa, cada fala nova sai uma vez no aviso.
  void _radioTick(_Ready r, int now) {
    final line = r.travel.radioLine(now)?.text;
    if (line == null || line == _radioSaid) return;
    _radioSaid = line;
    _toast('Rádio do Véu: $line', seconds: 6);
  }

  /// Um passo das camadas do mapa. Na primeira vez no piso, o Familiar comenta (o `setting` não deixa repetir).
  void _tickLayers(_Ready r, GameState st) {
    if (!r.game.avatar.hasPosition) return;
    unawaited(r.layers.tick(r.game.playerLat, r.game.playerLon));
    if (r.layers.source.value == MapSourceKind.floor && !st.setting(kFloorSeenSetting)) {
      st.setSetting(kFloorSeenSetting, true);
      st.recordEvent(kFloorSeenEvent, '', 1);
    }
  }

  /// O aviso de tamanho antes de baixar uma região grande.
  Future<bool> _confirmRegion(RegionEntry region, int bytes) async {
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kPanel,
        shape: const RoundedRectangleBorder(side: BorderSide(color: kSignal, width: 3)),
        title: Text('BAIXAR ${region.name.toUpperCase()}?', style: const TextStyle(fontSize: 16, color: kSignal)),
        content: Text('O mapa da região ocupa ${regionSizeLabel(bytes)}. Vale usar Wi-Fi.', style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('AGORA NÃO', style: TextStyle(fontSize: 8, color: kDim))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('BAIXAR', style: TextStyle(fontSize: 8, color: kSignal))),
        ],
      ),
    );
    return ok ?? false;
  }

  int _weatherIn = 0;

  // Opcionais dos Ajustes (desligados por padrão): modo bolso e contador de passos. Falham em silêncio.
  final _pocket = PocketMode();
  StreamSubscription<bool>? _proxSub;
  int _stepsIn = 0;

  void _optionalSensors(_Ready r, GameState st, int now) {
    try {
      final pocketOn = st.setting(kPocketSetting) || PatrolController.instance.running; // com a Patrulha, o bolso vem junto
      if (pocketOn && _proxSub == null) {
        _proxSub = const DeviceSensors().proximity().listen(_pocket.onProximity, onError: (_) {});
      } else if (!pocketOn && _proxSub != null) {
        _stopProximity();
      }
      if (st.setting(kStepsSetting) && _stepsIn-- <= 0) {
        _stepsIn = 30;
        final tracker = StepTracker(state: st, balance: r.data.steps, read: const DeviceSensors().readSteps, nowUtc: () => tools.clock.nowUtc);
        unawaited(tracker.sync(r.data.schedule.select(now).epoch).then((n) {
          if (n > 0 && mounted) _toast('+$n ${n == 1 ? 'Fagulha' : 'Fagulhas'} pelos seus passos');
        }));
      }
    } catch (_) {
      // sensores são opcionais
    }
  }

  PatrolHooks? _patrol;

  /// Bolso coberto com a Patrulha ligada: o serviço joga, então o mapa para de desenhar (taxa de quadros mínima). Destapar
  /// volta. Sem a Patrulha o mapa continua: é ele quem coleta.
  void _pocketFps() {
    final game = _ready?.game;
    if (game == null) return;
    final low = _pocket.covered && PatrolController.instance.running;
    game.setPocket(low); // o clima desenha poucas partículas no bolso
    if (low && !game.paused) game.pauseEngine();
    if (!low && game.paused) game.resumeEngine();
  }

  void _stopProximity() {
    _proxSub?.cancel();
    _proxSub = null;
    _pocket.reset();
  }

  /// Um Eco entrou no alcance de toque: com o modo bolso ligado e o sensor coberto, uma vibração curta.
  void _onEnteredRange(WorldSpawn eco) {
    final on = _ready?.session.state.setting(kPocketSetting) ?? false;
    if (!shouldBuzz(enabled: on, covered: _pocket.covered)) return;
    try {
      unawaited(Vibration.vibrate(duration: 120).catchError((_) {}));
    } catch (_) {}
  }

  /// A caminhada conta de 10 em 10 metros, para não gravar o save a cada passo.
  void _onWalked(double meters) {
    if ((_ready?.travel.quiet ?? false) || PatrolController.instance.running || tools.sandboxed) return; // de carro não é caminhada; na Patrulha, o diário conta; simulado não conta
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
    final own = ModalRoute.of(context);
    Navigator.of(context).popUntil((r) => r == own || r.isFirst); // os Ajustes e o que estiver por cima saem: o mapa novo entra no lugar deste
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

  /// Recomeçar do zero (Ajustes): apaga o progresso, mantém a identidade e reabre o mapa como numa instalação nova.
  Future<void> _freshStart(_Ready r) async {
    await (await FreshStart.onDevice(r.session.store, stopPatrol: _stopPatrol)).run(r.session, tools.clock.realNowUtc);
    await _restart();
  }

  /// Gancho da Patrulha do Véu: encerra o serviço antes de o recomeço apagar o diário.
  Future<void> _stopPatrol() => stopPatrol();

  SettingsScreen _settings(_Ready r) => SettingsScreen(
        session: r.session,
        data: r.data,
        nowUtc: () => tools.clock.nowUtc,
        realNowUtc: () => tools.clock.realNowUtc,
        appVersion: _version,
        followHeading: () => r.game.rotation.followHeading,
        onFollowHeading: (on) {
          if (r.game.rotation.followHeading != on) r.game.toggleFollowHeading();
        },
        onRestart: _restart,
        onFreshStart: () => _freshStart(r),
        notifier: _notifier,
        regions: r.layers.regions,
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
    if (r == null || _busy || r.travel.quiet) return;
    final eco = r.game.spawnAt(at);
    if (eco == null || !eco.isEco) return;
    final state = r.session.state;
    final now = tools.clock.nowUtc;
    if (state.markOf(eco.uid) != null) {
      state.removeMark(GameState.uidKey(eco.uid));
      _toast('Marcação solta');
    } else if (!r.world.inTouchRange(eco)) {
      _toast('Longe demais para prender o sinal (a ${r.world.distanceM(eco).round()} m)');
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
    final (cellX, cellY) = r.game.cellAt(at);
    final fx = tools.force.takeTapEffect(); // debug: o efeito de clima escolhido acontece onde o dedo tocou
    if (fx != null) {
      if (!(_climate?.world.debugTrigger(fx, cellX, cellY, tools.clock.nowUtc) ?? false)) _toast('Nenhum clima tem o efeito $fx');
      return;
    }
    if (r.travel.tapCell(cellX, cellY) || r.travel.quiet) return; // escolheu o destino, ou o mundo está calado
    final spawn = r.game.spawnAt(at);
    if (spawn == null) return;
    switch (r.world.touch(spawn, tools.clock.nowUtc)) {
      case TouchResult.collected:
        break; // o aviso já saiu do WorldView
      case TouchResult.auto:
        _toast(r.world.canReach(spawn) ? 'A Aura pega sozinha' : 'Entre na Aura para pegar a Fagulha (a ${r.world.distanceM(spawn).round()} m)');
      case TouchResult.tooFar:
        _toast('a ${r.world.distanceM(spawn).round()} m');
      case TouchResult.encounter:
        r.game.fx.hop(spawn.uid); // o Eco dá um pulo na hora, enquanto a folha sobe
        await _startEncounter(spawn);
      case TouchResult.ritual:
        break; // o WorldView já chamou onRitualTarget (_startRitual)
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
    if (r == null || _busy || r.travel.driver) return; // a sintonia vibra e pede a mão: nada disso ao volante
    if (isRitualOnlyId(spawn.entryId)) return _startRitual(spawn); // não responde à sintonia
    _busy = true;
    try {
      await runEncounter(context, eco: spawn, world: r.world, state: r.session.state, data: r.data, nowUtc: () => tools.clock.nowUtc, vibration: widget.vibration, onMessage: _toast);
    } finally {
      _busy = false;
    }
    if (mounted) setState(() {});
  }

  /// O mundo na célula do Eco: hora local do relógio do jogo, bioma da célula, lua e o clima determinístico.
  WorldCondition _ritualWorld(_Ready r, WorldSpawn eco) {
    final t = tools.clock.nowUtc;
    return WorldCondition(
      hour: localHourOf(t),
      biome: r.assets.map.biomes.spawnKey(r.assets.map.spawnBiomeAtCell(eco.cellX, eco.cellY)),
      moon: moonPhase(t),
      weather: r.data.climates.of(_climate!.world.idAt(eco.cellX, eco.cellY, t)).base,
    );
  }

  /// Abre o ritual do Eco que não responde à sintonia (a até 30 m).
  Future<void> _startRitual(WorldSpawn spawn) async {
    final r = _ready;
    final recipe = r?.data.ritual.of(spawn.entryId);
    if (r == null || recipe == null || _busy) return;
    _busy = true;
    try {
      final st = r.session.state;
      final status = await runRitual(context,
          state: st, data: r.data, recipe: recipe, uid: spawn.uid, level: spawn.level ?? 1, world: () => _ritualWorld(r, spawn), nowUtc: () => tools.clock.nowUtc, variant: spawn.variant, shiny: spawn.shiny);
      if (status != null) r.world.remove(spawn); // selou ou escapou: o Eco sai do mapa
    } finally {
      _busy = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TapLatency.instance.start(); // mede toque → primeiro quadro, para o menu de debug
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
    // O clima do mundo: o modelo é o da época ATIVA naquele instante (nunca o da mais nova); o debug pode forçar qualquer id.
    final climate = climateWorldFor(state: session.state, data: data, assets: assets, forced: () => tools.force.weather, forcedPhase: tools.force.phase);
    final world = worldViewFor(
      state: session.state,
      data: data,
      assets: assets,
      weatherAt: climate.idAt,
      climate: climate,
      force: tools.force,
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
      overlayRadii: () => tools.showRadii,
      auraM: assets.balance.auraM,
      defaultWidthM: assets.balance.defaultWidthM,
      minWidthM: assets.balance.cameraMinWidthM,
      maxWidthM: assets.balance.cameraMaxWidthM,
      sparkSizeM: assets.balance.sparkSizeM,
      declinationDeg: assets.balance.compassDeclinationDeg,
      dpr: dpr,
      worldView: world,
      streetNames: () => session.state.setting('street_names'),
      veilTraffic: () => session.state.settingOr('veil_traffic', true),
      rainFx: () => streetLifeEnabled && session.state.settingOr('rain_fx', true),
      climateShown: () => streetLifeEnabled ? _climate!.info : ClimateInfo.legacy(Weather.clear),
      climateCatalog: data.climates,
      climateBalance: data.climateBalance,
      reduceFlashes: () => session.state.setting(kReduceFlashesSetting),
      variantTint: (s) => data.variantInfo(biome: s.variant, shiny: s.shiny)?.tint ?? data.climates.tags[s.tag]?.tint, // o Eco carregado do raio é ciano
      familiarImage: familiar,
      floorTile: assets.world!.isFloorTile,
      floorGridCells: assets.fallback!.floorGridCells,
      familiarOffsetM: data.street.familiarFollowOffsetM,
      sprites: sprites,
      typeOf: (id) => data.species(id)?.type,
      nowUtc: () => tools.clock.nowUtc,
    );
    final layers = await openMapLayers(
      assets: assets,
      schedule: data.schedule,
      appVersion: _version,
      nowUtc: () => tools.clock.nowUtc,
      realNowUtc: () => tools.clock.realNowUtc,
      baseUrl: () => tools.feedBaseUrl,
      onNotice: _toast,
      confirm: _confirmRegion,
    );
    final tracker = PlayerTracker(source: tools.source);
    final accessTol = data.travel.accessTolM / metersPerCell(game.playerLat);
    final travel = TravelSession(
      state: session.state,
      balance: data.travel,
      graph: TrafficGraph(
          loadTile: assets.visual!.tile,
          cellsPerTile: assets.visual!.cellsPerTile,
          extent: assets.visual!.pack.extent,
          cacheTiles: 512,
          stitch: true,
          noCrossingAt: assets.world == null ? null : bridgeTest(assets.world!, accessTol)),
      patterns: data.ridePatterns,
      radioLines: data.mentor.radio,
      sparkItem: (lat, lon, t) => sparkForBiome(data.schedule.select(t).epoch, _biomeKeyAt(assets, lat, lon)),
      ecosInReach: () => [for (final s in world.spawns) if (s.isEco && world.distanceM(s) <= data.travel.autoMarkM) s],
      nowUtc: () => tools.clock.nowUtc,
      highway: assets.noWalk == null ? null : highwayTest(assets.noWalk!, data.travel.highwayTolM / metersPerCell(game.playerLat)),
      access: assets.world == null ? null : accessTest(assets.world!, accessTol),
      sandbox: () => tools.sandboxed,
    );
    // Com a Patrulha ligada quem coleta é o serviço; o mapa mostra e lê o diário (patrol_controller.dart).
    world.quiet = () => travel.quiet || PatrolController.instance.running;
    world.sandbox = () => tools.sandboxed;
    _patrol = PatrolHooks(state: session.state, balance: data.patrol, nowUtc: () => tools.clock.nowUtc, onMessage: _toast, onFocus: (m) => _startEncounter(m.toSpawn()));
    _pocket.addListener(_pocketFps);
    PatrolController.instance.addListener(_pocketFps);
    world.travelPickupM = () => travel.pickupBonusM;
    game.travelLayer = TravelLayer(travel, carM: assets.balance.ghostCarM);
    travel.addListener(() {
      game.setTravelView(travel.viewWidthM);
      game.avatar.travelMaxMps = travel.avatarMaxMps;
    });
    final sub = tracker.states.listen((s) {
      game.onPlayerState(s);
      layers.noteFix(s.lastRaw);
      noteTravelPosition(travel, s, game.avatar);
      _rememberBiome(s, session.state, assets);
      _markVisited(s, session.state);
      _rebuild();
    });
    game.onFollowHeading = _setFollowHeading;
    game.onWalked = _onWalked;
    world.onAggressive = _onAggressive;
    world.onRitualTarget = _startRitual;
    world.onCollected = game.onCollected;
    world.onFled = game.onEcoFled;
    world.onShiny = _onShiny;
    world.onEnteredRange = _onEnteredRange;
    _climate = ClimateDriver(data: data, world: climate, online: () => session.state.setting('weather_online'));
    unawaited(_climate!.loadEvents());
    game.climateFx
      ..onThunder = _scheduleThunder
      ..onEcoBorn = (d) => _toast(data.climates.tags[d.piece.spawn?.tag]?.born ?? 'Algo nasceu ali', seconds: 3);
    session.state.onNotice = _toast;
    session.state.ensureDaily(data.forum, data.schedule.select(tools.clock.nowUtc).epoch.id, localDay(tools.clock.nowUtc));
    _storyTimer = Timer.periodic(const Duration(seconds: 1), (_) => _storyTick());
    if (session.state.setting('follow_heading')) {
      game.rotation.toggleFollowHeading(); // volta ao modo que o jogador deixou ligado
      WidgetsBinding.instance.addPostFrameCallback((_) => _setFollowHeading(true));
    }
    _ready = _Ready(assets, game, tracker, sub, data, session, world, layers, travel);
    travel.addListener(() => _onTravel(_ready!));
    PatrolController.instance.addListener(_rebuild); // o atalho da Patrulha entra e sai da faixa
    _familiarSchool = session.state.conjurer.school;
    if (_familiarSchool != null) unawaited(_reloadFamiliar(game, session.state));
    session.state.addListener(_onStateForFamiliar);
    // O acesso é pedido depois do primeiro quadro: o diálogo precisa de uma tela montada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final note = session.loadNote;
      if (note != null) _toast(note, seconds: 8);
      unawaited(_patrol?.sync());
      unawaited(_checkActiveRides());
      _ensureAccess();
    });
    return _ready!;
  }

  /// Uma corrida do Uber ou da 99 pedida fora do jogo: com a permissão e o interruptor dos Ajustes, as notificações que
  /// já estão na barra retomam a viagem no estado certo.
  Future<void> _checkActiveRides() async {
    final r = _ready;
    if (r == null || !r.session.state.setting(kRideNotifySetting)) return;
    const bridge = SystemBridge();
    if (!await bridge.notificationAccess()) return;
    final active = await bridge.activeRides();
    if (active.isNotEmpty && mounted) r.travel.onActiveNotifications(active);
  }

  School? _familiarSchool;

  /// A escola mudou (escolhida nos testes do Chat ou no debug): o Familiar do mapa troca de forma na hora.
  void _onStateForFamiliar() {
    final r = _ready;
    if (r == null || r.session.state.conjurer.school == _familiarSchool) return;
    _familiarSchool = r.session.state.conjurer.school;
    unawaited(_reloadFamiliar(r.game, r.session.state));
  }

  Future<void> _reloadFamiliar(GameMapGame game, GameState state) async {
    final image = await loadFamiliarImage(school: state.conjurer.school);
    if (mounted) game.familiarImage = image;
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
      _stopProximity();
    } else if (state == AppLifecycleState.resumed) {
      _ensureAccess(); // o jogador pode ter mexido nos ajustes
      unawaited(_patrol?.sync()); // o que a Patrulha juntou com o app fechado
      unawaited(_checkActiveRides());
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
      r.session.state.removeListener(_onStateForFamiliar);
      r.travel.dispose();
      r.sub.cancel();
      r.tracker.dispose();
      r.layers.dispose();
      r.assets.dispose();
      r.session.dispose();
    }
    _toastTimer?.cancel();
    _longTimer?.cancel();
    _storyTimer?.cancel();
    for (final t in _thunders) {
      t.cancel();
    }
    _stopProximity();
    _patrol?.dispose();
    PatrolController.instance.removeListener(_pocketFps);
    PatrolController.instance.removeListener(_rebuild);
    _pocket.dispose();
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

  /// Abre um app do celular direto do mapa (atalhos do HUD), por cima do mapa: voltar devolve ao mapa.
  void _openApp(_Ready r, String id) {
    final screen = _appScreen(r, id);
    if (screen != null && mounted) unawaited(Navigator.of(context).push(phoneRoute<void>(screen)));
  }

  /// As telas dos apps que dependem do mapa (os outros o celular monta sozinho).
  Widget? _appScreen(_Ready r, String id) => switch (id) {
        PhoneAppId.radar => RadarScreen(
            state: r.session.state,
            street: r.data.street,
            nowUtc: () => tools.clock.nowUtc,
            onSweep: () => r.world.radar(tools.clock.nowUtc),
            echoes: r.world.sonar,
            rotation: () => r.game.follow.rotation,
          ),
        PhoneAppId.routes => RoutesScreen(
            travel: r.travel,
            state: r.session.state,
            data: r.data,
            appVersion: _version,
            playerLat: () => r.game.playerLat,
            playerLon: () => r.game.playerLon,
            onMessage: _toast,
            onPickOnMap: _backToMap,
          ),
        PhoneAppId.patrol => PatrolScreen(state: r.session.state, balance: r.data.patrol, onMessage: _toast),
        PhoneAppId.sky => SkyScreen(
            nowUtc: () => tools.clock.nowUtc,
            lat: () => r.game.playerLat,
            catalog: r.data.climates,
            shown: streetLifeEnabled ? () => _climate!.info : null,
            outlook: streetLifeEnabled ? cellSkyOutlook(_climate!.world, lat: () => r.game.playerLat, lon: () => r.game.playerLon, catalog: r.data.climates) : null,
          ),
        PhoneAppId.settings => _settings(r),
        _ => null,
      };

  /// Fecha o celular e os apps: o mapa volta à vista (escolher o destino da viagem tocando nele).
  void _backToMap() {
    if (!mounted) return;
    final own = ModalRoute.of(context);
    Navigator.of(context).popUntil((route) => route == own || route.isFirst);
  }

  TravelStage _travelStage = TravelStage.idle;

  /// O destino foi tocado no mapa: o app Rotas volta para escolher o veículo.
  void _onTravel(_Ready r) {
    final was = _travelStage;
    _travelStage = r.travel.stage;
    if (was == TravelStage.pickDestination && _travelStage == TravelStage.pickVehicle && mounted && ModalRoute.of(context)?.isCurrent == true) {
      _openApp(r, PhoneAppId.routes);
    }
    _rebuild();
  }

  /// O Radar já está liberado no nível do Conjurador (e na versão com a Rua viva).
  bool _radarUnlocked(_Ready r) =>
      streetLifeEnabled && r.data.phone.apps.any((a) => a.id == PhoneAppId.radar && a.unlockedAt(r.session.state.playerLevel));

  /// O atalho do Radar no HUD: o pulso sai sem abrir o app.
  void _pulse(_Ready r) {
    final out = r.world.radar(tools.clock.nowUtc);
    HapticFeedback.lightImpact();
    _toast(radarSummary(out), seconds: 3);
  }

  /// O atalho da viagem na faixa acima do celular: o que está acontecendo, em poucas letras. `null`: nenhuma viagem.
  String? _travelChip(TravelSession t) => switch (t.stage) {
        TravelStage.idle => null,
        TravelStage.pickDestination => 'TOQUE NO MAPA: DESTINO',
        TravelStage.pickVehicle || TravelStage.askPassenger => 'VIAGEM: ESCOLHA',
        TravelStage.traveling => t.ride != null && t.ride!.state != RideState.inTrip ? 'CORRIDA · ${t.ride!.appName.toUpperCase()}' : 'VIAGEM · ${(t.recordedM / 1000).toStringAsFixed(1)} KM',
        TravelStage.done => 'BAÚ DA VIAGEM',
      };

  /// O estado do GPS, do relógio e do mundo quando há algo a avisar (seguindo bem, nada).
  List<String> _warnings(_Ready r) {
    final s = r.tracker.state;
    return [
      if (r.assets.stale) 'MUNDO DESATUALIZADO',
      if (tools.clock.overridden) 'RELÓGIO UTC ${_StatusLines.utc(tools.clock.now)} (OVERRIDE)',
      if (s.status != TrackingStatus.tracking) _StatusLines.line(s, tools),
      ?_simLine(r),
    ];
  }

  /// A Simulação de clima do debug: o clima, a fase e a velocidade, na zona de avisos (não cobre o HUD).
  String? _simLine(_Ready r) {
    final st = tools.force.simState(), sim = tools.force.sim;
    if (st == null || sim == null) return null;
    final info = r.data.climates.of(st.id), p = tools.force.phase();
    final amount = st.fading
        ? formAmount(sinceStartS: p.prevFormedS + p.prevSinceEndS, sinceEndS: p.prevSinceEndS, growS: info.formS, fadeS: info.fadeS)
        : formAmount(sinceStartS: p.ageS, growS: info.formS, fadeS: info.fadeS);
    return 'SIMULAÇÃO ${st.index + 1}/${sim.ids.length} · ${info.name.toUpperCase()} · ${formPhaseLabel(amount, ending: st.fading).toUpperCase()} · ${tools.force.speed.toInt()}X';
  }

  /// A folha do selo de modo: o estado do GPS, a troca de fonte, os controles do simulador e o menu de debug (que nunca
  /// sai do jogo, CLAUDE.md).
  Future<void> _openModeSheet(_Ready r) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: kPanel,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([tools, r.layers.source]),
            builder: (sheet, _) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _StatusLines(state: r.tracker.state, tools: tools, stale: r.assets.stale),
                if (r.layers.source.value == MapSourceKind.overpass) ...[
                  const SizedBox(height: 8),
                  const Text(kVeilBadgeHelp, style: TextStyle(fontSize: 8, color: kVeil, height: 1.8)),
                ],
                const SizedBox(height: 12),
                PixelButton(
                  label: tools.useSimulator ? 'Usar GPS real' : 'Usar simulador',
                  color: kSignal,
                  onTap: () {
                    Navigator.of(sheet).pop();
                    unawaited(_switchSource(!tools.useSimulator));
                  },
                ),
                if (tools.useSimulator) ...[const SizedBox(height: 12), SimChips(tools: tools)],
                const SizedBox(height: 12),
                PixelButton(key: const Key('open-debug-menu'), label: 'Menu de debug', color: kEssence, onTap: () => Navigator.of(context).popUntil((route) => route.isFirst)),
              ]),
            ),
          ),
        ),
      );

  Widget _view(_Ready r) {
    final game = r.game;
    final pad = MediaQuery.paddingOf(context);
    final screen = MediaQuery.sizeOf(context);
    final blocked = _access != null && _access != LocationAccess.granted && !tools.useSimulator;
    final st = r.session.state;
    final now = tools.clock.nowUtc;
    final patrolOn = _patrol != null && PatrolController.instance.running;
    final travelChip = _travelChip(r.travel);
    final hud = hudLayout(
      screen,
      top: pad.top,
      bottom: pad.bottom,
      trackerMax: 0, // sem rastreador fixo: o atalho do Radar fica no canto (as marcas do pulso vão na borda da tela)
      marks: st.activeMarks(now).length,
      shortcuts: patrolOn || travelChip != null,
      compass: true, // a vaga da bússola fica reservada: ela aparece e some sem empurrar nada
      radar: _radarUnlocked(r),
      simulator: tools.useSimulator,
    );
    final warnings = _warnings(r);
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
        // As zonas fixas do HUD (`hud_layout.dart`): nada aqui cobre outra peça em nenhum tamanho de tela comum.
        Positioned.fromRect(
          rect: hud.bar,
          child: HudBar(
            nowUtc: () => tools.clock.nowUtc,
            lat: () => game.playerLat,
            weather: streetLifeEnabled ? () => _climate!.info : null,
            onSky: () => _openApp(r, PhoneAppId.sky),
            seal: ModeSeal(tools: tools, source: r.layers.source, onTap: () => _openModeSheet(r)),
          ),
        ),
        Positioned.fromRect(
          rect: hud.compass!,
          child: ValueListenableBuilder(
            valueListenable: game.compass,
            builder: (context, c, _) =>
                c.visible ? CompassButton(angle: c.angle, follow: c.follow, onNorth: game.goNorth, onToggleFollow: game.toggleFollowHeading) : const SizedBox.shrink(),
          ),
        ),
        if (_toastText != null || warnings.isNotEmpty)
          Positioned(
            left: hud.notice.left,
            top: hud.notice.top,
            width: hud.notice.width,
            child: IgnorePointer(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: hud.notice.height),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(), // corta o que passar da zona, sem rolar
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (warnings.isNotEmpty)
                      Container(
                        key: const Key('hud-warning'),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.88), border: Border.all(color: kPanelLine, width: 2)),
                        child: Text(warnings.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: kEssence, height: 1.4)),
                      ),
                    if (_toastText != null)
                      Container(
                        key: const Key('hud-toast'),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.9), border: Border.all(color: kEssence, width: 2)),
                        child: Text(_toastText!.toUpperCase(), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: kText, height: 1.4)),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        Positioned(
          left: hud.marks.left,
          top: hud.marks.top,
          width: hud.marks.width,
          child: MarkChips(state: st, nowUtc: () => tools.clock.nowUtc, sprites: game.sprites, max: hud.marksFit, onTap: (m) => _startEncounter(m.toSpawn())),
        ),
        if (hud.joystick != null) Positioned.fromRect(rect: hud.joystick!, child: Joystick(size: HudSize.joystick, onChanged: tools.simulator.setJoystick)),
        Positioned(
          left: hud.portrait.left,
          bottom: screen.height - hud.portrait.bottom,
          width: hud.portrait.width,
          child: PortraitHud(
            state: st,
            frame: game.playerFrames.isEmpty ? null : game.playerFrames.first,
            onTap: () => Navigator.of(context).push(phoneRoute<void>(ProfileScreen(
              state: st,
              data: r.data,
              nowUtc: () => tools.clock.nowUtc,
              onOpenSettings: () => Navigator.of(context).push(phoneRoute<void>(_settings(r))),
            ))),
          ),
        ),
        Positioned.fromRect(
          rect: hud.phone,
          child: ListenableBuilder(
            listenable: st,
            builder: (context, _) => PhoneButton(
              alert: phoneHasAlert(st, r.data.phone),
              onTap: () => showPhoneMenu(
                context,
                state: st,
                data: r.data,
                settings: () => _settings(r),
                radar: () => _appScreen(r, PhoneAppId.radar)!,
                routes: () => _appScreen(r, PhoneAppId.routes)!,
                patrol: () => _appScreen(r, PhoneAppId.patrol)!,
                sky: () => _appScreen(r, PhoneAppId.sky)!,
                nowUtc: () => tools.clock.nowUtc,
                weather: () => _climate!.info,
                lat: () => game.playerLat,
                epochId: () => r.data.schedule.select(tools.clock.nowUtc).epoch.id,
              ),
            ),
          ),
        ),
        if (hud.strip != null)
          Positioned.fromRect(
            key: const Key('hud-strip'),
            rect: hud.strip!,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (patrolOn) Flexible(child: PatrolShortcut(hooks: _patrol!, onOpen: () => _openApp(r, PhoneAppId.patrol))),
              if (patrolOn && travelChip != null) const SizedBox(width: 6),
              if (travelChip != null) Flexible(child: ShortcutChip(key: const Key('travel-chip'), label: travelChip, color: kVeil, onTap: () => _openApp(r, PhoneAppId.routes))),
            ]),
          ),
        if (hud.radar != null)
          Positioned.fromRect(
            rect: hud.radar!,
            child: RadarShortcut(state: st, street: r.data.street, nowUtc: () => tools.clock.nowUtc, onPulse: () => _pulse(r)),
          ),
        // Sem nada à vista: mantém a leitura das notificações da corrida com o app Rotas fechado.
        TravelOverlay(travel: r.travel, state: st, data: r.data, appVersion: _version, playerLat: () => game.playerLat, playerLon: () => game.playerLon, onMessage: _toast),
        if (blocked) SafeArea(child: _AccessPanel(access: _access!, gateway: widget.gateway, onRetry: _ensureAccess, onSimulator: () => _switchSource(true))),
        PocketOverlay(mode: _pocket, enabled: () => st.setting(kPocketSetting) || PatrolController.instance.running),
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

/// O estado do GPS na folha do selo: de onde vem a posição, como está o sinal, as coordenadas, o relógio e o mundo.
class _StatusLines extends StatelessWidget {
  const _StatusLines({required this.state, required this.tools, required this.stale});

  final PlayerState state;
  final DevTools tools;
  final bool stale;

  static String line(PlayerState state, DevTools tools) {
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stale) const Text('MUNDO DESATUALIZADO', style: TextStyle(fontSize: 8, color: kEssence, height: 1.6)),
        if (tools.clock.overridden) Text('RELÓGIO UTC ${utc(tools.clock.now)} (OVERRIDE)', style: const TextStyle(fontSize: 8, color: kEssence, height: 1.6)),
        Text(line(state, tools), style: style.copyWith(color: state.status == TrackingStatus.tracking ? kSignal : kDim)),
        if (p != null) Text('${p.lat.toStringAsFixed(5)}, ${p.lon.toStringAsFixed(5)}', style: style),
      ],
    );
  }

  static String utc(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
