import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/world/geo_fix.dart';
import 'package:kenoma/world/position_source.dart';

/// Fonte de mentira: emite o que o teste mandar, só enquanto iniciada.
class FakeSource implements PositionSource {
  FakeSource(this.name);

  @override
  final String name;
  final _c = StreamController<GeoFix>.broadcast();
  bool started = false;
  int starts = 0, stops = 0;

  @override
  Stream<GeoFix> get fixes => _c.stream;

  void emit(double lat) {
    if (started) _c.add(GeoFix(lat: lat, lon: 0, accuracyM: 5, timeMs: 0));
  }

  @override
  Future<void> start() async {
    if (started) return;
    started = true;
    starts++;
  }

  @override
  Future<void> stop() async {
    started = false;
    stops++;
  }
}

void main() {
  test('encaminha as leituras da fonte atual, só depois de iniciada', () async {
    final a = FakeSource('A');
    final s = SwitchablePositionSource(a);
    final got = <double>[];
    s.fixes.listen((f) => got.add(f.lat));
    a.emit(1); // não iniciada: nada
    await s.start();
    a.emit(2);
    a.emit(3);
    await pumpEventQueue();
    expect(got, [2.0, 3.0]);
    expect(s.name, 'A');
  });

  test('trocar de fonte com o jogo rodando liga a nova, desliga a antiga e quem ouve não percebe', () async {
    final real = FakeSource('GPS'), sim = FakeSource('Simulador');
    final s = SwitchablePositionSource(real);
    final got = <(String, double)>[];
    s.fixes.listen((f) => got.add((s.name, f.lat)));
    await s.start();
    real.emit(10);
    await pumpEventQueue();
    await s.switchTo(sim);
    expect(real.started, isFalse);
    expect(sim.started, isTrue);
    real.emit(11); // a antiga não chega mais
    sim.emit(20);
    await pumpEventQueue();
    expect(got, [('GPS', 10.0), ('Simulador', 20.0)]);
    await s.switchTo(real);
    real.emit(12);
    await pumpEventQueue();
    expect(got.last, ('GPS', 12.0));
  });

  test('trocar com a fonte parada não liga nada; ligar depois liga só a escolhida', () async {
    final real = FakeSource('GPS'), sim = FakeSource('Simulador');
    final s = SwitchablePositionSource(real);
    await s.switchTo(sim);
    expect((real.starts, sim.starts), (0, 0));
    expect(s.current, same(sim));
    await s.start();
    expect((real.starts, sim.starts), (0, 1));
  });

  test('stop e start de novo (app em segundo plano e de volta) retomam a mesma fonte', () async {
    final a = FakeSource('A');
    final s = SwitchablePositionSource(a);
    final got = <double>[];
    s.fixes.listen((f) => got.add(f.lat));
    await s.start();
    a.emit(1);
    await pumpEventQueue();
    await s.stop();
    a.emit(2); // parada: nada
    await s.start();
    a.emit(3);
    await pumpEventQueue();
    expect(got, [1.0, 3.0]);
    expect((a.starts, a.stops), (2, 1));
  });

  test('start e stop repetidos são inofensivos, e trocar para a mesma fonte não faz nada', () async {
    final a = FakeSource('A');
    final s = SwitchablePositionSource(a);
    await s.start();
    await s.start();
    expect(a.starts, 1);
    await s.switchTo(a);
    expect((a.starts, a.stops), (1, 0));
    await s.stop();
    await s.stop();
    expect(a.stops, 1);
  });

  test('várias telas ouvem a mesma fonte', () async {
    final a = FakeSource('A');
    final s = SwitchablePositionSource(a);
    final x = <double>[], y = <double>[];
    s.fixes.listen((f) => x.add(f.lat));
    s.fixes.listen((f) => y.add(f.lat));
    await s.start();
    a.emit(7);
    await pumpEventQueue();
    expect(x, [7.0]);
    expect(y, [7.0]);
  });
}
