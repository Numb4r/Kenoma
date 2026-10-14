import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/world_view.dart';

import '../support/fixtures.dart';

void main() {
  const t0 = 1790035200 + 86400;
  final (lat, lon) = kCentroCampinas;

  (WorldView, GameState, List<String>) make() {
    final state = GameState.fresh(groupCode: 'KENOMA-TESTE', startInventory: {});
    final msgs = <String>[];
    final view = WorldView(
      field: SpawnField(seed: seedGlobal('KENOMA-TESTE'), schedule: loadEpochs(), map: RegionMap(pack: loadCampinasPack(), biomes: loadBiomes())),
      state: state,
      auraM: 40,
      viewM: 120,
      itemName: (id) => id,
      onMessage: msgs.add,
    );
    return (view, state, msgs);
  }

  /// Um spawn do tipo [kind] perto do centro e a posição de quem está em cima dele.
  (double, double, WorldSpawn) find(String kind) {
    final (view, _, _) = make();
    final s = view.field
        .around(lat: lat, lon: lon, tUtc: t0, radiusM: 400, playerLevel: 1)
        .firstWhere((s) => s.kind == kind);
    final (la, lo) = tileFractionToLatLon(s.x, s.y, biomeZoom);
    return (la, lo, s);
  }

  test('Fagulha dentro da Aura é coletada sozinha, uma vez só', () {
    final hit = find('spark');
    final (view, state, msgs) = make();
    final got = view.refresh(lat: hit.$1, lon: hit.$2, tUtc: t0);
    expect(got, isNotEmpty);
    expect(state.isDone(hit.$3.uid), isTrue);
    expect(state.count(hit.$3.entryId), greaterThanOrEqualTo(hit.$3.quantity));
    expect(msgs, isNotEmpty);
    expect(view.spawns.any((s) => s.uid == hit.$3.uid), isFalse);
    final before = state.count(hit.$3.entryId);
    expect(view.refresh(lat: hit.$1, lon: hit.$2, tUtc: t0), isEmpty, reason: 'não reaparece');
    expect(state.count(hit.$3.entryId), before);
  });

  test('Fagulha fora da Aura, ainda à vista, fica onde está', () {
    final (view, state, _) = make();
    view.refresh(lat: lat, lon: lon, tUtc: t0);
    final far = view.spawns.where((s) => s.isSpark && !view.inAura(s));
    expect(far, isNotEmpty);
    expect(state.isDone(far.first.uid), isFalse);
  });

  test('material: toque dentro da Aura coleta; fora, não faz nada', () {
    final near = find('material');
    final (view, state, _) = make();
    view.refresh(lat: near.$1, lon: near.$2, tUtc: t0);
    final s = view.spawns.firstWhere((s) => s.uid == near.$3.uid);
    expect(view.touch(s, t0), TouchResult.collected);
    expect(state.count(s.entryId), s.quantity);
    expect(state.isDone(s.uid), isTrue);

    final (v2, st2, _) = make();
    v2.refresh(lat: lat, lon: lon, tUtc: t0);
    final f = v2.spawns.firstWhere((s) => s.isMaterial && !v2.inAura(s));
    expect(v2.touch(f, t0), TouchResult.tooFar);
    expect(st2.isDone(f.uid), isFalse);
  });

  test('Eco: dentro da Aura abre o encontro, fora pede para chegar perto, e some quando registrado', () {
    final inside = find('eco');
    final (v2, st2, _) = make();
    v2.refresh(lat: inside.$1, lon: inside.$2, tUtc: t0);
    final eco = v2.spawns.firstWhere((s) => s.uid == inside.$3.uid);
    expect(v2.touch(eco, t0), TouchResult.encounter);
    expect(st2.isDone(eco.uid), isFalse, reason: 'só o resultado do encontro registra');
    st2.markDone(eco.uid, t0);
    v2.refresh(lat: inside.$1, lon: inside.$2, tUtc: t0);
    expect(v2.spawns.any((s) => s.uid == eco.uid), isFalse, reason: 'capturado ou fugiu: não volta');
  });

  test('o registro vale entre sessões: outro WorldView com o mesmo estado não mostra o coletado', () {
    final hit = find('spark');
    final (a, state, _) = make();
    a.refresh(lat: hit.$1, lon: hit.$2, tUtc: t0);
    final b = WorldView(field: a.field, state: state, auraM: 40, viewM: 120, itemName: (i) => i);
    b.refresh(lat: hit.$1, lon: hit.$2, tUtc: t0 + 60);
    expect(b.spawns.any((s) => s.uid == hit.$3.uid), isFalse);
  });
}
