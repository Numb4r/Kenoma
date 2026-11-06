/// A viagem em si: a distância gravada, a chegada e o baú com teto diário. Dart puro.
library;

import 'dart:math' as math;

import '../player/game_state.dart';
import '../player/mark.dart';

/// Quanto o baú já deu hoje. Fica em `settings`: o save não muda de formato.
const String kChestDaySetting = 'travel_chest_day';
const String kChestGivenSetting = 'travel_chest_given';

/// Soma a distância da viagem a partir das posições do GPS.
class TripRecorder {
  TripRecorder({required this.maxRewardMps, required this.minStepM});

  /// Trecho mais rápido que isto não conta para o baú (bicicleta que entrou num carro, GPS que saltou).
  final double maxRewardMps;
  final double minStepM;

  /// Metros de toda a viagem, e os que contam para o baú.
  double recordedM = 0;
  double rewardM = 0;

  double? _x, _y;
  int _t = 0;

  void add(double x, double y, double mpc, int tUtc) {
    final ax = _x, ay = _y;
    if (ax == null || ay == null) {
      _x = x;
      _y = y;
      _t = tUtc;
      return;
    }
    final d = math.sqrt((x - ax) * (x - ax) + (y - ay) * (y - ay)) * mpc;
    if (d < minStepM) return;
    final mps = d / math.max(tUtc - _t, 1);
    _x = x;
    _y = y;
    _t = tUtc;
    recordedM += d;
    if (mps <= maxRewardMps) rewardM += d;
  }
}

/// Parar perto do destino por alguns segundos.
class ArrivalWatch {
  ArrivalWatch({required this.radiusM, required this.holdS, required this.speedMps});

  final double radiusM;
  final int holdS;
  final double speedMps;
  int? _since;

  /// Devolve `true` quando a parada já durou o bastante.
  bool feed({required double distanceM, required double speed, required int tUtc}) {
    if (distanceM > radiusM || speed > speedMps) {
      _since = null;
      return false;
    }
    final since = _since ??= tUtc;
    return tUtc - since >= holdS;
  }
}

/// Quantas Fagulhas o baú ainda pode dar em [today] (dia local).
int chestCapLeft(GameState state, int today, int cap) {
  final day = state.settings[kChestDaySetting], given = state.settings[kChestGivenSetting];
  if (day != today || given is! int) return cap;
  return math.max(0, cap - given);
}

/// As Fagulhas de uma viagem: proporcionais à distância, cortadas pelo teto do dia.
int chestSparks({required double rewardM, required double perKm, required int capLeft}) => math.min((rewardM / 1000 * perKm).floor(), capLeft);

/// Anota no save o que o baú deu em [today].
void recordChest(GameState state, int today, int sparks, int cap) {
  final left = chestCapLeft(state, today, cap);
  state.setSetting(kChestDaySetting, today);
  state.setSetting(kChestGivenSetting, cap - left + sparks);
}

/// O que se viu no fim da viagem.
class TripOutcome {
  const TripOutcome({required this.distanceM, required this.driver, this.sparks = 0, this.itemId, this.marks = const [], this.capped = false, this.chest = false});

  final double distanceM;

  /// Quem dirigiu só tem a viagem gravada.
  final bool driver;
  final int sparks;
  final String? itemId;
  final List<Mark> marks;

  /// O teto do dia cortou o baú.
  final bool capped;

  /// Se houve baú (a pé é jogo normal, e quem dirige não tem).
  final bool chest;
}
