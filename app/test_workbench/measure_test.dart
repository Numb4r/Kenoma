// Mede para o workbench (aba Números): Ecos por faixa de nível do Conjurador e poças do Rill por célula z18. Fica fora de
// `test/`. Uso: cd app && flutter test test_workbench/measure_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/species_ids.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/player/personal_build.dart';
import 'package:kenoma/world/climate_world.dart';
import 'package:kenoma/world/personal_layer.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/visual_map.dart';
import 'package:kenoma/world/walk_paths.dart';
import 'package:kenoma/world/world_view.dart';

import '../test/support/fixtures.dart';

void main() {
  test('números do workbench', () {
    final data = loadGameData(), schedule = loadEpochs(), seed = seedGlobal('KENOMA-TESTE');
    final map = RegionMap(pack: loadCampinasPack(), biomes: loadBiomes());
    const lat = -22.9056, lon = -47.0608; // Centro
    final t0 = DateTime.utc(2026, 11, 20, 15).millisecondsSinceEpoch ~/ 1000; // época 11, meio-dia
    final tables = <Map<String, Object>>[];

    // Ecos à vista (120 m) numa hora (três janelas de 20 min), pela faixa de nível: o que o Conjurador vê.
    final rows = <List<String>>[];
    for (final level in [1, 5, 8, 10, 15, 20]) {
      final s = GameState.fresh(groupCode: 'KENOMA-TESTE', startInventory: const {}, balance: data.progress)..levelOverride = level;
      final v = WorldView(field: SpawnField(seed: seed, schedule: schedule, map: map, typeOf: (id) => data.species(id)?.type.name, levelCapOf: data.progress.levelCapFor), state: s, auraM: 0, viewM: 120, itemName: (i) => i, street: loadStreetBalance());
      final seen = <int, String>{};
      for (var k = 0; k < 3; k++) {
        v.refresh(lat: lat, lon: lon, tUtc: t0 + k * 1200);
        for (final e in v.allEcos) {
          seen[e.uid] = e.entryId;
        }
      }
      final spirits = seen.values.where((id) => tierOfId(id) == SpeciesTier.spirit).length;
      rows.add(['$level', '${seen.length}', '$spirits', '${seen.values.where((id) => id.startsWith('wyrm.')).length}']);
    }
    tables.add({'title': 'Ecos à vista numa hora, por nível do Conjurador (Centro, 120 m, época 11, 3 janelas)', 'columns': ['Nível', 'Ecos', 'Espíritos', 'Wyrm'], 'rows': rows});

    // Poças do Rill de verdade por célula z18 (as que caíram na rua ou na calçada), num quadrado de ~1 km no Centro.
    final visual = VisualMap(VisualPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync())), cacheTiles: 128);
    final paths = WalkPaths(visual);
    final (x21, y21) = latLonToTileFraction(lat, lon, 21);
    final prow = <List<String>>[];
    for (final (i, band) in data.personal.rillBands.indexed) {
      final cw = ClimateWorld(seed: seed, schedule: schedule, speciesOfType: data.ecoOfType, itemExists: data.itemNames.containsKey, snapper: paths, forced: () => 'rain');
      final field = SpawnField(seed: seed, schedule: schedule, map: map);
      cw.personalPuddles = PersonalLayer(field: field, playerKey: playerKeyOf('workbench'), builds: () => [BuildEntry(fromUtc: 0, values: {kRainPuddles: i + 1.0})], balance: data.personal).puddlesAt;
      final mine = cw.puddlesNear(x21, y21, 500 / metersPerCell(lat), t0 + 600).where((p) => p.personal).toList();
      final cells = <(int, int)>{for (final p in mine) (p.x ~/ 8, p.y ~/ 8)};
      final eco = mine.where((p) => p.rolls.spawnRoll < p.ecoChance!).length;
      prow.add(['${i + 1}', '${band.puddles}', (mine.length / cells.length).toStringAsFixed(2), '${(100 * eco / mine.length).round()}%', '${(band.ecoChance * 100).round()}%']);
    }
    tables.add({'title': 'Poças do Rill por célula z18 na chuva (Centro, ~1 km)', 'columns': ['Faixa', 'Pedidas', 'Na rua, por célula', 'Com Eco de Água', 'Chance da faixa'], 'rows': prow});
    File('../workbench/catalog/medidas.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(tables));
  });
}
