/// O ritual básico (GDD, "Ritual"): tentar a receita de uma espécie `ritual_only` com materiais, uma criatura do Círculo e
/// a condição do mundo. Acertou, a criatura é selada; errou, ela escapa e os materiais se perdem. Dart puro.
///
/// A fase de pressão com sigilos desenhados NÃO existe aqui (fase 3).
///
/// Pesquisa dos espaços (`conjurer.ritualResearch[espécie]` = quantos espaços estão revelados, na ordem fixa condição,
/// materiais, Círculo): cada avistamento de um Eco de ritual diferente (um spawn novo, em outra janela) revela
/// `ritual.slots_per_sighting` espaços; selar a criatura revela todos.
library;

import '../capture/eco_type.dart';
import '../core/species_ids.dart';
import '../data/game_data.dart';
import '../player/game_state.dart';
import '../player/progression.dart' show tuningXp;
import 'ritual_data.dart';

/// O que errou. Só para teste e telemetria: a tela nunca diz qual espaço está errado.
enum RitualMiss { material, quantity, condition, circle }

enum RitualStatus { success, wrong, blocked }

class PlacedMaterial {
  const PlacedMaterial(this.item, this.qty);

  final String item;
  final int qty;
}

/// O que o jogador montou: um material por espaço (`null` = vazio), a criatura do Círculo e o mundo agora.
class RitualAttempt {
  const RitualAttempt({required this.materials, required this.circleUid, required this.world});

  final List<PlacedMaterial?> materials;
  final String? circleUid;
  final WorldCondition world;
}

class RitualOutcome {
  const RitualOutcome(this.status, {this.misses = const {}, this.creature, this.blockedReason = ''});

  final RitualStatus status;
  final Set<RitualMiss> misses;

  /// A criatura selada, no sucesso.
  final CreatureInstance? creature;

  /// Por que nem tentou (nível baixo, falta material, criatura fora do Círculo). Nada foi gasto.
  final String blockedReason;

  bool get success => status == RitualStatus.success;
}

/// Os espaços que erraram. Vazio: combinação certa. O Círculo certo é uma criatura de tipo forte contra [target] e nível
/// [circleLevel] ou mais ([circleType] `null`: nenhuma escolhida).
Set<RitualMiss> judgeRitual(RitualRecipe r, RitualAttempt a, {required EcoType target, EcoType? circleType, int circleLevel = 0}) {
  final misses = <RitualMiss>{};
  for (var i = 0; i < r.materials.length; i++) {
    final want = r.materials[i];
    final got = i < a.materials.length ? a.materials[i] : null;
    if (got == null || got.item != want.item) {
      misses.add(RitualMiss.material);
    } else if (got.qty != want.qty) {
      misses.add(RitualMiss.quantity);
    }
  }
  if (!r.condition.holds(a.world)) misses.add(RitualMiss.condition);
  if (circleType == null || !circleType.beats(target) || circleLevel < r.circleMinLevel) misses.add(RitualMiss.circle);
  return misses;
}

/// Tenta o ritual de [recipe] contra o Eco [uid] de nível [level]. Atômico: ou nada acontece (`blocked`), ou os
/// materiais colocados são gastos e a criatura é selada (`success`) ou foge (`wrong`).
RitualOutcome performRitual({
  required GameState state,
  required GameData data,
  required RitualRecipe recipe,
  required RitualAttempt attempt,
  required int uid,
  required int level,
  required int nowUtc,
  String? variant,
  bool shiny = false,
}) {
  final species = data.species(recipe.speciesId);
  if (species == null) return const RitualOutcome(RitualStatus.blocked, blockedReason: 'Espécie desconhecida');
  if (state.playerLevel < state.cb.ritualLevel) {
    return RitualOutcome(RitualStatus.blocked, blockedReason: 'O mentor ensina o ritual no nível ${state.cb.ritualLevel}');
  }
  final cost = <String, int>{};
  for (final m in attempt.materials) {
    if (m != null) cost[m.item] = (cost[m.item] ?? 0) + m.qty;
  }
  if (cost.entries.any((e) => state.count(e.key) < e.value)) {
    return const RitualOutcome(RitualStatus.blocked, blockedReason: 'Faltam materiais na Bolsa');
  }
  final circle = attempt.circleUid == null ? null : state.creature(attempt.circleUid!);
  if (attempt.circleUid != null && (circle == null || !state.inCircle(circle.uid))) {
    return const RitualOutcome(RitualStatus.blocked, blockedReason: 'A criatura não está no Círculo');
  }
  final circleSpecies = circle == null ? null : data.species(circle.speciesId);
  final misses = judgeRitual(recipe, attempt, target: species.type, circleType: circleSpecies?.type, circleLevel: circle?.level ?? 0);

  if (state.isDone(uid)) return const RitualOutcome(RitualStatus.blocked, blockedReason: 'Esse Eco já se foi');
  state.spend(cost);
  if (misses.isNotEmpty) {
    state.markDone(uid, nowUtc); // a criatura escapou: entra no registro de feitos como fuga
    state.recordEvent('ritual_failed', recipe.speciesId, 1);
    return RitualOutcome(RitualStatus.wrong, misses: misses);
  }
  final first = !state.hasCaptured(species.id);
  final c = state.capture(uid: uid, speciesId: species.id, level: level, nowUtc: nowUtc, variant: variant, shiny: shiny);
  state.conjurer.ritualResearch[species.id] = recipe.slotCount; // selar ensina a receita inteira
  state.recordEvent('capture', species.type.name, 1);
  state.recordEvent('ritual_done', species.id, 1);
  final b = state.balance;
  state.gainXp(tuningXp(level, b) + (first ? b.firstCapture : 0), nowUtc);
  return RitualOutcome(RitualStatus.success, creature: c);
}

/// Quantos espaços da receita a pesquisa já revelou.
int ritualRevealed(GameState s, RitualRecipe r) => (s.conjurer.ritualResearch[r.speciesId] ?? 0).clamp(0, r.slotCount);

/// Um Eco de ritual [uid] da espécie [speciesId] apareceu à vista. Cada Eco diferente ([seen] guarda os já contados nesta
/// sessão) revela espaços e, no primeiro da família, solta o evento da dica do mentor (`ritual_seen_<família>`).
void noteRitualSighting(GameState s, RitualBook book, int uid, String speciesId, Set<int> seen) {
  final r = book.of(speciesId);
  if (r == null || !seen.add(uid)) return;
  final now = ritualRevealed(s, r);
  if (now < r.slotCount) {
    s.conjurer.ritualResearch[speciesId] = (now + book.balance.slotsPerSighting).clamp(0, r.slotCount);
  }
  final kind = 'ritual_seen_${familyOfId(speciesId)}';
  if (s.story.count(kind) == 0) s.recordEvent(kind, '', 1);
  s.recordEvent('ritual_sighting', speciesId, 1); // também avisa os ouvintes (grava o save)
}

/// Chegou o nível do ritual: solta o evento que libera a mensagem do mentor (uma vez).
void syncRitualUnlock(GameState s) {
  if (s.playerLevel >= s.cb.ritualLevel && s.story.count('ritual_unlocked') == 0) s.recordEvent('ritual_unlocked', '', 1);
}

/// A chave do ajuste que guarda quantos espaços o jogador já viu no Bestiário.
String ritualViewedKey(String speciesId) => 'ritual_viewed_$speciesId';

/// Há espaço de ritual revelado que o jogador ainda não viu no Bestiário (a bolinha de novidade).
bool ritualResearchUnseen(GameState s) => s.conjurer.ritualResearch.entries.any((e) => e.value > ((s.settings[ritualViewedKey(e.key)] as int?) ?? 0));

/// O jogador viu os espaços revelados de [speciesId].
void markRitualViewed(GameState s, String speciesId) {
  final n = s.conjurer.ritualResearch[speciesId] ?? 0;
  if (((s.settings[ritualViewedKey(speciesId)] as int?) ?? 0) < n) s.setSetting(ritualViewedKey(speciesId), n);
}
