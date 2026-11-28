import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/behavior.dart';
import 'package:kenoma/dev/debug_capture.dart';
import 'package:kenoma/dev/debug_commands.dart';
import 'package:kenoma/dev/debug_env.dart';
import 'package:kenoma/dev/debug_items.dart';
import 'package:kenoma/dev/debug_menu_view.dart';
import 'package:kenoma/dev/debug_prefs.dart';
import 'package:kenoma/dev/debug_registry.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/save/save_store.dart';
import 'package:kenoma/ui/game/hud_bar.dart';
import 'package:kenoma/world/layered_world.dart';

import '../support/fake_position_source.dart';

/// Os ids do menu antes da 0.26.6 (seções e itens). Todos continuam valendo como id ou alias: os favoritos guardados e os
/// comandos antigos não quebram.
const oldIds = [
  'pos.simulator', 'pos.speed', 'pos.noise', 'pos.teleport', 'pos.patrol_sim', 'pos.patrol_journal', 'pos.steps_inject', //
  'time.clock', 'time.weather', 'time.events', 'time.weather_tap', 'time.lightning_here', 'time.rainbow_foot', 'time.weather_speed', 'time.weather_sim',
  'spawn.behavior', 'spawn.variant', 'spawn.shiny', 'spawn.spirit', 'spawn.ritual', 'spawn.personal', 'spawn.puddles', 'spawn.create',
  'map.open_game', 'map.visual_lab', 'map.biome_grid', 'map.grid20', 'map.relief', 'map.radii', 'map.radar_reset', 'map.width', 'map.code_art',
  'map.turn_labels', 'map.follow_piece', 'map.free',
  'traffic.sim',
  'player.level', 'player.grant', 'player.fusion_grant', 'player.crafting_kit', 'player.school', 'player.school_tests', 'player.ritual_research',
  'cap.species', 'cap.levels', 'cap.seal', 'cap.options', 'cap.start', 'cap.log', 'cap.vibration', 'cap.ritual',
  'sign.identity', 'sign.feed_url', 'perf.tap_latency',
  'save.export', 'save.import', 'save.migrate', 'save.delete',
  // Os comandos do celular.sh de antes.
  'sim', 'tp', 'lastcell', 'clock', 'weather', 'width', 'labels', 'npcs', 'speed', 'npctune', 'vehicle', 'spectral', 'buses', 'npc', 'event',
  'creature', 'seen', 'exit', 'level', 'turn', 'style', 'map',
];

DebugEnv newEnv({DevTools? tools, SaveStore? save}) =>
    DebugEnv(tools: tools ?? DevTools(realSource: FakeGps()), capture: CaptureDebug(), saveStore: save ?? MemorySaveStore());

Future<DebugRegistry> pumpMenu(WidgetTester tester, DebugPrefs prefs, {DebugEnv? env, VoidCallback? onTop}) async {
  tester.view.physicalSize = const Size(1080, 9600); // alto: a aba inteira cabe, todo cartão é construído
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final e = env ?? newEnv();
  final reg = buildDefaultRegistry(e);
  await tester.pumpWidget(MaterialApp(home: DebugMenuView(registry: reg, prefs: prefs, listenable: debugListenables(e), onTop: onTop)));
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  return reg;
}

/// As gravações das preferências vão em fila: cada uma espera a anterior terminar no disco.
Future<void> flushPrefs(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
}

Future<void> openTab(WidgetTester tester, DebugTab t) async {
  await tester.ensureVisible(find.byKey(Key('tab-${t.id}')));
  await tester.tap(find.byKey(Key('tab-${t.id}')));
  await tester.pump();
}

/// As keys de controle que a tela desenhou para as entradas (tudo o que não é estrutura da tela).
Set<String> screenKeys(WidgetTester tester) => {
      for (final w in find.descendant(of: find.byKey(const Key('debug-cards')), matching: find.byWidgetPredicate((w) => w.key is ValueKey<String>)).evaluate())
        if ((w.widget.key! as ValueKey<String>).value case final k when !k.startsWith('star-') && k != 'identity-details') k,
    };

/// A entrada (e o parâmetro, se houver) de uma key de controle: `id`, `id=valor`, `id.run`, `id.nome`, `id.nome=valor`.
(DebugEntry, String?)? entryOfKey(DebugRegistry reg, String key) {
  final base = key.split('=').first;
  final hits = [for (final e in reg.entries) if (base == e.id || base.startsWith('${e.id}.')) e]..sort((a, b) => b.id.length.compareTo(a.id.length));
  if (hits.isEmpty) return null;
  final e = hits.first;
  return (e, base == e.id ? null : base.substring(e.id.length + 1));
}

void main() {
  test('ids e aliases únicos; todo id antigo e todo comando antigo continuam valendo; nenhuma aba vazia', () {
    final reg = buildDefaultRegistry(newEnv());
    final names = [for (final e in reg.entries) ...[e.id, ...e.aliases]];
    expect(names.toSet().length, names.length, reason: 'nome repetido');
    expect([for (final id in oldIds) if (reg.byName(id) == null) id], isEmpty, reason: 'sumiu uma função do menu');
    for (final t in DebugTab.values) {
      expect(reg.inTab(t), isNotEmpty, reason: t.title);
    }
    for (final e in reg.entries) {
      expect(e.id, matches(RegExp('^${e.tab == DebugTab.world ? 'world' : e.tab == DebugTab.position ? 'pos' : e.tab == DebugTab.creatures ? 'creature' : e.tab == DebugTab.player ? 'player' : e.tab == DebugTab.visual ? 'visual' : 'system'}\\.[a-z0-9_.]+\$')),
          reason: 'o id começa pela aba');
      if (e.destructive) expect(e.kind, DebugKind.action, reason: e.id);
    }
  });

  testWidgets('toda entrada do registro aparece na aba dela, e todo controle da tela existe no cmd (com o parâmetro)', (tester) async {
    final reg = await pumpMenu(tester, DebugPrefs());
    final listed = (await runDebugCommands('list', reg)).map((l) => l.split(' · ').first).toSet();
    for (final t in DebugTab.values) {
      await openTab(tester, t);
      for (final e in reg.inTab(t)) {
        expect(find.byKey(Key(e.id)), findsOneWidget, reason: '${e.id} não aparece na aba ${t.title}');
      }
      for (final k in screenKeys(tester)) {
        final hit = entryOfKey(reg, k);
        expect(hit, isNotNull, reason: 'controle $k na tela sem entrada no registro');
        final (e, sub) = hit!;
        expect(listed, contains(e.id), reason: '$k: ${e.id} fora do cmd list');
        if (sub != null && !const {'run', 'field', 'go', 'load', 'slider', 'info', 'text'}.contains(sub)) {
          final param = sub.endsWith('.slider') ? sub.substring(0, sub.length - 7) : sub;
          expect(e.params.map((p) => p.name), contains(param), reason: '$k: parâmetro que o cmd não conhece');
        }
      }
    }
  });

  testWidgets('0.24.4: Voltar limpa a busca; no topo do menu chama o mapa e nunca fecha o app', (tester) async {
    var top = 0;
    await pumpMenu(tester, DebugPrefs(), onTop: () => top++);
    await tester.enterText(find.byKey(const Key('debug-search')), 'relogio');
    await tester.pump();
    expect(await tester.binding.handlePopRoute(), isTrue, reason: 'o app não sai');
    await tester.pump();
    expect(find.text('relogio'), findsNothing, reason: 'um nível: a busca');
    expect(top, 0);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    expect(top, 1, reason: 'no topo, o mapa');
    expect(find.byType(DebugMenuView), findsOneWidget);
  });

  test('as abas vêm na ordem pedida', () {
    expect(DebugTab.values.map((t) => t.title), ['Mundo', 'Posição', 'Criaturas', 'Jogador', 'Visual', 'Sistema']);
  });

  test('a busca ignora acento e caixa e acha por palavra-chave, id e alias', () {
    final reg = buildDefaultRegistry(newEnv());
    expect(reg.search('RELOGIO').map((e) => e.id), contains('world.clock'));
    expect(reg.search('chuva').map((e) => e.id), ['world.weather']);
    expect(reg.search('nivel forcado').map((e) => e.id), contains('player.level'));
    expect(reg.search('map.free').map((e) => e.id), ['pos.teleport']);
    expect(reg.search('zzzz'), isEmpty);
  });

  testWidgets('a busca mostra as entradas de todas as abas e limpar volta às abas', (tester) async {
    await pumpMenu(tester, DebugPrefs());
    await tester.enterText(find.byKey(const Key('debug-search')), 'teleporte');
    await tester.pump();
    expect(find.byKey(const Key('pos.teleport')), findsOneWidget);
    expect(find.text('POSIÇÃO · TELEPORTE'), findsOneWidget);
    expect(find.byKey(const Key('tab-mundo')), findsNothing, reason: 'com busca, as abas somem');
    await tester.enterText(find.byKey(const Key('debug-search')), 'nada disso existe');
    await tester.pump();
    expect(find.text('Nenhuma entrada com essa busca.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('debug-search')), '');
    await tester.pump();
    expect(find.byKey(const Key('tab-mundo')), findsOneWidget);
  });

  testWidgets('a aba aberta volta de um arquivo', (tester) async {
    final dir = Directory.systemTemp.createTempSync('kenoma_dbg_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final prefs = DebugPrefs(file: File('${dir.path}/debug_menu.json'));
    await pumpMenu(tester, prefs);
    expect(find.byKey(const Key('world.clock')), findsOneWidget, reason: 'começa em Mundo');
    await openTab(tester, DebugTab.visual);
    expect(find.byKey(const Key('world.clock')), findsNothing);
    expect(find.byKey(const Key('visual.biome_grid')), findsOneWidget);
    await flushPrefs(tester);
    final restored = DebugPrefs(file: prefs.file);
    await tester.runAsync(restored.load);
    expect(restored.tab, DebugTab.visual);
  });

  testWidgets('favoritos: a estrela põe o atalho na linha, que leva à aba e ao cartão; voltam do arquivo; ids antigos migram', (tester) async {
    final dir = Directory.systemTemp.createTempSync('kenoma_dbg_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/debug_menu.json');
    final prefs = DebugPrefs(file: file);
    final reg = await pumpMenu(tester, prefs);
    expect(find.textContaining('Sem favoritos'), findsOneWidget);
    await openTab(tester, DebugTab.visual);
    await tester.tap(find.byKey(const Key('star-visual.relief')));
    await tester.pump();
    expect(prefs.favorites, ['visual.relief']);
    expect(find.byKey(const Key('fav-visual.relief')), findsOneWidget);
    expect(find.byKey(const Key('visual.relief')), findsOneWidget, reason: 'o cartão continua na aba');
    await openTab(tester, DebugTab.world);
    await tester.tap(find.byKey(const Key('fav-visual.relief')));
    await tester.pump();
    expect(prefs.tab, DebugTab.visual);
    expect(find.byKey(const Key('visual.relief')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700)); // o contorno acende e apaga
    await flushPrefs(tester);

    final restored = DebugPrefs(file: file);
    await tester.runAsync(restored.load);
    expect(restored.favorites, ['visual.relief']);

    // Um arquivo da 0.26.5, com os ids de antes.
    file.writeAsStringSync('{"favorites": ["time.clock", "map.free", "nao.existe"], "open": {"posicao": true}}');
    final old = DebugPrefs(file: file);
    await tester.runAsync(old.load);
    old.migrateFavorites((id) => reg.byName(id)?.id);
    expect(old.favorites, ['world.clock', 'pos.teleport']);
    expect(old.tab, DebugTab.world);
  });

  test('sem disco o menu funciona e só não lembra', () async {
    final prefs = DebugPrefs(file: File('/caminho/que/nao/existe/debug_menu.json'));
    await prefs.load();
    await prefs.toggleFavorite('world.clock');
    await prefs.setTab(DebugTab.visual);
    expect(prefs.favorites, ['world.clock']);
    expect(prefs.tab, DebugTab.visual);
    final corrupt = File('${Directory.systemTemp.createTempSync('kenoma_dbg_').path}/x.json')..writeAsStringSync('{lixo');
    final p2 = DebugPrefs(file: corrupt);
    await p2.load();
    expect(p2.favorites, isEmpty);
  });

  testWidgets('fora do real: um chip por override, tocar desfaz só ele, e voltar tudo desfaz o resto menos o que mexe no save', (tester) async {
    final tools = DevTools(realSource: FakeGps());
    final store = MemorySaveStore()..json = {'schema_version': 15};
    final reg = await pumpMenu(tester, DebugPrefs(), env: newEnv(tools: tools, save: store));
    expect(find.text('TUDO REAL'), findsOneWidget);
    await runDebugCommands('world.clock 2027-01-08T03:17; world.weather rain; visual.biome_grid on; player.level 6', reg);
    await tester.pump();
    expect(find.text('FORA DO REAL · 4'), findsOneWidget);
    for (final t in ['RELÓGIO 03:17 UTC', 'CLIMA CHUVA', 'CAMADA DE BIOMAS', 'NÍVEL 6']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await tester.tap(find.byKey(const Key('real-world.weather')));
    await tester.pump();
    expect((tools.force.weather, tools.clock.overridden), (null, true), reason: 'só o clima voltou');
    await tester.tap(find.byKey(const Key('debug-all-real')));
    await tester.pump();
    await tester.pump();
    expect((tools.clock.overridden, tools.showBiomeGrid), (false, false));
    expect(tools.levelOverride, 6, reason: 'o nível forçado fica: mexe no save');
    expect(find.text('NÍVEL 6'), findsOneWidget);
    expect(find.textContaining('menos o que mexe no save: nível 6'), findsOneWidget);
  });

  testWidgets('alternar numa linha, escolha em chips (com o REAL), número na barra e o aviso de uma linha', (tester) async {
    final tools = DevTools(realSource: FakeGps());
    await pumpMenu(tester, DebugPrefs(), env: newEnv(tools: tools));
    await openTab(tester, DebugTab.visual);
    await tester.tap(find.byKey(const Key('visual.relief')));
    await tester.pump();
    expect(tools.showRelief, isTrue, reason: 'a linha inteira alterna');
    await tester.tap(find.byKey(const Key('visual.width=120')));
    await tester.pump();
    expect(tools.forcedWidthM, 120);
    await openTab(tester, DebugTab.world);
    await tester.tap(find.byKey(const Key('world.weather=rain')));
    await tester.pump();
    expect(tools.force.weather, 'rain');
    await tester.tap(find.byKey(const Key('world.weather=real')));
    await tester.pump();
    expect(tools.force.weather, isNull);
    await openTab(tester, DebugTab.creatures);
    expect(find.text('ATENÇÃO: o que for forçado e capturado fica no seu save como se fosse de verdade.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('creature.behavior=hidden')));
    await tester.tap(find.byKey(const Key('creature.shiny')));
    await tester.pump();
    expect((tools.force.nextBehavior, tools.force.nextShiny), (EcoBehavior.hidden, true));
    await tester.tap(find.byKey(const Key('creature.spirit.info')));
    await tester.pump();
    expect(find.textContaining('mesmo abaixo do nível 8'), findsOneWidget, reason: 'o (i) abre a descrição');
  });

  testWidgets('apagar save: a confirmação pede APAGAR digitado; cancelar não apaga', (tester) async {
    final store = MemorySaveStore()..json = {'schema_version': 4, 'group_code': 'AAAAA-BBBBB'};
    await pumpMenu(tester, DebugPrefs(), env: newEnv(save: store));
    await openTab(tester, DebugTab.player);
    Future<void> open() async {
      await tester.ensureVisible(find.byKey(const Key('player.save_delete.run')));
      await tester.tap(find.byKey(const Key('player.save_delete.run')));
      await tester.pumpAndSettle();
    }

    expect(find.descendant(of: find.byKey(const Key('player.save_delete.run')), matching: find.text('APAGA: PEDE CONFIRMAÇÃO')), findsOneWidget);
    await open();
    await tester.tap(find.byKey(const Key('debug-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(store.json, isNotNull);
    await open();
    for (final wrong in ['apagar', 'APAGA', 'APAGAR!']) {
      await tester.enterText(find.byKey(const Key('debug-confirm-word')), wrong);
      await tester.pump();
      await tester.tap(find.byKey(const Key('debug-confirm-ok')));
      await tester.pump();
      expect(store.json, isNotNull, reason: wrong);
    }
    await tester.enterText(find.byKey(const Key('debug-confirm-word')), 'APAGAR');
    await tester.pump();
    await tester.tap(find.byKey(const Key('debug-confirm-ok')));
    await tester.pumpAndSettle();
    expect(store.json, isNull);
    expect(find.text('Save apagado.'), findsOneWidget);
  });

  testWidgets('zerar o Radar grava no save (selo mexe no save); sem jogo salvo avisa', (tester) async {
    final store = MemorySaveStore()..json = {'schema_version': 3, 'group_code': 'AAAAA-BBBBB', 'inventory': {'item.chalk': 2}};
    await pumpMenu(tester, DebugPrefs(), env: newEnv(save: store));
    await openTab(tester, DebugTab.player);
    final run = find.byKey(const Key('player.radar_reset.run'));
    expect(find.descendant(of: run, matching: find.text('MEXE NO SAVE')), findsOneWidget);
    Future<void> tap() async {
      await tester.ensureVisible(run);
      await tester.tap(run);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }

    store.json!['radar'] = {'last_utc': 55, 'revealed': {}};
    await tap();
    expect((store.json!['radar'] as Map)['last_utc'], 0);
    store.json = null;
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
    await tester.pump();
    await tap();
    expect(store.json, isNull);
    expect(find.textContaining('Ainda não há jogo salvo'), findsOneWidget);
  });

  group('etiqueta DEBUG no selo de modo', () {
    testWidgets('some sem forçamento e aparece com cada um deles', (tester) async {
      final tools = DevTools(realSource: FakeGps());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: SizedBox(height: 48, child: ModeSeal(tools: tools, source: ValueNotifier(MapSourceKind.pack), onTap: () {}))))));
      final tag = find.byKey(const Key('debug-tag'));
      expect(tag, findsNothing);
      tools.force.set(behavior: EcoBehavior.hidden);
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
}
