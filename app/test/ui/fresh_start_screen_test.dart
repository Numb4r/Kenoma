import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/settings/fresh_start_screen.dart';

void main() {
  testWidgets('o botão só recomeça com RECOMEÇAR digitado, e exportar fica à mão', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    var confirms = 0, exports = 0;
    await tester.pumpWidget(MaterialApp(home: FreshStartScreen(onExport: () async => exports++, onConfirm: () async => confirms++)));
    expect(find.text('VAI SER APAGADO'), findsOneWidget);
    expect(find.text('FICA'), findsOneWidget);
    await tester.tap(find.byKey(const Key('fresh-start-go')));
    await tester.pump();
    expect(confirms, 0);
    await tester.enterText(find.byKey(const Key('fresh-start-word')), 'recomeca');
    await tester.tap(find.byKey(const Key('fresh-start-go')));
    await tester.pump();
    expect(confirms, 0, reason: 'a palavra tem de ser exata');
    await tester.enterText(find.byKey(const Key('fresh-start-word')), 'recomeçar');
    await tester.tap(find.byKey(const Key('fresh-start-go')));
    await tester.pump();
    expect(confirms, 1);
    await tester.tap(find.text('EXPORTAR BACKUP'));
    await tester.pump();
    expect(exports, 1);
  });
}
