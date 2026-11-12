/// As condições de cada família de Eco (docs/GDD.md, "Famílias da fase 1"), da época 11 em diante: a hora (dia, noite,
/// crepúsculo real), a lua cheia, o relevo, o clima e o nível mínimo do Conjurador mexem no peso da família na tabela do
/// bioma. Tudo é dado da época (`eco_v2.conditions`) e função da seed, do lugar e do tempo: igual para os amigos.
library;

/// O lugar e o instante de uma célula, no começo da janela dela.
class SpawnContext {
  const SpawnContext({required this.sunAltDeg, required this.moonIllum, required this.rise, required this.climate});

  /// Altura do sol em graus e a fração iluminada da lua (0 a 1).
  final double sunAltDeg, moonIllum;

  /// Quão alto o lugar é em relação ao entorno: -1 fundo de vale, 0 plano (ou sem relevo), 1 alto de morro.
  final double rise;

  /// O id do clima da célula.
  final String climate;
}

class FamilyCondition {
  const FamilyCondition({this.base = 1, this.day = 1, this.night = 1, this.twilight = 1, this.fullMoon = 1, this.hill = 1, this.valley = 1, this.climates = const {}, this.minLevel = 0});

  factory FamilyCondition.fromJson(Map<String, dynamic> j) {
    double n(String k) => (j[k] as num?)?.toDouble() ?? 1;
    return FamilyCondition(
      base: n('base'),
      day: n('day'),
      night: n('night'),
      twilight: n('twilight'),
      fullMoon: n('full_moon'),
      hill: n('hill'),
      valley: n('valley'),
      climates: {for (final e in ((j['climates'] as Map<String, dynamic>?) ?? const {}).entries) e.key: (e.value as num).toDouble()},
      minLevel: (j['min_level'] as int?) ?? 0,
    );
  }

  /// O peso fora dos climas de [climates]; num deles vale o número do clima.
  final double base;
  final double day, night, twilight, fullMoon, hill, valley;
  final Map<String, double> climates;

  /// O nível do Conjurador a partir do qual a família aparece para ele.
  final int minLevel;
}

class SpawnConditions {
  const SpawnConditions({required this.families, this.twilightDeg = 6, this.fullMoonMin = 0.9, this.ringCells = 16, this.spanDm = 150});

  factory SpawnConditions.fromJson(Map<String, dynamic> j) => SpawnConditions(
        twilightDeg: (j['twilight_deg'] as num).toDouble(),
        fullMoonMin: (j['full_moon_min'] as num).toDouble(),
        ringCells: j['ring_cells'] as int,
        spanDm: j['span_dm'] as int,
        families: {for (final e in (j['families'] as Map<String, dynamic>).entries) e.key: FamilyCondition.fromJson(e.value as Map<String, dynamic>)},
      );

  final Map<String, FamilyCondition> families;

  /// Crepúsculo: o sol a menos de [twilightDeg] graus do horizonte. Lua cheia: [fullMoonMin] ou mais da face iluminada.
  final double twilightDeg, fullMoonMin;

  /// O relevo do lugar é comparado com a média de oito pontos a [ringCells] células z21; [spanDm] decímetros acima dela é
  /// alto de morro e abaixo, fundo de vale (a mesma medida da neblina).
  final int ringCells, spanDm;

  FamilyCondition? of(String entryId) => families[entryId.split('.').first];

  /// Quanto o peso da espécie [entryId] na tabela é multiplicado em [c]. 1 para quem não tem condição.
  double mult(String entryId, SpawnContext c) {
    final f = of(entryId);
    if (f == null) return 1;
    var m = f.climates[c.climate] ?? f.base;
    m *= c.sunAltDeg.abs() < twilightDeg ? f.twilight : (c.sunAltDeg > 0 ? f.day : f.night);
    if (c.moonIllum >= fullMoonMin) m *= f.fullMoon;
    // O relevo pesa aos poucos: no plano não muda nada.
    if (c.rise > 0) m *= 1 + (f.hill - 1) * c.rise;
    if (c.rise < 0) m *= 1 + (f.valley - 1) * -c.rise;
    return m;
  }

  /// O Conjurador de nível [playerLevel] encontra a espécie [entryId].
  bool visibleTo(String entryId, int playerLevel) => playerLevel >= (of(entryId)?.minLevel ?? 0);

  /// Quão alto é um lugar de altura [h16] em relação ao anel em volta ([ring16], a soma de oito alturas): de -1 a 1.
  double rise(int h16, int ring16) => ((h16 - ring16 / 8) / (spanDm * 16)).clamp(-1.0, 1.0);
}
