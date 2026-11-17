/// O grimório e a Bancada da fase 1 (docs/GDD.md, "Regras da fase 1" e "Qualidade e descoberta"): quais receitas o
/// jogador conhece, o que cada uma gasta de verdade (pilha por qualidade e recipientes cheios), a qualidade que sai (a do
/// pior ingrediente), fabricar, experimentar sem gastar e as silhuetas com pista das desconhecidas. Dart puro.
library;

import '../data/game_data.dart';
import '../player/game_state.dart';
import 'bag.dart';
import 'collectors.dart';
import 'conditions.dart';
import 'crafting.dart' show essenceIds;
import 'crafting_data.dart';
import 'crafting_state.dart';
import 'quality.dart';

bool isKnown(GameState s, Recipe r) =>
    r.discovery == Discovery.start || s.crafting.known.contains(r.id) || (r.page != null && s.crafting.pages.contains(r.page));

/// Por que o nível ainda não deixa a receita, ou `null`.
String? levelBlocker(GameState s, Recipe r, CraftingBalance b) {
  final need = b.unlockLevels[r.id] ?? (r.bench ? b.benchLevel : 1);
  return s.playerLevel < need ? 'Nível $need' : null;
}

bool isCondition(CraftingBook book, String id) => book.items[id]?.kind == 'condition';

/// Os ids de um grupo `any:` das receitas: Essências de tipo (`essence`), Pós (`dust`) e Essências de traço (`trait`).
List<String> anyGroupIds(String group, CraftingBook book) => switch (group) {
      'essence' => essenceIds,
      'dust' => [for (final i in book.items.values) if (i.kind == 'essence_dust') i.id],
      'trait' => [for (final i in book.items.values) if (i.kind == 'essence_trait') i.id],
      _ => const [],
    };

/// O grupo `any:` de [id], ou `null`.
String? anyGroupOf(String id, CraftingBook book) => essenceIds.contains(id)
    ? 'essence'
    : switch (book.items[id]?.kind) {
        'essence_dust' => 'dust',
        'essence_trait' => 'trait',
        _ => null,
      };

/// O que uma receita gasta e o que sai.
class CraftPlan {
  const CraftPlan({required this.stacks, required this.vessels, required this.quality, required this.limiting});

  /// Pilhas exatas (`item.chalk@good`) e quantidades.
  final Map<String, int> stacks;

  /// Os recipientes cheios que a receita esvazia.
  final List<Vessel> vessels;

  /// A qualidade do resultado: a do pior ingrediente.
  final Quality quality;

  /// Os ingredientes que seguram a qualidade (os da pior), para a caixa "Vai sair" dizer o que faltaria para subir.
  final List<String> limiting;
}

/// O plano de [times] vezes [r] com a escolha de qualidade [pick] (id -> qualidade; sem escolha, a pior primeiro).
/// `null` se falta algum ingrediente.
CraftPlan? planCraft(GameState s, Recipe r, CraftingBook book, {Map<String, Quality> pick = const {}, int times = 1}) {
  final stacks = <String, int>{};
  final vessels = <Vessel>[];
  final used = <String, Quality>{}; // id -> pior qualidade usada
  void note(String id, Quality q) => used[id] = used[id] == null ? q : Quality.worst([used[id]!, q]);
  for (final e in r.inputs.entries) {
    final need = e.value * times;
    if (isCondition(book, e.key)) {
      final have = [for (final v in carriedWith(s, e.key)) if (pick[e.key] == null || v.quality == pick[e.key]) v];
      if (have.length < need) return null;
      for (final v in have.take(need)) {
        vessels.add(v);
        note(e.key, v.quality);
      }
      continue;
    }
    final want = pick[e.key];
    final plan = s.stacksFor({want == null ? e.key : stackKey(e.key, want): need});
    if (plan == null) return null;
    for (final p in plan.entries) {
      stacks[p.key] = (stacks[p.key] ?? 0) + p.value;
      note(e.key, parseStack(p.key).q);
    }
  }
  for (final g in r.anyOf.entries) {
    var left = g.value * times;
    // De qualquer tipo do grupo, da pilha maior primeiro (empate segue a ordem de sempre).
    final ids = [...anyGroupIds(g.key, book)]..sort((a, b) => s.count(b).compareTo(s.count(a)));
    for (final id in ids) {
      if (left == 0) break;
      final avail = s.count(id) - (stacks[id] ?? 0);
      final take = left < avail ? left : avail;
      if (take <= 0) continue;
      final plan = s.stacksFor({id: take})!;
      for (final p in plan.entries) {
        stacks[p.key] = (stacks[p.key] ?? 0) + p.value;
        note('any:${g.key}', parseStack(p.key).q);
      }
      left -= take;
    }
    if (left > 0) return null;
  }
  final q = used.isEmpty ? Quality.common : Quality.worst(used.values);
  return CraftPlan(stacks: stacks, vessels: vessels, quality: q, limiting: [for (final e in used.entries) if (e.value == q) e.key]);
}

/// Por que não dá para fazer [r] agora em [h], ou `null`.
String? craftBlocker(GameState s, Recipe r, CraftingBook book, Here h, {Map<String, Quality> pick = const {}, int times = 1}) {
  if (!isKnown(s, r)) return 'Receita desconhecida';
  final lv = levelBlocker(s, r, book.balance);
  if (lv != null) return lv;
  final unmet = unmetNeeds(r.needs, h, book.balance);
  if (unmet.isNotEmpty) return 'Pede ${unmet.first.what} (${unmet.first.when})';
  final plan = planCraft(s, r, book, pick: pick, times: times);
  if (plan == null) return 'Falta material';
  if (!fitsAfter(s, book, h.utc, add: {stackKey(r.outId, plan.quality): r.outQty * times}, remove: plan.stacks)) return 'Bolsa cheia';
  return null;
}

/// Fabrica [times] vezes [r] em [h]. Devolve a qualidade que saiu, ou `null` (nada gasto) se não pode.
Quality? craftAt(GameState s, Recipe r, CraftingBook book, Here h, {Map<String, Quality> pick = const {}, int times = 1}) {
  if (craftBlocker(s, r, book, h, pick: pick, times: times) != null) return null;
  final plan = planCraft(s, r, book, pick: pick, times: times)!;
  for (final v in plan.vessels) {
    useContent(s, v);
  }
  s.craft(plan.stacks, r.outId, r.outQty * times, q: plan.quality);
  s.recordEvent('craft', r.id, times);
  final tier = book.items[r.outId]?.tier;
  if (tier == Tier.refined) s.recordEvent('refine', r.id, times);
  if (tier == Tier.component) s.recordEvent('component', r.id, times);
  return plan.quality;
}

/// Os três grupos da lista de receitas conhecidas da Bancada.
typedef RecipeGroups = ({List<(Recipe, Quality)> now, List<(Recipe, List<Unmet>)> waiting, List<Recipe> missing});

RecipeGroups groupRecipes(GameState s, Iterable<Recipe> recipes, CraftingBook book, Here h, {required bool bench}) {
  final now = <(Recipe, Quality)>[];
  final waiting = <(Recipe, List<Unmet>)>[];
  final missing = <Recipe>[];
  for (final r in recipes) {
    if (r.bench != bench || !isKnown(s, r) || levelBlocker(s, r, book.balance) != null) continue;
    final plan = planCraft(s, r, book);
    if (plan == null) {
      missing.add(r);
      continue;
    }
    final unmet = unmetNeeds(r.needs, h, book.balance);
    unmet.isEmpty ? now.add((r, plan.quality)) : waiting.add((r, unmet));
  }
  return (now: now, waiting: waiting, missing: missing);
}

/// O resultado de Tentar no Experimentar.
typedef TryResult = ({Recipe? learned, String text});

/// Junta os materiais [ids] (até três) em [h]. Nunca gasta nada: acerta a receita (que entra no grimório), ou dá uma pista
/// se a combinação é parte de uma receita que pede algo mais, ou nada acontece.
TryResult experiment(GameState s, List<String> ids, Iterable<Recipe> recipes, CraftingBook book, Here h) {
  // Um Pó ou uma Essência vale pelo grupo quando a receita pede "qualquer"; senão, pelo próprio id.
  String key(String id) => anyGroupOf(id, book) == null ? id : 'any:${anyGroupOf(id, book)}';
  final combo = {for (final id in ids) id};
  if (combo.isEmpty) return (learned: null, text: 'Junte um material ou mais');
  Set<String> inputsOf(Recipe r) => {...r.inputs.keys, for (final g in r.anyOf.keys) 'any:$g'};
  String? partial;
  for (final r in recipes) {
    if (isKnown(s, r) && r.discovery != Discovery.experiment) continue;
    final need = inputsOf(r);
    final mapped = {for (final id in combo) need.contains(id) ? id : key(id)};
    if (!need.containsAll(mapped)) continue;
    if (r.discovery == Discovery.page) {
      partial ??= 'Uma página do grimório explica essa mistura';
      continue;
    }
    if (need.length > mapped.length) {
      partial ??= r.hint.isEmpty ? 'Falta mais um material' : r.hint;
      continue;
    }
    final unmet = unmetNeeds(r.needs, h, book.balance);
    if (unmet.isNotEmpty) {
      partial ??= 'Falta algo: ${unmet.first.what}';
      continue;
    }
    if (isKnown(s, r)) return (learned: r, text: 'Você já conhece esta');
    s.crafting.known.add(r.id);
    s.recordEvent('discover', r.id, 1);
    return (learned: r, text: 'Receita nova no grimório');
  }
  return (learned: null, text: partial ?? 'Nada acontece. Nada se perdeu');
}

/// As receitas desconhecidas que usam algo que o jogador tem (ou só [itemId]): a silhueta do grimório, com o degrau do
/// resultado e a pista. As de página só aparecem depois que a página chega.
List<Recipe> silhouettes(GameState s, Iterable<Recipe> recipes, {String? itemId}) => [
      for (final r in recipes)
        if (!isKnown(s, r) && r.discovery == Discovery.experiment && r.inputs.keys.any((id) => itemId == null ? s.count(id) > 0 || carriedWith(s, id).isNotEmpty : id == itemId)) r,
    ];

/// As receitas conhecidas que usam [itemId].
List<Recipe> knownUsing(GameState s, Iterable<Recipe> recipes, CraftingBook book, String itemId) => [
      for (final r in recipes)
        if (isKnown(s, r) && (r.inputs.containsKey(itemId) || r.anyOf.containsKey(anyGroupOf(itemId, book)))) r,
    ];
