import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../dev/dev_tools.dart';
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
  const GameMapScreen({required this.tools, this.gateway = const GeolocatorGateway(), this.bundle, super.key});

  final DevTools tools;

  /// De onde vem a permissão de localização. Por padrão, o geolocator.
  final LocationGateway gateway;

  /// De onde vêm os assets. Por padrão, os do app.
  final AssetBundle? bundle;

  @override
  State<GameMapScreen> createState() => _GameMapScreenState();
}

class _Ready {
  _Ready(this.assets, this.game, this.tracker, this.sub);

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

  DevTools get tools => widget.tools;

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
    final result = await loadMapAssets(nowUtc: tools.clock.nowUtc, bundle: widget.bundle);
    if (result is String) return result;
    final assets = result as MapAssets;
    final game = GameMapGame(renderer: assets.makeRenderer(), auraM: assets.balance.auraM);
    final tracker = PlayerTracker(source: tools.source);
    final sub = tracker.states.listen((s) {
      game.onPlayerState(s);
      _rebuild();
    });
    _ready = _Ready(assets, game, tracker, sub);
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
      ready.tracker.stop(); // só com o app aberto
    } else if (state == AppLifecycleState.resumed) {
      _ensureAccess(); // o jogador pode ter mexido nos ajustes
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
    }
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
    final blocked = _access != null && _access != LocationAccess.granted && !tools.useSimulator;
    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            if (_pointers++ == 0) game.touchStart();
          },
          onPointerUp: (_) {
            if (--_pointers <= 0) {
              _pointers = 0;
              game.touchEnd();
            }
          },
          onPointerCancel: (_) {
            if (--_pointers <= 0) {
              _pointers = 0;
              game.touchEnd();
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleUpdate: (d) => game.gesture(dx: d.focalPointDelta.dx, dy: d.focalPointDelta.dy, scale: d.scale),
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
