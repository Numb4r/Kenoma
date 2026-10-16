import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/conjurer_balance.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/save/save_store.dart';
import 'package:kenoma/ui/menu/chat_screen.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();
  const t = 1790040000;
  GameState state({int? level}) => GameState(groupCode: 'KENOMA-TESTE', balance: data.progress)..levelOverride = level;
  int offers(GameState s) => s.story.chat.delivered.where((e) => e.id == 'school_tests').length;

  test('o convite dos testes tem texto, botão e id estável no mentor.json', () {
    final m = data.mentor.byId('school_tests')!;
    expect((m.from, m.action), ('mentor', 'school_tests'));
    expect(data.mentor.school.map((x) => x.id), contains('school_after'));
    for (final s in School.values) {
      expect(data.mentor.byId('school_best_${s.id}'), isNotNull);
      expect(data.mentor.byId('school_choose_${s.id}'), isNotNull);
      expect(data.mentor.byId('school_best_${s.id}')!.text, startsWith('*'));
    }
  });

  test('sai só do nível 3 em diante, uma vez só', () {
    final low = state(level: 2);
    for (var i = 0; i < 5; i++) {
      low.tickChat(1, t + i, data.mentor);
    }
    expect(offers(low), 0);
    expect(low.conjurer.testsOffered, isFalse);

    final s = state(level: 3);
    s.tickChat(1, t, data.mentor);
    expect(offers(s), 1);
    expect(s.conjurer.testsOffered, isTrue);
    expect(s.story.chat.unread, greaterThan(0));
    for (var i = 1; i < 50; i++) {
      s.tickChat(100, t + i, data.mentor);
    }
    expect(offers(s), 1);
  });

  test('quem já escolheu a escola não recebe o convite', () {
    final s = state(level: 5)..conjurer.school = School.sealer;
    s.tickChat(1, t, data.mentor);
    expect(offers(s), 0);
  });

  test('save antigo já no nível 10 recebe na primeira abertura, e não de novo na seguinte', () async {
    final real = jsonDecode(File('test/fixtures/save_v4_0140.json').readAsStringSync()) as Map<String, dynamic>;
    final store = MemorySaveStore()..json = jsonDecode(jsonEncode(real)) as Map<String, dynamic>;
    Future<GameSession> open() => GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1792090000, nextInt: (n) => 0, appVersion: '0.15.0+23');

    var session = await open();
    expect(session.state.conjurer.testsOffered, isFalse);
    session.state.tickChat(1, 1792090000, data.mentor);
    expect(offers(session.state), 1);
    await session.flush();

    session = await open();
    expect(session.state.conjurer.testsOffered, isTrue);
    session.state.tickChat(1, 1792090100, data.mentor);
    expect(offers(session.state), 1, reason: 'a mensagem não se repete');
  });

  test('escolher a escola entrega a fala do mentor e a do Familiar daquela escola, uma vez cada', () {
    final s = state(level: 3);
    s.tickChat(1, t, data.mentor);
    expect(s.chooseSchool(School.shaman), isTrue);
    s.tickChat(1, t + 1, data.mentor);
    s.tickChat(1, t + 2, data.mentor);
    final ids = [for (final e in s.story.chat.delivered) e.id];
    expect(ids.where((i) => i == 'school_after'), hasLength(1));
    expect(ids.where((i) => i == 'school_choose_shaman'), hasLength(1));
    expect(ids, isNot(contains('school_choose_sealer')));
    expect(ids, isNot(contains('school_choose_technomancer')));
  });

  test('o comentário do melhor teste só sai quando o fluxo mostra a tela de escolha', () {
    final s = state(level: 3);
    s.tickChat(1, t, data.mentor);
    expect(s.story.chat.delivered.any((e) => e.id.startsWith('school_best_')), isFalse);
    s.recordEvent('school_best_sealer', '', 1);
    s.tickChat(1, t + 1, data.mentor);
    expect(s.story.chat.delivered.where((e) => e.id == 'school_best_sealer'), hasLength(1));
  });

  testWidgets('o Chat mostra o botão da mensagem, e ele some quando a escola já foi escolhida', (tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final s = state(level: 3);
    s.tickChat(1, t, data.mentor);
    await tester.pumpWidget(MaterialApp(home: ChatScreen(state: s, data: data)));
    await tester.pump();
    expect(find.byKey(const Key('chat-school_tests')), findsOneWidget);
    expect(find.byKey(const Key('chat-action-school_tests')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-action-school_tests')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('school-test-technomancer')), findsOneWidget, reason: 'o fluxo abriu na lista de testes');
    await tester.tap(find.byKey(const Key('phone-back')).last);
    await tester.pumpAndSettle();

    s.chooseSchool(School.sealer);
    await tester.pump();
    expect(find.byKey(const Key('chat-action-school_tests')), findsNothing);
    expect(find.byKey(const Key('chat-action-done')), findsOneWidget);
  });
}
