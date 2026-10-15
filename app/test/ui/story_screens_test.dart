import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/ui/menu/chat_screen.dart';
import 'package:kenoma/ui/menu/forum_screen.dart';
import 'package:kenoma/ui/menu/phone_menu.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();
  const t = 1790040000;
  const day = 20717;
  GameState state() => GameState(groupCode: 'KENOMA-TESTE', balance: data.progress);

  Future<void> tall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  testWidgets('o chat mostra o contato e as mensagens entregues, e abrir marca tudo como lido', (tester) async {
    await tall(tester);
    final s = state();
    s.tickChat(1000, t, data.mentor);
    s.tickChat(1000, t + 5, data.mentor);
    expect(s.story.chat.unread, 2);
    await tester.pumpWidget(MaterialApp(home: ChatScreen(state: s, data: data)));
    await tester.pump();
    await tester.pump();
    expect(find.text('NÚMERO DESCONHECIDO'), findsNWidgets(2), reason: 'o subtítulo e o contato');
    expect(find.byKey(Key('chat-${data.mentor.tutorial[0].id}')), findsOneWidget);
    expect(find.byKey(Key('chat-${data.mentor.tutorial[1].id}')), findsOneWidget);
    expect(find.byKey(Key('chat-${data.mentor.tutorial[2].id}')), findsNothing, reason: 'ainda não chegou');
    expect(s.story.chat.unread, 0);
  });

  testWidgets('o chat vazio diz para andar um pouco', (tester) async {
    await tall(tester);
    await tester.pumpWidget(MaterialApp(home: ChatScreen(state: state(), data: data)));
    await tester.pump();
    expect(find.textContaining('NENHUMA MENSAGEM'), findsOneWidget);
  });

  testWidgets('o fórum mostra os três pedidos como posts, entrega o que está pronto e troca um por dia', (tester) async {
    await tall(tester);
    final s = state()..ensureDaily(data.forum, 1, day);
    await tester.pumpWidget(MaterialApp(home: ForumScreen(state: s, data: data, nowUtc: () => t, epochId: () => 1)));
    await tester.pump();
    for (var slot = 0; slot < 3; slot++) {
      expect(find.byKey(Key('quest-$slot')), findsOneWidget);
    }
    expect(find.text('LIMEN'), findsOneWidget);
    expect(find.text('ENTREGAR'), findsNWidgets(3));

    final q = s.story.daily.atSlot(2)!;
    s.recordEvent(q.kind, q.key == 'any' ? '' : q.key, q.target);
    await tester.pump();
    final xpBefore = s.progress.xp + s.progress.level;
    await tester.tap(find.descendant(of: find.byKey(const Key('quest-2')), matching: find.text('ENTREGAR')));
    await tester.pump();
    expect(find.descendant(of: find.byKey(const Key('quest-2')), matching: find.text('ENTREGUE')), findsOneWidget);
    expect(s.progress.xp + s.progress.level, greaterThan(xpBefore));

    final before = s.story.daily.atSlot(0)!.text;
    await tester.tap(find.descendant(of: find.byKey(const Key('quest-0')), matching: find.text('TROCAR')));
    await tester.pump();
    expect(s.story.daily.rerolls, 1);
    expect(find.text('TROCAR'), findsNothing, reason: 'um reroll por dia');
    expect(before, isNotNull);
  });

  testWidgets('o celular avisa com um ponto quando há mensagem nova ou pedido pronto', (tester) async {
    final s = state()..ensureDaily(data.forum, 1, day);
    expect(phoneHasAlert(s), isFalse);
    s.tickChat(1000, t, data.mentor);
    expect(phoneHasAlert(s), isTrue);
    s.markChatRead();
    expect(phoneHasAlert(s), isFalse);
    final q = s.story.daily.atSlot(2)!;
    s.recordEvent(q.kind, q.key == 'any' ? '' : q.key, q.target);
    expect(phoneHasAlert(s), isTrue);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PhoneButton(onTap: () {}, alert: true))));
    expect(find.byKey(const Key('phone-alert')), findsOneWidget);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PhoneButton(onTap: () {}))));
    expect(find.byKey(const Key('phone-alert')), findsNothing);
  });
}
