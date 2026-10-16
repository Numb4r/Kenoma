/// Números de progressão lidos de `balance.json` (chaves `xp`, `mark` e `distill`). Nenhum vive no código.
library;

import 'conjurer_balance.dart';

class Band {
  const Band(this.from, this.to, this.value);

  final int from;
  final int to;
  final int value;
}

class ProgressBalance {
  ProgressBalance(Map<String, dynamic> balance)
      : this._(balance['xp'] as Map<String, dynamic>, balance['mark'] as Map<String, dynamic>, balance['distill'] as Map<String, dynamic>, ConjurerBalance(balance));

  ProgressBalance._(Map<String, dynamic> xp, Map<String, dynamic> mark, Map<String, dynamic> distill, this.conjurer)
      : curveA = ((xp['player_curve'] as Map<String, dynamic>)['a'] as num).toDouble(),
        curveExponent = ((xp['player_curve'] as Map<String, dynamic>)['exponent'] as num).toDouble(),
        curveRoundTo = (xp['player_curve'] as Map<String, dynamic>)['round_to'] as int,
        playerLevelCap = xp['player_level_cap'] as int,
        tuningBase = xp['tuning_base'] as int,
        tuningPerEcoLevel = xp['tuning_per_eco_level'] as int,
        tuningMax = xp['tuning_max'] as int,
        firstCapture = xp['first_capture'] as int,
        spark = xp['spark'] as int,
        material = xp['material'] as int,
        restDailyDoubled = (xp['rest'] as Map<String, dynamic>)['daily_doubled_xp'] as int,
        restMaxBanked = (xp['rest'] as Map<String, dynamic>)['max_banked_xp'] as int,
        creaturePerTuning = xp['creature_per_tuning'] as int,
        creatureCurvePerLevel = xp['creature_curve_per_level'] as int,
        creatureLevelCap = xp['creature_level_cap'] as int,
        markDurationS = mark['duration_s'] as int,
        markMax = mark['max_active'] as int,
        distillYield = [
          for (final b in distill['eco_yield'] as List<dynamic>)
            Band((b as Map<String, dynamic>)['from'] as int, b['to'] as int, b['value'] as int),
        ];

  /// O que cada nível libera, as escolas, a fusão e os talentos.
  final ConjurerBalance conjurer;

  /// Curva do Conjurador: `a × n^expoente`, arredondado para o múltiplo de [curveRoundTo].
  final double curveA;
  final double curveExponent;
  final int curveRoundTo;
  final int playerLevelCap;

  /// XP da sintonia: `base + por_nível × nível do Eco`, com teto.
  final int tuningBase;
  final int tuningPerEcoLevel;
  final int tuningMax;
  final int firstCapture;
  final int spark;
  final int material;

  /// Por dia, esta quantidade de XP bruto rende o dobro; o que sobra acumula até [restMaxBanked].
  final int restDailyDoubled;
  final int restMaxBanked;

  /// XP de cada criatura do Círculo por sintonia concluída, e a curva delas (`por_nível × n`).
  final int creaturePerTuning;
  final int creatureCurvePerLevel;
  final int creatureLevelCap;

  /// Duração da marcação e quantas podem estar ativas.
  final int markDurationS;
  final int markMax;

  /// Essência que um Eco rende na destilação, por faixa de nível.
  final List<Band> distillYield;
}
