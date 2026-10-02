import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/world/geo_fix.dart';
import 'package:kenoma/world/player_tracker.dart';
import 'package:kenoma/world/position_source.dart';

class FakeSource implements PositionSource {
  @override
  String get name => 'Fake';
  final c = StreamController<GeoFix>.broadcast();
  bool started = false;

  @override
  Stream<GeoFix> get fixes => c.stream;

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async => started = false;

  void emit(double lat, double lon, double acc, int t) => c.add(GeoFix(lat: lat, lon: lon, accuracyM: acc, timeMs: t));
}

void main() {
  test('começa procurando, sem posição', () async {
    final t = PlayerTracker(source: FakeSource());
    expect(t.state.status, TrackingStatus.searching);
    expect(t.state.position, isNull);
    await t.dispose();
  });

  test('a primeira leitura boa vira a posição e o estado passa a "seguindo"', () async {
    final s = FakeSource();
    final t = PlayerTracker(source: s);
    await t.start();
    expect(s.started, isTrue);
    s.emit(-22.8, -47.0, 6, 1000);
    await pumpEventQueue();
    expect(t.state.status, TrackingStatus.tracking);
    expect(t.state.position!.lat, closeTo(-22.8, 1e-9));
    expect(t.state.lastRaw!.accuracyM, 6);
    await t.dispose();
  });

  test('só leituras piores que 50 m: sem posição e "precisão ruim", com a contagem', () async {
    final s = FakeSource();
    final t = PlayerTracker(source: s);
    await t.start();
    s.emit(-22.8, -47.0, 120, 1000);
    s.emit(-22.8, -47.0, 80, 2000);
    await pumpEventQueue();
    expect(t.state.status, TrackingStatus.poorAccuracy);
    expect(t.state.position, isNull);
    expect(t.state.rejected, 2);
    expect(t.state.lastRaw!.accuracyM, 80);
    s.emit(-22.8, -47.0, 15, 3000);
    await pumpEventQueue();
    expect(t.state.status, TrackingStatus.tracking, reason: 'melhorou: passa a seguir');
    expect(t.state.position, isNotNull);
    await t.dispose();
  });

  test('uma leitura ruim no meio de leituras boas não tira o estado de "seguindo" nem a posição', () async {
    final s = FakeSource();
    final t = PlayerTracker(source: s);
    await t.start();
    s.emit(-22.8, -47.0, 5, 1000);
    s.emit(-22.8, -47.0, 90, 2000);
    await pumpEventQueue();
    expect(t.state.status, TrackingStatus.tracking);
    expect(t.state.position, isNotNull);
    expect(t.state.rejected, 1);
    await t.dispose();
  });

  test('cada leitura gera um estado no fluxo', () async {
    final s = FakeSource();
    final t = PlayerTracker(source: s);
    final seen = <TrackingStatus>[];
    t.states.listen((e) => seen.add(e.status));
    await t.start();
    s.emit(-22.8, -47.0, 100, 1000);
    s.emit(-22.8, -47.0, 5, 2000);
    await pumpEventQueue();
    expect(seen, [TrackingStatus.poorAccuracy, TrackingStatus.tracking]);
    await t.dispose();
  });

  test('stop para a fonte e start retoma, sem perder a posição', () async {
    final s = FakeSource();
    final t = PlayerTracker(source: s);
    await t.start();
    s.emit(-22.8, -47.0, 5, 1000);
    await pumpEventQueue();
    await t.stop();
    expect(s.started, isFalse);
    expect(t.state.position, isNotNull);
    await t.start();
    expect(s.started, isTrue);
    await t.dispose();
  });

  test('reset esquece a posição: a fonte trocou e a próxima leitura recomeça', () async {
    final s = FakeSource();
    final t = PlayerTracker(source: s);
    await t.start();
    s.emit(-22.8, -47.0, 5, 1000);
    await pumpEventQueue();
    t.reset();
    expect(t.state.position, isNull);
    expect(t.state.status, TrackingStatus.searching);
    s.emit(-22.9, -47.1, 5, 2000);
    await pumpEventQueue();
    expect(t.state.position!.lat, closeTo(-22.9, 1e-9), reason: 'recomeçou na nova leitura, sem arrastar da antiga');
    await t.dispose();
  });
}
