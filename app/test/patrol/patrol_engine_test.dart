import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/map_sources.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/patrol/patrol_balance.dart';
import 'package:kenoma/patrol/patrol_engine.dart';
import 'package:kenoma/patrol/patrol_journal.dart' show applyJournal;
import 'package:kenoma/patrol/street_name.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/player/mark.dart';
import 'package:kenoma/world/geo_fix.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/visual_map.dart';
import 'package:kenoma/world/world_view.dart';

import '../support/fixtures.dart';

const t0 = 1790040000;
final seed = seedGlobal('KENOMA-TESTE');
final map = RegionMap(pack: loadCampinasPack(), biomes: loadBiomes());
final balance = PatrolBalance(loadJson('assets/data/balance.json'));
final double lat0 = kCentroCampinas.$1, lon0 = kCentroCampinas.$2;

/// Uma época de teste que força o comportamento (e as chances de variante e Brilhante) de todos os Ecos.
EpochSchedule schedule(Map<String, int> weights, {double variant = 0, double shiny = 0}) {
  final j = jsonDecode(jsonEncode(epochsJson())) as Map<String, dynamic>;
  final e = (j['epochs'] as List).cast<Map<String, dynamic>>().firstWhere((e) => e['id'] == 3);
  e['starts_utc'] = '2026-01-01T00:00:00Z';
  e['valid_until_utc'] = '2027-12-31T00:00:00Z';
  final v2 = e['eco_v2'] as Map<String, dynamic>;
  v2['behavior_weights'] = {'passive': 0, 'skittish': 0, 'aggressive': 0, 'hidden': 0, ...weights};
  v2['variant_chance'] = variant;
  v2['shiny_chance'] = shiny;
  return EpochSchedule([Epoch.fromJson(e)]);
}

final passive = schedule({'passive': 100});

WorldView viewOf(GameState s, EpochSchedule sch) => WorldView(
      field: SpawnField(seed: seed, schedule: sch, map: map),
      state: s,
      auraM: 10,
      viewM: 120,
      itemName: (i) => i,
      street: loadStreetBalance(),
    );

(PatrolEngine, GameState) engineOf(EpochSchedule sch, {int maxS = 7200, String? Function(double, double)? street}) {
  final s = GameState(groupCode: 'KENOMA-TESTE', balance: loadProgressBalance());
  return (PatrolEngine(world: viewOf(s, sch), state: s, balance: balance, startUtc: t0, maxDurationS: maxS, streetAt: street), s);
}

/// O primeiro spawn do tipo [kind] perto do centro e o ponto dele.
(WorldSpawn, double, double) find(EpochSchedule sch, String kind) {
  final s = SpawnField(seed: seed, schedule: sch, map: map).around(lat: lat0, lon: lon0, tUtc: t0, radiusM: 400, playerLevel: 1).firstWhere((x) => x.kind == kind);
  final (la, lo) = tileFractionToLatLon(s.x, s.y, biomeZoom);
  return (s, la, lo);
}

GeoFix at(double lat, double lon, int t, {double? speed}) => GeoFix(lat: lat, lon: lon, accuracyM: 5, timeMs: t * 1000, speedMps: speed);

/// Um ponto [m] metros ao norte.
(double, double) north(double lat, double lon, double m) => (lat + m / 111320.0, lon);

List<String> kinds(PatrolOutput o) => [for (final l in o.lines) l['k'] as String];

void main() {
  test('Fagulha na Aura vira linha do diário, uma vez só', () {
    final (spark, la, lo) = find(passive, 'spark');
    final (e, s) = engineOf(passive);
    final out = e.fix(at(la, lo, t0), t0);
    final line = out.lines.firstWhere((l) => l['uid'] == GameState.uidKey(spark.uid));
    expect((line['k'], line['item'], line['q']), ('spark', spark.entryId, spark.quantity));
    expect(s.isDone(spark.uid), isTrue);
    expect(e.fix(at(la, lo, t0 + 10), t0 + 10).lines.where((l) => l['uid'] == GameState.uidKey(spark.uid)), isEmpty);
    expect(e.status(t0 + 10).sparks, greaterThanOrEqualTo(spark.quantity));
  });

  test('material na Aura também é coletado (no app pede toque)', () {
    final (mat, la, lo) = find(passive, 'material');
    final (e, _) = engineOf(passive);
    final out = e.fix(at(la, lo, t0), t0);
    expect(out.lines.where((l) => l['k'] == 'material' && l['uid'] == GameState.uidKey(mat.uid)), hasLength(1));
  });

  test('Eco a até 30 m é marcado e vibra curto; a marca vale da hora do diário', () {
    final (eco, la, lo) = find(passive, 'eco');
    final (e, s) = engineOf(passive);
    final out = e.fix(at(la, lo, t0), t0);
    final mark = out.lines.firstWhere((l) => l['k'] == 'mark' && l['uid'] == GameState.uidKey(eco.uid));
    expect(Mark.fromJson(mark['mark'] as Map<String, dynamic>).expiresUtc, t0 + balance.markDurationS);
    expect(out.vibrations.first, balance.vibrateMs);
    expect(s.markOf(eco.uid), isNotNull);
    expect(out.rare, isEmpty);
  });

  test('limite de marcas: com as vagas cheias nada é marcado nem vibra', () {
    final (_, la, lo) = find(passive, 'eco');
    final (e, s) = engineOf(passive);
    for (var i = 0; i < s.balance.markMax; i++) {
      s.marks.add(Mark(uid: '$i', speciesId: 'soot.eco', level: 1, x: 0, y: 0, cellX: 0, cellY: 0, window: 0, markedUtc: t0, expiresUtc: t0 + 9999));
    }
    final out = e.fix(at(la, lo, t0), t0);
    expect(kinds(out), isNot(contains('mark')));
    expect(out.vibrations, isEmpty);
  });

  test('Brilhante: outro padrão e aviso com a rua (sem rua, "por perto")', () {
    final sch = schedule({'passive': 100}, shiny: 1);
    final (_, la, lo) = find(sch, 'eco');
    final (e, _) = engineOf(sch, street: (_, _) => 'Rua Barão de Jaguara');
    final out = e.fix(at(la, lo, t0), t0);
    expect(out.vibrations.first, balance.vibrateRareMs);
    expect(out.rare.first.text, startsWith('Algo raro passou a '));
    expect(out.rare.first.text, endsWith(' m, na R. Barão de Jaguara'));
    final (e2, _) = engineOf(sch);
    expect(e2.fix(at(la, lo, t0), t0).rare.first.text, endsWith('por perto'));
  });

  group('regra de passageiro', () {
    test('carro detectado pergunta uma vez; até responder nada rende', () {
      final (_, la, lo) = find(passive, 'eco');
      final (e, _) = engineOf(passive);
      final (fla, flo) = north(la, lo, 400);
      expect(e.fix(at(fla, flo, t0, speed: 12), t0).ask, isFalse, reason: 'uma leitura rápida só não basta');
      final out = e.fix(at(fla, flo, t0 + 10, speed: 12), t0 + 10);
      expect((out.ask, e.mode), (true, PatrolMode.asking));
      expect(patrolNotificationText(e.status(t0 + 10)), contains('responder'));
      final there = e.fix(at(la, lo, t0 + 20, speed: 12), t0 + 20);
      expect(kinds(there), everyElement(isNot(anyOf('spark', 'material', 'mark'))));
      expect(there.vibrations, isEmpty);
    });

    test('quem dirige: sem coleta, sem marca, sem vibração; só a viagem gravada', () {
      final (_, la, lo) = find(passive, 'eco');
      final (e, _) = engineOf(passive);
      final (fla, flo) = north(la, lo, 400);
      e.fix(at(fla, flo, t0, speed: 12), t0);
      e.fix(at(fla, flo, t0 + 10, speed: 12), t0 + 10);
      e.answer(passenger: false);
      expect(e.mode, PatrolMode.driver);
      final there = e.fix(at(la, lo, t0 + 40, speed: 12), t0 + 40);
      expect(kinds(there), everyElement(isNot(anyOf('spark', 'material', 'mark', 'cell'))));
      expect(there.vibrations, isEmpty);
      e.fix(at(la, lo, t0 + 50, speed: 0), t0 + 50);
      final out = e.fix(at(la, lo, t0 + 50 + balance.vehicleExitS, speed: 0), t0 + 50 + balance.vehicleExitS);
      final trip = out.lines.firstWhere((l) => l['k'] == 'trip');
      expect((trip['driver'], (trip['m'] as int) > 300), (true, true));
      expect(e.mode, PatrolMode.walking);
      // No app, o diário do trecho ao volante e da chegada só grava a viagem: nem baú, nem item, nem XP, nem marca.
      final s = GameState(groupCode: 'KENOMA-TESTE', balance: loadProgressBalance());
      applyJournal(s, [{'k': 'start', 't': t0}, for (final l in [...there.lines, trip]) jsonDecode(jsonEncode(l)) as Map<String, dynamic>, {'k': 'end', 't': t0 + 400}], nowUtc: t0 + 400);
      expect(s.story.count('trip_m'), trip['m']);
      expect((s.inventory.length, s.progress.xp, s.marks.length), (0, 0, 0));
    });

    test('passageiro: Ecos do caminho marcados; a resposta vale para o próximo carro, sem perguntar de novo', () {
      final (eco, la, lo) = find(passive, 'eco');
      final (e, _) = engineOf(passive);
      final (fla, flo) = north(la, lo, 400);
      e.fix(at(fla, flo, t0, speed: 12), t0);
      e.fix(at(fla, flo, t0 + 10, speed: 12), t0 + 10);
      e.answer(passenger: true);
      final out = e.fix(at(la, lo, t0 + 40, speed: 12), t0 + 40);
      expect(out.lines.where((l) => l['k'] == 'mark' && l['uid'] == GameState.uidKey(eco.uid)), hasLength(1));
      expect(kinds(out), isNot(contains('spark')), reason: 'mundo calado, como no Modo Viagem');
      e.fix(at(la, lo, t0 + 50, speed: 0), t0 + 50);
      e.fix(at(la, lo, t0 + 300, speed: 0), t0 + 300);
      expect(e.mode, PatrolMode.walking);
      expect(e.fix(at(fla, flo, t0 + 310, speed: 12), t0 + 310).ask, isFalse);
      expect(e.fix(at(fla, flo, t0 + 320, speed: 12), t0 + 320).ask, isFalse);
      expect(e.mode, PatrolMode.passenger);
    });
  });

  group('desligamento', () {
    test('por tempo', () {
      final (e, _) = engineOf(passive, maxS: 3600);
      e.fix(at(lat0, lon0, t0 + 3500), t0 + 3500);
      expect(e.tick(t0 + 3599).stop, isNull);
      final out = e.tick(t0 + 3600);
      expect((out.stop, out.lines.last['k'], out.lines.last['why']), (PatrolStop.time, 'end', 'time'));
      expect(e.fix(at(lat0, lon0, t0 + 3700), t0 + 3700).lines, isEmpty, reason: 'acabou');
    });

    test('por bateria abaixo de 20%', () {
      final (e, _) = engineOf(passive);
      expect(e.battery(20, t0).stop, isNull);
      expect(e.battery(19, t0).stop, PatrolStop.battery);
    });

    test('por falta de GPS: 10 minutos sem leitura', () {
      final (e, _) = engineOf(passive);
      expect(e.tick(t0 + balance.gpsTimeoutS - 1).stop, isNull, reason: 'conta do começo, sem leitura nenhuma');
      expect(e.tick(t0 + balance.gpsTimeoutS).stop, PatrolStop.gps);
      final (e2, _) = engineOf(passive);
      e2.fix(at(lat0, lon0, t0 + 500), t0 + 500);
      expect(e2.tick(t0 + 500 + balance.gpsTimeoutS - 1).stop, isNull);
      expect(e2.tick(t0 + 500 + balance.gpsTimeoutS).stop, PatrolStop.gps);
    });

    test('o fim leva a caminhada que faltava e os passos', () {
      final (e, _) = engineOf(passive);
      e.fix(at(lat0, lon0, t0), t0);
      e.fix(at(north(lat0, lon0, 30).$1, lon0, t0 + 30), t0 + 30);
      final out = e.stop(PatrolStop.user, t0 + 60, extra: {'steps': 1234});
      expect(kinds(out), ['walk', 'end']);
      expect(out.lines.last['steps'], 1234);
    });
  });

  test('células z17 visitadas, uma linha por célula', () {
    final (e, _) = engineOf(passive);
    final a = e.fix(at(lat0, lon0, t0), t0);
    final b = e.fix(at(lat0, lon0, t0 + 10), t0 + 10);
    expect(a.lines.where((l) => l['k'] == 'cell').single['x'], latLonToTile(lat0, lon0, 17).$1);
    expect(b.lines.where((l) => l['k'] == 'cell'), isEmpty);
  });

  test('na Patrulha simulada do debug as células visitadas não são gravadas', () {
    final s = GameState(groupCode: 'KENOMA-TESTE', balance: loadProgressBalance());
    final sim = PatrolEngine(world: viewOf(s, passive), state: s, balance: balance, startUtc: t0, maxDurationS: 7200, recordCells: false);
    expect(sim.fix(at(lat0, lon0, t0), t0).lines.where((l) => l['k'] == 'cell'), isEmpty);
  });

  test('texto da notificação', () {
    const s = PatrolStatus(sparks: 12, materials: 3, marks: 2, minutes: 34, asking: false, mode: PatrolMode.walking);
    expect(patrolNotificationText(s), '12 Fagulhas · 2 Ecos marcados · 34 min');
    expect(patrolNotificationText(const PatrolStatus(sparks: 1, materials: 0, marks: 1, minutes: 0, asking: false, mode: PatrolMode.walking)), '1 Fagulha · 1 Eco marcado · 0 min');
  });

  group('rua', () {
    test('streetPhrase abrevia e escolhe a preposição', () {
      expect(streetPhrase('Rua Barão de Jaguara'), 'na R. Barão de Jaguara');
      expect(streetPhrase('Avenida Norte-Sul'), 'na Av. Norte-Sul');
      expect(streetPhrase('Viaduto Cury'), 'no Viaduto Cury');
      expect(streetPhrase(null), 'por perto');
    });

    test('nearestStreetName acha a linha com nome mais perto, dentro do raio', () {
      final v = VisualMap(_OneLine());
      expect(nearestStreetName(v, 10, 10.5, 2), 'Rua A');
      expect(nearestStreetName(v, 10, 20, 2), isNull);
    });
  });
}

/// Um tile z15 com uma rua com nome na horizontal, em y = 10 células.
class _OneLine implements VisualSource {
  @override
  int get version => 2;
  @override
  int get tileZoom => 15;
  @override
  int get extent => 64;
  @override
  int get revision => 0;
  @override
  bool hasTile(int x, int y) => x == 0 && y == 0;
  @override
  VisualTile? decode(int x, int y) => hasTile(x, y)
      ? VisualTile(lines: [VisualLine(RoadClass.principal, Int32List.fromList([0, 10, 64, 10]), name: 'Rua A')], areas: const [])
      : null;
}
