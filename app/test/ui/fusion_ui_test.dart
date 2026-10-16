import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/ui/collection/collection_screen.dart';
import 'package:kenoma/ui/menu/bench_screen.dart';
import 'package:kenoma/ui/menu/fusion_animation.dart';
import 'package:kenoma/ui/menu/fusion_screen.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();
  const now = 1790040000;

  GameState make(int level, {int ecos = 5, int essence = 5}) {
    final s = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress, inventory: {'item.essence.fire': essence})..levelOverride = level;
    for (var i = 0; i < ecos; i++) {
      s.collection.add(CreatureInstance(uid: 'e$i', speciesId: 'soot.eco', level: 5 + i, capturedUtc: now, variant: i == 0 ? 'urban' : null));
    }
    return s;
  }

  Future<void> tall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  group('Bancada', () {
    testWidgets('antes do nível 6 a aba da fusão é um ??? e abre o aviso do nível', (tester) async {
      await tall(tester);
      await tester.pumpWidget(MaterialApp(home: BenchScreen(state: make(5), data: data)));
      await tester.pump();
      expect(find.text('FUSÃO'), findsNothing);
      await tester.tap(find.text('???'));
      await tester.pump();
      expect(find.byKey(const Key('fusion-locked')), findsOneWidget);
      expect(find.textContaining('NÍVEL 6'), findsOneWidget);
    });

    testWidgets('no nível 6 a aba mostra a fusão e o botão só liga com 5 Ecos escolhidos', (tester) async {
      await tall(tester);
      final s = make(6);
      await tester.pumpWidget(MaterialApp(home: BenchScreen(state: s, data: data)));
      await tester.pump();
      await tester.tap(find.text('FUSÃO'));
      await tester.pump();
      expect(find.byKey(const Key('fusion-locked')), findsNothing);
      expect(find.text('ECOS ESCOLHIDOS 0/5'), findsOneWidget);
      expect(find.byKey(const Key('fusion-summary')), findsNothing);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(Key('fusion-eco-e$i')));
        await tester.pump();
      }
      expect(find.text('ECOS ESCOLHIDOS 4/5'), findsOneWidget);
      expect(find.byKey(const Key('fusion-summary')), findsOneWidget);
      expect(find.text('ESCOLHA OS CINCO ECOS'), findsOneWidget);
      await tester.tap(find.byKey(const Key('fusion-eco-e4')));
      await tester.pump();
      expect(find.text('ECOS ESCOLHIDOS 5/5'), findsOneWidget);
      expect(find.textContaining('NÍVEL MÉDIO 7'), findsOneWidget);
      expect(find.textContaining('TRAÇOS 1/2'), findsOneWidget);
      expect(find.textContaining('Aura +5 m (faixa 1 de 3'), findsOneWidget);
      expect(find.byKey(const Key('fusion-circle-warning')), findsNothing);

      await tester.tap(find.byKey(const Key('fusion-button')));
      await tester.pump();
      expect(find.byKey(const Key('fusion-skip')), findsOneWidget, reason: 'a animação roda');
      await tester.tap(find.byKey(const Key('fusion-skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fusion-skip')), findsNothing);
      expect(s.collection.single.speciesId, 'soot.spirit');
      expect(s.count('item.essence.fire'), 0);
    });

    testWidgets('Eco no Círculo: aviso na tela e confirmação antes de fundir', (tester) async {
      await tall(tester);
      final s = make(6)..toggleCircle('e2');
      await tester.pumpWidget(MaterialApp(home: BenchScreen(state: s, data: data)));
      await tester.pump();
      await tester.tap(find.text('FUSÃO'));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(Key('fusion-eco-e$i')));
        await tester.pump();
      }
      expect(find.byKey(const Key('fusion-circle-warning')), findsOneWidget);
      await tester.tap(find.byKey(const Key('fusion-button')));
      await tester.pumpAndSettle();
      expect(find.text('ECO NO CÍRCULO'), findsOneWidget);
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();
      expect(s.collection, hasLength(5), reason: 'cancelar não gasta nada');
      expect(s.circle, ['e2']);
      await tester.tap(find.byKey(const Key('fusion-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FUNDIR').last);
      await tester.pump();
      await tester.tap(find.byKey(const Key('fusion-skip')));
      await tester.pumpAndSettle();
      expect(s.circle, isEmpty);
      expect(s.collection.single.speciesId, 'soot.spirit');
    });
  });

  group('animação', () {
    testWidgets('roda os 2 s sem erro e avisa uma vez no fim', (tester) async {
      var done = 0;
      await tester.pumpWidget(MaterialApp(home: FusionAnimation(eco: null, spirit: null, durationS: data.progress.conjurer.fusionAnimS, onDone: () => done++)));
      for (var ms = 0; ms < 1900; ms += 100) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(done, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(done, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(done, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('um toque pula na hora, uma vez só', (tester) async {
      var done = 0;
      await tester.pumpWidget(MaterialApp(home: FusionAnimation(eco: null, spirit: null, durationS: 2, onDone: () => done++)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('fusion-skip')));
      await tester.tap(find.byKey(const Key('fusion-skip')));
      await tester.pump(const Duration(seconds: 3));
      expect(done, 1);
    });
  });

  group('Coleção', () {
    testWidgets('mostra Poder, Habilidade e Traços do Eco e do Espírito', (tester) async {
      await tall(tester);
      final s = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress);
      s.collection
        ..add(const CreatureInstance(uid: 'a', speciesId: 'soot.eco', level: 10, capturedUtc: now, variant: 'urban'))
        ..add(const CreatureInstance(uid: 'b', speciesId: 'soot.spirit', level: 12, capturedUtc: now, traits: ['shiny', 'green']));
      await tester.pumpWidget(MaterialApp(home: CollectionScreen(state: s, data: data)));
      await tester.pump();
      expect(find.byKey(const Key('power-a')), findsOneWidget);
      expect(find.text('PODER 30'), findsOneWidget);
      expect(find.text('PODER 76'), findsOneWidget);
      expect(find.text('HABILIDADE AURA +5 M (FAIXA 2 DE 3: NÍVEIS 10 A 19)'), findsOneWidget);
      expect(find.text('HABILIDADE AURA +8 M (FAIXA 2 DE 3: NÍVEIS 10 A 19)'), findsOneWidget);
      expect(find.text('TRAÇOS 1/1'), findsOneWidget);
      expect(find.text('TRAÇOS 2/2'), findsOneWidget);
      expect(find.byKey(const Key('variant-a')), findsOneWidget);
      expect(find.byKey(const Key('trait-b-shiny')), findsOneWidget);
      expect(find.byKey(const Key('trait-b-green')), findsOneWidget);
    });
  });

  testWidgets('FusionPanel sozinho: família sem Ecos mostra o aviso', (tester) async {
    await tall(tester);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: FusionPanel(state: make(6, ecos: 0), data: data, sprites: const {})))));
    expect(find.text('NENHUM ECO DESTA FAMÍLIA NA COLEÇÃO.'), findsOneWidget);
  });
}
