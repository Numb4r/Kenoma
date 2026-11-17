import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/colors.dart';
import 'package:kenoma/ui/game/hud_bar.dart';

/// 0.23.1: com a tela cheia a barra de status some, e a bateria vai para o HUD, ao lado da hora.
void main() {
  Future<void> pump(WidgetTester tester, Future<int?> Function()? battery) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 360, height: 40, child: HudBar(nowUtc: () => 1792080000, lat: () => -22.9, seal: const SizedBox(width: 40), battery: battery)),
      ),
    ));
    await tester.pump();
  }

  testWidgets('mostra a carga ao lado da hora, em Essência com 20% ou menos', (tester) async {
    await pump(tester, () async => 64);
    expect(find.text('64%'), findsOneWidget);
    expect(find.byKey(const Key('hud-battery')), findsOneWidget);
    final clock = tester.getRect(find.byKey(const Key('hud-clock'))), bat = tester.getRect(find.byKey(const Key('hud-battery')));
    expect(bat.left, greaterThan(clock.right), reason: 'logo depois da hora');
    await tester.pumpWidget(const SizedBox()); // outra barra: lê a bateria ao abrir
    await pump(tester, () async => 15);
    expect(tester.widget<Text>(find.text('15%')).style!.color, kEssence);
  });

  testWidgets('sem leitura (emulador, testes), sem indicador', (tester) async {
    await pump(tester, () async => null);
    expect(find.byKey(const Key('hud-battery')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await pump(tester, null);
    expect(find.byKey(const Key('hud-battery')), findsNothing);
  });
}
