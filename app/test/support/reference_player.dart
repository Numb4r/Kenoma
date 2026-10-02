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
    this.retargetThreshold = 0,
    this.overshootChance = 0,
    this.overshootFraction = 0.4,
    this.tremorRandomPhase = false,
    this.avoidsRoots = true,
  });

  /// Tempo que o jogador leva para descobrir para que lado girar o dial no começo.
  final double startDelayS;
  final double reactionS;

  /// Velocidade máxima do dial, em unidades de frequência por segundo.
  final double maxSpeed;
  final double tremorAmp;
  final double tremorHz;

  /// Uma correção só é refeita quando o sinal que o jogador vê andou tanto desde a última decisão,
  /// ou quando o dial chegou e ainda há erro. 0 (com `overshootChance` 0) acompanha o sinal o tempo
  /// todo, que é o comportamento de sempre.
  final double retargetThreshold;

  /// Chance de uma correção passar do ponto, e quanto passa, em fração do tamanho da correção. O dial
  /// termina o movimento no ponto que passou e só então corrige de volta (sujeito a passar de novo).
  final double overshootChance;
  final double overshootFraction;

  /// O tremor tem duas componentes (1,3 Hz e 2,9 Hz, 60% e 40% da amplitude) com fases sorteadas por
  /// sintonia, então nunca passa de ±[tremorAmp]. Falso: uma senoide de fase 0, como sempre.
  final bool tremorRandomPhase;

  /// As raízes da Planta estão desenhadas no dial, então o jogador as vê. Com o sinal dentro de uma
  /// (ou de várias que se sobrepõem), mira o ponto livre mais perto dele e não fica sentado em cima.
  /// Atravessar uma raiz de passagem custa quase nada, então o dial não desvia delas no caminho.
  final bool avoidsRoots;
  static const double dt = 1 / 60;
  static const double _rootMargin = 0.004;

  /// O ponto livre de raízes mais perto de [aim] em [t]: o próprio [aim] se ele já está livre.
  double _freeAim(TuningSession s, double aim) {
    final roots = s.signal.rootsAt(s.t);
    if (roots.isEmpty) return aim;
    final bands = [for (final r in roots) (r.lo - _rootMargin, r.hi + _rootMargin)]..sort((a, b) => a.$1.compareTo(b.$1));
    var from = bands.first.$1;
    var to = bands.first.$2;
    final merged = <(double, double)>[];
    for (final b in bands.skip(1)) {
      if (b.$1 <= to) {
        to = math.max(to, b.$2);
      } else {
        merged.add((from, to));
        from = b.$1;
        to = b.$2;
      }
    }
    merged.add((from, to));
    for (final (lo, hi) in merged) {
      if (aim > lo && aim < hi) {
        if (lo <= 0) return hi.clamp(0.0, 1.0);
        if (hi >= 1) return lo;
        return aim - lo <= hi - aim ? lo : hi;
      }
    }
    return aim;
  }

  /// Joga a sessão até o fim e devolve o instante em que terminou. [seed] sorteia quais correções
  /// passam do ponto, então cada sintonia simulada tem a sua.
  double play(TuningSession s, {int seed = 0, void Function(double t, double dial)? onStep}) {
    final rng = Pcg32(fnv1a64([seed, 0x70]), saltKenoma);
    var dial = s.dial;
    var aim = dial;
    var intended = dial; // o que viu na última decisão de mirar
    final phase1 = 2 * math.pi * rng.nextFloat();
    final phase2 = 2 * math.pi * rng.nextFloat();
    double tremor(double t) => tremorRandomPhase
        ? tremorAmp * (0.6 * math.sin(2 * math.pi * 1.3 * t + phase1) + 0.4 * math.sin(2 * math.pi * 2.9 * t + phase2))
        : tremorAmp * math.sin(2 * math.pi * tremorHz * s.t);
    while (s.running) {
      final seen = s.signal.frequencyAt(math.max(0, s.t - reactionS));
      if (s.t >= startDelayS) {
        if (retargetThreshold == 0 && overshootChance == 0) {
          aim = seen; // acompanha o sinal o tempo todo
        } else {
          // Uma correção é um movimento até `aim`, que só termina quando o dial chega. Nova decisão de
          // mirar: o sinal andou além do limiar desde a última, ou o dial chegou e ainda há erro.
          final arrived = (aim - dial).abs() < 0.01;
          final moved = (seen - intended).abs() > retargetThreshold;
          final off = (seen - aim).abs() > retargetThreshold;
          if (moved || (arrived && off)) {
            final distance = seen - dial;
            intended = seen;
            aim = seen;
            if (overshootChance > 0 && rng.nextFloat() < overshootChance) {
              aim = (seen + distance.sign * distance.abs() * overshootFraction).clamp(0.0, 1.0);
            }
          }
        }
      }
      if (s.t >= startDelayS) {
        final goal = avoidsRoots ? _freeAim(s, aim) : aim;
        final err = goal - dial;
        dial += err.sign * math.min(err.abs() * 8, maxSpeed) * dt;
      }
      final output = dial + tremor(s.t);
      onStep?.call(s.t, output);
      s.step(dt, dial: output);
    }
    return s.t;
  }
}

/// Jogador perfeito: sem tremor e quase sem hesitação, limitado só pelo que um humano não vence:
/// 0,2 s para reagir ao que vê e um dial de 3 unidades por segundo. É reativo: não prevê a deriva
/// nem os picos. A resistência forte tem de segurar até ele por 10 a 15 s.
const perfectPlayer = ReferencePlayer(startDelayS: 0.3, reactionS: 0.2, maxSpeed: 3, tremorAmp: 0);

/// Jogador típico: reage em 0,35 s, hesita 0,5 s no começo, a mão treme ±0,02 no dial e refaz a
/// pontaria só quando o sinal se afasta 0,03 de onde mirou. 10% das correções passam do ponto
/// (por 40% do tamanho delas). É reativo, como o perfeito.
const typicalPlayer = ReferencePlayer(
  startDelayS: 0.5,
  reactionS: 0.35,
  maxSpeed: 1.5,
  tremorAmp: 0.02,
  retargetThreshold: 0.03,
  overshootChance: 0.1,
  overshootFraction: 0.4,
  tremorRandomPhase: true,
);

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
