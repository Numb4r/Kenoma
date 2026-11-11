import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/data/traffic_pack.dart';
import 'package:kenoma/world/sim/birds.dart';

const mpc = 17.6;

void main() {
  final squares = TrafficPack.of([
    (kind: TrafficPointKind.square, x: 1000.0, y: 2000.0),
    (kind: TrafficPointKind.square, x: 1008.0, y: 2000.0),
    (kind: TrafficPointKind.shop, x: 1002.0, y: 2002.0),
  ]);
  bool nowhere(double x, double y) => false;

  test('cada praça perto tem um bando ciscando no chão', () {
    final b = BirdFlocks(points: squares);
    b.update(0.1, 1004, 2004, mpc, nowhere);
    expect(b.flocks.length, 2, reason: 'só nas praças');
    for (final f in b.flocks.values) {
      expect(f.birds.length, inInclusiveRange(4, 8));
      expect(f.birds.every((p) => !p.flying && p.height == 0), isTrue);
    }
    final before = [for (final f in b.flocks.values) for (final p in f.birds) (p.x, p.y)];
    for (var i = 0; i < 600; i++) {
      b.update(0.1, 1004, 2004, mpc, nowhere);
    }
    final after = [for (final f in b.flocks.values) for (final p in f.birds) (p.x, p.y)];
    expect(after, isNot(before), reason: 'ciscam: dão pulinhos');
    expect(b.takeoffs, 0, reason: 'com o avatar longe ninguém voa');
    for (final f in b.flocks.values) {
      for (final p in f.birds) {
        expect(((p.x - f.x) * mpc).abs(), lessThan(5));
      }
    }
  });

  test('o avatar chega perto: o bando levanta voo e pousa adiante, longe dele', () {
    final b = BirdFlocks(points: squares);
    b.update(0.1, 1004, 2004, mpc, nowhere);
    final flock = b.flocks.values.first;
    final x0 = flock.x, y0 = flock.y;
    b.update(0.1, x0, y0, mpc, nowhere); // o avatar no meio do bando
    expect(b.takeoffs, 1);
    expect(flock.birds.every((p) => p.flying), isTrue);
    var top = 0.0;
    var prev = [for (final p in flock.birds) (p.x, p.y)];
    for (var i = 0; i < 40; i++) {
      b.update(0.1, x0, y0, mpc, nowhere);
      for (final (k, p) in flock.birds.indexed) {
        top = math.max(top, p.height);
        expect(math.sqrt(math.pow((p.x - prev[k].$1) * mpc, 2) + math.pow((p.y - prev[k].$2) * mpc, 2)), lessThan(2.5), reason: 'voa, não pula de lugar');
      }
      prev = [for (final p in flock.birds) (p.x, p.y)];
    }
    expect(top, greaterThan(0.9));
    expect(flock.birds.every((p) => !p.flying && p.height == 0), isTrue, reason: 'pousaram');
    final d = math.sqrt(math.pow((flock.x - x0) * mpc, 2) + math.pow((flock.y - y0) * mpc, 2));
    expect(d, inInclusiveRange(9, 18), reason: 'uns 13 m adiante');
    expect(b.takeoffs, 1, reason: 'longe do avatar, não espantam de novo');
  });

  test('bando não nasce na vista; o que ficou longe some fora dela', () {
    final b = BirdFlocks(points: squares);
    b.update(0.1, 5000, 5000, mpc, nowhere); // longe das praças
    expect(b.flocks, isEmpty);
    b.update(0.1, 1004, 2004, mpc, (x, y) => true); // chegou de teleporte com as praças já na tela
    expect(b.flocks, isEmpty, reason: 'nada surge na tela');
    b.update(0.1, 1004, 2004, mpc, (x, y) => x > 1004); // uma praça fora da vista
    expect(b.flocks.length, 1);
    b.update(0.1, 9000, 9000, mpc, nowhere);
    expect(b.flocks, isEmpty);
  });
}
