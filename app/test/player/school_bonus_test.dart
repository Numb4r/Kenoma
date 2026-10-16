import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/session.dart';
import 'package:kenoma/capture/tuning_setup.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/core/pcg32.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/player/conjurer_balance.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/world_view.dart';

import '../support/fixtures.dart';
import '../support/reference_player.dart';

/// Os bônus de captura de cada escola, com e sem ela (docs/GDD.md, "Escolas de Conjuração").
void main() {
  final cb = loadProgressBalance().conjurer;
  final b = loadTuningBalance();

  TuningSetup setupFor(School? school) => TuningSetup(
        type: EcoType.fire,
        ecoLevel: 1,
        playerLevel: 1,
        seal: sealById('item.seal.simple'),
        toleranceMult: cb.toleranceMultFor(school),
        progressUpMult: cb.progressUpMultFor(school),
      );

  test('os fatores vêm do balance.json: só a escola dona do bônus muda', () {
    expect(cb.techToleranceMult, 1.10);
    expect(cb.sealerProgressMult, 1.15);
    expect(cb.toleranceMultFor(School.technomancer), 1.10);
    expect(cb.toleranceMultFor(School.shaman), 1.0);
    expect(cb.toleranceMultFor(School.sealer), 1.0);
    expect(cb.toleranceMultFor(null), 1.0);
    expect(cb.progressUpMultFor(School.sealer), 1.15);
    expect(cb.progressUpMultFor(School.technomancer), 1.0);
    expect(cb.progressUpMultFor(null), 1.0);
  });

  test('Tecnomante: a tolerância da sintonia é exatamente 10% maior; as outras não mudam', () {
    final base = setupFor(null).tolerance(b);
    expect(base, 0.08);
    expect(setupFor(School.technomancer).tolerance(b), closeTo(base * 1.10, 1e-12));
    expect(setupFor(School.shaman).tolerance(b), base);
    expect(setupFor(School.sealer).tolerance(b), base);
  });

  test('Tecnomante: a sessão usa a tolerância maior (alinha a uma distância que sem a escola não alinharia)', () {
    TuningSession session(School? s) => setupFor(s).start(b, Pcg32(1, 2));
    for (final (school, aligned) in [(null, false), (School.technomancer, true)]) {
      final t = session(school);
      final dial = t.signal.frequencyAt(0.1) + 0.085; // entre 0,08 e 0,088
      t.step(0.1, dial: dial);
      expect(t.aligned, aligned, reason: '$school');
    }
  });

  test('Selador: o progresso sobe exatamente 15% mais rápido; as outras escolas e sem escola não mudam', () {
    double progressAfterHalfSecond(School? s) {
      final t = setupFor(s).start(b, Pcg32(1, 2));
      t.step(0.5, dial: t.signal.frequencyAt(0.5));
      expect(t.aligned, isTrue);
      return t.progress;
    }

    final base = progressAfterHalfSecond(null);
    expect(base, closeTo(b.progressUpPerS * 0.5, 1e-12));
    expect(progressAfterHalfSecond(School.sealer), closeTo(base * 1.15, 1e-12));
    expect(progressAfterHalfSecond(School.technomancer), base);
    expect(progressAfterHalfSecond(School.shaman), base);
  });

  group('Xamã Urbano: já ligado no mapa', () {
    final seed = seedGlobal('KENOMA-TESTE');
    final street = loadStreetBalance();
    final map = RegionMap(pack: loadCampinasPack(), biomes: loadBiomes());
    final sch = () {
      final j = jsonDecode(jsonEncode(epochsJson())) as Map<String, dynamic>;
      final e = (j['epochs'] as List).cast<Map<String, dynamic>>().firstWhere((e) => e['id'] == 3);
      e['starts_utc'] = '2026-01-01T00:00:00Z';
      e['valid_until_utc'] = '2027-12-31T00:00:00Z';
      (e['eco_v2'] as Map<String, dynamic>)['behavior_weights'] = {'passive': 0, 'skittish': 100, 'aggressive': 0, 'hidden': 0};
      return EpochSchedule([Epoch.fromJson(e)]);
    }();

    GameState state(School? school) => GameState(groupCode: 'KENOMA-TESTE', balance: loadProgressBalance())..conjurer.school = school;

    WorldView view(GameState s) => WorldView(
          field: SpawnField(seed: seed, schedule: sch, map: map, typeOf: (id) => id.startsWith('soot') ? 'fire' : (id.startsWith('frond') ? 'plant' : 'water')),
          state: s,
          auraM: 10,
          viewM: 120,
          trackerM: 120,
          itemName: (i) => i,
          street: street,
          typeOf: (id) => id.startsWith('soot') ? 'fire' : (id.startsWith('frond') ? 'plant' : 'water'),
        );

    test('a Aura ganha +2 m só com a escola', () {
      final base = view(state(null)).auraRadiusM;
      expect(view(state(School.shaman)).auraRadiusM, closeTo(base + cb.shamanAuraBonusM, 1e-9));
      expect(cb.shamanAuraBonusM, 2);
      expect(view(state(School.sealer)).auraRadiusM, base);
      expect(view(state(School.technomancer)).auraRadiusM, base);
    });

    bool fledAtRunning(School? school) {
      const t0 = 1790040000;
      final probe = view(state(null));
      final eco = probe.field.around(lat: kCentroCampinas.$1, lon: kCentroCampinas.$2, tUtc: t0, radiusM: 500, playerLevel: 1).firstWhere((x) => x.isEco);
      final (la, lo) = tileFractionToLatLon(eco.x, eco.y, biomeZoom);
      final s = state(school);
      final v = view(s);
      var d = 70.0, t = t0;
      while (d > 5) {
        v.refresh(lat: la - d / 111320, lon: lo, tUtc: t++);
        d -= 6; // 6 m/s, bem acima dos 2,5 m/s do Arisco
      }
      return s.isDone(eco.uid);
    }

    test('o Arisco foge de quem corre, menos do Xamã', () {
      expect(fledAtRunning(null), isTrue);
      expect(fledAtRunning(School.sealer), isTrue);
      expect(fledAtRunning(School.shaman), isFalse);
    });
  });
}
