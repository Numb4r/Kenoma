/// As estações da Casa (GDD rev 400, "Primeiro recorte da casa"): o que cada uma faz (`home.json`), quem pode trabalhar
/// nela, quanto sai pelo tempo decorrido (determinístico: cada criatura faz um item a cada período desde o instante em que
/// conta) e o depósito, que para a estação quando enche. Relógio voltando para trás não produz. Dart puro.
library;

import 'dart:math' as math;

import '../core/species_ids.dart';
import '../data/game_data.dart';
import '../player/game_state.dart';
import '../player/home.dart';
import '../player/lot.dart';
import '../player/research.dart' show researchLevel;
import 'grimoire.dart' show isKnown;
import 'quality.dart';

/// O que uma estação pode fazer: um item sem insumo (`out`), receitas (`recipe`, a Forja), os selos de receita conhecida
/// (`seals`), envelhecer Essência (`age`, a Adega) ou pesquisa do Bestiário (`research`, o Arquivo).
enum StationKind { out, recipe, seals, age, research }

class StationDef {
  const StationDef({required this.id, required this.family, required this.name, required this.icon, required this.about, required this.kind, this.outId, this.recipes = const []});

  factory StationDef.fromJson(Map<String, dynamic> j) {
    final products = [for (final p in j['products'] as List<dynamic>) p as Map<String, dynamic>];
    final first = products.first;
    final kind = first.containsKey('recipe')
        ? StationKind.recipe
        : first.containsKey('seals')
            ? StationKind.seals
            : first.containsKey('age')
                ? StationKind.age
                : first.containsKey('research')
                    ? StationKind.research
                    : StationKind.out;
    return StationDef(
      id: j['id'] as String,
      family: j['family'] as String,
      name: j['name'] as String,
      icon: j['icon'] as String,
      about: j['about'] as String,
      kind: kind,
      outId: first['out'] as String?,
      recipes: [for (final p in products) if (p['recipe'] case final String r) r],
    );
  }

  final String id, family, name, icon, about;
  final StationKind kind;
  final String? outId;
  final List<String> recipes;
}

/// `home.json`: as estações e os textos do app.
class HomeData {
  const HomeData({this.stations = const [], this.texts = const {}, this.pieces = const {}, this.tabs = const [], this.starter = const {}});

  factory HomeData.fromJson(Map<String, dynamic>? j) => j == null
      ? const HomeData()
      : HomeData(
          stations: [for (final s in j['stations'] as List<dynamic>) StationDef.fromJson(s as Map<String, dynamic>)],
          texts: {for (final e in ((j['texts'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as String},
          pieces: {for (final p in (j['pieces'] as List<dynamic>?) ?? const []) (p as Map<String, dynamic>)['item'] as String: PieceDef.fromJson(p)},
          tabs: [for (final t in (j['lot_tabs'] as List<dynamic>?) ?? const []) ((t as List<dynamic>)[0] as String, t[1] as String)],
          starter: (j['lot_starter'] as Map<String, dynamic>?) ?? const {},
        );

  final List<StationDef> stations;
  final Map<String, String> texts;

  /// 0.29.0: as peças do lote, pelo id do item; as abas do modo construir (id, rótulo); o lote inicial.
  final Map<String, PieceDef> pieces;
  final List<(String, String)> tabs;
  final Map<String, dynamic> starter;

  /// A peça que é a estação [stationId].
  PieceDef? pieceOfStation(String stationId) => pieces.values.where((p) => p.station == stationId).firstOrNull;

  StationDef? station(String id) => stations.where((s) => s.id == id).firstOrNull;
  StationDef? ofFamily(String family) => stations.where((s) => s.family == family).firstOrNull;
  String text(String key) => texts[key] ?? key;
}

/// Uma criatura trabalhando: o período de um item e a qualidade do que ela faz.
class Worker {
  const Worker(this.uid, this.periodS, this.quality);

  final String uid;
  final int periodS;
  final Quality quality;
}

/// A qualidade pelo traço: Brilhante dá perfeita; qualquer outro traço (a variante, os herdados), boa; sem traço, comum.
Quality workQuality(CreatureInstance c) =>
    c.shiny || c.traits.contains('shiny') ? Quality.perfect : (c.variant != null || c.traits.isNotEmpty ? Quality.good : Quality.common);

/// Se [c] pode trabalhar em [def]: da família da estação e numa camada que trabalha.
bool canWork(StationDef def, CreatureInstance c, HomeBalance b) => familyOfId(c.speciesId) == def.family && b.periodOf(c.speciesId, c.level) != null;

/// Uma peça da estação: o que ela gasta da carga e o que entrega (a chave da pilha sai com a qualidade de quem fez, menos na
/// Adega, que já diz a qualidade nova; o Arquivo entrega pontos).
class UnitPlan {
  const UnitPlan({this.need = const {}, this.outId, this.outN = 1, this.fixed, this.points = false});

  final Map<String, int> need;
  final String? outId;
  final int outN;
  final Quality? fixed;
  final bool points;
}

const String kPointsKey = 'points';

/// O que [def] pode fazer agora para o jogador: as receitas conhecidas (Forja, Fábrica de selos), as pilhas de Essência do
/// Armazém que ainda sobem (Adega) ou as espécies vistas com pesquisa por fazer (Arquivo).
List<String> stationChoices(GameState s, GameData data, StationDef def) {
  bool known(String id) => data.recipes[id] != null && isKnown(s, data.recipes[id]!);
  switch (def.kind) {
    case StationKind.out:
      return const [];
    case StationKind.recipe:
      return [for (final r in def.recipes) if (data.recipes[r] != null && known(r)) r];
    case StationKind.seals:
      return [
        for (final r in data.recipes.values)
          if (data.craft.item(r.outId)?.kind == 'seal' && r.anyOf.isEmpty && r.needs.isNone && r.inputs.isNotEmpty && known(r.id)) r.id,
      ]..sort();
    case StationKind.age:
      return [
        for (final k in s.home.storage.keys)
          if ((s.home.storage[k] ?? 0) > 0 && data.craft.item(parseStack(k).id)?.kind == 'essence' && parseStack(k).q != Quality.perfect) k,
      ]..sort();
    case StationKind.research:
      return [
        for (final e in s.bestiary.entries)
          if (e.value.seen && data.lore[e.key] != null && researchLevelOf(s, data, e.key) < data.lore[e.key]!.research.length) e.key,
      ]..sort();
  }
}

/// O nível de pesquisa de [speciesId], contando as tarefas que o Arquivo já fez.
int researchLevelOf(GameState s, GameData data, String speciesId) => researchLevel(data.lore[speciesId]?.research ?? const [], speciesId, s.bestiary);

/// 0.29.0: a estação [id] está colocada no lote. Fora do lote ela não produz.
bool stationPlaced(GameState s, GameData data, String id) => s.home.lot.placed.any((p) => data.home.pieces[p.item]?.station == id);

/// A peça que [def] faz com a escolha [choice], ou `null` se não há o que fazer.
UnitPlan? planOf(GameData data, StationDef def, String? choice) {
  switch (def.kind) {
    case StationKind.out:
      return def.outId == null ? null : UnitPlan(outId: def.outId);
    case StationKind.recipe || StationKind.seals:
      final r = choice == null ? null : data.recipes[choice];
      return r == null ? null : UnitPlan(need: r.inputs, outId: r.outId, outN: r.outQty);
    case StationKind.age:
      if (choice == null) return null;
      final (:id, :q) = parseStack(choice);
      return q == Quality.perfect ? null : UnitPlan(need: {choice: 1}, outId: id, fixed: q.up());
    case StationKind.research:
      return choice == null ? null : const UnitPlan(points: true);
  }
}

/// As criaturas que trabalham em [st] agora (as que sumiram da coleção não contam).
List<Worker> workersOf(GameState s, StationState st) => [
      for (final uid in st.workers)
        if (s.creature(uid) case final c?)
          if (s.balance.home.periodOf(c.speciesId, c.level) case final p?) Worker(uid, p, workQuality(c)),
    ];

/// Quantas peças cabem no depósito: a produção de [HomeBalance.depositS] de quem trabalha, no mínimo uma.
int depositUnits(List<Worker> ws, HomeBalance b) => ws.isEmpty ? 0 : math.max(1, ws.fold<double>(0, (a, w) => a + b.depositS / w.periodS).floor());

int _stockUnits(StationState st, UnitPlan p) => p.points ? (st.stock[kPointsKey] ?? 0) : (st.stock.values.fold<int>(0, (a, b) => a + b) / p.outN).ceil();

int _loadUnits(StationState st, UnitPlan p) =>
    p.need.isEmpty ? 1 << 30 : p.need.entries.map((e) => (st.load[e.key] ?? 0) ~/ e.value).fold(1 << 30, math.min);

/// O que sairia de [st] até [t]: quantas peças cada um fez e quem parou (depósito cheio ou carga no fim). Não muda nada.
({Map<String, int> made, Set<String> blocked, List<int> times}) runUntil(StationState st, List<Worker> ws, UnitPlan p, int cap, int t) {
  final room = math.max(0, math.min(cap - _stockUnits(st, p), _loadUnits(st, p)));
  final events = <(int, String)>[];
  final due = <String, int>{};
  for (final w in ws) {
    final from = st.since[w.uid];
    if (from == null || t <= from) continue; // relógio para trás: nada
    final k = (t - from) ~/ w.periodS;
    due[w.uid] = k;
    for (var i = 1; i <= math.min(k, room); i++) {
      events.add((from + i * w.periodS, w.uid));
    }
  }
  events.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2.compareTo(b.$2));
  final made = <String, int>{};
  final times = <int>[];
  for (final (at, uid) in events.take(room)) {
    made[uid] = (made[uid] ?? 0) + 1;
    times.add(at);
  }
  return (made: made, blocked: {for (final e in due.entries) if ((made[e.key] ?? 0) < e.value) e.key}, times: times);
}

/// O estado de uma estação para a tela, sem mudar nada: o depósito agora, o tamanho dele e quando enche.
class StationView {
  const StationView({required this.def, required this.workers, required this.plan, required this.ready, required this.cap, this.fullAtUtc, this.starved = false, this.placed = true});

  final StationDef def;
  final List<Worker> workers;
  final UnitPlan? plan;

  /// Peças no depósito agora (pontos, no Arquivo).
  final int ready;
  final int cap;

  /// Quando o depósito enche no ritmo de agora; `null` se já está cheio, se ninguém trabalha ou se a carga acaba antes.
  final int? fullAtUtc;

  /// A carga de insumos acaba antes de o depósito encher.
  final bool starved;

  /// Colocada no lote (0.29.0); fora dele, parada.
  final bool placed;

  bool get full => cap > 0 && ready >= cap;
}

StationView stationView(GameState s, GameData data, StationDef def, int t) {
  final st = s.home.stations[def.id] ?? StationState();
  final ws = workersOf(s, st);
  final p = planOf(data, def, st.choice);
  if (p == null) return StationView(def: def, workers: ws, plan: null, ready: 0, cap: depositUnits(ws, s.balance.home), placed: stationPlaced(s, data, def.id));
  if (!stationPlaced(s, data, def.id)) return StationView(def: def, workers: ws, plan: p, ready: _stockUnits(st, p), cap: depositUnits(ws, s.balance.home), placed: false);
  final cap = depositUnits(ws, s.balance.home);
  final now = runUntil(st, ws, p, cap, t);
  final ready = _stockUnits(st, p) + now.made.values.fold<int>(0, (a, b) => a + b);
  if (ws.isEmpty || ready >= cap) return StationView(def: def, workers: ws, plan: p, ready: ready, cap: cap);
  final ahead = runUntil(st, ws, p, cap, t + 2 * s.balance.home.depositS);
  final total = _stockUnits(st, p) + ahead.times.length;
  return StationView(def: def, workers: ws, plan: p, ready: ready, cap: cap, fullAtUtc: total >= cap && ahead.times.isNotEmpty ? ahead.times.last : null, starved: total < cap);
}

/// Leva a produção de [st] até [t]: o que saiu entra no depósito, a carga gasta sai, e cada um conta de novo do ponto
/// certo (quem parou com o depósito cheio volta a contar de [t]).
void settle(GameState s, GameData data, StationDef def, StationState st, int t) {
  final ws = workersOf(s, st);
  final p = stationPlaced(s, data, def.id) ? planOf(data, def, st.choice) : null; // fora do lote, parada
  if (p == null) {
    for (final w in ws) {
      if ((st.since[w.uid] ?? t) < t) st.since[w.uid] = t; // sem o que fazer (ou fora do lote), não acumula
    }
    return;
  }
  final run = runUntil(st, ws, p, depositUnits(ws, s.balance.home), t);
  for (final w in ws) {
    final made = run.made[w.uid] ?? 0;
    final from = st.since[w.uid];
    if (from == null || t <= from) continue;
    st.since[w.uid] = run.blocked.contains(w.uid) ? t : from + made * w.periodS;
    for (var i = 0; i < made; i++) {
      for (final e in p.need.entries) {
        st.load[e.key] = (st.load[e.key] ?? 0) - e.value;
        if (st.load[e.key]! <= 0) st.load.remove(e.key);
      }
      final key = p.points ? kPointsKey : stackKey(p.outId!, p.fixed ?? w.quality);
      st.stock[key] = (st.stock[key] ?? 0) + (p.points ? 1 : p.outN);
    }
  }
}
