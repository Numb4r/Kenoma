import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/dev/game_clock.dart';
import 'package:kenoma/dev/gps_simulator.dart';
import 'package:kenoma/world/geo_fix.dart';
import 'package:kenoma/world/gps_filter.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/world/position_source.dart';

const mLat = 111132.92, mLon = 111319.49;

double metersBetween(double lat0, double lon0, double lat1, double lon1) {
  final dy = (lat1 - lat0) * mLat, dx = (lon1 - lon0) * mLon * math.cos(lat0 * math.pi / 180);
  return math.sqrt(dx * dx + dy * dy);
}

void main() {
  late SimulatedPositionSource sim;
  late List<GeoFix> got;

  setUp(() async {
    sim = SimulatedPositionSource(lat: kUnicamp.$1, lon: kUnicamp.$2, startTimeMs: 1000000);
    got = [];
    sim.fixes.listen(got.add);
    await sim.start();
    await pumpEventQueue();
    got.clear(); // a primeira leitura, logo ao iniciar, não interessa aos testes de movimento
  });
  tearDown(() => sim.stop());

  group('joystick e velocidade', () {
    test('as velocidades prontas: andando 1,4, correndo 3, bicicleta 6 m/s', () {
      expect([for (final s in SimSpeed.values) (s.label, s.mps)], [('Andando', 1.4), ('Correndo', 3.0), ('Bicicleta', 6.0)]);
    });

    test('parado, o jogador não sai do lugar, mas as leituras continuam saindo', () async {
      sim.advance(const Duration(seconds: 5));
      await pumpEventQueue();
      expect(got, hasLength(5));
      for (final f in got) {
        expect((f.lat, f.lon), (kUnicamp.$1, kUnicamp.$2));
      }
    });

    test('joystick para o leste anda para o leste na velocidade ajustada (1,4 m/s por 10 s = 14 m)', () {
      sim.setJoystick(1, 0);
      sim.advance(const Duration(seconds: 10));
      expect(metersBetween(kUnicamp.$1, kUnicamp.$2, sim.lat, sim.lon), closeTo(14.0, 0.01));
      expect(sim.lat, closeTo(kUnicamp.$1, 1e-9), reason: 'leste não muda a latitude');
      expect(sim.lon, greaterThan(kUnicamp.$2));
    });

    test('norte aumenta a latitude, sul diminui, oeste diminui a longitude', () {
      sim.setJoystick(0, 1);
      sim.advance(const Duration(seconds: 10));
      expect(sim.lat, greaterThan(kUnicamp.$1));
      sim.setJoystick(0, -1);
      sim.advance(const Duration(seconds: 20));
      expect(sim.lat, lessThan(kUnicamp.$1));
      final lat = sim.lat;
      sim.setJoystick(-1, 0);
      sim.advance(const Duration(seconds: 10));
      expect(sim.lat, closeTo(lat, 1e-9));
      expect(sim.lon, lessThan(kUnicamp.$2));
    });

    test('a velocidade ajustável vale: correndo e de bicicleta andam 3 e 6 m/s', () {
      for (final speed in SimSpeed.values) {
        final s = SimulatedPositionSource(lat: kUnicamp.$1, lon: kUnicamp.$2)..speedMps = speed.mps;
        s.setJoystick(0, 1);
        s.advance(const Duration(seconds: 10));
        expect(metersBetween(kUnicamp.$1, kUnicamp.$2, s.lat, s.lon), closeTo(speed.mps * 10, 0.01), reason: speed.label);
      }
    });

    test('meio joystick, meia velocidade; passar de 1 satura na velocidade ajustada, também na diagonal', () {
      sim.setJoystick(0.5, 0);
      sim.advance(const Duration(seconds: 10));
      expect(metersBetween(kUnicamp.$1, kUnicamp.$2, sim.lat, sim.lon), closeTo(7.0, 0.01));
      final s = SimulatedPositionSource(lat: kUnicamp.$1, lon: kUnicamp.$2);
      s.setJoystick(3, 4);
      expect(math.sqrt(s.joystickX * s.joystickX + s.joystickY * s.joystickY), closeTo(1, 1e-12));
      s.advance(const Duration(seconds: 10));
      expect(metersBetween(kUnicamp.$1, kUnicamp.$2, s.lat, s.lon), closeTo(14.0, 0.01));
    });

    test('soltar o joystick para o jogador; o resultado não depende do tamanho do passo de tempo', () {
      final a = SimulatedPositionSource(lat: kUnicamp.$1, lon: kUnicamp.$2)..setJoystick(1, 1);
      final b = SimulatedPositionSource(lat: kUnicamp.$1, lon: kUnicamp.$2)..setJoystick(1, 1);
      a.advance(const Duration(seconds: 10));
      for (var i = 0; i < 100; i++) {
        b.advance(const Duration(milliseconds: 100));
      }
      expect(a.lat, closeTo(b.lat, 1e-9));
      expect(a.lon, closeTo(b.lon, 1e-9));
      a.setJoystick(0, 0);
      final lat = a.lat;
      a.advance(const Duration(seconds: 5));
      expect(a.lat, lat);
    });
  });

  group('leituras', () {
    test('uma por segundo, com o tempo simulado andando e a precisão pedida', () async {
      sim.accuracyM = 8;
      sim.advance(const Duration(milliseconds: 3500));
      await pumpEventQueue();
      expect(got.map((f) => f.timeMs), [1001000, 1002000, 1003000]);
      expect(got.every((f) => f.accuracyM == 8), isTrue);
      sim.advance(const Duration(milliseconds: 500));
      await pumpEventQueue();
      expect(got, hasLength(4), reason: 'o resto de 0,5 s completa a quarta');
    });

    test('cada leitura informa a velocidade do joystick: 0 parado, e a ajustada com o joystick no máximo', () async {
      sim.advance(const Duration(seconds: 2));
      sim.setJoystick(1, 0);
      sim.advance(const Duration(seconds: 2));
      sim.setJoystick(0.5, 0);
      sim.speedMps = 6;
      sim.advance(const Duration(seconds: 2));
      await pumpEventQueue();
      expect(got.map((f) => f.speedMps), [0.0, 0.0, 1.4, 1.4, 3.0, 3.0]);
    });

    test('o intervalo entre leituras é configurável', () async {
      final fast = SimulatedPositionSource(lat: 0, lon: 0, fixInterval: const Duration(milliseconds: 250));
      final out = <GeoFix>[];
      fast.fixes.listen(out.add);
      await fast.start();
      await pumpEventQueue();
      out.clear();
      fast.advance(const Duration(seconds: 1));
      await pumpEventQueue();
      expect(out, hasLength(4));
      await fast.stop();
    });

    test('ao iniciar já emite uma leitura, e parada não emite nada', () async {
      final s = SimulatedPositionSource(lat: 1, lon: 2);
      final out = <GeoFix>[];
      s.fixes.listen(out.add);
      s.advance(const Duration(seconds: 3)); // não iniciada
      await pumpEventQueue();
      expect(out, isEmpty);
      await s.start();
      await pumpEventQueue();
      expect(out, hasLength(1));
      await s.stop();
      s.advance(const Duration(seconds: 3));
      await pumpEventQueue();
      expect(out, hasLength(1));
    });

    test('sem ruído a posição da leitura é a exata; com ruído de 5 m ela se espalha e é reproduzível', () async {
      sim.noiseM = 5;
      sim.advance(const Duration(seconds: 50));
      await pumpEventQueue();
      final errors = [for (final f in got) metersBetween(kUnicamp.$1, kUnicamp.$2, f.lat, f.lon)];
      final mean = errors.reduce((a, b) => a + b) / errors.length;
      expect(mean, inInclusiveRange(3.5, 8.5), reason: 'erro médio de ~6 m');
      final other = SimulatedPositionSource(lat: kUnicamp.$1, lon: kUnicamp.$2);
      final again = <GeoFix>[];
      other.fixes.listen(again.add);
      await other.start();
      await pumpEventQueue();
      again.clear();
      other.noiseM = 5;
      other.advance(const Duration(seconds: 50));
      await pumpEventQueue();
      expect([for (final f in again) f.lat], [for (final f in got) f.lat], reason: 'a mesma semente repete o ruído');
      await other.stop();
    });
  });

  group('teleporte', () {
    test('leva o jogador para a coordenada e emite uma leitura na hora', () async {
      sim.teleport(kCentroCampinas.$1, kCentroCampinas.$2);
      await pumpEventQueue();
      expect((sim.lat, sim.lon), kCentroCampinas);
      expect(got, hasLength(1));
      expect((got.single.lat, got.single.lon), kCentroCampinas);
    });

    test('depois do teleporte o joystick anda a partir do novo lugar', () {
      sim.teleport(kCentroCampinas.$1, kCentroCampinas.$2);
      sim.setJoystick(0, 1);
      sim.advance(const Duration(seconds: 10));
      expect(metersBetween(kCentroCampinas.$1, kCentroCampinas.$2, sim.lat, sim.lon), closeTo(14, 0.01));
    });

    test('o filtro de GPS trata o teleporte como salto e não arrasta o marcador', () async {
      final f = GpsFilter();
      for (final fix in [...got]) {
        f.add(fix);
      }
      sim.advance(const Duration(seconds: 20));
      await pumpEventQueue();
      for (final fix in [...got]) {
        f.add(fix);
      }
      got.clear();
      sim.teleport(kCentroCampinas.$1, kCentroCampinas.$2);
      await pumpEventQueue();
      expect(got.single.timeMs, greaterThan(1020000), reason: 'o tempo das leituras só cresce, mesmo no teleporte');
      final p = f.add(got.single)!;
      expect(metersBetween(p.lat, p.lon, kCentroCampinas.$1, kCentroCampinas.$2), lessThan(0.5));
    });
  });

  group('é uma fonte como outra qualquer', () {
    test('o simulador é uma PositionSource e o filtro acompanha o que ele anda (a 6 m/s, de bicicleta)', () async {
      expect(sim, isA<PositionSource>());
      sim.speedMps = SimSpeed.cycling.mps;
      sim.setJoystick(1, 0);
      final f = GpsFilter();
      sim.noiseM = 4;
      sim.advance(const Duration(seconds: 60));
      await pumpEventQueue();
      FilteredPosition? p;
      for (final fix in got) {
        p = f.add(fix);
      }
      // 60 s a 6 m/s = 360 m para o leste.
      expect(metersBetween(kUnicamp.$1, kUnicamp.$2, p!.lat, p.lon), closeTo(360, 25));
    });
  });

  group('DevTools: GPS real ou simulador', () {
    test('troca de fonte sem o jogo perceber, e o relógio é independente', () async {
      final real = SimulatedPositionSource(lat: 1, lon: 1); // qualquer fonte serve de "GPS real" no teste
      final tools = DevTools(realSource: real);
      expect(tools.useSimulator, isFalse);
      expect(tools.source.name, 'Simulador', reason: 'o "real" do teste também se chama Simulador');
      var notified = 0;
      tools.addListener(() => notified++);
      await tools.setUseSimulator(true);
      expect(tools.source.current, same(tools.simulator));
      expect(notified, 1);
      await tools.setUseSimulator(true);
      expect(notified, 1, reason: 'sem mudança não notifica');
      await tools.setUseSimulator(false);
      expect(tools.source.current, same(real));
      expect(tools.simulator.lat, kUnicamp.$1, reason: 'o simulador nasce na Unicamp');
      expect(tools.clock.overridden, isFalse);
    });
  });

  group('relógio UTC com override', () {
    test('sem override é o relógio real', () {
      var real = 1790000000000;
      final c = GameClock(realNowMs: () => real);
      expect(c.overridden, isFalse);
      expect(c.nowUtc, 1790000000);
      real += 5000;
      expect(c.nowUtc, 1790000005);
    });

    test('com override marca o instante pedido e continua andando a partir dele', () {
      var real = 1790000000000;
      final c = GameClock(realNowMs: () => real);
      var notified = 0;
      c.addListener(() => notified++);
      c.setUtc(1800000000);
      expect(c.overridden, isTrue);
      expect(c.nowUtc, 1800000000);
      real += 90000;
      expect(c.nowUtc, 1800000090, reason: 'continua andando: não congela');
      expect(c.now, DateTime.utc(2027, 1, 15, 8, 1, 30));
      expect(notified, 1);
    });

    test('clear volta ao relógio real, e clear sem override não notifica', () {
      var real = 1790000000000;
      final c = GameClock(realNowMs: () => real);
      var notified = 0;
      c.addListener(() => notified++);
      c.clear();
      expect(notified, 0);
      c.setUtc(1700000000);
      c.clear();
      expect(c.overridden, isFalse);
      expect(c.nowUtc, 1790000000);
      expect(notified, 2);
    });

    test('o relógio é sempre UTC, sem fuso', () {
      final c = GameClock(realNowMs: () => 0);
      expect(c.now.isUtc, isTrue);
      expect(c.now, DateTime.utc(1970));
    });
  });
}
