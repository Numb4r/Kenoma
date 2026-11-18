import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/behavior.dart';
import 'package:kenoma/core/veilbreaker_model.dart';
import 'package:kenoma/data/game_data.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/world/npc_talk.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/veilbreakers.dart';

import '../support/fixtures.dart';

/// 0.24.5: a troca do dia (uma por NPC, sempre com perda), o rumor verdadeiro e a relação com os conhecidos no save.
void main() {
  final data = loadGameData();
  final d = data.npc, b = data.npcBalance;
  const day = 20775, player = 0xabcdef;

  /// O valor de um item pelo custo nas receitas: material bruto vale 1.
  final memo = <String, double>{};
  double value(String id, [int depth = 0]) {
    if (memo[id] case final v?) return v;
    final makes = [for (final r in data.recipes.values) if (r.outId == id) r];
    if (makes.isEmpty || depth > 8) return memo[id] = 1;
    double cost(Recipe r) => ([for (final e in r.inputs.entries) value(e.key, depth + 1) * e.value].fold(0.0, (a, x) => a + x) + r.anyOf.values.fold(0, (a, x) => a + x)) / r.outQty;
    return memo[id] = makes.map(cost).reduce((a, x) => a < x ? a : x);
  }

  test('toda troca dos dados é com perda para o jogador, e a perda diminui com a relação', () {
    expect(d.trades, isNotEmpty);
    for (final t in d.trades) {
      final give = value(t.give) * t.giveQty, get = value(t.get) * t.getQty;
      expect(get, lessThan(give), reason: '${t.giveQty} ${t.give} por ${t.getQty} ${t.get}');
      expect(data.craft.item(t.give), isNotNull, reason: t.give);
      expect(data.craft.item(t.get), isNotNull, reason: t.get);
    }
    double worst(int rel) => [for (final t in d.trades) if (t.minRel == rel) value(t.get) * t.getQty / (value(t.give) * t.giveQty)].reduce((a, x) => a < x ? a : x);
    expect(worst(b.relKnown), greaterThan(worst(0)));
    expect(worst(b.relFriend), greaterThan(worst(b.relKnown)));
  });

  GameState state() => GameState(groupCode: 'KENOMA-TESTE', balance: data.progress, inventory: {for (final t in d.trades) t.give: 50});

  test('uma troca por NPC por dia; no dia seguinte, de novo', () {
    final s = state();
    final t = npcOfferFor(npcId: 'npc.1.2.3', rel: 0, playerKey: player, day: day, d: d)!;
    expect(t.minRel, 0);
    expect(npcOfferFor(npcId: 'npc.1.2.3', rel: 0, playerKey: player, day: day, d: d), same(t), reason: 'a mesma o dia todo');
    final before = s.count(t.give);
    expect(doNpcTrade(s, 'npc.1.2.3', t, day, b, known: false), NpcTradeResult.done);
    expect(s.count(t.give), before - t.giveQty);
    expect(s.count(t.get), greaterThanOrEqualTo(t.getQty));
    expect(doNpcTrade(s, 'npc.1.2.3', t, day, b, known: false), NpcTradeResult.already);
    expect(doNpcTrade(s, 'npc.9.9.9', t, day, b, known: false), NpcTradeResult.done, reason: 'outro NPC, outra troca');
    expect(doNpcTrade(s, 'npc.1.2.3', t, day + 1, b, known: false), NpcTradeResult.done);
    final poor = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress);
    expect(doNpcTrade(poor, 'npc.1.2.3', t, day, b, known: false), NpcTradeResult.missing);
    expect(poor.npcs.traded, isEmpty);
  });

  test('a relação com um conhecido sobe com as trocas, libera trocas melhores e fica no save', () {
    final s = state();
    const id = 'known.lorena';
    for (var i = 0; i < b.relFriend; i++) {
      final t = npcOfferFor(npcId: id, rel: s.npcs.relOf(id), playerKey: player, day: day + i, d: d)!;
      expect(doNpcTrade(s, id, t, day + i, b, known: true), NpcTradeResult.done);
    }
    expect(s.npcs.relOf(id), b.relFriend * b.relPerTrade);
    expect(npcOfferFor(npcId: id, rel: s.npcs.relOf(id), playerKey: player, day: day + 99, d: d)!.minRel, b.relFriend);
    final back = GameState.fromJson(jsonDecode(jsonEncode(s.toJson(1795800000))) as Map<String, dynamic>, data.progress);
    expect(back.npcs.relOf(id), s.npcs.relOf(id));
    expect(back.npcs.tradedToday(id, day + b.relFriend - 1), isTrue);
  });

  test('o rumor é verdadeiro: a família, a distância e a direção são as de um Eco que está lá; o ônibus e o evento, os do mundo', () {
    final f = VeilbreakerField(seed: 1, modelAt: (_) => const VeilbreakerModel(baseChance: 1), epochAt: (_) => 12, biomeAt: (_, _) => 'lit', ecosNear: (_, _, _, _) => const [], mpcAt: (_) => 17.6, data: d);
    final v = f.inCell(100, 100, 1000, const VeilbreakerModel(baseChance: 1)).first;
    const at = (x: 804.0, y: 804.0);
    final eco = WorldSpawn(uid: 7, kind: 'eco', entryId: 'soot.eco', quantity: 1, x: 804, y: 794, cellX: 402, cellY: 397, window: 1, level: 2); // 10 células ao norte
    final shiny = WorldSpawn(uid: 8, kind: 'eco', entryId: 'rill.eco', quantity: 1, x: 814, y: 804, cellX: 407, cellY: 402, window: 1, level: 2, shiny: true, behavior: EcoBehavior.passive);
    final facts = RumorFacts(ecos: [eco, shiny], familyName: (e) => e.uid == 7 ? 'Sootling' : 'Rill', busMin: 12, event: (name: 'Lua Carmim', days: 3), metersPerCell: 17.6);
    final kinds = <String>{};
    for (var dd = 0; dd < 400; dd++) {
      for (final rel in [0, b.relFriend]) {
        final r = npcRumor(v: v, at: at, rel: rel, playerKey: player, day: day + dd, b: b, d: d, f: facts);
        if (r == null) continue;
        kinds.add(r.kind);
        switch (r.kind) {
          case 'familia':
            expect(r.eco!.uid, 7, reason: 'o mais perto');
            expect(r.text, isNot(contains('{')));
            if (d.rumors['familia']!.any((x) => x.contains('{familia}'))) expect(r.text.contains('Sootling') || !r.text.contains('Rill'), isTrue);
            expect(compassOf(at.x, at.y, eco.x, eco.y), 'norte');
          case 'brilhante':
            expect(rel, b.relFriend, reason: 'raro: só com relação de amigo');
            expect(r.eco!.shiny, isTrue);
          case 'onibus':
            expect(r.text, isNot(contains('{min}')));
          case 'evento':
            expect(r.text, isNot(contains('{evento}')));
        }
      }
    }
    expect(kinds, containsAll(['familia', 'onibus', 'evento', 'brilhante']));
  });
}
