import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/relief_pack.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/climate_world.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/world/visual_map.dart';
import 'package:kenoma/world/walk_paths.dart';
import 'package:kenoma/world/water_field.dart';

import '../support/fixtures.dart';

/// 0.20.3: a água do relevo na chuva forçada pelo debug, com o cálculo fora da thread do desenho (como no mapa do jogo):
/// o bloco começa seco, o tile fica pronto, quem desenha é avisado e as poças aparecem; no Dilúvio, o vale alaga.
void main() {
  final seed = seedGlobal('KENOMA-TESTE');
  final data = loadGameData();
  final schedule = loadEpochs();
  final visual = VisualMap(VisualPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync())), cacheTiles: 64);
  final relief = ReliefPack.parse(File('assets/regions/campinas_e9_relief.bin').readAsBytesSync());
  final t = DateTime.utc(2026, 11, 13, 16).millisecondsSinceEpoch ~/ 1000;

  ({ClimateWorld world, WaterField field}) device(String forced, {required bool background}) {
    final fields = <int, WaterField>{};
    WaterField? waterOf(e) => e.water == null ? null : fields[e.id] ??= (WaterField(relief: relief, visual: visual, model: e.water!)..background = background);
    final w = ClimateWorld(
      seed: seed,
      schedule: schedule,
      speciesOfType: data.ecoOfType,
      itemExists: data.itemNames.containsKey,
      snapper: WalkPaths(visual),
      relief: relief,
      water: waterOf,
      typeOf: (id) => data.species(id)?.type.name,
      forced: () => forced,
      // Chovendo há 3 horas de clima (a "velocidade do clima" do debug faz isto em minutos).
      forcedPhase: () => (ageS: 3 * 3600.0, prevId: null, prevFormedS: 0, prevSinceEndS: 0),
    );
    return (world: w, field: waterOf(schedule.select(t).epoch)!);
  }

  for (final (name, place) in [('Taquaral', kTaquaral), ('Centro', kCentroCampinas)]) {
    test('chuva forçada em $name: o bloco começa seco, o tile fica pronto, o desenho é avisado e as poças são as do cálculo na hora', () async {
      final (x21, y21) = latLonToTileFraction(place.$1, place.$2, 21);
      final r21 = 300 / metersPerCell(place.$1);
      final bg = device('rain', background: true);
      var told = 0;
      bg.field.onTile = () => told++;
      expect(bg.world.puddlesNear(x21, y21, r21, t), isEmpty, reason: 'o tile ainda está a caminho');
      expect(bg.field.pendingAt(x21.floor() >>> 6, y21.floor() >>> 6), isTrue);
      await bg.field.settled;
      expect(bg.field.revision, greaterThan(0));
      expect(told, bg.field.revision, reason: 'cada tile que chega avisa quem desenha');
      final after = bg.world.puddlesNear(x21, y21, r21, t);
      expect(after, isNotEmpty, reason: 'com o tile pronto, a água do relevo forma poças');
      expect(after.every((p) => p.size == 1 && p.wet), isTrue);
      final now = device('rain', background: false).world.puddlesNear(x21, y21, r21, t);
      String key(Puddle p) => '${p.x}|${p.y}|${p.radiusM}|${p.rolls.uid}';
      expect([for (final p in after) key(p)], [for (final p in now) key(p)], reason: 'em fundo ou na hora, as mesmas poças');
    });
  }

  test('Dilúvio forçado no vale da Norte-Sul: o campo alaga depois que o tile fica pronto', () async {
    const ns = (-22.9095, -47.0560); // a Norte-Sul perto da Orosimbo Maia, o fundo do vale
    final (x21, y21) = latLonToTileFraction(ns.$1, ns.$2, 21);
    final bg = device('deluge', background: true);
    final (cx, cy) = (x21.floor(), y21.floor());
    expect(bg.field.floodAt(cx, cy), 0, reason: 'a caminho: seco');
    await bg.field.settled;
    var wet = 0;
    for (var y = cy - 40; y <= cy + 40; y++) {
      for (var x = cx - 40; x <= cx + 40; x++) {
        if ((bg.field.floodAt(x, y) ?? 0) > 0.5) wet++;
      }
    }
    expect(wet, greaterThan(0), reason: 'células alagadas perto do fundo do vale');
  });
}
