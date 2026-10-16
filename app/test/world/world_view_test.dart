import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/player/circle.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/player/mark.dart';
import 'package:kenoma/player/progression.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/world_view.dart';

import '../support/fixtures.dart';

void main() {
  const t0 = 1790035200 + 86400;
  final (lat, lon) = kCentroCampinas;

  (WorldView, GameState, List<String>) make() {
    final state = GameState.fresh(groupCode: 'KENOMA-TESTE', startInventory: {}, balance: loadProgressBalance());
    final msgs = <String>[];
    final view = WorldView(
      field: SpawnField(seed: seedGlobal('KENOMA-TESTE'), schedule: loadEpochs(), map: RegionMap(pack: loadCampinasPack(), biomes: loadBiomes())),
      state: state,
      auraM: 40,
      viewM: 120,
      itemName: (id) => id,
      street: loadStreetBalance(),
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
    final b = WorldView(field: a.field, state: state, auraM: 40, viewM: 120, itemName: (i) => i, street: loadStreetBalance());
    b.refresh(lat: hit.$1, lon: hit.$2, tUtc: t0 + 60);
    expect(b.spawns.any((s) => s.uid == hit.$3.uid), isFalse);
  });

  group('progressão no mapa', () {
    WorldView viewWith(GameState state, {MapAbilities Function()? abilities}) => WorldView(
          field: SpawnField(seed: seedGlobal('KENOMA-TESTE'), schedule: loadEpochs(), map: RegionMap(pack: loadCampinasPack(), biomes: loadBiomes())),
          state: state,
          auraM: 25,
          viewM: 120,
          trackerM: 120,
          itemName: (id) => id,
          street: loadStreetBalance(),
          abilities: abilities ?? () => MapAbilities.none,
        );

    GameState fresh() => GameState.fresh(groupCode: 'KENOMA-TESTE', startInventory: {}, balance: loadProgressBalance());

    test('Fagulha dá 2 de XP e material 5, com o dobro do descanso no primeiro dia', () {
      final hit = find('spark');
      final state = fresh();
      viewWith(state).refresh(lat: hit.$1, lon: hit.$2, tUtc: t0);
      final sparks = state.registrySize;
      expect(state.progress.xp, sparks * 4 - _xpSpentOnLevels(state), reason: '2 de XP por Fagulha, dobrado pelo descanso');

      final m = find('material');
      final st2 = fresh();
      final v2 = viewWith(st2)..refresh(lat: m.$1, lon: m.$2, tUtc: t0);
      final before = st2.progress.xp + _xpSpentOnLevels(st2);
      final mat = v2.spawns.firstWhere((x) => x.uid == m.$3.uid);
      v2.touch(mat, t0);
      expect(st2.progress.xp + _xpSpentOnLevels(st2) - before, 10, reason: '5 de XP, dobrado');
    });

    test('ver um Eco no mapa põe a espécie no bestiário como vista, ainda não capturada', () {
      final eco = find('eco');
      final state = fresh();
      viewWith(state).refresh(lat: eco.$1, lon: eco.$2, tUtc: t0);
      expect(state.bestiary[eco.$3.entryId]?.seen, isTrue);
      expect(state.bestiary[eco.$3.entryId]?.captured, isFalse);
    });

    test('Aura maior do Círculo: um Eco a ~30 m passa a ser alcançável', () {
      final eco = find('eco');
      final (la, lo) = (eco.$1 + 30 / 111320, eco.$2); // ~30 m ao norte do Eco
      final plain = viewWith(fresh())..refresh(lat: la, lon: lo, tUtc: t0);
      final spawn = plain.spawns.firstWhere((x) => x.uid == eco.$3.uid);
      expect(plain.touch(spawn, t0), TouchResult.tooFar);
      final boosted = viewWith(fresh(), abilities: () => const MapAbilities(auraBonusM: 12))..refresh(lat: la, lon: lo, tUtc: t0);
      expect(boosted.auraRadiusM, 37);
      expect(boosted.touch(boosted.spawns.firstWhere((x) => x.uid == eco.$3.uid), t0), TouchResult.encounter);
    });

    test('alcance de coleta do Círculo pega Fagulhas de mais longe, e o rastreador alarga a área gerada', () {
      final v = viewWith(fresh(), abilities: () => const MapAbilities(pickupBonusM: 10, trackerRangeM: 200));
      expect(v.pickupRadiusM, 40, reason: 'Aura 25 + Círculo 10 + Familiar 5');
      expect(v.trackerRangeM, 200);
      expect(v.reachM, 200);
      expect(viewWith(fresh(), abilities: () => const MapAbilities(trackerRangeM: 90)).trackerRangeM, 120, reason: 'nunca abaixo do padrão');
    });

    test('Eco marcado abre o encontro de qualquer distância', () {
      final eco = find('eco');
      final state = fresh();
      final (la, lo) = (eco.$1 + 80 / 111320, eco.$2);
      final v = viewWith(state)..refresh(lat: la, lon: lo, tUtc: t0);
      final spawn = v.spawns.firstWhere((x) => x.uid == eco.$3.uid);
      expect(v.touch(spawn, t0), TouchResult.tooFar);
      state.addMark(Mark.of(spawn, nowUtc: t0, durationS: 300), t0);
      expect(v.touch(spawn, t0), TouchResult.encounter);
    });
  });
}

/// XP gasto nos níveis já subidos, para medir o XP total ganho.
int _xpSpentOnLevels(GameState s) {
  var spent = 0;
  for (var n = 1; n < s.progress.level; n++) {
    spent += xpToNext(n, s.balance);
  }
  return spent;
}
