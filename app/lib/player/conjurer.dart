/// O que o Conjurador é além do nível: a escola, os testes do nível 3, os pontos de talento, a pesquisa de rituais e as
/// contagens do Perfil. Dart puro; vai para o bloco `conjurer` do save (schema 5).
library;

import 'conjurer_balance.dart';

class ConjurerState {
  ConjurerState({
    this.school,
    this.testsOffered = false,
    Map<String, int>? testScores,
    this.talentEarned = 0,
    this.talentSpent = 0,
    Map<String, int>? ritualResearch,
    List<int>? daysPlayed,
    this.fusions = 0,
    this.playerName = '',
  })  : testScores = {...?testScores},
        ritualResearch = {...?ritualResearch},
        daysPlayed = [...?daysPlayed];

  factory ConjurerState.fromJson(Map<String, dynamic>? j) => ConjurerState(
        school: School.parse(j?['school'] as String?),
        testsOffered: (j?['tests_offered'] as bool?) ?? false,
        testScores: {for (final e in ((j?['test_scores'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int},
        talentEarned: (j?['talent_earned'] as int?) ?? 0,
        talentSpent: (j?['talent_spent'] as int?) ?? 0,
        ritualResearch: {for (final e in ((j?['ritual_research'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int},
        daysPlayed: [for (final d in (j?['days_played'] as List<dynamic>?) ?? const []) d as int],
        fusions: (j?['fusions'] as int?) ?? 0,
        playerName: (j?['player_name'] as String?) ?? '',
      );

  /// A escola escolhida (definitiva até o nível 30), ou `null`.
  School? school;

  /// O mentor já mandou os três testes do nível 3.
  bool testsOffered;

  /// Nota (0 a 100) do jogador em cada teste, por id de escola. Só entram os testes já feitos.
  final Map<String, int> testScores;

  /// Pontos de talento ganhos (um por nível) e gastos (as árvores vêm numa fatia futura: por ora nada gasta).
  int talentEarned;
  int talentSpent;
  int get talentAvailable => talentEarned - talentSpent;

  /// Quanto de cada espécie de ritual o Bestiário já pesquisou: quantos espaços da receita estão revelados.
  final Map<String, int> ritualResearch;

  /// Dias locais (contados desde a época Unix) em que o jogo foi aberto, para "dias jogados".
  final List<int> daysPlayed;

  /// Quantos Espíritos o jogador já fundiu.
  int fusions;

  /// O nome do Conjurador, editável no Perfil. Vazio: "Conjurador".
  String playerName;

  String get displayName => playerName.trim().isEmpty ? 'Conjurador' : playerName.trim();

  /// A escola em que o jogador foi melhor, ou `null` se ainda não fez nenhum teste.
  School? get bestTest {
    School? best;
    var score = -1;
    for (final s in School.values) {
      final v = testScores[s.id];
      if (v != null && v > score) {
        best = s;
        score = v;
      }
    }
    return best;
  }

  /// Registra o dia local; guarda só os últimos 3.650 dias.
  bool markDay(int day) {
    if (daysPlayed.isNotEmpty && daysPlayed.last >= day) return false;
    daysPlayed.add(day);
    if (daysPlayed.length > 3650) daysPlayed.removeAt(0);
    return true;
  }

  Map<String, dynamic> toJson() => {
        if (school != null) 'school': school!.id,
        'tests_offered': testsOffered,
        'test_scores': testScores,
        'talent_earned': talentEarned,
        'talent_spent': talentSpent,
        'ritual_research': ritualResearch,
        'days_played': daysPlayed,
        'fusions': fusions,
        if (playerName.isNotEmpty) 'player_name': playerName,
      };
}
