/// Números do Conjurador lidos de `balance.json` (chaves `unlocks`, `school`, `fusion`, `spirit` e `talent`): o que cada nível
/// libera, os bônus de cada escola, o custo da fusão e os pontos de talento. Nenhum vive no código.
library;

/// As escolas de Conjuração, em ids estáveis (o save grava o id).
enum School {
  technomancer('technomancer', 'Tecnomante'),
  shaman('shaman', 'Xamã Urbano'),
  sealer('sealer', 'Selador');

  const School(this.id, this.label);

  final String id;
  final String label;

  static School? parse(String? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

class ConjurerBalance {
  ConjurerBalance(Map<String, dynamic> b)
      : schoolLevel = _i(b['unlocks'], 'school_level'),
        fusionLevel = _i(b['unlocks'], 'fusion_level'),
        ritualLevel = _i(b['unlocks'], 'ritual_level'),
        spiritSpawnLevel = _i(b['unlocks'], 'spirit_spawn_level'),
        _auraBonus = [
          for (final e in (b['unlocks'] as Map<String, dynamic>)['aura_bonus'] as List<dynamic>)
            ((e as Map<String, dynamic>)['level'] as int, (e['m'] as num).toDouble()),
        ],
        techToleranceMult = _d((b['school'] as Map<String, dynamic>)['technomancer'], 'tolerance_mult'),
        shamanAuraBonusM = _d((b['school'] as Map<String, dynamic>)['shaman'], 'aura_bonus_m'),
        sealerProgressMult = _d((b['school'] as Map<String, dynamic>)['sealer'], 'progress_up_mult'),
        fusionEcoCount = _i(b['fusion'], 'eco_count'),
        fusionEssenceCost = _i(b['fusion'], 'essence_cost'),
        spiritLevelCap = _i(b['fusion'], 'spirit_level_cap'),
        ecoTraitsMax = _i(b['fusion'], 'eco_traits_max'),
        spiritTraitsMax = _i(b['fusion'], 'spirit_traits_max'),
        fusionAnimS = _d(b['fusion'], 'anim_s'),
        spiritHeightM = _d(b['spirit'], 'height_m'),
        spiritAbilitySteps = _i(b['spirit'], 'ability_steps'),
        spiritResistanceAdd = _d(b['spirit'], 'resistance_add'),
        _powerBase = _tiers(b['power'], 'base'),
        _powerPerLevel = _tiers(b['power'], 'per_level'),
        talentPerLevel = _i(b['talent'], 'points_per_level');

  static Map<String, double> _tiers(Object? m, String k) => {
        for (final e in ((m as Map<String, dynamic>)[k] as Map<String, dynamic>).entries) e.key: (e.value as num).toDouble(),
      };

  static int _i(Object? m, String k) => ((m as Map<String, dynamic>)[k] as num).toInt();
  static double _d(Object? m, String k) => ((m as Map<String, dynamic>)[k] as num).toDouble();

  /// Níveis que liberam a escola, a fusão, o ritual básico e os Espíritos no mapa.
  final int schoolLevel;
  final int fusionLevel;
  final int ritualLevel;
  final int spiritSpawnLevel;

  final List<(int, double)> _auraBonus;

  /// Metros a mais na Aura só por ter chegado ao [level] (níveis 10 e 20).
  double auraBonusFor(int level) => _auraBonus.where((e) => level >= e.$1).fold(0.0, (sum, e) => sum + e.$2);

  /// Tecnomante: a tolerância da sintonia vezes isto. Xamã Urbano: Aura +m e Ariscos não fogem. Selador: o progresso sobe vezes isto.
  final double techToleranceMult;
  final double shamanAuraBonusM;
  final double sealerProgressMult;

  /// Fusão de 5 Ecos da mesma família mais Essência do tipo num Espírito.
  final int fusionEcoCount;
  final int fusionEssenceCost;
  final int spiritLevelCap;
  final int ecoTraitsMax;
  final int spiritTraitsMax;
  final double fusionAnimS;

  /// Altura do Espírito no mapa e quantos degraus a habilidade de mapa dele é mais forte que a do Eco.
  final double spiritHeightM;
  final int spiritAbilitySteps;

  /// Degraus de resistência a mais na sintonia de um Espírito (a resistência forte do tipo).
  final double spiritResistanceAdd;

  /// Poder de uma criatura: `base + por_nível × nível`, por camada (`eco`, `spirit`). Sem estabilidade ainda.
  final Map<String, double> _powerBase;
  final Map<String, double> _powerPerLevel;
  int power(String tier, int level) => (_powerBase[tier]! + _powerPerLevel[tier]! * level).round();

  /// Pontos de talento por nível.
  final int talentPerLevel;
}
