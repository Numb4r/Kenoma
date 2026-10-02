/// Fogo: a onda se parte em duas num ponto de queima e as duas rolam para a esquerda.
///
/// - A **real** fica à direita da queima: o trecho novo desliza para a nova frequência (smoothstep,
///   `glide_s`) e o salto é permanente.
/// - A **isca** fica à esquerda e é cinza desde a queima. Continua na frequência antiga, com a deriva
///   de base e, acima de `decoy_counter_from` de intensidade, um deslize contrário ao da real. Não tem
///   tempo de vida: acaba quando a fronteira sai da tela pela esquerda.
/// - A **fronteira** é um ponto da onda e rola com ela, na velocidade `boundary_u_per_s`. Cada queima
///   cai no trecho vivo, à direita da fronteira anterior.
///
/// Tudo é função do tempo e dos sorteios, então é reproduzível e testável. A tela só desenha.
library;

import 'dart:math' as math;

import 'fx/wave_geometry.dart';
import 'signal_math.dart';
import 'tuning_balance.dart';

/// Um pico do Fogo, já com o ponto de queima.
class FireKick {
  const FireKick({
    required this.at,
    required this.delta,
    required this.burnU,
    required this.phase,
    required this.oldOffset,
  });

  final double at;

  /// Salto da onda real, com sinal, em fração do eixo.
  final double delta;

  /// Onde a queima caiu na tela, de 0 a 1, no instante do pico.
  final double burnU;

  /// Fase das duas ondas na fronteira, herdada da onda antiga: sem salto de fase na queima.
  final double phase;

  /// Soma dos saltos dos picos anteriores no instante deste: a frequência antiga da isca.
  final double oldOffset;
}

/// A onda partida, vista num instante.
class FireSplit {
  const FireSplit({
    required this.index,
    required this.since,
    required this.boundaryU,
    required this.decoyFrequency,
    required this.decoyLife,
    required this.segments,
  });

  /// Número do pico mais recente, a partir de 0.
  final int index;

  /// Segundos desde esse pico.
  final double since;

  /// Onde a fronteira está agora. Passa de 0 para menos: a isca saiu da tela.
  final double boundaryU;

  /// Frequência da isca do pico mais recente.
  final double decoyFrequency;

  /// Quanto resta da isca desse pico: 1 na queima, 0 quando a fronteira sai pela esquerda.
  final double decoyLife;

  /// A real (`real: true`, a da direita) e as iscas cinza, da direita para a esquerda.
  final List<WaveSegment> segments;

  bool get decoyAlive => boundaryU > 0;

  WaveSegment get real => segments.first;
}

class FireWave {
  FireWave._(this.kicks, this._fire, this._intensity, this._baseAt) : glideS = lerpRange(_fire.glideS, _intensity);

  /// Sem picos: fora do Fogo ou sem resistência.
  FireWave.none(FireBalance fire, double Function(double) baseAt)
      : kicks = const [],
        _fire = fire,
        _intensity = 0,
        _baseAt = baseAt,
        glideS = 1;

  /// Monta os picos de [times] e [deltas], e sorteia a queima de cada um com [draws] (um por pico, em
  /// `[0, 1)`). [baseAt] é a frequência inicial mais a deriva de base.
  factory FireWave.build({
    required List<double> times,
    required List<double> deltas,
    required List<double> draws,
    required FireBalance fire,
    required double intensity,
    required double Function(double t) baseAt,
  }) {
    final glide = lerpRange(fire.glideS, intensity);
    final speed = fire.boundaryUPerS;
    final built = <FireKick>[];
    for (var i = 0; i < times.length; i++) {
      final at = times[i];
      // Os saltos anteriores já somados no instante deste pico.
      var oldOffset = 0.0;
      for (var j = 0; j < i; j++) {
        oldOffset += deltas[j] * smoothstep((at - times[j]) / glide);
      }
      final oldFrequency = fold01(baseAt(at) + oldOffset);
      // A fronteira anterior, onde está agora. A queima nova cai à direita dela, no trecho vivo.
      final prevU = i == 0 ? null : built[i - 1].burnU - speed * (at - times[i - 1]);
      final lo = math.max(fire.burnU.$1, prevU ?? 0.0);
      final hi = fire.burnU.$2;
      final u = hi - lo >= fire.burnMinLiveU ? lerp(lo, hi, draws[i]) : fire.burnEdgeU;
      final anchor = prevU ?? 0.5;
      final basePhase = i == 0 ? waveScroll(at) : built[i - 1].phase;
      final phase = 2 * math.pi * waveCycles(oldFrequency) * (u - anchor) + basePhase;
      built.add(FireKick(at: at, delta: deltas[i], burnU: u, phase: phase, oldOffset: oldOffset));
    }
    return FireWave._(built, fire, intensity, baseAt);
  }

  final List<FireKick> kicks;
  final FireBalance _fire;
  final double _intensity;
  final double Function(double) _baseAt;

  /// Tempo que o trecho novo leva para deslizar até a nova frequência.
  final double glideS;

  /// Soma dos saltos da onda real em [t], antes de dobrar nas bordas.
  double offsetAt(double t) {
    var f = 0.0;
    for (final k in kicks) {
      if (t < k.at) break;
      f += k.delta * smoothstep((t - k.at) / glideS);
    }
    return f;
  }

  /// Onde a fronteira do pico [i] está em [t]: nasce em `burnU` e rola para a esquerda.
  double boundaryUAt(int i, double t) => kicks[i].burnU - _fire.boundaryUPerS * (t - kicks[i].at);

  /// Frequência da isca do pico [i] em [t]: a antiga (os saltos anteriores como estavam na queima),
  /// com a deriva de base e, acima de `decoy_counter_from`, um deslize contrário ao da real.
  double decoyFrequencyAt(int i, double t) {
    final k = kicks[i];
    var f = _baseAt(t) + k.oldOffset;
    if (_intensity > _fire.decoyCounterFrom) {
      f -= _fire.decoyCounter * k.delta * smoothstep((t - k.at) / glideS);
    }
    return fold01(f);
  }

  /// Índice do pico mais recente em [t], ou -1 antes do primeiro.
  int latestAt(double t) {
    var i = -1;
    while (i + 1 < kicks.length && kicks[i + 1].at <= t) {
      i++;
    }
    return i;
  }

  /// Os trechos visíveis em [t], da direita para a esquerda: a real em [realFrequency] e as iscas
  /// cinza. Vazio antes do primeiro pico: aí a onda é uma só.
  List<WaveSegment> segmentsAt(double t, double realFrequency) {
    final k = latestAt(t);
    if (k < 0) return const [];
    final uk = boundaryUAt(k, t);
    final out = <WaveSegment>[
      WaveSegment(
        fromU: math.max(0.0, uk),
        toU: 1,
        frequency: realFrequency,
        anchorU: uk,
        phase: kicks[k].phase,
        real: true,
      ),
    ];
    for (var i = k; i >= 0; i--) {
      final ui = boundaryUAt(i, t);
      if (ui <= 0) break; // as fronteiras mais antigas estão ainda mais à esquerda
      final prev = i > 0 ? boundaryUAt(i - 1, t) : 0.0;
      out.add(WaveSegment(
        fromU: math.max(0.0, prev),
        toU: ui,
        frequency: decoyFrequencyAt(i, t),
        anchorU: ui,
        phase: kicks[i].phase,
        real: false,
      ));
    }
    return out;
  }

  /// A onda partida em [t]. `null` antes do primeiro pico.
  FireSplit? splitAt(double t, double realFrequency) {
    final k = latestAt(t);
    if (k < 0) return null;
    final u = boundaryUAt(k, t);
    return FireSplit(
      index: k,
      since: t - kicks[k].at,
      boundaryU: u,
      decoyFrequency: decoyFrequencyAt(k, t),
      decoyLife: (u / kicks[k].burnU).clamp(0.0, 1.0),
      segments: segmentsAt(t, realFrequency),
    );
  }
}
