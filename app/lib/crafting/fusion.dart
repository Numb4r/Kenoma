/// A fusão (GDD, "Fusão"): no nível 6, cinco Ecos da mesma família mais Essência do tipo dela viram o Espírito da família.
/// O Espírito herda o nível médio dos Ecos e até dois traços (Brilhante primeiro, depois variantes distintas). Dart puro.
library;

import '../core/species_ids.dart';
import '../data/game_data.dart';
import '../player/game_state.dart';
import 'crafting.dart' show essenceIds, essenceTotal;

/// Por que uma fusão não pode acontecer agora. `needsCircleConfirm` não é erro: pede a confirmação do jogador.
enum FusionBlocker { locked, unknownFamily, wrongCount, invalidEco, missingEssence, needsCircleConfirm }

/// O que a fusão vai fazer, calculado sem gastar nada.
class FusionPlan {
  const FusionPlan({required this.family, required this.spiritId, required this.essenceId, required this.essenceCost, required this.ecos, required this.level, required this.traits, required this.circleUids});

  final String family;
  final String spiritId;
  final String essenceId;
  final int essenceCost;
  final List<CreatureInstance> ecos;

  /// Nível médio dos Ecos (arredondado), limitado ao teto do Espírito.
  final int level;

  /// Os traços herdados: `shiny` e chaves de variante de bioma.
  final List<String> traits;

  /// Os Ecos escolhidos que estão no Círculo (a fusão tira cada um da vaga).
  final List<String> circleUids;
}

String spiritIdOf(String family) => '$family.spirit';

/// As famílias que fundem, na ordem dos dados (uma por Eco que não seja de ritual).
List<String> fusionFamilies(GameData data) => [
      for (final sp in data.tuning.species)
        if (sp.tier == 'eco' && !sp.ritualOnly) sp.family,
    ];

/// O item de Essência da família: a do tipo do Eco dela.
String? essenceOfFamily(GameData data, String family) {
  final eco = data.species('$family.eco');
  return eco == null ? null : 'item.essence.${eco.type.name}';
}

/// Os Ecos da coleção que podem entrar na fusão da [family] (só Ecos dela, não Espíritos).
List<CreatureInstance> fusibleEcos(GameState s, String family) => [for (final c in s.collection) if (c.speciesId == '$family.eco') c];

/// Os traços que o Espírito herda: o Brilhante primeiro, depois cada variante de bioma distinta na ordem dos Ecos, até [max].
List<String> inheritedTraits(List<CreatureInstance> ecos, int max) {
  final out = <String>[if (ecos.any((c) => c.shiny)) 'shiny'];
  for (final c in ecos) {
    final v = c.variant;
    if (v != null && !out.contains(v)) out.add(v);
  }
  return out.take(max).toList();
}

/// O plano da fusão da [family] com os Ecos [uids] (nesta ordem). `null` se os Ecos não são válidos: repetidos, de outra
/// família ou fora da coleção. Não confere custo nem nível: isso é de [fusionBlocker].
FusionPlan? fusionPlan(GameState s, GameData data, String family, List<String> uids) {
  final essence = essenceOfFamily(data, family);
  if (essence == null || data.species(spiritIdOf(family)) == null) return null;
  if (uids.toSet().length != uids.length) return null;
  final ecos = <CreatureInstance>[];
  for (final u in uids) {
    final c = s.creature(u);
    if (c == null || c.speciesId != '$family.eco') return null;
    ecos.add(c);
  }
  final cb = s.cb;
  final avg = ecos.isEmpty ? 0 : (ecos.fold<int>(0, (sum, c) => sum + c.level) / ecos.length).round();
  return FusionPlan(
    family: family,
    spiritId: spiritIdOf(family),
    essenceId: essence,
    essenceCost: cb.fusionEssenceCost,
    ecos: ecos,
    level: avg.clamp(1, cb.spiritLevelCap),
    traits: inheritedTraits(ecos, cb.spiritTraitsMax),
    circleUids: [for (final c in ecos) if (s.inCircle(c.uid)) c.uid],
  );
}

/// O que impede a fusão, ou `null` se pode. Com Ecos do Círculo e sem [confirmCircle], devolve `needsCircleConfirm`.
FusionBlocker? fusionBlocker(GameState s, GameData data, String family, List<String> uids, {bool confirmCircle = false}) {
  if (s.playerLevel < s.cb.fusionLevel) return FusionBlocker.locked;
  if (essenceOfFamily(data, family) == null) return FusionBlocker.unknownFamily;
  if (uids.length != s.cb.fusionEcoCount) return FusionBlocker.wrongCount;
  final plan = fusionPlan(s, data, family, uids);
  if (plan == null) return FusionBlocker.invalidEco;
  if (s.count(plan.essenceId) < plan.essenceCost) return FusionBlocker.missingEssence;
  if (plan.circleUids.isNotEmpty && !confirmCircle) return FusionBlocker.needsCircleConfirm;
  return null;
}

/// Executa a fusão de uma vez: ou tudo acontece ou nada é gasto. Devolve o Espírito, ou `null` se há [fusionBlocker].
/// Os Ecos saem da coleção (e do Círculo, que perde a vaga), a Essência é gasta, o evento `fusion` conta, o Espírito entra
/// na coleção e no bestiário como capturado.
CreatureInstance? fuse(GameState s, GameData data, String family, List<String> uids, {required int nowUtc, bool confirmCircle = false}) {
  if (fusionBlocker(s, data, family, uids, confirmCircle: confirmCircle) != null) return null;
  final plan = fusionPlan(s, data, family, uids)!;
  for (var i = 0; i < plan.essenceCost; i++) {
    s.take(plan.essenceId);
  }
  for (final c in plan.ecos) {
    s.circle.remove(c.uid);
    s.removeCreature(c.uid);
  }
  final spirit = CreatureInstance(uid: 'fusion-$nowUtc-${s.conjurer.fusions}', speciesId: plan.spiritId, level: plan.level, capturedUtc: nowUtc, traits: plan.traits);
  s.conjurer.fusions++;
  s.addCreature(spirit);
  s.recordEvent('fusion', family, 1);
  return spirit;
}

/// Há uma fusão possível agora? Nível liberado, cinco Ecos de alguma família e a Essência do custo. A Essência confere só
/// o total de qualquer tipo (o estado não sabe qual tipo é de qual família); quem abre a tela confere o tipo certo.
// ponytail: aproximação para a bolinha da Bancada; exata se o celular passar o GameData, o que a bolinha não recebe.
bool fusionPossible(GameState s) {
  if (s.playerLevel < s.cb.fusionLevel || essenceTotal(s) < s.cb.fusionEssenceCost) return false;
  final perFamily = <String, int>{};
  for (final c in s.collection) {
    if (tierOfId(c.speciesId) == SpeciesTier.eco) perFamily.update(familyOfId(c.speciesId), (n) => n + 1, ifAbsent: () => 1);
  }
  return perFamily.values.any((n) => n >= s.cb.fusionEcoCount) && essenceIds.any((id) => s.count(id) >= s.cb.fusionEssenceCost);
}
