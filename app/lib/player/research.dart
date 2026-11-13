/// A pesquisa do Bestiário (docs/GDD.md, "Bestiário"): cada espécie tem cinco níveis, um por tarefa, e cada nível libera
/// uma coisa (lore, onde aparece, atributos, bônus de tolerância). As tarefas vêm de `creatures.json` (`bestiary`);
/// o progresso sai do que o save guarda em [BestiaryEntry]. Dart puro.
library;

import 'bestiary.dart';

class ResearchTask {
  const ResearchTask({required this.kind, required this.text, required this.unlocks, this.n = 1, this.when = ''});

  factory ResearchTask.fromJson(Map<String, dynamic> j) => ResearchTask(
        kind: j['task'] as String,
        text: j['text'] as String,
        unlocks: j['unlocks'] as String,
        n: (j['n'] as int?) ?? 1,
        when: (j['when'] as String?) ?? '',
      );

  /// `capture` (capturar [n] vezes), `see` (ver em [when]), `biomes` (capturar em [n] biomas) ou `variant` (achar [n]).
  final String kind;
  final String text;

  /// O que o nível libera: `lore1`, `where`, `attributes`, `tolerance`, `lore3`.
  final String unlocks;
  final int n;

  /// `day`, `night`, `twilight`, `day+night` (os dois) ou `climate:a|b` (qualquer um dos climas).
  final String when;
}

/// O texto e a pesquisa de uma espécie.
class SpeciesLore {
  const SpeciesLore({required this.about, required this.lore, required this.research});

  factory SpeciesLore.fromJson(Map<String, dynamic> j) => SpeciesLore(
        about: j['about'] as String,
        lore: (j['lore'] as List<dynamic>).cast<String>(),
        research: [for (final t in j['research'] as List<dynamic>) ResearchTask.fromJson(t as Map<String, dynamic>)],
      );

  final String about;

  /// As três partes: a I abre no nível 1, a II no 3 e a III no 5.
  final List<String> lore;
  final List<ResearchTask> research;
}

/// Uma família: a linha Fagulha, Eco, Espírito.
class FamilyDef {
  const FamilyDef({required this.id, required this.name, required this.type, required this.sparkItem, required this.sparkName, required this.sparkAbout, required this.where, this.minLevel = 0, this.workTitle = '', this.workAbout = ''});

  factory FamilyDef.fromJson(Map<String, dynamic> j) {
    final spark = j['spark'] as Map<String, dynamic>;
    return FamilyDef(
      id: j['id'] as String,
      name: j['name'] as String,
      type: j['type'] as String,
      sparkItem: spark['item'] as String,
      sparkName: spark['name'] as String,
      sparkAbout: spark['about'] as String,
      where: {for (final e in (j['where'] as Map<String, dynamic>).entries) e.key: e.value as String},
      minLevel: (j['min_level'] as int?) ?? 0,
      workTitle: ((j['work'] as Map<String, dynamic>?)?['title'] as String?) ?? '',
      workAbout: ((j['work'] as Map<String, dynamic>?)?['about'] as String?) ?? '',
    );
  }

  final String id, name, type;
  final String sparkItem, sparkName, sparkAbout;

  /// Onde aparece, para a tela: `biome`, `hour`, `climate`, `moon` e, em algumas, `place`.
  final Map<String, String> where;
  final int minLevel;

  /// O trabalho da família na Casa (GDD, "Trabalho das criaturas"): só texto até a casa entrar, na fase 2.
  final String workTitle, workAbout;

  String get ecoId => '$id.eco';
  String get spiritId => '$id.spirit';
}

/// Quanto da tarefa [t] da espécie [speciesId] já foi feito, de 0 a `t.n`.
int taskProgress(ResearchTask t, String speciesId, Map<String, BestiaryEntry> bestiary) {
  final e = bestiary[speciesId] ?? const BestiaryEntry();
  switch (t.kind) {
    case 'capture':
      return e.captures.clamp(0, t.n);
    case 'biomes':
      return e.biomes.length.clamp(0, t.n);
    case 'variant':
      return bestiary.entries.where((x) => x.key.startsWith('$speciesId@') && x.value.seen).length.clamp(0, t.n);
    case 'see':
      if (t.when == 'day+night') return (e.when.contains('day') ? 1 : 0) + (e.when.contains('night') ? 1 : 0) == 2 ? t.n : 0;
      if (t.when.startsWith('climate:')) {
        return t.when.substring(8).split('|').any((c) => e.when.contains('climate:$c')) ? t.n : 0;
      }
      return e.when.contains(t.when) ? t.n : 0;
  }
  return 0;
}

/// O nível de pesquisa (0 a 5): quantas tarefas seguidas, desde a primeira, estão feitas.
int researchLevel(List<ResearchTask> tasks, String speciesId, Map<String, BestiaryEntry> bestiary) {
  var level = 0;
  for (final t in tasks) {
    if (taskProgress(t, speciesId, bestiary) < t.n) break;
    level++;
  }
  return level;
}

/// O que a pesquisa já liberou da espécie (os `unlocks` das tarefas feitas).
Set<String> researchUnlocks(List<ResearchTask> tasks, String speciesId, Map<String, BestiaryEntry> bestiary) =>
    {for (final t in tasks.take(researchLevel(tasks, speciesId, bestiary))) t.unlocks};

/// O estado de uma forma no Bestiário.
enum FormStatus { captured, seen, unknown }

FormStatus formState(String speciesId, Map<String, BestiaryEntry> bestiary) {
  final e = bestiary[speciesId];
  return e == null ? FormStatus.unknown : (e.captured ? FormStatus.captured : (e.seen ? FormStatus.seen : FormStatus.unknown));
}
