/// Os coletores da fase 1 (docs/GDD.md, "Coletores" e "Regras da fase 1"). Levados no cinto, enchem com a condição em volta
/// do jogador depois de alguns minutos (app aberto ou Patrulha). Plantados num ponto, enchem com a condição daquele lugar
/// e daquela janela, calculada como o resto do mundo, mesmo com o jogador longe; colher pede voltar ao alcance de toque.
/// O perecível estraga no mesmo ritmo plantado ou na bolsa, e a garrafa nunca some. Dart puro.
library;

import 'dart:math' as math;

import '../player/game_state.dart';
import 'conditions.dart';
import 'crafting_data.dart';
import 'crafting_state.dart';
import 'loadout.dart';
import 'quality.dart';

/// Metros entre dois pontos (equiretangular: sobra para distâncias de bairro).
double metersBetween(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final x = (lon2 - lon1) * math.pi / 180 * math.cos((lat1 + lat2) / 2 * math.pi / 180);
  final y = (lat2 - lat1) * math.pi / 180;
  return math.sqrt(x * x + y * y) * r;
}

/// A primeira regra que enche o recipiente [kind] em [h], ou `null`.
CollectorRule? ruleFor(String kind, Here h, CraftingBalance b) {
  for (final r in b.rules) {
    if (!r.vessels.contains(kind)) continue;
    if (r.night && !h.night(b)) continue;
    final byClimate = r.climates.any(h.climates.contains);
    final byEvent = r.events.any(h.events.contains);
    if ((r.climates.isNotEmpty || r.events.isNotEmpty) && !byClimate && !byEvent) continue;
    return r;
  }
  return null;
}

/// O que a regra põe no recipiente em [h] (`{moon}` vira o grupo de fase).
String ruleOut(CollectorRule r, Here h) => r.out.replaceAll('{moon}', h.moon.key);

void _fill(Vessel v, CollectorRule r, Here h, CraftingBalance b, int whenUtc) {
  final out = ruleOut(r, h);
  v
    ..content = out
    ..quality = rawQuality(out, h, b, base: r.quality)
    ..filledUtc = whenUtc
    ..progressS = 0
    ..progressRule = null;
}

/// Estraga ou derrete o conteúdo de [v] até [now]: a neve vira água de neve depois de `perish_h` (menos num recipiente que
/// guarda o frio), e o que estraga sem virar nada some, deixando o recipiente vazio. Devolve se mudou.
bool settle(Vessel v, int now, CraftingBook book) {
  var changed = false;
  for (var guard = 0; guard < 4 && v.content != null; guard++) {
    final def = book.items[v.content];
    final h = def?.perishH;
    if (h == null) break;
    if (def!.meltsTo != null && (book.items[v.kind]?.keepsCold ?? false)) break;
    final end = v.filledUtc + (h * 3600).round();
    if (now < end) break;
    changed = true;
    if (def.meltsTo == null) {
      v.clear();
    } else {
      v
        ..content = def.meltsTo
        ..filledUtc = end;
    }
  }
  return changed;
}

/// Um passo do cinto: [dtS] segundos de [h]. Recipiente vazio acumula a condição (e zera se ela muda ou acaba); cheio, só
/// estraga. `fill_speed` do loadout encurta o tempo. Devolve os que encheram agora.
List<Vessel> tickBelt(GameState s, Here h, double dtS, CraftingBook book) {
  final b = book.balance;
  final speed = 1 + loadoutEffects(s, book, h.utc)['fill_speed']!;
  final filled = <Vessel>[];
  for (final v in s.crafting.at(VesselPlace.belt)) {
    if (!v.empty) {
      settle(v, h.utc, book);
      continue;
    }
    final r = ruleFor(v.kind, h, b);
    if (r == null || r.id != v.progressRule) {
      v
        ..progressS = 0
        ..progressRule = r?.id;
    }
    if (r == null) continue;
    v.progressS += dtS * speed;
    if (v.progressS >= r.carryS) {
      _fill(v, r, h, b, h.utc);
      filled.add(v);
    }
  }
  return filled;
}

/// O estado de um coletor plantado na tela de Rotas, no Radar e na bolsa.
enum PlantedState { waiting, filling, full }

/// Passo da conta dos plantados: a condição de cada janela de clima é conferida a cada 10 minutos.
const int kPlantedStepS = 600;

/// No máximo tanto tempo de conta por chamada (um coletor esquecido por meses não trava a tela).
const int kPlantedMaxScanS = 21 * 86400;

/// Leva a conta do plantado [v] até [now] com [hereAt] (a condição naquele ponto em cada instante). Determinística: a
/// mesma seed e o mesmo tempo dão o mesmo resultado, com o jogador perto ou longe. Devolve o estado.
PlantedState updatePlanted(Vessel v, int now, Here Function(int t) hereAt, CraftingBook book) {
  final b = book.balance;
  if (!v.empty) {
    settle(v, now, book);
    if (!v.empty) return PlantedState.full;
    // estragou sem virar nada: o recipiente volta a esperar dali em diante
    v.checkedUtc = now;
  }
  var t = v.checkedUtc < v.plantedUtc ? v.plantedUtc : v.checkedUtc;
  final stop = math.min(now, t + kPlantedMaxScanS);
  while (t + kPlantedStepS <= stop) {
    final h = hereAt(t);
    final r = ruleFor(v.kind, h, b);
    if (r == null || r.id != v.progressRule) {
      v
        ..progressS = 0
        ..progressRule = r?.id;
    }
    t += kPlantedStepS;
    if (r == null) continue;
    v.progressS += kPlantedStepS;
    if (v.progressS >= r.plantedS) {
      _fill(v, r, h, b, t);
      v.checkedUtc = t;
      settle(v, now, book);
      return v.empty ? PlantedState.waiting : PlantedState.full;
    }
  }
  v.checkedUtc = t;
  return v.progressS > 0 ? PlantedState.filling : PlantedState.waiting;
}

/// Por que não dá para plantar um [kind] agora, ou `null` se dá. A pé (até [walkMaxMps]), com um recipiente vazio desse
/// tipo na bolsa, dentro do limite e a [CraftingBalance.plantedGapM] ou mais de outro plantado.
String? plantBlocker(GameState s, String kind, Here h, double speedMps, double walkMaxMps, CraftingBook book) {
  if (speedMps > walkMaxMps) return 'Só a pé: plante parado ou andando';
  if ((s.inventory[kind] ?? 0) <= 0) return 'Nenhum recipiente vazio desse na bolsa';
  final planted = s.crafting.at(VesselPlace.planted).toList();
  if (planted.length >= plantedCapacity(s, book, h.utc)) return 'Já há ${planted.length} coletores plantados';
  for (final p in planted) {
    final d = metersBetween(h.lat, h.lon, p.lat, p.lon);
    if (d < book.balance.plantedGapM) return 'Outro coletor a ${d.round()} m: plante a ${book.balance.plantedGapM.round()} m dele';
  }
  return null;
}

/// Planta um recipiente vazio [kind] em [h]. `null` se não pode (ver [plantBlocker]).
Vessel? plant(GameState s, String kind, Here h, double speedMps, double walkMaxMps, CraftingBook book) {
  if (plantBlocker(s, kind, h, speedMps, walkMaxMps, book) != null) return null;
  s.spend({kind: 1});
  final v = Vessel(uid: s.crafting.nextUid++, kind: kind, place: VesselPlace.planted, lat: h.lat, lon: h.lon, plantedUtc: h.utc, checkedUtc: h.utc);
  s.crafting.vessels.add(v);
  s.changed();
  return v;
}

/// Colhe o plantado [v] estando a [distM] dele: volta para o cinto se há espaço, senão para a bolsa. `false` se longe.
bool harvest(GameState s, Vessel v, double distM, double touchM, CraftingBook book, int now) {
  if (distM > touchM || v.place != VesselPlace.planted) return false;
  final beltFree = s.crafting.at(VesselPlace.belt).length < beltCapacity(s, book, now);
  if (v.empty) {
    s.crafting.vessels.remove(v);
    if (beltFree) {
      s.crafting.vessels.add(Vessel(uid: v.uid, kind: v.kind, place: VesselPlace.belt));
    } else {
      s.add(v.kind, 1);
    }
  } else {
    v.place = beltFree ? VesselPlace.belt : VesselPlace.bag;
  }
  s.changed();
  return true;
}

/// Põe um recipiente vazio [kind] da bolsa no cinto. `false` se o cinto está cheio ou não há o recipiente.
bool toBelt(GameState s, String kind, CraftingBook book, int now) {
  if (s.crafting.at(VesselPlace.belt).length >= beltCapacity(s, book, now) || (s.inventory[kind] ?? 0) <= 0) return false;
  s.spend({kind: 1});
  s.crafting.vessels.add(Vessel(uid: s.crafting.nextUid++, kind: kind, place: VesselPlace.belt));
  s.changed();
  return true;
}

/// Tira [v] do cinto: vazio volta a ser pilha; cheio fica guardado na bolsa (não enche mais).
void fromBelt(GameState s, Vessel v) {
  if (v.place != VesselPlace.belt) return;
  if (v.empty) {
    s.crafting.vessels.remove(v);
    s.add(v.kind, 1);
  } else {
    v.place = VesselPlace.bag;
  }
  s.changed();
}

/// Os recipientes cheios de [contentId] que o jogador carrega (cinto e bolsa), do pior ao melhor.
List<Vessel> carriedWith(GameState s, String contentId) => [
      for (final v in s.crafting.vessels)
        if (v.place != VesselPlace.planted && v.content == contentId) v,
    ]..sort((a, b) => a.quality.index.compareTo(b.quality.index));

/// Esvazia [v] ao usar o conteúdo numa receita: no cinto continua lá, vazio; na bolsa volta a ser pilha.
void useContent(GameState s, Vessel v) {
  if (v.place == VesselPlace.bag) {
    s.crafting.vessels.remove(v);
    s.add(v.kind, 1);
  } else {
    v.clear();
  }
}

/// A qualidade do conteúdo de [v] (comum se vazio).
Quality contentQuality(Vessel v) => v.empty ? Quality.common : v.quality;
