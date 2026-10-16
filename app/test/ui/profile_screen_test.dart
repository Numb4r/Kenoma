import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/features.dart';
import 'package:kenoma/player/conjurer_balance.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/save/founder.dart';
import 'package:kenoma/ui/menu/phone_apps.dart';
import 'package:kenoma/ui/menu/profile_screen.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();
  GameState state() => GameState(groupCode: 'KENOMA-TESTE', balance: data.progress);

  Future<void> open(WidgetTester tester, GameState s, {VoidCallback? onSettings, bool cell = true}) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        state: s,
        data: data,
        nowUtc: () => 1790040000,
        cellSideM: cell ? () => 35 : null,
        onOpenSettings: onSettings,
      ),
    ));
    await tester.pump();
  }

  testWidgets('o nome vazio vira Conjurador; editar e confirmar salva, limpo e com no máximo 20', (tester) async {
    final s = state();
    await open(tester, s);
    expect(find.text('Conjurador'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-name')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-name-field')), 'Zé da Luz!! 123456789012345678');
    await tester.tap(find.byKey(const Key('profile-name-ok')));
    await tester.pumpAndSettle();
    expect(s.conjurer.playerName, 'Zé da Luz 1234567890');
    expect(s.conjurer.playerName.length, 20);
    expect(find.text('Zé da Luz 1234567890'), findsOneWidget);
  });

  testWidgets('barra de XP no meio do caminho e no teto', (tester) async {
    final s = state();
    s.progress
      ..level = 2
      ..xp = s.progress.toNext ~/ 2;
    await open(tester, s);
    expect(find.text('${s.progress.xp} / ${s.progress.toNext} XP'), findsOneWidget);
    expect(find.textContaining('XP rendem o dobro'), findsOneWidget);

    s.progress.level = data.progress.playerLevelCap;
    s.setSetting('x', true);
    await tester.pump();
    expect(find.text('Nível máximo (${data.progress.playerLevelCap})'), findsOneWidget);
  });

  testWidgets('sem escola: aviso só se já pode escolher; com escola: nome da escola', (tester) async {
    final s = state();
    await open(tester, s);
    expect(find.text('Sem escola'), findsOneWidget);
    expect(find.byKey(const Key('profile-school-hint')), findsNothing);

    s.progress.level = s.cb.schoolLevel;
    s.setSetting('x', true);
    await tester.pump();
    expect(find.byKey(const Key('profile-school-hint')), findsOneWidget);

    s.conjurer.school = School.sealer;
    s.setSetting('y', true);
    await tester.pump();
    expect(find.text(School.sealer.label), findsOneWidget);
    expect(find.byKey(const Key('profile-school-hint')), findsNothing);
  });

  testWidgets('estatísticas: km, capturas e dias jogados', (tester) async {
    final s = state();
    s.recordEvent('walk_m', '', 1250);
    s.recordEvent('capture', 'fire', 3);
    s.conjurer.markDay(10);
    await open(tester, s);
    expect(find.text('1,3 km'), findsOneWidget);
    expect(find.text('ÁREA REVELADA'), findsOneWidget);
    expect(find.text('CAPTURAS'), findsOneWidget);
  });

  testWidgets('com a Rua viva desligada, a área revelada some', (tester) async {
    final old = streetLifeEnabled;
    streetLifeEnabled = false;
    addTearDown(() => streetLifeEnabled = old);
    await open(tester, state());
    expect(find.text('ÁREA REVELADA'), findsNothing);
    expect(find.text('FAGULHAS'), findsOneWidget);
  });

  testWidgets('selo de fundador só com founder; sem certificados a seção some', (tester) async {
    final s = state();
    await open(tester, s);
    expect(find.byKey(const Key('seal-founder')), findsNothing);
    expect(find.text('CERTIFICADOS'), findsNothing);

    s.founder = Founder.create(randomBytes: (n) => List.filled(n, 7), version: '0.15.0', utc: 1790040000);
    s.setSetting('x', true);
    await tester.pump();
    expect(find.byKey(const Key('seal-founder')), findsOneWidget);
    expect(find.text('CERTIFICADOS'), findsOneWidget);
  });

  testWidgets('o atalho de compartilhar seed chama os Ajustes; sem callback não aparece', (tester) async {
    var opened = 0;
    await open(tester, state(), onSettings: () => opened++);
    expect(find.text('KENOMA-TESTE'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-share-seed')));
    expect(opened, 1);

    await open(tester, state());
    expect(find.byKey(const Key('profile-share-seed')), findsNothing);
  });

  testWidgets('ver o Perfil apaga a bolinha de talento', (tester) async {
    final s = state();
    s.conjurer.talentEarned = 2;
    expect(profileHasNews(s), isTrue);
    await open(tester, s);
    await tester.pump();
    expect(profileHasNews(s), isFalse);
    expect(find.text('Pontos de talento: 2'), findsOneWidget);
  });
}
