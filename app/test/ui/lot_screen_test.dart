import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/crafting/conditions.dart' show Here;
import 'package:kenoma/crafting/lot_actions.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/ui/craft/craft_context.dart';
import 'package:kenoma/ui/lot/lot_painter.dart';
import 'package:kenoma/ui/lot/lot_screen.dart';

import '../support/fixtures.dart';

/// 0.29.0: a cena do lote abre, o modo construir põe uma peça na casa tocada e o botão de sair volta.
void main() {
  final data = loadGameData();
  const t0 = 1796000000;
  const home = (lat: -22.8936, lon: -47.0536);

  CraftContext ctx() => CraftContext(
        nowUtc: () => t0,
        here: () => const Here(utc: t0, lat: -22.8936, lon: -47.0536, sunAltDeg: 45, climate: 'clear'),
        hereAt: (lat, lon, t) => Here(utc: t, lat: lat, lon: lon, sunAltDeg: 45, climate: 'clear'),
      );

  testWidgets('abre o lote com o piso e a Bancada, constrói uma parede e sai', (tester) async {
    tester.view.physicalSize = const Size(945, 2100); // 360 dp
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final s = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress)
      ..levelOverride = 10
      ..home.cell = latLonToTile(home.lat, home.lon, biomeZoom)
      ..home.setUtc = t0
      ..home.storage['item.lot.wall'] = 2;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          key: const Key('go'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LotScreen(state: s, data: data, ctx: ctx(), animate: false))),
          child: const Text('ir'),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('go')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lot-scene')), findsOneWidget);
    expect(s.home.lot.started, isTrue, reason: 'o lote inicial entra ao abrir');
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('lot-build')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('lot-tab-wall')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('lot-piece-item.lot.wall')));
    await tester.pump();
    // A casa tocada: a câmera está no Conjurador; toque duas casas abaixo do meio (acima fica a Bancada).
    final scene = tester.getRect(find.byKey(const Key('lot-scene')));
    await tester.tapAt(scene.center.translate(0, 2 * kLotCellDp));
    await tester.pump();
    expect(s.home.lot.placed.where((p) => p.item == 'item.lot.wall'), hasLength(1));
    expect(find.text('1'), findsWidgets, reason: 'o contador da paleta baixou');
    expect(piecesLeft(s, 'item.lot.wall'), 1);

    await tester.tap(find.byKey(const Key('lot-exit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lot-scene')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
