/// Os Outros Veilbreakers (`epochs.json`, `veilbreakers`, da época 12 em diante; docs/GDD.md, "Outros Veilbreakers"):
/// **é mundo**, porque eles sintonizam Ecos que iam sumir e o Eco some para todos. Só os números; quem os usa é
/// `world/veilbreakers.dart`. Dart puro.
library;

class VeilbreakerModel {
  const VeilbreakerModel({
    this.slotS = 900,
    this.baseChance = 0.05,
    this.biomeMult = const {'lit': 3, 'green': 2, 'urban': 1, 'residential': 0.5, 'sacred': 1},
    this.hourMult = const [0.05, 0.02, 0.02, 0.02, 0.02, 0.05, 0.3, 0.6, 0.8, 0.8, 0.8, 0.9, 1, 1, 1, 1, 1.3, 1.8, 2, 1.8, 1.4, 1, 0.6, 0.2],
    this.walkMps = 1.1,
    this.tuneRadiusM = 45,
    this.tuneLeadS = 120,
    this.tuneChance = 0.5,
    this.tuneMax = 2,
    this.tunePauseS = 6,
    this.tuneAnimS = 2,
    this.protectM = 30,
    this.knownPerTile = 2,
  });

  factory VeilbreakerModel.fromJson(Map<String, dynamic> j) {
    const d = VeilbreakerModel();
    double n(String k, double v) => (j[k] as num?)?.toDouble() ?? v;
    final tune = (j['tune'] as Map<String, dynamic>?) ?? const {};
    double t(String k, double v) => (tune[k] as num?)?.toDouble() ?? v;
    return VeilbreakerModel(
      slotS: (j['slot_s'] as int?) ?? d.slotS,
      baseChance: n('base_chance', d.baseChance),
      biomeMult: {for (final e in ((j['biome_mult'] as Map<String, dynamic>?) ?? d.biomeMult).entries) e.key: (e.value as num).toDouble()},
      hourMult: [for (final v in (j['hour_mult'] as List<dynamic>?) ?? d.hourMult) (v as num).toDouble()],
      walkMps: n('walk_mps', d.walkMps),
      tuneRadiusM: t('radius_m', d.tuneRadiusM),
      tuneLeadS: t('lead_s', d.tuneLeadS),
      tuneChance: t('chance', d.tuneChance),
      tuneMax: (tune['max'] as int?) ?? d.tuneMax,
      tunePauseS: t('pause_s', d.tunePauseS),
      tuneAnimS: t('anim_s', d.tuneAnimS),
      protectM: t('protect_m', d.protectM),
      knownPerTile: (j['known_per_tile'] as int?) ?? d.knownPerTile,
    );
  }

  /// A fatia de tempo (segundos) em que um NPC sorteado fica numa célula z18.
  final int slotS;

  /// A chance de uma célula z18 ter um NPC na fatia, vezes o bioma do centro e a hora local.
  final double baseChance;
  final Map<String, num> biomeMult;

  /// Multiplicador por hora local (24 valores, o fuso fixo do clima, UTC-3): quase ninguém de madrugada, mais no fim da tarde.
  final List<double> hourMult;

  /// Velocidade a pé (m/s) no caminho de ida e volta.
  final double walkMps;

  /// Sintonia: só Ecos da camada base a até [tuneRadiusM] do NPC cuja janela termina dentro da fatia dele; somem
  /// [tuneLeadS] segundos antes do fim, com chance [tuneChance], no máximo [tuneMax] por fatia. O NPC para [tunePauseS] e a
  /// animação dura [tuneAnimS]. Nunca some um Eco a até [protectM] do jogador (isso é local, o resto é igual para todos).
  final double tuneRadiusM, tuneLeadS, tuneChance, tunePauseS, tuneAnimS, protectM;
  final int tuneMax;

  /// Quantos conhecidos (`npc.json`, `known`) cada tile z15 tem.
  final int knownPerTile;

  /// O mesmo modelo com outra chance base (o debug "NPC em toda célula").
  VeilbreakerModel withChance(double c) => VeilbreakerModel(slotS: slotS, baseChance: c, biomeMult: {for (final k in biomeMult.keys) k: 1}, hourMult: const [1], walkMps: walkMps, tuneRadiusM: tuneRadiusM, tuneLeadS: tuneLeadS, tuneChance: tuneChance, tuneMax: tuneMax, tunePauseS: tunePauseS, tuneAnimS: tuneAnimS, protectM: protectM, knownPerTile: knownPerTile);

  double biomeFactor(String key) => (biomeMult[key] ?? 0.5).toDouble();
  double hourFactor(int localHour) => hourMult.isEmpty ? 1 : hourMult[localHour % hourMult.length];
}
