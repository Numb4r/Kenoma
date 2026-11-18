import '../../dev/tap_latency.dart';
import '../../core/features.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;

import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show kProfileMode, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, rootBundle;
import '../lab/lab_art.dart' show loadAsepriteArt;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/plural.dart';
import '../../core/fnv.dart';
import '../../core/pcg32.dart';
import '../../core/tiles.dart';
import '../../core/windows.dart' show windowIndex;
import '../../world/style_advisor.dart';
import '../../world/climate_world.dart' show nearestPuddle;
import '../../core/weather.dart';
import '../../core/astro.dart' show moonPhase;
import '../../core/species_ids.dart' show isRitualOnlyId;
import '../../crafting/bag.dart' show acceptable;
import '../../crafting/collector_tick.dart';
import '../../crafting/quality.dart' show parseStack;
import '../../crafting/tutorial.dart' show syncTutorial;
import '../../crafting/loadout.dart' show rideBandOf;
import '../../travel/travel_balance.dart' show Vehicle;
import '../craft/craft_context.dart';
import '../craft/planted_list.dart';
import '../craft/ui_art.dart';
import 'map_touch_flow.dart';
import 'npc_sheet.dart';
import 'creature_art.dart';
import 'traffic_art.dart';
import '../../crafting/collectors.dart';
import '../../crafting/crafting_state.dart';
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
import '../../save/ksv_save_store.dart';
import '../../player/game_session.dart';
import '../../save/fresh_start.dart';
import '../../save/save_store.dart';
import '../../world/spawn_field.dart';
import '../../world/touch_gesture.dart';
import '../../world/veilbreakers.dart';
import '../../world/map_touch.dart' show placeKey, spectralBusNext;
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
import '../../player/circle.dart' show abilitiesOf, circleAbilities;
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
import '../../world/climate_outlook.dart' show nextCalendarItems, stackLine;
import '../../world/dew_prism.dart';
import '../../core/climate.dart' show RainbowArc;
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
import 'spawn_painter.dart' show mapVariantKeys;
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
import '../system_bars.dart';

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

  // O teste de viaduto da simulação do tráfego: montado no primeiro uso, já com a latitude do jogador.
  bool Function(double x, double y)? _bridge;
  double Function() _bridgeLat = () => -22.9;
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

  /// 0.24.5: refaz os NPCs quando o debug liga ou desliga "NPC em toda célula".
  VoidCallback? _npcListener;

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
    if (_collectorsIn-- <= 0) {
      _collectorsIn = 10;
      _tickCollectors(r, st, now);
    }
    _radioTick(r, now);
    if (tools.force.rainbowJumpPending) _pendingRainbowJump(r);
    if (_weatherIn-- <= 0 || tools.force.simulating) {
      _weatherIn = 10;
      _updateWeather();
      if (tools.force.simulating) setState(() {}); // a fase da simulação nos avisos
    }
  }

  String? _radioSaid;
  int _collectorsIn = 0;
  int _bagFullToastUtc = 0;

  /// A cada 10 s: as garrafas do cinto enchem com a condição em volta do jogador e os plantados seguem a conta do lugar.
  void _tickCollectors(_Ready r, GameState st, int now) {
    syncTutorial(st); // os passos da quest do crafting soltam as mensagens do mentor
    if (st.crafting.vessels.isEmpty || !r.world.hasPlayer) return;
    final news = tickCollectors(st, r.data.craft,
        hereAt: (lat, lon, t) => r.world.here(lat, lon, t, waterSearchM: 0), lat: r.game.playerLat, lon: r.game.playerLon, now: now, dtS: 10);
    for (final v in news.belt) {
      _toast(vesselFullText(v, r.data.craft));
    }
    for (final v in news.planted) {
      _toast('Plantado: ${vesselFullText(v, r.data.craft)}');
    }
  }

  /// A condição de agora e aqui para a Bolsa, a Bancada e os plantados: o mesmo mundo do mapa.
  CraftContext _craftContext(_Ready r) => CraftContext(
        nowUtc: () => tools.clock.nowUtc,
        here: () => r.world.here(r.game.playerLat, r.game.playerLon, tools.clock.nowUtc, waterSearchM: r.data.craft.balance.waterNearM * 2),
        hereAt: (lat, lon, t) => r.world.here(lat, lon, t, waterSearchM: 0),
        speedMps: () => r.game.avatar.speedMps,
        walkMaxMps: r.data.patrol.walkMaxMps,
        touchM: r.world.touchRangeM,
        climateName: (id) => r.data.climates.of(id).name,
      );

  /// Toque num coletor plantado: de perto colhe (cinto se houver espaço, senão bolsa); de longe diz a distância.
  void _tapCollector(_Ready r, Vessel v) {
    final st = r.session.state;
    final d = metersBetween(r.game.playerLat, r.game.playerLon, v.lat, v.lon);
    final what = v.content == null ? r.data.craft.items[v.kind]?.agree('vazio', 'vazia') ?? 'vazio' : '${r.data.itemName(v.content!)}, ${v.quality.phrase}';
    if (!harvest(st, v, d, r.world.touchRangeM, r.data.craft, tools.clock.nowUtc)) return _toast('Coletor a ${d.round()} m ($what): chegue perto para colher');
    _toast(v.place == VesselPlace.belt ? 'Colhido para o cinto: $what' : 'Colhido para a bolsa: $what');
  }

  /// 0.24.2: o toque que não pegou Eco nem material vai para o mapa (ponto de ônibus, banca, árvore, poste, placa, bando,
  /// gato, poça), no alcance de toque e a pé.
  Future<void> _touchMap(_Ready r, Offset at) async {
    final now = tools.clock.nowUtc;
    // 0.24.5: um dos Outros Veilbreakers sob o dedo abre a folha dele.
    final cw = _climate?.world;
    MapTouchDeps deps() => MapTouchDeps(
          state: r.session.state,
          data: r.data,
          world: r.world,
          game: r.game,
          nowUtc: () => tools.clock.nowUtc,
          speedMps: r.game.avatar.speedMps,
          toast: _toast,
          climate: cw,
          visual: r.assets.visual,
        );
    if (r.game.npcAt(at) case final npc?) return handleNpcTouch(context, npc, deps());
    final (x, y) = latLonToTileFraction(r.game.playerLat, r.game.playerLon, biomeZoom);
    final puddles = cw == null ? const <(double, double)>[] : [for (final p in cw.puddlesNear(x, y, 60 / r.world.metersPerCell21, now)) (p.x, p.y)];
    final hit = r.game.touchAt(at, puddles: puddles);
    if (hit == null) return;
    await handleMapTouch(context, hit, deps());
  }

  void _onBagFull() {
    final now = tools.clock.nowUtc;
    if (now - _bagFullToastUtc < 20) return; // a Fagulha na Aura tenta a cada quadro
    _bagFullToastUtc = now;
    _toast('Bolsa cheia. Destile, descarte ou fabrique para abrir espaço.');
  }

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
      _toast('Limite de ${countText(state.balance.markMax, 'marcação')}. Solte uma com toque longo');
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
    if (r.game.collectorAt(at) case final v?) return _tapCollector(r, v);
    final spawn = r.game.spawnAt(at);
    if (spawn == null) return _touchMap(r, at);
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
      case TouchResult.bagFull:
        break; // o WorldView já avisou (onBagFull)
    }
  }

  /// Abre o encontro com [spawn]: a folha de selo e a sintonia.
  Future<void> _startEncounter(WorldSpawn spawn) async {
    final r = _ready;
    if (r == null || _busy || r.travel.driver) return; // a sintonia vibra e pede a mão: nada disso ao volante
    if (isRitualOnlyId(spawn.entryId)) return _startRitual(spawn); // não responde à sintonia
    _busy = true;
    try {
      await runEncounter(context, eco: spawn, world: r.world, state: r.session.state, data: r.data, nowUtc: () => tools.clock.nowUtc, vibration: widget.vibration, onMessage: _toast, onExit: (eco, {required tuned}) => r.game.fx.exit(eco, tuned: tuned, facingLeft: r.game.facingLeftOfEco(eco.uid)));
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _live = this;
    _route = ModalRoute.of(context);
  }

  ModalRoute<Object?>? _route;

  /// Completa quando este mapa termina de fechar (o debug espera antes de abrir outro).
  final _closed = Completer<void>();

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

  /// Os ouvintes do [DevTools] e do relógio podem ser avisados no meio de um build (outro mapa ainda saindo, um item do
  /// debug): aí o redesenho fica para depois do quadro, sem "setState during build".
  void _rebuild() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (_rebuildQueued) return;
      _rebuildQueued = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _rebuildQueued = false;
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  bool _rebuildQueued = false;

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
      // 0.21.0: cada variante com o valor e o acessório dela (`species@variante`) e o neon da Iluminada (`@lit#glow`),
      // montados na hora (sem fila de decodificação).
      for (final s in data.tuning.species) {
        for (final v in mapVariantKeys) {
          sprites['${s.id}@$v'] = EcoSprite.loadMapVariant(s.id, v);
        }
        if (EcoSprite.loadMapGlow(s.id, 'lit') case final g?) sprites['${s.id}@lit#glow'] = g;
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
    unawaited(applySystemBars(show: session.state.setting(kSystemBarsSetting)));
    // 0.24.1: a bolsa nunca passa do limite. Todo item que entra passa por aqui; o que não cabe é recusado com aviso.
    session.state.accept = (key, n) {
      final ok = acceptable(session.state, data.craft, tools.clock.nowUtc, key, n);
      if (ok < n && mounted) _toast('Bolsa cheia: ${n - ok} × ${data.itemName(parseStack(key).id)} ${n - ok == 1 ? 'ficou' : 'ficaram'} de fora');
      return ok;
    };
    session.onSeen = tools.clock.raiseFloor;
    // O clima do mundo: o modelo é o da época ATIVA naquele instante (nunca o da mais nova); o debug pode forçar qualquer id.
    final climate = climateWorldFor(state: session.state, data: data, assets: assets, forced: () => tools.force.weather, forcedEvents: () => tools.force.events, forcedPhase: tools.force.phase);
    final world = worldViewFor(
      state: session.state,
      data: data,
      assets: assets,
      weatherAt: climate.idAt,
      climate: climate,
      force: tools.force,
      onMessage: _toast,
      personalHidden: () => tools.hidePersonal,
      abilities: () => switch (tools.testCircle) {
        null => abilitiesOf(session.state, data),
        final ids => circleAbilities([for (final id in ids) if (data.species(id) case final sp?) (species: sp, level: 10)], data.tuning.abilityBands),
      },
    );
    tools.personalStats = () => world.personal!.stats;
    tools.layerHashes = () {
      if (!world.hasPlayer) return 'sem posição ainda';
      final t = tools.clock.nowUtc, cx = world.playerX.floor() >>> 1, cy = world.playerY.floor() >>> 1;
      String hex(int h) => (h >>> 32).toRadixString(16).padLeft(8, '0');
      return 'célula $cx,$cy · janela ${windowIndex(world.field.seed, cx, cy, t)} · época ${data.schedule.select(t).epoch.id}\n'
          'base ${hex(world.field.baseHashAt(cx, cy, t))} · pessoal ${hex(world.personal!.personalHashAt(cx, cy, t))}';
    };
    tools.nearestPuddle = () {
      // A até 1 km do jogador, as duas camadas de poça (a do Rill está no mesmo mundo do clima).
      if (!world.hasPlayer) return null;
      final p = nearestPuddle(climate.puddlesNear(world.playerX, world.playerY, 1000 / world.metersPerCell21, tools.clock.nowUtc), world.playerX, world.playerY);
      return p == null ? null : tileFractionToLatLon(p.x, p.y, biomeZoom);
    };
    final game = GameMapGame(
      renderer: assets.makeRenderer(),
      visual: assets.visual!,
      style: ArtStyle(assets.biomes),
      balance: assets.balance,
      playerFrames: playerFrames,
      overlayBiomes: () => tools.showBiomeGrid,
      overlayGrid20: () => tools.showGrid20,
      overlayRadii: () => tools.showRadii,
      overlayPuddles: () => tools.showPuddles,
      overlayTraffic: () => tools.showTraffic,
      overlayRelief: () => tools.showRelief,
      relief: assets.relief,
      trafficDensity: () => tools.trafficDensity,
      trafficSim: assets.balance.trafficSim,
      trafficPoints: assets.trafficPoints,
      cycleways: assets.cycleways,
      ground: assets.ground,
      noCrossingAt: assets.world == null ? null : (x, y) => (_bridge ??= bridgeTest(assets.world!, data.travel.accessTolM / metersPerCell(_bridgeLat())))(x, y),
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
      buildings: assets.buildings,
      simpleStyle: () => session.state.setting(kSimpleGraphicsSetting),
      floorGridCells: assets.fallback!.floorGridCells,
      familiarOffsetM: data.street.familiarFollowOffsetM,
      sprites: sprites,
      typeOf: (id) => data.species(id)?.type,
      nowUtc: () => tools.clock.nowUtc,
    );
    // 0.22.0: com o Completo lento por um minuto, uma sugestão, uma vez só (nunca troca sozinho).
    game.followPiece = () => tools.followPiece;
    game.turnLabels = () => tools.turnLabels;
    game.wideZoom = () => session.state.setting(kWideZoomSetting);
    game.forcedWidthM = () => tools.forcedWidthM;
    game.asepriteArt = () => tools.asepriteArt;
    unawaited(loadAsepriteArt((p) async {
      try {
        final d = await (widget.bundle ?? rootBundle).load(p);
        return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
      } catch (_) {
        return null;
      }
    }).then((m) => game.asepriteStamps = m));
    game.styleAdvisor.alreadySuggested = session.state.setting(kSimpleSuggestedSetting);
    game.onSuggestSimple = () {
      session.state.setSetting(kSimpleSuggestedSetting, true);
      _toast('O mapa está pesado neste celular. Em Ajustes, os gráficos Simplificado são mais leves e poupam bateria.', seconds: 8);
    };
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
    _bridgeLat = () => game.playerLat;
    // Da época 9 em diante, com relevo: as ruas que o Dilúvio alaga saem da água no relevo. No mapa do jogo a água de cada
    // tile é calculada fora da thread do desenho: o bloco aparece sem água até ela chegar.
    assets.waterInBackground = true;
    game.waterRevision = () => assets.waterFor(data.schedule.select(tools.clock.nowUtc).epoch)?.revision ?? 0;
    game.climateGround.floods = (key) => assets.waterFor(data.schedule.select(tools.clock.nowUtc).epoch)?.lineFloods(key.$1, key.$2, key.$3);
    tools.trafficStats = () {
      final sim = game.trafficSimState, g = sim?.lanes;
      if (sim == null || g == null) return 'A simulação ainda não começou (sem posição ou com o Tráfego do Véu desligado).';
      return '${sim.cars.length} carros, ${sim.walkers.length} passantes · passo ${sim.avgStepUs.round()} µs (último ${sim.lastStepUs} µs) · '
          '${g.nodes.length} esquinas, ${g.nodes.where((n) => n.signal).length} semáforos, ${g.nodes.where((n) => n.entry).length} entradas · grafo em ${g.buildUs ~/ 1000} ms\n'
          '${() {
            final w = assets.waterFor(data.schedule.select(tools.clock.nowUtc).epoch);
            return 'Água no relevo: ${w?.builds ?? 0} tiles calculados, último em ${(w?.lastBuildMs ?? 0).toStringAsFixed(1)} ms (uma vez por tile)';
          }()} · Véu da neblina: ${game.fogUs.round()} µs por quadro · Bichos e vento: ${game.lifeUs.round()} µs por quadro\n'
          'Cobertura por campo: ${game.climateGround.cover?.fieldDrawn ?? 0} blocos na tela, ${game.climateGround.cover?.fieldBuilds ?? 0} refeitos, último em ${(game.climateGround.cover?.fieldLastMs ?? 0).toStringAsFixed(1)} ms (fora do quadro)\n'
          '${game.fullStyle && game.isMounted ? 'Mapa Completo: chão ${game.city.groundMs.toStringAsFixed(1)} ms (${game.city.drawnChunks} blocos, ${game.city.rebuiltLastFrame} refeitos no quadro, ${game.city.rebuiltTotal} no total, ${game.city.onGrid ? 'na grade' : 'girando'}), de pé ${game.city.uprightMs.toStringAsFixed(1)} ms (${game.city.upright.stats.buildings} prédios, ${game.city.upright.stats.props} árvores e props)' : 'Mapa Simplificado: ${game.artRasterMs.toStringAsFixed(1)} ms'} · partículas ${game.rainCount}\nPrédios: ${assets.world?.buildingStats ?? '-'} · build ${kReleaseMode ? 'release' : kProfileMode ? 'profile' : 'debug (não vale como medida)'}';
    };
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
    // 0.24.5: os Outros Veilbreakers (só nas épocas com `veilbreakers`), iguais para o grupo. A camada base é consultada no
    // nível máximo: o que existe no mundo não depende do nível de quem olha.
    final veil = VeilbreakerField(
      seed: world.field.seed,
      modelAt: (t) => switch (data.schedule.select(t).epoch.veilbreakers) { final m? when tools.forceNpcs => m.withChance(1), final m => m },
      epochAt: (t) => data.schedule.select(t).epoch.id,
      biomeAt: (cx, cy) => world.field.map.biomes.spawnKey(world.field.map.spawnBiomeAtCell(cx >>> 1, cy >>> 1)),
      ecosNear: (x, y, t, r) {
        final (lat, lon) = tileFractionToLatLon(x, y, biomeZoom);
        return world.field.around(lat: lat, lon: lon, tUtc: t, radiusM: r, playerLevel: 99);
      },
      mpcAt: (y) => metersPerCell(tileFractionToLatLon(0, y, biomeZoom).$1),
      data: data.npc,
      snapper: world.field.snapper,
      nicknameChance: data.npcBalance.nicknameChance,
      // 0.25.0: o caminho segue a calçada das ruas do pacote visual (igual para todos), como os passantes.
      roadsNear: (x, y, r) {
        final n = game.visual.cellsPerTile, reach = r / metersPerCell(tileFractionToLatLon(0, y, biomeZoom).$1);
        return [
          for (var ty = ((y - reach) / n).floor(); ty <= ((y + reach) / n).floor(); ty++)
            for (var tx = ((x - reach) / n).floor(); tx <= ((x + reach) / n).floor(); tx++)
              for (final road in game.cityTiles.tileAt(tx, ty).roads)
                if (road.bounds.$1 <= x + reach && road.bounds.$3 >= x - reach && road.bounds.$2 <= y + reach && road.bounds.$4 >= y - reach)
                  (pts: [for (var i = 0; i + 1 < road.xy.length; i += 2) (road.xy[i], road.xy[i + 1])], halfM: (assets.balance.roadWidthM[road.cls] ?? 6) / 2),
        ];
      },
    );
    world.veil = veil;
    game.debugWalkAt = (s, t, mpc) => tools.force.creatures.walkAt(s, t, mpc);
    tools.turnMapTo = (deg) => game.rotation
      ..reset()
      ..rotateBy(deg * math.pi / 180);
    tools.exitNearestEco = (tuned) {
      if (!game.avatar.hasPosition) return null;
      final ecos = [for (final s in world.spawns) if (s.isEco) s]
        ..sort((a, b) => ((a.x - game.avatar.x) * (a.x - game.avatar.x) + (a.y - game.avatar.y) * (a.y - game.avatar.y)).compareTo((b.x - game.avatar.x) * (b.x - game.avatar.x) + (b.y - game.avatar.y) * (b.y - game.avatar.y)));
      if (ecos.isEmpty) return null;
      game.fx.exit(ecos.first, tuned: tuned, facingLeft: game.facingLeftOfEco(ecos.first.uid));
      world.remove(ecos.first);
      return ecos.first.uid;
    };
    tools.openNearestNpc = () {
      final r = _ready;
      if (r == null || !game.avatar.hasPosition) return null;
      final t = tools.clock.nowUtc.toDouble();
      Veilbreaker? best;
      var bd = double.infinity;
      for (final n in game.visibleVeilbreakers) {
        if (!n.presentAt(t)) continue;
        final p = n.at(t), d = (p.x - game.avatar.x) * (p.x - game.avatar.x) + (p.y - game.avatar.y) * (p.y - game.avatar.y);
        if (d < bd) (best, bd) = (n, d);
      }
      final n = best;
      if (n == null) return null;
      final p = n.at(t);
      final (lat, lon) = tileFractionToLatLon(p.x, p.y, biomeZoom);
      tools.simulator.teleport(lat - 12 / 111320, lon);
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        final cw = _climate?.world;
        unawaited(handleNpcTouch(context, n, MapTouchDeps(state: r.session.state, data: r.data, world: r.world, game: r.game, nowUtc: () => tools.clock.nowUtc, speedMps: 0, toast: _toast, climate: cw, visual: r.assets.visual), anyDistance: true));
      });
      return n.id;
    };
    tools.nextSpectral = () {
      if (!game.avatar.hasPosition || game.size.x <= 0) return null;
      final now = tools.clock.nowUtc;
      ({int at, double lat, double lon})? best;
      var bd = double.infinity;
      for (final tile in game.visibleTiles(Size(game.size.x, game.size.y), game.follow.camera)) {
        for (final p in tile.props) {
          if (p.kind != 'bus_stop' || p.roadX == null) continue;
          final d = (p.x - game.avatar.x) * (p.x - game.avatar.x) + (p.y - game.avatar.y) * (p.y - game.avatar.y);
          if (d >= bd) continue;
          bd = d;
          final next = spectralBusNext(seed: world.field.seed, stopKey: placeKey(p.x, p.y), t: now + 30, b: data.mapTouch, localHourOf: (_) => 12);
          final (lat, lon) = tileFractionToLatLon(p.x, p.y, biomeZoom);
          best = (at: next.utc, lat: lat, lon: lon);
        }
      }
      return best;
    };
    tools.nextNpcTune = () {
      if (!game.avatar.hasPosition) return null;
      final now = tools.clock.nowUtc;
      VeilTune? best;
      for (var slot = 0; slot < 8 && best == null; slot++) {
        for (final v in veil.around(game.avatar.x, game.avatar.y, now + slot * 900, 150)) {
          for (final u in v.tunes) {
            if (u.atUtc > now + 5 && (best == null || u.atUtc < best.atUtc)) best = u;
          }
        }
      }
      if (best == null) return null;
      final (lat, lon) = tileFractionToLatLon(best.eco.x, best.eco.y, biomeZoom);
      return (at: best.atUtc, lat: lat, lon: lon);
    };
    var forced = tools.forceNpcs;
    if (_npcListener case final l?) tools.removeListener(l);
    tools.addListener(_npcListener = () {
      if (tools.forceNpcs == forced) return;
      forced = tools.forceNpcs;
      veil.clear();
    });
    game.veil = veil;
    game.touchBalance = data.mapTouch;
    game.manyBuses = () => tools.manyBuses;
    world.sandbox = () => tools.sandboxed;
    _patrol = PatrolHooks(state: session.state, balance: data.patrol, nowUtc: () => tools.clock.nowUtc, onMessage: _toast, onFocus: (m) => _startEncounter(m.toSpawn()));
    _pocket.addListener(_pocketFps);
    PatrolController.instance.addListener(_pocketFps);
    world.travelPickupM = () => travel.pickupBonusM;
    game.travelLayer = TravelLayer(travel, carM: assets.balance.ghostCarM);
    // 0.24.5 (Veículos do Véu): a faixa do modo trânsito escolhe o desenho; os limites são os do Modo Viagem.
    game.rideBand = () => rideBandOf(
          speedMps: game.avatar.speedMps,
          walkMaxMps: data.travel.vehicles[Vehicle.foot]!.maxMps,
          bikeMaxMps: data.travel.vehicles[Vehicle.bike]!.maxMps,
          travel: travel.traveling ? travel.vehicle : null,
        );
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
    world.onRitualTarget = _startRitual;
    world.onCollected = game.onCollected;
    world.onBagFull = _onBagFull;
    unawaited(UiArt.load()); // os ícones dos coletores plantados no mapa
    unawaited(CreatureArt.loadAll(widget.bundle)); // 0.25.0: as criaturas com arte animada
    unawaited(TrafficArt.load(widget.bundle)); // 0.25.1: o tráfego e as Fagulhas do Aseprite
    unawaited(SparkArt.load(widget.bundle));
    world.onShiny = _onShiny;
    world.onEnteredRange = _onEnteredRange;
    _climate = ClimateDriver(data: data, world: climate, online: () => session.state.setting('weather_online'));
    tools.force.rainbowFoot = () => _ready == null ? null : _rainbowFoot(_ready!);
    climate.debugArcs.addAll(tools.force.tapArcs);
    unawaited(_climate!.loadEvents().then((_) => game.matchUtc = _climate!.matchUtc));
    game.climateFx
      .onThunder = _scheduleThunder;
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
    if (identical(_live, this)) _live = null;
    _closed.complete();
    WidgetsBinding.instance.removeObserver(this);
    if (!_restarting) unawaited(WakelockPlus.disable().catchError((_) {}));
    tools.removeListener(_rebuild);
    if (_npcListener case final l?) tools.removeListener(l);
    tools.clock.removeListener(_rebuild);
    tools.force.rainbowFoot = null;
    tools.force.tapArcs
      ..clear()
      ..addAll(_climate?.world.debugArcs ?? const []);
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
            planted: PlantedList(state: r.session.state, data: r.data, ctx: _craftContext(r)),
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
            planted: PlantedList(state: r.session.state, data: r.data, ctx: _craftContext(r)),
          ),
        PhoneAppId.patrol => PatrolScreen(state: r.session.state, balance: r.data.patrol, onMessage: _toast),
        PhoneAppId.sky => SkyScreen(
            nowUtc: () => tools.clock.nowUtc,
            lat: () => r.game.playerLat,
            catalog: r.data.climates,
            shown: streetLifeEnabled ? () => _climate!.info : null,
            outlook: streetLifeEnabled ? cellSkyOutlook(_climate!.world, lat: () => r.game.playerLat, lon: () => r.game.playerLon, catalog: r.data.climates) : null,
            calendar: streetLifeEnabled ? (now) => nextCalendarItems(world: _climate!.world, catalog: r.data.climates, nowUtc: now) : null,
            prisms: () => r.session.state.count(dewPrismId),
            usePrism: streetLifeEnabled ? () => _usePrism(r) : null,
          ),
        PhoneAppId.settings => _settings(r),
        _ => null,
      };

  /// O Prisma de orvalho na posição do Conjurador: só se gasta com um arco-íris ativo.
  PrismReading? _usePrism(_Ready r) {
    final (x, y) = latLonToTileFraction(r.game.playerLat, r.game.playerLon, biomeZoom);
    return useDewPrism(world: _climate!.world, take: () => r.session.state.take(dewPrismId), x21: x, y21: y, t: tools.clock.nowUtc, metersPerCell21: metersPerCell(r.game.playerLat), searchM: r.data.climateBalance.prismSearchM);
  }

  /// Debug: o "Ir até o pé do arco-íris" pedido com o mapa fechado. Espera alguns segundos pelo pacote (o pé vai para a
  /// rua) e desiste com aviso se não houver arco.
  int _rainbowJumpTries = 0;
  void _pendingRainbowJump(_Ready r) {
    final p = _rainbowFoot(r);
    if (p == null && ++_rainbowJumpTries < 5) return;
    tools.force.rainbowJumpPending = false;
    _rainbowJumpTries = 0;
    if (p == null) return _toast('Nenhum arco-íris ativo por perto', seconds: 3);
    tools.simulator.teleport(p.$1, p.$2);
    _toast('No pé do arco-íris', seconds: 3);
  }

  /// Debug: o pé do arco-íris ativo mais perto do Conjurador (latitude, longitude), ou `null`.
  (double, double)? _rainbowFoot(_Ready r) {
    final (x, y) = latLonToTileFraction(r.game.playerLat, r.game.playerLon, biomeZoom);
    final arcs = _climate?.world.rainbowsNear(x, y, r.data.climateBalance.prismSearchM / metersPerCell(r.game.playerLat), tools.clock.nowUtc) ?? const [];
    if (arcs.isEmpty) return null;
    double d(RainbowArc a) => (a.footX - x) * (a.footX - x) + (a.footY - y) * (a.footY - y);
    final a = arcs.reduce((p, q) => d(p) <= d(q) ? p : q);
    return tileFractionToLatLon(a.footX, a.footY, biomeZoom);
  }

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
      ?_stackLine(r),
    ];
  }

  /// Época 12: a pilha do clima no lugar (clima, eventos com a origem, combinações), quando há evento ou algo forçado.
  String? _stackLine(_Ready r) {
    final cw = _climate?.world;
    if (cw == null || !r.game.avatar.hasPosition) return null;
    final (cx, cy) = latLonToTile(r.game.playerLat, r.game.playerLon, 20);
    final now = tools.clock.nowUtc;
    final cause = cw.causeAt(cx, cy, now);
    final forced = tools.force.weather != null || tools.force.events.isNotEmpty;
    return stackLine(cause, r.data.climates, cw.modelAt(now)?.$2, forced: forced);
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
    // 0.23.2: na tela cheia o HUD sobe até o topo e só desvia do furo da câmera (`displayFeatures`); o Android declara a faixa
    // inteira da barra de status como recorte, e era ela que ficava preta. Com as barras à vista, vale a barra de status.
    final barsShown = st.setting(kSystemBarsSetting);
    final hole = barsShown
        ? null
        : MediaQuery.displayFeaturesOf(context).where((f) => f.type == ui.DisplayFeatureType.cutout && f.bounds.top <= 1).map((f) => f.bounds).firstOrNull;
    final hud = hudLayout(
      screen,
      top: hole != null ? 0 : pad.top,
      bottom: pad.bottom,
      trackerMax: 0, // sem rastreador fixo: o atalho do Radar fica no canto (as marcas do pulso vão na borda da tela)
      marks: st.activeMarks(now).length,
      shortcuts: patrolOn || travelChip != null,
      compass: true, // a vaga da bússola fica reservada: ela aparece e some sem empurrar nada
      radar: _radarUnlocked(r),
      simulator: tools.useSimulator,
    );
    // 0.23.1: o mapa e o céu começam embaixo da barra do HUD e terminam acima da barra de navegação (com as barras do Android
    // à vista); nada do mapa desenha por baixo da barra do HUD nem das do sistema. O que o jogo desenha nas vagas do HUD
    // (lua, Sol Negro) vem para as coordenadas do mapa.
    final mapTop = hud.bar.bottom;
    game.skyRects = {for (final e in hud.sky.entries) e.key: e.value.shift(Offset(0, -mapTop))};
    final warnings = _warnings(r);
    return Stack(
      children: [
        const SizedBox.expand(), // a tela inteira: o mapa agora é posicionado e não dá mais o tamanho da pilha
        Positioned(left: 0, right: 0, top: mapTop, bottom: pad.bottom, child: Listener(
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
            child: ClipRect(child: GameWidget(game: game)), // o Flame não recorta: sem isto o mapa passa por cima da barra
          ),
        )),
        // As zonas fixas do HUD (`hud_layout.dart`): nada aqui cobre outra peça em nenhum tamanho de tela comum.
        Positioned.fromRect(
          rect: hud.bar,
          child: HudBar(
            nowUtc: () => tools.clock.nowUtc,
            lat: () => game.playerLat,
            weather: streetLifeEnabled ? () => _climate!.info : null,
            onSky: () => _openApp(r, PhoneAppId.sky),
            seal: ModeSeal(tools: tools, source: r.layers.source, onTap: () => _openModeSheet(r)),
            battery: const SystemBridge().batteryLevel,
            hole: hole?.shift(-hud.bar.topLeft),
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
                craft: () => _craftContext(r),
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

/// O mapa do jogo vivo agora (um só), e quando ele termina de fechar.
_GameMapScreenState? _live;

/// O save do mapa aberto agora, ou `null`: o debug grava nele em vez de gravar por baixo (o mapa sobrescreveria).
GameState? liveGameState() => _live?._ready?.session.state;

/// Abre o mapa do jogo pelo debug sem empilhar outro: se já há um mapa na pilha, volta até ele; se um mapa ainda está
/// saindo (a animação de voltar ao menu), espera ele fechar e só então abre o novo.
Future<void> openGameMap(BuildContext context, DevTools tools) async {
  final nav = Navigator.of(context);
  final live = _live;
  final route = live?._route;
  if (live != null && live.mounted && route != null && route.isActive) {
    nav.popUntil((r) => r == route);
    return;
  }
  // Um mapa que ainda sai: espera ele fechar (no máximo 2 s; um que já saiu da árvore não conta).
  if (live != null && live.mounted) await live._closed.future.timeout(const Duration(seconds: 2), onTimeout: () {});
  if (!nav.mounted) return;
  await nav.push(MaterialPageRoute<void>(builder: (_) => GameMapScreen(tools: tools, openStore: KsvSaveStore.inDocuments)));
}
