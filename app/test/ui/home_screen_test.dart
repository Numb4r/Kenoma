import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/crafting/conditions.dart' show Here;
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/ui/craft/craft_context.dart';
import 'package:kenoma/ui/menu/home_screen.dart';

import '../support/fixtures.dart';

/// 0.28.0: o app Casa sem casa, dentro do raio e fora dele.
void main() {
  final data = loadGameData();
  const t0 = 1796000000;
  const home = (lat: -22.8936, lon: -47.0536), far = (lat: -22.9056, lon: -47.0608);
  var at = home;

  CraftContext ctx() => CraftContext(
        nowUtc: () => t0 + 9 * 3600,
        here: () => Here(utc: t0, lat: at.lat, lon: at.lon, sunAltDeg: 45, climate: 'clear'),
        hereAt: (lat, lon, t) => Here(utc: t, lat: lat, lon: lon, sunAltDeg: 45, climate: 'clear'),
      );

  GameState make() => GameState(groupCode: 'KENOMA-TESTE', balance: data.progress)
    ..levelOverride = 10
    ..collection.add(const CreatureInstance(uid: 'e1', speciesId: 'frond.eco', level: 1, capturedUtc: t0));

  Future<void> open(WidgetTester tester, GameState s) async {
    tester.view.physicalSize = const Size(945, 2100); // 360 dp
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox()); // tela nova, do topo
    await tester.pumpWidget(MaterialApp(home: HomeScreen(state: s, data: data, ctx: ctx())));
    await tester.pump();
  }

  testWidgets('sem casa: define a casa aqui, com a confirmação', (tester) async {
    at = home;
    final s = make();
    await open(tester, s);
    expect(find.byKey(const Key('home-none')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-set')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-set-yes')));
    await tester.pumpAndSettle();
    expect(s.home.cell, latLonToTile(home.lat, home.lon, biomeZoom));
    expect(find.byKey(const Key('home-station-garden')), findsOneWidget);
    expect(find.byKey(const Key('home-away')), findsNothing);
  });

  testWidgets('em casa: põe para trabalhar, a horta enche e recolhe; fora, só o estado e o aviso', (tester) async {
    at = home;
    final s = make()
      ..home.cell = latLonToTile(home.lat, home.lon, biomeZoom)
      ..home.setUtc = t0;
    await open(tester, s);
    await tester.ensureVisible(find.byKey(const Key('home-assign-garden')));
    await tester.tap(find.byKey(const Key('home-assign-garden')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('home-pick-e1')));
    await tester.pump();
    expect(s.home.stations['garden']!.workers, ['e1']);
    s.home.stations['garden']!.since['e1'] = t0; // 9 h antes do relógio da tela
    s.changed();
    await tester.pump();
    expect(find.text('3/8'), findsOneWidget);

    at = far;
    await open(tester, s);
    expect(find.byKey(const Key('home-away')), findsOneWidget);
    expect(find.text('3/8'), findsOneWidget, reason: 'longe, a tela mostra o que a horta fez');
    expect(find.byKey(const Key('home-collect-garden')), findsNothing, reason: 'e nenhum botão que mexe');
    expect(find.byKey(const Key('home-from-bag')), findsNothing);

    at = home;
    await open(tester, s);
    await tester.ensureVisible(find.byKey(const Key('home-collect-garden')));
    await tester.tap(find.byKey(const Key('home-collect-garden')));
    await tester.pump();
    expect(s.home.storage['item.herbs'], 3);
    expect(tester.takeException(), isNull);
  });
}
