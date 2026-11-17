/// A bolsa da fase 1 (docs/GDD.md, "Regras da fase 1"): espaços (cada pilha de até 99 ocupa um, cada recipiente guardado
/// também), capacidade pela bolsa equipada, as abas e o descarte, que rende Pó de Essência. Criaturas não ficam na
/// bolsa, ficam na Coleção. Dart puro.
library;

import '../player/game_state.dart';
import 'crafting.dart' show essenceIds;
import 'crafting_data.dart';
import 'crafting_state.dart';
import 'loadout.dart';
import 'quality.dart';

int _slots(int n, int stack) => n <= 0 ? 0 : (n + stack - 1) ~/ stack;

/// Espaços ocupados por [inventory] e pelos recipientes guardados na bolsa.
int slotsUsedBy(Map<String, int> inventory, int vesselsInBag, int stack) => inventory.values.fold(0, (n, q) => n + _slots(q, stack)) + vesselsInBag;

/// Quantos de [n] da pilha [key] cabem: o que falta para completar as pilhas de [key] já abertas mais as pilhas novas que
/// os espaços livres comportam. A bolsa nunca passa de [cap] (0.24.1): o resto é recusado.
int acceptableCount({required Map<String, int> inventory, required int vesselsInBag, required int stack, required int cap, required String key, required int n}) {
  final have = inventory[key] ?? 0;
  final room = _slots(have, stack) * stack - have;
  final free = cap - slotsUsedBy(inventory, vesselsInBag, stack);
  final max = room + (free > 0 ? free * stack : 0);
  return n < 0 ? 0 : (n < max ? n : max);
}

/// Quantos de [n] da pilha [key] cabem na bolsa de [s] agora.
int acceptable(GameState s, CraftingBook book, int utc, String key, int n) => acceptableCount(
      inventory: s.inventory,
      vesselsInBag: s.crafting.at(VesselPlace.bag).length,
      stack: book.balance.stack,
      cap: bagCapacity(s, book, utc),
      key: key,
      n: n,
    );

int slotsUsed(GameState s, CraftingBook book) => slotsUsedBy(s.inventory, s.crafting.at(VesselPlace.bag).length, book.balance.stack);

/// Se a bolsa comporta a troca: [remove] sai e [add] entra (chaves de pilha exatas).
bool fitsAfter(GameState s, CraftingBook book, int utc, {Map<String, int> add = const {}, Map<String, int> remove = const {}}) {
  final inv = {...s.inventory};
  for (final e in remove.entries) {
    inv[e.key] = (inv[e.key] ?? 0) - e.value;
  }
  for (final e in add.entries) {
    inv[e.key] = (inv[e.key] ?? 0) + e.value;
  }
  final after = slotsUsedBy(inv, s.crafting.at(VesselPlace.bag).length, book.balance.stack);
  // Quem já está acima (save antigo cheio) pode trocar sem crescer: só recusa o que aumenta os espaços.
  return after <= bagCapacity(s, book, utc) || after <= slotsUsed(s, book);
}

/// Se cabem [n] [key] (chave de pilha) na bolsa.
bool fits(GameState s, CraftingBook book, int utc, String key, int n) => fitsAfter(s, book, utc, add: {key: n});

/// As pilhas de uma aba, os fixados primeiro e depois pela ordem do id. Recipientes guardados ficam em [BagTab.conditions]
/// fora desta lista (a aba Condições lista o cinto e os plantados).
List<MapEntry<String, int>> tabStacks(GameState s, CraftingBook book, BagTab tab, {Tier? tier}) {
  final out = [
    for (final e in s.inventory.entries)
      if (e.value > 0 && (book.item(e.key)?.tab ?? BagTab.materials) == tab && (tier == null || book.item(e.key)?.tier == tier)) e,
  ];
  final pins = s.crafting.pins;
  int rank(String key) {
    final i = pins.indexOf(parseStack(key).id);
    return i < 0 ? pins.length : i;
  }

  out.sort((a, b) {
    final r = rank(a.key).compareTo(rank(b.key));
    return r != 0 ? r : a.key.compareTo(b.key);
  });
  return out;
}

/// Quantos itens há em cada aba (a contagem do topo das abas).
Map<BagTab, int> tabCounts(GameState s, CraftingBook book) {
  final out = {for (final t in BagTab.values) t: 0};
  for (final e in s.inventory.entries) {
    if (e.value <= 0) continue;
    final t = book.item(e.key)?.tab ?? BagTab.materials;
    out[t] = out[t]! + e.value;
  }
  out[BagTab.conditions] = out[BagTab.conditions]! + s.crafting.vessels.length;
  return out;
}

/// O Pó que o descarte de [id] rende: o do tipo do item, ou o tipo de que o jogador tem menos.
String dustFor(GameState s, CraftingBook book, String id) {
  final type = book.item(id)?.type;
  if (type != null && book.items.containsKey('item.dust.$type')) return 'item.dust.$type';
  final dusts = [for (final e in essenceIds) e.replaceFirst('item.essence.', 'item.dust.')]..removeWhere((d) => !book.items.containsKey(d));
  dusts.sort((a, b) => s.count(a).compareTo(s.count(b))); // estável: empate segue a ordem de sempre
  return dusts.first;
}

/// Descarta [n] da pilha [key] e devolve o Pó ganho (1 a cada `discard_per_dust`). Nada se a pilha não tem [n].
({String dust, int qty})? discard(GameState s, CraftingBook book, String key, int n) {
  if (n <= 0 || (s.inventory[key] ?? 0) < n) return null;
  final left = s.inventory[key]! - n;
  left == 0 ? s.inventory.remove(key) : s.inventory[key] = left;
  final dust = dustFor(s, book, parseStack(key).id);
  final qty = n ~/ book.balance.discardPerDust;
  if (qty > 0) {
    s.add(dust, qty);
  } else {
    s.changed();
  }
  s.recordEvent('discard', parseStack(key).id, n);
  return (dust: dust, qty: qty);
}

/// Fixa ou solta [id] no topo da bolsa.
void togglePin(GameState s, String id) {
  final pins = s.crafting.pins;
  pins.contains(id) ? pins.remove(id) : pins.insert(0, id);
  s.changed();
}
