/// As etapas altas no mundo (0.27.0; GDD, "Etapas altas antes dos grimórios e das Incursões"): a Entidade Maior solta e o
/// Arquétipo que surge no auge de um evento. É mundo, igual para todos os amigos, por isso mora na época (`epochs.json`,
/// bloco `high_tiers`), não no `balance.json`. Dart puro.
library;

class HighTiersModel {
  const HighTiersModel({
    this.majorPerMonth = 1,
    this.majorTries = 6,
    this.majorScanStepS = 3600,
    this.majorScanMaxSteps = 168,
    this.majorWindowS = 1200,
    this.majorRumorLeadS = 4 * 3600,
    this.majorLevel = 25,
    this.archetypeChance = 0.1,
    this.archetypePeakShare = 1 / 3,
    this.archetypeStayS = 12,
    this.archetypeEvents = const {},
  });

  factory HighTiersModel.fromJson(Map<String, dynamic> j) {
    final m = (j['major'] as Map<String, dynamic>?) ?? const {};
    final a = (j['archetype'] as Map<String, dynamic>?) ?? const {};
    int i(Map<String, dynamic> o, String k, int d) => (o[k] as num?)?.toInt() ?? d;
    double f(Map<String, dynamic> o, String k, double d) => (o[k] as num?)?.toDouble() ?? d;
    return HighTiersModel(
      majorPerMonth: i(m, 'per_month', 1),
      majorTries: i(m, 'tries', 6),
      majorScanStepS: i(m, 'scan_step_min', 60) * 60,
      majorScanMaxSteps: i(m, 'scan_max_h', 168) * 3600 ~/ (i(m, 'scan_step_min', 60) * 60),
      majorWindowS: i(m, 'window_min', 20) * 60,
      majorRumorLeadS: i(m, 'rumor_lead_h', 4) * 3600,
      majorLevel: i(m, 'level', 25),
      archetypeChance: f(a, 'chance', 0.1),
      archetypePeakShare: f(a, 'peak_share', 1 / 3),
      archetypeStayS: i(a, 'stay_s', 12),
      archetypeEvents: {for (final e in ((a['events'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as String},
    );
  }

  /// Entidades soltas por família, por região, por mês (no máximo), e quantos pontos o sorteio tenta para achar uma célula e
  /// uma hora em que a condição do ritual da família vale.
  final int majorPerMonth;
  final int majorTries;

  /// O passo da busca pela hora em que a condição vale, e quantos passos cada ponto anda no máximo (o custo no celular:
  /// 12 famílias × pontos × passos, uma vez por mês e região).
  final int majorScanStepS;
  final int majorScanMaxSteps;

  /// Quanto ela fica, e quanto antes o rumor sai no fórum.
  final int majorWindowS;
  final int majorRumorLeadS;

  /// O nível da Entidade solta.
  final int majorLevel;

  /// A chance de uma célula z17 ter o Arquétipo no auge de uma ocorrência do evento da família, a parte do meio do evento
  /// que conta como auge e quantos segundos ele fica à vista.
  final double archetypeChance;
  final double archetypePeakShare;
  final int archetypeStayS;

  /// Família -> o evento grande (`eventos.json`) ou o clima (`clima.json`, pela janela dele) em que o Arquétipo dela pode surgir.
  final Map<String, String> archetypeEvents;
}
