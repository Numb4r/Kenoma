import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/travel/deep_links.dart';
import 'package:kenoma/travel/travel_balance.dart';
import 'package:kenoma/travel/travel_session.dart';
import 'package:kenoma/ui/settings/ride_notifications_screen.dart';
import 'package:kenoma/ui/travel/routes_screen.dart';
import 'package:kenoma/world/traffic_graph.dart';

import '../support/fixtures.dart';

void main() {
  late TravelSession travel;
  var pickedOnMap = 0;

  Widget app() {
    final data = loadGameData();
    final state = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress);
    travel = TravelSession(
      state: state,
      balance: data.travel,
      graph: TrafficGraph(loadTile: (_, _) => null, cellsPerTile: 64, extent: 4096),
      patterns: data.ridePatterns,
      radioLines: data.mentor.radio,
      sparkItem: (_, _, _) => null,
      ecosInReach: () => const [],
      nowUtc: () => 1800000000,
    );
    return MaterialApp(
      home: RoutesScreen(
        travel: travel,
        state: state,
        data: data,
        appVersion: 'test',
        playerLat: () => -22.9,
        playerLon: () => -47.0,
        onMessage: (_, {seconds = 2}) {},
        onPickOnMap: () => pickedOnMap++,
      ),
    );
  }

  setUp(() => pickedOnMap = 0);

  testWidgets('do app Rotas ao fim da viagem, de passageiro', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('travel-hud')));
    await tester.pump();
    expect(travel.stage, TravelStage.pickDestination);
    expect(find.text('BUSCAR'), findsOneWidget);
    await tester.tap(find.byKey(const Key('travel-pick-map')));
    expect(pickedOnMap, 1, reason: 'o destino no mapa fecha o celular');

    travel.tapCell(1000, 2000);
    await tester.pump();
    for (final v in Vehicle.values) {
      expect(find.text(v.label.toUpperCase()), findsOneWidget);
    }

    await tester.tap(find.text('CARRO'));
    await tester.pump();
    await tester.pump();
    expect(find.text('SOU PASSAGEIRO'), findsOneWidget);
    expect(find.text('CHAMAR UBER'), findsNothing, reason: 'sem o app instalado o botão não aparece');

    await tester.tap(find.text('SOU PASSAGEIRO'));
    await tester.pump();
    expect(find.text('RÁDIO DO VÉU'), findsOneWidget);

    await tester.tap(find.text('ENCERRAR'));
    await tester.pump();
    expect(travel.stage, TravelStage.idle);
    expect(find.byKey(const Key('travel-hud')), findsOneWidget);
  });

  testWidgets('quem dirige não vê o Rádio', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    travel.open();
    travel.tapCell(1000, 2000);
    travel.chooseVehicle(Vehicle.car);
    travel.answerPassenger(false);
    await tester.pump();
    expect(find.text('RÁDIO DO VÉU'), findsNothing);
    expect(find.textContaining('VIAGEM GRAVADA'), findsOneWidget);
  });

  testWidgets('a corrida pelos botões mostra o tempo, Entrei e Cheguei', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    travel.open();
    travel.tapCell(1000, 2000);
    travel.chooseVehicle(Vehicle.car);
    travel.startRide('Uber', kUberPackage);
    await tester.pump();
    expect(find.text('ENTREI'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.textContaining('CHEGA EM'), findsOneWidget);
    await tester.tap(find.text('ENTREI'));
    await tester.pump();
    expect(find.text('CHEGUEI'), findsOneWidget);
    expect(find.text('RÁDIO DO VÉU'), findsOneWidget);
  });

  testWidgets('a tela dos Ajustes explica o que lê e liga o interruptor', (tester) async {
    final state = GameState(groupCode: 'KENOMA-TESTE', balance: loadProgressBalance());
    await tester.pumpWidget(MaterialApp(home: RideNotificationsScreen(state: state)));
    await tester.pump();
    expect(find.textContaining('Só Uber e 99'), findsOneWidget);
    expect(find.textContaining('Permitir configurações restritas'), findsOneWidget);
    expect(state.setting(kRideNotifySetting), isFalse);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(state.setting(kRideNotifySetting), isTrue);
  });
}
