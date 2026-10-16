import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/conjurer_balance.dart';
import 'package:kenoma/ui/school/school_flow.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();
  final cb = data.progress.conjurer;

  Future<void> tall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  Future<void> frames(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Faz um teste de escola até o fim e volta para a lista.
  Future<void> doTest(WidgetTester tester, School s) async {
    await tester.tap(find.descendant(of: find.byKey(Key('school-test-${s.id}')), matching: find.textContaining(RegExp('FAZER|REPETIR'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('COMEÇAR'));
    await tester.pump();
    switch (s) {
      case School.technomancer:
        await frames(tester, 170); // 15 s de cena a até 0,1 s por quadro
      case School.shaman:
        await frames(tester, 420); // parado até o tempo limite de 40 s: nota 0
      case School.sealer:
        final c = tester.getCenter(find.byKey(const Key('sealer-canvas')));
        final ref = tester.getSize(find.byKey(const Key('sealer-canvas'))).shortestSide / 2 * 0.55;
        final g = await tester.startGesture(c + Offset(ref, 0));
        for (var i = 1; i <= 60; i++) {
          final a = 2 * math.pi * i / 58;
          await g.moveTo(c + Offset(ref * math.cos(a), ref * math.sin(a)));
        }
        await g.up();
        await tester.pump();
    }
    expect(find.byKey(const Key('school-test-score')), findsOneWidget);
    await tester.tap(find.text('CONCLUIR'));
    await tester.pumpAndSettle();
  }

  testWidgets('todos os testes, a escolha com o Familiar comentando o melhor, e a confirmação definitiva', (tester) async {
    await tall(tester);
    final recorded = <School, int>{};
    final shown = <School>[];
    School? chosen;
    await tester.pumpWidget(MaterialApp(
      home: SchoolFlow(
        tests: cb.schoolTests,
        cb: cb,
        initialScores: const {},
        bestLine: (s) => data.mentor.byId('school_best_${s.id}')!.text,
        onRecord: (s, n) => recorded[s] = n,
        onChoiceShown: shown.add,
        onChoose: (s) {
          chosen = s;
          return true;
        },
      ),
    ));
    expect(find.text('ESCOLHER ESCOLA'), findsOneWidget);
    // Sem os três testes, o botão de escolher não faz nada.
    await tester.tap(find.text('ESCOLHER ESCOLA'));
    await tester.pump();
    expect(find.byKey(const Key('school-familiar-line')), findsNothing);

    // Qualquer ordem: Selador, Tecnomante e Xamã.
    await doTest(tester, School.sealer);
    await doTest(tester, School.technomancer);
    expect(recorded.keys, {School.sealer, School.technomancer});
    await doTest(tester, School.shaman);
    expect(recorded[School.shaman], 0);
    expect(recorded[School.sealer], greaterThan(80), reason: 'um círculo limpo em volta do Eco');

    await tester.tap(find.text('ESCOLHER ESCOLA'));
    await tester.pumpAndSettle();
    expect(shown, [School.sealer], reason: 'o melhor foi o Selador');
    expect(find.byKey(const Key('school-familiar-line')), findsOneWidget);
    expect(find.textContaining('costura'), findsWidgets, reason: 'a fala do Familiar sobre o sigilo');
    expect(find.textContaining('15%'), findsOneWidget, reason: 'o bônus do Selador, do balance.json');
    expect(find.textContaining('10%'), findsOneWidget);
    expect(find.textContaining('+2 m'), findsOneWidget);
    expect(find.text('CONFIRMAR'), findsOneWidget);

    // Sem escola marcada, confirmar não abre nada.
    await tester.tap(find.text('CONFIRMAR'));
    await tester.pump();
    expect(find.text('A escolha é definitiva até o nível 30.'), findsOneWidget, reason: 'só o aviso fixo da tela');

    await tester.tap(find.byKey(const Key('school-pick-technomancer')));
    await tester.pump();
    await tester.tap(find.text('CONFIRMAR'));
    await tester.pumpAndSettle();
    expect(find.text('A escolha é definitiva até o nível 30.'), findsNWidgets(2), reason: 'o diálogo repete o aviso');
    await tester.tap(find.byKey(const Key('school-cancel')));
    await tester.pumpAndSettle();
    expect(chosen, isNull);

    await tester.tap(find.text('CONFIRMAR'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('school-confirm')));
    await tester.pumpAndSettle();
    expect(chosen, School.technomancer, reason: 'a escolha é livre: não precisa ser a do melhor teste');
    expect(find.byType(SchoolFlow), findsNothing);
  });
}
