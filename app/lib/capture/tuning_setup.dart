/// O que o jogador escolheu antes de sintonizar: o Eco, os níveis, o selo e o tônico.
library;

import '../core/pcg32.dart';
import 'eco_type.dart';
import 'overlevel.dart';
import 'resistance.dart';
import 'seal.dart';
import 'session.dart';
import 'signal.dart';
import 'tuning_balance.dart';

class TuningSetup {
  const TuningSetup({
    required this.type,
    required this.ecoLevel,
    required this.playerLevel,
    required this.seal,
    this.tonic,
    this.circleStrong = 0,
  });

  final EcoType type;
  final int ecoLevel;
  final int playerLevel;
  final Seal seal;
  final Tonic? tonic;

  /// Criaturas do Círculo fortes contra o tipo do alvo (até 3).
  final int circleStrong;

  /// Diferença de nível: Eco menos Conjurador.
  int get gap => levelGap(playerLevel: playerLevel, ecoLevel: ecoLevel);

  /// Sobrenível `g`: níveis acima de `overlevel_free`.
  int overlevel(TuningBalance b) => overlevelOf(playerLevel: playerLevel, ecoLevel: ecoLevel, balance: b);

  double intensity(TuningBalance b) =>
      resistanceIntensity(playerLevel: playerLevel, ecoLevel: ecoLevel, balance: b);

  double tolerance(TuningBalance b) =>
      tuningTolerance(seal: seal, target: type, balance: b, circleStrong: circleStrong);

  /// 20 s, ou 25 s com tônico.
  double timeLimitS(TuningBalance b) => b.timeLimitS + (tonic?.extraTimeS ?? 0);

  /// Começa uma sintonia. O [rng] define o sinal, então a mesma semente repete a sintonia.
  TuningSession start(TuningBalance b, Pcg32 rng) => TuningSession(
        signal: TargetSignal.generate(type: type, intensity: intensity(b), rng: rng, balance: b),
        baseTolerance: tolerance(b),
        balance: b,
        timeLimitS: timeLimitS(b),
        overlevel: overlevel(b),
      );
}
