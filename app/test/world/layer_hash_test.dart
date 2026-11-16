import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/world/personal_layer.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';

import '../support/fixtures.dart';

/// 0.20.4: os resumos das camadas no debug, para comparar dois aparelhos de verdade (o celular e o emulador) a olho.
void main() {
  final seed = seedGlobal('KENOMA-TESTE');
  final map = RegionMap(pack: loadCampinasPack(), biomes: loadBiomes());
  final (x21, y21) = latLonToTileFraction(-22.9056, -47.0608, 21);
  final (cx, cy) = (x21.floor() >>> 1, y21.floor() >>> 1);
  const t = 1795000000;

  /// Um aparelho: lê tudo do zero, com o próprio player_id.
  (SpawnField, PersonalLayer) device(String playerId) {
    final field = SpawnField(seed: seed, schedule: loadEpochs(), map: map);
    return (field, PersonalLayer(field: field, playerKey: playerKeyOf(playerId), builds: () => const []));
  }

  test('na mesma célula e janela, a base é igual nos dois aparelhos e a pessoal difere pelo player_id', () {
    final (phoneField, phone) = device('celular');
    final (emuField, emu) = device('emulador');
    expect(phoneField.baseHashAt(cx, cy, t), emuField.baseHashAt(cx, cy, t));
    expect(phone.personalHashAt(cx, cy, t), isNot(emu.personalHashAt(cx, cy, t)));
    final (_, again) = device('celular');
    expect(again.personalHashAt(cx, cy, t), phone.personalHashAt(cx, cy, t), reason: 'o mesmo jogador reabrindo o app');
  });

  test('a base muda com a célula e com a janela', () {
    final (f, _) = device('celular');
    final here = f.baseHashAt(cx, cy, t);
    expect(f.baseHashAt(cx + 1, cy, t), isNot(here));
    expect(f.baseHashAt(cx, cy, t + f.secondsLeft(cx, cy, t) + 1), isNot(here));
  });
}
