/// A folha de um dos Outros Veilbreakers (0.24.5): nome, escola, uma fala curta, a troca do dia (uma por NPC por dia,
/// sempre com perda) e, às vezes, um rumor verdadeiro. Só a pé e a até 30 m, como o resto do mapa que responde ao toque.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/species_ids.dart' show familyOfId;
import '../../core/tiles.dart';
import '../../crafting/collectors.dart' show metersBetween;
import '../../player/progression.dart' show localDay;
import '../../world/climate_outlook.dart' show nextCalendarItems;
import '../../world/map_touch.dart' show canTouch, placeKey, spectralBusNext;
import '../../world/npc_data.dart';
import '../../world/npc_talk.dart';
import '../../world/personal_layer.dart' show playerKeyOf;
import '../../world/spawn_field.dart' show WorldSpawn;
import '../../world/veilbreakers.dart';
import '../colors.dart';
import '../craft/ui_art.dart';
import '../tuning/tuning_screen.dart' show PixelButton;
import 'map_touch_flow.dart' show MapTouchDeps;

/// Os fatos do mundo em volta de [v] para o rumor: Ecos da camada base a até 300 m, o Espectral no ponto mais perto (até
/// 400 m) e o próximo evento do calendário (até 14 dias).
RumorFacts rumorFactsFor(MapTouchDeps d, Veilbreaker v, ({double x, double y}) at, int now) {
  final (lat, lon) = tileFractionToLatLon(at.x, at.y, biomeZoom);
  final mpc = d.world.metersPerCell21;
  final ecos = d.world.field.around(lat: lat, lon: lon, tUtc: now, radiusM: 300, playerLevel: 99).where((e) => e.isEco && !(d.world.veil?.goneAt(e, now, playerDistM: double.infinity) ?? false)).toList();
  int? busMin;
  var best = 400 / mpc;
  final view = d.game.size;
  for (final tile in d.game.visibleTiles(Size(view.x, view.y), d.game.follow.camera)) {
    for (final p in tile.props) {
      if (p.kind != 'bus_stop') continue;
      final dist = math.sqrt(math.pow(p.x - at.x, 2) + math.pow(p.y - at.y, 2));
      if (dist >= best) continue;
      best = dist;
      final next = spectralBusNext(seed: d.state.seed, stopKey: placeKey(p.x, p.y), t: now, b: d.data.mapTouch, localHourOf: (u) => DateTime.fromMillisecondsSinceEpoch(u * 1000).hour);
      busMin = ((next.utc - now) / 60).ceil();
    }
  }
  final cal = d.climate == null ? const <({String event, String what, bool isEvent, int startUtc})>[] : nextCalendarItems(world: d.climate!, catalog: d.data.climates, nowUtc: now, count: 1, days: 14);
  String family(WorldSpawn e) => d.data.families.where((f) => f.id == familyOfId(e.entryId)).firstOrNull?.name ?? familyOfId(e.entryId);
  return RumorFacts(
    ecos: ecos,
    familyName: family,
    busMin: busMin,
    event: cal.isEmpty ? null : (name: cal.first.event, days: ((cal.first.startUtc - now) / 86400).floor().clamp(0, 99)),
    metersPerCell: mpc,
  );
}

/// [anyDistance]: só o debug (comando `npc`) abre a folha sem a checagem de 30 m e a pé.
Future<void> handleNpcTouch(BuildContext context, Veilbreaker v, MapTouchDeps d, {bool anyDistance = false}) async {
  final now = d.nowUtc(), s = d.state, b = d.data.npcBalance, npc = d.data.npc;
  final p = v.at(now.toDouble());
  final (lat, lon) = tileFractionToLatLon(p.x, p.y, biomeZoom);
  final dist = metersBetween(d.game.playerLat, d.game.playerLon, lat, lon);
  if (!anyDistance && !canTouch(dist, d.speedMps, d.data.patrol.walkMaxMps, d.data.mapTouch)) {
    d.toast(dist > d.data.mapTouch.touchM ? 'A ${dist.round()} m: chegue perto' : 'Só a pé');
    return;
  }
  final day = localDay(now), player = playerKeyOf(s.founder?.playerId ?? s.groupCode);
  final known = v.known != null, rel = known ? s.npcs.relOf(v.id) : 0;
  final offer = npcOfferFor(npcId: v.id, rel: rel, playerKey: player, day: day, d: npc);
  final rumor = npcRumor(v: v, at: (x: p.x, y: p.y), rel: rel, playerKey: player, day: day, b: b, d: npc, f: rumorFactsFor(d, v, (x: p.x, y: p.y), now));
  String qty(String id, int n) => d.data.itemCount(id, n);
  final pick = day + v.id.length;
  // Logo depois de sintonizar, ele comenta o Eco que acabou de levar.
  final last = [for (final t in v.tunes) if (now >= t.atUtc && now - t.atUtc < 60) t].lastOrNull;
  final greet = last != null
      ? fillGaps(NpcData.pickOf(npc.lines, 'sintonizando', pick), {'familia': d.data.families.where((f) => f.id == familyOfId(last.eco.entryId)).firstOrNull?.name ?? ''})
      : npcGreeting(v, npc, rel, b, day);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => StatefulBuilder(builder: (context, setLocal) {
      final traded = s.npcs.tradedToday(v.id, day);
      final has = offer != null && s.count(offer.give) >= offer.giveQty;
      String? result;
      return UiFrame(
        name: 'sheet',
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(key: const Key('npc-sheet'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(npcName(v, npc).toUpperCase(), style: const TextStyle(fontSize: 16, color: kVeil)),
          Text(npcSchoolTitle(v, npc).toUpperCase(), style: const TextStyle(fontSize: 8, color: kDim, height: 1.8)),
          if (known) Text('CONHECIDO · RELAÇÃO $rel', key: const Key('npc-rel'), style: const TextStyle(fontSize: 8, color: kSignal, height: 1.8)),
          const SizedBox(height: 10),
          Text(greet, style: const TextStyle(fontSize: 12, color: kText, height: 1.5)),
          const SizedBox(height: 10),
          if (offer != null) ...[
            Text(
              traded
                  ? NpcData.pickOf(npc.lines, 'ja_trocou_hoje', pick)
                  : (has ? fillGaps(NpcData.pickOf(npc.lines, 'oferta', pick), {'da': qty(offer.give, offer.giveQty), 'recebe': qty(offer.get, offer.getQty)}) : fillGaps(NpcData.pickOf(npc.lines, 'sem_material', pick), {'da': qty(offer.give, offer.giveQty), 'recebe': qty(offer.get, offer.getQty)})),
              key: const Key('npc-offer'),
              style: const TextStyle(fontSize: 12, color: kText, height: 1.5),
            ),
            Text('VOCÊ DÁ ${qty(offer.give, offer.giveQty).toUpperCase()} · RECEBE ${qty(offer.get, offer.getQty).toUpperCase()}', style: const TextStyle(fontSize: 8, color: kDim, height: 1.8)),
            if (!traded) ...[
              const SizedBox(height: 8),
              PixelButton(
                key: const Key('npc-trade'),
                label: 'Trocar',
                color: has ? kSignal : kDim,
                onTap: () {
                  final r = doNpcTrade(s, v.id, offer, day, b, known: known);
                  result = switch (r) {
                    NpcTradeResult.done => NpcData.pickOf(npc.lines, 'troca_feita', pick),
                    NpcTradeResult.already => NpcData.pickOf(npc.lines, 'ja_trocou_hoje', pick),
                    NpcTradeResult.missing => fillGaps(NpcData.pickOf(npc.lines, 'sem_material', pick), {'da': qty(offer.give, offer.giveQty), 'recebe': qty(offer.get, offer.getQty)}),
                    NpcTradeResult.bagFull => 'Sua bolsa não comporta o que vem.',
                  };
                  d.toast(result!);
                  setLocal(() {});
                },
              ),
            ],
          ],
          if (rumor != null) ...[
            const SizedBox(height: 12),
            const Text('RUMOR', style: TextStyle(fontSize: 8, color: kVeil, height: 1.8)),
            Text(rumor.text, key: const Key('npc-rumor'), style: const TextStyle(fontSize: 12, color: kText, height: 1.5)),
          ],
        ]),
      );
    }),
  );
}
