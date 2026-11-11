/// Os números da água da chuva no relevo (`epochs.json`, `water`, da época 9 em diante). Ver `world/water_field.dart`.
library;

/// Os números da água (`epochs.json`, `water`): mudam o mundo, moram na época.
class WaterModel {
  const WaterModel({
    this.steps = 32,
    this.carveDm = const {'pedestrian': 1, 'local': 2, 'secondary': 3, 'principal': 3},
    this.drain256 = const {'pedestrian': 0, 'local': 5, 'secondary': 10, 'principal': 16},
    this.poolMin = 1100,
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

  /// Vazão acumulada a partir da qual o Dilúvio alaga a célula, e a que a alaga por inteiro.
  final int floodFlow, floodFull;

  /// Até quanto acima do córrego ou do lago (dm) a margem alaga no Dilúvio.
  final int streamRiseDm;

  /// Quanto a mais (fração do tempo de secar) a poça mais funda leva para secar: as baixadas secam por último.
  final double dryDepthBonus;
}
