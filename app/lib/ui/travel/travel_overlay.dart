/// O Modo Viagem na tela: o botão do HUD, a escolha de destino e de veículo, os atalhos do Uber e da 99, o painel da
/// corrida, o Rádio do Véu e o baú. Só desenha e repassa toques: a lógica é de `travel/travel_session.dart`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../../travel/deep_links.dart';
import '../../travel/place_search.dart';
import '../../travel/ride.dart';
import '../../travel/system_bridge.dart';
import '../../travel/travel_balance.dart';
import '../../travel/travel_session.dart';
import '../colors.dart';
import '../pressable.dart';
import '../settings/ride_notifications_screen.dart' show kRideNotifySetting;
import '../tuning/tuning_screen.dart' show PixelButton;

const _body = TextStyle(fontSize: 8, color: kText, height: 1.8);
const _dim = TextStyle(fontSize: 8, color: kDim, height: 1.8);

class TravelOverlay extends StatefulWidget {
  const TravelOverlay({
    required this.travel,
    required this.state,
    required this.data,
    required this.appVersion,
    required this.playerLat,
    required this.playerLon,
    required this.onMessage,
    this.bridge = const SystemBridge(),
    super.key,
  });

  final TravelSession travel;
  final GameState state;
  final GameData data;

  /// Vai no User-Agent da busca, e nada mais.
  final String appVersion;
  final double Function() playerLat;
  final double Function() playerLon;
  final void Function(String message, {int seconds}) onMessage;
  final SystemBridge bridge;

  @override
  State<TravelOverlay> createState() => _TravelOverlayState();
}

class _TravelOverlayState extends State<TravelOverlay> {
  TravelSession get travel => widget.travel;
  TravelBalance get b => widget.data.travel;

  late final _search = PlaceSearch(appVersion: widget.appVersion, minIntervalS: b.searchMinIntervalS, viewboxDeg: b.searchViewboxDeg, limit: b.searchLimit, timeoutS: b.searchTimeoutS);
  StreamSubscription<Object?>? _rideSub;
  Future<List<bool>>? _installed;
  late int _etaMin = b.etaDefaultMin;

  @override
  void initState() {
    super.initState();
    travel.addListener(_onChange);
  }

  @override
  void dispose() {
    travel.removeListener(_onChange);
    _stopRelay();
    super.dispose();
  }

  void _onChange() {
    if (travel.stage == TravelStage.idle) {
      _installed = null; // o jogador pode ter instalado o app entre uma viagem e outra
      _etaMin = b.etaDefaultMin;
    }
    final want = travel.ride != null && widget.state.setting(kRideNotifySetting);
    if (want && _rideSub == null) {
      unawaited(widget.bridge.setRideRelay(true));
      _rideSub = widget.bridge.rideNotifications().listen((n) => travel.onNotification(n.package, n.title, n.text));
    } else if (!want && _rideSub != null) {
      _stopRelay();
    }
    if (mounted) setState(() {});
  }

  void _stopRelay() {
    if (_rideSub == null) return;
    unawaited(_rideSub!.cancel());
    _rideSub = null;
    unawaited(widget.bridge.setRideRelay(false));
  }

  Future<void> _openSearch() async {
    final place = await showDialog<Place>(
      context: context,
      builder: (_) => _SearchDialog(search: _search, lat: widget.playerLat(), lon: widget.playerLon()),
    );
    if (place != null) travel.choosePlace(place);
  }

  Future<void> _callUber() async {
    final ok = await widget.bridge.openUrl(uberDeepLink(lat: travel.destLat!, lon: travel.destLon!, nickname: travel.destName));
    if (ok) {
      travel.startRide('Uber', kUberPackage);
    } else {
      widget.onMessage('Não consegui abrir o Uber');
    }
  }

  Future<void> _call99() async {
    final link = taxi99DeepLink(lat: travel.destLat!, lon: travel.destLon!, nickname: travel.destName);
    if (link == null) {
      final isPoint = travel.destName == kMapPointName;
      final address = isPoint ? '${travel.destLat!.toStringAsFixed(6)}, ${travel.destLon!.toStringAsFixed(6)}' : travel.destName;
      await Clipboard.setData(ClipboardData(text: address));
      widget.onMessage('Destino copiado: cole no 99', seconds: 5);
    }
    final ok = link == null ? await widget.bridge.launchPackage(k99Package) : await widget.bridge.openUrl(link);
    if (ok) {
      travel.startRide('99', k99Package);
    } else {
      widget.onMessage('Não consegui abrir o 99');
    }
  }

  @override
  Widget build(BuildContext context) {
    final panel = switch (travel.stage) {
      TravelStage.idle => null,
      TravelStage.pickDestination => _pickDestination(),
      TravelStage.pickVehicle => _pickVehicle(),
      TravelStage.askPassenger => _askPassenger(),
      TravelStage.traveling => _traveling(),
      TravelStage.done => _outcome(),
    };
    return Stack(children: [
      if (travel.stage == TravelStage.idle)
        Positioned(
          right: 8,
          bottom: 8,
          child: Pressable(
            key: const Key('travel-hud'),
            onTap: travel.open,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.85), border: Border.all(color: kSignal, width: 2)),
              child: const Text('VIAGEM', style: TextStyle(fontSize: 8, color: kSignal)),
            ),
          ),
        ),
      if (panel != null) Positioned(left: 8, right: 8, bottom: 72, child: _Panel(child: panel)),
    ]);
  }

  Widget _pickDestination() => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('TOQUE NO MAPA PARA ESCOLHER O DESTINO, OU BUSQUE UM LUGAR.', style: _body),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          PixelButton(label: 'Buscar', color: kSignal, onTap: _openSearch),
          PixelButton(label: 'Cancelar', color: kDim, onTap: travel.cancel),
        ]),
      ]);

  Widget _pickVehicle() => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('DESTINO: ${travel.destName}'.toUpperCase(), style: _body, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in Vehicle.values) PixelButton(label: v.label, color: kSignal, onTap: () => travel.chooseVehicle(v)),
          PixelButton(label: 'Cancelar', color: kDim, onTap: travel.cancel),
        ]),
      ]);

  Widget _askPassenger() {
    final isCar = travel.vehicle == Vehicle.car;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('VOCÊ VAI DE PASSAGEIRO? QUEM DIRIGE SÓ TEM A VIAGEM GRAVADA: O JOGO NUNCA RECOMPENSA DIRIGIR.', style: _body),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        PixelButton(label: 'Sou passageiro', color: kSignal, onTap: () => travel.answerPassenger(true)),
        PixelButton(label: 'Estou dirigindo', color: kEssence, onTap: () => travel.answerPassenger(false)),
        if (isCar)
          FutureBuilder<List<bool>>(
            future: _installed ??= Future.wait([widget.bridge.isInstalled(kUberPackage), widget.bridge.isInstalled(k99Package)]),
            builder: (context, snap) {
              final apps = snap.data ?? const [false, false];
              return Wrap(spacing: 8, runSpacing: 8, children: [
                if (apps[0]) PixelButton(label: 'Chamar Uber', color: kVeil, onTap: _callUber),
                if (apps[1]) PixelButton(label: 'Chamar 99', color: kVeil, onTap: _call99),
              ]);
            },
          ),
        PixelButton(label: 'Cancelar', color: kDim, onTap: travel.cancel),
      ]),
    ]);
  }

  Widget _traveling() {
    final ride = travel.ride;
    final km = (travel.recordedM / 1000).toStringAsFixed(1);
    final line = travel.radioLine(travel.nowUtc());
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (travel.driver)
        Text('VIAGEM GRAVADA · $km KM', style: _body)
      else if (ride != null && ride.state != RideState.inTrip)
        ..._rideStatus(ride)
      else
        Text('${(travel.destName.isEmpty ? 'Corrida do ${ride?.appName ?? ''}' : travel.destName).toUpperCase()} · ${travel.routeStatus}', style: _dim, maxLines: 3, overflow: TextOverflow.ellipsis),
      if (line != null) ...[
        const SizedBox(height: 4),
        Text('RÁDIO DO VÉU', style: _dim.copyWith(color: kVeil)),
        Text(line.text, style: _body),
      ],
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (ride != null)
          for (final button in ride.buttons)
            switch (button) {
              RideButton.eta => _etaStepper(),
              RideButton.boarded => PixelButton(label: 'Entrei', color: kSignal, onTap: travel.onRideBoarded),
              RideButton.arrived => PixelButton(label: 'Cheguei', color: kSignal, onTap: travel.onRideArrived),
            },
        PixelButton(label: 'Encerrar', color: kDim, onTap: travel.cancel),
      ]),
    ]);
  }

  List<Widget> _rideStatus(Ride ride) {
    final left = ride.etaDueUtc == null ? null : ((ride.etaDueUtc! - travel.nowUtc()) / 60).ceil();
    final text = switch (ride.state) {
      RideState.searching => 'PROCURANDO MOTORISTA NO ${ride.appName}. QUANDO O APP MOSTRAR O TEMPO DE CHEGADA, INFORME AQUI.',
      RideState.driverComing => left == null ? 'MOTORISTA A CAMINHO.' : 'MOTORISTA A CAMINHO: CHEGA EM ${left < 1 ? 1 : left} MIN.',
      RideState.arrived => 'O CARRO CHEGOU. TOQUE EM ENTREI QUANDO EMBARCAR.',
      _ => 'VOCÊ CHEGOU.',
    };
    return [Text(text.toUpperCase(), style: _body)];
  }

  Widget _etaStepper() => Row(mainAxisSize: MainAxisSize.min, children: [
        Pressable(
          onTap: () => setState(() => _etaMin = (_etaMin - 1).clamp(1, b.etaMaxMin)),
          child: const SizedBox(width: 48, height: 48, child: Center(child: Text('-', style: TextStyle(fontSize: 16, color: kSignal)))),
        ),
        Text('$_etaMin MIN', style: const TextStyle(fontSize: 8, color: kText)),
        Pressable(
          onTap: () => setState(() => _etaMin = (_etaMin + 1).clamp(1, b.etaMaxMin)),
          child: const SizedBox(width: 48, height: 48, child: Center(child: Text('+', style: TextStyle(fontSize: 16, color: kSignal)))),
        ),
        PixelButton(label: 'Ok', color: kSignal, onTap: () => travel.onRideEta(_etaMin)),
      ]);

  Widget _outcome() {
    final o = travel.outcome!;
    final km = (o.distanceM / 1000).toStringAsFixed(1);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(o.chest ? 'BAÚ DA VIAGEM' : 'FIM DA VIAGEM', style: const TextStyle(fontSize: 16, color: kEssence)),
      const SizedBox(height: 8),
      Text('$km KM', style: _body),
      if (o.driver) const Text('VIAGEM GRAVADA. DIRIGIR NÃO RENDE NADA NO VÉU.', style: _dim),
      if (o.sparks > 0) Text('+${o.sparks} ${widget.data.itemName(o.itemId!)}'.toUpperCase(), style: _body),
      if (o.chest && o.sparks == 0 && !o.capped) const Text('O CAMINHO FOI CURTO DEMAIS PARA RENDER FAGULHAS.', style: _dim),
      if (o.capped) const Text('O BAÚ JÁ DEU TUDO O QUE PODIA HOJE.', style: _dim),
      if (o.marks.isNotEmpty) ...[
        const SizedBox(height: 4),
        const Text('ECOS MARCADOS NA VIAGEM:', style: _dim),
        for (final m in o.marks) Text('${widget.data.species(m.speciesId)?.name ?? m.speciesId} · NV ${m.level}'.toUpperCase(), style: _body),
      ],
      const SizedBox(height: 8),
      PixelButton(label: 'Fechar', color: kSignal, onTap: travel.closeOutcome),
    ]);
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.92), border: Border.all(color: kVeil, width: 3)),
        child: child,
      );
}

/// A busca por nome. Sem rede avisa, e o toque no mapa continua valendo.
class _SearchDialog extends StatefulWidget {
  const _SearchDialog({required this.search, required this.lat, required this.lon});

  final PlaceSearch search;
  final double lat;
  final double lon;

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final _field = TextEditingController();
  List<Place> _results = const [];
  String? _note;
  bool _busy = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final q = _field.text.trim();
    if (q.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _note = null;
    });
    final found = await widget.search.search(q, lat: widget.lat, lon: widget.lon);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _results = found ?? const [];
      _note = found == null ? 'Sem rede. Feche e toque no mapa para escolher o destino.' : (found.isEmpty ? 'Nada encontrado.' : null);
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: kPanel,
        shape: const RoundedRectangleBorder(side: BorderSide(color: kSignal, width: 3)),
        title: const Text('BUSCAR LUGAR', style: TextStyle(fontSize: 16, color: kSignal)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: _field, autofocus: true, style: const TextStyle(fontSize: 16), textInputAction: TextInputAction.search, onSubmitted: (_) => _run()),
            const SizedBox(height: 8),
            PixelButton(label: _busy ? 'Buscando' : 'Buscar', color: kSignal, onTap: _run),
            if (_note != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_note!.toUpperCase(), style: _dim)),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final p in _results)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name, style: _body, maxLines: 3, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.of(context).pop(p),
                  ),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('FECHAR', style: TextStyle(fontSize: 8, color: kDim))),
        ],
      );
}
