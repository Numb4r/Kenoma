import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_state.dart' show saveSchemaVersion;
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
    expect((r.chainValid, r.savedEpoch, r.appVersion, r.schemaVersion), (true, 1, '0.12.0+18', saveSchemaVersion));

    final tampered = {...store.json!, 'founder': {...(store.json!['founder'] as Map<String, dynamic>), 'versions_seen': [(store.json!['founder'] as Map)['versions_seen'][1]]}};
    expect(IdentityReport.fromSave(tampered).chainValid, isFalse);

    final old = IdentityReport.fromSave({'schema_version': 1, 'group_code': 'AAAAA-BBBBB'});
    expect((old.founder, old.chainValid, old.schemaVersion), (null, false, saveSchemaVersion));
    expect(IdentityReport.fromSave(null).groupCode, isNull);
  });

  testWidgets('a entrada do debug resume em uma linha e o detalhe recolhido traz player_id, log de versões e época', (tester) async {
    final store = MemorySaveStore();
    final s = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1790040000, nextInt: (n) => 0, appVersion: '0.12.0+18', epochOf: (_) => 0);
    await s.flush();
    final info = (await tester.runAsync(() => readIdentity(GameClock(), store: store)))!;
    final id = s.state.founder!.playerId;
    expect(info.line, allOf(startsWith('época '), contains('player_id ${id.substring(0, 8)}…'), contains('1 versões · cadeia íntegra')));
    expect(info.line, isNot(contains(id)), reason: 'a linha não mostra o player_id inteiro');
    expect(info.full, allOf(contains('player_id $id'), contains('0.12.0+18')));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: IdentityDetails(info: info)))));
    expect(find.textContaining(id), findsNothing, reason: 'recolhido');
    expect(find.text('VERSIONS_SEEN · 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('identity-details')));
    await tester.pump();
    expect(find.textContaining('player_id $id'), findsOneWidget);
    expect(Founder.fromJson(store.json!['founder'] as Map<String, dynamic>).chainValid, isTrue);
  });
}
