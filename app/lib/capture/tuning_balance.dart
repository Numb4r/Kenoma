/// Parâmetros da sintonia, lidos de `balance.json` (chave `tuning`).
/// Nenhum número de balanceamento vive no código.
library;

/// Par `(valor com intensidade 0, valor com intensidade 1)`.
typedef Range2 = (double, double);

double lerp(double a, double b, double t) => a + (b - a) * t;

double lerpRange(Range2 r, double t) => lerp(r.$1, r.$2, t);

double _d(dynamic v) => (v as num).toDouble();

Range2 _range(dynamic json) {
  final list = json as List<dynamic>;
  return (_d(list[0]), _d(list[1]));
}

class ResistanceBand {
  const ResistanceBand({required this.from, required this.to, this.value, this.base, this.perLevel});

  factory ResistanceBand.fromJson(Map<String, dynamic> j) => ResistanceBand(
        from: j['from'] as int,
        to: j['to'] as int,
        value: (j['value'] as num?)?.toDouble(),
        base: (j['base'] as num?)?.toDouble(),
        perLevel: (j['per_level'] as num?)?.toDouble(),
      );

  final int from;
  final int to;

  /// Valor fixo da faixa. `null` se a faixa sobe por nível (`base` + `perLevel`).
  final double? value;
  final double? base;
  final double? perLevel;
}

class FireBalance {
  FireBalance(Map<String, dynamic> j)
      : intervalS = _range(j['interval_s']),
        kick = _range(j['kick']),
        decayS = _d(j['decay_s']),
        warningLeadS = _d(j['warning_lead_s']),
        trembleAfterS = _d(j['tremble_after_s']);

  /// Intervalo médio entre picos, em segundos.
  final Range2 intervalS;

  /// Tamanho do empurrão, em fração do eixo de frequência.
  final Range2 kick;

  /// Constante de tempo com que o sinal volta depois do pico.
  final double decayS;

  /// A vibração de aviso e o tremor da onda começam este tempo antes do pico.
  final double warningLeadS;
  final double trembleAfterS;
}

class WaterBalance {
  WaterBalance(Map<String, dynamic> j)
      : amplitude = _range(j['amplitude']),
        periodS = _range(j['period_s']),
        secondPeriodRatio = _d(j['second_period_ratio']),
        secondWeight = _d(j['second_weight']),
        tidePeriodS = _d((j['tide'] as Map<String, dynamic>)['period_s']),
        tideMin = _d((j['tide'] as Map<String, dynamic>)['min']),
        cueLeadS = _d(j['cue_lead_s']);

  /// Amplitude total da deriva, em fração do eixo de frequência.
  final Range2 amplitude;

  /// Período `P` da primeira senoide.
  final Range2 periodS;

  /// A segunda senoide tem período `P × secondPeriodRatio` (razão áurea: as duas nunca se repetem juntas).
  final double secondPeriodRatio;

  /// Fração da amplitude que vai para a segunda senoide. A primeira leva o resto.
  final double secondWeight;

  /// A amplitude total oscila devagar entre [tideMin] e 1 com este período (a maré).
  final double tidePeriodS;
  final double tideMin;

  /// A vibração avisa este tempo antes de cada inversão de sentido do sinal.
  final double cueLeadS;
}

class PlantBalance {
  PlantBalance(Map<String, dynamic> j)
      : toleranceShrink = _d(j['tolerance_shrink']),
        shrinkOverS = _d(j['shrink_over_s']),
        toleranceFloor = _d(j['tolerance_floor']),
        growthPerS = _range(j['growth_per_s']),
        budStep = _range(j['bud_step']),
        cueEveryS = _d(j['cue_every_s']),
        pulseMs = _range(j['pulse_ms']);

  /// Fração da tolerância perdida quando o encolhimento termina, com intensidade 1.
  final double toleranceShrink;

  /// Tempo que a tolerância leva para encolher até o mínimo.
  final double shrinkOverS;

  /// Menor fração da tolerância que sobra. Sem piso, com resistência 1 a tolerância chegava a zero
  /// e a captura ficava impossível.
  final double toleranceFloor;

  /// Deriva do sinal, em fração do eixo por segundo, no sentido sorteado.
  final Range2 growthPerS;

  /// Passo extra do sinal a cada pulso, no mesmo sentido da deriva (o broto).
  final Range2 budStep;
  final double cueEveryS;

  /// Duração do pulso de vibração no início e no fim do tempo.
  final Range2 pulseMs;
}

class SignalBalance {
  SignalBalance(Map<String, dynamic> j)
      : startRange = _range(j['start_range']),
        wanderAmplitude = _d(j['wander_amplitude']),
        wanderPeriodS = _d(j['wander_period_s']),
        fire = FireBalance(j['fire'] as Map<String, dynamic>),
        water = WaterBalance(j['water'] as Map<String, dynamic>),
        plant = PlantBalance(j['plant'] as Map<String, dynamic>);

  /// Faixa da frequência inicial do sinal.
  final Range2 startRange;

  /// Deriva lenta que existe mesmo sem resistência.
  final double wanderAmplitude;
  final double wanderPeriodS;
  final FireBalance fire;
  final WaterBalance water;
  final PlantBalance plant;
}

class TuningBalance {
  TuningBalance(Map<String, dynamic> balance) : this._(balance['tuning'] as Map<String, dynamic>);

  TuningBalance._(Map<String, dynamic> t)
      : progressUpPerS = _d(t['progress_up_per_s']),
        progressDownPerS = _d(t['progress_down_per_s']),
        timeLimitS = _d(t['time_limit_s']),
        fleeChanceOnFail = _d(t['flee_chance_on_fail']),
        overlevelFree = t['overlevel_free'] as int,
        ectoplasmReward = ((t['ectoplasm_reward'] as List<dynamic>)[0] as int, t['ectoplasm_reward'][1] as int),
        circleStrongMultiplier = _d(t['circle_strong_multiplier']),
        circleStrongMax = t['circle_strong_max'] as int,
        resistanceBands = [
          for (final b in (t['resistance'] as Map<String, dynamic>)['by_player_level'] as List<dynamic>)
            ResistanceBand.fromJson(b as Map<String, dynamic>),
        ],
        resistancePerEcoLevelAbove = _d((t['resistance'] as Map<String, dynamic>)['per_eco_level_above_player']),
        resistanceMax = _d((t['resistance'] as Map<String, dynamic>)['max']),
        signal = SignalBalance(t['signal'] as Map<String, dynamic>);

  final double progressUpPerS;
  final double progressDownPerS;
  final double timeLimitS;
  final double fleeChanceOnFail;

  /// Níveis de diferença (Eco acima do Conjurador) que só somam à intensidade da resistência.
  /// Passando disso, vale o sobrenível.
  final int overlevelFree;
  final (int, int) ectoplasmReward;
  final double circleStrongMultiplier;
  final int circleStrongMax;
  final List<ResistanceBand> resistanceBands;
  final double resistancePerEcoLevelAbove;
  final double resistanceMax;
  final SignalBalance signal;
}
