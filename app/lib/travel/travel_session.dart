/// O Modo Viagem de ponta a ponta: destino, veículo, rota, marcação automática, Rádio do Véu, corrida e baú. Vive só na
/// memória: fechar o app perde a viagem em curso, e o save não muda de formato. A tela e o mapa só leem daqui e repassam
/// toques, GPS e notificações. Dart puro (o `ChangeNotifier` é o mesmo do `GameState`).
///
/// O jogo nunca recompensa dirigir: com [driver] ligado a viagem só grava a distância. Sem marcação, sem Rádio, sem baú, e
/// o [quiet] cala o mundo (coleta, fuga, vibração, folha do Agressivo).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../core/fnv.dart';
import '../core/pcg32.dart';
import '../core/species_ids.dart' show isRitualOnlyId;
import '../core/tiles.dart';
import '../player/game_state.dart';
import '../player/mark.dart';
import '../player/progression.dart' show localDay;
import '../story/mentor_script.dart';
import '../world/spawn_field.dart';
import '../world/traffic_graph.dart';
import 'notification_parser.dart';
import 'place_search.dart';
import 'ride.dart';
import 'travel_balance.dart';
import 'travel_path.dart';
import 'trip.dart';

enum TravelStage { idle, pickDestination, pickVehicle, askPassenger, traveling, done }

/// O nome do destino escolhido por toque: não é endereço.
const String kMapPointName = 'Ponto no mapa';

final int _saltRide = salt('RIDE');

/// Qual fala do Rádio está no ar em [tUtc]: um rodízio com ponto de partida tirado da seed e do começo da viagem.
int radioIndex({required int seed, required int startUtc, required int tUtc, required int lineS, required int count}) {
  final offset = (fnv1a64([seed, startUtc, _saltRide]) >>> 33) % count;
  return (offset + (tUtc - startUtc) ~/ lineS) % count;
}

class TravelSession extends ChangeNotifier {
  TravelSession({
    required this.state,
    required this.balance,
    required this.graph,
    required this.patterns,
    required this.radioLines,
    required this.sparkItem,
    required this.ecosInReach,
    required this.nowUtc,
    this.highway,
    this.access,
  });

  /// Rodovias e vias expressas: fora da rota a pé e de bicicleta. `null`: sem esse dado.
  final bool Function(GhostLine)? highway;

  /// Os bits de acesso de cada trecho (`accessTest`), do arquivo de rota. `null`: sem ele.
  final int Function(GhostLine, int)? access;
  final GameState state;
  final TravelBalance balance;
  final TrafficGraph graph;
  final RidePatterns patterns;
  final List<MentorMessage> radioLines;

  /// A Fagulha do baú no destino, ou `null` se a época não tem nenhuma.
  final String? Function(double lat, double lon, int tUtc) sparkItem;

  /// Os Ecos à vista a até `auto_mark_m`.
  final Iterable<WorldSpawn> Function() ecosInReach;
  final int Function() nowUtc;

  TravelStage stage = TravelStage.idle;

  /// O destino, em células z21 e em graus, e o nome que vai para o deep link e para a área de transferência.
  double? destX, destY, destLat, destLon;
  String destName = '';

  Vehicle vehicle = Vehicle.foot;

  /// `false` só para quem disse que dirige.
  bool passenger = true;

  /// A rota. `null` enquanto calcula ou sem grafo: o mapa desenha a reta tracejada.
  TravelPath? route;
  bool routing = false;

  /// Quanto falta pela rota, em metros, do ponto dela mais perto do jogador. `null` sem rota.
  double? get routeLeftM {
    final r = route;
    if (r == null || !_hasFix) return r?.lengthM;
    return math.max(0, r.lengthM - r.locate(_x, _y).alongM);
  }

  /// A linha da rota na tela: o que falta e o tempo estimado, ou por que não há rota. Fora dos dados, o aviso.
  String get routeStatus {
    if (destX == null) return 'SEM DESTINO';
    if (routing) return 'CALCULANDO ROTA';
    final left = routeLeftM, eta = routeEtaS, r = route;
    if (left == null || eta == null || r == null) return 'SEM ROTA, SÓ A DIREÇÃO';
    final km = (left / 1000).toStringAsFixed(1).replaceFirst('.', ',');
    final min = math.max(1, (eta / 60).round());
    return 'FALTAM $km KM · ~$min MIN${r.offData ? ' · O DESTINO ESTÁ FORA DO MAPA: O FIM É EM LINHA RETA' : ''}';
  }

  /// O tempo estimado do que falta, na velocidade média do veículo (`route_kmh`). `null` sem rota.
  int? get routeEtaS {
    final left = routeLeftM;
    return left == null ? null : (left / balance.vehicles[vehicle]!.routeMps).round();
  }

  /// A corrida de Uber ou 99, se a viagem veio por um desses botões.
  Ride? ride;
  String? _ridePackage;
  RideApproach? approach;

  /// Os Ecos marcados nesta viagem, e o fim dela.
  final List<Mark> tripMarks = [];
  TripOutcome? outcome;

  TripRecorder? _trip;
  ArrivalWatch? _arrival;
  int _startUtc = 0;
  int _rideUtc = 0;
  int _token = 0;
  int _carToken = 0;
  double _x = 0, _y = 0, _mpc = 1, _heading = 0;
  bool _hasFix = false;
  double _pickupBonusM = 0;
  double _boardEnd = 0;
  int _routedUtc = -1 << 40;
  TravelPath? _leave;
  double _leaveT = 0;
  bool _approachBusy = false;

  bool get traveling => stage == TravelStage.traveling;

  /// A distância gravada até agora, em metros.
  double get recordedM => _trip?.recordedM ?? 0;

  /// Está numa viagem motorizada de verdade: a corrida só conta depois do embarque.
  bool get quiet => traveling && vehicle.passive && (ride == null || ride!.state == RideState.inTrip);

  /// Dirigindo: só grava. Nada de recompensa.
  bool get driver => quiet && !passenger;

  /// O Rádio do Véu no ar.
  bool get radioOn => quiet && passenger && radioLines.isNotEmpty;

  /// A largura da tela que a viagem pede. `null`: a normal.
  double? get viewWidthM => stage == TravelStage.pickDestination ? balance.pickViewM : (quiet ? balance.tripViewM : null);

  /// A velocidade que o marcador aceita. `null`: a normal, de quem anda.
  double? get avatarMaxMps => traveling ? balance.avatarMaxMps : null;

  /// O raio a mais de coleta das Fagulhas: a faixa da rota, de bicicleta, sem passar da velocidade aceita.
  double get pickupBonusM => _pickupBonusM;

  /// A fala do Rádio que está no ar em [tUtc].
  MentorMessage? radioLine(int tUtc) => !radioOn
      ? null
      : radioLines[radioIndex(seed: state.seed, startUtc: _startUtc, tUtc: tUtc, lineS: balance.radioLineS, count: radioLines.length)];

  /// Abre a escolha do destino.
  void open() {
    if (stage != TravelStage.idle) return;
    stage = TravelStage.pickDestination;
    notifyListeners();
  }

  /// Volta ao mapa normal. A viagem em curso acaba sem baú; as marcas ficam.
  void cancel() => _reset();

  /// Um toque no mapa em células z21. `true` se o toque virou destino.
  bool tapCell(double x, double y) {
    if (stage != TravelStage.pickDestination) return false;
    final (lat, lon) = tileFractionToLatLon(x, y, biomeZoom);
    _destination(x, y, lat, lon, kMapPointName);
    return true;
  }

  /// O jogador escolheu um lugar na busca.
  void choosePlace(Place p) {
    if (stage != TravelStage.pickDestination) return;
    final (x, y) = latLonToTileFraction(p.lat, p.lon, biomeZoom);
    _destination(x, y, p.lat, p.lon, p.name);
  }

  void _destination(double x, double y, double lat, double lon, String name) {
    destX = x;
    destY = y;
    destLat = lat;
    destLon = lon;
    destName = name;
    stage = TravelStage.pickVehicle;
    notifyListeners();
  }

  void chooseVehicle(Vehicle v) {
    if (stage != TravelStage.pickVehicle) return;
    vehicle = v;
    if (v.asksPassenger) {
      stage = TravelStage.askPassenger; // uma vez por viagem: hoje passageiro, amanhã ao volante
      notifyListeners();
    } else {
      answerPassenger(true);
    }
  }

  void answerPassenger(bool isPassenger) {
    passenger = isPassenger;
    _begin();
    _trip = _newTrip();
    notifyListeners();
  }

  /// A viagem vem do botão de um app de corrida: já é passageiro, sem pergunta, e só conta depois do embarque.
  void startRide(String appName, String package) {
    if (stage != TravelStage.askPassenger) return;
    passenger = true;
    ride = Ride(appName: appName);
    _ridePackage = package;
    _rideUtc = nowUtc();
    _begin();
    notifyListeners();
  }

  TripRecorder _newTrip() => TripRecorder(maxRewardMps: balance.vehicles[vehicle]!.maxMps, minStepM: balance.minStepM);

  void _begin() {
    stage = TravelStage.traveling;
    _startUtc = nowUtc();
    _arrival = ArrivalWatch(radiusM: balance.arrivalRadiusM, holdS: balance.arrivalHoldS, speedMps: balance.arrivalSpeedMps);
    unawaited(_findRoute(++_token));
  }

  Future<void> _findRoute(int token) async {
    if (!_hasFix || destX == null) return;
    _routedUtc = nowUtc();
    routing = true;
    notifyListeners();
    final r = await findRouteAsync(graph,
        fromX: _x,
        fromY: _y,
        toX: destX!,
        toY: destY!,
        rules: RouteRules(vehicle.profile, highway: highway, access: access),
        mpc: _mpc,
        snapM: balance.snapM,
        maxNodes: balance.maxNodes,
        sliceNodes: balance.sliceNodes);
    if (token != _token) return;
    route = r;
    routing = false;
    notifyListeners();
  }

  /// Uma posição nova: células z21 fracionárias, metros por célula, velocidade (m/s) e, andando, a direção (rad).
  void onPosition({required double x, required double y, required double mpc, required double speedMps, double? heading}) {
    final first = !_hasFix;
    _x = x;
    _y = y;
    _mpc = mpc;
    _heading = heading ?? _heading;
    _hasFix = true;
    if (!traveling) return;
    if (first && route == null) unawaited(_findRoute(_token));
    if (_recording) _trip?.add(x, y, mpc, nowUtc());
    final vb = balance.vehicles[vehicle]!;
    final r = route;
    // Saiu da rota: refaz de onde está, sem repetir a conta a cada leitura.
    if (r != null && !routing && nowUtc() - _routedUtc >= balance.rerouteMinS && r.distanceToM(x, y) > balance.offRouteM) {
      unawaited(_findRoute(++_token));
    }
    _pickupBonusM = vb.bandM > 0 && speedMps <= vb.maxMps && r != null && r.distanceToM(x, y) <= vb.bandM ? vb.bandM : 0;
  }

  bool get _recording => ride == null || ride!.state == RideState.inTrip;

  /// Uma vez por segundo. [speedMps] é a velocidade do marcador: parado, o GPS não entrega leituras.
  void tick({required double speedMps}) {
    if (!traveling) return;
    final now = nowUtc();
    final r = ride;
    if (r != null) {
      r.tick(now);
      if (r.state == RideState.finished) {
        if (now >= _leaveT + balance.leaveS) _settle();
        notifyListeners();
        return;
      }
    }
    if (_recording && _hasFix) {
      final d = math.sqrt(math.pow(_x - destX!, 2) + math.pow(_y - destY!, 2)) * _mpc;
      if (_arrival!.feed(distanceM: d, speed: speedMps, tUtc: now)) {
        if (r != null) {
          onRideArrived();
        } else {
          _settle();
        }
        return;
      }
    }
    if (quiet && passenger) _autoMark(now);
    notifyListeners();
  }

  /// Marca os Ecos que passam perto, com o limite de marcas de sempre. Os de ritual não respondem a marcação.
  void _autoMark(int now) {
    for (final s in ecosInReach()) {
      if (!s.isEco || isRitualOnlyId(s.entryId) || state.isDone(s.uid) || state.markOf(s.uid) != null) continue;
      final m = Mark.of(s, nowUtc: now, durationS: balance.markDurationS);
      if (!state.addMark(m, now)) return;
      tripMarks.add(m);
    }
  }

  /// O fim da viagem: quem dirigiu só grava; os outros abrem o baú.
  void _settle() {
    final now = nowUtc();
    final trip = _trip;
    final dist = trip?.recordedM ?? 0;
    state.recordEvent('trip_m', vehicle.name, dist.floor());
    final perKm = balance.vehicles[vehicle]!.sparksPerKm;
    if (!passenger) {
      outcome = TripOutcome(distanceM: dist, driver: true);
    } else {
      final today = localDay(now);
      final left = chestCapLeft(state, today, balance.chestDailyCap);
      final rewardM = trip?.rewardM ?? 0;
      final n = chestSparks(rewardM: rewardM, perKm: perKm, capLeft: left);
      final item = n > 0 ? sparkItem(destLat!, destLon!, now) : null;
      if (item != null) {
        state.add(item, n);
        recordChest(state, today, n, balance.chestDailyCap);
        state.recordEvent('trip_chest', item.replaceFirst('item.dust.', ''), n);
      }
      outcome = TripOutcome(
        distanceM: dist,
        driver: false,
        sparks: item == null ? 0 : n,
        itemId: item,
        marks: List.unmodifiable(tripMarks),
        capped: chestSparks(rewardM: rewardM, perKm: perKm, capLeft: 1 << 30) > n,
        chest: perKm > 0,
      );
    }
    stage = TravelStage.done;
    notifyListeners();
  }

  /// O jogador viu o fim da viagem.
  void closeOutcome() => _reset();

  void _reset() {
    _token++;
    _carToken++;
    stage = TravelStage.idle;
    destX = destY = destLat = destLon = null;
    destName = '';
    passenger = true;
    route = null;
    routing = false;
    ride = null;
    _ridePackage = null;
    approach = null;
    _approachBusy = false;
    tripMarks.clear();
    outcome = null;
    _trip = null;
    _arrival = null;
    _pickupBonusM = 0;
    _leave = null;
    notifyListeners();
  }

  // Corrida.

  /// Uma notificação de corrida. O texto é lido aqui e descartado.
  void onNotification(String package, String title, String text) {
    final r = ride;
    if (r == null || package != _ridePackage) return;
    final before = r.state, due = r.etaDueUtc;
    r.onSignal(patterns.parse(package, title, text), nowUtc());
    _afterRide(before, due);
  }

  /// O jogador informou o tempo que o app mostra.
  void onRideEta(int minutes) {
    final r = ride;
    if (r == null) return;
    final before = r.state, due = r.etaDueUtc;
    r.onEtaButton(minutes, nowUtc());
    _afterRide(before, due);
  }

  /// "Entrei".
  void onRideBoarded() {
    final r = ride;
    if (r == null) return;
    final before = r.state, due = r.etaDueUtc;
    r.onBoarded();
    _afterRide(before, due);
  }

  /// "Cheguei", ou parado perto do destino.
  void onRideArrived() {
    final r = ride;
    if (r == null) return;
    final before = r.state, due = r.etaDueUtc;
    r.onArrived();
    _afterRide(before, due);
  }

  void _afterRide(RideState before, int? dueBefore) {
    final r = ride!;
    final now = nowUtc();
    if (r.state == before && r.etaDueUtc == dueBefore) {
      notifyListeners();
      return;
    }
    if (r.state == RideState.searching && before != RideState.searching) {
      approach = null; // outro motorista: o carro some e o próximo vem de outro lugar
      _approachBusy = false;
      _carToken++;
    }
    if (r.state == RideState.inTrip && before != RideState.inTrip) {
      _trip = _newTrip();
      _boardEnd = now + balance.boardS;
    }
    if (r.state == RideState.finished && before != RideState.finished) {
      _leaveT = now.toDouble();
      _leave = leavePath(graph, _x, _y, _heading, balance.leaveS * balance.leaveSpeedMps, mpc: _mpc, snapM: balance.snapM);
    }
    if (r.etaDueUtc != dueBefore && r.etaDueUtc != null) _carToEta(now);
    notifyListeners();
  }

  /// O carro passa a chegar na hora nova; na primeira estimativa, ele nasce.
  void _carToEta(int now) {
    final etaS = math.max(ride!.etaDueUtc! - now, 1);
    final a = approach;
    if (a != null) {
      a.correct(etaS, now.toDouble());
    } else if (!_approachBusy && _hasFix) {
      _approachBusy = true;
      unawaited(_buildApproach(_carToken, etaS));
    }
  }

  Future<void> _buildApproach(int token, int etaS) async {
    final rng = Pcg32(fnv1a64([state.seed, _rideUtc, _saltRide]), _saltRide);
    final path = await approachPath(graph, rng,
        px: _x,
        py: _y,
        distM: etaS * balance.urbanSpeedMps,
        mpc: _mpc,
        snapM: balance.snapM,
        maxNodes: balance.maxNodes,
        sliceNodes: balance.sliceNodes,
        tries: balance.carTries);
    if (token != _carToken) return;
    _approachBusy = false;
    final now = nowUtc();
    final due = ride?.etaDueUtc;
    if (due == null) return;
    approach = RideApproach(path, etaS: math.max(due - now, 1), startUtc: now.toDouble());
    notifyListeners();
  }

  /// O carro no mapa em [t] (UTC com fração), ou `null` se ainda não há carro. Em viagem ele é o avatar: passe a posição dele
  /// em ([ax], [ay]).
  ({double x, double y, double heading})? carPose(double t, double ax, double ay, double heading) {
    final r = ride;
    if (r == null) return null;
    final a = approach;
    switch (r.state) {
      case RideState.searching:
        return null;
      case RideState.driverComing || RideState.arrived:
        return a?.at(t);
      case RideState.inTrip:
        if (t < _boardEnd && a != null) return a.at(t);
        return (x: ax, y: ay, heading: heading);
      case RideState.finished:
        final l = _leave;
        return l?.at(balance.leaveSpeedMps * (t - _leaveT));
    }
  }

  /// O embarque está acontecendo: de 0 a 1, ou `null` fora dele.
  double? boardingAt(double t) {
    if (ride?.state != RideState.inTrip || t >= _boardEnd) return null;
    return (1 - (_boardEnd - t) / balance.boardS).clamp(0.0, 1.0);
  }

  /// O desembarque está acontecendo: de 0 a 1, ou `null` fora dele.
  double? alightingAt(double t) {
    if (ride?.state != RideState.finished || t >= _leaveT + balance.boardS) return null;
    return ((t - _leaveT) / balance.boardS).clamp(0.0, 1.0);
  }

  /// O avatar some enquanto o carro faz o papel dele.
  bool hidesPlayerAt(double t) => ride?.state == RideState.inTrip && t >= _boardEnd;
}
