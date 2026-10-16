import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/behavior.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/story/chat_state.dart';
import 'package:kenoma/ui/collection/collection_screen.dart';
import 'package:kenoma/ui/game/encounter_flow.dart';
import 'package:kenoma/ui/game/fog_painter.dart';
import 'package:kenoma/ui/game/rain_painter.dart';
import 'package:kenoma/ui/menu/bestiary_screen.dart';
import 'package:kenoma/ui/menu/chat_screen.dart';
import 'package:kenoma/ui/menu/radar_screen.dart';
import 'package:kenoma/world/fog.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/radar.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();
  final street = loadStreetBalance();
  const t = 1790040000;

  GameState state() => GameState(groupCode: 'KENOMA-TESTE', balance: data.progress);

  Future<void> tall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  group('Radar', () {
    testWidgets('um toque varre, mostra o resultado e depois recarrega por 2 minutos', (tester) async {
      await tall(tester);
      final s = state();
      var now = t;
      var sweeps = 0;
      await tester.pumpWidget(MaterialApp(
        home: RadarScreen(
          state: s,
          street: street,
          nowUtc: () => now,
          onSweep: () {
            sweeps++;
            s.recordSweep(now, const [], now + 900);
            return const RadarOutcome(traces: [], revealed: []);
          },
        ),
      ));
      expect(find.text('SCANNER NÍVEL 1'), findsOneWidget);
      await tester.tap(find.text('VARRER'));
      await tester.pump();
      expect(sweeps, 1);
      expect(find.byKey(const Key('radar-result')), findsOneWidget);
      expect(find.text('NADA RARO POR PERTO.'), findsOneWidget);
      expect(find.text('RECARREGANDO 2:00'), findsOneWidget);
      await tester.tap(find.text('RECARREGANDO 2:00'));
      await tester.pump();
      expect(sweeps, 1, reason: 'carregando: o toque não varre');
      now += 121;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('VARRER'), findsOneWidget);
    });

    testWidgets('o nível 2 do scanner (nível 5 do Conjurador) aparece no texto', (tester) async {
      await tall(tester);
      final s = state()..levelOverride = 5;
      await tester.pumpWidget(MaterialApp(home: RadarScreen(state: s, street: street, nowUtc: () => t, onSweep: () => const RadarOutcome(traces: [], revealed: []))));
      expect(find.text('SCANNER NÍVEL 2'), findsOneWidget);
      expect(find.textContaining('MOSTRAM O TIPO'), findsOneWidget);
    });
  });

  group('folha de preparo', () {
    testWidgets('mostra o comportamento e a variante do Eco', (tester) async {
      await tall(tester);
      final species = data.species('soot.eco')!;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PrepSheet(
            species: species,
            level: 5,
            seals: data.tuning.seals,
            count: (_) => 3,
            tonics: 0,
            behavior: EcoBehavior.skittish,
            variant: data.variantInfo(biome: 'green'),
          ),
        ),
      ));
      expect(find.byKey(const Key('prep-behavior')), findsOneWidget);
      expect(find.textContaining('ARISCO'), findsOneWidget);
      expect(find.textContaining('FOGE'), findsOneWidget);
      expect(find.byKey(const Key('prep-variant')), findsOneWidget);
      expect(find.textContaining('VARIANTE VERDE'), findsOneWidget);
    });

    testWidgets('um Eco comum não ganha linha de comportamento nem de variante', (tester) async {
      await tall(tester);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: PrepSheet(species: data.species('soot.eco')!, level: 5, seals: data.tuning.seals, count: (_) => 3, tonics: 0))));
      expect(find.byKey(const Key('prep-behavior')), findsNothing);
      expect(find.byKey(const Key('prep-variant')), findsNothing);
    });

    test('cada comportamento tem uma dica própria', () {
      final hints = {for (final b in EcoBehavior.values) behaviorHint(b)};
      expect(hints.length, EcoBehavior.values.length);
    });
  });

  group('coleção e bestiário com variantes', () {
    testWidgets('a coleção mostra a variante e o traço da criatura', (tester) async {
      await tall(tester);
      final s = state();
      s.capture(uid: 1, speciesId: 'rill.eco', level: 4, nowUtc: t, variant: 'water');
      s.capture(uid: 2, speciesId: 'rill.eco', level: 4, nowUtc: t, shiny: true);
      s.capture(uid: 3, speciesId: 'rill.eco', level: 4, nowUtc: t);
      await tester.pumpWidget(MaterialApp(home: CollectionScreen(state: s, data: data)));
      await tester.pump();
      expect(find.byKey(const Key('variant-1')), findsOneWidget);
      expect(find.textContaining('VARIANTE AQUÁTICA'), findsOneWidget);
      expect(find.byKey(const Key('variant-2')), findsOneWidget);
      expect(find.textContaining('VARIANTE BRILHANTE'), findsOneWidget);
      expect(find.byKey(const Key('variant-3')), findsNothing, reason: 'a comum não tem linha de variante');
    });

    testWidgets('o bestiário marca vista e capturada por variante', (tester) async {
      await tall(tester);
      final s = state();
      s.markSeen('soot.eco');
      s.markSeen('soot.eco', variant: 'urban');
      s.capture(uid: 5, speciesId: 'soot.eco', level: 3, nowUtc: t, variant: 'green');
      s.markSeen('soot.eco', shiny: true);
      await tester.pumpWidget(MaterialApp(home: BestiaryScreen(state: s, data: data)));
      await tester.pump();
      expect(find.byKey(const Key('bestiary-soot.eco@urban')), findsOneWidget);
      expect(find.text('URBANA: VISTA'), findsOneWidget);
      expect(find.text('VERDE: CAPTURADA'), findsOneWidget);
      expect(find.text('BRILHANTE: VISTA'), findsOneWidget);
      expect(find.byKey(const Key('bestiary-soot.eco@water')), findsNothing, reason: 'não vista: não aparece');
    });

    test('capturar uma variante marca a espécie e a variante; ver o Brilhante conta para o Familiar', () {
      final s = state();
      s.capture(uid: 9, speciesId: 'frond.eco', level: 3, nowUtc: t, variant: 'green', shiny: true);
      for (final k in ['frond.eco', 'frond.eco@green', 'frond.eco@shiny']) {
        expect((s.bestiary[k]!.seen, s.bestiary[k]!.captured), (true, true), reason: k);
      }
      expect(s.hasCaptured('frond.eco'), isTrue);
      final seen = state()..markSeen('soot.eco', variant: 'urban', shiny: true);
      expect((seen.story.count('variant_seen'), seen.story.count('shiny_seen')), (1, 1));
      expect(state().story.count('shiny_seen'), 0);
    });

    test('uma variante vista não conta duas vezes, e a espécie comum não gera evento', () {
      final s = state()..markSeen('soot.eco')..markSeen('soot.eco');
      expect((s.story.count('variant_seen'), s.story.count('shiny_seen')), (0, 0));
    });
  });

  group('falas do Familiar', () {
    final script = data.mentor;

    test('o Familiar tem 3 falas, ligadas a variante, Brilhante e Radar, no JSON e no documento de revisão', () {
      final street = script.familiar.where((m) => RegExp(r'^f\d+$').hasMatch(m.id)); // as de outras fatias têm prefixo (`fusion_f01`)
      expect(street.map((m) => m.id), ['f01', 'f02', 'f03']);
      expect(script.familiar.every((m) => m.from == 'familiar' && m.requires != null), isTrue);
      expect(street.map((m) => m.requires!.event), ['variant_seen', 'shiny_seen', 'hidden_revealed']);
    });

    test('saem sozinhas quando o acontecimento acontece, uma vez cada, e não atrapalham o tutorial', () {
      final chat = ChatState();
      expect(chat.deliverFamiliar(t, script, (_) => 0), isEmpty);
      final first = chat.deliverFamiliar(t, script, (e) => e == 'shiny_seen' ? 1 : 0);
      expect(first.map((m) => m.id), ['f02']);
      expect(chat.deliverFamiliar(t + 1, script, (e) => e == 'shiny_seen' ? 1 : 0), isEmpty, reason: 'só uma vez');
      final rest = chat.deliverFamiliar(t + 2, script, (_) => 1);
      expect(rest.map((m) => m.id).where((id) => RegExp(r'^f\d+$').hasMatch(id)), ['f01', 'f03']);
      expect(chat.mentorDelivered(script), 0, reason: 'as falas do Familiar não contam como o tutorial do mentor');
      expect(chat.tick(script.tutorial.first.afterS, t + 3, script, (_) => 0)?.id, script.tutorial.first.id);
    });

    test('pelo estado do jogo: ver o primeiro Brilhante faz o Familiar falar na hora do tique', () {
      final s = state();
      final notices = <String>[];
      s.onNotice = notices.add;
      s.markSeen('soot.eco', shiny: true);
      s.tickChat(1, t, script);
      expect(s.story.chat.delivered.map((e) => e.id), ['f02']);
      expect(notices.single, contains('Familiar'));
      expect(s.story.chat.unread, 1);
    });

    testWidgets('no chat a fala do Familiar tem o nome dele e a borda ciano', (tester) async {
      await tall(tester);
      final s = state()..markSeen('soot.eco', variant: 'urban');
      s.tickChat(1, t, script);
      await tester.pumpWidget(MaterialApp(home: ChatScreen(state: s, data: data)));
      await tester.pump();
      expect(find.byKey(const Key('chat-f01')), findsOneWidget);
      expect(find.text('FAMILIAR'), findsOneWidget);
    });
  });

  group('chuva e névoa', () {
    test('a chuva sobe devagar com o clima, a tempestade pesa mais e sem chuva as gotas somem', () {
      final rain = RainPainter(maxDrops: 70);
      const size = ui.Size(411, 914);
      for (var i = 0; i < 300; i++) {
        rain.update(1 / 30, size, 1.0);
      }
      final light = rain.count;
      expect(light, inInclusiveRange(55, 76));
      for (var i = 0; i < 300; i++) {
        rain.update(1 / 30, size, 1.6);
      }
      expect(rain.count, greaterThan(light));
      expect(rain.count, lessThanOrEqualTo(120));
      rain.update(1 / 30, size, 0);
      expect(rain.count, greaterThan(0), reason: 'não corta de uma vez');
      for (var i = 0; i < 600; i++) {
        rain.update(1 / 30, size, 0);
      }
      expect(rain.count, 0);
    });

    test('o véu recorta uma célula por célula revelada à vista, e nada sem névoa revelada', () {
      const size = ui.Size(411, 914);
      final cam = MapCamera.atLatLon(-22.8174, -47.0697, pixelsPerCell: 80);
      final fog = FogState();
      final painter = FogPainter();
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      painter.paint(canvas, size, cam, fog);
      expect(painter.lastCut, 0);
      fog.reveal(cam.centerX, cam.centerY, 40, 17.6);
      painter.paint(canvas, size, cam, fog);
      expect(painter.lastCut, fog.revealedCount);
      expect(painter.lastCut, greaterThan(3));
      rec.endRecording();
    });
  });
}

