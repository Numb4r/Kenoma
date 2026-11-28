import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/session_record.dart';
import 'package:kenoma/capture/tuning_setup.dart';
import 'package:kenoma/data/session_log_store.dart';
import 'package:kenoma/data/tuning_data.dart';
import 'package:kenoma/dev/debug_prefs.dart';
import 'package:kenoma/dev/debug_registry.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/save/save_store.dart';
import 'package:kenoma/ui/game/game_map_screen.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/dev/tuning_debug_menu.dart';
import 'package:kenoma/ui/tuning/log_exporter.dart';
import 'package:kenoma/dev/debug_widgets.dart' show DebugSwitch;
import 'package:kenoma/ui/tuning/tuning_screen.dart';

import '../support/fake_position_source.dart';
import '../support/fixed_map_world.dart';

class FakeExporter implements LogExporter {
  final files = <File>[];

  @override
  Future<void> export(File file) async => files.add(file);
}

SessionRecord sampleRecord() => SessionRecord(
      timeUtc: DateTime.utc(2026, 9, 29, 12),
      type: EcoType.fire,
      ecoLevel: 1,
      playerLevel: 1,
      sealId: 'item.seal.simple',
      tonic: false,
      tolerance: 0.08,
      resistance: 0,
      durationS: 5.5,
      success: true,
      alignedTimeS: 5,
      alignmentLosses: 0,
      balanceVersion: 'a1b2c3d4',
      gap: 0,
      overlevel: 0,
      appBuild: '0.2.0+2',
    );

/// Abre o menu com um registro num diretório temporário, na aba [tab]. [seeded] é quantas sessões já existem.
Future<({SessionLogStore store, FakeExporter exporter})> pumpMenu(WidgetTester tester,
    {int seeded = 0, List<String> legacyRows = const [], DevTools? tools, DebugTab tab = DebugTab.creatures}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  // Desmonta a árvore no fim, para o jogo Flame de um teste não vazar para o seguinte.
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  final dir = Directory.systemTemp.createTempSync('kenoma_menu_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final store = SessionLogStore(File('${dir.path}/sessions.csv'));
  for (var i = 0; i < seeded; i++) {
    await tester.runAsync(() => store.append(sampleRecord()));
  }
  if (legacyRows.isNotEmpty) {
    store.file.writeAsStringSync('${SessionRecord.legacyHeader}\n${legacyRows.join('\n')}\n');
  }
  final exporter = FakeExporter();
  PackageInfo.setMockInitialValues(
      appName: 'kenoma', packageName: 'com.numb4r.kenoma', version: '0.2.0', buildNumber: '2', buildSignature: '');

  // O cache de assets guarda o Future do teste anterior, que morreu com a zona dele.
  // Recarregar na zona real deixa o menu carregar em qualquer teste.
  // Todos os assets: dois testes que abrem o mapa do jogo leem muito mais que estes (0.21.0).
  rootBundle.clear();
  await tester.runAsync(TuningData.load);
  final prefs = DebugPrefs();
  await prefs.setTab(tab);
  await tester.pumpWidget(MaterialApp(home: TuningDebugMenu(store: store, exporter: exporter, devTools: tools, prefs: prefs, saveStore: MemorySaveStore())));
  final ready = tab == DebugTab.creatures ? find.byKey(const Key('creature.tuning_species=soot.eco')) : find.byKey(const Key('debug-cards'));
  for (var i = 0; i < 300 && ready.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  return (store: store, exporter: exporter);
}

/// Rola até o alvo e toca: a aba é longa, e o que fica fora da tela não recebe o toque.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tapVisible(tester, find.byKey(Key(key)));
  await tester.pump();
}

Future<TuningScreen> start(WidgetTester tester) async {
  await tapKey(tester, 'creature.tuning_start.run');
  await tester.pump(const Duration(milliseconds: 500));
  return tester.widget<TuningScreen>(find.byType(TuningScreen));
}

TuningSetup setupOf(TuningScreen s) => s.buildSetup(s.pool.first);

/// Espera o mapa do jogo terminar de abrir (a tela de carregamento some e o selo de modo aparece).
Future<void> settleMap(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  for (var i = 0; i < 400 && (find.text('Carregando mapa...').evaluate().isNotEmpty || find.byKey(const Key('mode-seal')).evaluate().isEmpty); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> openSeal(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const Key('mode-seal')));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('abre com Sootling, nível 1, selo simples, sem tônico e sem tipo oculto', (tester) async {
    await pumpMenu(tester);
    expect(find.text('Resistência 0.00 · tolerância 0.080 · 20 s'), findsOneWidget);
    final screen = await start(tester);
    expect(screen.pool.single.id, 'soot.eco');
    expect(setupOf(screen).type, EcoType.fire);
    expect(setupOf(screen).ecoLevel, 1);
    expect(setupOf(screen).playerLevel, 1);
    expect(setupOf(screen).seal.id, 'item.seal.simple');
    expect(setupOf(screen).tonic, isNull);
    expect(screen.showTarget, isFalse);
    expect(screen.hidden, isFalse);
  });

  testWidgets('escolher o Rillet abre a sintonia com o Rillet, do tipo Água; o Frondling, Planta', (tester) async {
    await pumpMenu(tester);
    await tapKey(tester, 'creature.tuning_species=rill.eco');
    var screen = await start(tester);
    expect(screen.pool.single.id, 'rill.eco');
    expect(setupOf(screen).type, EcoType.water);
    Navigator.of(tester.element(find.byType(TuningScreen))).pop();
    await tester.pumpAndSettle();
    await tapKey(tester, 'creature.tuning_species=frond.eco');
    screen = await start(tester);
    expect(setupOf(screen).type, EcoType.plant);
  });

  testWidgets('o tônico soma o tempo do items.json; o alvo no dial é opcional', (tester) async {
    await pumpMenu(tester);
    await tapKey(tester, 'creature.tuning_tonic');
    await tapKey(tester, 'creature.tuning_target');
    expect(find.text('Resistência 0.00 · tolerância 0.080 · 25 s'), findsOneWidget);
    final screen = await start(tester);
    expect(setupOf(screen).tonic, isNotNull);
    expect(setupOf(screen).timeLimitS(screen.balance), 25);
    expect(screen.showTarget, isTrue);
  });

  testWidgets('o menu deixa sentir a identidade de cada tipo e os alertas da resistência', (tester) async {
    await pumpMenu(tester);
    for (final v in ['fire', 'water', 'plant', 'fire_warning', 'water_swell', 'plant_pulse']) {
      expect(find.byKey(Key('creature.vibration.pattern=$v')), findsOneWidget, reason: v);
    }
  });

  group('tipo oculto', () {
    testWidgets('com o modo ligado a sintonia leva as três espécies, a espécie não fixa e o alvo fica desligado', (tester) async {
      await pumpMenu(tester);
      await tapKey(tester, 'creature.tuning_target');
      await tapKey(tester, 'creature.tuning_tonic');
      await tapKey(tester, 'creature.tuning_hidden');
      await tapKey(tester, 'creature.tuning_species=rill.eco');
      final target = tester.widget<DebugSwitch>(find.descendant(of: find.byKey(const Key('creature.tuning_target')), matching: find.byType(DebugSwitch)));
      expect((target.value, target.onChanged), (false, null));
      final screen = await start(tester);
      expect(screen.hidden, isTrue);
      expect(screen.pool.map((s) => s.type).toSet(), EcoType.mvp.toSet());
      expect(screen.pool, hasLength(3), reason: 'o Rillet não fixou a espécie');
      for (final s in screen.pool) {
        final setup = screen.buildSetup(s);
        expect(setup.type, s.type);
        expect(setup.tonic, isNotNull);
        expect(setup.seal.id, 'item.seal.simple');
      }
    });
  });

  group('registro de sessões', () {
    testWidgets('mostra a contagem e exporta o arquivo do registro', (tester) async {
      final env = await pumpMenu(tester, seeded: 3);
      expect(find.text('Sessões gravadas: 3'), findsOneWidget);
      await tapKey(tester, 'creature.tuning_log_export.run');
      expect(env.exporter.files.single.path, env.store.file.path);
    });

    testWidgets('ao abrir, migra o registro antigo: o contador segue igual e quem exporta já leva a coluna nova', (tester) async {
      const old = [
        '2026-09-29T15:01:00.000000Z,fire,1,1,item.seal.simple,0,0.080,0.000,5.50,success,5.00,0,0,',
        '2026-09-29T15:02:00.000000Z,water,17,15,item.seal.reinforced,1,0.110,0.810,20.00,fail,3.65,3,1,1',
      ];
      final env = await pumpMenu(tester, legacyRows: old);
      expect(find.text('Sessões gravadas: 2'), findsOneWidget);
      final lines = env.store.file.readAsLinesSync();
      expect(lines.first, SessionRecord.header);
      // Primeiro formato: ganha pre-ajuste, o gap dos próprios níveis (0 e 2), overlevel 0 e pre-visual.
      expect(lines.skip(1).toList(), ['${old[0]},pre-ajuste,0,0,pre-visual', '${old[1]},pre-ajuste,2,0,pre-visual']);
      expect(env.store.backup.existsSync(), isTrue);
      await tapKey(tester, 'creature.tuning_log_export.run');
      expect(env.exporter.files.single.readAsLinesSync().first, contains('balance_version'));
    });

    testWidgets('sem sessões avisa e não abre a folha de compartilhamento', (tester) async {
      final env = await pumpMenu(tester);
      expect(find.text('Sessões gravadas: 0'), findsOneWidget);
      await tapKey(tester, 'creature.tuning_log_export.run');
      expect(find.text('Nenhuma sessão gravada ainda'), findsOneWidget);
      expect(env.exporter.files, isEmpty);
    });
  });

  group('simulador de GPS, teleporte, relógio e mapa do jogo no menu de debug', () {
    DevTools newTools() => DevTools(realSource: FakeGps());
    // Os que abrem o mapa do jogo: relógio e clima fixos (`support/fixed_map_world.dart`).
    DevTools mapTools(WidgetTester tester) {
      resetArtLoading();
      return fixedDevTools(tester, realSource: FakeGps());
    }

    testWidgets('ligar o simulador troca a fonte de posição; a velocidade e o ruído se ajustam', (tester) async {
      final tools = newTools();
      await pumpMenu(tester, tools: tools, tab: DebugTab.position);
      await tapKey(tester, 'pos.simulator');
      expect(tools.useSimulator, isTrue);
      expect(find.byKey(const Key('real-pos.simulator')), findsOneWidget, reason: 'o chip do topo');
      await tapKey(tester, 'pos.speed=6.0');
      expect(tools.simulator.speedMps, 6.0);
      await tapKey(tester, 'pos.speed=3.0');
      expect(tools.simulator.speedMps, 3.0);
      expect(tools.simulator.noiseM, 0);
      await tapKey(tester, 'pos.noise');
      expect(tools.simulator.noiseM, 5.0);
      await tapKey(tester, 'real-pos.simulator');
      expect(tools.useSimulator, isFalse);
    });

    testWidgets('teleporte: coordenada colada ruim avisa e não move; boa liga o simulador', (tester) async {
      final tools = newTools();
      await pumpMenu(tester, tools: tools, tab: DebugTab.position);
      for (final bad in ['abc', '-22.8', '95, -47', '-22.8, 200']) {
        await tester.enterText(find.byKey(const Key('pos.teleport.field')), bad);
        await tapKey(tester, 'pos.teleport.go');
        expect(find.textContaining('lat,lon ou um lugar'), findsOneWidget, reason: bad);
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
        await tester.pump();
      }
      expect((tools.useSimulator, tools.simulator.lat), (false, kUnicamp.$1), reason: 'não teleportou');
    });

    testWidgets('teleporte pelo chip do Centro: liga o simulador, abre o mapa do jogo e o Conjurador está lá', (tester) async {
      final tools = mapTools(tester);
      await pumpMenu(tester, tools: tools, tab: DebugTab.position);
      await tapKey(tester, 'pos.teleport=centro');
      expect((tools.useSimulator, tools.simulator.lat, tools.simulator.lon), (true, kCentroCampinas.$1, kCentroCampinas.$2));
      await settleMap(tester);
      expect(find.byType(GameMapScreen), findsOneWidget, reason: 'o teleporte abre o mapa fechado');
      await openSeal(tester);
      expect(find.textContaining('-22.9056'), findsOneWidget);
      await tester.tap(find.byKey(const Key('open-debug-menu')));
      await tester.pumpAndSettle();
      expect(find.text('DEBUG'), findsOneWidget, reason: 'volta ao menu');
    });

    testWidgets('escolher no mapa: arma o toque longo e abre o mapa; o chip do topo desarma', (tester) async {
      final tools = mapTools(tester);
      await pumpMenu(tester, tools: tools, tab: DebugTab.position);
      await tools.setUseSimulator(true); // sem o GPS real (o pedido de permissão não existe nos testes)
      await tapKey(tester, 'pos.teleport=escolhernomapa');
      expect(tools.pickTeleport, isTrue);
      await settleMap(tester);
      expect(find.byType(GameMapScreen), findsOneWidget);
      // O toque longo leva o simulador até o ponto e desarma.
      final g = await tester.startGesture(tester.getCenter(find.byType(GameMapScreen)) + const Offset(0, -150));
      await tester.pump(const Duration(milliseconds: 600));
      await g.up();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tools.pickTeleport, isFalse);
      expect(tools.simulator.lat, isNot(kUnicamp.$1), reason: 'foi até o ponto do toque');
      expect(tools.simulator.lat, closeTo(kUnicamp.$1, 0.05));
      await openSeal(tester);
      await tester.tap(find.byKey(const Key('open-debug-menu')));
      await tester.pumpAndSettle();
      tools.setPickTeleport(true); // armado de novo: o chip do topo desarma
      await tester.pump();
      await tapKey(tester, 'real-pos.teleport');
      expect(tools.pickTeleport, isFalse);
    });

    testWidgets('relógio UTC: aplica o instante digitado, o chip do topo mostra a hora e desfaz; data inválida avisa', (tester) async {
      final tools = newTools();
      await pumpMenu(tester, tools: tools, tab: DebugTab.world);
      await tester.enterText(find.byKey(const Key('world.clock.t')), '2026-02-30 10:00');
      await tapKey(tester, 'world.clock.run');
      expect(find.text('Use aaaa-mm-dd hh:mm em UTC'), findsOneWidget);
      expect(tools.clock.overridden, isFalse);
      await tester.enterText(find.byKey(const Key('world.clock.t')), '2026-12-22 00:00');
      await tapKey(tester, 'world.clock.run');
      expect(tools.clock.overridden, isTrue);
      expect(tools.clock.nowUtc, closeTo(DateTime.utc(2026, 12, 22).millisecondsSinceEpoch ~/ 1000, 3));
      expect(find.text('RELÓGIO 00:00 UTC'), findsOneWidget);
      expect(find.textContaining('(forçado)'), findsOneWidget);
      await tapKey(tester, 'real-world.clock');
      expect(tools.clock.overridden, isFalse);
      expect(find.textContaining('(forçado)'), findsNothing);
    });

    testWidgets('abrir o mapa do jogo com o simulador leva ao mapa, com o Conjurador na Unicamp', (tester) async {
      final tools = mapTools(tester);
      await pumpMenu(tester, tools: tools, tab: DebugTab.position);
      await tools.setUseSimulator(true);
      await tester.pump();
      await tapKey(tester, 'pos.open_map.run');
      await settleMap(tester);
      expect(find.byType(GameMapScreen), findsOneWidget);
      await openSeal(tester);
      expect(find.textContaining('SEGUINDO'), findsOneWidget);
      expect(find.textContaining('-22.8174'), findsOneWidget);
      await tester.tap(find.byKey(const Key('open-debug-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pos.open_map')), findsOneWidget, reason: 'volta ao menu');
    });

    testWidgets('0.21.0, o bug do debug: reabrir o mapa enquanto o outro ainda sai não empilha dois nem dá setState no build', (tester) async {
      final tools = mapTools(tester);
      await pumpMenu(tester, tools: tools, tab: DebugTab.position);
      await tools.setUseSimulator(true);
      await tester.pump();
      await tapKey(tester, 'pos.open_map.run');
      await settleMap(tester);
      expect(find.byType(GameMapScreen), findsOneWidget);
      await openSeal(tester);
      await tester.tap(find.byKey(const Key('open-debug-menu')));
      await tester.pump(const Duration(milliseconds: 60)); // o mapa ainda está saindo
      // O menu ainda entra deslizando: o centro do botão (alinhado à esquerda) está fora da tela; a ponta direita já não.
      final run = tester.getRect(find.byKey(const Key('pos.open_map.run')));
      await tester.tapAt(Offset(run.right - 6, run.center.dy));
      tools.force.toggleEvent('vigil'); // o DevTools avisa com os dois mapas na árvore
      tools.force.toggleEvent('vigil');
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settleMap(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(GameMapScreen, skipOffstage: false), findsOneWidget, reason: 'um mapa só, o novo, depois de o velho fechar');
      await openSeal(tester);
      await tester.tap(find.byKey(const Key('open-debug-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pos.open_map')), findsOneWidget);
    });
  });
}
