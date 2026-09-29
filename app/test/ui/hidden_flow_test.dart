import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/tuning_setup.dart';
import 'package:kenoma/capture/vibe.dart';
import 'package:kenoma/data/session_log_store.dart';
import 'package:kenoma/data/tuning_data.dart';
import 'package:kenoma/ui/tuning/tuning_game.dart';
import 'package:kenoma/ui/tuning/tuning_screen.dart';
import 'package:kenoma/ui/type_label.dart';

import '../support/fake_vibration.dart';

class Env {
  Env(this.tester, this.store, this.vibration);

  final WidgetTester tester;
  final SessionLogStore store;
  final FakeVibration vibration;

  TuningGame get game => tester.widget<GameWidget<TuningGame>>(find.byType(GameWidget<TuningGame>)).game!;

  /// Passa [seconds] de jogo em quadros de 50 ms.
  Future<void> play(double seconds) async {
    for (var i = 0; i < (seconds / 0.05).round(); i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Linhas do registro. A gravação encadeia operações de arquivo reais, então alterna espera real e
  /// quadro para as continuações rodarem e espera até haver [expected] linhas (no máximo ~24 s).
  /// Com [expected] 0, espera um tempo fixo e confere que nada foi gravado.
  Future<List<List<String>>> rows({int expected = 0}) async {
    List<List<String>> read() => store.file.existsSync()
        ? [for (final l in store.file.readAsLinesSync().skip(1)) if (l.isNotEmpty) l.split(',')]
        : [];
    for (var i = 0; i < 400; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
      if (i >= 5 && read().length >= expected) break;
    }
    return read();
  }
}

Future<Env> open(WidgetTester tester, {required bool hidden, EcoType? only, int playerLevel = 1, int ecoLevel = 1}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  final dir = Directory.systemTemp.createTempSync('kenoma_flow_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final store = SessionLogStore(File('${dir.path}/sessions.csv'));
  final vibration = FakeVibration();

  for (final name in ['balance', 'creatures', 'items']) {
    rootBundle.evict('assets/data/$name.json');
  }
  final data = (await tester.runAsync(TuningData.load))!;
  await tester.pumpWidget(MaterialApp(
    home: TuningScreen(
      pool: hidden ? data.species : [only == null ? data.species.first : data.species.firstWhere((s) => s.type == only)],
      buildSetup: (s) => TuningSetup(type: s.type, ecoLevel: ecoLevel, playerLevel: playerLevel, seal: data.seals.first),
      balance: data.balance,
      store: store,
      hidden: hidden,
      vibration: vibration,
    ),
  ));
  // O jogo carrega os sprites de forma assíncrona de verdade. Com a suíte inteira rodando em
  // paralelo isso pode demorar: espera até 30 s, e sai assim que a primeira sintonia está pronta.
  bool ready() {
    try {
      final game = tester.widget<GameWidget<TuningGame>>(find.byType(GameWidget<TuningGame>)).game!;
      game.session; // ainda não iniciada: lança
      return game.isLoaded;
    } catch (_) {
      return false;
    }
  }

  for (var i = 0; i < 300 && !ready(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  await tester.pump();
  return Env(tester, store, vibration);
}

void main() {
  testWidgets('modo oculto: começa numa tela escura que só pede o palpite, com a vibração do tipo', (tester) async {
    final env = await open(tester, hidden: true);
    expect(find.text('Sinta o sinal'), findsOneWidget);
    expect(find.text('SENTIR DE NOVO'), findsOneWidget);
    for (final t in EcoType.values) {
      expect(find.text(typeLabel(t).toUpperCase()), findsOneWidget);
    }
    expect(env.vibration.played, hasLength(1));
    expect(env.vibration.played.single.pattern, identityPattern(env.game.setup.type).pattern);
  });

  testWidgets('antes do palpite o tempo não corre', (tester) async {
    final env = await open(tester, hidden: true);
    await env.play(2);
    expect(env.game.session.t, 0);
    expect(env.game.session.running, isTrue);
    expect(env.game.awaitingGuess.value, isTrue);
  });

  testWidgets('"Sentir de novo" repete a vibração de identidade do mesmo tipo', (tester) async {
    final env = await open(tester, hidden: true);
    final type = env.game.setup.type;
    await tester.tap(find.text('SENTIR DE NOVO'));
    await tester.tap(find.text('SENTIR DE NOVO'));
    await tester.pump();
    expect(env.vibration.played, hasLength(3));
    for (final p in env.vibration.played) {
      expect(p.pattern, identityPattern(type).pattern);
    }
    expect(env.game.setup.type, type, reason: 'o tipo não é sorteado de novo');
    expect(env.game.session.t, 0);
  });

  testWidgets('depois do palpite a tela some, o tempo corre e a identidade não toca de novo', (tester) async {
    final env = await open(tester, hidden: true);
    await tester.tap(find.text(typeLabel(env.game.setup.type).toUpperCase()));
    await tester.pump();
    expect(find.text('Sinta o sinal'), findsNothing);
    expect(env.game.awaitingGuess.value, isFalse);
    await env.play(1);
    expect(env.game.session.t, closeTo(1.0, 0.11));
    expect(env.vibration.played, hasLength(1));
  });

  testWidgets('palpite certo: o resultado revela o tipo e o registro leva guess_correct 1', (tester) async {
    final env = await open(tester, hidden: true);
    final real = env.game.setup.type;
    await tester.tap(find.text(typeLabel(real).toUpperCase()));
    await tester.pump();
    await env.play(21);
    // Sem mexer no dial a sintonia costuma falhar, mas se o alvo cair perto de 0,5 ela sela.
    expect(find.textContaining(RegExp('SELADO|SINAL PERDIDO')), findsOneWidget);
    expect(find.text('Era ${typeLabel(real)}'), findsOneWidget);
    expect(find.text('Você acertou'), findsOneWidget);
    final rows = await env.rows(expected: 1);
    expect(rows, hasLength(1));
    expect((rows.single[1], rows.single[12], rows.single[13]), (real.name, '1', '1'));
  });

  testWidgets('palpite errado: o resultado diz o que foi dito e o registro leva guess_correct 0', (tester) async {
    final env = await open(tester, hidden: true);
    final real = env.game.setup.type;
    final wrong = EcoType.values.firstWhere((t) => t != real);
    await tester.tap(find.text(typeLabel(wrong).toUpperCase()));
    await tester.pump();
    await env.play(21);
    expect(find.text('Você disse ${typeLabel(wrong)}'), findsOneWidget);
    expect(find.text('Era ${typeLabel(real)}'), findsOneWidget);
    final rows = await env.rows(expected: 1);
    expect((rows.single[1], rows.single[12], rows.single[13]), (real.name, '1', '0'));
  });

  testWidgets('sair no meio da sintonia não grava nada', (tester) async {
    final env = await open(tester, hidden: true);
    await tester.tap(find.text(typeLabel(env.game.setup.type).toUpperCase()));
    await tester.pump();
    await env.play(4); // uma sintonia não termina antes de 5 s de alinhamento
    expect(await env.rows(), isEmpty);
  });

  testWidgets('Repetir volta à tela do palpite, com o tempo parado, e o próximo registro é da nova sintonia', (tester) async {
    final env = await open(tester, hidden: true);
    await tester.tap(find.text(typeLabel(env.game.setup.type).toUpperCase()));
    await tester.pump();
    await env.play(21);
    await tester.tap(find.text('REPETIR'));
    await tester.pump();
    expect(find.text('Sinta o sinal'), findsOneWidget);
    expect(find.textContaining(RegExp('SELADO|SINAL PERDIDO')), findsNothing);
    await env.play(2);
    expect(env.game.session.t, 0);
    expect(env.vibration.played.last.pattern, identityPattern(env.game.setup.type).pattern);
    await tester.tap(find.text(typeLabel(env.game.setup.type).toUpperCase()));
    await tester.pump();
    await env.play(21);
    expect(await env.rows(expected: 2), hasLength(2));
  });

  testWidgets('fora do modo oculto não há tela de palpite nem vibração de identidade: começa na hora e grava sem palpite', (tester) async {
    final env = await open(tester, hidden: false);
    expect(find.text('Sinta o sinal'), findsNothing);
    expect(env.game.awaitingGuess.value, isFalse);
    expect(env.vibration.played, isEmpty, reason: 'a vibração é só alerta: nada toca no início e a identidade não vaza');
    await env.play(1);
    expect(env.game.session.t, closeTo(1.0, 0.11));
    await env.play(21);
    final rows = await env.rows(expected: 1);
    expect((rows.single[12], rows.single[13]), ('0', ''));
  });

  group('a vibração da sintonia é só alerta', () {
    // Conjurador 15 contra Eco 17: resistência 0,81.
    for (final (type, alert) in [
      (EcoType.fire, fireWarningPattern),
      (EcoType.water, waterSwellPattern),
      (EcoType.plant, null),
    ]) {
      testWidgets('${type.name}: só toca os alertas da resistência, nunca a identidade do tipo', (tester) async {
        final env = await open(tester, hidden: false, only: type, playerLevel: 15, ecoLevel: 17);
        await env.play(9);
        final played = env.vibration.played;
        expect(played, isNotEmpty, reason: 'com resistência forte há alertas');
        final identity = identityPattern(type).pattern;
        for (final p in played) {
          expect(p.pattern, isNot(identity), reason: 'a identidade não pode tocar');
          if (alert != null) {
            expect(p.pattern, alert.pattern, reason: 'só o alerta do ${type.name}');
          } else {
            expect(p.segments, hasLength(1), reason: 'o broto da Planta é um pulso só');
            expect(p.segments.single.durationMs, inInclusiveRange(30, 140));
          }
        }
      });
    }

    testWidgets('sem resistência não toca nada durante a sintonia inteira', (tester) async {
      final env = await open(tester, hidden: false, only: EcoType.water);
      await env.play(4); // uma sintonia não termina antes de 5 s: nada de vibração de resultado
      expect(env.vibration.played, isEmpty);
    });
  });
}
