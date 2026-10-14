import 'dart:async';

import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/fnv.dart';
import '../../core/pcg32.dart';
import '../../data/game_data.dart';
import '../../dev/dev_tools.dart';
import '../../player/game_session.dart';
import '../../save/save_store.dart';
import '../../world/spawn_field.dart';
import '../../world/world_view.dart';
import '../collection/collection_screen.dart';
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
import 'game_map_game.dart';
import 'sim_overlay.dart';

/// O mapa do jogo (M5): o Conjurador anda com o GPS e a câmera o segue, com a Aura no chão. Arrastar
/// espia em volta e a câmera volta sozinha depois de 3 s sem toque; pinça dá zoom numa faixa de jogo.
///
/// A posição vem de `tools.source`: o GPS real (pedindo a permissão com uma explicação curta) ou o
/// simulador do menu de debug, que entra no lugar sem o resto do código saber.
class GameMapScreen extends StatefulWidget {
  const GameMapScreen({required this.tools, this.gateway = const GeolocatorGateway(), this.bundle, this.store, this.openStore, this.vibration, this.headingSource, super.key});

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
  Offset? _tapStart;
  Duration _tapAt = Duration.zero;

  DevTools get tools => widget.tools;

  Future<SaveStore> _store() async {
    if (widget.store != null) return widget.store!;
    try {
      return await widget.openStore?.call() ?? MemorySaveStore();
    } catch (_) {
      return MemorySaveStore(); // sem pasta de documentos
    }
  }

  /// Liga ou desliga a leitura da bússola do celular, só enquanto o "seguir direção" está ligado.
  void _setFollowHeading(bool on) {
    _headingSub?.cancel();
    _headingSub = null;
    final game = _ready?.game;
    if (!on || game == null) return;
    _headingSub = (widget.headingSource ?? const CompassHeadingSource()).headings.listen(game.setHeading);
  }

  /// Aviso curto no alto da tela ("+1 Pó de Essência de Fogo").
  void _toast(String message) {
    if (!mounted) return;
    _toastTimer?.cancel();
    _headingSub?.cancel();
    setState(() => _toastText = message);
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toastText = null);
    });
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
        _toast(r.world.inAura(spawn) ? 'A Aura pega sozinha' : 'Entre na Aura para pegar a Fagulha');
      case TouchResult.tooFar:
        _toast('Longe demais. Chegue com a Aura até lá (${r.world.distanceM(spawn).round()} m)');
      case TouchResult.encounter:
        _busy = true;
        try {
          await runEncounter(context, eco: spawn, world: r.world, state: r.session.state, data: r.data, nowUtc: () => tools.clock.nowUtc, vibration: widget.vibration);
        } finally {
          _busy = false;
        }
        if (mounted) setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    final ui.Image playerSprite;
    try {
      data = await GameData.load(widget.bundle);
      playerSprite = await loadPlayerSprite();
      for (final s in data.tuning.species) {
        sprites[s.id] = (await EcoSprite.load(s.id)).normal;
      }
      session = await GameSession.open(
        store: await _store(),
        startInventory: data.startInventory,
        nowUtc: () => tools.clock.nowUtc,
        nextInt: Pcg32(fnv1a64([DateTime.now().microsecondsSinceEpoch]), saltKenoma).nextInt, // só sorteia o código do grupo
      );
    } catch (e) {
      assets.dispose();
      return 'Não consegui ler os dados do jogo: $e';
    }
    final world = WorldView(
      field: SpawnField(seed: session.state.seed, schedule: data.schedule, map: assets.map),
      state: session.state,
      auraM: assets.balance.auraM,
      viewM: assets.balance.viewM,
      itemName: data.itemName,
      onMessage: _toast,
    );
    final game = GameMapGame(
      renderer: assets.makeRenderer(),
      visual: assets.visual!,
      style: ArtStyle(assets.biomes),
      balance: assets.balance,
      playerSprite: playerSprite,
      overlayBiomes: () => tools.showBiomeGrid,
      overlayGrid20: () => tools.showGrid20,
      auraM: assets.balance.auraM,
      defaultWidthM: assets.balance.defaultWidthM,
      minWidthM: assets.balance.zoomMinWidthM,
      maxWidthM: assets.balance.zoomMaxWidthM,
      playerHeightFraction: assets.balance.playerHeightFraction,
      trackerM: assets.balance.trackerM,
      trackerMax: assets.balance.trackerMax,
      declinationDeg: assets.balance.compassDeclinationDeg,
      dpr: dpr,
      worldView: world,
      sprites: sprites,
      typeOf: (id) => data.species(id)?.type,
      nowUtc: () => tools.clock.nowUtc,
    );
    final tracker = PlayerTracker(source: tools.source);
    final sub = tracker.states.listen((s) {
      game.onPlayerState(s);
      _rebuild();
    });
    game.onFollowHeading = _setFollowHeading;
    _ready = _Ready(assets, game, tracker, sub, data, session, world);
    // O acesso é pedido depois do primeiro quadro: o diálogo precisa de uma tela montada.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureAccess());
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
            if (_pointers++ == 0) {
              game.touchStart();
              _tapStart = e.localPosition;
              _tapAt = e.timeStamp;
            } else {
              _tapStart = null; // dois dedos: pinça, não toque
            }
          },
          onPointerMove: (e) {
            final start = _tapStart;
            if (start != null && (e.localPosition - start).distance > 18) _tapStart = null;
          },
          onPointerUp: (e) {
            final start = _tapStart;
            if (start != null && e.timeStamp - _tapAt < const Duration(milliseconds: 500)) _onTap(e.localPosition);
            _tapStart = null;
            if (--_pointers <= 0) {
              _pointers = 0;
              game.touchEnd();
            }
          },
          onPointerCancel: (_) {
            _tapStart = null;
            if (--_pointers <= 0) {
              _pointers = 0;
              game.touchEnd();
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => game.gestureStart(),
            onScaleUpdate: (d) => game.gesture(dx: d.focalPointDelta.dx, dy: d.focalPointDelta.dy, scale: d.scale, turn: d.rotation),
            child: GameWidget(game: game),
          ),
        ),
        SafeArea(
          child: Stack(
            children: [
              _StatusHud(state: r.tracker.state, tools: tools, stale: r.assets.stale),
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
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CollectionScreen(state: r.session.state, data: r.data))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.85), border: Border.all(color: kVeil, width: 2)),
                    child: const Text('COLEÇÃO', style: TextStyle(fontSize: 8, color: kVeil)),
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
