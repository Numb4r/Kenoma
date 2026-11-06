import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/travel/deep_links.dart';
import 'package:kenoma/travel/place_search.dart';

void main() {
  group('uberDeepLink', () {
    test('monta o link padrão com embarque em my_location e coordenadas fixas', () {
      expect(
        uberDeepLink(lat: -22.9056, lon: -47.0608, nickname: 'Unicamp'),
        'uber://?action=setPickup&pickup=my_location&dropoff%5Blatitude%5D=-22.905600&dropoff%5Blongitude%5D=-47.060800&dropoff%5Bnickname%5D=Unicamp',
      );
    });

    test('acentos e espaços do nome vão codificados', () {
      final url = uberDeepLink(lat: 1, lon: 2, nickname: 'Praça São João & Cia');
      expect(url, contains('dropoff%5Bnickname%5D=Pra%C3%A7a%20S%C3%A3o%20Jo%C3%A3o%20%26%20Cia'));
      expect(Uri.parse(url).queryParameters['dropoff[nickname]'], 'Praça São João & Cia');
      expect(Uri.parse(url).queryParameters['dropoff[latitude]'], '1.000000');
    });
  });

  test('o deep link da 99 fica nulo até ser testado no aparelho', () {
    expect(taxi99DeepLink(lat: 1, lon: 2, nickname: 'x'), isNull);
  });

  group('busca de lugar', () {
    test('o viewbox sai arredondado a ~1 km e a posição exata não vaza', () {
      final uri = nominatimUri('praça', lat: -22.90561234, lon: -47.06087654, viewboxDeg: 0.2, limit: 5);
      expect(uri.host, 'nominatim.openstreetmap.org');
      expect(uri.path, '/search');
      expect(uri.queryParameters['viewbox'], '-47.26,-22.71,-46.86,-23.11');
      expect(uri.toString(), isNot(contains('90561')));
      expect(uri.queryParameters.containsKey('bounded'), isFalse);
    });

    test('lê a resposta e ignora item quebrado', () {
      final places = parsePlaces('[{"display_name":"A","lat":"-22.9","lon":"-47.0"},{"display_name":"B"},{"lat":"1","lon":"2"}]');
      expect(places.length, 1);
      expect(places.single.name, 'A');
      expect(places.single.lat, -22.9);
      expect(parsePlaces('{}'), isEmpty);
    });

    test('no máximo um pedido por segundo', () {
      expect(rateLimitWaitMs(lastMs: null, nowMs: 5, minIntervalMs: 1000), 0);
      expect(rateLimitWaitMs(lastMs: 1000, nowMs: 1300, minIntervalMs: 1000), 700);
      expect(rateLimitWaitMs(lastMs: 1000, nowMs: 2000, minIntervalMs: 1000), 0);
    });
  });
}
