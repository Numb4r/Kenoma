import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/ui/tuning/tuning_screen.dart';

import 'run_logger_test.dart' show makeRun;

Future<void> pump(WidgetTester tester,
    {EcoType type = EcoType.fire, EcoType? guess, bool success = true, VoidCallback? onAgain, VoidCallback? onMenu}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: TuningResultPanel(
        run: makeRun(type: type, success: success),
        guess: guess,
        onAgain: onAgain ?? () {},
        onMenu: onMenu ?? () {},
      ),
    ),
  ));
}

void main() {
  testWidgets('sintonia normal: resultado, Repetir e Menu, sem revelar tipo nem palpite', (tester) async {
    await pump(tester);
    expect(find.text('SELADO!'), findsOneWidget);
    expect(find.textContaining('Ectoplasma'), findsOneWidget);
    expect(find.text('REPETIR'), findsOneWidget);
    expect(find.text('MENU'), findsOneWidget);
    expect(find.textContaining('Era '), findsNothing);
    expect(find.textContaining('Você'), findsNothing);
  });

  testWidgets('falha mostra o sinal perdido e se a criatura fugiu ou ficou', (tester) async {
    await pump(tester, success: false);
    expect(find.text('SINAL PERDIDO'), findsOneWidget);
    expect(find.textContaining(RegExp('fugiu|ainda está aqui')), findsOneWidget);
  });

  for (final (type, label) in [(EcoType.fire, 'Fogo'), (EcoType.water, 'Água'), (EcoType.plant, 'Planta')]) {
    testWidgets('modo oculto revela o tipo real: $label', (tester) async {
      await pump(tester, type: type, guess: type);
      expect(find.text('Era $label'), findsOneWidget);
    });
  }

  testWidgets('palpite certo: "Você acertou"', (tester) async {
    await pump(tester, type: EcoType.water, guess: EcoType.water);
    expect(find.text('Você acertou'), findsOneWidget);
    expect(find.textContaining('Você disse'), findsNothing);
  });

  testWidgets('palpite errado: diz o que o jogador tinha dito, e o tipo real continua à vista', (tester) async {
    await pump(tester, type: EcoType.plant, guess: EcoType.fire);
    expect(find.text('Você disse Fogo'), findsOneWidget);
    expect(find.text('Era Planta'), findsOneWidget);
    expect(find.text('Você acertou'), findsNothing);
  });

  testWidgets('não há mais Sim e Não: o palpite veio antes da sintonia', (tester) async {
    await pump(tester, guess: EcoType.fire);
    expect(find.text('SIM'), findsNothing);
    expect(find.text('NÃO'), findsNothing);
    expect(find.text('Você acertou o tipo?'), findsNothing);
  });

  testWidgets('Repetir e Menu chamam o que foi passado', (tester) async {
    var again = 0, menu = 0;
    await pump(tester, guess: EcoType.fire, onAgain: () => again++, onMenu: () => menu++);
    await tester.tap(find.text('REPETIR'));
    await tester.tap(find.text('MENU'));
    expect((again, menu), (1, 1));
  });

  group('tela do palpite', () {
    Future<(List<EcoType>, int)> pumpPrepare(WidgetTester tester) async {
      final guesses = <EcoType>[];
      var again = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(children: [
            HiddenPrepare(onFeelAgain: () => again++, onGuess: guesses.add),
          ]),
        ),
      ));
      return (guesses, again);
    }

    testWidgets('só o texto mínimo e os botões: nada da criatura, da onda ou do tempo', (tester) async {
      await pumpPrepare(tester);
      expect(find.text('Sinta o sinal'), findsOneWidget);
      expect(find.text('Qual é o tipo?'), findsOneWidget);
      expect(find.text('SENTIR DE NOVO'), findsOneWidget);
      expect(find.text('FOGO'), findsOneWidget);
      expect(find.text('ÁGUA'), findsOneWidget);
      expect(find.text('PLANTA'), findsOneWidget);
      expect(find.byType(CustomPaint).evaluate().where((e) => e.widget is CustomPaint && (e.widget as CustomPaint).painter != null), isEmpty);
    });

    testWidgets('cada botão entrega o tipo certo, e o fundo é o escuro do jogo', (tester) async {
      final (guesses, _) = await pumpPrepare(tester);
      await tester.tap(find.text('FOGO'));
      await tester.tap(find.text('ÁGUA'));
      await tester.tap(find.text('PLANTA'));
      expect(guesses, [EcoType.fire, EcoType.water, EcoType.plant]);
      final box = tester.widget<ColoredBox>(find.descendant(of: find.byType(HiddenPrepare), matching: find.byType(ColoredBox)).first);
      expect(box.color, const Color(0xFF1A1424));
    });

    testWidgets('"Sentir de novo" avisa quem toca a vibração', (tester) async {
      var again = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Stack(children: [HiddenPrepare(onFeelAgain: () => again++, onGuess: (_) {})])),
      ));
      await tester.tap(find.text('SENTIR DE NOVO'));
      await tester.tap(find.text('SENTIR DE NOVO'));
      expect(again, 2);
    });
  });
}
