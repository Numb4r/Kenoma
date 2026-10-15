/// O Círculo: 3 espaços ativos escolhidos da coleção (docs/fase0-spec.md, seção 6). Cada criatura ativa aplica
/// a habilidade de mapa dela, dá bônus de tolerância se é forte contra o alvo e ganha XP por sintonia. Dart puro.
library;

import 'dart:math' as math;

import '../capture/eco_type.dart';
import '../data/game_data.dart';
import '../data/tuning_data.dart';
import 'game_state.dart';
import 'progress_balance.dart';

const int circleSlots = 3;

/// O efeito somado do Círculo no mapa. Habilidades iguais não se somam: vale a maior.
class MapAbilities {
  const MapAbilities({this.auraBonusM = 0, this.pickupBonusM = 0, this.trackerRangeM = 0});

  static const none = MapAbilities();

  /// Metros a mais no raio da Aura.
  final double auraBonusM;

  /// Metros a mais no alcance de coleta de Fagulhas e materiais.
  final double pickupBonusM;

  /// Alcance do rastreador (absoluto: o rastreador usa o maior entre ele e o padrão). 0 se nenhum Rillet.
  final double trackerRangeM;
}

/// A faixa (0, 1 ou 2) do nível [level]: a primeira cujo intervalo o contém.
int abilityBandIndex(int level, List<(int, int)> bands) {
  for (var i = 0; i < bands.length; i++) {
    if (level >= bands[i].$1 && level <= bands[i].$2) return i;
  }
  return level < bands.first.$1 ? 0 : bands.length - 1;
}

/// Habilidades de mapa dos membros do Círculo.
MapAbilities circleAbilities(List<({EcoSpecies species, int level})> members, List<(int, int)> bands) {
  var aura = 0.0, pickup = 0.0, tracker = 0.0;
  for (final m in members) {
    final a = m.species.ability;
    if (a == null) continue;
    final v = a.bands[abilityBandIndex(m.level, bands).clamp(0, a.bands.length - 1)].toDouble();
    switch (a.kind) {
      case 'aura_bonus_m':
        aura = math.max(aura, v);
      case 'spark_pickup_bonus_m':
        pickup = math.max(pickup, v);
      case 'tracker_range_m':
        tracker = math.max(tracker, v);
    }
  }
  return MapAbilities(auraBonusM: aura, pickupBonusM: pickup, trackerRangeM: tracker);
}

/// Quantas criaturas do Círculo vencem o tipo [target]. A sintonia limita o bônus ao máximo do balanceamento.
int circleStrongCount(Iterable<EcoType> memberTypes, EcoType target) => memberTypes.where((t) => t.beats(target)).length;

/// A criatura depois de ganhar XP de sintonia: `por_nível × n` para ir do nível n ao n+1, até o teto.
CreatureInstance withCreatureXp(CreatureInstance c, ProgressBalance b, {int? amount}) {
  var level = c.level, xp = c.xp + (amount ?? b.creaturePerTuning);
  while (level < b.creatureLevelCap && xp >= b.creatureCurvePerLevel * level) {
    xp -= b.creatureCurvePerLevel * level;
    level++;
  }
  if (level >= b.creatureLevelCap) xp = 0;
  return CreatureInstance(uid: c.uid, speciesId: c.speciesId, level: level, capturedUtc: c.capturedUtc, xp: xp);
}

/// Os membros do Círculo de [s] com a espécie e o nível, na ordem dos espaços.
List<({EcoSpecies species, int level})> circleMembers(GameState s, GameData data) => [
      for (final uid in s.circle)
        if (s.creature(uid) case final c? when data.species(c.speciesId) != null) (species: data.species(c.speciesId)!, level: c.level),
    ];

/// As habilidades de mapa do Círculo de agora.
MapAbilities abilitiesOf(GameState s, GameData data) => circleAbilities(circleMembers(s, data), data.tuning.abilityBands);

/// Quantas criaturas do Círculo vencem o tipo [target], para o bônus de tolerância.
int strongInCircle(GameState s, GameData data, EcoType target) => circleStrongCount([for (final m in circleMembers(s, data)) m.species.type], target);

/// XP de sintonia concluída para cada criatura do Círculo. Devolve as que subiram de nível.
List<CreatureInstance> awardCircleXp(GameState s) {
  final leveled = <CreatureInstance>[];
  for (final uid in [...s.circle]) {
    final c = s.creature(uid);
    if (c == null) continue;
    final next = withCreatureXp(c, s.balance);
    s.replaceCreature(next);
    if (next.level > c.level) leveled.add(next);
  }
  return leveled;
}
