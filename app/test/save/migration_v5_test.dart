import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/conjurer_balance.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/save/migrations.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fixtures.dart';

/// `test/fixtures/save_v4_0140.json` foi gravado pelo código da própria 0.14.0 (build 0.14.0+22) a partir do save real da
/// 0.13.0, com jogo de verdade por cima: névoa, Radar, variante, Brilhante, XP até o nível 10.
void main() {
  final real = jsonDecode(File('test/fixtures/save_v4_0140.json').readAsStringSync()) as Map<String, dynamic>;

  test('o fixture é mesmo um save da 0.14.0: schema 4, névoa, Radar e criaturas com variante', () {
    expect((real['schema_version'], real['app_version']), (4, '0.14.0+22'));
    expect((real['player'] as Map)['level'], 10);
    expect(real.containsKey('conjurer'), isFalse);
    expect((real['fog'] as Map)['cells'], isNotEmpty);
    expect((real['collection'] as List).any((c) => (c as Map)['shiny'] == true), isTrue);
  });

  test('v4 vira v5: a escola entra vazia, os pontos de talento saem do nível e todo o resto passa intacto', () {
    final out = migrateSave(real);
    expect(out['schema_version'], 5);
    final c = out['conjurer'] as Map<String, dynamic>;
    expect(c['talent_earned'], 9, reason: 'nível 10: um ponto por nível subido');
    expect(c['talent_spent'], 0);
    expect(c['tests_offered'], false);
    expect(c.containsKey('school'), isFalse);
    for (final k in real.keys.where((k) => k != 'schema_version')) {
      expect(out[k], real[k], reason: 'o campo $k passa sem mudar');
    }
  });

  test('migrar duas vezes dá o mesmo, e um bloco conjurer que já existe não é sobrescrito', () {
    final once = migrateSave(real);
    expect(migrateSave(once), once);
    final custom = {...real, 'conjurer': {'school': 'sealer', 'talent_earned': 12}};
    expect(migrateSave(custom)['conjurer'], custom['conjurer']);
  });

  test('abrir o save da 0.14.0: o jogo é o mesmo, sem escola, com talentos pelo nível, e grava no schema 5', () async {
    final store = MemorySaveStore()..json = jsonDecode(jsonEncode(real)) as Map<String, dynamic>;
    final session = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1792090000, nextInt: (n) => 0, appVersion: '0.15.0+23');
    await session.flush();
    final s = session.state;
    expect((s.progress.level, s.progress.xp), ((real['player'] as Map)['level'], (real['player'] as Map)['xp']));
    expect(s.collection.length, (real['collection'] as List).length);
    expect(s.conjurer.school, isNull);
    expect(s.conjurer.talentAvailable, 9);
    expect(s.canChooseSchool, isTrue, reason: 'quem já passou do nível 3 recebe a escolha na próxima abertura');
    expect(s.fog.revealedCount, greaterThan(0));
    expect(s.founder!.chainValid, isTrue);
    expect(s.founder!.versionsSeen.map((e) => e.version).last, '0.15.0+23');
    expect(store.json!['schema_version'], 5);
    expect(store.json!['conjurer'], isNotNull);
  });

  test('o nível sobe e o talento acompanha; a escola só vale do nível 3 e é definitiva', () async {
    final store = MemorySaveStore();
    final session = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1792090000, nextInt: (n) => 0);
    final s = session.state;
    expect(s.canChooseSchool, isFalse);
    expect(s.chooseSchool(School.sealer), isFalse);
    s.progress.restBalance = 0;
    s.gainXp(60 + 140 + 240 + 5, 1792090000);
    expect(s.progress.level, 4);
    expect(s.conjurer.talentEarned, 3);
    expect(s.canChooseSchool, isTrue);
    expect(s.chooseSchool(School.shaman), isTrue);
    expect(s.chooseSchool(School.sealer), isFalse, reason: 'definitiva');
    expect(s.conjurer.school, School.shaman);
  });
}
