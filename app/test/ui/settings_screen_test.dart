import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/save/backup.dart';
import 'package:kenoma/save/backup_io.dart';
import 'package:kenoma/save/ksv1.dart';
import 'package:kenoma/save/save_store.dart';
import 'package:kenoma/story/local_notifier.dart';
import 'package:kenoma/story/notification_plan.dart';
import 'package:kenoma/ui/settings/settings_screen.dart';

import '../support/fixtures.dart';

class _FakeNotifier implements Notifier {
  bool grant = true;
  int asked = 0;
  final applied = <List<PlannedNotification>>[];

  @override
  Future<bool> requestPermission() async {
    asked++;
    return grant;
  }

  @override
  Future<void> apply(List<PlannedNotification> plan) async => applied.add(plan);
}

class _FakeIo implements BackupIo {
  Uint8List? toPick;
  final shared = <(String, Uint8List)>[];

  @override
  Future<Uint8List?> pick() async => toPick;

  @override
  Future<void> share(Uint8List bytes, String name) async => shared.add((name, bytes));
}

void main() {
  final data = loadGameData();
  const t = 1790040000; // dentro da época 0

  Future<GameSession> session(MemorySaveStore store, {String code = 'AAAAA-BBBBB'}) async {
    store.json ??= {'schema_version': 2, 'group_code': code};
    final s = await GameSession.open(store: store, startInventory: {}, balance: data.progress, nowUtc: () => t, nextInt: (n) => 0, appVersion: '0.12.0+18');
    await s.flush();
    return s;
  }

  var restarts = 0;
  var follow = false;

  Future<void> pump(WidgetTester tester, GameSession s, {_FakeIo? io, String? scanned, int? now, _FakeNotifier? notifier}) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    restarts = 0;
    follow = false;
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        session: s,
        data: data,
        nowUtc: () => now ?? t,
        realNowUtc: () => now ?? t,
        appVersion: '0.12.0+18',
        cellSideM: () => 35.2,
        followHeading: () => follow,
        onFollowHeading: (on) => follow = on,
        onRestart: () async => restarts++,
        io: io ?? _FakeIo(),
        notifier: notifier ?? _FakeNotifier(),
        scan: (_) async => scanned,
      ),
    ));
    await tester.pump();
  }

  testWidgets('mostra o código do grupo, o QR, a época, a versão e o player_id', (tester) async {
    final s = await session(MemorySaveStore());
    await pump(tester, s);
    expect(find.byKey(const Key('group-code')), findsOneWidget);
    expect(find.text('AAAAA-BBBBB'), findsOneWidget);
    expect(find.text('ÉPOCA 0'), findsOneWidget);
    expect(find.text('VERSÃO 0.12.0+18'), findsOneWidget);
    expect(find.text(s.state.founder!.playerId), findsOneWidget);
    expect(find.textContaining('DESATUALIZADO'), findsNothing);
  });

  testWidgets('depois do fim da última época avisa que o mundo está desatualizado', (tester) async {
    final s = await session(MemorySaveStore());
    await pump(tester, s, now: data.schedule.epochs.last.validUntilUtc + 10);
    expect(find.textContaining('MUNDO DESATUALIZADO'), findsOneWidget);
  });

  testWidgets('entrar noutro grupo pede confirmação; confirmando troca a seed, limpa o registro e recomeça o mapa', (tester) async {
    final store = MemorySaveStore();
    final s = await session(store);
    s.state.markDone(5, t);
    s.state.capture(uid: 1, speciesId: 'soot.eco', level: 2, nowUtc: t);
    await pump(tester, s);
    await tester.tap(find.text('ENTRAR NOUTRO GRUPO'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ccccc-ddddd');
    await tester.tap(find.text('ENTRAR'));
    await tester.pumpAndSettle();
    expect(find.text('TROCAR DE GRUPO?'), findsOneWidget);
    expect(s.state.groupCode, 'AAAAA-BBBBB', reason: 'ainda não trocou');
    await tester.tap(find.text('TROCAR'));
    await tester.pumpAndSettle();
    expect(s.state.groupCode, 'CCCCC-DDDDD');
    expect(s.state.registrySize, 0);
    expect(s.state.collection, hasLength(1));
    expect(restarts, 1);
    expect(store.json!['group_code'], 'CCCCC-DDDDD');
  });

  testWidgets('cancelar a confirmação não troca nada', (tester) async {
    final s = await session(MemorySaveStore());
    await pump(tester, s);
    await tester.tap(find.text('ENTRAR NOUTRO GRUPO'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ZZZZZ-99999');
    await tester.tap(find.text('ENTRAR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();
    expect(s.state.groupCode, 'AAAAA-BBBBB');
    expect(restarts, 0);
  });

  testWidgets('código inválido não segue, e o QR lido preenche o campo', (tester) async {
    final s = await session(MemorySaveStore());
    await pump(tester, s, scanned: 'QQQQQ-WWWWW');
    await tester.tap(find.text('ENTRAR NOUTRO GRUPO'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.tap(find.text('ENTRAR'));
    await tester.pumpAndSettle();
    expect(find.textContaining('6 a 20'), findsOneWidget);
    await tester.tap(find.text('ESCANEAR QR'));
    await tester.pumpAndSettle();
    expect(find.text('QQQQQ-WWWWW'), findsWidgets);
  });

  testWidgets('exportar manda o save em KSV1 com nome de backup', (tester) async {
    final s = await session(MemorySaveStore());
    s.state.capture(uid: 1, speciesId: 'soot.eco', level: 2, nowUtc: t);
    final io = _FakeIo();
    await pump(tester, s, io: io);
    await tester.tap(find.text('EXPORTAR BACKUP'));
    await tester.pumpAndSettle();
    expect(io.shared, hasLength(1));
    expect(io.shared.single.$1, startsWith('kenoma-backup-'));
    final back = decodeKsv(io.shared.single.$2);
    expect(back['group_code'], 'AAAAA-BBBBB');
    expect((back['collection'] as List), hasLength(1));
  });

  testWidgets('importar mostra nível, criaturas e a data antes de substituir; confirmando troca o jogo', (tester) async {
    final other = MemorySaveStore();
    final theirs = await session(other, code: 'XXXXX-YYYYY');
    theirs.state.gainXp(300, t);
    for (var i = 0; i < 3; i++) {
      theirs.state.capture(uid: i + 1, speciesId: 'rill.eco', level: 2, nowUtc: t);
    }
    final bytes = exportBackup(theirs.state.toJson(t));

    final mine = MemorySaveStore();
    final s = await session(mine);
    final io = _FakeIo()..toPick = bytes;
    await pump(tester, s, io: io);
    await tester.tap(find.text('IMPORTAR BACKUP'));
    await tester.pumpAndSettle();
    expect(find.text('SUBSTITUIR O JOGO?'), findsOneWidget);
    expect(find.textContaining('NÍVEL ${theirs.state.progress.level} · 3 CRIATURAS'), findsOneWidget);
    expect(find.textContaining('XXXXX-YYYYY'), findsWidgets);
    final local = DateTime.fromMillisecondsSinceEpoch(t * 1000, isUtc: true).toLocal(); // a data é mostrada no horário local
    expect(find.textContaining('${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}'), findsWidgets);
    expect(mine.json!['group_code'], 'AAAAA-BBBBB', reason: 'ainda não substituiu');

    await tester.tap(find.text('IMPORTAR').last);
    await tester.pumpAndSettle();
    expect(mine.json!['group_code'], 'XXXXX-YYYYY');
    expect((mine.json!['collection'] as List), hasLength(3));
    expect(restarts, 1);
  });

  testWidgets('importar e cancelar não mexe no jogo; arquivo inválido avisa e não mexe', (tester) async {
    final other = MemorySaveStore();
    final theirs = await session(other, code: 'XXXXX-YYYYY');
    final mine = MemorySaveStore();
    final s = await session(mine);
    final io = _FakeIo()..toPick = exportBackup(theirs.state.toJson(t));
    await pump(tester, s, io: io);
    await tester.tap(find.text('IMPORTAR BACKUP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();
    expect(mine.json!['group_code'], 'AAAAA-BBBBB');

    io.toPick = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38]);
    await tester.tap(find.text('IMPORTAR BACKUP'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Esse arquivo não serve'), findsOneWidget);
    expect(mine.json!['group_code'], 'AAAAA-BBBBB');
    expect(restarts, 0);
  });

  testWidgets('os interruptores do mapa: nomes de rua ficam no save, seguir direção chama o mapa', (tester) async {
    final s = await session(MemorySaveStore());
    await pump(tester, s);
    expect(s.state.setting('street_names'), isFalse);
    await tester.tap(find.text('Nomes de rua'));
    await tester.pump();
    expect(s.state.setting('street_names'), isTrue);
    await tester.tap(find.text('Seguir direção'));
    await tester.pump();
    expect(follow, isTrue);
  });

  testWidgets('avisos no celular: desligados por padrão; ligar pede a permissão e agenda; negar deixa desligado; desligar cancela', (tester) async {
    final s = await session(MemorySaveStore());
    final n = _FakeNotifier();
    await pump(tester, s, notifier: n);
    expect(s.state.setting('notifications'), isFalse);
    expect(n.asked, 0);

    n.grant = false;
    await tester.tap(find.text('Avisos no celular'));
    await tester.pump();
    expect(n.asked, 1);
    expect(s.state.setting('notifications'), isFalse, reason: 'permissão negada: continua desligado');
    expect(n.applied, isEmpty);

    n.grant = true;
    await tester.tap(find.text('Avisos no celular'));
    await tester.pump();
    expect(s.state.setting('notifications'), isTrue);
    expect(n.applied.single.map((p) => p.id), contains(notifyDailyId));

    await tester.tap(find.text('Avisos no celular'));
    await tester.pump();
    expect(s.state.setting('notifications'), isFalse);
    expect(n.applied.last, isEmpty, reason: 'desligar cancela tudo');
  });
}
