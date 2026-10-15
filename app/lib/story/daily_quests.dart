/// As diárias do fórum (docs/GDD.md, "Quests"): três pedidos por dia, gerados por
/// `hash(seed, época, data, slot)`, então amigos do mesmo grupo e do mesmo dia recebem os mesmos pedidos. Cada
/// pedido tem um evento de jogo que conta, uma meta que cresce com o nível e uma recompensa de XP e materiais.
/// Um slot de cada dia é sempre de "casa" (dá para fazer sem sair), e há um reroll por dia. Dart puro.
library;

import 'dart:math' as math;

import '../core/fnv.dart';
import '../core/pcg32.dart';
import 'forum_data.dart';

/// Sal da geração das diárias.
final int saltQust = salt('QUST');

class Quest {
  Quest({
    required this.slot,
    required this.templateId,
    required this.kind,
    required this.key,
    required this.target,
    required this.user,
    required this.text,
    required this.rewardXp,
    required this.rewardItems,
    this.progress = 0,
    this.claimed = false,
  });

  factory Quest.fromJson(Map<String, dynamic> j) => Quest(
        slot: j['slot'] as int,
        templateId: j['template'] as String,
        kind: j['kind'] as String,
        key: j['key'] as String,
        target: j['target'] as int,
        user: j['user'] as String,
        text: j['text'] as String,
        rewardXp: j['reward_xp'] as int,
        rewardItems: {for (final e in (j['reward_items'] as Map<String, dynamic>).entries) e.key: e.value as int},
        progress: (j['progress'] as int?) ?? 0,
        claimed: (j['claimed'] as bool?) ?? false,
      );

  final int slot;
  final String templateId;
  final String kind;
  final String key;
  final int target;
  final String user;

  /// O post já escrito, com a meta e o tipo no lugar.
  final String text;
  final int rewardXp;
  final Map<String, int> rewardItems;
  int progress;
  bool claimed;

  bool get done => progress >= target;
  bool get claimable => done && !claimed;

  Map<String, dynamic> toJson() => {
        'slot': slot,
        'template': templateId,
        'kind': kind,
        'key': key,
        'target': target,
        'user': user,
        'text': text,
        'reward_xp': rewardXp,
        'reward_items': rewardItems,
        'progress': progress,
        'claimed': claimed,
      };
}

const Map<String, String> _typeNames = {'fire': 'Fogo', 'plant': 'Planta', 'water': 'Água', 'any': 'qualquer tipo'};

/// O nome de um item para o texto do post (sem depender do JSON de itens).
String _itemName(String id) => switch (id) {
      'item.chalk' => 'giz',
      'item.herbs' => 'ervas',
      'item.pure_water' => 'água pura',
      _ => id,
    };

/// Gera o pedido do [slot] do dia [day]. [reroll] é 0 no pedido original e 1 depois de trocar. [taken] são os pares
/// `kind:key` dos outros slots, que não se repetem.
Quest generateQuest({
  required int seed,
  required int epochId,
  required int day,
  required int slot,
  required int level,
  required ForumData forum,
  int reroll = 0,
  Set<String> taken = const {},
}) {
  final rng = Pcg32(fnv1a64([seed, epochId, day, slot, reroll, saltQust]), saltKenoma);
  final categories = forum.slots.firstWhere((s) => s.slot == slot, orElse: () => forum.slots.last).categories;
  final pool = [for (final t in forum.templates) if (categories.contains(t.category)) t];
  late ForumTemplate t;
  late String key;
  for (var attempt = 0; attempt < 12; attempt++) {
    t = pool[rng.nextInt(pool.length)];
    key = t.keys[rng.nextInt(t.keys.length)];
    if (!taken.contains('${t.kind}:$key')) break;
  }
  final span = t.targetMax - t.targetMin;
  var n = t.targetMin + (span == 0 ? 0 : rng.nextInt(span + 1));
  final scaled = n * (1 + forum.levelScale * (math.max(1, level) - 1));
  n = math.max(t.targetMin, ((scaled / t.step).round()) * t.step);
  final text = t.texts[rng.nextInt(t.texts.length)]
      .replaceAll('{n}', '$n')
      .replaceAll('{tipo}', _typeNames[key] ?? key)
      .replaceAll('{item}', _itemName(key));
  return Quest(
    slot: slot,
    templateId: t.id,
    kind: t.kind,
    key: key,
    target: n,
    user: t.user,
    text: text,
    rewardXp: t.rewardXp,
    rewardItems: t.rewardItems,
  );
}

/// O dia de hoje e seus pedidos.
class DailyState {
  DailyState({this.day, List<Quest>? quests, this.rerolls = 0}) : quests = [...?quests];

  factory DailyState.fromJson(Map<String, dynamic>? j) => DailyState(
        day: j?['day'] as int?,
        rerolls: (j?['rerolls'] as int?) ?? 0,
        quests: [for (final q in (j?['quests'] as List<dynamic>?) ?? const []) Quest.fromJson(q as Map<String, dynamic>)],
      );

  /// O dia local dos pedidos (como o descanso: o dia do aparelho). `null` antes do primeiro.
  int? day;
  final List<Quest> quests;
  int rerolls;

  /// Há um reroll por dia.
  static const int maxRerolls = 1;

  bool get canReroll => rerolls < maxRerolls;

  /// Os pedidos de [today]. Se o dia virou, joga fora os de ontem e gera os novos. Devolve `true` se gerou.
  bool ensure({required int today, required int seed, required int epochId, required int level, required ForumData forum}) {
    if (day == today && quests.length == forum.slots.length) return false;
    quests.clear();
    final taken = <String>{};
    for (final s in forum.slots) {
      final q = generateQuest(seed: seed, epochId: epochId, day: today, slot: s.slot, level: level, forum: forum, taken: taken);
      taken.add('${q.kind}:${q.key}');
      quests.add(q);
    }
    day = today;
    rerolls = 0;
    return true;
  }

  Quest? atSlot(int slot) {
    for (final q in quests) {
      if (q.slot == slot) return q;
    }
    return null;
  }

  /// Troca o pedido do [slot] por outro (uma vez por dia, e só se ainda não foi entregue).
  bool reroll(int slot, {required int seed, required int epochId, required int level, required ForumData forum}) {
    final i = quests.indexWhere((q) => q.slot == slot);
    if (i < 0 || !canReroll || quests[i].claimed || day == null) return false;
    final taken = {for (final q in quests) if (q.slot != slot) '${q.kind}:${q.key}'};
    quests[i] = generateQuest(seed: seed, epochId: epochId, day: day!, slot: slot, level: level, forum: forum, reroll: 1, taken: taken);
    rerolls++;
    return true;
  }

  /// Conta [n] do evento [kind] com a variação [key]. Devolve os pedidos que ficaram prontos agora.
  List<Quest> record(String kind, String key, int n) {
    final done = <Quest>[];
    if (n <= 0) return done;
    for (final q in quests) {
      if (q.claimed || q.done || q.kind != kind) continue;
      if (q.key != 'any' && q.key != key) continue;
      q.progress = math.min(q.target, q.progress + n);
      if (q.done) done.add(q);
    }
    return done;
  }

  Map<String, dynamic> toJson() => {'day': day, 'rerolls': rerolls, 'quests': [for (final q in quests) q.toJson()]};
}
