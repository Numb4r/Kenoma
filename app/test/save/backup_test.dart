import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/player/mark.dart';
import 'package:kenoma/save/backup.dart';
import 'package:kenoma/save/ksv1.dart';
import 'package:kenoma/save/save_store.dart';
import 'package:kenoma/world/spawn_field.dart';

import '../support/fixtures.dart';

void main() {
  final b = loadProgressBalance();
  const t = 1790040000;

  Future<GameSession> played(MemorySaveStore store) async {
    final s = await GameSession.open(store: store, startInventory: {'item.chalk': 3}, balance: b, nowUtc: () => t, nextInt: (n) => 7, appVersion: '0.12.0+18');
    s.state.gainXp(500, t);
    s.state.capture(uid: 9, speciesId: 'soot.eco', level: 4, nowUtc: t);
    s.state.capture(uid: 10, speciesId: 'rill.eco', level: 2, nowUtc: t);
    s.state.toggleCircle('9');
    await s.flush();
    return s;
  }

  group('backup de ida e volta', () {
    test('exportar e importar noutro aparelho devolve o mesmo jogo', () async {
      final a = await played(MemorySaveStore());
      final bytes = exportBackup(a.state.toJson(t));

      final other = MemorySaveStore();
      await restoreBackup(other, readBackup(bytes));
      final restored = await GameSession.open(store: other, startInventory: {}, balance: b, nowUtc: () => t + 99, nextInt: (n) => 0, appVersion: '0.12.0+18');
      final r = restored.state, o = a.state;
      expect(r.groupCode, o.groupCode);
      expect((r.progress.level, r.progress.xp), (o.progress.level, o.progress.xp));
      expect(r.collection.map((c) => (c.uid, c.speciesId, c.level)), o.collection.map((c) => (c.uid, c.speciesId, c.level)));
      expect(r.circle, ['9']);
      expect(r.count('item.chalk'), 3);
      expect(r.founder!.playerId, o.founder!.playerId);
      expect(r.bestiary.keys, o.bestiary.keys);
    });

    test('a pré-visualização mostra nível, criaturas e a data do backup', () async {
      final a = await played(MemorySaveStore());
      final p = previewBackup(readBackup(exportBackup(a.state.toJson(t))));
      expect((p.level, p.creatures, p.savedUtc, p.groupCode, p.appVersion), (a.state.progress.level, 2, t, a.state.groupCode, '0.12.0+18'));
      expect(p.level, greaterThan(1));
    });

    test('um backup do formato antigo também importa, migrado', () {
      final v1 = {
        'schema_version': 1,
        'group_code': 'AAAAA-BBBBB',
        'player_level': 5,
        'saved_utc': 77,
        'collection': [
          {'uid': '1', 'species': 'soot.eco', 'level': 2, 'xp': 0, 'captured_utc': 5},
        ],
      };
      final json = readBackup(exportBackup(v1));
      expect(json['schema_version'], 2);
      final p = previewBackup(json);
      expect((p.level, p.creatures, p.savedUtc), (1, 1, 77));
    });

    test('arquivo corrompido, que não é KSV1 ou que não é um jogo é recusado antes de qualquer troca', () async {
      final good = exportBackup((await played(MemorySaveStore())).state.toJson(t));
      final flipped = Uint8List.fromList(good)..[good.length - 2] ^= 1;
      expect(() => readBackup(flipped), throwsA(isA<SaveCorrupt>()));
      expect(() => readBackup(File('pubspec.yaml').readAsBytesSync()), throwsA(isA<SaveCorrupt>()));
      expect(() => readBackup(exportBackup({'schema_version': 2, 'sem': 'jogo'})), throwsA(isA<SaveCorrupt>()));
    });

    test('importar substitui o jogo atual por inteiro', () async {
      final store = MemorySaveStore();
      final mine = await played(store);
      final theirs = await played(MemorySaveStore());
      theirs.state.changeGroup('ZZZZZ-99999');
      await restoreBackup(store, readBackup(exportBackup(theirs.state.toJson(t))));
      expect(store.json!['group_code'], 'ZZZZZ-99999');
      expect(mine.state.groupCode, isNot('ZZZZZ-99999'));
    });

    test('o nome do arquivo leva a data e a hora em UTC', () {
      expect(backupFileName(1790040000), 'kenoma-backup-20260922-012000.ksv');
    });
  });

  group('código do grupo', () {
    test('valida: letras e números, 6 a 20, com ou sem hífen e em qualquer caixa', () {
      for (final ok in ['ABCDE-12345', 'abcde12345', ' KENOMA-TESTE ', 'ABC123']) {
        expect(isValidGroupCode(ok), isTrue, reason: ok);
      }
      for (final bad in ['', 'ABC', 'ÇÃO123456', 'AB CD!EF12', 'A' * 21]) {
        expect(isValidGroupCode(bad), isFalse, reason: bad);
      }
    });

    test('a mesma seed para qualquer jeito de escrever o mesmo código', () {
      expect(seedGlobal('abcde-12345'), seedGlobal('ABCDE12345'));
      expect(seedGlobal('KENOMA-TESTE'), 0x6ebe19ac6345175f);
      expect(formatGroupCode('abcde12345'), 'ABCDE-12345');
    });

    test('QR: o que se mostra é o que se lê, e texto solto também serve', () {
      expect(groupQrPayload('abcde-12345'), 'kenoma:group:ABCDE12345');
      expect(parseGroupQr(groupQrPayload('abcde-12345')), 'ABCDE-12345');
      expect(parseGroupQr('KENOMA:GROUP:ABCDE12345'), 'ABCDE-12345');
      expect(parseGroupQr('abcde12345'), 'ABCDE-12345');
      expect(parseGroupQr('https://exemplo.com/x'), isNull);
      expect(parseGroupQr('kenoma:group:'), isNull);
    });

    test('um código sorteado passa na própria validação', () {
      var k = 0;
      final code = generateGroupCode((n) => (k++ * 7) % n);
      expect(isValidGroupCode(code), isTrue);
      expect(parseGroupQr(groupQrPayload(code)), code);
    });
  });

  group('trocar de grupo', () {
    GameState state() {
      final s = GameState(groupCode: 'AAAAA-BBBBB', balance: b);
      s.capture(uid: 1, speciesId: 'soot.eco', level: 3, nowUtc: t);
      s.toggleCircle('1');
      s.add('item.chalk', 2);
      s.markDone(5, t);
      s.addMark(
        Mark.of(WorldSpawn(uid: 8, kind: 'eco', entryId: 'soot.eco', quantity: 1, x: 1, y: 1, cellX: 0, cellY: 0, window: 0, level: 2), nowUtc: t, durationS: 300),
        t,
      );
      return s;
    }

    test('limpa o registro de coletas e as marcações, e mantém coleção, Círculo, inventário e nível', () {
      final s = state()..gainXp(200, t);
      final level = s.progress.level;
      final seed = s.seed;
      expect(s.changeGroup('ccccc-ddddd'), isTrue);
      expect(s.groupCode, 'CCCCC-DDDDD');
      expect(s.seed, isNot(seed));
      expect(s.seed, seedGlobal('CCCCCDDDDD'));
      expect(s.registrySize, 0);
      expect(s.marks, isEmpty);
      expect(s.circle, ['1']);
      expect((s.collection.length, s.count('item.chalk'), s.progress.level), (1, 2, level));
      expect(s.isDone(5), isFalse);
    });

    test('o mesmo código, escrito de outro jeito, não é troca e não apaga nada', () {
      final s = state();
      expect(s.changeGroup('aaaaa bbbbb'), isFalse);
      expect(s.registrySize, greaterThan(0));
      expect(s.groupCode, 'AAAAA-BBBBB');
    });

    test('a troca vai para o save e volta ao reabrir', () async {
      final store = MemorySaveStore();
      final session = await GameSession.open(store: store, startInventory: {}, balance: b, nowUtc: () => t, nextInt: (n) => 3);
      session.state.markDone(5, t);
      session.state.changeGroup('QQQQQ-WWWWW');
      await session.flush();
      final again = await GameSession.open(store: store, startInventory: {}, balance: b, nowUtc: () => t + 5, nextInt: (n) => 0);
      expect(again.state.groupCode, 'QQQQQ-WWWWW');
      expect(again.state.registrySize, 0);
    });
  });
}
