/// Os números da simulação local do tráfego (`balance.json`, `traffic_sim`): é cenário e vale por aparelho. Dart puro.
library;

import '../../data/visual_pack.dart';

class TrafficSimConfig {
  const TrafficSimConfig({
    this.radiusM = 400,
    this.borderM = 60,
    this.rebuildM = 150,
    this.mergeM = 12,
    this.maxCars = 400,
    this.maxWalkers = 350,
    this.carsPer100m = const {'principal': 2.6, 'secondary': 1.8, 'local': 0.9},
    this.walkersPer100m = const {'principal': 0.7, 'secondary': 0.6, 'local': 0.45, 'pedestrian': 1.0},
    this.lanes = const {'principal': 2, 'secondary': 1, 'local': 1},
    this.speedMps = const {'principal': 12.5, 'secondary': 9.0, 'local': 6.5},
    this.accel = 1.5,
    this.brake = 2.0,
    this.headwayS = 1.2,
    this.minGapM = 2.0,
    this.turnMps = 3.5,
    this.greenS = 22,
    this.pedGreenS = 10,
    this.yellowS = 3,
    this.allRedS = 2,
    this.gapS = 4.5,
    this.cornerExtraM = 1.0,
    this.sidewalkM = 1.5,
    this.controlNearM = 25,
    this.entryNearM = 40,
    this.walkMps = 1.3,
    this.farM = 60,
    this.farEvery = 4,
    this.warmupS = 30,
    this.spawnPerS = 4,
    this.climateCarFloor = 0.4,
    this.climateWalkerFloor = 0.3,
    this.shelterNearM = 20,
    this.runMult = 2.4,
    this.windMps = const {'wind': 3, 'gale': 7, 'storm': 3, 'dry_dust': 3, 'sandstorm': 6, 'blizzard': 4, 'tornado': 8, 'rift_wind': 5, 'smoke': 1.5, 'smog': 1.5},
    this.windStyle = const {'smoke': 'smoke', 'smog': 'soot', 'sandstorm': 'sand', 'dry_dust': 'sand'},
    this.duneMps = 0.02,
    this.leaves = 40,
    this.loiter = const {'shop': 3, 'bar': 4, 'school': 6, 'square': 2, 'bus': 2},
    this.busShare = 0.04,
    this.busDwellS = 7,
    this.matchUtc = const [],
    this.matchBeforeS = 7200,
  });

  factory TrafficSimConfig.fromJson(Map<String, dynamic>? j) {
    const d = TrafficSimConfig();
    if (j == null) return d;
    double n(String k, double v) => (j[k] as num?)?.toDouble() ?? v;
    Map<String, double> m(String k, Map<String, double> v) => {...v, for (final e in ((j[k] as Map<String, dynamic>?) ?? const {}).entries) e.key: (e.value as num).toDouble()};
    return TrafficSimConfig(
      radiusM: n('radius_m', d.radiusM),
      borderM: n('border_m', d.borderM),
      rebuildM: n('rebuild_m', d.rebuildM),
      mergeM: n('merge_m', d.mergeM),
      maxCars: n('max_cars', d.maxCars.toDouble()).round(),
      maxWalkers: n('max_walkers', d.maxWalkers.toDouble()).round(),
      carsPer100m: m('cars_per_100m', d.carsPer100m),
      walkersPer100m: m('walkers_per_100m', d.walkersPer100m),
      lanes: {for (final e in m('lanes', {for (final e in d.lanes.entries) e.key: e.value.toDouble()}).entries) e.key: e.value.round()},
      speedMps: m('speed_mps', d.speedMps),
      accel: n('accel', d.accel),
      brake: n('brake', d.brake),
      headwayS: n('headway_s', d.headwayS),
      minGapM: n('min_gap_m', d.minGapM),
      turnMps: n('turn_mps', d.turnMps),
      greenS: n('green_s', d.greenS),
      pedGreenS: n('ped_green_s', d.pedGreenS),
      yellowS: n('yellow_s', d.yellowS),
      allRedS: n('all_red_s', d.allRedS),
      gapS: n('gap_s', d.gapS),
      cornerExtraM: n('corner_extra_m', d.cornerExtraM),
      sidewalkM: n('sidewalk_m', d.sidewalkM),
      controlNearM: n('control_near_m', d.controlNearM),
      entryNearM: n('entry_near_m', d.entryNearM),
      walkMps: n('walk_mps', d.walkMps),
      farM: n('far_m', d.farM),
      farEvery: n('far_every', d.farEvery.toDouble()).round(),
      warmupS: n('warmup_s', d.warmupS),
      spawnPerS: n('spawn_per_s', d.spawnPerS),
      climateCarFloor: n('climate_car_floor', d.climateCarFloor),
      climateWalkerFloor: n('climate_walker_floor', d.climateWalkerFloor),
      shelterNearM: n('shelter_near_m', d.shelterNearM),
      runMult: n('run_mult', d.runMult),
      windMps: m('wind_mps', d.windMps),
      windStyle: {...d.windStyle, for (final e in ((j['wind_style'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as String},
      duneMps: n('dune_mps', d.duneMps),
      leaves: n('leaves', d.leaves.toDouble()).round(),
      loiter: m('loiter', d.loiter),
      busShare: n('bus_share', d.busShare),
      busDwellS: n('bus_dwell_s', d.busDwellS),
      matchUtc: [for (final t in (j['match_utc'] as List<dynamic>?) ?? const []) DateTime.parse(t as String).millisecondsSinceEpoch ~/ 1000],
      matchBeforeS: n('match_before_s', d.matchBeforeS),
    );
  }

  /// Raio simulado em volta do jogador, a folga além dele onde ficam as bordas, e quanto o jogador anda até o grafo ser
  /// refeito em volta dele.
  final double radiusM, borderM, rebuildM;

  /// Esquinas ligadas por um trecho mais curto que isto (m) viram uma só.
  final double mergeM;
  final int maxCars, maxWalkers;

  /// Carros e passantes por 100 m de rua com a densidade em 1, por classe.
  final Map<String, double> carsPer100m, walkersPer100m;

  /// Faixas por sentido e velocidade de cruzeiro (m/s), por classe.
  final Map<String, int> lanes;
  final Map<String, double> speedMps;

  /// Modelo de seguimento (IDM): aceleração, freada confortável (m/s²), intervalo (s) e folga parado (m).
  final double accel, brake, headwayS, minGapM;

  /// Velocidade nas curvas das esquinas.
  final double turnMps;

  /// Semáforo: verde base, amarelo e vermelho geral, em segundos.
  final double greenS, yellowS, allRedS;

  /// Quanto a faixa fica aberta num semáforo de pedestre no meio da quadra (s).
  final double pedGreenS;

  /// Quem cede a vez entra se ninguém da preferencial chega em menos que isto (s).
  final double gapS;
  final double cornerExtraM, sidewalkM, controlNearM, entryNearM, walkMps;

  /// Além desta distância da tela (m), o agente atualiza a cada [farEvery] quadros.
  final double farM;
  final int farEvery;

  /// Quanto a simulação roda antes do primeiro quadro (s), para já começar com filas nos semáforos.
  final double warmupS;
  final double spawnPerS;

  /// Com o clima deixando o tráfego mais lento (multiplicador perto de 0), sobra esta fração dos carros e dos passantes.
  final double climateCarFloor, climateWalkerFloor;

  /// Marquise ou ponto de ônibus a até isto (m) da esquina faz dela um abrigo; e quanto mais rápido corre quem foi pego
  /// pela chuva.
  final double shelterNearM, runMult;

  /// A força do vento local (m/s) em cada clima de vento, e quantas folhas e papéis ele leva pela tela.
  final Map<String, double> windMps;
  final int leaves;

  /// O que o vento leva em cada clima (`smoke`, `soot`, `sand`; o resto leva folhas), e a que velocidade as dunas andam.
  final Map<String, String> windStyle;
  final double duneMps;

  /// Quanta gente fica parada em cada tipo de lugar na hora dele: comércio de dia, bar à noite, escola na entrada e na
  /// saída, sentada na praça, esperando no ponto de ônibus.
  final Map<String, double> loiter;

  /// A fração dos carros de avenida que é ônibus, e quanto ele fica parado no ponto.
  final double busShare, busDwellS;

  /// Os jogos em casa da Ponte Preta e do Guarani (início, UTC): nas [matchBeforeS] antes, a multidão anda para o estádio.
  final List<int> matchUtc;
  final double matchBeforeS;

  /// Dia de jogo em [utc]: algum jogo começa nas próximas [matchBeforeS]. [extra]: os do `events.json` assinado (o
  /// `match_utc` do `balance.json` fica vazio; é só para teste local).
  bool matchAt(int utc, [List<int> extra = const []]) => matchUtc.followedBy(extra).any((k) => utc >= k - matchBeforeS && utc < k);

  /// Quantos ficam parados num lugar do tipo [kind] na [hour] local.
  int loiterAt(String kind, double hour) {
    final n = loiter[kind] ?? 0;
    final on = switch (kind) {
      'shop' => hour >= 9 && hour < 19,
      'bar' => hour >= 19 || hour < 2 || (hour >= 11.5 && hour < 14),
      'school' => (hour >= 6.5 && hour < 7.5) || (hour >= 11.5 && hour < 12.5) || (hour >= 17 && hour < 18.5),
      'square' => hour >= 8 && hour < 18,
      'bus' => hour >= 6 && hour < 23,
      _ => false,
    };
    return on ? (kind == 'bar' && hour >= 11.5 && hour < 14 ? n / 2 : n).round() : 0;
  }

  double carDensityIn(double speedMult) => climateCarFloor + (1 - climateCarFloor) * speedMult.clamp(0.0, 1.0);
  double walkerDensityIn(double walkMult) => climateWalkerFloor + (1 - climateWalkerFloor) * walkMult.clamp(0.0, 1.0);

  int lanesOf(RoadClass c) => lanes[c.name] ?? 1;
  double speedOf(RoadClass c) => speedMps[c.name] ?? 6.5;
  double carConc(RoadClass c) => carsPer100m[c.name] ?? 0;
  double walkConc(RoadClass c) => walkersPer100m[c.name] ?? 0;
}
