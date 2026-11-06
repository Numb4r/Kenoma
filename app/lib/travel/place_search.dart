/// Busca de lugar pelo nome, para o destino do Modo Viagem: o Nominatim do OpenStreetMap. Saem do aparelho só o texto
/// digitado e um `viewbox` arredondado a ~1 km; o User-Agent é genérico. No máximo um pedido por segundo. Sem rede a busca
/// avisa e o toque no mapa continua valendo.
library;

import 'dart:convert';
import 'dart:io';

import '../world/weather_source.dart' show roundToKm;

class Place {
  const Place({required this.name, required this.lat, required this.lon});

  final String name;
  final double lat;
  final double lon;
}

/// O endereço do pedido. O `viewbox` só dá preferência, não limita: `bounded` fica de fora.
Uri nominatimUri(String query, {required double lat, required double lon, required double viewboxDeg, required int limit}) {
  final clat = roundToKm(lat), clon = roundToKm(lon);
  String f(double v) => v.toStringAsFixed(2);
  return Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': query,
    'format': 'jsonv2',
    'limit': '$limit',
    'accept-language': 'pt-BR',
    'viewbox': '${f(clon - viewboxDeg)},${f(clat + viewboxDeg)},${f(clon + viewboxDeg)},${f(clat - viewboxDeg)}',
  });
}

/// Lê a resposta. Item sem nome ou sem coordenada fica de fora.
List<Place> parsePlaces(String body) {
  final json = jsonDecode(body);
  if (json is! List<dynamic>) return const [];
  return [
    for (final e in json)
      if (e is Map<String, dynamic> && e['display_name'] is String && double.tryParse('${e['lat']}') != null && double.tryParse('${e['lon']}') != null)
        Place(name: e['display_name'] as String, lat: double.parse('${e['lat']}'), lon: double.parse('${e['lon']}')),
  ];
}

/// Quantos milissegundos esperar antes do próximo pedido, para ficar a [minIntervalMs] do anterior.
int rateLimitWaitMs({required int? lastMs, required int nowMs, required int minIntervalMs}) {
  if (lastMs == null) return 0;
  final wait = lastMs + minIntervalMs - nowMs;
  return wait > 0 ? wait : 0;
}

class PlaceSearch {
  PlaceSearch({required this.appVersion, required this.minIntervalS, required this.viewboxDeg, required this.limit, required this.timeoutS});

  /// Só a versão: `Kenoma/0.15.1+24`. Nenhum dado do jogador.
  final String appVersion;
  final double minIntervalS;
  final double viewboxDeg;
  final int limit;
  final int timeoutS;

  int? _lastMs;
  final Stopwatch _clock = Stopwatch()..start();

  /// Os lugares achados, ou `null` se não deu (sem rede, resposta estranha).
  Future<List<Place>?> search(String query, {required double lat, required double lon}) async {
    final wait = rateLimitWaitMs(lastMs: _lastMs, nowMs: _clock.elapsedMilliseconds, minIntervalMs: (minIntervalS * 1000).round());
    _lastMs = _clock.elapsedMilliseconds + wait;
    if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
    final timeout = Duration(seconds: timeoutS);
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent = 'Kenoma/$appVersion';
    try {
      final req = await client.getUrl(nominatimUri(query, lat: lat, lon: lon, viewboxDeg: viewboxDeg, limit: limit)).timeout(timeout);
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) return null;
      return parsePlaces(await res.transform(utf8.decoder).join().timeout(timeout));
    } catch (_) {
      return null; // sem rede ou resposta estranha: a tela avisa
    } finally {
      client.close(force: true);
    }
  }
}
