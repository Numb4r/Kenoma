import 'dart:convert';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/map/map_screen.dart';

/// O jogo de mapa: `GameWidget<MapGame>`, que `find.byType(GameWidget)` não casa.
final gameWidget = find.byWidgetPredicate((w) => w is GameWidget);

class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);

  final Map<String, List<int>> files;

  @override
  Future<ByteData> load(String key) async {
    final data = files[key];
    if (data == null) throw FlutterError('Unable to load asset: "$key".');
    return ByteData.sublistView(Uint8List.fromList(data));
  }
}

Map<String, List<int>> realAssets({Uint8List? bin}) => {
      'assets/data/epochs.json': File('assets/data/epochs.json').readAsBytesSync(),
      'assets/data/biomes.json': File('assets/data/biomes.json').readAsBytesSync(),
      'assets/regions/campinas_e0.bin': bin ?? File('assets/regions/campinas_e0.bin').readAsBytesSync(),
    };

Future<void> pumpMap(WidgetTester tester, {Map<String, List<int>>? assets, double lat = -22.8174, double lon = -47.0697}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(MaterialApp(home: MapScreen(lat: lat, lon: lon, bundle: _Bundle(assets ?? realAssets()))));
  for (var i = 0; i < 100 && find.text('Carregando mapa...').evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 300));
}

String? hudLine(WidgetTester tester, String prefix) {
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final t = w.data ?? '';
    if (t.startsWith(prefix)) return t;
  }
  return null;
}

(double, double) center(WidgetTester tester) {
  final m = RegExp(r'CENTRO (-?[\d.]+), (-?[\d.]+)').firstMatch(hudLine(tester, 'CENTRO')!)!;
  return (double.parse(m.group(1)!), double.parse(m.group(2)!));
}

double zoom(WidgetTester tester) =>
    double.parse(RegExp(r'ZOOM ([\d.]+)').firstMatch(hudLine(tester, 'Z21')!)!.group(1)!);

void main() {
  testWidgets('abre centrado na coordenada pedida, na escala da spec, sem sonda antes do primeiro toque', (tester) async {
    await pumpMap(tester);
    expect(gameWidget, findsOneWidget);
    expect(center(tester), (-22.8174, -47.0697));
    expect(zoom(tester), 16.0);
    expect(hudLine(tester, 'TOQUE'), isNotNull);
    expect(find.text('GRADE Z20'), findsOneWidget);
    expect(find.text('MUNDO DESATUALIZADO'), findsNothing);
  });

  testWidgets('arrastar o dedo move o centro do mapa para o outro lado', (tester) async {
    await pumpMap(tester);
    final before = center(tester);
    await tester.drag(gameWidget, const Offset(160, 320)); // para a direita e para baixo
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final after = center(tester);
    expect(after.$2, lessThan(before.$2), reason: 'o mapa foi para a direita: o centro vai para oeste (longitude menor)');
    expect(after.$1, greaterThan(before.$1), reason: 'o mapa desceu: o centro vai para o norte (latitude maior)');
  });

  testWidgets('a pinça aproxima e afasta, sempre entre o mínimo e o máximo', (tester) async {
    await pumpMap(tester);
    Future<void> pinch(double from, double to) async {
      final c = tester.getCenter(gameWidget);
      final a = await tester.startGesture(c.translate(-from, 0), pointer: 1);
      final b = await tester.startGesture(c.translate(from, 0), pointer: 2);
      for (var i = 1; i <= 10; i++) {
        final d = from + (to - from) * i / 10;
        await a.moveTo(c.translate(-d, 0));
        await b.moveTo(c.translate(d, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await pinch(100, 200);
    expect(zoom(tester), closeTo(32.0, 0.01), reason: 'abrir os dedos 2x dobra a escala (16 → 32, o máximo)');
    await pinch(60, 180);
    expect(zoom(tester), 32.0, reason: 'nunca passa do máximo');
    await pinch(190, 5);
    expect(zoom(tester), closeTo(1.0, 0.01), reason: 'fechar os dedos vai até o mínimo e para');
    await pinch(120, 5);
    expect(zoom(tester), 1.0);
  });

  testWidgets('tocar mostra o que há sob o dedo: coordenada, células z21 e z20 e os biomas', (tester) async {
    await pumpMap(tester);
    final c = tester.getCenter(gameWidget);
    final g = await tester.startGesture(c);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(hudLine(tester, 'DEDO'), isNotNull);
    final line = hudLine(tester, 'DEDO')!;
    expect(line, contains('-22.8'));
    expect(hudLine(tester, 'Z21 ') , isNotNull);
    final z21 = tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').where((t) => t.startsWith('Z21 ') && t.contains('·') && !t.contains('ZOOM')).single;
    expect(z21, matches(RegExp(r'^Z21 \d+,\d+ · (VAZIO|URBANO|VERDE|ÁGUA|RESIDENCIAL)$')));
    final z20 = hudLine(tester, 'Z20 ')!;
    expect(z20, matches(RegExp(r'^Z20 \d+,\d+ · SPAWN (VAZIO|URBANO|VERDE|ÁGUA|RESIDENCIAL)$')));
    // A célula z20 é a z21 dividida por 2.
    final a = RegExp(r'Z21 (\d+),(\d+)').firstMatch(z21)!;
    final b = RegExp(r'Z20 (\d+),(\d+)').firstMatch(z20)!;
    expect((int.parse(b.group(1)!), int.parse(b.group(2)!)), (int.parse(a.group(1)!) ~/ 2, int.parse(a.group(2)!) ~/ 2));
    await g.up();
  });

  testWidgets('a opção da grade z20 liga e desliga', (tester) async {
    await pumpMap(tester);
    final sw = find.byType(Switch);
    expect(tester.widget<Switch>(sw).value, isFalse);
    await tester.tap(sw);
    await tester.pump();
    expect(tester.widget<Switch>(sw).value, isTrue);
    await tester.tap(sw);
    await tester.pump();
    expect(tester.widget<Switch>(sw).value, isFalse);
  });

  testWidgets('o botão < volta ao menu', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => MapScreen(lat: -22.8174, lon: -47.0697, bundle: _Bundle(realAssets())))),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // a transição da rota
    for (var i = 0; i < 100 && find.text('Carregando mapa...').evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('<'));
    await tester.pumpAndSettle();
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('pacote adulterado: mostra o erro claro com os hashes, sem derrubar o app, e o botão volta', (tester) async {
    final bad = Uint8List.fromList(File('assets/regions/campinas_e0.bin').readAsBytesSync())..[2000] ^= 0xff;
    await pumpMap(tester, assets: realAssets(bin: bad));
    expect(find.text('MAPA INDISPONÍVEL'), findsOneWidget);
    final message = tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').firstWhere((t) => t.contains('SHA-256 esperado'));
    expect(message, contains('campinas_e0.bin'));
    expect(message, contains('559f3551cf04'), reason: 'o hash da época 0');
    expect(gameWidget, findsNothing);
    expect(find.text('VOLTAR'), findsOneWidget);
  });

  testWidgets('arquivo do mapa ausente: erro claro, sem exceção', (tester) async {
    await pumpMap(tester, assets: {
      'assets/data/epochs.json': File('assets/data/epochs.json').readAsBytesSync(),
      'assets/data/biomes.json': File('assets/data/biomes.json').readAsBytesSync(),
    });
    expect(find.text('MAPA INDISPONÍVEL'), findsOneWidget);
    expect(find.textContaining('campinas_e0.bin não está no app'), findsOneWidget);
  });

  testWidgets('relógio depois do fim da época: o mapa abre e avisa que o mundo está desatualizado', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final epochs = jsonDecode(File('assets/data/epochs.json').readAsStringSync()) as Map<String, dynamic>;
    final end = DateTime.parse(((epochs['epochs'] as List).first as Map)['valid_until_utc'] as String).millisecondsSinceEpoch ~/ 1000;
    await tester.pumpWidget(MaterialApp(home: MapScreen(lat: -22.8174, lon: -47.0697, nowUtc: end + 1000, bundle: _Bundle(realAssets()))));
    for (var i = 0; i < 100 && find.text('Carregando mapa...').evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('MUNDO DESATUALIZADO'), findsOneWidget);
    expect(gameWidget, findsOneWidget);
  });
}
