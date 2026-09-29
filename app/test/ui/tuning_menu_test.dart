import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/session_record.dart';
import 'package:kenoma/capture/tuning_setup.dart';
import 'package:kenoma/data/session_log_store.dart';
import 'package:kenoma/data/tuning_data.dart';
import 'package:kenoma/dev/tuning_debug_menu.dart';
import 'package:kenoma/ui/tuning/log_exporter.dart';
import 'package:kenoma/ui/tuning/tuning_screen.dart';

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
    );

/// Abre o menu com um registro num diretório temporário. [seeded] é quantas sessões já existem.
Future<({SessionLogStore store, FakeExporter exporter})> pumpMenu(WidgetTester tester, {int seeded = 0}) async {
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
  final exporter = FakeExporter();

  // O cache de assets guarda o Future do teste anterior, que morreu com a zona dele.
  // Recarregar na zona real deixa o menu carregar em qualquer teste.
  for (final name in ['balance', 'creatures', 'items']) {
    rootBundle.evict('assets/data/$name.json');
  }
  await tester.runAsync(TuningData.load);
  await tester.pumpWidget(MaterialApp(home: TuningDebugMenu(store: store, exporter: exporter)));
  for (var i = 0; i < 300 && find.text('INICIAR SINTONIA').evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  return (store: store, exporter: exporter);
}

Future<TuningScreen> start(WidgetTester tester) async {
  await tester.ensureVisible(find.text('INICIAR SINTONIA'));
  await tester.tap(find.text('INICIAR SINTONIA'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return tester.widget<TuningScreen>(find.byType(TuningScreen));
}

TuningSetup setupOf(TuningScreen s) => s.buildSetup(s.pool.first);

void main() {
  testWidgets('abre com Sootling, nível 1, selo simples, sem tônico e sem tipo oculto', (tester) async {
    await pumpMenu(tester);
    expect(find.textContaining('Resistência 0.00'), findsOneWidget);
    expect(find.textContaining('Tolerância 0.080'), findsOneWidget);
    expect(find.textContaining('Tempo 20 s'), findsOneWidget);
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

  testWidgets('escolher o Rillet abre a sintonia com o Rillet, do tipo Água', (tester) async {
    await pumpMenu(tester);
    await tester.tap(find.text('Rillet'));
    await tester.pump();
    final screen = await start(tester);
    expect(screen.pool.single.id, 'rill.eco');
    expect(setupOf(screen).type, EcoType.water);
  });

  testWidgets('escolher o Frondling abre a sintonia do tipo Planta', (tester) async {
    await pumpMenu(tester);
    await tester.tap(find.text('Frondling'));
    await tester.pump();
    final screen = await start(tester);
    expect(screen.pool.single.id, 'frond.eco');
    expect(setupOf(screen).type, EcoType.plant);
  });

  testWidgets('o tônico soma o tempo do items.json e o rótulo vem do dado', (tester) async {
    await pumpMenu(tester);
    expect(find.text('Tônico (+5 s)'), findsOneWidget);
    await tester.tap(find.text('Tônico (+5 s)'));
    await tester.pump();
    expect(find.textContaining('Tempo 25 s'), findsOneWidget);
    final screen = await start(tester);
    expect(setupOf(screen).tonic, isNotNull);
    expect(setupOf(screen).timeLimitS(screen.balance), 25);
  });

  testWidgets('o alvo no dial é opcional', (tester) async {
    await pumpMenu(tester);
    await tester.tap(find.text('Mostrar alvo no dial'));
    await tester.pump();
    final screen = await start(tester);
    expect(screen.showTarget, isTrue);
  });

  testWidgets('o menu oferece a vibração de cada tipo para sentir de olhos fechados', (tester) async {
    await pumpMenu(tester);
    for (final label in ['FOGO', 'ÁGUA', 'PLANTA', 'FOGO: AVISO', 'ÁGUA: ONDA', 'PLANTA: PULSO']) {
      await tester.scrollUntilVisible(find.text(label), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  group('tipo oculto', () {
    testWidgets('com o modo ligado a sintonia leva as três espécies para sortear o tipo', (tester) async {
      await pumpMenu(tester);
      await tester.ensureVisible(find.text('Tipo oculto'));
      await tester.tap(find.text('Tipo oculto'));
      await tester.pump();
      final screen = await start(tester);
      expect(screen.hidden, isTrue);
      expect(screen.pool.map((s) => s.type).toSet(), EcoType.values.toSet());
      expect(screen.pool, hasLength(3));
    });

    testWidgets('com o modo ligado, escolher uma espécie não vale: o tipo é sorteado', (tester) async {
      await pumpMenu(tester);
      await tester.ensureVisible(find.text('Tipo oculto'));
      await tester.tap(find.text('Tipo oculto'));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Rillet'), -200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Rillet'));
      await tester.pump();
      final screen = await start(tester);
      expect(screen.pool, hasLength(3), reason: 'o Rillet não fixou a espécie');
    });

    testWidgets('o alvo no dial fica desligado no modo oculto', (tester) async {
      await pumpMenu(tester);
      await tester.ensureVisible(find.text('Mostrar alvo no dial'));
      await tester.tap(find.text('Mostrar alvo no dial'));
      await tester.pump();
      await tester.tap(find.text('Tipo oculto'));
      await tester.pump();
      final toggle = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Mostrar alvo no dial'));
      expect(toggle.value, isFalse);
      expect(toggle.onChanged, isNull);
    });

    testWidgets('cada espécie do sorteio usa os mesmos níveis e o mesmo selo do menu', (tester) async {
      await pumpMenu(tester);
      await tester.tap(find.text('Tônico (+5 s)'));
      await tester.ensureVisible(find.text('Tipo oculto'));
      await tester.tap(find.text('Tipo oculto'));
      await tester.pump();
      final screen = await start(tester);
      for (final s in screen.pool) {
        final setup = screen.buildSetup(s);
        expect(setup.type, s.type);
        expect(setup.tonic, isNotNull);
        expect(setup.seal.id, 'item.seal.simple');
      }
    });
  });

  group('registro de sessões', () {
    testWidgets('mostra quantas sessões já foram gravadas', (tester) async {
      await pumpMenu(tester);
      await tester.scrollUntilVisible(find.textContaining('Sessões gravadas'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Sessões gravadas: 0'), findsOneWidget);
    });

    testWidgets('com sessões no arquivo, mostra a contagem e exporta o arquivo do registro', (tester) async {
      final env = await pumpMenu(tester, seeded: 3);
      await tester.scrollUntilVisible(find.text('EXPORTAR REGISTRO'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Sessões gravadas: 3'), findsOneWidget);
      await tester.tap(find.text('EXPORTAR REGISTRO'));
      await tester.pump();
      expect(env.exporter.files.single.path, env.store.file.path);
    });

    testWidgets('sem sessões avisa e não abre a folha de compartilhamento', (tester) async {
      final env = await pumpMenu(tester);
      await tester.scrollUntilVisible(find.text('EXPORTAR REGISTRO'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('EXPORTAR REGISTRO'));
      await tester.pump();
      expect(find.text('Nenhuma sessão gravada ainda'), findsOneWidget);
      expect(env.exporter.files, isEmpty);
    });
  });
}
