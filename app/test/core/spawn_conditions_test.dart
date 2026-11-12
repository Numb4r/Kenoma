import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/core/spawn.dart';
import 'package:kenoma/core/spawn_conditions.dart';

import '../support/fixtures.dart';

/// As nove famílias da fase 1 na época 11 (docs/GDD.md, "Famílias da fase 1"): cada uma no bioma, na hora, na lua, no
/// relevo e no clima dela. Conta os Ecos de 6.000 células com a seed dos vetores; o resultado é sempre o mesmo.
void main() {
  final data = loadGameData();
  final e11 = loadEpochs().epochs.firstWhere((e) => e.id == 11);
  final cond = e11.ecoV2!.conditions!;
  String? typeOf(String id) => data.species(id)?.type.name;

  const day = SpawnContext(sunAltDeg: 40, moonIllum: 0.3, rise: 0, climate: 'clear');
  const night = SpawnContext(sunAltDeg: -40, moonIllum: 0.3, rise: 0, climate: 'clear');
  const twilight = SpawnContext(sunAltDeg: 2, moonIllum: 0.3, rise: 0, climate: 'clear');
  SpawnContext at(SpawnContext c, {double? moon, double? rise, String? climate}) =>
      SpawnContext(sunAltDeg: c.sunAltDeg, moonIllum: moon ?? c.moonIllum, rise: rise ?? c.rise, climate: climate ?? c.climate);

  /// Quantos Ecos de cada família nascem no [biome] em [ctx] (item 0, o Eco comum), em 6.000 células.
  Map<String, int> count(String biome, SpawnContext ctx, {Epoch? epoch}) {
    final e = epoch ?? e11, out = <String, int>{};
    final mult = e.climate?.def(ctx.climate)?.spawn;
    for (var i = 0; i < 6000; i++) {
      final items = generateCell(seed: vectorSeed, epoch: e, cellX: 387000 + i % 80, cellY: 592000 + i ~/ 80, window: 1500000, biomeKey: biome, climateMult: mult == null || mult.isEmpty ? null : mult, typeOf: typeOf, context: epoch == null ? ctx : null);
      final eco = items.first;
      if (eco.exists) out[eco.entryId.split('.').first] = (out[eco.entryId.split('.').first] ?? 0) + 1;
    }
    return out;
  }

  int n(Map<String, int> m, String family) => m[family] ?? 0;

  test('a época 11 traz as condições de sete famílias; Rust e Bit dependem só do bioma e do clima', () {
    expect(cond.families.keys.toSet(), {'hum', 'clod', 'glare', 'shade', 'wisp', 'sprig', 'wyrm'});
    expect(loadEpochs().epochs.where((e) => e.id < 11).every((e) => e.ecoV2?.conditions == null), isTrue, reason: 'as épocas antigas não ganham condições');
    expect(e11.ecoV2!.behaviorWeights.keys.toSet(), {'passive', 'hidden'}, reason: 'só Passivo e Oculto');
  });

  test('nativas com peso 6: Residencial tem a Shade, Iluminado a Glare e a Bit, Sagrado a Wisp', () {
    Map<String, int> weights(String biome) => {for (final e in e11.items.first.table[biome]!) e.id.split('.').first: e.weight};
    expect(weights('residential')['shade'], 6);
    expect((weights('lit')['glare'], weights('lit')['bit']), (6, 6));
    expect(weights('sacred')['wisp'], 6);
    expect((weights('urban')['hum'], weights('urban')['rust'], weights('urban')['soot']), (6, 6, 6));
    expect((weights('green')['clod'], weights('green')['sprig'], weights('green')['frond']), (6, 6, 6));
    for (final biome in ['urban', 'green', 'water', 'residential', 'lit', 'sacred']) {
      expect(weights(biome).keys.toSet(), {'soot', 'frond', 'rill', 'hum', 'clod', 'rust', 'glare', 'shade', 'wisp', 'bit', 'sprig', 'wyrm'}, reason: 'toda família pode aparecer em $biome');
    }
  });

  test('Hum (Elétrico): Urbano, à noite; e na tempestade mais ainda', () {
    final byNight = count('urban', night), byDay = count('urban', day);
    expect(n(byNight, 'hum'), greaterThan(n(byDay, 'hum') * 3));
    expect(n(byNight, 'hum'), greaterThan(n(count('green', night), 'hum') * 2), reason: 'Urbano é o bioma dela');
    expect(n(count('urban', at(night, climate: 'storm')), 'hum'), greaterThan(n(byNight, 'hum')));
  });

  test('Clod (Terra): Verde e morros; na poeira seca mais ainda', () {
    final flat = count('green', day), hill = count('green', at(day, rise: 1));
    expect(n(hill, 'clod'), greaterThan(n(flat, 'clod') * 1.5));
    expect(n(count('urban', at(day, rise: 1)), 'clod'), greaterThan(n(count('urban', day), 'clod') * 2), reason: 'o morro pesa em qualquer bioma');
    expect(n(count('green', at(day, climate: 'dry_dust')), 'clod'), greaterThan(n(flat, 'clod')));
    expect(cond.mult('clod.eco', at(day, rise: -1)), 1, reason: 'o vale não muda o peso dela');
  });

  test('Rust (Metal): Urbano; na chuva ácida e no smog mais ainda', () {
    final clear = count('urban', day);
    expect(n(clear, 'rust'), greaterThan(n(count('green', day), 'rust') * 3));
    expect(n(count('urban', at(day, climate: 'acid_rain')), 'rust'), greaterThan(n(clear, 'rust') * 1.2));
    expect(n(count('urban', at(day, climate: 'smog')), 'rust'), greaterThan(n(clear, 'rust')));
  });

  test('Glare (Luz): Iluminado, de dia; sol forte e arco-íris; quase nada à noite', () {
    final byDay = count('lit', day), byNight = count('lit', night);
    expect(n(byDay, 'glare'), greaterThan(n(byNight, 'glare') * 8));
    expect(n(byDay, 'glare'), greaterThan(n(count('urban', day), 'glare') * 3));
    expect(n(count('lit', at(day, climate: 'strong_sun')), 'glare'), greaterThan(n(byDay, 'glare')));
    expect(n(count('lit', at(day, climate: 'rainbow')), 'glare'), greaterThan(n(byDay, 'glare')));
  });

  test('Shade (Sombra): Residencial, à noite; nublado e Sol Negro', () {
    final byNight = count('residential', night), byDay = count('residential', day);
    expect(n(byNight, 'shade'), greaterThan(n(byDay, 'shade') * 2));
    expect(n(count('residential', at(day, climate: 'cloudy')), 'shade'), greaterThan(n(byDay, 'shade')));
    expect(n(count('residential', at(day, climate: 'black_sun')), 'shade'), greaterThan(n(byDay, 'shade') * 1.5));
  });

  test('Wisp (Espectral): Sagrado; neblina e fundo de vale', () {
    final sacred = count('sacred', day);
    expect(n(sacred, 'wisp'), greaterThan(n(count('urban', day), 'wisp') * 3));
    expect(n(count('sacred', at(day, climate: 'fog')), 'wisp'), greaterThan(n(sacred, 'wisp')));
    expect(n(count('urban', at(day, climate: 'fog', rise: -1)), 'wisp'), greaterThan(n(count('urban', at(day, climate: 'fog')), 'wisp') * 1.5), reason: 'a neblina dos vales');
  });

  test('Bit (Digital): Iluminado; na Estática mais ainda', () {
    final lit = count('lit', night);
    expect(n(lit, 'bit'), greaterThan(n(count('green', night), 'bit') * 3));
    expect(n(count('lit', at(night, climate: 'static')), 'bit'), greaterThan(n(lit, 'bit')));
  });

  test('Sprig (Feérico): Verde no crepúsculo real; lua cheia, arco-íris e vento', () {
    final dusk = count('green', twilight), noon = count('green', day), midnight = count('green', night);
    expect(n(dusk, 'sprig'), greaterThan(n(noon, 'sprig') * 8));
    expect(n(dusk, 'sprig'), greaterThan(n(midnight, 'sprig') * 8));
    expect(n(count('green', at(twilight, moon: 0.97)), 'sprig'), greaterThan(n(dusk, 'sprig')));
    expect(n(count('green', at(twilight, climate: 'wind')), 'sprig'), greaterThan(n(dusk, 'sprig')));
    expect(n(count('green', at(twilight, climate: 'rainbow')), 'sprig'), greaterThan(n(dusk, 'sprig')));
    expect(n(dusk, 'sprig'), greaterThan(n(count('urban', twilight), 'sprig') * 2));
  });

  test('Wyrm (Dracônico): só em eclipses e chuva de meteoros, e só para o Conjurador de nível 10 em diante', () {
    for (final biome in ['urban', 'green', 'water', 'residential', 'lit', 'sacred']) {
      for (final ctx in [day, night, twilight, at(day, climate: 'storm'), at(night, moon: 1, rise: 1)]) {
        expect(n(count(biome, ctx), 'wyrm'), 0, reason: 'fora dos eclipses não nasce ($biome)');
      }
    }
    expect(n(count('urban', at(day, climate: 'black_sun')), 'wyrm'), greaterThan(0));
    expect(n(count('green', at(night, climate: 'crimson_rain')), 'wyrm'), greaterThan(0));
    expect(n(count('urban', at(night, climate: 'meteor_shower')), 'wyrm'), greaterThan(0));
    for (final id in ['wyrm.eco', 'wyrm.spirit']) {
      expect([for (var level = 1; level <= 12; level++) cond.visibleTo(id, level)], [...List.filled(9, false), true, true, true], reason: id);
    }
    expect(cond.visibleTo('hum.eco', 1) && cond.visibleTo('soot.eco', 1), isTrue);
  });

  test('o relevo entra aos poucos e a lua cheia começa em 90% da face', () {
    const clod = 'clod.eco', sprig = 'sprig.eco';
    expect(cond.mult(clod, day), 1);
    expect(cond.mult(clod, at(day, rise: 0.5)), closeTo(2, 1e-12));
    expect(cond.mult(clod, at(day, rise: 1)), closeTo(3, 1e-12));
    expect(cond.mult(sprig, at(twilight, moon: 0.89)), cond.mult(sprig, twilight));
    expect(cond.mult(sprig, at(twilight, moon: 0.9)), closeTo(cond.mult(sprig, twilight) * 2.5, 1e-12));
    expect(cond.mult('soot.eco', night), 1, reason: 'família sem condição');
    expect(cond.rise(1600 + 150 * 16, 8 * 1600), 1);
    expect(cond.rise(1600 - 75 * 16, 8 * 1600), -0.5);
  });

  test('as épocas antigas não mudam: sem condições, o mesmo sorteio com ou sem contexto; e as espécies novas não entram nelas', () {
    final e10 = loadEpochs().epochs.firstWhere((e) => e.id == 10);
    final families = count('urban', night, epoch: e10).keys.toSet();
    expect(families.difference({'soot', 'frond', 'rill'}), isEmpty);
    for (var i = 0; i < 200; i++) {
      final a = generateCell(seed: vectorSeed, epoch: e10, cellX: 387000 + i, cellY: 592000, window: 1500000, biomeKey: 'urban', typeOf: typeOf);
      final b = generateCell(seed: vectorSeed, epoch: e10, cellX: 387000 + i, cellY: 592000, window: 1500000, biomeKey: 'urban', typeOf: typeOf, context: night);
      expect([for (final x in a) (x.exists, x.entryId, x.px, x.py)], [for (final x in b) (x.exists, x.entryId, x.px, x.py)]);
    }
    // O Eco do raio: até a época 10 o tipo Elétrico não tem espécie (vale o fallback do dado); da 11 em diante é o Humoth.
    expect(data.ecoOfType('electric', 0.5), isNull);
    expect(data.ecoOfType('electric', 0.5, 10), isNull);
    expect(data.ecoOfType('electric', 0.5, 11), 'hum.eco');
    expect({for (var p = 0.0; p < 1; p += 0.01) data.ecoOfType('any', p, 10)}, {'soot.eco', 'frond.eco', 'rill.eco'});
    expect({for (var p = 0.0; p < 1; p += 0.01) data.ecoOfType('any', p, 11)}, hasLength(12));
    expect((data.ecoOfType('spectral', 0, 11), data.ecoOfType('fae', 0, 11), data.ecoOfType('draconic', 0, 11)), ('wisp.eco', 'sprig.eco', 'wyrm.eco'));
  });
}
