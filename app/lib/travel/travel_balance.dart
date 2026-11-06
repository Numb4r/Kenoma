/// Os números do Modo Viagem (`balance.json`, bloco `travel`) e os veículos. Nada aqui muda o mundo: é o que vale por
/// aparelho. Dart puro.
library;

enum Vehicle {
  foot('A pé'),
  bike('Bicicleta'),
  moto('Moto'),
  car('Carro'),
  bus('Ônibus');

  const Vehicle(this.label);

  /// O nome na interface.
  final String label;

  /// Moto, carro e ônibus: nada exige tocar na tela e o jogo vira o Rádio do Véu.
  bool get passive => this == moto || this == car || this == bus;

  /// Moto e carro perguntam se o jogador é passageiro. Quem dirige não ganha nada.
  bool get asksPassenger => this == moto || this == car;

  /// As regras de rua de quem vai motorizado: respeita a mão única e fica fora dos caminhos de pedestre.
  bool get motorized => passive;
}

class VehicleBalance {
  VehicleBalance(Map<String, dynamic> j)
      : maxKmh = (j['max_kmh'] as num).toDouble(),
        bandM = (j['band_m'] as num).toDouble(),
        sparksPerKm = (j['sparks_per_km'] as num).toDouble();

  /// Até esta velocidade o trecho conta para o baú (e, na bicicleta, para a coleta na faixa da rota).
  final double maxKmh;
  double get maxMps => maxKmh / 3.6;

  /// Meia largura da faixa de coleta ao longo da rota, em metros. 0: sem faixa.
  final double bandM;

  /// Fagulhas por km no baú. 0: sem baú (a pé é jogo normal).
  final double sparksPerKm;
}

class TravelBalance {
  TravelBalance(Map<String, dynamic> balance) : this._(balance['travel'] as Map<String, dynamic>);

  TravelBalance._(Map<String, dynamic> t)
      : vehicles = {for (final v in Vehicle.values) v: VehicleBalance((t['vehicles'] as Map<String, dynamic>)[v.name] as Map<String, dynamic>)},
        autoMarkM = _d(t['auto_mark_m']),
        markDurationS = t['mark_duration_s'] as int,
        chestDailyCap = t['chest_daily_cap'] as int,
        minStepM = _d(t['min_step_m']),
        arrivalRadiusM = _d(_m(t, 'arrival')['radius_m']),
        arrivalHoldS = _m(t, 'arrival')['hold_s'] as int,
        arrivalSpeedMps = _d(_m(t, 'arrival')['speed_mps']),
        snapM = _d(_m(t, 'route')['snap_m']),
        maxNodes = _m(t, 'route')['max_nodes'] as int,
        sliceNodes = _m(t, 'route')['slice_nodes'] as int,
        pickViewM = _d(_m(t, 'view')['pick_m']),
        tripViewM = _d(_m(t, 'view')['trip_m']),
        avatarMaxMps = _d(t['avatar_max_mps']),
        radioLineS = t['radio_line_s'] as int,
        urbanSpeedMps = _d(_m(t, 'ride')['urban_speed_mps']),
        etaDefaultMin = _m(t, 'ride')['eta_default_min'] as int,
        etaMaxMin = _m(t, 'ride')['eta_max_min'] as int,
        carTries = _m(t, 'ride')['car_tries'] as int,
        boardS = _d(_m(t, 'ride')['board_s']),
        leaveS = _d(_m(t, 'ride')['leave_s']),
        leaveSpeedMps = _d(_m(t, 'ride')['leave_speed_mps']),
        searchMinIntervalS = _d(_m(t, 'search')['min_interval_s']),
        searchViewboxDeg = _d(_m(t, 'search')['viewbox_deg']),
        searchLimit = _m(t, 'search')['limit'] as int,
        searchTimeoutS = _m(t, 'search')['timeout_s'] as int;

  static double _d(Object? v) => (v as num).toDouble();
  static Map<String, dynamic> _m(Map<String, dynamic> t, String k) => t[k] as Map<String, dynamic>;

  final Map<Vehicle, VehicleBalance> vehicles;

  /// Até onde a viagem de passageiro marca os Ecos sozinha, e por quanto tempo essa marca vale (GDD: algumas horas).
  final double autoMarkM;
  final int markDurationS;

  /// Quantas Fagulhas o baú dá por dia local, somadas todas as viagens.
  final int chestDailyCap;

  /// O trecho só entra na distância depois de andar isto: tira o tremor do GPS parado.
  final double minStepM;

  /// Chegada: parado (abaixo de [arrivalSpeedMps]) a até [arrivalRadiusM] do destino por [arrivalHoldS] segundos.
  final double arrivalRadiusM;
  final int arrivalHoldS;
  final double arrivalSpeedMps;

  /// Rota: até onde a origem e o destino procuram uma rua, o teto de nós do A* e quantos nós por fatia, sem travar a tela.
  final double snapM;
  final int maxNodes;
  final int sliceNodes;

  /// Largura da tela, em metros, ao escolher o destino e durante a viagem passiva.
  final double pickViewM;
  final double tripViewM;

  /// Velocidade que o marcador aceita em viagem (o normal, a pé, recusa acima de 12 m/s).
  final double avatarMaxMps;

  /// Segundos de cada fala do Rádio do Véu.
  final int radioLineS;

  /// Corrida: velocidade urbana média (põe o carro à distância ETA × velocidade), o ETA que os botões sugerem e o maior
  /// aceito, quantas direções tentar para achar rua, duração do embarque, e como o carro sai depois da chegada.
  final double urbanSpeedMps;
  final int etaDefaultMin;
  final int etaMaxMin;
  final int carTries;
  final double boardS;
  final double leaveS;
  final double leaveSpeedMps;

  /// Busca de lugar: intervalo mínimo entre pedidos, meia largura do `viewbox` em graus, resultados e tempo limite.
  final double searchMinIntervalS;
  final double searchViewboxDeg;
  final int searchLimit;
  final int searchTimeoutS;
}
