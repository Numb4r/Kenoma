/// A corrida de Uber ou 99 no mapa: a máquina de estados e o carro que vem buscar o jogador. Só atalho: nada aqui fala
/// com as contas desses apps. As entradas são a notificação já interpretada, os botões e o GPS. Dart puro.
library;

import 'dart:math' as math;

import 'travel_path.dart';

enum RideState { searching, driverComing, arrived, inTrip, finished }

/// O que uma notificação disse. Tudo `null`: não reconhecida, e a corrida segue pelos botões.
class RideSignal {
  const RideSignal({this.state, this.etaMin, this.carType, this.carColor});

  static const empty = RideSignal();

  final RideState? state;
  final int? etaMin;

  /// `hatch`, `sedan` ou `suv`.
  final String? carType;

  /// 0xAARRGGBB.
  final int? carColor;

  bool get isEmpty => state == null && etaMin == null && carType == null && carColor == null;
}

/// Os botões que a corrida mostra. Valem com e sem notificação: são o que sobra quando o texto não é reconhecido.
enum RideButton { eta, boarded, arrived }

class Ride {
  Ride({required this.appName});

  /// `Uber` ou `99`, só para o texto.
  final String appName;

  RideState state = RideState.searching;

  /// Quando o carro chega, em segundos UTC. `null` sem estimativa.
  int? etaDueUtc;

  /// O carro: tipo e cor vistos numa notificação.
  String? carType;
  int? carColor;

  /// Quantas notificações vieram sem nada reconhecível.
  int unrecognized = 0;

  /// A chegada do carro veio só do relógio: uma notificação ainda pode dizer que ele está a caminho.
  bool _arrivalGuessed = false;

  List<RideButton> get buttons => switch (state) {
        RideState.searching || RideState.driverComing => const [RideButton.eta, RideButton.boarded],
        RideState.arrived => const [RideButton.boarded],
        RideState.inTrip => const [RideButton.arrived],
        RideState.finished => const [],
      };

  /// Uma notificação interpretada. Texto desconhecido não muda nada.
  void onSignal(RideSignal s, int tUtc) {
    if (s.isEmpty) {
      unrecognized++;
      return;
    }
    carType = s.carType ?? carType;
    carColor = s.carColor ?? carColor;
    final next = s.state;
    if (next != null) _go(next);
    final eta = s.etaMin;
    if (eta != null && state.index <= RideState.driverComing.index) {
      etaDueUtc = tUtc + eta * 60;
      if (state == RideState.searching) state = RideState.driverComing;
    }
  }

  /// O jogador informou o tempo que o app mostra.
  void onEtaButton(int minutes, int tUtc) {
    if (state.index > RideState.driverComing.index) return;
    etaDueUtc = tUtc + minutes * 60;
    state = RideState.driverComing;
  }

  /// "Entrei".
  void onBoarded() {
    if (state.index < RideState.inTrip.index) state = RideState.inTrip;
  }

  /// "Cheguei", ou parado perto do destino.
  void onArrived() {
    if (state == RideState.inTrip) state = RideState.finished;
  }

  /// O tempo passou: acabou a estimativa, o carro chegou, até que digam o contrário.
  void tick(int tUtc) {
    final due = etaDueUtc;
    if (state == RideState.driverComing && due != null && tUtc >= due) {
      state = RideState.arrived;
      _arrivalGuessed = true;
    }
  }

  void _go(RideState next) {
    if (state == RideState.finished) return;
    if (next.index > state.index) {
      state = next;
      _arrivalGuessed = false;
      return;
    }
    // Só dois recuos existem: outro motorista (volta a procurar) e a chegada que foi só palpite do relógio.
    final redo = next == RideState.searching && state.index <= RideState.arrived.index;
    final late = next == RideState.driverComing && state == RideState.arrived && _arrivalGuessed;
    if (redo || late) {
      state = next;
      _arrivalGuessed = false;
      if (redo) etaDueUtc = null;
    }
  }
}

/// O carro que vem até o jogador por [path] e chega junto com a estimativa. O tempo é o do relógio, não o dos quadros: com
/// o app em segundo plano ele continua andando.
class RideApproach {
  RideApproach(this.path, {required int etaS, required double startUtc}) : _t0 = startUtc {
    _v = path.lengthM / math.max(etaS, 1);
  }

  final TravelPath path;
  double _s0 = 0;
  double _t0;
  late double _v;

  /// Velocidade de agora, em m/s.
  double get speedMps => _v;

  /// Metros andados em [t].
  double sAt(double t) => math.min(path.lengthM, _s0 + _v * math.max(0.0, t - _t0));

  /// Quando o carro chega, em segundos UTC.
  double get arrivalUtc => _t0 + (path.lengthM - _s0) / _v;

  /// Veio um tempo novo: a velocidade muda para o carro chegar daqui a [etaS] segundos, de onde ele está.
  void correct(int etaS, double t) {
    _s0 = sAt(t);
    _t0 = t;
    _v = math.max(path.lengthM - _s0, 0.001) / math.max(etaS, 1);
  }

  ({double x, double y, double heading}) at(double t) => path.at(sAt(t));
}
