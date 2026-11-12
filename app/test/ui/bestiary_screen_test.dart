import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/bestiary.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/ui/menu/bestiary/bestiary_widgets.dart';
import 'package:kenoma/ui/menu/bestiary_screen.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();
  const t = 1800000000;
  GameState state() => GameState(groupCode: 'KENOMA-TESTE', balance: data.progress)
    ..capture(uid: 1, speciesId: 'hum.eco', level: 3, nowUtc: t, biome: 'urban')
    ..markSeen('hum.eco', tags: seenTags(sunAltDeg: -30, climate: 'storm'))
    ..add('item.dust.electric', 2)
    ..markSeen('clod.eco')
    ..capture(uid: 2, speciesId: 'soot.eco', level: 3, nowUtc: t, variant: 'green');

  Future<GameState> open(WidgetTester tester, {Size size = const Size(1080, 2400), double dpr = 2.625}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    final s = state();
    await tester.pumpWidget(MaterialApp(home: BestiaryScreen(state: s, data: data)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return s;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('por família: o cartão tem a linha de fusão, a pesquisa em % e "Família ???" para quem nunca apareceu', (tester) async {
    await open(tester, size: const Size(1080, 12000));
    expect(find.text('HUM'), findsOneWidget);
    expect(find.text('SOOT'), findsOneWidget);
    expect(find.text('CLOD'), findsOneWidget, reason: 'o Pebblet foi visto');
    expect(find.text('FAMÍLIA ???'), findsNWidgets(9));
    final hum = find.byKey(const Key('family-hum'));
    for (final name in ['Arc Mote', 'Humoth', '???']) {
      expect(find.descendant(of: hum, matching: find.text(name)), findsOneWidget, reason: name);
    }
    for (final layer in ['FAGULHA', 'ECO', 'ESPÍRITO']) {
      expect(find.descendant(of: hum, matching: find.text(layer)), findsOneWidget);
    }
    expect(find.descendant(of: hum, matching: find.byType(KTick)), findsNWidgets(2), reason: 'Fagulha e Eco capturados');
    expect(find.descendant(of: find.byKey(const Key('family-clod')), matching: find.byType(KTick)), findsNothing, reason: 'vista, não capturada');
    expect(find.descendant(of: hum, matching: find.text('27%')), findsOneWidget, reason: '1 (Fagulha) + 2 (Eco) de 11 níveis');
    expect(find.byKey(const Key('bestiary-percent')), findsOneWidget);
    expect(find.byKey(const Key('form-soot.ritual')), findsOneWidget, reason: 'o Espírito de ritual das três do MVP');
  });

  testWidgets('a ficha de tipo filtra as famílias, e a busca acha por nome, tipo e lugar', (tester) async {
    await open(tester, size: const Size(1080, 12000));
    // As fichas de tipo rolam para o lado: a do Elétrico fica além da borda num celular de 411 dp.
    await tester.dragUntilVisible(find.byKey(const Key('chip-electric')), find.byKey(const Key('bestiary-chips')), const Offset(-120, 0));
    await tester.tap(find.byKey(const Key('chip-electric')));
    await tester.pump();
    expect(find.byType(FamilyCard), findsOneWidget);
    expect(find.byKey(const Key('family-hum')), findsOneWidget);
    await tester.dragUntilVisible(find.byKey(const Key('chip-all')), find.byKey(const Key('bestiary-chips')), const Offset(120, 0));
    await tester.tap(find.byKey(const Key('chip-all')));
    await tester.pump();
    expect(find.byType(FamilyCard), findsNWidgets(12));
    await tester.enterText(find.byKey(const Key('bestiary-search')), 'morros');
    await tester.pump();
    expect(find.byType(FamilyCard), findsOneWidget);
    expect(find.byKey(const Key('family-clod')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('bestiary-search')), 'coilkin');
    await tester.pump();
    expect(find.byType(FamilyCard), findsNothing, reason: 'o que nunca foi visto não se acha pelo nome');
    expect(find.text('Nada com esse filtro.'), findsOneWidget);
  });

  testWidgets('grade por camada, com o filtro numa folha: tipo, camada e estado', (tester) async {
    await open(tester, size: const Size(1080, 12000));
    await tester.tap(find.byKey(const Key('seg-1')));
    await tester.pump();
    expect(find.byKey(const Key('bestiary-grid')), findsOneWidget);
    expect(find.text('ECOS · 12'), findsOneWidget);
    expect(find.text('FAGULHAS · 12'), findsOneWidget);
    expect(find.text('ESPÍRITOS · 12'), findsOneWidget);
    expect(find.byType(SpeciesCell), findsNWidgets(39));
    await tester.tap(find.byKey(const Key('bestiary-filter')));
    await settle(tester);
    expect(find.byKey(const Key('filter-sheet')), findsOneWidget);
    expect(find.text('VER 39 FORMAS'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-type-electric')));
    await tester.pump();
    expect(find.text('VER 3 FORMAS'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-state-captured')));
    await tester.pump();
    expect(find.text('VER 2 FORMAS'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-apply')));
    await settle(tester);
    expect(find.byType(SpeciesCell), findsNWidgets(2));
    expect(find.byKey(const Key('cell-hum.eco')), findsOneWidget);
    expect(find.byKey(const Key('cell-item.dust.electric')), findsOneWidget);
    expect(find.text('FILTRAR · LIGADO'), findsOneWidget);
  });

  testWidgets('detalhe: quatro abas, a pesquisa com o próximo passo, setas entre as formas, Marcar e Fundir', (tester) async {
    final s = await open(tester, size: const Size(1080, 12000));
    await tester.tap(find.byKey(const Key('form-hum.eco')));
    await settle(tester);
    expect(find.byKey(const Key('detail-name')), findsOneWidget);
    expect(find.text('Humoth'), findsOneWidget);
    expect(find.text('FAMÍLIA HUM'), findsOneWidget);
    expect(find.text('NÍVEL DE PESQUISA 2 DE 5'), findsOneWidget);
    expect(find.text('Capturar uma vez'), findsOneWidget);
    expect(find.text('Sintonizar em 2 biomas · 1/2'), findsOneWidget, reason: 'o próximo passo mostra o quanto falta');
    expect(find.text('LORE I'), findsOneWidget);
    expect(find.text('+TOLERÂNCIA'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('where')), matching: find.text('Noite')), findsOneWidget, reason: 'o nível 2 libera onde aparece');
    expect(find.textContaining('Ronda postes e letreiros'), findsOneWidget, reason: 'a Lore I, do nível 1');
    await tester.tap(find.byKey(const Key('tab-1')));
    await tester.pump();
    expect(find.text('Mariposa de faísca que ronda postes e letreiros.'), findsOneWidget);
    expect(find.textContaining('Lore II: abre com a pesquisa no nível 3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-2')));
    await tester.pump();
    expect(find.text('Atributos reais abrem com a pesquisa no nível 3.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-3')));
    await tester.pump();
    expect(find.textContaining('salta entre duas ou três frequências'), findsOneWidget);
    expect(find.text('Forte contra: Água, Metal, Digital'), findsOneWidget);
    expect(find.text('Fraco contra: Terra'), findsOneWidget);
    // Marcar e Fundir.
    expect(find.text('FUNDIR 1/5'), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail-pin')));
    await tester.pump();
    expect(s.pinnedSpecies, 'hum.eco');
    expect(find.text('MARCADA'), findsOneWidget);
    // As setas: a forma anterior é a Fagulha e a seguinte, o Espírito (ainda ???).
    expect(find.text('< ARC MOTE'), findsOneWidget);
    expect(find.text('??? >'), findsOneWidget);
    await tester.tap(find.byKey(const Key('form-prev')));
    await tester.pump();
    expect(find.text('Arc Mote'), findsOneWidget);
    expect(find.text('COLETADA ×2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('form-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('form-next')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('detail-name'))).data, '???', reason: 'o Espírito nunca visto');
  });

  testWidgets('os atributos reais abrem no nível 3 da pesquisa, com as três faixas da habilidade', (tester) async {
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final s = state()..capture(uid: 9, speciesId: 'hum.eco', level: 3, nowUtc: t, biome: 'lit');
    await tester.pumpWidget(MaterialApp(home: BestiaryScreen(state: s, data: data)));
    await settle(tester);
    await tester.tap(find.byKey(const Key('form-hum.eco')));
    await settle(tester);
    expect(find.text('NÍVEL DE PESQUISA 3 DE 5'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-2')));
    await tester.pump();
    expect(find.text('Níveis 1 a 9: Radar +20 m'), findsOneWidget);
    expect(find.text('Níveis 10 a 19: Radar +40 m'), findsOneWidget);
    expect(find.text('Níveis 20+: Radar +60 m'), findsOneWidget);
    expect(find.text('FUNDIR 2/5'), findsOneWidget);
  });

  for (final (w, h) in const [(360.0, 800.0), (412.0, 915.0), (480.0, 1000.0)]) {
    testWidgets('cabe em ${w.round()}×${h.round()} sem estourar: famílias, grade com a folha de filtro e o detalhe', (tester) async {
      await open(tester, size: Size(w, h), dpr: 1);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('form-hum.eco')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('form-hum.eco')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      for (final tab in [1, 2, 3]) {
        await tester.tap(find.byKey(Key('tab-$tab')));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byKey(const Key('phone-back')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('seg-1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bestiary-filter')));
      await settle(tester);
      expect(find.byKey(const Key('filter-sheet')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
