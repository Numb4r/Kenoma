/// A Bancada (docs/fase0-spec.md, seção 7): receitas improvisadas e a destilação de Ecos em Essência. Dart puro.
library;

import '../data/game_data.dart';
import '../player/game_state.dart';
import '../player/progress_balance.dart';

/// As três Essências, na ordem usada para desempatar.
const List<String> essenceIds = ['item.essence.fire', 'item.essence.plant', 'item.essence.water'];

int essenceTotal(GameState s) => essenceIds.fold(0, (sum, id) => sum + s.count(id));

/// O que a receita gasta de verdade: os ingredientes fixos mais [Recipe.anyEssence] Essências tiradas primeiro
/// da pilha maior. `null` se falta algo.
Map<String, int>? craftPlan(GameState s, Recipe r) {
  if (r.inputs.entries.any((e) => s.count(e.key) < e.value)) return null;
  if (essenceTotal(s) < r.anyEssence) return null;
  final plan = {...r.inputs};
  var left = r.anyEssence;
  final stacks = [...essenceIds]..sort((a, b) => s.count(b).compareTo(s.count(a))); // estável: empate segue a ordem
  for (final id in stacks) {
    if (left == 0) break;
    final take = left < s.count(id) ? left : s.count(id);
    if (take > 0) plan[id] = take;
    left -= take;
  }
  return plan;
}

bool canCraft(GameState s, Recipe r) => craftPlan(s, r) != null;

/// Fabrica a receita. `false` se falta algum ingrediente (nada é gasto).
bool craftRecipe(GameState s, Recipe r) {
  final plan = craftPlan(s, r);
  if (plan == null || !s.craft(plan, r.outId, r.outQty)) return false;
  s.recordEvent('craft', r.id, 1);
  return true;
}

/// Essência que um Eco de nível [level] rende: 3 do 1 ao 7, 4 do 8 ao 14, 5 do 15 ao 20.
int distillYield(int level, ProgressBalance b) {
  for (final band in b.distillYield) {
    if (level >= band.from && level <= band.to) return band.value;
  }
  return b.distillYield.last.value;
}

/// Por que um Eco não pode ser destilado, ou `null` se pode.
String? distillBlocker(GameState s, String uid) {
  if (s.creature(uid) == null) return 'Criatura não encontrada';
  if (s.inCircle(uid)) return 'Tire do Círculo antes de destilar';
  return null;
}

/// Destila o Eco [uid]: ele sai da coleção e vira Essência do tipo dele. Devolve o item e a quantidade, ou
/// `null` se não pode (Círculo, não existe, espécie desconhecida).
({String itemId, int qty})? distill(GameState s, String uid, GameData data) {
  final c = s.creature(uid);
  final species = c == null ? null : data.species(c.speciesId);
  if (c == null || species == null || distillBlocker(s, uid) != null) return null;
  final qty = distillYield(c.level, s.balance);
  s.removeCreature(uid);
  final id = 'item.essence.${species.type.name}';
  s.add(id, qty);
  s.recordEvent('distill', '', 1);
  return (itemId: id, qty: qty);
}
