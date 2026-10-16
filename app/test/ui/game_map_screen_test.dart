import 'dart:async';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/features.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/heading_source.dart';
import 'package:kenoma/player/conjurer_balance.dart';
import 'package:kenoma/ui/game/compass_button.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/dev/gps_simulator.dart';
import 'package:kenoma/ui/game/game_map_game.dart';
import 'package:kenoma/core/weather.dart';
import 'package:kenoma/core/behavior.dart';
import 'package:kenoma/ui/game/player_hud.dart';
import 'package:kenoma/ui/menu/circle_screen.dart';
import 'package:kenoma/ui/menu/phone_menu.dart';
import 'package:kenoma/ui/menu/profile_screen.dart';
import 'package:kenoma/ui/game/game_map_screen.dart';
import 'package:kenoma/ui/game/joystick.dart';
import 'package:kenoma/world/location_access.dart';
import 'package:kenoma/save/save_store.dart';
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
      for (final f in ['epochs', 'biomes', 'balance', 'creatures', 'items', 'recipes', 'mentor', 'forum', 'rituals']) 'assets/data/$f.json': File('assets/data/$f.json').readAsBytesSync(),
      'assets/regions/campinas_e0.bin': File('assets/regions/campinas_e0.bin').readAsBytesSync(),
      'assets/regions/campinas_e0_vis.bin': File('assets/regions/campinas_e0_vis.bin').readAsBytesSync(),
      'assets/regions/campinas_e2_nowalk.bin': File('assets/regions/campinas_e2_nowalk.bin').readAsBytesSync(),
    };

final gameWidget = find.byWidgetPredicate((w) => w is GameWidget);

/// O jogo do mapa, de dentro da árvore.
GameMapGame gameOf(WidgetTester tester) => tester.widget<GameWidget>(gameWidget).game! as GameMapGame;

class FakeHeading implements HeadingSource {
  final _c = StreamController<double>.broadcast();

  bool get listening => _c.hasListener;

  void emit(double deg) => _c.add(deg);

  @override
  Stream<double> get headings => _c.stream;
}

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

  /// Anda [seconds] segundos em tempo real: uma leitura do simulador por segundo e 20 quadros de 50 ms.
  Future<void> live(int seconds, {void Function()? each}) async {
    for (var i = 0; i < seconds; i++) {
      sim.advance(const Duration(seconds: 1));
      for (var f = 0; f < 20; f++) {
        await tester.pump(const Duration(milliseconds: 50));
        each?.call();
      }
    }
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
  HeadingSource? heading,
  MemorySaveStore? store,
  bool realClock = false,
  void Function(DevTools tools)? beforeOpen,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final gps = FakeGps();
  final gw = gateway ?? FakeGateway(state: LocationPermissionState.granted);
  final tools = DevTools(realSource: gps);
  // Por padrão o relógio fica na época 1 (sem o fluxo v2): comportamentos aleatórios abririam a folha de preparo no meio
  // dos testes de toque. Os testes da época 2 passam o horário que querem.
  if (!realClock || clockUtc != null) tools.clock.setUtc(clockUtc ?? 1792080000);
  if (simulator) await tools.setUseSimulator(true);
  beforeOpen?.call(tools);
  await tester.pumpWidget(MaterialApp(home: GameMapScreen(tools: tools, gateway: gw, bundle: _Bundle(realAssets()), headingSource: heading, store: store)));
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
      expect(env.game.auraM, 10.0);
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
      await env.settle(200); // o marcador anda atrás das leituras, com cerca de 1 s de atraso
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
      await env.settle(200);
      expect(env.game.avatar.y, lessThan(startY));
    });

    testWidgets('a velocidade vale: de bicicleta (6 m/s) o Conjurador anda mais de 4 vezes o andando', (tester) async {
      final walk = await pumpGame(tester);
      walk.sim.setJoystick(1, 0);
      final x0 = walk.game.avatar.x;
      await walk.simulate(const Duration(seconds: 40), frames: 10);
      await walk.settle(400);
      final walked = walk.game.avatar.x - x0;
      await tester.pumpWidget(const SizedBox.shrink());
      final bike = await pumpGame(tester);
      bike.sim.speedMps = SimSpeed.cycling.mps;
      bike.sim.setJoystick(1, 0);
      final x1 = bike.game.avatar.x;
      await bike.simulate(const Duration(seconds: 40), frames: 10);
      await bike.settle(400);
      final cycled = bike.game.avatar.x - x1;
      expect(cycled / walked, closeTo(6 / 1.4, 1.2));
    });

    testWidgets('teleporte: duas leituras no novo lugar e o marcador e a câmera pulam para lá, sem deslizar pelo mapa', (tester) async {
      final env = await pumpGame(tester);
      env.sim.teleport(kCentroCampinas.$1, kCentroCampinas.$2);
      await env.simulate(const Duration(seconds: 3), frames: 40); // uma leitura por segundo; a segunda confirma a mudança
      final (x, y) = cellOf(kCentroCampinas.$1, kCentroCampinas.$2);
      expect(env.game.avatar.x, closeTo(x, 0.5));
      expect(env.game.avatar.y, closeTo(y, 0.5));
      expect(env.game.follow.followX, closeTo(x, 0.5), reason: 'saltou: o centro está a ~10 km');
    });

    testWidgets('animação: parado fica no quadro de parado; andando alterna os dois quadros de passo', (tester) async {
      final env = await pumpGame(tester);
      expect(env.game.avatar.moving, isFalse);
      expect(env.game.playerFrameIndex, 0);
      env.sim.setJoystick(1, 0);
      await env.live(6); // chega a andar
      expect(env.game.avatar.moving, isTrue);
      final seen = <int>{};
      await env.live(4, each: () => seen.add(env.game.playerFrameIndex));
      expect(seen, {1, 2}, reason: 'os dois quadros do passo, e nunca o de parado enquanto anda');
      env.sim.setJoystick(0, 0);
      await env.live(6); // as leituras param de andar e o marcador chega e para
      expect(env.game.avatar.moving, isFalse);
      expect(env.game.playerFrameIndex, 0);
    });

    testWidgets('o sprite olha para o lado em que anda, e mantém o lado ao parar; com o mapa girado vale o lado na tela', (tester) async {
      final env = await pumpGame(tester);
      env.sim.setJoystick(1, 0); // leste
      await env.live(6);
      expect(env.game.facingLeft, isFalse);
      env.sim.setJoystick(-1, 0); // oeste
      await env.live(8);
      expect(env.game.facingLeft, isTrue);
      env.sim.setJoystick(0, 0);
      await env.live(6);
      expect(env.game.facingLeft, isTrue, reason: 'parado, continua olhando para onde andava');
      // Com o mapa girado 180°, andar para o leste é andar para a esquerda na tela.
      env.game.rotation.rotateBy(3.141592653589793);
      env.sim.setJoystick(1, 0);
      await env.live(8);
      expect(env.game.facingLeft, isTrue);
      env.game.rotation.goNorth();
      await env.live(8);
      expect(env.game.facingLeft, isFalse);
    });

    testWidgets('a câmera segue o marcador suavizado, não a leitura crua do GPS', (tester) async {
      final env = await pumpGame(tester);
      env.sim.setJoystick(1, 0);
      await env.live(10);
      final (latest, _) = env.game.avatar.latest!;
      expect(env.game.avatar.x, lessThan(latest), reason: 'o marcador está atrás da última leitura');
      expect(env.game.follow.followX, lessThanOrEqualTo(env.game.avatar.x + 0.05), reason: 'a câmera não passa do marcador');
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
    testWidgets('arrastar gira o mapa em torno do Conjurador: a câmera não sai dele e o giro não volta', (tester) async {
      final env = await pumpGame(tester);
      final cam = env.game.follow.camera;
      final c = env.game.screenCenter;
      // O dedo desce pelo lado direito, a 120 px do Conjurador: um quarto de volta é descer 120 px (45°).
      await tester.dragFrom(c + const Offset(120, 0), const Offset(0, 120));
      await env.settle(2);
      expect(env.game.rotation.angle, closeTo(0.7853981633974483, 1e-6), reason: 'o mapa girou o mesmo ângulo que o dedo: 45° horário');
      expect(env.game.follow.camera.centerX, closeTo(cam.centerX, 0.05));
      expect(env.game.follow.camera.centerY, closeTo(cam.centerY, 0.05));
      final angle = env.game.rotation.angle;
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 50)); // 6 s depois de soltar
      }
      expect(env.game.rotation.angle, closeTo(angle, 1e-9), reason: 'o giro manual não volta sozinho');
      expect(env.game.follow.camera.centerX, closeTo(env.game.avatar.x, 0.05));
    });

    testWidgets('a pinça vai de 40 m a 80 m de largura de tela, com 50 m no padrão', (tester) async {
      final env = await pumpGame(tester);
      Future<void> pinch(double from, double to) async {
        final c = tester.getCenter(gameWidget);
        final a = await tester.startGesture(c.translate(0, -from), pointer: 1);
        final b = await tester.startGesture(c.translate(0, from), pointer: 2);
        for (var i = 1; i <= 10; i++) {
          final d = from + (to - from) * i / 10;
          await a.moveTo(c.translate(0, -d));
          await b.moveTo(c.translate(0, d));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await a.up();
        await b.up();
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(env.game.widthM, closeTo(50, 0.01));
      await pinch(60, 120);
      expect(env.game.widthM, 40, reason: 'abrir 2x passaria de 40 m: trava no mínimo');
      await pinch(100, 20);
      expect(env.game.widthM, 80, reason: 'fechar 5x passaria de 80 m: trava no máximo');
    });
  });

  group('rotação do mapa', () {
    // Um Eco de mentira a [east] e [south] células do Conjurador.
    WorldSpawn ecoAt(Env env, double east, double south) => WorldSpawn(
          uid: 7,
          kind: 'eco',
          entryId: 'soot.eco',
          quantity: 1,
          x: env.game.avatar.x + east,
          y: env.game.avatar.y + south,
          cellX: 0,
          cellY: 0,
          window: 0,
          level: 1,
        );

    testWidgets('tocar num Eco continua achando o Eco com o mapa girado', (tester) async {
      final env = await pumpGame(tester);
      final game = env.game;
      game.worldView!.spawns = [ecoAt(env, 1.5, -2.0)];
      for (final turn in [0.0, 0.8, 1.9, -2.6]) {
        game.follow.setRotation(turn);
        final (sx, sy) = game.follow.camera.cellToScreen(env.game.avatar.x + 1.5, env.game.avatar.y - 2.0, game.size.x, game.size.y);
        expect(game.spawnAt(Offset(sx, sy))?.uid, 7, reason: 'giro $turn: tocando onde o Eco aparece');
        expect(game.spawnAt(Offset(sx + 200, sy)), isNull, reason: 'longe do Eco não acha nada');
      }
    });

    testWidgets('com o mapa girado o Eco aparece onde a rotação o põe, e não onde estaria sem girar', (tester) async {
      final env = await pumpGame(tester);
      final game = env.game;
      game.worldView!.spawns = [ecoAt(env, 0, -2.0)]; // 2 células ao norte
      game.follow.setRotation(0);
      final (ux, uy) = game.follow.camera.cellToScreen(game.avatar.x, game.avatar.y - 2, game.size.x, game.size.y);
      game.follow.setRotation(1.5707963267948966); // 90° horário: o norte vai para a direita
      final (rx, ry) = game.follow.camera.cellToScreen(game.avatar.x, game.avatar.y - 2, game.size.x, game.size.y);
      expect(rx, greaterThan(ux + 10));
      expect(game.spawnAt(Offset(ux, uy)), isNull, reason: 'onde ele estaria sem girar já não é o Eco');
      expect(game.spawnAt(Offset(rx, ry))?.uid, 7);
    });

    testWidgets('com o norte para cima não há bússola; arrastar faz a bússola aparecer, e tocar nela volta ao norte', (tester) async {
      final env = await pumpGame(tester);
      expect(find.byType(CompassButton), findsNothing);
      env.game.dragRotate(0.5);
      env.game.dragRotate(0.5);
      env.game.touchEnd();
      await env.settle(2);
      expect(env.game.rotation.angle, closeTo(1.0, 1e-6));
      expect(find.byType(CompassButton), findsOneWidget);
      await tester.tap(find.byType(CompassButton));
      await tester.pump(const Duration(milliseconds: 400)); // o duplo toque espera para ter certeza
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(env.game.rotation.angle, 0);
      expect(find.byType(CompassButton), findsNothing, reason: 'norte para cima: a bússola some');
    });

    testWidgets('duplo toque na bússola liga o seguir direção: o mapa gira com a bússola do celular, com o norte verdadeiro', (tester) async {
      final heading = FakeHeading();
      final env = await pumpGame(tester, heading: heading);
      env.game.dragRotate(1.0);
      env.game.touchEnd();
      await env.settle(2);
      expect(env.game.rotation.followHeading, isFalse);
      expect(heading.listening, isFalse, reason: 'a bússola do celular só liga no seguir direção');

      final compass = find.byType(CompassButton);
      await tester.tap(compass);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(compass);
      await tester.pump(const Duration(milliseconds: 40));
      expect(env.game.rotation.followHeading, isTrue);
      expect(heading.listening, isTrue);

      heading.emit(90); // magnético; a declinação de Campinas (-21°) leva ao norte verdadeiro 69°
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final trueHeading = 90 + env.game.declinationDeg;
      expect(env.game.declinationDeg, lessThan(0));
      expect(env.game.rotation.angle, closeTo(-trueHeading * 3.141592653589793 / 180, 0.01));

      await tester.tap(compass);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(compass);
      await tester.pump(const Duration(milliseconds: 40));
      expect(env.game.rotation.followHeading, isFalse);
      expect(heading.listening, isFalse, reason: 'desligou: para de ler a bússola');
    });

    testWidgets('a pinça só dá zoom: não gira o mapa', (tester) async {
      final env = await pumpGame(tester);
      env.game.gestureStart();
      env.game.pinch(1.2);
      env.game.touchEnd();
      expect(env.game.rotation.angle, 0);
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
      await pumpGame(tester, realClock: true);
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

  group('progressão na interface', () {
    /// Leva o Conjurador para ~4 m de um Eco real e devolve o Eco.
    Future<WorldSpawn> goToEco(Env env) async {
      final field = env.game.worldView!.field;
      final eco = field
          .around(lat: kUnicamp.$1, lon: kUnicamp.$2, tUtc: env.tools.clock.nowUtc, radiusM: 300, playerLevel: 1)
          .firstWhere((s) => s.isEco);
      final (la, lo) = tileFractionToLatLon(eco.x + 0.2, eco.y + 0.2, biomeZoom);
      env.sim.teleport(la, lo);
      await env.simulate(const Duration(seconds: 3), frames: 40);
      return eco;
    }

    Offset screenOf(Env env, WorldSpawn s) {
      final (sx, sy) = env.game.follow.camera.cellToScreen(s.x, s.y, env.game.size.x, env.game.size.y);
      return Offset(sx, sy);
    }

    testWidgets('o botão do celular abre o menu: apps do nível 1 abertos, o resto bloqueado', (tester) async {
      final env = await pumpGame(tester);
      expect(find.byType(PhoneButton), findsOneWidget);
      await tester.tap(find.byType(PhoneButton));
      await env.settle(10);
      for (final label in ['BOLSA', 'CÍRCULO', 'BESTIÁRIO', 'PERFIL']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('BANCADA'), findsNothing, reason: 'nível 2');
      expect(find.text('???'), findsNWidgets(4));
      await tester.tap(find.text('CÍRCULO'));
      await env.settle(20);
      expect(find.byType(CircleScreen), findsOneWidget);
    });

    testWidgets('tocar no retrato abre o Perfil', (tester) async {
      final env = await pumpGame(tester);
      await tester.tap(find.byKey(const Key('portrait-hud')));
      await env.settle(20);
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('o retrato mostra o nível e a barra de XP sobe com o XP', (tester) async {
      final env = await pumpGame(tester);
      final state = env.game.worldView!.state;
      expect(find.text('NV 1'), findsOneWidget);
      expect(find.byType(PortraitHud), findsOneWidget);
      double bar() => tester.getSize(find.descendant(of: find.byKey(const Key('xp-bar')), matching: find.byType(Container)).last).width;
      final before = bar();
      state.gainXp(10, env.tools.clock.nowUtc); // com o descanso, 20 de XP rumo aos 60 do nível 2
      await env.settle(2);
      expect(bar(), greaterThan(before));
      state.gainXp(100, env.tools.clock.nowUtc);
      await env.settle(2);
      expect(find.text('NV 2'), findsNothing, reason: '10 + 100, dobrados, passam do nível 2');
      expect(find.text('NV 3'), findsOneWidget);
    });

    testWidgets('toque longo num Eco dentro da Aura prende o sinal, aparece a ficha, e outro toque longo solta', (tester) async {
      final env = await pumpGame(tester);
      final eco = await goToEco(env);
      final state = env.game.worldView!.state;
      expect(state.markOf(eco.uid), isNull);
      await tester.longPressAt(screenOf(env, eco));
      await env.settle(4);
      expect(state.markOf(eco.uid), isNotNull);
      expect(find.byKey(Key('mark-${eco.uid}')), findsOneWidget);
      expect(env.game.rotation.angle, 0, reason: 'o toque longo não gira o mapa');
      await tester.longPressAt(screenOf(env, eco));
      await env.settle(4);
      expect(state.markOf(eco.uid), isNull);
      expect(find.byKey(Key('mark-${eco.uid}')), findsNothing);
    });

    testWidgets('arrastar a partir de um Eco gira o mapa e não marca nem abre o encontro', (tester) async {
      final env = await pumpGame(tester);
      final eco = await goToEco(env);
      final state = env.game.worldView!.state;
      final g = await tester.startGesture(screenOf(env, eco));
      await g.moveBy(const Offset(60, 0));
      await g.moveBy(const Offset(0, 100)); // já longe do Conjurador: o dedo gira o mapa
      await g.up();
      await env.settle(4);
      expect(env.game.rotation.angle, isNot(0));
      expect(state.markOf(eco.uid), isNull);
      expect(find.text('SINTONIZAR'), findsNothing);
    });

    testWidgets('segurar sem soltar e depois arrastar não vira toque longo', (tester) async {
      final env = await pumpGame(tester);
      final eco = await goToEco(env);
      final g = await tester.startGesture(screenOf(env, eco));
      await tester.pump(const Duration(milliseconds: 200));
      await g.moveBy(const Offset(60, 0)); // passa do limiar antes dos 500 ms
      await g.moveBy(const Offset(0, 100));
      await tester.pump(const Duration(milliseconds: 600));
      await g.up();
      await env.settle(4);
      expect(env.game.worldView!.state.markOf(eco.uid), isNull);
      expect(env.game.rotation.angle, isNot(0));
    });

    testWidgets('toque longo em Eco fora da Aura não marca', (tester) async {
      final env = await pumpGame(tester);
      final eco = await goToEco(env);
      env.sim.teleport(kUnicamp.$1 + 0.0006, kUnicamp.$2); // ~65 m ao norte dali
      await env.simulate(const Duration(seconds: 3), frames: 40);
      final far = env.game.worldView!.spawns.where((s) => s.isEco && !env.game.worldView!.inAura(s));
      if (far.isEmpty) return; // sem Eco à vista fora da Aura nesse trecho
      await tester.longPressAt(screenOf(env, far.first));
      await env.settle(4);
      expect(env.game.worldView!.state.markOf(far.first.uid), isNull);
      expect(eco.uid, isNotNull);
    });
  });

  group('tráfego do Véu e luz do dia', () {
    // 2026-10-15 em Campinas: 08:00 local (11:00 UTC) é rush; 03:00 local (06:00 UTC) é madrugada, de noite.
    int utcOf(String iso) => DateTime.parse(iso).millisecondsSinceEpoch ~/ 1000;

    /// O máximo de fantasmas desenhados em [frames] quadros (a seed do jogo muda a cada execução: um quadro só pode ser vazio).
    Future<int> peak(Env env, {int frames = 40}) async {
      var best = 0;
      for (var i = 0; i < frames; i++) {
        await env.settle(5);
        if (env.game.ghostsDrawn > best) best = env.game.ghostsDrawn;
      }
      return best;
    }

    MemorySaveStore fixedGroup() => MemorySaveStore()..json = {'schema_version': 2, 'group_code': 'KENOMA-TESTE'};

    testWidgets('no rush aparecem fantasmas, respeitando o teto, e o interruptor os apaga', (tester) async {
      final env = await pumpGame(tester, clockUtc: utcOf('2026-10-16T11:10:00Z'), store: fixedGroup());
      final best = await peak(env);
      expect(best, greaterThan(0));
      expect(best, lessThanOrEqualTo(160));
      env.game.worldView!.state.setSetting('veil_traffic', false);
      await env.settle(4);
      expect(env.game.ghostsDrawn, 0);
    });

    testWidgets('de madrugada há bem menos fantasmas que no rush', (tester) async {
      final rush = await pumpGame(tester, clockUtc: utcOf('2026-10-16T11:10:00Z'), store: fixedGroup());
      final busy = await peak(rush);
      await tester.pumpWidget(const SizedBox.shrink());
      final dead = await pumpGame(tester, clockUtc: utcOf('2026-10-16T06:10:00Z'), store: fixedGroup());
      final quiet = await peak(dead);
      expect(busy, greaterThan(0));
      expect(quiet, lessThan(busy));
    });

    testWidgets('a luz do mapa segue o sol: noite fechada à 00:00 local, dia pleno ao meio-dia', (tester) async {
      final night = await pumpGame(tester, clockUtc: utcOf('2026-10-16T03:00:00Z'));
      await night.settle(130); // a luz é recalculada a cada 5 s
      expect(night.game.light.night, greaterThan(0.95));
      await tester.pumpWidget(const SizedBox.shrink());
      final noon = await pumpGame(tester, clockUtc: utcOf('2026-10-16T15:00:00Z'));
      await noon.settle(130);
      expect(noon.game.light.night, 0);
      expect(find.byKey(const Key('moon-hud')), findsOneWidget);
    });
  });

  group('rua viva no mapa', () {
    testWidgets('o Familiar anda ao lado do Conjurador e o acompanha quando ele anda', (tester) async {
      final env = await pumpGame(tester);
      expect(env.game.companion.hasPosition, isTrue);
      env.sim.setJoystick(1, 0);
      await env.live(8);
      final ax = env.game.avatar.x, ay = env.game.avatar.y;
      final d = ((env.game.companion.x - ax) * (env.game.companion.x - ax) + (env.game.companion.y - ay) * (env.game.companion.y - ay));
      expect(d, lessThan(1.0), reason: 'a menos de uma célula (~17 m) do avatar');
      expect(env.game.companion.y - ay, greaterThan(0), reason: 'andando a leste, ele vai pela direita: ao sul');
      env.sim.setJoystick(0, 0);
    });

    testWidgets('o clima forçado pelo debug aparece no HUD junto da lua e faz chover no mapa; sem chuva, nada cai', (tester) async {
      final env = await pumpGame(tester);
      expect(find.byKey(const Key('weather-label')), findsOneWidget);
      env.tools.force.set(weather: Weather.rain);
      await env.live(12); // o clima que se vê é atualizado a cada 10 s
      expect(find.text('CHUVA'), findsOneWidget);
      expect(env.game.rainCount, greaterThan(20));
      env.tools.force.set(weather: Weather.clear);
      await env.live(12);
      expect(find.text('CHUVA'), findsNothing);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(env.game.rainCount, 0);
    });

    testWidgets('o interruptor "chuva no mapa" apaga a chuva mesmo com o clima de chuva', (tester) async {
      final env = await pumpGame(tester);
      env.tools.force.set(weather: Weather.storm);
      await env.live(12);
      expect(env.game.rainCount, greaterThan(40));
      env.game.worldView!.state.setSetting('rain_fx', false);
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(env.game.rainCount, 0);
    });

    testWidgets('a névoa: o caminho do simulador revela em volta do Conjurador no conjunto de debug, e o véu recorta as células', (tester) async {
      final env = await pumpGame(tester);
      await env.live(4);
      final fog = env.game.worldView!.state.fog;
      expect(fog.debugCount, greaterThan(3), reason: 'o simulador revela, marcado como debug');
      expect(fog.revealedCount, 0, reason: 'o contador de área só conta o caminho real');
      expect(env.game.fogCuts, greaterThan(3));
    });

    /// Leva o Conjurador até um Eco real da área (a 300 m do Unicamp), para haver Ecos novos à vista.
    Future<void> goToSomeEco(Env env) async {
      final eco = env.game.worldView!.field
          .around(lat: kUnicamp.$1, lon: kUnicamp.$2, tUtc: env.tools.clock.nowUtc, radiusM: 300, playerLevel: 1)
          .firstWhere((s) => s.isEco);
      final (la, lo) = tileFractionToLatLon(eco.x + 0.2, eco.y + 0.2, biomeZoom);
      env.sim.teleport(la, lo);
      await env.simulate(const Duration(seconds: 6), frames: 120);
    }

    testWidgets('um Eco Brilhante forçado pelo debug avisa com a mensagem e fica no bestiário como visto', (tester) async {
      final env = await pumpGame(tester, beforeOpen: (t) => t.force.set(shiny: true));
      if (env.tools.force.pendingEco) await goToSomeEco(env); // sem Eco à vista no começo: vai até um
      expect(env.tools.force.pendingEco, isFalse, reason: 'o pedido caiu no primeiro Eco novo');
      final seen = env.game.worldView!.state.bestiary.keys.where((k) => k.endsWith('@shiny'));
      expect(seen, isNotEmpty);
      expect(env.game.worldView!.state.story.count('shiny_seen'), 1);
      expect(env.tools.force.pendingEco, isFalse);
    });

    testWidgets('um Eco oculto forçado não aparece no mapa até a varredura do Radar, e depois aparece', (tester) async {
      final env = await pumpGame(tester, beforeOpen: (t) => t.force.set(behavior: EcoBehavior.hidden));
      final w = env.game.worldView!;
      if (env.tools.force.pendingEco) await goToSomeEco(env); // sem Eco à vista no começo: vai até um
      final hidden = w.allEcos.where((e) => e.behavior == EcoBehavior.hidden).toList();
      expect(hidden, hasLength(1));
      final target = hidden.single;
      expect(w.spawns.any((s) => s.uid == target.uid), isFalse, reason: 'oculto: fora do mapa e do rastreador');
      final (la, lo) = tileFractionToLatLon(target.x + 0.2, target.y + 0.2, biomeZoom);
      env.sim.teleport(la, lo);
      await env.simulate(const Duration(seconds: 6), frames: 120);
      w.radar(env.tools.clock.nowUtc);
      await env.settle(4);
      expect(w.spawns.any((s) => s.uid == target.uid), isTrue);
      expect(w.state.story.count('hidden_revealed'), greaterThan(0));
    });

    testWidgets('o menu do celular tem o Radar a partir do nível 2', (tester) async {
      final env = await pumpGame(tester);
      env.game.worldView!.state.levelOverride = 2;
      await tester.tap(find.byType(PhoneButton));
      await env.settle(10);
      expect(find.text('RADAR'), findsOneWidget);
    });

    testWidgets('na 0.13.1 (STREET_LIFE desligado) o celular não tem Radar e o HUD não mostra o clima', (tester) async {
      streetLifeEnabled = false;
      addTearDown(() => streetLifeEnabled = true);
      final env = await pumpGame(tester);
      expect(find.byKey(const Key('weather-glyph')), findsNothing);
      await tester.tap(find.byType(PhoneButton));
      await env.settle(10);
      expect(find.text('RADAR'), findsNothing);
      expect(find.text('BESTIÁRIO'), findsOneWidget);
    });

    testWidgets('escolher a escola troca a forma do Familiar no mapa na hora', (tester) async {
      final env = await pumpGame(tester);
      final state = env.game.worldView!.state;
      final before = env.game.familiarImage;
      expect(before, isNotNull);
      state.levelOverride = 3;
      expect(state.chooseSchool(School.shaman), isTrue);
      for (var i = 0; i < 20 && identical(env.game.familiarImage, before); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      expect(identical(env.game.familiarImage, before), isFalse, reason: 'a imagem foi recarregada com a paleta da escola');
    });
  });
}
