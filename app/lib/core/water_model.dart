/// Os números da água da chuva no relevo (`epochs.json`, `water`, da época 9 em diante). Ver `world/water_field.dart`.
library;

/// Os números da água (`epochs.json`, `water`): mudam o mundo, moram na época.
class WaterModel {
  const WaterModel({
    this.steps = 32,
    this.carveDm = const {'pedestrian': 1, 'local': 2, 'secondary': 3, 'principal': 3},
    this.drain256 = const {'pedestrian': 0, 'local': 5, 'secondary': 10, 'principal': 16},
    this.poolMin = 1100,
    this.spotSpacing = 0,
    this.wetPerCell = 0,
    this.wetChance = 0,
    this.meltClimates = const {},
    this.meltAs = 'drizzle',
    this.meltRise = 0.3,
    this.freezeClimates = const {},
    this.freezeAs = 'hard_frost',
    this.freezeFromH = 2,
    this.freezeToH = 7,
    this.freezeMaxSize = 0.5,
    this.floodFlow = 60000,
    this.floodFull = 400000,
    this.streamRiseDm = 12,
    this.dryDepthBonus = 0.5,
  });

  factory WaterModel.fromJson(Map<String, dynamic> j) {
    const d = WaterModel();
    Map<String, int> m(String k, Map<String, int> v) => {...v, for (final e in ((j[k] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int};
    return WaterModel(
      steps: (j['steps'] as int?) ?? d.steps,
      carveDm: m('carve_dm', d.carveDm),
      drain256: m('drain_256', d.drain256),
      poolMin: (j['pool_min'] as int?) ?? d.poolMin,
      spotSpacing: (j['spot_spacing'] as int?) ?? d.spotSpacing,
      wetPerCell: (j['wet_per_cell'] as int?) ?? d.wetPerCell,
      wetChance: (j['wet_chance'] as num?)?.toDouble() ?? d.wetChance,
      meltClimates: {for (final c in (j['melt_climates'] as List<dynamic>?) ?? const []) c as String},
      meltAs: (j['melt_as'] as String?) ?? d.meltAs,
      meltRise: (j['melt_rise'] as num?)?.toDouble() ?? d.meltRise,
      freezeClimates: {for (final c in (j['freeze_climates'] as List<dynamic>?) ?? const []) c as String},
      freezeAs: (j['freeze_as'] as String?) ?? d.freezeAs,
      freezeFromH: (j['freeze_from_h'] as int?) ?? d.freezeFromH,
      freezeToH: (j['freeze_to_h'] as int?) ?? d.freezeToH,
      freezeMaxSize: (j['freeze_max_size'] as num?)?.toDouble() ?? d.freezeMaxSize,
      floodFlow: (j['flood_flow'] as int?) ?? d.floodFlow,
      floodFull: (j['flood_full'] as int?) ?? d.floodFull,
      streamRiseDm: (j['stream_rise_dm'] as int?) ?? d.streamRiseDm,
      dryDepthBonus: (j['dry_depth_bonus'] as num?)?.toDouble() ?? d.dryDepthBonus,
    );
  }

  /// Quantos passos a água anda (cada passo, uma célula z21): também a folga lida em volta do tile.
  final int steps;

  /// Quanto o leito de cada classe de rua fica abaixo do terreno (dm) e quanto o bueiro tira por passo (em 1/256).
  final Map<String, int> carveDm, drain256;

  /// Água parada mínima para a célula ser uma poça (a chuva põe 1024 em cada célula).
  final int poolMin;

  /// Época 10 em diante: qualquer célula com água parada acima de [poolMin] pode ser poça, desde que fique a pelo menos
  /// isto (células z21) de outra maior. 0 (época 9): só os pontos com mais água que os oito em volta.
  final int spotSpacing;

  /// Época 10 em diante: enquanto chove, cada célula z17 sorteia [wetPerCell] trechos de rua molhada, e em cada um nasce
  /// o Eco da poça do clima com a chance [wetChance], mesmo sem poça ali.
  final int wetPerCell;
  final double wetChance;

  /// Ciclo da água (época 10 em diante). Depois de um clima de [meltClimates] (neve), a neve derretida entra no campo:
  /// aparecem as poças do clima [meltAs], que crescem na primeira fração [meltRise] do tempo de secar e depois secam.
  final Set<String> meltClimates;
  final String meltAs;
  final double meltRise;

  /// Nos climas de [freezeClimates], entre [freezeFromH] e [freezeToH] horas locais, a poça com até [freezeMaxSize] do
  /// tamanho cheio congela: vira a poça de gelo do clima [freezeAs] (com o item dela), no mesmo lugar.
  final Set<String> freezeClimates;
  final String freezeAs;
  final int freezeFromH, freezeToH;
  final double freezeMaxSize;

  /// Vazão acumulada a partir da qual o Dilúvio alaga a célula, e a que a alaga por inteiro.
  final int floodFlow, floodFull;

  /// Até quanto acima do córrego ou do lago (dm) a margem alaga no Dilúvio.
  final int streamRiseDm;

  /// Quanto a mais (fração do tempo de secar) a poça mais funda leva para secar: as baixadas secam por último.
  final double dryDepthBonus;
}
