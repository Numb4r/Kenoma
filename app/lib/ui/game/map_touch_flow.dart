/// O que cada toque no mapa faz (0.24.2), no alcance de toque e a pé: o ponto de ônibus mostra o próximo Ônibus Espectral,
/// a banca a manchete do Véu do dia, a placa o nome da rua; o bando levanta voo (às vezes cai uma pena), a árvore sacode
/// (folha seca no outono, flor do ipê florido), a poça faz onda (um Eco de Água perto se vira para o Conjurador), o poste
/// pisca à noite (um Hum perto fica à vista alguns segundos a mais) e o gato ganha carinho (segue um quarteirão e às vezes
/// larga uma coisa). As recompensas são da camada pessoal, com limite por dia (`map_touch` no `balance.json`).
library;

import 'package:flutter/material.dart';

import '../../core/astro.dart';
import '../../core/species_ids.dart';
import '../../core/tiles.dart';
import '../../crafting/collectors.dart' show metersBetween;
import '../../crafting/conditions.dart' show seasonAt;
import '../../crafting/crafting_data.dart' show YearSeason;
import '../../data/game_data.dart';
import '../../patrol/street_name.dart';
import '../../player/game_state.dart';
import '../../player/progression.dart' show localDay;
import '../../world/climate_outlook.dart';
import '../../world/climate_world.dart';
import '../../world/map_touch.dart';
import '../../world/npc_data.dart';
import '../../world/spectral_bus.dart';
import '../../world/personal_layer.dart' show playerKeyOf;
import '../../world/visual_map.dart';
import '../../world/spawn_field.dart' show WorldSpawn;
import '../../world/world_view.dart';
import '../colors.dart';
import '../craft/ui_art.dart';
import '../sprites/map_style.dart' show ipeStamp;
import 'game_map_game.dart';
import 'touch_fx.dart';

class MapTouchDeps {
  const MapTouchDeps({
    required this.state,
    required this.data,
    required this.world,
    required this.game,
    required this.nowUtc,
    required this.speedMps,
    required this.toast,
    this.climate,
    this.visual,
  });

  final GameState state;
  final GameData data;
  final WorldView world;
  final GameMapGame game;
  final int Function() nowUtc;
  final double speedMps;
  final void Function(String) toast;
  final ClimateWorld? climate;
  final VisualMap? visual;
}

Future<void> handleMapTouch(BuildContext context, TouchHit h, MapTouchDeps d) async {
  final b = d.data.mapTouch, now = d.nowUtc(), s = d.state;
  final (lat, lon) = tileFractionToLatLon(h.x, h.y, biomeZoom);
  final dist = metersBetween(d.game.playerLat, d.game.playerLon, lat, lon);
  if (!canTouch(dist, d.speedMps, d.data.patrol.walkMaxMps, b)) {
    d.toast(dist > b.touchM ? 'A ${dist.round()} m: chegue perto' : 'Só a pé');
    return;
  }
  final day = localDay(now);
  final player = playerKeyOf(s.founder?.playerId ?? s.groupCode);
  final t = d.game.gameTime;
  final px = d.game.playerSizePx / 16;
  String n(String id) => d.data.notice(id);

  /// Uma recompensa pequena: limite do dia, sorteio pessoal e a bolsa (que pode recusar).
  bool give(TouchKind k, String item, double chance, {String? objectKey}) {
    if (!s.touches.canReward(k, day, b, objectKey: objectKey)) return false;
    if (personalRoll(player, day, h.key, s.touches.count(k, day)) >= chance) return false;
    if (s.add(item, 1) == 0) return false;
    s.touches.reward(k, day, objectKey: objectKey);
    s.changed();
    return true;
  }

  switch (h.kind) {
    case TouchKind.busStop:
      final next = spectralBusNext(seed: s.seed, stopKey: placeKey(h.x, h.y), t: now, b: b, localHourOf: (u) => DateTime.fromMillisecondsSinceEpoch(u * 1000).hour);
      final min = ((next.utc - now) / 60).ceil();
      final bus = (d.data.mapTexts['bus'] as Map<String, dynamic>?) ?? const {};
      var line = (min <= 0 ? bus['now'] : (next.night ? bus['night'] : bus['day'])) as String? ?? '';
      // 0.24.5: o Espectral parado ali agora.
      final pass = spectralBusAt(seed: s.seed, stopKey: placeKey(h.x, h.y), t: now.toDouble(), b: b);
      if (pass != null && pass.phase == SpectralPhase.stopped && d.data.npc.busNow.isNotEmpty) {
        line = fillGaps(NpcData.pickOf({'n': d.data.npc.busNow}, 'n', pass.arriveUtc), {'seg': (pass.arriveUtc + b.busDwellS - now).ceil().clamp(1, 99)});
      }
      await _panel(context, (bus['title'] as String?) ?? 'Ponto de ônibus', [line.replaceAll('{min}', '$min'), (bus['no_lines'] as String?) ?? '']);
    case TouchKind.newsstand:
      final here = d.world.here(lat, lon, now, waterSearchM: 0);
      final climate = d.data.climates.of(here.climates.first).name;
      final cal = d.climate == null ? const <({String event, String what, bool isEvent, int startUtc})>[] : nextCalendarItems(world: d.climate!, catalog: d.data.climates, nowUtc: now, count: 1, days: 14);
      final ev = cal.isEmpty ? null : (name: cal.first.event, days: ((cal.first.startUtc - now) / 86400).ceil().clamp(0, 99));
      // A família que anda aparecendo ali: a de mais Ecos a até 150 m da banca agora (o mundo é igual para o grupo).
      final counts = <String, int>{};
      for (final e in d.world.allEcos) {
        final (elat, elon) = tileFractionToLatLon(e.x, e.y, biomeZoom);
        if (metersBetween(lat, lon, elat, elon) <= 150) counts.update(familyOfId(e.entryId), (v) => v + 1, ifAbsent: () => 1);
      }
      final top = counts.entries.isEmpty ? null : (counts.entries.toList()..sort((a, c) => c.value != a.value ? c.value - a.value : a.key.compareTo(c.key))).first.key;
      final family = top == null ? null : d.data.families.where((f) => f.id == top).firstOrNull?.name;
      final news = (d.data.mapTexts['news'] as Map<String, dynamic>?) ?? const {};
      final hl = veilHeadline(seed: s.seed, epochId: d.data.schedule.select(now).epoch.id, day: day, standKey: placeKey(h.x, h.y), climate: climate, templates: news, event: ev, family: family);
      await _panel(context, (news['title'] as String?) ?? 'Manchetes do Véu', [if (hl != null) hl.title.toUpperCase(), if (hl != null) hl.body, (news['footer'] as String?) ?? '']);
    case TouchKind.sign:
      final name = d.visual == null ? null : nearestStreetName(d.visual!, h.x, h.y, 30 / metersPerCell(lat));
      final sign = (d.data.mapTexts['sign'] as Map<String, dynamic>?) ?? const {};
      await _panel(context, (sign['label'] as String?) ?? 'Você está em', [name ?? 'Rua sem nome no mapa', (sign['hint'] as String?) ?? '']);
    case TouchKind.flock:
      final f = h.flock;
      if (f != null) d.game.flocks.takeOff(f, d.game.playerX, d.game.playerY, metersPerCell(lat));
      if (give(TouchKind.flock, 'item.feather', b.featherChance)) {
        d.game.touchFx.add(TouchFx('fx_feather', h.x, h.y, t, fall: 18, life: 1.6));
        d.toast(n('map.feather_drop'));
      } else if (!s.touches.canReward(TouchKind.flock, day, b)) {
        d.toast(n('map.limit_feather'));
      }
    case TouchKind.tree:
      d.game.swayTree(h.x, h.y); // a copa balança em todo toque, com folha ou sem
      final month = DateTime.fromMillisecondsSinceEpoch(now * 1000).month;
      final ipe = h.prop.startsWith('ipe_') && ipeStamp(h.prop.substring(4), month) != 'ipe_green';
      final autumn = seasonAt(now) == YearSeason.autumn;
      final item = ipe ? 'item.ipe_flower' : (autumn ? 'item.dry_leaf' : null);
      if (item == null) {
        d.toast(n('map.tree_empty'));
      } else if (!s.touches.canReward(TouchKind.tree, day, b, objectKey: h.key)) {
        d.toast(s.touches.canReward(TouchKind.tree, day, b) ? n('map.tree_empty') : n('map.limit_tree'));
      } else if (give(TouchKind.tree, item, b.treeChance, objectKey: h.key)) {
        d.game.touchFx.add(TouchFx(ipe ? (h.prop == 'ipe_purple' ? 'fx_ipe_petal_pink' : 'fx_ipe_petal') : 'fx_leaf', h.x, h.y, t, fall: 22, life: 1.6, lift: 6 * px));
        d.toast(n(ipe ? 'map.ipe_drop' : 'map.leaf_drop'));
      } else {
        d.toast(n('map.tree_empty'));
      }
    case TouchKind.puddle:
      if (!s.touches.canReward(TouchKind.puddle, day, b)) return d.toast(n('map.limit_puddle'));
      s.touches.reward(TouchKind.puddle, day);
      s.changed();
      d.game.touchFx.add(TouchFx('fx_ripple', h.x, h.y, t, frames: 4, fps: 5, life: 0.8));
      final water = _ecosNear(d, lat, lon, b.puddleEcoM, (e) => d.data.species(e.entryId)?.type.name == 'water');
      if (water.isEmpty) return d.toast(n('map.puddle_empty'));
      for (final e in water) {
        d.game.ecoFacing[e.uid] = (t + b.puddleTurnS, e.x > d.game.playerX);
        d.game.fx.hop(e.uid);
      }
    case TouchKind.lamp:
      if (sunAltitudeDeg(lat, lon, now) > 0) return d.toast('De dia o poste não acende');
      if (!s.touches.canReward(TouchKind.lamp, day, b)) return d.toast(n('map.limit_lamp'));
      s.touches.reward(TouchKind.lamp, day);
      s.changed();
      d.game.touchFx.add(TouchFx('fx_lamp_flicker', h.x, h.y, t, frames: 2, fps: 8, life: 1.2, lift: 3 * px));
      final hums = _ecosNear(d, lat, lon, b.humM, (e) => familyOfId(e.entryId) == 'hum');
      if (hums.isEmpty) return d.toast(n('map.lamp_empty'));
      for (final e in hums) {
        d.world.revealUntil[e.uid] = now + b.humExtraS.round();
        d.game.fx.hop(e.uid);
      }
    case TouchKind.cat:
      d.game.touchFx.add(TouchFx('fx_cat_heart', h.x, h.y, t, fps: 3, life: 1.5));
      if (h.cat != null) d.game.flocks.followCat(h.cat!, b.catFollowM);
      final gift = b.catGifts[(personalRoll(player, day, h.key, 99) * b.catGifts.length).floor() % b.catGifts.length];
      if (give(TouchKind.cat, gift, b.catGiftChance)) {
        d.toast('${n('map.cat_gift')} +1 ${d.data.itemName(gift)}');
      } else {
        d.toast(s.touches.canReward(TouchKind.cat, day, b) ? n('map.cat_follow') : n('map.limit_cat'));
      }
  }
}

List<WorldSpawn> _ecosNear(MapTouchDeps d, double lat, double lon, double m, bool Function(WorldSpawn) test) => [
      for (final e in d.world.allEcos)
        if (test(e) && () {
          final (elat, elon) = tileFractionToLatLon(e.x, e.y, biomeZoom);
          return metersBetween(lat, lon, elat, elon) <= m;
        }())
          e,
    ];

Future<void> _panel(BuildContext context, String title, List<String> lines) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => UiFrame(
        name: 'sheet',
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(key: const Key('map-touch-panel'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 16, color: kVeil)),
          const SizedBox(height: 10),
          for (final l in lines)
            if (l.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l, style: const TextStyle(fontSize: 12, color: kText, height: 1.5))),
        ]),
      ),
    );
