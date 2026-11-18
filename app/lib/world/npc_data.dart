/// Os textos e as trocas dos Outros Veilbreakers (`assets/data/npc.json`, 0.24.5): nomes, apelidos, títulos de escola,
/// falas, rumores com lacunas, os conhecidos de cada bairro e a tabela de trocas. Conteúdo é dado: nada disto vive no
/// código. Dart puro.
library;

import '../core/plural.dart';

/// Um conhecido: fixo por bairro, com rotina por dia da semana e hora local.
class KnownNpc {
  const KnownNpc({required this.id, required this.name, required this.nickname, required this.gender, required this.school, required this.outfit, required this.about, required this.days, required this.fromH, required this.toH, required this.place, required this.greet});

  factory KnownNpc.fromJson(Map<String, dynamic> j) => KnownNpc(
        id: j['id'] as String,
        name: j['name'] as String,
        nickname: (j['nickname'] as String?) ?? '',
        gender: (j['g'] as String?) ?? 'n',
        school: (j['school'] as String?) ?? 'none',
        outfit: (j['outfit'] as int?) ?? 0,
        about: (j['about'] as String?) ?? '',
        days: {for (final d in (j['days'] as List<dynamic>?) ?? const []) d as int},
        fromH: (j['from_h'] as int?) ?? 0,
        toH: (j['to_h'] as int?) ?? 24,
        place: (j['place'] as String?) ?? 'urbano',
        greet: [for (final g in (j['greet'] as List<dynamic>?) ?? const []) g as String],
      );

  final String id, name, nickname, gender, school, about, place;
  final int outfit, fromH, toH;

  /// 1 = segunda ... 7 = domingo.
  final Set<int> days;
  final List<String> greet;

  /// Está na rua no dia da semana [weekday] (1 a 7) e na hora local [hour].
  bool activeAt(int weekday, int hour) => days.contains(weekday) && hour >= fromH && hour < toH;

  /// O bioma de spawn em que ele fica: praça (verde), Iluminado ou urbano.
  String get biome => switch (place) { 'praca' => 'green', 'iluminado' => 'lit', _ => 'urban' };
}

/// Uma troca: o jogador entrega [give] e recebe [get]. [minRel]: a relação que o NPC precisa ter com o jogador.
class NpcTrade {
  const NpcTrade({required this.give, required this.giveQty, required this.get, required this.getQty, required this.minRel});

  factory NpcTrade.fromJson(Map<String, dynamic> j) {
    final g = j['give'] as List<dynamic>, r = j['get'] as List<dynamic>;
    return NpcTrade(give: g[0] as String, giveQty: g[1] as int, get: r[0] as String, getQty: r[1] as int, minRel: (j['min_rel'] as int?) ?? 0);
  }

  final String give, get;
  final int giveQty, getQty, minRel;
}

class NpcData {
  const NpcData({this.names = const [], this.nicknames = const [], this.schools = const {}, this.lines = const {}, this.rumors = const {}, this.busNow = const [], this.known = const [], this.trades = const []});

  factory NpcData.fromJson(Map<String, dynamic> j) {
    List<String> strs(Object? o) => [for (final s in (o as List<dynamic>?) ?? const []) s as String];
    Map<String, List<String>> groups(Object? o) => {for (final e in ((o as Map<String, dynamic>?) ?? const {}).entries) e.key: strs(e.value)};
    return NpcData(
      names: [for (final n in (j['names'] as List<dynamic>?) ?? const []) (name: (n as Map<String, dynamic>)['name'] as String, g: (n['g'] as String?) ?? 'n')],
      nicknames: [for (final n in (j['nicknames'] as List<dynamic>?) ?? const []) {for (final e in (n as Map<String, dynamic>).entries) e.key: e.value as String}],
      schools: groups(j['schools']),
      lines: groups(j['lines']),
      rumors: groups(j['rumors']),
      busNow: strs(j['bus_now']),
      known: [for (final k in (j['known'] as List<dynamic>?) ?? const []) KnownNpc.fromJson(k as Map<String, dynamic>)],
      trades: [for (final t in (j['trades'] as List<dynamic>?) ?? const []) NpcTrade.fromJson(t as Map<String, dynamic>)],
    );
  }

  final List<({String name, String g})> names;

  /// Cada apelido nas três formas: `m` e `f` com o artigo, `n` sem.
  final List<Map<String, String>> nicknames;

  /// Títulos de escola na folha: `technomancer`, `shaman`, `sealer`, `none`.
  final Map<String, List<String>> schools;
  final Map<String, List<String>> lines;
  final Map<String, List<String>> rumors;
  final List<String> busNow;
  final List<KnownNpc> known;
  final List<NpcTrade> trades;

  /// Uma variação do grupo [group] de [from] escolhida por [pick] (qualquer inteiro), ou `''` sem texto.
  static String pickOf(Map<String, List<String>> from, String group, int pick) {
    final l = from[group];
    return l == null || l.isEmpty ? '' : l[pick % l.length];
  }
}

/// As quatro escolas que um NPC pode ter, na ordem do sorteio.
const List<String> kNpcSchools = ['technomancer', 'shaman', 'sealer', 'none'];

/// Preenche as lacunas `{chave}` de [text] com [values].
/// Preenche as lacunas de [text] com [values] (ver `fillText`: `{dias:dia}` concorda com o número).
String fillGaps(String text, Map<String, Object> values) => fillText(text, values);
