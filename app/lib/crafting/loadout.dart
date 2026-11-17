/// O loadout (docs/GDD.md, "Regras da fase 1"): equipar e tirar, a aparência separada do efeito, o que aparece no
/// personagem e a soma dos efeitos, que dá os limites da bolsa, do cinto e dos coletores plantados. Dart puro.
library;

import '../player/game_state.dart';
import 'conditions.dart';
import 'crafting_data.dart';
import 'crafting_state.dart';

/// A soma dos efeitos do que está equipado em [utc]: o amuleto de estação vale `in_season_mult` vezes na estação dele.
Map<String, double> loadoutEffects(GameState s, CraftingBook book, int utc) {
  final out = {for (final k in kEffectKeys) k: 0.0};
  for (final key in s.crafting.equipped.values) {
    final def = book.item(key);
    if (def == null) continue;
    final mult = def.season != null && seasonAt(utc) == def.season ? def.inSeasonMult : 1.0;
    for (final e in def.effects.entries) {
      out[e.key] = (out[e.key] ?? 0) + e.value * mult;
    }
  }
  return out;
}

int bagCapacity(GameState s, CraftingBook book, int utc) => book.balance.baseSlots + loadoutEffects(s, book, utc)['bag_slots']!.round();
int beltCapacity(GameState s, CraftingBook book, int utc) => book.balance.beltSlots + loadoutEffects(s, book, utc)['belt_slots']!.round();
int plantedCapacity(GameState s, CraftingBook book, int utc) => book.balance.plantedSlots + loadoutEffects(s, book, utc)['planted_slots']!.round();

/// Equipa a pilha [key] no espaço [slot]: ela sai da bolsa e o que estava lá volta. `false` se não há o item ou se o
/// espaço não aceita esse tipo.
bool equip(GameState s, CraftingBook book, LoadoutSlot slot, String key) {
  final def = book.item(key);
  // A chave já é a pilha exata: o id puro é a pilha comum.
  if (def == null || def.kind != slot.kind || (s.inventory[key] ?? 0) <= 0) return false;
  s.spend({key: 1}); // id puro gasta a pior pilha primeiro, e a comum existe
  final old = s.crafting.equipped[slot];
  s.crafting.equipped[slot] = key;
  if (old != null) s.add(old, 1);
  return true;
}

/// Tira o item do espaço e o devolve à bolsa. `false`, sem tirar, se a bolsa não comporta (0.24.1: nada passa do limite).
bool unequip(GameState s, LoadoutSlot slot) {
  final old = s.crafting.equipped[slot];
  if (old == null) return false;
  s.crafting.equipped.remove(slot);
  if (s.add(old, 1) == 1) return true;
  s.crafting.equipped[slot] = old; // não coube: volta para o espaço
  s.changed();
  return false;
}

/// O item cuja cara aparece no espaço: a aparência escolhida ou, sem ela, o equipado.
String? lookOf(GameState s, LoadoutSlot slot) => s.crafting.looks[slot] ?? s.crafting.equipped[slot];

/// O que o sprite do Conjurador no mapa desenha: só o que lê no tamanho dele (a bolsa, as garrafas do cinto e o brilho do
/// amuleto), cada um se o espaço tem algo e não está escondido.
({bool bag, int bottles, bool amuletGlow}) avatarGear(GameState s) {
  final c = s.crafting;
  bool shown(LoadoutSlot slot) => !c.hidden.contains(slot) && lookOf(s, slot) != null;
  return (
    bag: shown(LoadoutSlot.bag),
    bottles: c.hidden.contains(LoadoutSlot.belt) ? 0 : c.at(VesselPlace.belt).length.clamp(0, 3),
    amuletGlow: shown(LoadoutSlot.amulet),
  );
}
