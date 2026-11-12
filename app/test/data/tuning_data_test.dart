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

  test('lê os doze Ecos com id, nome e tipo: os três do MVP primeiro, depois as nove famílias da fase 1', () {
    expect([for (final s in data.species) if (!s.isSpirit) (s.id, s.name, s.type)], [
      ('soot.eco', 'Sootling', EcoType.fire),
      ('frond.eco', 'Frondling', EcoType.plant),
      ('rill.eco', 'Rillet', EcoType.water),
      ('hum.eco', 'Humoth', EcoType.electric),
      ('clod.eco', 'Pebblet', EcoType.earth),
      ('rust.eco', 'Rustling', EcoType.metal),
      ('glare.eco', 'Glimlet', EcoType.light),
      ('shade.eco', 'Umbrel', EcoType.shadow),
      ('wisp.eco', 'Wisplet', EcoType.spectral),
      ('bit.eco', 'Bitling', EcoType.digital),
      ('sprig.eco', 'Sprigglet', EcoType.fae),
      ('wyrm.eco', 'Wyrmlet', EcoType.draconic),
    ]);
    // As da fase 1 só existem para o mundo da época 11 em diante; as do MVP, desde sempre.
    expect({for (final s in data.species) if (s.sinceEpoch != 0) s.family}, {'hum', 'clod', 'rust', 'glare', 'shade', 'wisp', 'bit', 'sprig', 'wyrm'});
    expect(data.species.where((s) => s.sinceEpoch != 0).every((s) => s.sinceEpoch == 11), isTrue);
  });

  test('lê os Espíritos: um por família que a fusão forma e, nas três do MVP, um só de ritual', () {
    expect([for (final s in data.species) if (s.isSpirit && s.sinceEpoch == 0) (s.id, s.family, s.ritualOnly)], [
      ('soot.spirit', 'soot', false),
      ('frond.spirit', 'frond', false),
      ('rill.spirit', 'rill', false),
      ('soot.ritual', 'soot', true),
      ('frond.ritual', 'frond', true),
      ('rill.ritual', 'rill', true),
    ]);
    expect(data.species.firstWhere((s) => s.id == 'soot.spirit').ability!.bands, [5, 8, 11], reason: 'um degrau acima do Eco (3, 5, 8)');
    expect([for (final s in data.species) if (s.isSpirit && s.sinceEpoch != 0) (s.id, s.name)], [
      ('hum.spirit', 'Coilkin'), ('clod.spirit', 'Bouldkin'), ('rust.spirit', 'Gratekin'), ('glare.spirit', 'Prismkin'), ('shade.spirit', 'Shadekin'),
      ('wisp.spirit', 'Hollowkin'), ('bit.spirit', 'Glitchkin'), ('sprig.spirit', 'Fairkin'), ('wyrm.spirit', 'Wyrmkin'),
    ]);
  });

  test('lê os selos (simples, reforçado e um de cada um dos 12 tipos) e o tônico', () {
    expect(data.seals.map((s) => s.id).toSet(), {'item.seal.simple', 'item.seal.reinforced', for (final t in EcoType.values) 'item.seal.${t.name}'});
    expect({for (final s in data.seals) if (s.type != null) s.type}, EcoType.values.toSet());
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
