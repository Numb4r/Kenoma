/// O clima que o jogador vê (HUD e chuva no mapa). Por padrão é o determinístico da seed (`core/weather.dart`). Com
/// o interruptor "clima pela internet" ligado, usa o Open-Meteo: a posição é arredondada a ~1 km e o resultado é o da
/// janela de 3 horas, para amigos juntos verem o mesmo. Sem rede ou com qualquer erro, volta ao determinístico, sem
/// aviso. **O clima da rede só muda o que se vê**: o peso dos spawns usa sempre o determinístico, porque o mundo tem de
/// ser igual em todos os aparelhos e funcionar sem rede (CLAUDE.md, regra 4).
library;

import 'dart:convert';
import 'dart:io';

import '../core/weather.dart';

/// O código de tempo do Open-Meteo (WMO) como um dos quatro climas do jogo.
Weather weatherFromWmoCode(int code) {
  if (code == 0 || code == 1) return Weather.clear;
  if (code >= 95 && code <= 99) return Weather.storm;
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return Weather.rain;
  return Weather.cloudy; // 2, 3, nevoeiro, neve e o resto
}

/// A posição arredondada a 0,01° (~1,1 km): a mesma para amigos juntos.
double roundToKm(double deg) => (deg * 100).round() / 100;

/// A hora do dia (UTC) cujo código vale para a janela de 3 horas de [tUtc]: a do meio da janela.
int windowHourUtc(int tUtc, {int windowS = 10800}) => ((tUtc ~/ windowS) * windowS + windowS ~/ 2) ~/ 3600;

/// Escolhe, na resposta horária do Open-Meteo (`hourly.time` em UTC e `hourly.weather_code`), o clima da janela de
/// [tUtc]. `null` se a resposta não tem essa hora.
Weather? pickHourlyWeather(Map<String, dynamic> json, int tUtc) {
  final hourly = json['hourly'] as Map<String, dynamic>?;
  final times = (hourly?['time'] as List<dynamic>?)?.cast<String>();
  final codes = hourly?['weather_code'] as List<dynamic>?;
  if (times == null || codes == null || times.length != codes.length) return null;
  final want = DateTime.fromMillisecondsSinceEpoch(windowHourUtc(tUtc) * 3600 * 1000, isUtc: true);
  String two(int n) => n.toString().padLeft(2, '0');
  final key = '${want.year}-${two(want.month)}-${two(want.day)}T${two(want.hour)}:00';
  final i = times.indexOf(key);
  if (i < 0 || codes[i] == null) return null;
  return weatherFromWmoCode((codes[i] as num).toInt());
}

abstract class WeatherSource {
  /// O clima da janela de [tUtc] em ([lat], [lon]) já arredondados, ou `null` se não deu.
  Future<Weather?> fetch(double lat, double lon, int tUtc);
}

class OpenMeteoSource implements WeatherSource {
  OpenMeteoSource({this.timeout = const Duration(seconds: 6)});

  final Duration timeout;

  @override
  Future<Weather?> fetch(double lat, double lon, int tUtc) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      // Só a hora e a posição arredondada saem do aparelho. past_hours e forecast_hours cobrem a janela inteira.
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': lat.toStringAsFixed(2),
        'longitude': lon.toStringAsFixed(2),
        'hourly': 'weather_code',
        'timezone': 'UTC',
        'past_hours': '6',
        'forecast_hours': '6',
      });
      final req = await client.getUrl(uri).timeout(timeout);
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      return pickHourlyWeather(jsonDecode(body) as Map<String, dynamic>, tUtc);
    } catch (_) {
      return null; // sem rede ou resposta estranha: o determinístico assume, sem aviso
    } finally {
      client.close(force: true);
    }
  }
}

/// Junta o determinístico e a rede: [shown] é o que se vê agora. [refresh] busca na rede quando ela está ligada.
class WeatherService {
  WeatherService({required this.deterministic, required this.source, required this.online});

  /// O clima determinístico de (lat, lon) no instante: sempre existe.
  final Weather Function(double lat, double lon, int tUtc) deterministic;
  final WeatherSource source;

  /// Se o interruptor "clima pela internet" está ligado (lido a cada vez).
  final bool Function() online;

  final _cache = <(double, double, int), Weather>{};
  final _asked = <(double, double, int)>{};

  (double, double, int) _key(double lat, double lon, int tUtc) => (roundToKm(lat), roundToKm(lon), tUtc ~/ 10800);

  /// O clima que se vê: o da rede, se está ligado e já chegou, senão o determinístico.
  Weather shown(double lat, double lon, int tUtc) {
    if (online()) {
      final cached = _cache[_key(lat, lon, tUtc)];
      if (cached != null) return cached;
    }
    return deterministic(lat, lon, tUtc);
  }

  /// Pede o clima da rede para esta posição e janela (uma vez por janela e quadra de ~1 km). Nada acontece com a rede
  /// desligada. Falhas ficam em silêncio.
  Future<void> refresh(double lat, double lon, int tUtc) async {
    if (!online()) return;
    final k = _key(lat, lon, tUtc);
    if (_cache.containsKey(k) || !_asked.add(k)) return;
    final w = await source.fetch(k.$1, k.$2, tUtc);
    if (w == null) {
      _asked.remove(k); // tenta de novo mais tarde
      return;
    }
    _cache[k] = w;
  }
}
