import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/climate.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/ui/menu/sky_screen.dart';
import 'package:kenoma/ui/patrol/patrol_screen.dart';
import 'package:kenoma/ui/settings/connectivity_section.dart' show kPocketSetting;
import 'package:kenoma/world/climate_world.dart';
import 'package:kenoma/world/sky_outlook.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();

  Future<void> tall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  group('app Patrulha', () {
    GameState withHistory() {
      final s = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress);
      s.deliverMessage('patrol_summary', 1790000000, vars: {'min': 34, 'sparks': 12, 'materials': 2, 'marks': 3});
      s.deliverMessage('patrol_summary', 1790090000, vars: {'min': 60, 'sparks': 20, 'materials': 0, 'marks': 1});
      return s;
    }

    test('o histórico vem dos resumos do diário no Chat, do mais novo ao mais velho', () {
      final h = patrolHistory(withHistory());
      expect(h.map((p) => p.min), [60, 34]);
      expect((h.last.sparks, h.last.materials, h.last.marks), (12, 2, 3));
    });

    testWidgets('mostra as anteriores e o interruptor do modo bolso', (tester) async {
      await tall(tester);
      final s = withHistory();
      await tester.pumpWidget(MaterialApp(home: PatrolScreen(state: s, balance: data.patrol)));
      await tester.pump();
      expect(find.text('LIGAR A PATRULHA'), findsOneWidget);
      expect(find.textContaining('60 MIN · 20 FAGULHAS'), findsOneWidget);
      expect(find.textContaining('34 MIN · 12 FAGULHAS'), findsOneWidget);
      expect(s.setting(kPocketSetting), isFalse);
      await tester.tap(find.byKey(const Key('pocket-switch')));
      await tester.pump();
      expect(s.setting(kPocketSetting), isTrue);
    });
  });

  group('app Céu', () {
    final seed = seedGlobal('KENOMA-TESTE');
    final e6 = loadEpochs().epochs.firstWhere((e) => e.id == 6);
    final t0 = e6.startsUtc + 7 * 86400;
    ClimateWorld world({String? forced}) =>
        ClimateWorld(seed: seed, schedule: loadEpochs(), speciesOfType: data.ecoOfType, itemExists: data.itemNames.containsKey, forced: () => forced);

    test('as janelas seguem uma à outra, com o clima da célula, e o motivo quando um evento ou o debug força', () {
      final w = world();
      final sky = cellSkyOutlook(w, lat: () => -22.8174, lon: () => -47.0697);
      final list = sky(t0, 6);
      expect(list, hasLength(6));
      expect(list.first.startUtc <= t0 && t0 < list.first.endUtc, isTrue);
      for (var i = 1; i < list.length; i++) {
        expect(list[i].startUtc, list[i - 1].endUtc);
      }
      expect(list.every((x) => x.reason == null), isTrue, reason: 'sem evento, é o sorteio da estação');

      w.events = [ClimateEvent(climate: 'storm', startsUtc: list[2].startUtc, endsUtc: list[2].endUtc)];
      final withEvent = sky(t0, 6);
      expect(withEvent[2].climateId, 'storm');
      expect(withEvent[2].reason, isNotNull);
      expect(withEvent[0].reason, isNull);

      final forced = cellSkyOutlook(world(forced: 'rain'), lat: () => -22.8174, lon: () => -47.0697)(t0, 2);
      expect(forced.every((x) => x.climateId == 'rain' && x.reason != null), isTrue);
    });

    testWidgets('a tela mostra o clima de agora com o efeito no spawn, as próximas janelas e a lua', (tester) async {
      await tall(tester);
      final w = world(forced: 'storm');
      await tester.pumpWidget(MaterialApp(
        home: SkyScreen(
          nowUtc: () => t0,
          lat: () => -22.8,
          catalog: data.climates,
          shown: () => data.climates.of('storm'),
          outlook: cellSkyOutlook(w, lat: () => -22.8174, lon: () => -47.0697),
        ),
      ));
      await tester.pump();
      expect(find.byKey(const Key('sky-now')), findsOneWidget);
      expect(find.text('TEMPESTADE'), findsOneWidget);
      expect(find.byKey(const Key('sky-event')), findsOneWidget, reason: 'o clima forçado aparece como evento ativo, com o motivo');
      expect(find.textContaining('% ILUMINADA'), findsOneWidget);
    });

    testWidgets('sem a Rua viva o Céu mostra só a lua', (tester) async {
      await tall(tester);
      await tester.pumpWidget(MaterialApp(home: SkyScreen(nowUtc: () => t0, lat: () => -22.8, catalog: data.climates)));
      await tester.pump();
      expect(find.byKey(const Key('sky-now')), findsNothing);
      expect(find.byKey(const Key('sky-moon')), findsOneWidget);
    });
  });
}
