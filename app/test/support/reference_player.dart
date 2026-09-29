import 'dart:math' as math;

import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/seal.dart';
import 'package:kenoma/capture/session.dart';
import 'package:kenoma/capture/tuning_setup.dart';
import 'package:kenoma/capture/tuning_balance.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/pcg32.dart';

import 'fixtures.dart';

TuningBalance loadTuningBalance() => TuningBalance(loadJson('assets/data/balance.json'));

({List<Seal> seals, List<Tonic> tonics}) loadTuningItems() => parseTuningItems(loadJson('assets/data/items.json'));

Seal sealById(String id) => loadTuningItems().seals.firstWhere((s) => s.id == id);

/// Jogador de referência: vê o sinal com atraso, gira o dial com velocidade limitada e a mão
/// treme um pouco. Não antecipa os picos. Serve para conferir os alvos de duração da spec.
class ReferencePlayer {
  const ReferencePlayer({
    this.startDelayS = 0.8,
    this.reactionS = 0.3,
    this.maxSpeed = 1.5,
    this.tremorAmp = 0.03,
    this.tremorHz = 1.3,
  });

  /// Tempo que o jogador leva para descobrir para que lado girar o dial no começo.
  final double startDelayS;
  final double reactionS;

  /// Velocidade máxima do dial, em unidades de frequência por segundo.
  final double maxSpeed;
  final double tremorAmp;
  final double tremorHz;

  static const double dt = 1 / 60;

  /// Joga a sessão até o fim e devolve o instante em que terminou.
  double play(TuningSession s) {
    var dial = s.dial;
    while (s.running) {
      final seen = s.signal.frequencyAt(math.max(0, s.t - reactionS));
      final err = seen - dial;
      if (s.t >= startDelayS) dial += err.sign * math.min(err.abs() * 8, maxSpeed) * dt;
      s.step(dt, dial: dial + tremorAmp * math.sin(2 * math.pi * tremorHz * s.t));
    }
    return s.t;
  }
}

/// Jogador perfeito: sem tremor e quase sem hesitação, limitado só pelo que um humano não vence:
/// 0,2 s para reagir ao que vê e um dial de 3 unidades por segundo. É reativo: não prevê a deriva
/// nem os picos. A resistência forte tem de segurar até ele por 10 a 15 s.
const perfectPlayer = ReferencePlayer(startDelayS: 0.3, reactionS: 0.2, maxSpeed: 3, tremorAmp: 0);

/// Sessão de sintonia com a semente [seed], pelo mesmo caminho que o app usa.
TuningSession makeSession({
  required EcoType type,
  required int playerLevel,
  required int ecoLevel,
  required int seed,
  String sealId = 'item.seal.simple',
  bool tonic = false,
  int circleStrong = 0,
  TuningBalance? balance,
}) {
  final b = balance ?? loadTuningBalance();
  final setup = TuningSetup(
    type: type,
    ecoLevel: ecoLevel,
    playerLevel: playerLevel,
    seal: sealById(sealId),
    tonic: tonic ? loadTuningItems().tonics.first : null,
    circleStrong: circleStrong,
  );
  return setup.start(b, Pcg32(fnv1a64([seed]), saltKenoma));
}
