import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/tuning_setup.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/pcg32.dart';
import 'package:kenoma/data/balance_version.dart';
import 'package:kenoma/data/tuning_data.dart';

import '../support/fixtures.dart';

TuningData load() => TuningData.fromJson(
      balance: loadJson('assets/data/balance.json'),
      creatures: loadJson('assets/data/creatures.json'),
      items: loadJson('assets/data/items.json'),
      balanceVersion: balanceVersionOf(File('assets/data/balance.json').readAsBytesSync()),
    );

void main() {
  final data = load();

  test('lê os três Ecos com id, nome e tipo', () {
    expect([for (final s in data.species) (s.id, s.name, s.type)], [
      ('soot.eco', 'Sootling', EcoType.fire),
      ('frond.eco', 'Frondling', EcoType.plant),
      ('rill.eco', 'Rillet', EcoType.water),
    ]);
  });

  test('lê os cinco selos e o tônico', () {
    expect(data.seals.map((s) => s.id), [
      'item.seal.simple',
      'item.seal.reinforced',
      'item.seal.fire',
      'item.seal.plant',
      'item.seal.water',
    ]);
    expect(data.tonics.single.extraTimeS, 5);
  });

  group('TuningSetup', () {
    final seal = data.seals.first;

    TuningSetup setup({int player = 1, int eco = 1, bool tonic = false}) => TuningSetup(
        type: EcoType.fire,
        ecoLevel: eco,
        playerLevel: player,
        seal: seal,
        tonic: tonic ? data.tonics.first : null);

    test('tempo: 20 s, ou 25 s com tônico', () {
      expect(setup().timeLimitS(data.balance), 20);
      expect(setup(tonic: true).timeLimitS(data.balance), 25);
    });

    test('intensidade e tolerância vêm dos níveis e do selo', () {
      expect(setup().intensity(data.balance), 0);
      expect(setup(player: 15, eco: 17).intensity(data.balance), closeTo(0.81, 1e-12));
      expect(setup().tolerance(data.balance), 0.08);
    });

    test('mesma semente, mesma sintonia; a sessão nasce em andamento com o dial no meio', () {
      final a = setup(player: 15, eco: 15).start(data.balance, Pcg32(fnv1a64([7]), saltKenoma));
      final b = setup(player: 15, eco: 15).start(data.balance, Pcg32(fnv1a64([7]), saltKenoma));
      expect([for (var t = 0.0; t < 20; t += 0.5) a.signal.frequencyAt(t)], [for (var t = 0.0; t < 20; t += 0.5) b.signal.frequencyAt(t)]);
      expect(a.running, isTrue);
      expect(a.dial, 0.5);
      expect(a.timeLimitS, 20);
      expect(a.baseTolerance, 0.08);
    });
  });
}
