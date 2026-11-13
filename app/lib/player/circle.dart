/// O Círculo: 3 espaços ativos escolhidos da coleção (docs/fase0-spec.md, seção 6). Cada criatura ativa aplica
/// a habilidade de mapa dela, dá bônus de tolerância se é forte contra o alvo e ganha XP por sintonia. Dart puro.
library;

import 'dart:math' as math;

import '../capture/eco_type.dart';
import '../core/fnv.dart';
import '../core/pcg32.dart';
import '../data/game_data.dart';
import '../data/tuning_data.dart';
import 'game_state.dart';
import 'progress_balance.dart';

const int circleSlots = 3;

/// O efeito somado do Círculo no mapa. Habilidades iguais não se somam: vale a maior.
class MapAbilities {
  const MapAbilities({this.auraBonusM = 0, this.pickupBonusM = 0, this.values = const {}});

  static const none = MapAbilities();

  /// Metros a mais no raio da Aura.
  final double auraBonusM;

  /// Metros a mais no alcance de coleta de Fagulhas e materiais.
  final double pickupBonusM;

  /// O maior valor de cada habilidade do Círculo, pela chave do dado (`seal_save_pct`, `night_eco_pct`...).
  final Map<String, double> values;

  /// O valor da habilidade [kind] no Círculo, ou 0.
  double of(String kind) => values[kind] ?? 0;
}

/// O texto curto de uma habilidade de mapa com o valor [v] ("Aura +5 m").
String abilityLabel(String kind, int v) => switch (kind) {
      'aura_bonus_m' => 'Aura +$v m',
      'spark_pickup_bonus_m' => 'Coleta +$v m',
      'rain_puddles' => 'Chuva: +$v poças',
      'storm_night_ecos_per_hour' => 'Elétricos nos postes +$v/h',
      'extra_material_pct' => 'Material extra $v%',
      'seal_save_pct' => 'Selo salvo na falha $v%',
      'day_tolerance_pct' => 'Tolerância de dia +$v%',
      'night_eco_pct' => 'Eco em becos e marquises $v%',
      'fog_ecos_per_hour' => 'Espectrais na neblina +$v/h',
      'hidden_chance_pct' => 'Oculto +$v%',
      'variant_chance_pct' => 'Variante +$v%',
      'distill_bonus' => 'Essência na destilação +$v',
      _ => '$kind $v',
    };

/// O efeito por extenso de uma habilidade de mapa com o valor [v]. "Só para você": vem da camada pessoal de spawn, que
/// acrescenta ao mundo de todos sem tirar nada dele.
String abilityEffect(String kind, int v) => switch (kind) {
      'aura_bonus_m' => 'A Aura pega Fagulhas e materiais $v m mais longe.',
      'spark_pickup_bonus_m' => 'Coleta Fagulhas e materiais $v m mais longe.',
      'rain_puddles' => 'Na chuva, $v ${v == 1 ? 'poça' : 'poças'} a mais a cada área de uns 300 m, só para você; cada uma pode ter um Eco de Água.',
      'storm_night_ecos_per_hour' => 'À noite e na tempestade, $v ${v == 1 ? 'Eco Elétrico' : 'Ecos Elétricos'} a mais por hora junto dos postes (semáforos e pontos de ônibus) de cada área de uns 300 m, só para você.',
      'extra_material_pct' => '$v% de chance de levar uma unidade a mais de cada material coletado.',
      'seal_save_pct' => '$v% de chance de não gastar o selo quando a sintonia falha.',
      'day_tolerance_pct' => 'De dia, a tolerância da sintonia fica $v% maior.',
      'night_eco_pct' => 'À noite, $v% de chance de um Eco a mais em becos e sob marquises (comércio, bares e restaurantes), por célula e janela, só para você.',
      'fog_ecos_per_hour' => 'Na neblina e no Sagrado, $v ${v == 1 ? 'Eco Espectral' : 'Ecos Espectrais'} a mais por hora em cada área de uns 300 m, só para você. Os rastros do Radar duram mais.',
      'hidden_chance_pct' => 'Os Ecos que só você vê têm $v% a mais de chance de ser Ocultos. Destilar um Eco que era Oculto rende Essência a mais.',
      'variant_chance_pct' => 'Os Ecos que só você vê têm $v% a mais de chance de ser variante.',
      'distill_bonus' => 'Destilar um Eco rende $v de Essência a mais.',
      _ => abilityLabel(kind, v),
    };

/// A faixa (0, 1 ou 2) do nível [level]: a primeira cujo intervalo o contém.
int abilityBandIndex(int level, List<(int, int)> bands) {
  for (var i = 0; i < bands.length; i++) {
    if (level >= bands[i].$1 && level <= bands[i].$2) return i;
  }
  return level < bands.first.$1 ? 0 : bands.length - 1;
}

/// Habilidades de mapa dos membros do Círculo.
MapAbilities circleAbilities(List<({EcoSpecies species, int level})> members, List<(int, int)> bands) {
  var aura = 0.0, pickup = 0.0;
  final values = <String, double>{};
  for (final m in members) {
    final a = m.species.ability;
    if (a == null) continue;
    final v = a.bands[abilityBandIndex(m.level, bands).clamp(0, a.bands.length - 1)].toDouble();
    values[a.kind] = math.max(values[a.kind] ?? 0, v);
    switch (a.kind) {
      case 'aura_bonus_m':
        aura = math.max(aura, v);
      case 'spark_pickup_bonus_m':
        pickup = math.max(pickup, v);
    }
  }
  return MapAbilities(auraBonusM: aura, pickupBonusM: pickup, values: values);
}

/// O Rustling no Círculo: na sintonia falha do Eco [uid] em [nowUtc], o selo não é gasto com [pct] por cento de chance.
/// O sorteio sai do uid e do instante (FNV e PCG32 do núcleo): a mesma falha dá sempre o mesmo resultado.
bool sealSaved(int uid, int nowUtc, double pct) => pct > 0 && Pcg32(fnv1a64([uid, nowUtc, salt('seal')]), saltKenoma).nextFloat() < pct / 100;

/// Quantas criaturas do Círculo vencem o tipo [target]. A sintonia limita o bônus ao máximo do balanceamento.
int circleStrongCount(Iterable<EcoType> memberTypes, EcoType target) => memberTypes.where((t) => t.beats(target)).length;

/// A criatura depois de ganhar XP de sintonia: `por_nível × n` para ir do nível n ao n+1, até o teto.
CreatureInstance withCreatureXp(CreatureInstance c, ProgressBalance b, {int? amount}) {
  final cap = b.levelCapFor(c.speciesId);
  var level = c.level, xp = c.xp + (amount ?? b.creaturePerTuning);
  while (level < cap && xp >= b.creatureCurvePerLevel * level) {
    xp -= b.creatureCurvePerLevel * level;
    level++;
  }
  if (level >= cap) xp = 0;
  return c.advanced(level: level, xp: xp);
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
