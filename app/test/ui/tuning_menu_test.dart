import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/data/tuning_data.dart';
import 'package:kenoma/dev/tuning_debug_menu.dart';
import 'package:kenoma/ui/tuning/tuning_screen.dart';

Future<void> pumpMenu(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  // Desmonta a árvore no fim, para o jogo Flame de um teste não vazar para o seguinte.
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  // O cache de assets guarda o Future do teste anterior, que morreu com a zona dele.
  // Recarregar na zona real deixa o menu carregar em qualquer teste.
  for (final name in ['balance', 'creatures', 'items']) {
    rootBundle.evict('assets/data/$name.json');
  }
  await tester.runAsync(TuningData.load);
  await tester.pumpWidget(const MaterialApp(home: TuningDebugMenu()));
  for (var i = 0; i < 50 && find.text('INICIAR SINTONIA').evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
}

Future<TuningScreen> start(WidgetTester tester) async {
  await tester.ensureVisible(find.text('INICIAR SINTONIA'));
  await tester.tap(find.text('INICIAR SINTONIA'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return tester.widget<TuningScreen>(find.byType(TuningScreen));
}

void main() {
  testWidgets('abre com Sootling, nível 1, selo simples, sem tônico', (tester) async {
    await pumpMenu(tester);
    expect(find.textContaining('Resistência 0.00'), findsOneWidget);
    expect(find.textContaining('Tolerância 0.080'), findsOneWidget);
    expect(find.textContaining('Tempo 20 s'), findsOneWidget);
    final screen = await start(tester);
    expect(screen.species.id, 'soot.eco');
    expect(screen.setup.type, EcoType.fire);
    expect(screen.setup.ecoLevel, 1);
    expect(screen.setup.playerLevel, 1);
    expect(screen.setup.seal.id, 'item.seal.simple');
    expect(screen.setup.tonic, isNull);
    expect(screen.showTarget, isFalse);
  });

  testWidgets('escolher o Rillet abre a sintonia com o Rillet, do tipo Água', (tester) async {
    await pumpMenu(tester);
    await tester.tap(find.text('Rillet'));
    await tester.pump();
    final screen = await start(tester);
    expect(screen.species.id, 'rill.eco');
    expect(screen.setup.type, EcoType.water);
  });

  testWidgets('escolher o Frondling abre a sintonia do tipo Planta', (tester) async {
    await pumpMenu(tester);
    await tester.tap(find.text('Frondling'));
    await tester.pump();
    final screen = await start(tester);
    expect(screen.species.id, 'frond.eco');
    expect(screen.setup.type, EcoType.plant);
  });

  testWidgets('o tônico soma o tempo do items.json e o rótulo vem do dado', (tester) async {
    await pumpMenu(tester);
    expect(find.text('Tônico (+5 s)'), findsOneWidget);
    await tester.tap(find.text('Tônico (+5 s)'));
    await tester.pump();
    expect(find.textContaining('Tempo 25 s'), findsOneWidget);
    final screen = await start(tester);
    expect(screen.setup.tonic, isNotNull);
    expect(screen.setup.timeLimitS(screen.balance), 25);
  });

  testWidgets('o alvo no dial é opcional', (tester) async {
    await pumpMenu(tester);
    await tester.tap(find.text('Mostrar alvo no dial'));
    await tester.pump();
    final screen = await start(tester);
    expect(screen.showTarget, isTrue);
  });

  testWidgets('o menu oferece a vibração de cada tipo para sentir de olhos fechados', (tester) async {
    await pumpMenu(tester);
    for (final label in ['FOGO', 'ÁGUA', 'PLANTA', 'FOGO: AVISO', 'ÁGUA: ONDA', 'PLANTA: PULSO']) {
      await tester.scrollUntilVisible(find.text(label), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
