import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/world/debug_force.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/world_view.dart';

import '../support/fixtures.dart';

void main() {
  // Dentro da época 4 (a primeira que sorteia Espíritos e rituais).
  const t0 = 1792176000 + 3600;
  final (lat, lon) = kCentroCampinas;
  final data = loadGameData();
  final map = RegionMap(pack: loadCampinasPack(), biomes: loadBiomes());

  SpawnField field({bool caps = true}) =>
      SpawnField(seed: seedGlobal('KENOMA-TESTE'), schedule: loadEpochs(), map: map, levelCapOf: caps ? data.progress.levelCapFor : null);

  (WorldView, GameState) view(int level, {bool caps = true}) {
    final state = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress)..levelOverride = level;
    return (WorldView(field: field(caps: caps), state: state, auraM: 40, viewM: 400, itemName: (id) => id, street: loadStreetBalance()), state);
  }

  /// Um Espírito (ou ritual) qualquer da época 4 e o ponto onde ficar para tocá-lo, procurando em várias janelas.
  (double, double, WorldSpawn, int) findSpirit({bool ritual = false}) {
    final f = field();
    for (var k = 0; k < 400; k++) {
      final t = t0 + k * 1200;
      for (final s in f.around(lat: lat, lon: lon, tUtc: t, radiusM: 900, playerLevel: 20)) {
        if (s.isEco && s.entryId.endsWith(ritual ? '.ritual' : '.spirit')) {
          final (la, lo) = tileFractionToLatLon(s.x, s.y, biomeZoom);
          return (la, lo, s, t);
        }
      }
    }
    fail('nenhum ${ritual ? 'ritual' : 'Espírito'} na época 4 perto do centro');
  }

  test('Espíritos só aparecem a partir do nível 8; abaixo disso o mundo é o mesmo, mas o jogador não os vê', () {
    final sp = findSpirit();
    final (low, _) = view(7);
    low.refresh(lat: sp.$1, lon: sp.$2, tUtc: sp.$4);
    expect(low.spawns.any((s) => s.uid == sp.$3.uid), isFalse);
    expect(low.allEcos.any((s) => s.entryId.endsWith('.spirit') || s.entryId.endsWith('.ritual')), isFalse);
    expect(low.spawns.where((s) => s.isEco), isNotEmpty, reason: 'os Ecos comuns seguem aparecendo');

    final (high, _) = view(8);
    high.refresh(lat: sp.$1, lon: sp.$2, tUtc: sp.$4);
    expect(high.spawns.any((s) => s.uid == sp.$3.uid), isTrue);
  });

  test('o nível do Espírito vai ao teto 30; sem o teto por camada ele travava em 20', () {
    var max30 = 0;
    for (var k = 0; k < 400 && max30 <= 20; k++) {
      final f = field();
      for (final s in f.around(lat: lat, lon: lon, tUtc: t0 + k * 1200, radiusM: 900, playerLevel: 20)) {
        if (s.isEco && s.entryId.endsWith('.spirit')) max30 = s.level! > max30 ? s.level! : max30;
        expect(s.level ?? 1, lessThanOrEqualTo(s.entryId.endsWith('.eco') ? 20 : 30));
      }
    }
    expect(max30, greaterThan(20), reason: 'um Conjurador de nível 20 vê Espíritos acima de 20');
    for (var k = 0; k < 400; k++) {
      for (final s in field(caps: false).around(lat: lat, lon: lon, tUtc: t0 + k * 1200, radiusM: 900, playerLevel: 20)) {
        expect(s.level ?? 1, lessThanOrEqualTo(20), reason: 'sem levelCapOf vale o teto antigo');
      }
    }
  });

  test('o toque num Eco só de ritual não abre a sintonia: devolve TouchResult.ritual e chama o gancho', () {
    final r = findSpirit(ritual: true);
    final (v, _) = view(10);
    final hits = <int>[];
    v.onRitualTarget = (s) => hits.add(s.uid);
    v.refresh(lat: r.$1, lon: r.$2, tUtc: r.$4);
    final eco = v.spawns.firstWhere((s) => s.uid == r.$3.uid);
    expect(v.touch(eco, r.$4), TouchResult.ritual);
    expect(hits, [eco.uid]);
  });

  test('forçar Espírito pelo debug transforma o próximo Eco novo, abaixo do nível 8', () {
    final state = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress)..levelOverride = 3;
    final f = field();
    final spawns = f.around(lat: lat, lon: lon, tUtc: t0, radiusM: 400, playerLevel: 3);
    expect(spawns.any((s) => s.isEco), isTrue);
    final force = DebugForce()..set(spirit: true);
    final v = WorldView(field: f, state: state, auraM: 40, viewM: 400, itemName: (id) => id, street: loadStreetBalance(), force: force);
    v.refresh(lat: lat, lon: lon, tUtc: t0);
    final forced = v.spawns.where((s) => s.isEco && s.entryId.endsWith('.spirit'));
    expect(forced, hasLength(1));
    expect(forced.first.level, lessThanOrEqualTo(30));
    expect(force.nextSpirit, isFalse, reason: 'o pedido foi gasto');
  });
}
