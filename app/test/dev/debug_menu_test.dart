import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/behavior.dart';
import 'package:kenoma/core/weather.dart';
import 'package:kenoma/world/fog.dart';
import 'package:kenoma/dev/debug_capture.dart';
import 'package:kenoma/dev/debug_env.dart';
import 'package:kenoma/dev/debug_items.dart';
import 'package:kenoma/dev/debug_items_save.dart';
import 'package:kenoma/dev/debug_menu_view.dart';
import 'package:kenoma/dev/debug_prefs.dart';
import 'package:kenoma/dev/debug_registry.dart';
import 'package:kenoma/dev/debug_tag.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fake_position_source.dart';

/// Os ids das funções que o menu de debug tinha antes da reorganização (e as de save, que o menu ganhou). Se algum
/// sumir do registro, o menu perdeu uma função: este teste falha.
const originalIds = [
  'pos.simulator', 'pos.speed', 'pos.noise', 'pos.joystick', 'pos.teleport', //
  'time.clock', 'time.weather',
  'spawn.behavior', 'spawn.variant', 'spawn.shiny', 'spawn.clear',
  'map.open_game', 'map.biome_grid', 'map.grid20', 'map.radii', 'map.fog_reveal', 'map.fog_clear', 'map.radar_reset', 'map.free',
  'player.level',
  'cap.species', 'cap.levels', 'cap.seal', 'cap.options', 'cap.start', 'cap.log', 'cap.vibration',
  'sign.identity',
  'perf.tap_latency',
  'save.export', 'save.import', 'save.migrate', 'save.delete',
];

DebugEnv newEnv({DevTools? tools, SaveStore? save}) =>
    DebugEnv(tools: tools ?? DevTools(realSource: FakeGps()), capture: CaptureDebug(), saveStore: save ?? MemorySaveStore());

Future<DebugRegistry> pumpMenu(WidgetTester tester, DebugPrefs prefs, {DebugEnv? env, DebugRegistry? registry}) async {
  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final reg = registry ?? buildDefaultRegistry(env ?? newEnv());
  await tester.pumpWidget(MaterialApp(home: DebugMenuView(registry: reg, prefs: prefs)));
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  return reg;
}

bool shown(String id) => find.byKey(Key('item-$id')).evaluate().isNotEmpty;

void main() {
  test('todos os ids originais continuam registrados, sem repetir, e cada item cabe numa seção do menu', () {
    final reg = buildDefaultRegistry(newEnv());
    final ids = reg.items.map((i) => i.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'ids repetidos');
    expect(reg.ids.toList()..sort(), containsAll(originalIds));
    expect(originalIds.where((id) => !reg.ids.contains(id)), isEmpty);
    expect(reg.items.every((i) => i.section != DebugSection.favorites), isTrue);
  });

  test('as seções vêm na ordem pedida', () {
    expect(DebugSection.values.map((s) => s.title), [
      'Favoritos', 'Posição', 'Tempo e mundo', 'Spawns', 'Mapa e câmera', 'Tráfego', 'Jogador', 'Captura', 'Assinaturas', 'Desempenho', 'Save',
    ]);
  });

  test('a busca ignora acento e caixa e acha por palavra-chave', () {
    final reg = buildDefaultRegistry(newEnv());
    expect(reg.search('RELOGIO').map((i) => i.id), contains('time.clock'));
    expect(reg.search('chuva').map((i) => i.id), ['time.weather']);
    expect(reg.search('nivel conjurador').map((i) => i.id), contains('player.level'));
    expect(reg.search('zzzz'), isEmpty);
  });

  testWidgets('a busca filtra os itens na tela e limpar a busca volta às seções', (tester) async {
    await pumpMenu(tester, DebugPrefs());
    await tester.enterText(find.byKey(const Key('debug-search')), 'teleporte');
    await tester.pump();
    expect(shown('pos.teleport'), isTrue);
    expect(shown('pos.speed'), isFalse);
    expect(shown('time.clock'), isFalse);
    await tester.enterText(find.byKey(const Key('debug-search')), 'nada disso existe');
    await tester.pump();
    expect(find.text('Nenhum item com essa busca.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('debug-search')), '');
    await tester.pump();
    expect(find.byKey(const Key('section-posicao')), findsOneWidget);
  });

  testWidgets('as seções recolhem e abrem, e o estado volta de um arquivo', (tester) async {
    final dir = Directory.systemTemp.createTempSync('kenoma_dbg_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/debug_menu.json');
    final prefs = DebugPrefs(file: file);
    final reg = await pumpMenu(tester, prefs);
    expect(shown('pos.teleport'), isFalse, reason: 'começa fechada');
    await tester.tap(find.byKey(const Key('section-posicao')));
    await tester.pump();
    expect(shown('pos.teleport'), isTrue);
    await tester.tap(find.byKey(const Key('section-spawns')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('section-spawns')));
    await tester.pump();
    expect(shown('spawn.clear'), isFalse);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));

    final restored = DebugPrefs(file: file);
    await tester.runAsync(restored.load);
    expect((restored.isOpen(DebugSection.position), restored.isOpen(DebugSection.spawns), restored.isOpen(DebugSection.time)), (true, false, false));
    await tester.pumpWidget(MaterialApp(home: DebugMenuView(registry: reg, prefs: restored)));
    expect(shown('pos.teleport'), isTrue);
    expect(shown('time.clock'), isFalse);
  });

  testWidgets('a estrela fixa o item nos Favoritos e os favoritos voltam de um arquivo', (tester) async {
    final dir = Directory.systemTemp.createTempSync('kenoma_dbg_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/debug_menu.json');
    final prefs = DebugPrefs(file: file, defaultOpen: true);
    final reg = await pumpMenu(tester, prefs);
    expect(find.textContaining('Nenhum favorito'), findsOneWidget);
    await tester.tap(find.byKey(const Key('star-time.clock')));
    await tester.pump();
    expect(prefs.favorites, ['time.clock']);
    expect(find.textContaining('Nenhum favorito'), findsNothing);
    expect(find.byKey(const Key('item-time.clock')), findsOneWidget, reason: 'o item sai da seção e aparece só nos Favoritos');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));

    final restored = DebugPrefs(file: file);
    await tester.runAsync(restored.load);
    expect(restored.favorites, ['time.clock']);
    await tester.pumpWidget(MaterialApp(home: DebugMenuView(registry: reg, prefs: restored)));
    expect(shown('time.clock'), isTrue, reason: 'Favoritos abre sozinho');
    await tester.tap(find.byKey(const Key('star-time.clock')));
    await tester.pump();
    expect(restored.favorites, isEmpty);
  });

  test('sem disco o menu funciona e só não lembra', () async {
    final prefs = DebugPrefs(file: File('/caminho/que/nao/existe/debug_menu.json'));
    await prefs.load();
    await prefs.toggleFavorite('time.clock');
    await prefs.setOpen(DebugSection.map, true);
    expect(prefs.favorites, ['time.clock']);
    expect(prefs.isOpen(DebugSection.map), isTrue);
    final corrupt = File('${Directory.systemTemp.createTempSync('kenoma_dbg_').path}/x.json')..writeAsStringSync('{lixo');
    final p2 = DebugPrefs(file: corrupt);
    await p2.load();
    expect(p2.favorites, isEmpty);
  });

  testWidgets('seção sem itens diz "sem itens ainda" e um item registrado depois aparece nela', (tester) async {
    final reg = buildDefaultRegistry(newEnv());
    final prefs = DebugPrefs(defaultOpen: true);
    await pumpMenu(tester, prefs, registry: reg);
    expect(find.text('sem itens ainda'), findsOneWidget, reason: 'Tráfego');
    reg.add(DebugItem(id: 'traffic.test', title: 'Item novo', section: DebugSection.traffic, keywords: const ['novo'], builder: (_) => const Text('corpo do item novo')));
    await pumpMenu(tester, prefs, registry: reg);
    expect(find.text('corpo do item novo'), findsOneWidget);
    expect(find.text('sem itens ainda'), findsNothing);
  });

  group('apagar save', () {
    testWidgets('o botão só habilita com APAGAR exato e então apaga', (tester) async {
      final store = MemorySaveStore()..json = {'schema_version': 4, 'group_code': 'AAAAA-BBBBB'};
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: DeleteSaveBox(env: newEnv(save: store))))));
      Opacity op() => tester.widget<Opacity>(find.ancestor(of: find.text('APAGAR SAVE'), matching: find.byType(Opacity)).first);
      expect(op().opacity, lessThan(1));
      await tester.tap(find.text('APAGAR SAVE'));
      await tester.pump();
      expect(store.json, isNotNull);
      for (final wrong in ['apagar', 'APAGA', 'APAGAR ', 'APAGAR!']) {
        await tester.enterText(find.byType(TextField), wrong);
        await tester.pump();
        await tester.tap(find.text('APAGAR SAVE'));
        await tester.pump();
        expect(store.json, isNotNull, reason: wrong);
      }
      await tester.enterText(find.byType(TextField), 'APAGAR');
      await tester.pump();
      expect(op().opacity, 1);
      await tester.tap(find.text('APAGAR SAVE'));
      await tester.pump();
      await tester.pump();
      expect(store.json, isNull);
    });
  });

  group('etiqueta DEBUG', () {
    Future<DevTools> pumpTag(WidgetTester tester) async {
      final tools = DevTools(realSource: FakeGps());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Stack(children: [Positioned(right: 0, top: 0, child: DebugTag(tools: tools))]))));
      return tools;
    }

    final tag = find.byKey(const Key('debug-tag'));

    testWidgets('some sem forçamento e aparece com cada um deles', (tester) async {
      final tools = await pumpTag(tester);
      expect(tag, findsNothing);

      tools.force.set(behavior: EcoBehavior.skittish);
      await tester.pump();
      expect(tag, findsOneWidget);
      expect(find.text('DEBUG'), findsOneWidget);
      tools.force.clearAll();
      await tester.pump();
      expect(tag, findsNothing);

      tools.clock.setUtc(1790040000);
      await tester.pump();
      expect(tag, findsOneWidget);
      tools.clock.clear();
      await tester.pump();
      expect(tag, findsNothing);

      tools.setLevelOverride(7);
      await tester.pump();
      expect(tag, findsOneWidget);
      tools.setLevelOverride(0);
      tools.force.set(shiny: true);
      await tester.pump();
      expect(tag, findsOneWidget);
      tools.force.take();
      await tester.pump();
      expect(tag, findsNothing);

      await tester.runAsync(() => tools.setUseSimulator(true));
      await tester.pump();
      expect(tag, findsOneWidget);
      await tester.runAsync(() => tools.setUseSimulator(false));
      await tester.pump();
      expect(tag, findsNothing);
    });
  });

  group('itens de spawn e névoa', () {
    testWidgets('os chips forçam comportamento, variante, Brilhante e clima, e limpar zera os pedidos', (tester) async {
      final tools = DevTools(realSource: FakeGps());
      await pumpMenu(tester, DebugPrefs(defaultOpen: true), env: newEnv(tools: tools));
      for (final t in ['ARISCO', 'VARIANTE DE BIOMA', 'BRILHANTE', 'CHUVA']) {
        await tester.ensureVisible(find.text(t));
        await tester.tap(find.text(t));
      }
      await tester.pump();
      expect((tools.force.nextBehavior, tools.force.nextVariant, tools.force.nextShiny, tools.force.weather), (EcoBehavior.skittish, true, true, Weather.rain));
      await tester.ensureVisible(find.text('LIMPAR PEDIDOS'));
      await tester.tap(find.text('LIMPAR PEDIDOS'));
      await tester.ensureVisible(find.text('REAL'));
      await tester.tap(find.text('REAL'));
      await tester.pump();
      expect((tools.force.pendingEco, tools.force.weather), (false, null));
    });

    testWidgets('revelar, limpar e zerar o Radar gravam no save; sem jogo salvo avisa', (tester) async {
      final store = MemorySaveStore()..json = {'schema_version': 3, 'group_code': 'AAAAA-BBBBB', 'inventory': {'item.chalk': 2}};
      await pumpMenu(tester, DebugPrefs(defaultOpen: true), env: newEnv(save: store));
      Future<void> tap(String t) async {
        await tester.ensureVisible(find.text(t));
        await tester.tap(find.text(t));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }

      await tap('REVELAR NÉVOA (600 M)');
      expect(FogState.fromJson(store.json!['fog'] as Map<String, dynamic>).debugCount, greaterThan(0));
      await tap('LIMPAR NÉVOA DE DEBUG');
      expect(FogState.fromJson(store.json!['fog'] as Map<String, dynamic>).debugCount, 0);
      store.json!['radar'] = {'last_utc': 55, 'revealed': {}};
      await tap('ZERAR RECARGA DO RADAR');
      expect((store.json!['radar'] as Map)['last_utc'], 0);

      store.json = null;
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
      await tester.pump();
      await tap('ZERAR RECARGA DO RADAR');
      expect(store.json, isNull);
      expect(find.textContaining('Ainda não há jogo salvo'), findsOneWidget);
    });
  });
}
