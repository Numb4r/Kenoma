/// Clima (docs/GDD.md, "Tempo, astronomia e clima"). O determinístico sai da seed, da janela de 3 horas e da região
/// (um tile z12, cerca de 10 km), com a probabilidade seguindo a estação do ano de Campinas: é igual em todos os
/// aparelhos, sem rede, e é o único que mexe nos spawns. O clima de uma fonte de rede só muda o que se vê. Dart puro.
library;

import 'fnv.dart';
import 'pcg32.dart';

enum Weather {
  clear('clear', 'Limpo'),
  cloudy('cloudy', 'Nublado'),
  rain('rain', 'Chuva'),
  storm('storm', 'Tempestade');

  const Weather(this.id, this.label);

  final String id;
  final String label;

  static Weather parse(String? id) => values.firstWhere((w) => w.id == id, orElse: () => clear);

  bool get wet => this == rain || this == storm;
}

/// A estação pelo mês UTC (hemisfério sul): verão em dezembro a fevereiro.
String seasonOfMonth(int month) => switch (month) {
      12 || 1 || 2 => 'summer',
      3 || 4 || 5 => 'autumn',
      6 || 7 || 8 => 'winter',
      _ => 'spring',
    };

final int saltWthr = salt('WTHR');

/// O modelo do clima de uma época: a janela, as probabilidades por estação (limpo, nublado, chuva, tempestade) e
/// os multiplicadores de peso de spawn por tipo.
class WeatherModel {
  const WeatherModel({required this.windowS, required this.probs, required this.spawnMultipliers});

  factory WeatherModel.fromJson(Map<String, dynamic> j) => WeatherModel(
        windowS: j['window_s'] as int,
        probs: {
          for (final e in (j['probs'] as Map<String, dynamic>).entries) e.key: [for (final p in e.value as List<dynamic>) (p as num).toDouble()],
        },
        spawnMultipliers: {
          for (final e in (j['spawn_multipliers'] as Map<String, dynamic>).entries)
            e.key: {for (final t in (e.value as Map<String, dynamic>).entries) t.key: (t.value as num).toDouble()},
        },
      );

  final int windowS;
  final Map<String, List<double>> probs;

  /// `clima -> tipo -> multiplicador` do peso de spawn.
  final Map<String, Map<String, double>> spawnMultipliers;

  /// O clima de [tUtc] na região `(regionX, regionY)`, sorteado por `hash(seed, janela, região, WTHR)`.
  Weather at({required int seed, required int tUtc, required int regionX, required int regionY}) {
    final window = tUtc ~/ windowS;
    final month = DateTime.fromMillisecondsSinceEpoch(tUtc * 1000, isUtc: true).month;
    final p = probs[seasonOfMonth(month)] ?? const [1.0, 0.0, 0.0, 0.0];
    final u = Pcg32(fnv1a64([seed, window, regionX, regionY, saltWthr]), saltKenoma).nextFloat();
    var acc = 0.0;
    for (var i = 0; i < p.length; i++) {
      acc += p[i];
      if (u < acc) return Weather.values[i];
    }
    return Weather.values[p.length - 1];
  }

  /// O multiplicador do peso de um tipo (`fire`, `water`...) com o clima [w]; 1 se não há regra.
  double multiplier(Weather w, String typeId) => spawnMultipliers[w.id]?[typeId] ?? 1.0;
}

/// A região do clima de uma célula z20: o tile z12 que a contém (2^8 células por lado).
(int, int) weatherRegionOfCell(int cellX, int cellY) => (cellX ~/ 256, cellY ~/ 256);
