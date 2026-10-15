import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/dev/game_clock.dart';
import 'package:kenoma/dev/identity_section.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/save/founder.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fixtures.dart';

void main() {
  test('o relatório lê o registro do save, migra um save antigo e confere a cadeia', () async {
    final store = MemorySaveStore();
    var t = 1790040000;
    for (final v in ['0.11.0+17', '0.12.0+18']) {
      final s = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => t, nextInt: (n) => 0, appVersion: v, epochOf: (_) => 1);
      await s.flush();
      t += 100;
    }
    final r = IdentityReport.fromSave(store.json);
    expect(r.founder!.versionsSeen.map((e) => e.version), ['0.11.0+17', '0.12.0+18']);
    expect((r.chainValid, r.savedEpoch, r.appVersion, r.schemaVersion), (true, 1, '0.12.0+18', 2));

    final tampered = {...store.json!, 'founder': {...(store.json!['founder'] as Map<String, dynamic>), 'versions_seen': [(store.json!['founder'] as Map)['versions_seen'][1]]}};
    expect(IdentityReport.fromSave(tampered).chainValid, isFalse);

    final old = IdentityReport.fromSave({'schema_version': 1, 'group_code': 'AAAAA-BBBBB'});
    expect((old.founder, old.chainValid, old.schemaVersion), (null, false, 2));
    expect(IdentityReport.fromSave(null).groupCode, isNull);
  });

  testWidgets('a seção do menu de debug mostra player_id, log de versões e época', (tester) async {
    final store = MemorySaveStore();
    final s = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1790040000, nextInt: (n) => 0, appVersion: '0.12.0+18', epochOf: (_) => 0);
    await s.flush();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: IdentitySection(clock: GameClock(), store: store)))));
    await tester.pump();
    await tester.pump();
    expect(find.text(s.state.founder!.playerId), findsOneWidget);
    expect(find.textContaining('VERSIONS_SEEN · 1 · CADEIA ÍNTEGRA'), findsOneWidget);
    expect(find.textContaining('0.12.0+18'), findsWidgets);
    expect(find.textContaining('ÉPOCA'), findsOneWidget);
    expect(Founder.fromJson(store.json!['founder'] as Map<String, dynamic>).chainValid, isTrue);
  });
}
