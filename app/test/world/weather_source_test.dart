import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/weather.dart';
import 'package:kenoma/world/weather_source.dart';

class _Fake implements WeatherSource {
  _Fake(this.result);

  Weather? result;
  final calls = <(double, double, int)>[];

  @override
  Future<Weather?> fetch(double lat, double lon, int tUtc) async {
    calls.add((lat, lon, tUtc));
    return result;
  }
}

void main() {
  const t = 1790040000; // 2026-09-22 01:20 UTC

  test('os códigos do Open-Meteo viram os quatro climas', () {
    expect([for (final c in [0, 1]) weatherFromWmoCode(c)], everyElement(Weather.clear));
    expect([for (final c in [2, 3, 45, 48, 71, 85]) weatherFromWmoCode(c)], everyElement(Weather.cloudy));
    expect([for (final c in [51, 55, 61, 65, 67, 80, 82]) weatherFromWmoCode(c)], everyElement(Weather.rain));
    expect([for (final c in [95, 96, 99]) weatherFromWmoCode(c)], everyElement(Weather.storm));
  });

  test('a posição é arredondada a ~1 km: amigos a poucas ruas pedem a mesma coisa', () {
    expect(roundToKm(-22.81744), -22.82);
    expect(roundToKm(-22.8149), -22.81);
    expect(roundToKm(-47.0697), -47.07);
    expect(roundToKm(-22.8174), roundToKm(-22.8212), reason: 'a ~400 m de distância cai no mesmo ponto');
  });

  test('a hora pedida é a do meio da janela de 3 horas, igual para todos da janela', () {
    final w0 = (t ~/ 10800) * 10800;
    final hours = {for (var s = 0; s < 10800; s += 600) windowHourUtc(w0 + s)};
    expect(hours.length, 1, reason: 'uma hora só para a janela inteira');
    expect(windowHourUtc(w0), (w0 + 5400) ~/ 3600);
  });

  test('lê a hora certa da resposta horária e ignora respostas quebradas', () {
    final hour = windowHourUtc(t);
    String iso(int h) {
      final d = DateTime.fromMillisecondsSinceEpoch(h * 3600 * 1000, isUtc: true);
      String two(int n) => n.toString().padLeft(2, '0');
      return '${d.year}-${two(d.month)}-${two(d.day)}T${two(d.hour)}:00';
    }

    final json = {
      'hourly': {
        'time': [for (var h = hour - 3; h <= hour + 3; h++) iso(h)],
        'weather_code': [0, 0, 0, 63, 95, 0, 0],
      },
    };
    expect(pickHourlyWeather(json, t), Weather.rain, reason: 'o código da hora do meio da janela');
    expect(pickHourlyWeather({'hourly': {'time': <String>[], 'weather_code': <int>[]}}, t), isNull);
    expect(pickHourlyWeather({'x': 1}, t), isNull);
    expect(pickHourlyWeather({'hourly': {'time': ['a'], 'weather_code': <int>[]}}, t), isNull);
  });

  group('serviço', () {
    Weather det(double la, double lo, int tt) => Weather.clear;

    test('com a rede desligada (o padrão) mostra o determinístico e nunca consulta a rede', () async {
      final src = _Fake(Weather.storm);
      final svc = WeatherService(deterministic: det, source: src, online: () => false);
      await svc.refresh(-22.8, -47.0, t);
      expect(src.calls, isEmpty);
      expect(svc.shown(-22.8, -47.0, t), Weather.clear);
    });

    test('ligada: depois da resposta mostra o da rede; antes dela, o determinístico', () async {
      final src = _Fake(Weather.storm);
      final svc = WeatherService(deterministic: det, source: src, online: () => true);
      expect(svc.shown(-22.8174, -47.0697, t), Weather.clear);
      await svc.refresh(-22.8174, -47.0697, t);
      expect(svc.shown(-22.8174, -47.0697, t), Weather.storm);
      expect(src.calls.single, (-22.82, -47.07, t), reason: 'só a posição arredondada sai do aparelho');
    });

    test('uma consulta por janela e por quadra: andar um pouco ou voltar a pedir não repete', () async {
      final src = _Fake(Weather.rain);
      final svc = WeatherService(deterministic: det, source: src, online: () => true);
      await svc.refresh(-22.8174, -47.0697, t);
      await svc.refresh(-22.8190, -47.0701, t + 60);
      await svc.refresh(-22.8174, -47.0697, t + 120);
      expect(src.calls, hasLength(1));
      await svc.refresh(-22.8174, -47.0697, t + 10800);
      expect(src.calls, hasLength(2), reason: 'janela nova');
    });

    test('sem rede ou com erro volta ao determinístico em silêncio e tenta de novo depois', () async {
      final src = _Fake(null);
      final svc = WeatherService(deterministic: (a, b, c) => Weather.cloudy, source: src, online: () => true);
      await svc.refresh(-22.8, -47.0, t);
      expect(svc.shown(-22.8, -47.0, t), Weather.cloudy);
      src.result = Weather.rain;
      await svc.refresh(-22.8, -47.0, t + 30);
      expect(src.calls.length, 2, reason: 'a falha não fica gravada como resposta');
      expect(svc.shown(-22.8, -47.0, t + 30), Weather.rain);
    });

    test('desligar a rede volta ao determinístico mesmo com resposta guardada', () async {
      var on = true;
      final svc = WeatherService(deterministic: det, source: _Fake(Weather.storm), online: () => on);
      await svc.refresh(-22.8, -47.0, t);
      expect(svc.shown(-22.8, -47.0, t), Weather.storm);
      on = false;
      expect(svc.shown(-22.8, -47.0, t), Weather.clear);
    });
  });
}
