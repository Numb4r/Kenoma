import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/ui/game/pocket_overlay.dart';
import 'package:kenoma/world/pocket_mode.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/world_view.dart';

import '../support/fixtures.dart';

void main() {
  testWidgets('debounce de 300 ms: leitura que dura vira estado, piscada não', (tester) async {
    final m = PocketMode();
    var changes = 0;
    m.addListener(() => changes++);
    m.onProximity(true);
    await tester.pump(const Duration(milliseconds: 200));
    expect(m.covered, isFalse);
    m.onProximity(false); // piscou: volta ao estado atual antes dos 300 ms
    await tester.pump(const Duration(milliseconds: 400));
    expect((m.covered, changes), (false, 0));
    m.onProximity(true);
    await tester.pump(const Duration(milliseconds: 300));
    expect((m.covered, changes), (true, 1));
    m.onProximity(true); // repetido: nada
    m.onProximity(false);
    await tester.pump(const Duration(milliseconds: 299));
    expect(m.covered, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect((m.covered, changes), (false, 2));
    m.dispose();
  });

  testWidgets('reset descobre na hora', (tester) async {
    final m = PocketMode(debounce: Duration.zero)..onProximity(true);
    await tester.pump(const Duration(milliseconds: 1));
    expect(m.covered, isTrue);
    m.reset();
    expect(m.covered, isFalse);
  });

  test('só vibra com o modo ligado e coberto', () {
    expect([for (final e in [false, true]) for (final c in [false, true]) shouldBuzz(enabled: e, covered: c)], [false, false, false, true]);
  });

  group('sobreposição', () {
    Widget host(PocketMode m, bool Function() enabled, {VoidCallback? onTap}) => Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(children: [
            GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: const SizedBox.expand()),
            PocketOverlay(mode: m, enabled: enabled),
          ]),
        );

    testWidgets('coberto e ligado: preto a 95% que absorve o toque; descoberto: some', (tester) async {
      final m = PocketMode(debounce: Duration.zero);
      var taps = 0;
      await tester.pumpWidget(host(m, () => true, onTap: () => taps++));
      expect(find.byKey(const ValueKey('pocket-dark')), findsNothing);
      m.onProximity(true);
      await tester.pump(const Duration(milliseconds: 1));
      final box = tester.widget<ColoredBox>(find.byKey(const ValueKey('pocket-dark')));
      expect(box.color.a, closeTo(0.95, 0.005));
      expect(box.color.r + box.color.g + box.color.b, 0);
      await tester.tapAt(const Offset(10, 10));
      expect(taps, 0);
      m.onProximity(false);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(const ValueKey('pocket-dark')), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      expect(taps, 1);
    });

    testWidgets('modo desligado: coberto não escurece', (tester) async {
      final m = PocketMode(debounce: Duration.zero)..onProximity(true);
      await tester.pumpWidget(host(m, () => false));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(const ValueKey('pocket-dark')), findsNothing);
    });
  });

  test('WorldView.onEnteredRange: uma vez por entrada no alcance de toque', () {
    const t0 = 1790035200 + 86400;
    final state = GameState.fresh(groupCode: 'KENOMA-TESTE', startInventory: {}, balance: loadProgressBalance());
    final view = WorldView(
      field: SpawnField(seed: seedGlobal('KENOMA-TESTE'), schedule: loadEpochs(), map: RegionMap(pack: loadCampinasPack(), biomes: loadBiomes())),
      state: state,
      touchRangeM: 30,
      auraM: 40,
      viewM: 120,
      itemName: (id) => id,
      street: loadStreetBalance(),
    );
    final eco = view.field.around(lat: -22.9056, lon: -47.0608, tUtc: t0, radiusM: 400, playerLevel: 1).firstWhere((s) => s.isEco);
    final (la, lo) = tileFractionToLatLon(eco.x, eco.y, biomeZoom);
    final entered = <int>[];
    view.onEnteredRange = (e) => entered.add(e.uid);
    view.refresh(lat: la + 200 / 111320, lon: lo, tUtc: t0);
    expect(entered, isEmpty);
    view.refresh(lat: la, lon: lo, tUtc: t0);
    view.refresh(lat: la, lon: lo, tUtc: t0 + 1);
    expect(entered.where((u) => u == eco.uid), hasLength(1));
  });
}
