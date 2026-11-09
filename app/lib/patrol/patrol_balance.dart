/// Os números da Patrulha do Véu (`balance.json`, bloco `patrol`). Nada aqui muda o mundo: é o que vale por aparelho.
/// O limite de caminhada vem do Modo Viagem (`travel.vehicles.foot.max_kmh`). Dart puro.
library;

class PatrolBalance {
  PatrolBalance(Map<String, dynamic> balance) : this._(balance['patrol'] as Map<String, dynamic>, balance['travel'] as Map<String, dynamic>);

  PatrolBalance._(Map<String, dynamic> p, Map<String, dynamic> travel)
      : gpsIntervalS = p['gps_interval_s'] as int,
        gpsDistanceM = p['gps_distance_m'] as int,
        maxHoursDefault = p['max_hours_default'] as int,
        maxHoursLimit = p['max_hours_limit'] as int,
        batteryMinPct = p['battery_min_pct'] as int,
        gpsTimeoutS = p['gps_timeout_s'] as int,
        tickS = p['tick_s'] as int,
        markM = _d(p['mark_m']),
        markDurationS = p['mark_duration_s'] as int,
        streetM = _d(p['street_m']),
        vibrateMs = [for (final v in p['vibrate_ms'] as List<dynamic>) v as int],
        vibrateRareMs = [for (final v in p['vibrate_rare_ms'] as List<dynamic>) v as int],
        vehicleMps = _d(p['vehicle_kmh']) / 3.6,
        vehicleConfirmFixes = p['vehicle_confirm_fixes'] as int,
        vehicleExitS = p['vehicle_exit_s'] as int,
        walkLineM = _d(p['walk_line_m']),
        maxJumpM = _d(p['max_jump_m']),
        journalReadS = p['journal_read_s'] as int,
        walkMaxMps = _d((((travel['vehicles'] as Map<String, dynamic>)['foot']) as Map<String, dynamic>)['max_kmh']) / 3.6;

  static double _d(Object? v) => (v as num).toDouble();

  /// GPS em precisão equilibrada: uma leitura a cada [gpsIntervalS] segundos ou [gpsDistanceM] metros andados. O intervalo
  /// é o primeiro botão se a bateria passar da meta.
  final int gpsIntervalS;
  final int gpsDistanceM;

  /// Duração máxima: o padrão e o teto que os Ajustes aceitam, em horas.
  final int maxHoursDefault;
  final int maxHoursLimit;

  /// Desliga com a bateria abaixo disto (%) ou com o GPS calado por [gpsTimeoutS] segundos.
  final int batteryMinPct;
  final int gpsTimeoutS;

  /// De quanto em quanto tempo o serviço confere o relógio, a bateria e a notificação, em segundos.
  final int tickS;

  /// Ecos a até [markM] metros são marcados, e a marca vale [markDurationS] segundos contados da hora do diário.
  final double markM;
  final int markDurationS;

  /// Até onde se procura o nome da rua de um Eco raro, em metros.
  final double streetM;

  /// Padrões de vibração (Android: espera, vibra, espera...), em ms: Eco comum e raro (Brilhante, variante, Espírito).
  final List<int> vibrateMs;
  final List<int> vibrateRareMs;

  /// Acima de [walkMaxMps] valem as regras do Modo Viagem; acima de [vehicleMps] por [vehicleConfirmFixes] leituras seguidas
  /// é carro ou moto, e a pergunta sai. Abaixo da caminhada por [vehicleExitS] segundos a viagem acaba.
  final double walkMaxMps;
  final double vehicleMps;
  final int vehicleConfirmFixes;
  final int vehicleExitS;

  /// A caminhada vai para o diário de [walkLineM] em [walkLineM] metros; um salto maior que [maxJumpM] entre leituras não
  /// conta (GPS ruim ou teleporte).
  final double walkLineM;
  final double maxJumpM;

  /// Com o app aberto e a Patrulha ligada, o app lê o diário a cada [journalReadS] segundos.
  final int journalReadS;
}
