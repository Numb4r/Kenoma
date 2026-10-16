import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/dev/debug_capture.dart';
import 'package:kenoma/dev/debug_env.dart';
import 'package:kenoma/dev/debug_items.dart';
import 'package:kenoma/dev/debug_items_school.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fake_position_source.dart';

void main() {
  test('os itens da escola entram na seção Jogador do registro padrão', () {
    final env = DebugEnv(tools: DevTools(realSource: FakeGps()), capture: CaptureDebug(), saveStore: MemorySaveStore());
    final ids = buildDefaultRegistry(env).ids;
    expect(ids, containsAll(['player.school', 'player.school_tests']));
  });

  testWidgets('escolher e limpar a escola e zerar o convite mexem só no bloco conjurer do save', (tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final store = MemorySaveStore()
      ..json = {
        'schema_version': 5,
        'player': {'level': 5},
        'conjurer': {'tests_offered': true, 'test_scores': {'sealer': 80}},
      };
    final env = DebugEnv(tools: DevTools(realSource: FakeGps()), capture: CaptureDebug(), saveStore: store);
    final item = schoolItems(env).first;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Builder(builder: item.builder)))));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Escola: nenhuma'), findsOneWidget);

    await tester.tap(find.text('SELADOR'));
    await tester.pump();
    await tester.pump();
    expect((store.json!['conjurer'] as Map)['school'], 'sealer');
    expect(store.json!['player'], {'level': 5}, reason: 'o resto do save fica como estava');

    await tester.tap(find.text('ZERAR CONVITE DOS TESTES'));
    await tester.pump();
    await tester.pump();
    expect((store.json!['conjurer'] as Map)['tests_offered'], false);

    await tester.tap(find.text('LIMPAR ESCOLA'));
    await tester.pump();
    await tester.pump();
    expect((store.json!['conjurer'] as Map).containsKey('school'), isFalse);
    expect((store.json!['conjurer'] as Map)['test_scores'], {'sealer': 80});
  });

  testWidgets('sem save ainda, o item avisa e não cria um', (tester) async {
    final store = MemorySaveStore();
    final env = DebugEnv(tools: DevTools(realSource: FakeGps()), capture: CaptureDebug(), saveStore: store);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: schoolItems(env).first.builder))));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Sem save ainda'), findsOneWidget);
    expect(store.json, isNull);
  });
}
