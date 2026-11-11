/// A neblina no relevo (`epochs.json`, `fog`, da época 9 em diante): **é mundo**, porque muda até onde os Ecos aparecem.
/// A densidade se acumula nas baixadas e perto de rios e lagos, sobe pouco nos morros e se desfaz com o sol da manhã.
/// Dart puro, função da posição e do tempo: igual em dois aparelhos.
library;

class FogModel {
  const FogModel({
    this.climates = const {'fog', 'fog_procession'},
    this.ringCells = 16,
    this.spanDm = 150,
    this.valleyView = 0.6,
    this.hillView = 1.6,
    this.waterBoost = 0.25,
    this.sunStartDeg = 8,
    this.sunClearDeg = 30,
    this.clearView = 2.5,
  });

  factory FogModel.fromJson(Map<String, dynamic> j) {
    const d = FogModel();
    double n(String k, double v) => (j[k] as num?)?.toDouble() ?? v;
    return FogModel(
      climates: {for (final c in (j['climates'] as List<dynamic>?) ?? d.climates) c as String},
      ringCells: (j['ring_cells'] as int?) ?? d.ringCells,
      spanDm: (j['span_dm'] as int?) ?? d.spanDm,
      valleyView: n('valley_view', d.valleyView),
      hillView: n('hill_view', d.hillView),
      waterBoost: n('water_boost', d.waterBoost),
      sunStartDeg: n('sun_start_deg', d.sunStartDeg),
      sunClearDeg: n('sun_clear_deg', d.sunClearDeg),
      clearView: n('clear_view', d.clearView),
    );
  }

  /// Os climas em que a visão dos Ecos passa a depender do relevo.
  final Set<String> climates;

  /// O lugar é comparado com a média de oito pontos a esta distância (células z21); [spanDm] decímetros abaixo dela é fundo
  /// de vale, [spanDm] acima é alto de morro.
  final int ringCells, spanDm;

  /// A visão do clima (`view_max_m`) vezes isto: no fundo do vale e no alto do morro.
  final double valleyView, hillView;

  /// Quanto a beira de rio ou lago conta a mais como baixada (0 a 1).
  final double waterBoost;

  /// O sol acima de [sunStartDeg] começa a desfazer a neblina; em [sunClearDeg] a visão chega a [clearView] vezes a do clima.
  final double sunStartDeg, sunClearDeg, clearView;

  /// Quão baixo é o lugar, de 0 (alto do morro) a 1 (fundo do vale): a altura do ponto ([h16], 1/16 dm) contra a média do
  /// anel em volta ([ring16], a soma de oito alturas). [nearWater] de 0 a 1.
  double lowness(int h16, int ring16, double nearWater) {
    final d = (ring16 / 8 - h16) / (spanDm * 16);
    return (0.5 + d / 2 + waterBoost * nearWater).clamp(0.0, 1.0);
  }

  /// Quanto o sol já desfez a neblina, de 0 (inteira) a 1 (desfeita), pela altura dele em graus.
  double cleared(double sunAltDeg) => ((sunAltDeg - sunStartDeg) / (sunClearDeg - sunStartDeg)).clamp(0.0, 1.0);

  /// A densidade da neblina no lugar, de 0 a 1.
  double density(double low, double sunAltDeg) => (0.3 + 0.7 * low) * (1 - cleared(sunAltDeg));

  /// O multiplicador da visão dos Ecos no lugar.
  double viewMult(double low, double sunAltDeg) {
    final base = hillView + (valleyView - hillView) * low, c = cleared(sunAltDeg);
    return base + (clearView - base) * c;
  }
}
