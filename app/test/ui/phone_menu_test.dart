import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/astro.dart';
import 'package:kenoma/core/features.dart';
import 'package:kenoma/core/weather.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/ui/menu/chat_screen.dart';
import 'package:kenoma/ui/menu/forum_screen.dart';
import 'package:kenoma/ui/menu/phone_icons.dart';
import 'package:kenoma/ui/menu/phone_menu.dart';
import 'package:kenoma/ui/menu/phone_shell.dart';
import 'package:kenoma/ui/menu/phone_status.dart';
import 'package:kenoma/ui/menu/profile_screen.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();
  const t = 1790040000;
  const order = ['vision', 'radar', 'bestiary', 'circle', 'bag', 'bench', 'chat', 'forum', 'profile', 'settings'];

  GameState state(int level) => GameState(groupCode: 'KENOMA-TESTE', balance: data.progress)..levelOverride = level;

  Future<void> openPhone(WidgetTester tester, GameState s) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () => showPhoneMenu(
                context,
                state: s,
                data: data,
                settings: () => const PhoneScreen(title: 'Ajustes', child: SizedBox()),
                radar: () => const PhoneScreen(title: 'Radar', child: SizedBox()),
                nowUtc: () => t,
                epochId: () => 1,
                weather: () => Weather.rain,
                lat: () => -22.9,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> closePhone(WidgetTester tester) async {
    Navigator.of(tester.element(find.byKey(const Key('phone-screen')))).pop();
    await settle(tester);
  }

  test('a tabela vem do balance.json e os ícones são todos de 12 x 12', () {
    expect([for (final a in data.phone.apps) a.id], order);
    expect({for (final a in data.phone.apps) a.id: a.unlockLevel}, {'vision': 1, 'radar': 2, 'bestiary': 1, 'circle': 1, 'bag': 1, 'bench': 2, 'chat': 2, 'forum': 2, 'profile': 1, 'settings': 1});
    for (final id in order) {
      final art = phoneIconArt[id]!;
      expect(art.length, 12, reason: id);
      for (final row in art) {
        expect(row.length, 12, reason: id);
      }
    }
    for (final id in ['radar', 'bench', 'chat', 'forum']) {
      expect(data.mentor.phoneUnlock[id], isNotNull, reason: id);
    }
  });

  testWidgets('a grade lista os 10 apps na ordem e todos têm toque de pelo menos 48 dp', (tester) async {
    await openPhone(tester, state(2)..setSetting('phone_seen_radar', true));
    final pos = <double>[];
    for (final id in order) {
      final f = find.byKey(Key('app-$id'));
      expect(f, findsOneWidget, reason: id);
      expect(tester.getSize(f).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(f).height, greaterThanOrEqualTo(48));
      pos.add(tester.getTopLeft(f).dy * 1000 + tester.getTopLeft(f).dx);
    }
    expect(pos, [...pos]..sort(), reason: 'ordem de leitura');
    expect(find.text('VISÃO ESPECTRAL'), findsOneWidget);
    expect(find.text('???'), findsNothing);
  });

  testWidgets('apps acima do nível mostram ??? e não abrem; os do nível 1 abrem', (tester) async {
    final s = state(1);
    await openPhone(tester, s);
    expect(find.text('???'), findsNWidgets(4));
    expect(find.text('CHAT'), findsNothing);
    await tester.tap(find.byKey(const Key('app-chat')));
    await settle(tester);
    expect(find.byType(ChatScreen), findsNothing);
    await tester.tap(find.byKey(const Key('app-profile')));
    await settle(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byKey(const Key('profile-level')), findsOneWidget);
  });

  testWidgets('no nível 2 os apps abrem e o botão voltar de cada tela devolve ao celular', (tester) async {
    final s = state(2)..setSetting('phone_seen_radar', true);
    await openPhone(tester, s);
    for (final id in ['chat', 'forum', 'radar', 'settings', 'profile']) {
      await tester.tap(find.byKey(Key('app-$id')));
      await settle(tester);
      expect(find.byKey(const Key('phone-back')), findsOneWidget, reason: id);
      expect(tester.getSize(find.byKey(const Key('phone-back'))).shortestSide, greaterThanOrEqualTo(48));
      expect(find.byKey(const Key('phone-screen')).hitTestable(), findsNothing, reason: '$id cobre o celular');
      await tester.tap(find.byKey(const Key('phone-back')));
      await settle(tester);
      expect(find.byKey(const Key('phone-screen')), findsOneWidget, reason: '$id volta ao celular');
    }
    await tester.tap(find.byKey(const Key('app-chat')));
    await settle(tester);
    expect(find.byType(ChatScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('phone-back')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('app-forum')));
    await settle(tester);
    expect(find.byType(ForumScreen), findsOneWidget);
  });

  testWidgets('a Visão espectral fecha o celular', (tester) async {
    await openPhone(tester, state(1));
    await tester.tap(find.byKey(const Key('app-vision')));
    await settle(tester);
    expect(find.byKey(const Key('phone-screen')), findsNothing);
  });

  testWidgets('o app novo se forma uma vez, o Familiar comenta e fica marcado como visto', (tester) async {
    final s = state(2);
    await openPhone(tester, s);
    expect(find.byKey(const Key('familiar-balloon')), findsOneWidget);
    expect(find.textContaining(data.mentor.phoneUnlock['radar']!), findsOneWidget);
    await tester.pump(phoneFormDuration);
    for (final id in ['radar', 'bench', 'chat', 'forum']) {
      expect(s.setting('phone_seen_$id'), isTrue, reason: id);
    }
    expect(s.setting('phone_seen_bestiary'), isFalse, reason: 'apps do nível 1 já nascem abertos');
    await closePhone(tester);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
    expect(find.byKey(const Key('familiar-balloon')), findsNothing);
  });

  testWidgets('a bolinha laranja aparece no Chat com mensagem não lida e some ao ler', (tester) async {
    final s = state(2);
    s.tickChat(1000, t, data.mentor);
    await openPhone(tester, s);
    expect(find.byKey(const Key('badge-chat')), findsOneWidget);
    expect(find.byKey(const Key('badge-bench')), findsNothing);
    s.markChatRead();
    await tester.pump();
    expect(find.byKey(const Key('badge-chat')), findsNothing);
  });

  testWidgets('no nível 1 o Chat bloqueado não tem bolinha nem alerta no botão', (tester) async {
    final s = state(1);
    s.tickChat(1000, t, data.mentor);
    expect(phoneHasAlert(s, data.phone), isFalse);
    await openPhone(tester, s);
    expect(find.byKey(const Key('badge-chat')), findsNothing);
  });

  testWidgets('a barra de status mostra a hora, a lua e o clima; sem a Rua viva esconde o clima e o Radar', (tester) async {
    await openPhone(tester, state(2));
    expect(find.text(phoneClock(t)), findsOneWidget);
    expect(find.text(moonPhaseNames[moonPhase(t)]!.toUpperCase()), findsOneWidget);
    expect(find.byKey(const Key('status-weather')), findsOneWidget);
    expect(find.text('CHUVA'), findsOneWidget);
    await closePhone(tester);
    streetLifeEnabled = false;
    addTearDown(() => streetLifeEnabled = true);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
    expect(find.text(phoneClock(t)), findsOneWidget);
    expect(find.byKey(const Key('status-weather')), findsNothing);
    expect(find.byKey(const Key('app-radar')), findsNothing);
  });
}
