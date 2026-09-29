import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/ui/tuning/tuning_screen.dart';

import 'run_logger_test.dart' show makeRun;

Future<void> pump(WidgetTester tester,
    {required bool hidden,
    required bool marked,
    EcoType type = EcoType.fire,
    bool success = true,
    ValueChanged<bool>? onGuess,
    VoidCallback? onAgain,
    VoidCallback? onMenu}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: TuningResultPanel(
        run: makeRun(type: type, success: success),
        hidden: hidden,
        marked: marked,
        onGuess: onGuess ?? (_) {},
        onAgain: onAgain ?? () {},
        onMenu: onMenu ?? () {},
      ),
    ),
  ));
}

void main() {
  testWidgets('sintonia normal: resultado, Repetir e Menu, sem revelar tipo nem pedir palpite', (tester) async {
    await pump(tester, hidden: false, marked: false);
    expect(find.text('SELADO!'), findsOneWidget);
    expect(find.textContaining('Ectoplasma'), findsOneWidget);
    expect(find.text('REPETIR'), findsOneWidget);
    expect(find.text('MENU'), findsOneWidget);
    expect(find.textContaining('Era '), findsNothing);
    expect(find.text('SIM'), findsNothing);
  });

  testWidgets('falha mostra o sinal perdido e se a criatura fugiu ou ficou', (tester) async {
    await pump(tester, hidden: false, marked: false, success: false);
    expect(find.text('SINAL PERDIDO'), findsOneWidget);
    expect(find.textContaining(RegExp('fugiu|ainda está aqui')), findsOneWidget);
  });

  for (final (type, label) in [(EcoType.fire, 'Fogo'), (EcoType.water, 'Água'), (EcoType.plant, 'Planta')]) {
    testWidgets('tipo oculto revela o tipo real: $label', (tester) async {
      await pump(tester, hidden: true, marked: false, type: type);
      expect(find.text('Era $label'), findsOneWidget);
    });
  }

  testWidgets('tipo oculto sem marcação: pergunta se acertou e ainda não oferece Repetir', (tester) async {
    await pump(tester, hidden: true, marked: false);
    expect(find.text('Você acertou o tipo?'), findsOneWidget);
    expect(find.text('SIM'), findsOneWidget);
    expect(find.text('NÃO'), findsOneWidget);
    expect(find.text('REPETIR'), findsNothing);
    expect(find.text('MENU'), findsNothing);
  });

  testWidgets('Sim e Não devolvem o palpite certo', (tester) async {
    final answers = <bool>[];
    await pump(tester, hidden: true, marked: false, onGuess: answers.add);
    await tester.tap(find.text('SIM'));
    await tester.tap(find.text('NÃO'));
    expect(answers, [true, false]);
  });

  testWidgets('depois de marcar volta o Repetir e o Menu, e o tipo continua visível', (tester) async {
    var again = 0, menu = 0;
    await pump(tester, hidden: true, marked: true, type: EcoType.plant, onAgain: () => again++, onMenu: () => menu++);
    expect(find.text('Era Planta'), findsOneWidget);
    expect(find.text('SIM'), findsNothing);
    await tester.tap(find.text('REPETIR'));
    await tester.tap(find.text('MENU'));
    expect((again, menu), (1, 1));
  });
}
