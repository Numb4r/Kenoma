import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/behavior.dart';
import 'package:kenoma/core/weather.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/dev/street_debug_section.dart';
import 'package:kenoma/save/save_store.dart';
import 'package:kenoma/world/fog.dart';
import 'package:kenoma/world/places.dart';

import '../support/fake_position_source.dart';

void main() {
  final v3 = <String, dynamic>{'schema_version': 3, 'group_code': 'AAAAA-BBBBB', 'inventory': {'item.chalk': 2}};

  group('operações no save', () {
    test('revelar névoa marca o conjunto de debug, não o real, e migra o save antigo sem perder nada', () {
      final out = revealDebugFog(v3, kUnicamp.$1, kUnicamp.$2, 600);
      expect(out['schema_version'], 5);
      expect(out['inventory'], {'item.chalk': 2});
      final fog = FogState.fromJson(out['fog'] as Map<String, dynamic>);
      expect(fog.debugCount, greaterThan(500), reason: '600 m de raio são centenas de células de 35 m');
      expect(fog.revealedCount, 0, reason: 'o contador de área só conta o caminho real');
    });

    test('limpar tira só o debug: o caminho real fica', () {
      final real = FogState()..reveal(774426.4, 1185714.7, 40, 17.6);
      final base = {...v3, 'fog': real.toJson()};
      final withDebug = revealDebugFog(base, kUnicamp.$1, kUnicamp.$2, 300);
      final cleared = clearDebugFog(withDebug);
      final fog = FogState.fromJson(cleared['fog'] as Map<String, dynamic>);
      expect(fog.debugCount, 0);
      expect(fog.revealedCount, real.revealedCount);
    });

    test('zerar o Radar tira a recarga e os Ocultos revelados', () {
      final out = resetRadar({...v3, 'radar': {'last_utc': 999, 'revealed': {'5': 123456}}});
      expect(out['radar'], {'last_utc': 0, 'revealed': <String, dynamic>{}});
    });
  });

  group('seção do menu', () {
    Future<(DevTools, MemorySaveStore)> pump(WidgetTester tester, {Map<String, dynamic>? save}) async {
      tester.view.physicalSize = const Size(1080, 4800);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      final tools = DevTools(realSource: FakeGps());
      final store = MemorySaveStore()..json = save;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: StreetDebugSection(tools: tools, store: store, center: () => kUnicamp)))));
      return (tools, store);
    }

    testWidgets('os chips forçam comportamento, variante, Brilhante e clima, e limpar zera os pedidos', (tester) async {
      final (tools, _) = await pump(tester);
      await tester.tap(find.text('ARISCO'));
      await tester.tap(find.text('VARIANTE DE BIOMA'));
      await tester.tap(find.text('BRILHANTE'));
      await tester.tap(find.text('CHUVA'));
      await tester.pump();
      expect((tools.force.nextBehavior, tools.force.nextVariant, tools.force.nextShiny, tools.force.weather), (EcoBehavior.skittish, true, true, Weather.rain));
      await tester.tap(find.text('LIMPAR PEDIDOS'));
      await tester.tap(find.text('REAL'));
      await tester.pump();
      expect((tools.force.pendingEco, tools.force.weather), (false, null));
    });

    testWidgets('revelar, limpar e zerar o Radar gravam no save; sem jogo salvo avisa', (tester) async {
      final (_, store) = await pump(tester, save: {...v3});
      await tester.tap(find.text('REVELAR NÉVOA (600 M)'));
      await tester.pumpAndSettle();
      expect(FogState.fromJson(store.json!['fog'] as Map<String, dynamic>).debugCount, greaterThan(0));
      await tester.tap(find.text('LIMPAR NÉVOA DE DEBUG'));
      await tester.pumpAndSettle();
      expect(FogState.fromJson(store.json!['fog'] as Map<String, dynamic>).debugCount, 0);
      store.json!['radar'] = {'last_utc': 55, 'revealed': {}};
      await tester.tap(find.text('ZERAR RECARGA DO RADAR'));
      await tester.pumpAndSettle();
      expect((store.json!['radar'] as Map)['last_utc'], 0);

      final (_, empty) = await pump(tester);
      await tester.tap(find.text('ZERAR RECARGA DO RADAR'));
      await tester.pumpAndSettle();
      expect(empty.json, isNull);
      expect(find.textContaining('NÃO HÁ JOGO'), findsOneWidget);
    });
  });
}
