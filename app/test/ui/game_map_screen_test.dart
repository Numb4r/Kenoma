import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/dev/gps_simulator.dart';
import 'package:kenoma/ui/game/game_map_game.dart';
import 'package:kenoma/ui/game/game_map_screen.dart';
import 'package:kenoma/ui/game/joystick.dart';
import 'package:kenoma/world/follow_camera.dart';
import 'package:kenoma/world/location_access.dart';
import 'package:kenoma/world/places.dart';

import '../support/fake_position_source.dart';

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

Map<String, List<int>> realAssets() => {
      for (final f in ['epochs', 'biomes', 'balance']) 'assets/data/$f.json': File('assets/data/$f.json').readAsBytesSync(),
      'assets/regions/campinas_e0.bin': File('assets/regions/campinas_e0.bin').readAsBytesSync(),
    };

final gameWidget = find.byWidgetPredicate((w) => w is GameWidget);

/// O jogo do mapa, de dentro da árvore.
GameMapGame gameOf(WidgetTester tester) => tester.widget<GameWidget>(gameWidget).game! as GameMapGame;

class Env {
  Env(this.tester, this.tools, this.gps, this.gateway);

  final WidgetTester tester;
  final DevTools tools;
  final FakeGps gps;
  final FakeGateway gateway;

  GameMapGame get game => gameOf(tester);
  SimulatedPositionSource get sim => tools.simulator;

  /// Anda o tempo do simulador e deixa a tela processar.
  Future<void> simulate(Duration d, {int frames = 6}) async {
    sim.advance(d);
    await settle(frames);
  }

  Future<void> settle([int frames = 6]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}

Future<Env> pumpGame(
  WidgetTester tester, {
  bool simulator = true,
  FakeGateway? gateway,
  int? clockUtc,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final gps = FakeGps();
  final gw = gateway ?? FakeGateway(state: LocationPermissionState.granted);
  final tools = DevTools(realSource: gps);
  if (clockUtc != null) tools.clock.setUtc(clockUtc);
  if (simulator) await tools.setUseSimulator(true);
  await tester.pumpWidget(MaterialApp(home: GameMapScreen(tools: tools, gateway: gw, bundle: _Bundle(realAssets()))));
  for (var i = 0; i < 100 && find.text('Carregando mapa...').evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  final env = Env(tester, tools, gps, gw);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
  });
  await env.settle(10);
  return env;
}

(double, double) cellOf(double lat, double lon) => latLonToTileFraction(lat, lon, biomeZoom);

void main() {
  group('com o simulador', () {
    testWidgets('o marcador aparece na posição do simulador, a câmera começa nele e a Aura vem do balance.json', (tester) async {
      final env = await pumpGame(tester);
      expect(env.game.avatar.hasPosition, isTrue);
      final (x, y) = cellOf(kUnicamp.$1, kUnicamp.$2);
      expect(env.game.avatar.x, closeTo(x, 0.5), reason: 'a posição filtrada é a primeira leitura');
      expect(env.game.avatar.y, closeTo(y, 0.5));
      expect(env.game.follow.followX, closeTo(env.game.avatar.x, 1e-6), reason: 'a primeira posição não desliza');
      expect(env.game.auraM, 40.0);
      expect(find.textContaining('SEGUINDO'), findsOneWidget);
      expect(find.textContaining('-22.8174'), findsOneWidget);
      expect(find.text('SIMULADOR'), findsOneWidget);
    });

    testWidgets('o joystick anda o Conjurador e a câmera o segue, deslizando atrás dele', (tester) async {
      final env = await pumpGame(tester);
      final startX = env.game.avatar.x;
      // Arrasta o joystick para a direita: leste.
      final c = tester.getCenter(find.byType(Joystick));
      final g = await tester.startGesture(c);
      await g.moveBy(const Offset(80, 0)); // além do raio de 70: satura em 1
      await tester.pump();
      expect(env.sim.joystickX, closeTo(1, 0.05));
      expect(env.sim.joystickY, closeTo(0, 0.05));
      await env.simulate(const Duration(seconds: 30), frames: 10);
      await g.up();
      expect(env.sim.joystickX, 0, reason: 'soltar o joystick volta a zero');
      final moved = env.game.avatar.x - startX;
      expect(moved, closeTo(30 * 1.4 / 17.6, 1.0), reason: '30 s a 1,4 m/s ≈ 2,4 células para o leste');
      expect(moved, greaterThan(1.5));
      await env.settle(60); // a câmera termina de deslizar
      expect(env.game.follow.followX, closeTo(env.game.avatar.x, 0.05));
    });

    testWidgets('joystick para cima anda para o norte (a latitude sobe, o y da célula cai)', (tester) async {
      final env = await pumpGame(tester);
      final startY = env.game.avatar.y;
      final g = await tester.startGesture(tester.getCenter(find.byType(Joystick)));
      await g.moveBy(const Offset(0, -80));
      await tester.pump();
      await env.simulate(const Duration(seconds: 20), frames: 10);
      await g.up();
      expect(env.game.avatar.y, lessThan(startY));
    });

    testWidgets('a velocidade vale: de bicicleta (6 m/s) o Conjurador anda mais de 4 vezes o andando', (tester) async {
      final walk = await pumpGame(tester);
      walk.sim.setJoystick(1, 0);
      final x0 = walk.game.avatar.x;
      await walk.simulate(const Duration(seconds: 40), frames: 10);
      final walked = walk.game.avatar.x - x0;
      await tester.pumpWidget(const SizedBox.shrink());
      final bike = await pumpGame(tester);
      bike.sim.speedMps = SimSpeed.cycling.mps;
      bike.sim.setJoystick(1, 0);
      final x1 = bike.game.avatar.x;
      await bike.simulate(const Duration(seconds: 40), frames: 10);
      final cycled = bike.game.avatar.x - x1;
      expect(cycled / walked, closeTo(6 / 1.4, 1.2));
    });

    testWidgets('teleporte: o marcador e a câmera pulam para o novo lugar, sem deslizar pelo mapa', (tester) async {
      final env = await pumpGame(tester);
      env.sim.teleport(kCentroCampinas.$1, kCentroCampinas.$2);
      await env.settle(4);
      final (x, y) = cellOf(kCentroCampinas.$1, kCentroCampinas.$2);
      expect(env.game.avatar.x, closeTo(x, 0.5));
      expect(env.game.avatar.y, closeTo(y, 0.5));
      expect(env.game.follow.followX, closeTo(x, 0.5), reason: 'saltou: o centro está a ~10 km');
    });

    testWidgets('os botões do overlay: velocidade e teleportes', (tester) async {
      final env = await pumpGame(tester);
      await tester.tap(find.textContaining('CORRENDO'));
      await tester.pump();
      expect(env.sim.speedMps, 3.0);
      await tester.tap(find.text('TELEPORTE: CENTRO'));
      await env.settle(4);
      expect(env.sim.lat, kCentroCampinas.$1);
      await tester.tap(find.text('TELEPORTE: UNICAMP'));
      await env.settle(4);
      expect(env.sim.lat, kUnicamp.$1);
    });

    testWidgets('leitura com precisão pior que 50 m: sem marcador e o aviso de precisão ruim', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      final gps = FakeGps();
      final tools = DevTools(realSource: gps);
      tools.simulator.accuracyM = 80;
      await tools.setUseSimulator(true);
      await tester.pumpWidget(MaterialApp(home: GameMapScreen(tools: tools, gateway: FakeGateway(state: LocationPermissionState.granted), bundle: _Bundle(realAssets()))));
      for (var i = 0; i < 100 && find.text('Carregando mapa...').evaluate().isNotEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(gameOf(tester).avatar.hasPosition, isFalse);
      expect(find.textContaining('PRECISÃO RUIM ±80'), findsOneWidget);
      tools.simulator.accuracyM = 6;
      tools.simulator.advance(const Duration(seconds: 2));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(gameOf(tester).avatar.hasPosition, isTrue, reason: 'a precisão melhorou: o marcador aparece');
      expect(find.textContaining('SEGUINDO'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('câmera de jogo', () {
    testWidgets('arrastar espia em volta, e depois de 3 s sem toque a câmera volta sozinha', (tester) async {
      final env = await pumpGame(tester);
      final base = env.game.follow.camera.centerX;
      await tester.drag(gameWidget, const Offset(160, 0)); // 16 px por célula: 10 células
      await env.settle(2);
      expect(env.game.follow.peeking, isTrue);
      expect(env.game.follow.camera.centerX, lessThan(base - 5), reason: 'o mapa foi com o dedo: a câmera foi para oeste');
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 50)); // 2,5 s
      }
      expect(env.game.follow.peeking, isTrue, reason: 'antes dos 3 s não volta');
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 50)); // mais 6 s
      }
      expect(env.game.follow.peeking, isFalse);
      expect(env.game.follow.camera.centerX, closeTo(env.game.avatar.x, 0.05));
    });

    testWidgets('o dedo encostado segura o espiar: a câmera só volta depois de soltar', (tester) async {
      final env = await pumpGame(tester);
      final g = await tester.startGesture(tester.getCenter(gameWidget));
      await g.moveBy(const Offset(120, 0));
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100)); // 10 s com o dedo parado
      }
      expect(env.game.follow.peeking, isTrue);
      await g.up();
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(env.game.follow.peeking, isFalse);
    });

    testWidgets('a pinça dá zoom só na faixa de jogo: de 8 a 24 px por célula, menor que a do debug', (tester) async {
      final env = await pumpGame(tester);
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
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(env.game.follow.pixelsPerCell, 16);
      await pinch(60, 120);
      expect(env.game.follow.pixelsPerCell, closeTo(24, 0.01), reason: 'abrir 2x passaria de 32: trava no máximo de jogo (24)');
      await pinch(100, 20);
      expect(env.game.follow.pixelsPerCell, closeTo(8, 0.01), reason: 'trava no mínimo de jogo (8)');
      expect(FollowCamera.minScale, greaterThan(1));
      expect(FollowCamera.maxScale, lessThan(32));
    });
  });

  group('GPS real: permissão com explicação curta', () {
    testWidgets('sem permissão: explica antes, e só depois do "Continuar" pede ao sistema; concedida, liga o GPS', (tester) async {
      final gw = FakeGateway();
      final env = await pumpGame(tester, simulator: false, gateway: gw);
      expect(find.text('LOCALIZAÇÃO'), findsOneWidget);
      expect(find.textContaining('só com o app aberto'), findsOneWidget);
      expect(gw.requests, 0, reason: 'o diálogo do sistema só vem depois da explicação');
      expect(env.gps.started, isFalse);
      await tester.tap(find.text('CONTINUAR'));
      await env.settle(6);
      expect(gw.requests, 1);
      expect(env.gps.started, isTrue);
      env.gps.emit(-22.8174, -47.0697, acc: 8);
      await env.settle(4);
      expect(env.game.avatar.hasPosition, isTrue);
      expect(find.text('GPS REAL'), findsOneWidget);
    });

    testWidgets('já concedida: não explica nem pede, e liga o GPS direto', (tester) async {
      final env = await pumpGame(tester, simulator: false);
      expect(find.text('LOCALIZAÇÃO'), findsNothing);
      expect(env.gateway.requests, 0);
      expect(env.gps.started, isTrue);
    });

    testWidgets('"Agora não": mostra o que houve e dá o botão de tentar de novo, que explica de novo', (tester) async {
      final gw = FakeGateway();
      final env = await pumpGame(tester, simulator: false, gateway: gw);
      await tester.tap(find.text('AGORA NÃO'));
      await env.settle(6);
      expect(find.text('SEM LOCALIZAÇÃO'), findsOneWidget);
      expect(env.gps.started, isFalse);
      expect(gw.requests, 0);
      await tester.tap(find.text('TENTAR DE NOVO'));
      await env.settle(6);
      expect(find.text('LOCALIZAÇÃO'), findsOneWidget, reason: 'explica de novo');
      await tester.tap(find.text('CONTINUAR'));
      await env.settle(6);
      expect(env.gps.started, isTrue);
      expect(find.text('SEM LOCALIZAÇÃO'), findsNothing);
    });

    testWidgets('negada para sempre: leva aos ajustes do aparelho', (tester) async {
      final gw = FakeGateway(state: LocationPermissionState.deniedForever);
      final env = await pumpGame(tester, simulator: false, gateway: gw);
      expect(find.text('LOCALIZAÇÃO'), findsNothing, reason: 'não adianta explicar: o sistema nem abriria o diálogo');
      expect(find.text('SEM LOCALIZAÇÃO'), findsOneWidget);
      expect(find.textContaining('ajustes'), findsWidgets);
      await tester.tap(find.text('ABRIR AJUSTES'));
      await env.settle(2);
      expect(gw.appSettings, 1);
      expect(env.gps.started, isFalse);
    });

    testWidgets('GPS do aparelho desligado: leva às configurações de localização', (tester) async {
      final gw = FakeGateway(service: false);
      final env = await pumpGame(tester, simulator: false, gateway: gw);
      expect(find.text('SEM LOCALIZAÇÃO'), findsOneWidget);
      await tester.tap(find.text('LIGAR GPS'));
      await env.settle(2);
      expect(gw.locationSettings, 1);
    });

    testWidgets('sem permissão dá para usar o simulador no lugar, sem mudar mais nada', (tester) async {
      final gw = FakeGateway(state: LocationPermissionState.deniedForever);
      final env = await pumpGame(tester, simulator: false, gateway: gw);
      await tester.tap(find.text('USAR SIMULADOR'));
      await env.settle(10);
      expect(env.tools.useSimulator, isTrue);
      expect(find.text('SEM LOCALIZAÇÃO'), findsNothing);
      expect(env.game.avatar.hasPosition, isTrue);
      expect(find.text('SIMULADOR'), findsOneWidget);
    });

    testWidgets('o app vai para segundo plano: a fonte para; volta ao primeiro plano: liga de novo', (tester) async {
      final env = await pumpGame(tester, simulator: false);
      expect(env.gps.started, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await env.settle(4);
      expect(env.gps.started, isFalse, reason: 'só com o app aberto');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await env.settle(6);
      expect(env.gps.started, isTrue);
    });
  });

  group('trocar de fonte com o mapa aberto', () {
    testWidgets('o botão GPS REAL / SIMULADOR troca a fonte, o marcador recomeça e os controles do simulador aparecem', (tester) async {
      final env = await pumpGame(tester, simulator: false);
      expect(find.byType(Joystick), findsNothing, reason: 'sem simulador, sem joystick');
      env.gps.emit(-22.9056, -47.0608);
      await env.settle(4);
      final (gx, _) = cellOf(-22.9056, -47.0608);
      expect(env.game.avatar.x, closeTo(gx, 0.5));
      await tester.tap(find.text('GPS REAL'));
      await env.settle(10);
      expect(env.tools.useSimulator, isTrue, reason: 'useSimulator depois do toque');
      expect(find.byType(Joystick), findsOneWidget);
      final (sx, _) = cellOf(kUnicamp.$1, kUnicamp.$2);
      expect(env.game.avatar.x, closeTo(sx, 0.5), reason: 'agora o marcador está no simulador, não no GPS');
      expect(env.gps.started, isFalse);
      await tester.tap(find.text('SIMULADOR'));
      await env.settle(10);
      expect(env.tools.useSimulator, isFalse);
      expect(env.gps.started, isTrue);
      expect(find.byType(Joystick), findsNothing);
    });
  });

  group('relógio UTC e mundo desatualizado', () {
    testWidgets('com o relógio sobreposto o painel avisa, e o mapa carrega a época desse instante', (tester) async {
      final inEpoch = DateTime.utc(2026, 10, 15).millisecondsSinceEpoch ~/ 1000;
      final env = await pumpGame(tester, clockUtc: inEpoch);
      expect(find.textContaining('RELÓGIO UTC 2026-10-15'), findsOneWidget);
      expect(find.textContaining('(OVERRIDE)'), findsOneWidget);
      expect(find.text('MUNDO DESATUALIZADO'), findsNothing);
      expect(env.tools.clock.overridden, isTrue);
    });

    testWidgets('relógio depois do fim da época 0: o mapa abre e avisa que o mundo está desatualizado', (tester) async {
      final after = DateTime.utc(2027, 2, 1).millisecondsSinceEpoch ~/ 1000;
      await pumpGame(tester, clockUtc: after);
      expect(find.text('MUNDO DESATUALIZADO'), findsOneWidget);
      expect(find.byType(Joystick), findsOneWidget, reason: 'o mapa funciona mesmo assim');
    });

    testWidgets('sem override o painel não fala do relógio', (tester) async {
      await pumpGame(tester);
      expect(find.textContaining('RELÓGIO UTC'), findsNothing);
    });
  });

  group('erros e saída', () {
    testWidgets('pacote do mapa adulterado: erro claro, sem derrubar o app', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      final files = realAssets();
      final bin = Uint8List.fromList(files['assets/regions/campinas_e0.bin']!)..[3000] ^= 0xff;
      files['assets/regions/campinas_e0.bin'] = bin;
      final tools = DevTools(realSource: FakeGps());
      await tester.pumpWidget(MaterialApp(home: GameMapScreen(tools: tools, gateway: FakeGateway(), bundle: _Bundle(files))));
      for (var i = 0; i < 100 && find.text('Carregando mapa...').evaluate().isNotEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('MAPA INDISPONÍVEL'), findsOneWidget);
      expect(find.textContaining('SHA-256 esperado'), findsOneWidget);
      expect(find.text('VOLTAR'), findsOneWidget);
    });

    testWidgets('o botão < volta ao menu e para a fonte de posição', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      final tools = DevTools(realSource: FakeGps());
      await tools.setUseSimulator(true);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => GameMapScreen(tools: tools, gateway: FakeGateway(state: LocationPermissionState.granted), bundle: _Bundle(realAssets())))),
            child: const Text('abrir'),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (var i = 0; i < 100 && find.text('Carregando mapa...').evaluate().isNotEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('<'));
      await tester.pumpAndSettle();
      expect(find.text('abrir'), findsOneWidget);
      // A fonte compartilhada parou: nenhuma leitura chega depois de sair.
      var got = 0;
      tools.source.fixes.listen((_) => got++);
      tools.simulator.advance(const Duration(seconds: 5));
      await tester.pump();
      expect(got, 0);
    });
  });
}
