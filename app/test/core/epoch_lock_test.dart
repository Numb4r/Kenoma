import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/spawn.dart';
import 'package:kenoma/core/weather.dart';

import '../support/fixtures.dart';

/// Impressão digital completa (inclusive o fluxo v2: comportamento, variante, Brilhante e a espécie depois do clima) de
/// 400 células em 3 janelas e 4 biomas.
int fullFingerprint(Epoch e, Weather weather) {
  final seed = seedGlobal('KENOMA-TESTE');
  final parts = <int>[];
  for (var cx = 387200; cx < 387220; cx++) {
    for (var cy = 592850; cy < 592870; cy++) {
      for (final w in [1491667, 1491668, 1491700]) {
        for (final biome in ['urban', 'green', 'water', 'residential']) {
          for (final it in generateCell(seed: seed, epoch: e, cellX: cx, cellY: cy, window: w, biomeKey: biome, weather: weather, typeOf: _typeOf)) {
            parts.addAll([
              it.index, it.exists ? 1 : 0, fnv1a64Bytes(utf8.encode(it.entryId)), it.quantity, it.levelDelta ?? -99,
              (it.px * 1e6).round(), (it.py * 1e6).round(), it.uid, it.behaviorDraw, fnv1a64Bytes(utf8.encode(it.variantBiome ?? '-')), it.shiny ? 1 : 0,
            ]);
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

  test('épocas 3 a 5 geram exatamente o mesmo de antes do clima completo, com cada um dos quatro climas (travadas)', () {
    final got = {
      for (final id in [3, 4, 5])
        id: [for (final w in Weather.values) fullFingerprint(schedule.epochs.firstWhere((e) => e.id == id), w)],
    };
    expect(got, _locked);
  });

  test('as épocas 0 a 5 não têm o bloco do clima completo; a 6 tem', () {
    for (final e in schedule.epochs) {
      expect(e.climate != null, e.id >= 6, reason: 'época ${e.id}');
    }
  });
}

/// Valores tirados com o `spawn.dart` de antes do clima completo (0.15.1) e conferidos de novo depois da mudança. Na
/// 0.20.0 Arisco e Agressivo saíram do jogo: o sorteio é o mesmo (`behaviorDraw`), só o que ele vale mudou.
const _locked = <int, List<int>>{
  3: [5207940006108082115, 5207940006108082115, 5018513371915077700, 8133888879088649275],
  4: [2946721170008908634, 2946721170008908634, 6102919310607052129, 7025128431824203446],
  5: [57940976763546005, 57940976763546005, -6424626649578882263, -5870231655988321346],
};
