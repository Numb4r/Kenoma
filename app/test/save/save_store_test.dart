import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/save/ksv1.dart';
import 'package:kenoma/save/ksv_save_store.dart';

import '../support/fixtures.dart';

void main() {
  late Directory dir;
  late KsvSaveStore store;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('kenoma_save');
    store = KsvSaveStore(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  List<int> copyBytes(File f) => f.readAsBytesSync();
  Map<String, dynamic> n(int v) => {'n': v, 'texto': 'ação $v'};

  group('formato KSV1', () {
    test('magic, SHA-256 do payload e JSON em gzip', () {
      final bytes = encodeKsv(n(1));
      expect(bytes.sublist(0, 4), utf8.encode('KSV1'));
      expect(bytes.length, greaterThan(36));
      expect(decodeKsv(bytes), n(1));
    });

    test('um bit mudado no payload derruba o checksum', () {
      final bytes = Uint8List.fromList(encodeKsv(n(1)));
      bytes[bytes.length - 3] ^= 1;
      expect(() => decodeKsv(bytes), throwsA(isA<SaveCorrupt>()));
    });

    test('magic errado, arquivo curto e vazio são corrompidos', () {
      final bytes = Uint8List.fromList(encodeKsv(n(1)))..[0] = 0x58;
      expect(() => decodeKsv(bytes), throwsA(isA<SaveCorrupt>()));
      expect(() => decodeKsv(encodeKsv(n(1)).sublist(0, 20)), throwsA(isA<SaveCorrupt>()));
      expect(() => decodeKsv(const []), throwsA(isA<SaveCorrupt>()));
    });

    test('payload com checksum certo mas que não é JSON de objeto também é rejeitado', () {
      final good = encodeKsv(n(1));
      final payload = gzip.encode(utf8.encode('[1,2]'));
      final bytes = BytesBuilder()
        ..add(good.sublist(0, 4))
        ..add(sha256Of(payload))
        ..add(payload);
      expect(() => decodeKsv(bytes.toBytes()), throwsA(isA<SaveCorrupt>()));
    });
  });

  group('escrita atômica e rodízio de 3 cópias', () {
    test('grava, lê e não deixa temporário', () async {
      expect(await store.read(), isNull);
      await store.write(n(1));
      expect(await store.read(), n(1));
      expect(store.loadNote, isNull);
      expect(File('${dir.path}/save.ksv.tmp').existsSync(), isFalse);
    });

    test('guarda as 3 últimas: a atual, a anterior e a anterior a essa', () async {
      for (var i = 1; i <= 5; i++) {
        await store.write(n(i));
      }
      expect(decodeKsv(copyBytes(store.current)), n(5));
      expect(decodeKsv(copyBytes(store.previous)), n(4));
      expect(decodeKsv(copyBytes(store.oldest)), n(3));
      expect(dir.listSync().length, 3, reason: 'nada além das 3 cópias');
    });

    test('um corte no meio da gravação (temporário pela metade) não estraga nada', () async {
      await store.write(n(1));
      await store.write(n(2));
      File('${dir.path}/save.ksv.tmp').writeAsBytesSync(encodeKsv(n(3)).sublist(0, 30));
      expect(await store.read(), n(2));
      await store.write(n(3));
      expect(await store.read(), n(3));
      expect(File('${dir.path}/save.ksv.tmp').existsSync(), isFalse);
    });
  });

  group('corrupção', () {
    test('a mais recente corrompida: carrega a anterior e avisa', () async {
      await store.write(n(1));
      await store.write(n(2));
      final bad = Uint8List.fromList(copyBytes(store.current))..[40] ^= 0xff;
      store.current.writeAsBytesSync(bad);
      expect(await store.read(), n(1));
      expect(store.loadNote, allOf(contains('corrompida'), contains('save.ksv.1')));
    });

    test('depois de carregar a anterior, a próxima gravação não perde a cópia boa', () async {
      await store.write(n(1));
      await store.write(n(2));
      store.current.writeAsBytesSync([1, 2, 3]);
      await store.read();
      await store.write(n(3));
      expect(decodeKsv(copyBytes(store.current)), n(3));
      expect(decodeKsv(copyBytes(store.previous)), n(1), reason: 'a boa continua, a corrompida foi posta de lado');
      expect(File('${dir.path}/save.ksv.bad').existsSync(), isTrue);
      expect(await store.read(), n(3));
      expect(store.loadNote, isNull);
    });

    test('atual e anterior corrompidas: cai para a mais velha', () async {
      for (var i = 1; i <= 3; i++) {
        await store.write(n(i));
      }
      store.current.writeAsBytesSync([0]);
      store.previous.writeAsBytesSync([0]);
      expect(await store.read(), n(1));
      expect(store.loadNote, contains('save.ksv.2'));
    });

    test('todas corrompidas: o jogo recomeça, avisa e os arquivos ficam', () async {
      await store.write(n(1));
      store.current.writeAsBytesSync([9, 9, 9]);
      expect(await store.read(), isNull);
      expect(store.loadNote, contains('corrompidas'));
      expect(store.current.existsSync(), isTrue);
    });
  });

  group('migração do save.json atual', () {
    final v1 = <String, dynamic>{
      'schema_version': 1,
      'group_code': 'AAAAA-BBBBB',
      'player_level': 4,
      'saved_utc': 77,
      'inventory': {'item.chalk': 3, 'item.seal.simple': 2},
      'collection': [
        {'uid': '42', 'species': 'rill.eco', 'level': 3, 'xp': 0, 'captured_utc': 50},
      ],
      'collected': {'42': 50},
    };

    test('lê o save.json, avisa, e a primeira gravação o vira KSV1 guardando o original', () async {
      File('${dir.path}/save.json').writeAsStringSync(jsonEncode(v1));
      expect(await store.read(), v1);
      expect(store.loadNote, contains('migrado'));
      await store.write(v1);
      expect(store.current.existsSync(), isTrue);
      expect(File('${dir.path}/save.json').existsSync(), isFalse);
      expect(File('${dir.path}/save.json.migrated').existsSync(), isTrue, reason: 'nada é apagado');
      expect(await store.read(), v1);
      expect(store.loadNote, isNull);
    });

    test('abrir o jogo por cima do save.json antigo não perde nada e grava em KSV1 no schema 2', () async {
      File('${dir.path}/save.json').writeAsStringSync(jsonEncode(v1));
      final session = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 100, nextInt: (n) => 0);
      await session.flush();
      final s = session.state;
      expect((s.groupCode, s.count('item.chalk'), s.count('item.seal.simple'), s.collection.single.speciesId, s.isDone(42)), ('AAAAA-BBBBB', 3, 2, 'rill.eco', true));
      expect(s.levelOverride, 4);
      final disk = decodeKsv(copyBytes(store.current));
      expect(disk['schema_version'], 3);
      expect(disk['group_code'], 'AAAAA-BBBBB');
      expect(File('${dir.path}/save.json.migrated').existsSync(), isTrue);
    });

    test('save.json ilegível vira .bad e o jogo recomeça', () async {
      File('${dir.path}/save.json').writeAsStringSync('{quebrado');
      expect(await store.read(), isNull);
      expect(File('${dir.path}/save.json.bad').readAsStringSync(), '{quebrado');
    });
  });
}

List<int> sha256Of(List<int> data) => sha256.convert(data).bytes;
