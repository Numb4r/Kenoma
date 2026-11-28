/// O que o jogador faz na Casa (GDD rev 400): definir o lugar, mover entre a Bolsa e o Armazém, guardar criaturas no
/// santuário, instalar móveis, pôr e tirar quem trabalha, escolher o que cada estação faz e recolher. Tudo, menos definir
/// a casa, só vale dentro do raio dela; fora, nada muda ([HomeResult.away]). Dart puro.
library;

import 'dart:math' as math;

import '../data/game_data.dart';
import '../player/game_state.dart';
import '../player/home.dart';
import 'bag.dart' show acceptableCount, slotsUsedBy;
import 'quality.dart';
import 'stations.dart';

enum HomeResult { ok, locked, noHome, away, cooldown, storageFull, sanctumFull, slotsFull, invalid }

/// Onde o jogador está (graus), ou `null` sem posição.
typedef HerePos = ({double lat, double lon});

bool homeOpen(GameState s) => s.playerLevel >= s.balance.home.unlockLevel;

/// Dentro do raio da casa.
bool atHome(GameState s, HerePos? here) => here != null && (s.home.distanceM(here.lat, here.lon) ?? double.infinity) <= s.balance.home.radiusM;

/// Quanto falta para poder trocar a casa de lugar, em segundos (0: já pode). Relógio antes da última troca conta como espera.
int cooldownLeftS(GameState s, int now) {
  final at = s.home.setUtc;
  if (s.home.cell == null || at == null) return 0;
  return math.max(0, at + s.balance.home.moveCooldownS - math.max(now, at));
}

/// Define a casa na célula z21 [cell] (a do jogador). [ignoreCooldown]: o debug.
HomeResult setHome(GameState s, (int, int) cell, int now, {bool ignoreCooldown = false}) {
  if (!homeOpen(s)) return HomeResult.locked;
  if (!ignoreCooldown && cooldownLeftS(s, now) > 0) return HomeResult.cooldown;
  s.home
    ..cell = cell
    ..setUtc = now;
  s.recordEvent('home_set', '', 1);
  return HomeResult.ok;
}

HomeResult _gate(GameState s, HerePos? here) {
  if (!homeOpen(s)) return HomeResult.locked;
  if (s.home.cell == null) return HomeResult.noHome;
  return atHome(s, here) ? HomeResult.ok : HomeResult.away;
}

/// Os espaços de item do Armazém: os do começo e os das estantes.
int storageCap(GameState s, GameData data) => s.balance.home.storageItems + _furnitureSum(s, data, 'storage_items');

/// Os espaços de criatura do santuário: os do começo e os dos santuários instalados.
int sanctumCap(GameState s, GameData data) => s.balance.home.storageCreatures + _furnitureSum(s, data, 'storage_creatures');

int _furnitureSum(GameState s, GameData data, String effect) =>
    s.home.furniture.entries.fold(0, (a, e) => a + ((data.craft.item(e.key)?.effects[effect] ?? 0) * e.value).round());

int storageUsed(GameState s, GameData data) => slotsUsedBy(s.home.storage, 0, data.craft.balance.stack);
int sanctumUsed(GameState s) => s.home.creaturesAtHome.length;

/// Quantos de [n] da pilha [key] cabem no Armazém.
int storageRoom(GameState s, GameData data, String key, int n) =>
    acceptableCount(inventory: s.home.storage, vesselsInBag: 0, stack: data.craft.balance.stack, cap: storageCap(s, data), key: key, n: n);

/// Da Bolsa para o Armazém: [n] da pilha [key] (chave exata). Entra o que cabe.
HomeResult storeItem(GameState s, GameData data, HerePos? here, String key, int n) {
  final g = _gate(s, here);
  if (g != HomeResult.ok) return g;
  final have = s.inventory[key] ?? 0, move = math.min(storageRoom(s, data, key, math.min(n, have)), have);
  if (move <= 0) return have <= 0 ? HomeResult.invalid : HomeResult.storageFull;
  s.inventory[key] = have - move;
  if (s.inventory[key] == 0) s.inventory.remove(key);
  s.home.storage[key] = (s.home.storage[key] ?? 0) + move;
  s.changed();
  return HomeResult.ok;
}

/// Do Armazém para a Bolsa: o que a Bolsa aceita.
HomeResult takeItem(GameState s, HerePos? here, String key, int n) {
  final g = _gate(s, here);
  if (g != HomeResult.ok) return g;
  final have = s.home.storage[key] ?? 0;
  if (have <= 0) return HomeResult.invalid;
  final moved = s.add(key, math.min(n, have));
  if (moved <= 0) return HomeResult.storageFull;
  s.home.storage[key] = have - moved;
  if (s.home.storage[key] == 0) s.home.storage.remove(key);
  s.changed();
  return HomeResult.ok;
}

/// Guarda a criatura no santuário (sai do Círculo).
HomeResult storeCreature(GameState s, GameData data, HerePos? here, String uid) {
  final g = _gate(s, here);
  if (g != HomeResult.ok) return g;
  if (s.creature(uid) == null || s.home.holds(uid)) return HomeResult.invalid;
  if (sanctumUsed(s) >= sanctumCap(s, data)) return HomeResult.sanctumFull;
  s.circle.remove(uid);
  s.home.stored.add(uid);
  s.changed();
  return HomeResult.ok;
}

/// Tira do santuário (ou da estação) e devolve à coleção.
HomeResult retrieveCreature(GameState s, GameData data, HerePos? here, String uid, int now) {
  final g = _gate(s, here);
  if (g != HomeResult.ok) return g;
  if (s.home.stored.remove(uid)) {
    s.changed();
    return HomeResult.ok;
  }
  final station = s.home.stationOf(uid);
  return station == null ? HomeResult.invalid : unassign(s, data, here, station, uid, now);
}

/// Instala um móvel da Bolsa ou do Armazém (gasta o item), até [HomeBalance.furnitureMax] de cada.
HomeResult installFurniture(GameState s, GameData data, HerePos? here, String itemId) {
  final g = _gate(s, here);
  if (g != HomeResult.ok) return g;
  if (data.craft.item(itemId)?.kind != 'furniture' || (s.home.furniture[itemId] ?? 0) >= s.balance.home.furnitureMax) return HomeResult.invalid;
  if (!s.take(itemId)) {
    final key = s.home.storage.keys.where((k) => parseStack(k).id == itemId && (s.home.storage[k] ?? 0) > 0).firstOrNull;
    if (key == null) return HomeResult.invalid;
    s.home.storage[key] = s.home.storage[key]! - 1;
    if (s.home.storage[key] == 0) s.home.storage.remove(key);
  }
  s.home.furniture[itemId] = (s.home.furniture[itemId] ?? 0) + 1;
  s.changed();
  return HomeResult.ok;
}

/// Põe [uid] para trabalhar em [stationId]: da família da estação, com vaga e com espaço no santuário; sai do Círculo.
HomeResult assign(GameState s, GameData data, HerePos? here, String stationId, String uid, int now) {
  final g = _gate(s, here);
  if (g != HomeResult.ok) return g;
  final def = data.home.station(stationId), c = s.creature(uid);
  if (def == null || c == null || !canWork(def, c, s.balance.home) || s.home.stationOf(uid) != null) return HomeResult.invalid;
  final st = s.home.station(stationId);
  if (st.workers.length >= s.balance.home.slotsAt(s.playerLevel)) return HomeResult.slotsFull;
  final fromStored = s.home.stored.contains(uid);
  if (!fromStored && sanctumUsed(s) >= sanctumCap(s, data)) return HomeResult.sanctumFull;
  settle(s, data, def, st, now);
  s.home.stored.remove(uid);
  s.circle.remove(uid);
  st.workers.add(uid);
  st.since[uid] = now;
  _refill(s, data, def, st);
  s.changed();
  return HomeResult.ok;
}

/// Tira [uid] da estação (volta à coleção). O que ele já fez fica no depósito.
HomeResult unassign(GameState s, GameData data, HerePos? here, String stationId, String uid, int now) {
  final g = _gate(s, here);
  if (g != HomeResult.ok) return g;
  final def = data.home.station(stationId), st = s.home.stations[stationId];
  if (def == null || st == null || !st.workers.contains(uid)) return HomeResult.invalid;
  settle(s, data, def, st, now);
  st.workers.remove(uid);
  st.since.remove(uid);
  s.changed();
  return HomeResult.ok;
}

/// Troca o que a estação faz: recolhe, devolve a carga ao Armazém e carrega para a escolha nova.
HomeResult choose(GameState s, GameData data, HerePos? here, String stationId, String? choice, int now) {
  final g = _gate(s, here);
  if (g != HomeResult.ok) return g;
  final def = data.home.station(stationId);
  if (def == null || (choice != null && !stationChoices(s, data, def).contains(choice))) return HomeResult.invalid;
  final st = s.home.station(stationId);
  collect(s, data, here, stationId, now);
  for (final e in [...st.load.entries]) {
    final back = math.min(e.value, storageRoom(s, data, e.key, e.value));
    s.home.storage[e.key] = (s.home.storage[e.key] ?? 0) + back;
    if (back < e.value) {
      st.load[e.key] = e.value - back; // não coube: fica na estação até caber
    } else {
      st.load.remove(e.key);
    }
  }
  if (st.load.isNotEmpty) return HomeResult.storageFull;
  st.choice = choice;
  _refill(s, data, def, st);
  s.changed();
  return HomeResult.ok;
}

/// Recolhe o depósito para o Armazém (o que couber; os pontos do Arquivo vão para a pesquisa da espécie escolhida) e
/// recarrega os insumos.
HomeResult collect(GameState s, GameData data, HerePos? here, String stationId, int now) {
  final g = _gate(s, here);
  if (g != HomeResult.ok) return g;
  final def = data.home.station(stationId);
  if (def == null) return HomeResult.invalid;
  final st = s.home.station(stationId);
  settle(s, data, def, st, now);
  var full = false;
  for (final e in [...st.stock.entries]) {
    if (e.key == kPointsKey) {
      final species = st.choice;
      final per = s.balance.home.archivePointsPerTask;
      if (species == null || e.value < per) continue;
      final b = s.bestiary[species];
      if (b != null) s.bestiary[species] = b.copyWith(archived: b.archived + e.value ~/ per);
      st.stock[kPointsKey] = e.value % per;
      if (st.stock[kPointsKey] == 0) st.stock.remove(kPointsKey);
      continue;
    }
    final move = storageRoom(s, data, e.key, e.value);
    if (move < e.value) full = true;
    if (move <= 0) continue;
    s.home.storage[e.key] = (s.home.storage[e.key] ?? 0) + move;
    if (move == e.value) {
      st.stock.remove(e.key);
    } else {
      st.stock[e.key] = e.value - move;
    }
  }
  _refill(s, data, def, st);
  s.changed();
  return full ? HomeResult.storageFull : HomeResult.ok;
}

/// Tira do Armazém os insumos para o depósito inteiro (o que falta para a carga cobrir as peças que ainda cabem), a pior
/// qualidade primeiro para guardar o material bom; a Adega tira da pilha exata.
void _refill(GameState s, GameData data, StationDef def, StationState st) {
  final p = planOf(data, def, st.choice);
  if (p == null || p.need.isEmpty) return;
  final cap = depositUnits(workersOf(s, st), s.balance.home);
  final stockUnits = (st.stock.values.fold<int>(0, (a, b) => a + b) / p.outN).ceil();
  final loaded = p.need.entries.map((e) => (st.load[e.key] ?? 0) ~/ e.value).fold(1 << 30, math.min);
  int have(String key) => key.contains('@') || p.fixed != null ? (s.home.storage[key] ?? 0) : [for (final k in stackKeys(key)) s.home.storage[k] ?? 0].fold(0, (a, b) => a + b);
  final can = p.need.entries.map((e) => have(e.key) ~/ e.value).fold(1 << 30, math.min);
  final units = math.min(math.max(0, cap - stockUnits - loaded), can);
  if (units <= 0) return;
  for (final e in p.need.entries) {
    var left = e.value * units;
    final keys = e.key.contains('@') || p.fixed != null ? [e.key] : stackKeys(e.key);
    for (final k in keys) {
      final take = math.min(left, s.home.storage[k] ?? 0);
      if (take <= 0) continue;
      s.home.storage[k] = s.home.storage[k]! - take;
      if (s.home.storage[k] == 0) s.home.storage.remove(k);
      left -= take;
    }
    st.load[e.key] = (st.load[e.key] ?? 0) + e.value * units;
  }
}
