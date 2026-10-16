import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/behavior.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/spawn.dart';
import 'package:kenoma/core/weather.dart';

import '../support/fixtures.dart';

/// Impressão digital dos itens (sem o que o fluxo v2 acrescenta) de 400 células em 3 janelas e 4 biomas.
int fingerprint(Epoch e, {Weather weather = Weather.clear}) {
  final seed = seedGlobal('KENOMA-TESTE');
  final parts = <int>[];
  for (var cx = 387200; cx < 387220; cx++) {
    for (var cy = 592850; cy < 592870; cy++) {
      for (final w in [1491667, 1491668, 1491700]) {
        for (final biome in ['urban', 'green', 'water', 'residential']) {
          for (final it in generateCell(seed: seed, epoch: e, cellX: cx, cellY: cy, window: w, biomeKey: biome, weather: weather, typeOf: _typeOf)) {
            parts.addAll([it.index, it.exists ? 1 : 0, fnv1a64Bytes(utf8.encode(it.entryId)), it.quantity, it.levelDelta ?? -99, (it.px * 1e6).round(), (it.py * 1e6).round(), it.uid]);
          }
        }
      }
    }
  }
  return fnv1a64(parts);
}

String? _typeOf(String id) => switch (id) {
      'soot.eco' => 'fire',
      'frond.eco' => 'plant',
      'rill.eco' => 'water',
      _ => null,
    };

void main() {
  final schedule = loadEpochs();
  final e0 = schedule.epochs.firstWhere((e) => e.id == 0);
  final e1 = schedule.epochs.firstWhere((e) => e.id == 1);
  final e2 = schedule.epochs.firstWhere((e) => e.id == 2);
  final seed = seedGlobal('KENOMA-TESTE');

  group('o que já existe não muda', () {
    test('épocas 0 e 1: os itens de uma célula são idênticos aos da 0.13.0 (impressões digitais travadas)', () {
      expect(fingerprint(e0), 9104614648277001924);
      expect(fingerprint(e1), -7119576224363917910);
    });

    test('épocas 0 e 1 não têm o fluxo v2: todo Eco é passivo, sem variante nem Brilhante, com qualquer clima', () {
      expect(e0.ecoV2, isNull);
      expect(e1.ecoV2, isNull);
      for (final w in Weather.values) {
        expect(fingerprint(e1, weather: w), -7119576224363917910, reason: 'o clima não pesa em época sem v2');
      }
      for (final it in generateCell(seed: seed, epoch: e1, cellX: 387210, cellY: 592860, window: 1491667, biomeKey: 'urban')) {
        expect((it.behavior, it.variantBiome, it.shiny), (EcoBehavior.passive, null, false));
      }
    });

    test('na época 2 com tempo limpo, existência, espécie, nível, quantidade, posição e uid saem iguais aos da época 1', () {
      // Só o número da época entra no hash, então comparar com a época 1 exige o mesmo id: troca-se só o fluxo v2 ligado.
      final plain = Epoch(id: e2.id, startsUtc: e2.startsUtc, validUntilUtc: e2.validUntilUtc, regionPacks: e2.regionPacks, items: e2.items);
      expect(fingerprint(e2), fingerprint(plain), reason: 'o fluxo v2 não mexe nos sorteios originais');
    });
  });

  group('fluxo v2 da época 2', () {
    List<SpawnItem> ecos({String biome = 'green', int n = 4000, Weather weather = Weather.clear}) => [
          for (var i = 0; i < n; i++)
            generateCell(seed: seed, epoch: e2, cellX: 387000 + i % 100, cellY: 592000 + i ~/ 100, window: 1491667 + i % 7, biomeKey: biome, weather: weather, typeOf: _typeOf).first,
        ];

    test('é determinístico: a mesma célula dá o mesmo comportamento, variante e Brilhante', () {
      for (var i = 0; i < 50; i++) {
        final a = generateCell(seed: seed, epoch: e2, cellX: 387000 + i, cellY: 592000, window: 1491667, biomeKey: 'urban').first;
        final b = generateCell(seed: seed, epoch: e2, cellX: 387000 + i, cellY: 592000, window: 1491667, biomeKey: 'urban').first;
        expect((a.behavior, a.variantBiome, a.shiny, a.entryId), (b.behavior, b.variantBiome, b.shiny, b.entryId));
      }
    });

    test('só o item Eco ganha comportamento; Fagulhas e materiais saem como antes', () {
      for (final it in generateCell(seed: seed, epoch: e2, cellX: 387210, cellY: 592860, window: 1491667, biomeKey: 'urban').skip(1)) {
        expect((it.behavior, it.variantBiome, it.shiny), (EcoBehavior.passive, null, false));
      }
    });

    test('os comportamentos seguem os pesos da época: maioria passivo, e os outros três aparecem', () {
      final all = ecos();
      final counts = {for (final b in EcoBehavior.values) b: all.where((i) => i.behavior == b).length};
      final w = e2.ecoV2!.behaviorWeights;
      final total = w.values.fold(0, (a, b) => a + b);
      for (final b in EcoBehavior.values) {
        expect(counts[b]! / all.length, closeTo(w[b.id]! / total, 0.03), reason: b.id);
      }
      expect(counts[EcoBehavior.passive]!, greaterThan(counts[EcoBehavior.skittish]! * 3));
    });

    test('a variante carrega o bioma da célula, na chance da época; a Brilhante é raríssima e vale em qualquer bioma', () {
      for (final biome in ['urban', 'green', 'water', 'residential']) {
        final all = ecos(biome: biome, n: 6000);
        final variants = all.where((i) => i.variantBiome != null);
        expect(variants.length / all.length, closeTo(e2.ecoV2!.variantChance, 0.025), reason: biome);
        expect(variants.every((i) => i.variantBiome == biome), isTrue, reason: 'a variante é do bioma da célula');
      }
      final big = [for (final b in ['urban', 'green', 'water', 'residential']) ...ecos(biome: b, n: 20000)];
      final shinies = big.where((i) => i.shiny).length;
      expect(e2.ecoV2!.shinyChance, 1 / 400);
      expect(shinies / big.length, closeTo(1 / 400, 0.0015));
      expect(shinies, greaterThan(0));
    });

    test('variante e Brilhante são sorteios independentes dos outros: o mesmo Eco pode ser as duas coisas, e nenhum afeta a espécie', () {
      final all = ecos(n: 20000);
      final plain = all.where((i) => i.variantBiome == null && !i.shiny).map((i) => i.entryId).toList();
      final vars = all.where((i) => i.variantBiome != null).map((i) => i.entryId).toList();
      double share(List<String> l, String id) => l.where((x) => x == id).length / l.length;
      expect(share(vars, 'frond.eco'), closeTo(share(plain, 'frond.eco'), 0.06));
    });
  });

  group('clima determinístico', () {
    final model = e2.ecoV2!.weather;
    const t0 = 1790040000;

    test('o mesmo aparelho ou outro, com a mesma seed, janela e região, vê o mesmo clima', () {
      final other = WeatherModel.fromJson(jsonDecode(jsonEncode((epochsJson()['epochs'] as List).last['eco_v2']['weather'])) as Map<String, dynamic>);
      for (var i = 0; i < 200; i++) {
        final t = t0 + i * 3607;
        expect(model.at(seed: seed, tUtc: t, regionX: 1512, regionY: 2315), other.at(seed: seed, tUtc: t, regionX: 1512, regionY: 2315));
      }
    });

    test('dentro de uma janela de 3 horas o clima não muda; entre regiões e janelas ele varia', () {
      final w = (t0 ~/ 10800) * 10800;
      final first = model.at(seed: seed, tUtc: w, regionX: 1, regionY: 1);
      for (var s = 0; s < 10800; s += 997) {
        expect(model.at(seed: seed, tUtc: w + s, regionX: 1, regionY: 1), first);
      }
      final seen = {for (var i = 0; i < 300; i++) model.at(seed: seed, tUtc: t0 + i * 10800, regionX: i, regionY: 7)};
      expect(seen.length, 4, reason: 'os quatro climas aparecem');
    });

    test('a região é o tile z12 da célula z20', () {
      expect(weatherRegionOfCell(387213, 592857), (1512, 2315));
      expect(weatherRegionOfCell(255, 256), (0, 1));
    });

    test('a probabilidade segue a estação: chove bem mais no verão que no inverno', () {
      double rainShare(int month) {
        var wet = 0;
        const n = 4000;
        final t = DateTime.utc(2026, month, 15).millisecondsSinceEpoch ~/ 1000;
        for (var i = 0; i < n; i++) {
          if (model.at(seed: seed, tUtc: t + (i % 8) * 10800, regionX: i, regionY: i ~/ 8).wet) wet++;
        }
        return wet / n;
      }

      expect(rainShare(1), closeTo(0.45, 0.04), reason: 'verão: 32% chuva + 13% tempestade');
      expect(rainShare(7), closeTo(0.08, 0.03), reason: 'inverno: 7% + 1%');
      expect(rainShare(1), greaterThan(rainShare(7) * 4));
      expect(seasonOfMonth(12), 'summer');
      expect(seasonOfMonth(6), 'winter');
    });

    test('com chuva sai mais Água e menos Fogo; tempo limpo deixa a espécie original', () {
      Map<String, int> species(Weather w) {
        final m = <String, int>{};
        for (var i = 0; i < 12000; i++) {
          final it = generateCell(seed: seed, epoch: e2, cellX: 387000 + i % 120, cellY: 592000 + i ~/ 120, window: 1491667, biomeKey: 'green', weather: w, typeOf: _typeOf).first;
          m[it.entryId] = (m[it.entryId] ?? 0) + 1;
        }
        return m;
      }

      final clear = species(Weather.clear), rain = species(Weather.rain), storm = species(Weather.storm);
      expect(rain['rill.eco']!, greaterThan(clear['rill.eco']!));
      expect(rain['soot.eco']!, lessThan(clear['soot.eco']!));
      expect(storm['soot.eco']!, lessThan(rain['soot.eco']!));
      // Com tempo limpo é a espécie do fluxo original.
      final original = Epoch(id: e2.id, startsUtc: e2.startsUtc, validUntilUtc: e2.validUntilUtc, regionPacks: e2.regionPacks, items: e2.items);
      for (var i = 0; i < 300; i++) {
        final a = generateCell(seed: seed, epoch: e2, cellX: 387000 + i, cellY: 592100, window: 1491667, biomeKey: 'green', typeOf: _typeOf).first;
        final b = generateCell(seed: seed, epoch: original, cellX: 387000 + i, cellY: 592100, window: 1491667, biomeKey: 'green').first;
        expect(a.entryId, b.entryId);
      }
    });

    test('o clima não muda existência, nível, quantidade nem posição, só a espécie do Eco', () {
      for (var i = 0; i < 200; i++) {
        final clear = generateCell(seed: seed, epoch: e2, cellX: 387000 + i, cellY: 592200, window: 1491667, biomeKey: 'urban', typeOf: _typeOf);
        final rain = generateCell(seed: seed, epoch: e2, cellX: 387000 + i, cellY: 592200, window: 1491667, biomeKey: 'urban', weather: Weather.rain, typeOf: _typeOf);
        for (var k = 0; k < 4; k++) {
          expect((clear[k].exists, clear[k].quantity, clear[k].levelDelta, clear[k].px, clear[k].py, clear[k].uid), (rain[k].exists, rain[k].quantity, rain[k].levelDelta, rain[k].px, rain[k].py, rain[k].uid));
          if (k > 0) expect(clear[k].entryId, rain[k].entryId);
        }
      }
    });
  });
}
