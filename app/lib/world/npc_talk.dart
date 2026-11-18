/// A conversa com um dos Outros Veilbreakers (0.24.5): nome e título, a saudação pela relação, a troca do dia (uma por NPC
/// por dia, sempre com perda) e, às vezes, um rumor verdadeiro tirado do mundo determinístico. Dart puro.
library;

import 'dart:math' as math;

import '../core/behavior.dart' show EcoBehavior;
import '../core/fnv.dart';
import '../player/game_state.dart';
import 'npc_data.dart';
import 'spawn_field.dart' show WorldSpawn;
import 'veilbreakers.dart';

/// Os números da conversa (`balance.json`, `npc`): por aparelho, não mudam o mundo.
class NpcBalance {
  const NpcBalance({this.rumorChance = 0.35, this.relKnown = 3, this.relFriend = 6, this.relPerTrade = 1, this.relMax = 10, this.nicknameChance = 0.4});

  factory NpcBalance.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const NpcBalance();
    return NpcBalance(
      rumorChance: (j['rumor_chance'] as num?)?.toDouble() ?? 0.35,
      relKnown: (j['rel_known'] as int?) ?? 3,
      relFriend: (j['rel_friend'] as int?) ?? 6,
      relPerTrade: (j['rel_per_trade'] as int?) ?? 1,
      relMax: (j['rel_max'] as int?) ?? 10,
      nicknameChance: (j['nickname_chance'] as num?)?.toDouble() ?? 0.4,
    );
  }

  final double rumorChance;
  final int relKnown, relFriend, relPerTrade, relMax;
  final double nicknameChance;
}

double _unit(int h) => (h >>> 11) / (1 << 53);
int _idHash(String id) => fnv1a64([for (final c in id.codeUnits) c]);

/// O nome na folha: "Jade", "Jade, a Giz" ou, no conhecido, o nome e o apelido dele.
String npcName(Veilbreaker v, NpcData d) {
  final k = v.known;
  if (k != null) return k.nickname.isEmpty ? k.name : '${k.name}, ${k.nickname}';
  final n = d.names[v.nameIndex % d.names.length];
  if (v.nicknameIndex < 0 || d.nicknames.isEmpty) return n.name;
  final nick = d.nicknames[v.nicknameIndex % d.nicknames.length];
  return '${n.name}, ${nick[n.g] ?? nick['n'] ?? nick.values.first}';
}

/// O título de escola visto na folha (uma das variações, fixa para o NPC).
String npcSchoolTitle(Veilbreaker v, NpcData d) => NpcData.pickOf(d.schools, v.school, _idHash(v.id) >>> 33);

/// 0 desconhecido, 1 conhecido, 2 amigo.
int relTier(int rel, NpcBalance b) => rel >= b.relFriend ? 2 : (rel >= b.relKnown ? 1 : 0);

/// A fala de chegada: a do conhecido (as dele), ou a do grupo da relação.
String npcGreeting(Veilbreaker v, NpcData d, int rel, NpcBalance b, int day) {
  final pick = fnv1a64([_idHash(v.id), day]) >>> 33;
  final tier = relTier(rel, b);
  final k = v.known;
  if (k != null && k.greet.isNotEmpty && tier < 2) return k.greet[pick % k.greet.length];
  return NpcData.pickOf(d.lines, switch (tier) { 2 => 'saudacao_amigo', 1 => 'saudacao_conhecido', _ => 'saudacao' }, pick);
}

/// A troca do dia que [npcId] oferece ao jogador [playerKey]: entre as que a relação libera, as da faixa mais alta (quanto
/// maior a relação, menor a perda). Igual o dia todo.
NpcTrade? npcOfferFor({required String npcId, required int rel, required int playerKey, required int day, required NpcData d}) {
  final ok = [for (final t in d.trades) if (t.minRel <= rel) t];
  if (ok.isEmpty) return null;
  final top = ok.map((t) => t.minRel).reduce(math.max);
  final best = [for (final t in ok) if (t.minRel == top) t];
  return best[(fnv1a64([playerKey, _idHash(npcId), day, 0x7472]) >>> 33) % best.length];
}

enum NpcTradeResult { done, already, missing, bagFull }

/// Faz a troca [t] com [npcId] hoje ([day]): uma por NPC por dia. Com um conhecido ([known]), a relação sobe. Se a bolsa
/// não comporta o que vem, nada muda.
NpcTradeResult doNpcTrade(GameState s, String npcId, NpcTrade t, int day, NpcBalance b, {required bool known}) {
  if (s.npcs.tradedToday(npcId, day)) return NpcTradeResult.already;
  if (s.count(t.give) < t.giveQty) return NpcTradeResult.missing;
  if (!s.spend({t.give: t.giveQty})) return NpcTradeResult.missing;
  final got = s.add(t.get, t.getQty);
  if (got < t.getQty) {
    if (got > 0) s.spend({t.get: got});
    s.add(t.give, t.giveQty);
    return NpcTradeResult.bagFull;
  }
  s.npcs.markTraded(npcId, day);
  if (known) s.npcs.rel[npcId] = math.min(b.relMax, s.npcs.relOf(npcId) + b.relPerTrade);
  s.changed();
  return NpcTradeResult.done;
}

/// O que o mundo determinístico diz perto do NPC, para o rumor: Ecos da camada base (com o nome da família), o próximo
/// Ônibus Espectral no ponto mais perto e o próximo evento do calendário.
class RumorFacts {
  const RumorFacts({this.ecos = const [], required this.familyName, this.busMin, this.event, required this.metersPerCell});

  final List<WorldSpawn> ecos;
  final String Function(WorldSpawn) familyName;
  final int? busMin;
  final ({String name, int days})? event;
  final double metersPerCell;
}

typedef NpcRumor = ({String kind, String text, WorldSpawn? eco});

const _dirs = ['leste', 'sudeste', 'sul', 'sudoeste', 'oeste', 'noroeste', 'norte', 'nordeste'];

/// A direção de ([fx], [fy]) para ([tx], [ty]) em células (x para leste, y para o sul), em oito rumos.
String compassOf(double fx, double fy, double tx, double ty) {
  final a = math.atan2(ty - fy, tx - fx);
  return _dirs[((a / (math.pi / 4)).round() % 8 + 8) % 8];
}

/// O rumor de hoje de [v] para o jogador, ou `null` (nem sempre há). Sempre verdadeiro: sai de [f]. Família perto,
/// ônibus e evento valem para todos; Brilhante e Oculto, os raros, só com relação de amigo.
NpcRumor? npcRumor({required Veilbreaker v, required ({double x, double y}) at, required int rel, required int playerKey, required int day, required NpcBalance b, required NpcData d, required RumorFacts f}) {
  final h = fnv1a64([playerKey, _idHash(v.id), day, 0x726d]);
  if (_unit(h) >= b.rumorChance) return null;
  WorldSpawn? nearest(bool Function(WorldSpawn) ok) {
    WorldSpawn? best;
    var bd = double.infinity;
    for (final e in f.ecos) {
      if (!e.isEco || !ok(e)) continue;
      final dd = math.pow(e.x - at.x, 2) + math.pow(e.y - at.y, 2);
      if (dd < bd || (dd == bd && e.uid < best!.uid)) (best, bd) = (e, dd.toDouble());
    }
    return best;
  }

  final options = <(String, WorldSpawn?)>[
    if (nearest((_) => true) case final e?) ('familia', e),
    if (f.busMin != null) ('onibus', null),
    if (f.event != null) ('evento', null),
    if (rel >= b.relFriend) ...[
      if (nearest((e) => e.shiny) case final e?) ...[('brilhante', e), ('brilhante', e)],
      if (nearest((e) => e.behavior == EcoBehavior.hidden) case final e?) ...[('oculto', e), ('oculto', e)],
    ],
  ];
  if (options.isEmpty) return null;
  final (kind, eco) = options[(h >>> 20) % options.length];
  String? where(WorldSpawn e) => compassOf(at.x, at.y, e.x, e.y);
  int metros(WorldSpawn e) => (math.sqrt(math.pow(e.x - at.x, 2) + math.pow(e.y - at.y, 2)) * f.metersPerCell / 10).round() * 10;
  final group = kind == 'evento' && f.event!.days == 0 && (d.rumors['evento_hoje']?.isNotEmpty ?? false) ? 'evento_hoje' : kind;
  final text = fillGaps(NpcData.pickOf(d.rumors, group, h >>> 40), {
    if (eco != null) ...{'familia': f.familyName(eco), 'metros': metros(eco), 'direcao': where(eco)!},
    if (kind == 'onibus') 'min': f.busMin!,
    if (kind == 'evento') ...{'evento': f.event!.name, 'dias': f.event!.days},
  });
  return (kind: kind, text: text, eco: eco);
}
