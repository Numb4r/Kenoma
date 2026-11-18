import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/data/region_pack.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';

import '../support/fixtures.dart';

/// 0.25.2 (modo de desenvolvimento, GDD rev 368): o que muda é só a regra de congelar épocas. Dois aparelhos com a mesma
/// versão (o mesmo `epochs.json` e o mesmo pacote) e a mesma seed veem o mesmo mundo em qualquer instante, cada um lendo
/// os arquivos por conta própria.
void main() {
  SpawnField device(int seed) {
    final schedule = EpochSchedule.fromJson(shippedEpochsJson()); // cada aparelho lê o seu
    final ref = schedule.epochs.single.regionPacks['campinas']!;
    final pack = RegionPack.parse(Uint8List.fromList(File('assets/regions/${ref.file}').readAsBytesSync()));
    return SpawnField(seed: seed, schedule: schedule, map: RegionMap(pack: pack, biomes: loadBiomes()));
  }

  final seed = seedGlobal('KENOMA-TESTE');
  final (lat, lon) = kCentroCampinas;
  // Do começo do jogo até daqui a anos: a época de desenvolvimento vale em todos.
  final instants = [1790035200 + 3600, 1795800000, 1795800000 + 7 * 86400 + 1234, 1900000000];

  test('mesma versão, mesma seed: o mesmo mundo em dois aparelhos, em qualquer instante', () {
    final a = device(seed), b = device(seed);
    var n = 0;
    for (final t in instants) {
      String trace(SpawnField f) => [
            for (final s in f.around(lat: lat, lon: lon, tUtc: t, radiusM: 200, playerLevel: 10)) '${s.uid}:${s.entryId}:${s.x}:${s.y}:${s.quantity}:${s.level}:${s.variant}',
          ].join('|');
      final ta = trace(a);
      expect(ta, isNotEmpty, reason: 'há mundo em $t');
      expect(trace(b), ta, reason: 'em $t');
      n += ta.split('|').length;
    }
    expect(n, greaterThan(20));
  });

  test('outra seed, outro mundo (o teste não passa por acaso)', () {
    final t = instants[1];
    String trace(SpawnField f) => [for (final s in f.around(lat: lat, lon: lon, tUtc: t, radiusM: 200, playerLevel: 10)) '${s.entryId}:${s.x}:${s.y}'].join('|');
    expect(trace(device(seed + 1)), isNot(trace(device(seed))));
  });
}
