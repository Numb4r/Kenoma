import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/crafting/crafting_state.dart';
import 'package:kenoma/crafting/quality.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/ui/craft/bag_screen.dart';
import 'package:kenoma/ui/craft/bench_screen.dart';
import 'package:kenoma/ui/craft/craft_context.dart';
import 'package:kenoma/ui/craft/loadout_screen.dart';

import '../support/fixtures.dart';

/// As telas da 0.24.0 com os dados reais: a Bolsa (abas, grade, detalhe e descarte), a Bancada (grupos, Experimentar) e o
/// Loadout (equipar e "mostrar no personagem").
void main() {
  final data = loadGameData();
  const t0 = 1795446000;
  final ctx = CraftContext.offline(() => t0);
  GameState state(Map<String, int> inv) => GameState(groupCode: 'KENOMA-TESTE', balance: data.progress, inventory: inv);

  Future<void> pump(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: w));
    await tester.pump();
  }

  testWidgets('a Bolsa: espaços usados, abas com contagem, pontos de qualidade e o descarte segurando o botão', (tester) async {
    final s = state({'item.chalk': 12, 'item.chalk@perfect': 1, 'item.seal.simple': 2, 'item.vessel.glass': 1});
    await pump(tester, BagScreen(state: s, data: data, ctx: ctx));
    expect(find.text('4/40'), findsOneWidget);
    expect(find.text('MATERIAIS 13'), findsOneWidget);
    expect(find.byKey(const Key('bag-cell-item.chalk@perfect')), findsOneWidget);
    expect(find.text('12'), findsOneWidget, reason: 'até 99, uma célula');
    await tester.tap(find.byKey(const Key('bag-tab-use')));
    await tester.pump();
    expect(find.byKey(const Key('bag-cell-item.seal.simple')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bag-tab-materials')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('bag-cell-item.chalk')));
    await tester.pumpAndSettle();
    expect(find.text('COMUM  ×12'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('+'));
      await tester.pump();
    }
    expect(find.text('RENDE 1 PÓ (1 A CADA 5)'), findsOneWidget);
    final hold = await tester.startGesture(tester.getCenter(find.byKey(const Key('discard-hold'))));
    await tester.pump(const Duration(milliseconds: 500));
    expect(s.count('item.chalk'), 13, reason: 'soltar antes não descarta');
    await tester.pump(const Duration(milliseconds: 700));
    await hold.up();
    await tester.pump();
    expect(s.countQ('item.chalk', Quality.common), 7);
  });

  testWidgets('uma pilha de mais de 99 vira uma célula por pilha, como os espaços contam', (tester) async {
    final s = state({'item.dust.fire': 230});
    await pump(tester, BagScreen(state: s, data: data, ctx: ctx));
    expect(find.text('3/40'), findsOneWidget);
    expect(find.text('99'), findsNWidgets(2));
    expect(find.text('32'), findsOneWidget);
  });

  testWidgets('a aba Condições planta a pé e recusa sem GPS', (tester) async {
    final s = state({'item.vessel.glass': 2});
    await pump(tester, BagScreen(state: s, data: data, ctx: ctx));
    await tester.tap(find.byKey(const Key('bag-tab-conditions')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('plant-item.vessel.glass')));
    await tester.pump();
    expect(s.crafting.at(VesselPlace.planted), isEmpty, reason: 'sem GPS não se sabe se é a pé');
    final walking = CraftContext(nowUtc: ctx.nowUtc, here: ctx.here, hereAt: ctx.hereAt, speedMps: () => 1.2);
    await pump(tester, BagScreen(state: s, data: data, ctx: walking));
    await tester.tap(find.byKey(const Key('bag-tab-conditions')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('plant-item.vessel.glass')));
    await tester.pump();
    expect(s.crafting.at(VesselPlace.planted), hasLength(1));
    expect(find.byKey(Key('planted-${s.crafting.vessels.single.uid}')), findsOneWidget);
  });

  testWidgets('a Bancada mostra o que dá agora e o Experimentar não gasta nada', (tester) async {
    final s = state({'item.chalk': 2, 'item.ectoplasm': 2, 'item.herbs': 1});
    await pump(tester, CraftBenchScreen(state: s, data: data, ctx: ctx));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recipe-recipe.seal.simple')), findsOneWidget);
    expect(find.text('AGORA, AQUI'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bench-experiment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('experiment-slot-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('experiment-pick-item.herbs')));
    await tester.pump();
    final before = {...s.inventory};
    await tester.tap(find.byKey(const Key('experiment-try')));
    await tester.pump();
    expect(find.byKey(const Key('experiment-result')), findsOneWidget);
    expect(s.inventory, before);
  });

  testWidgets('no último passo da quest, a Bancada marca o tônico e abre no caminho da Água de chuva', (tester) async {
    final s = state({'item.herbs': 2, 'item.pure_water': 1})
      ..add('item.glass_shard', 1) // liga a quest
      ..crafting.known.add('recipe.tonic.focus'); // o caminho antigo, de Água pura, também conhecido
    s.crafting.vessels.add(Vessel(uid: 1, kind: 'item.vessel.glass', place: VesselPlace.belt, content: 'item.rain_water', quality: Quality.good));
    s.recordEvent('vessel_made', '', 1);
    s.recordEvent('vessel_filled', '', 1);
    await pump(tester, CraftBenchScreen(state: s, data: data, ctx: ctx));
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('recipe-recipe.tonic.focus'));
    await tester.scrollUntilVisible(row, 300);
    expect(find.descendant(of: row, matching: find.byKey(const Key('tutorial-mark'))), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('CAMINHO 2'), findsOneWidget);
    expect(find.text('1/1'), findsWidgets, reason: 'a Água de chuva do cinto conta');
    expect(find.text('ÁGUA DE CHUVA'), findsOneWidget, reason: 'abriu no caminho da chuva');
  });

  testWidgets('o Loadout equipa a bolsa, soma o efeito e esconde do personagem', (tester) async {
    final bag = data.craft.items.values.firstWhere((i) => i.kind == 'bag');
    final s = state({bag.id: 1});
    await pump(tester, LoadoutScreen(state: s, data: data, nowUtc: () => t0));
    await tester.tap(find.text('TROCAR').first);
    await tester.pump();
    await tester.tap(find.byKey(Key('loadout-pick-${bag.id}')));
    await tester.pump();
    expect(s.crafting.equipped[LoadoutSlot.bag], bag.id);
    await tester.scrollUntilVisible(find.byKey(const Key('loadout-effect-bag_slots')), 200);
    expect(find.byKey(const Key('loadout-effect-bag_slots')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('loadout-show-bag')), -200);
    await tester.tap(find.byKey(const Key('loadout-show-bag')));
    await tester.pump();
    expect(s.crafting.hidden, contains(LoadoutSlot.bag));
  });

  /// Abre [w] por cima de uma tela vazia, como o celular faz: o Voltar tem para onde ir.
  Future<void> pushed(WidgetTester tester, Widget w) async {
    await pump(tester, Builder(builder: (context) => TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w)), child: const Text('abrir'))));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('0.24.4: no Loadout, Voltar com a lista de troca aberta fecha só a lista; o segundo sai da tela', (tester) async {
    final bag = data.craft.items.values.firstWhere((i) => i.kind == 'bag');
    await pushed(tester, LoadoutScreen(state: state({bag.id: 1}), data: data, nowUtc: () => t0));
    await tester.tap(find.text('TROCAR').first);
    await tester.pump();
    expect(find.byKey(Key('loadout-pick-${bag.id}')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(Key('loadout-pick-${bag.id}')), findsNothing);
    expect(find.byType(LoadoutScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(LoadoutScreen), findsNothing);
  });

  testWidgets('0.24.4: no Experimentar, Voltar com a escolha de material aberta fecha só a escolha', (tester) async {
    await pushed(tester, CraftBenchScreen(state: state({'item.herbs': 1}), data: data, ctx: ctx));
    await tester.tap(find.byKey(const Key('bench-experiment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('experiment-slot-0')));
    await tester.pump();
    expect(find.byKey(const Key('experiment-pick-item.herbs')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('experiment-pick-item.herbs')), findsNothing);
    expect(find.byKey(const Key('experiment-slot-0')), findsOneWidget, reason: 'o experimento continua aberto');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('experiment-slot-0')), findsNothing);
    expect(find.byType(CraftBenchScreen), findsOneWidget, reason: 'volta à Bancada');
  });
}
