import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/astro.dart';
import 'package:kenoma/core/weather.dart';
import 'package:kenoma/crafting/ritual.dart';
import 'package:kenoma/crafting/ritual_data.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/ui/menu/bestiary_screen.dart';
import 'package:kenoma/ui/ritual/ritual_screen.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();
  final soot = data.ritual.of('soot.ritual')!;
  const evening = WorldCondition(hour: 20, biome: 'urban', moon: MoonPhase.newMoon, weather: Weather.clear);

  GameState state({int level = 8}) {
    final s = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress)..levelOverride = level;
    for (final m in soot.materials) {
      s.add(m.item, m.qty);
    }
    s.collection.add(CreatureInstance(uid: 'water', speciesId: 'rill.eco', level: 6, capturedUtc: 1));
    s.toggleCircle('water');
    return s;
  }

  Future<void> open(WidgetTester tester, GameState s, {WorldCondition world = evening}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: RitualScreen(state: s, data: data, recipe: soot, uid: 7, level: 9, world: () => world, nowUtc: () => 1790040000),
    ));
    await tester.pump();
  }

  /// Põe [qty] unidades de [item] no espaço [slot] pela folha de material.
  Future<void> place(WidgetTester tester, int slot, String item, int qty) async {
    await tester.tap(find.byKey(Key('ritual-slot-$slot')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(Key('ritual-item-$item')));
    await tester.pump();
    for (var i = 1; i < qty; i++) {
      await tester.tap(find.byKey(const Key('ritual-plus')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('ritual-place')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> fill(WidgetTester tester, {String scrapItem = 'item.scrap'}) async {
    await place(tester, 1, scrapItem, 2);
    await place(tester, 2, 'item.essence.fire', 1);
    await place(tester, 3, 'item.chalk', 1);
    await tester.tap(find.byKey(Key('ritual-slot-${soot.circleIndex}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('ritual-member-water')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('sem pesquisa, todos os espaços aparecem como ???', (tester) async {
    await open(tester, state());
    for (var i = 0; i < soot.slotCount; i++) {
      expect(find.descendant(of: find.byKey(Key('ritual-slot-$i')), matching: find.text('???')), findsOneWidget, reason: 'espaço $i');
    }
    expect(find.textContaining('Agora: 20h'), findsOneWidget);
  });

  testWidgets('a pesquisa revela espaços na ordem: condição, materiais, Círculo', (tester) async {
    final s = state()..conjurer.ritualResearch['soot.ritual'] = 3;
    await open(tester, s);
    expect(find.descendant(of: find.byKey(const Key('ritual-slot-0')), matching: find.text('Entre 18h e 23h')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('ritual-slot-1')), matching: find.text('2× Sucata')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('ritual-slot-2')), matching: find.text('1× Essência de Fogo')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('ritual-slot-3')), matching: find.text('???')), findsOneWidget);
    expect(find.descendant(of: find.byKey(Key('ritual-slot-${soot.circleIndex}')), matching: find.text('???')), findsOneWidget);
  });

  testWidgets('abaixo do nível 8 o ritual está bloqueado', (tester) async {
    await open(tester, state(level: 7));
    expect(find.byKey(const Key('ritual-locked')), findsOneWidget);
    expect(find.byKey(const Key('ritual-go')), findsNothing);
  });

  testWidgets('combinação certa: o sigilo se fecha em ~2 s e a criatura entra na coleção', (tester) async {
    final s = state();
    await open(tester, s);
    await fill(tester);
    await tester.tap(find.byKey(const Key('ritual-go')));
    await tester.pump();
    expect(find.byKey(const Key('ritual-skip')), findsOneWidget);
    expect(find.byKey(const Key('ritual-sealed')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byKey(const Key('ritual-sealed')), findsNothing, reason: 'a animação ainda roda');
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.byKey(const Key('ritual-sealed')), findsOneWidget);
    expect(s.collection.any((c) => c.speciesId == 'soot.ritual' && c.level == 9), isTrue);
    expect(s.bestiary['soot.ritual']!.captured, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dá para pular a animação com um toque', (tester) async {
    await open(tester, state());
    await fill(tester);
    await tester.tap(find.byKey(const Key('ritual-go')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('ritual-stage')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('ritual-sealed')), findsOneWidget);
  });

  testWidgets('combinação errada: a criatura escapa, os materiais se perdem e a tela não diz o que errou', (tester) async {
    final s = state();
    await open(tester, s, world: evening.copyWith(hour: 9));
    await fill(tester);
    await tester.tap(find.byKey(const Key('ritual-go')));
    await tester.pump();
    expect(find.byKey(const Key('ritual-escaped')), findsOneWidget);
    expect(find.textContaining('hora'), findsNothing);
    expect(s.collection.any((c) => c.speciesId == 'soot.ritual'), isFalse);
    expect(s.isDone(7), isTrue);
    expect(s.count('item.scrap'), 0);
    await tester.tap(find.byKey(const Key('ritual-close')));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('Bestiário: a seção Ritual mostra ??? e o que a pesquisa revelou', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final s = state()
      ..markSeen('soot.ritual')
      ..conjurer.ritualResearch['soot.ritual'] = 2;
    await tester.pumpWidget(MaterialApp(home: BestiaryScreen(state: s, data: data)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('ritual-research-soot.ritual')), findsOneWidget);
    expect(find.text('Condição: Entre 18h e 23h'), findsOneWidget);
    expect(find.text('Material: 2× Sucata'), findsOneWidget);
    expect(find.text('Material: ???'), findsNWidgets(2));
    expect(find.text('Círculo: ???'), findsOneWidget);
    expect(find.byKey(const Key('ritual-research-frond.ritual')), findsNothing, reason: 'espécie não vista não mostra a receita');
    expect(ritualResearchUnseen(s), isFalse, reason: 'abrir a seção marca como visto');
  });
}
