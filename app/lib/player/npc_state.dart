/// O que os Outros Veilbreakers lembram do jogador (0.24.5, save schema 13): quem já trocou hoje (uma troca por NPC por
/// dia) e a relação com cada conhecido, que sobe com as trocas. É do jogador, não do mundo. Dart puro.
library;

class NpcState {
  NpcState({this.day = 0, Set<String>? traded, Map<String, int>? rel})
      : traded = traded ?? {},
        rel = rel ?? {};

  factory NpcState.fromJson(Map<String, dynamic>? j) => j == null
      ? NpcState()
      : NpcState(
          day: (j['day'] as int?) ?? 0,
          traded: {for (final s in (j['traded'] as List<dynamic>?) ?? const []) s as String},
          rel: {for (final e in ((j['rel'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int},
        );

  /// O dia local das trocas de [traded]; num dia novo a lista recomeça.
  int day;
  final Set<String> traded;

  /// A relação com cada conhecido (`known.lorena`), de 0 até `rel_max`.
  final Map<String, int> rel;

  bool tradedToday(String npcId, int today) => day == today && traded.contains(npcId);

  void markTraded(String npcId, int today) {
    if (day != today) {
      day = today;
      traded.clear();
    }
    traded.add(npcId);
  }

  int relOf(String npcId) => rel[npcId] ?? 0;

  Map<String, dynamic> toJson() => {'day': day, 'traded': traded.toList()..sort(), 'rel': rel};
}
