import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/save/founder.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fixtures.dart';

void main() {
  List<int> bytes(int n) => [for (var i = 0; i < n; i++) (i * 17 + 3) & 0xff];

  group('player_id', () {
    test('128 bits em 32 caracteres hexadecimais', () {
      final f = Founder.create(randomBytes: bytes, version: '0.12.0+18', utc: 100);
      expect(f.playerId, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(f.playerId, '03' '14' '25' '36' '47' '58' '69' '7a' '8b' '9c' 'ad' 'be' 'cf' 'e0' 'f1' '02');
    });

    test('o gerador seguro do sistema dá ids diferentes', () async {
      final a = await GameSession.open(store: MemorySaveStore(), startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1, nextInt: (n) => 0);
      final b = await GameSession.open(store: MemorySaveStore(), startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1, nextInt: (n) => 0);
      expect(a.state.founder!.playerId, isNot(b.state.founder!.playerId));
      expect(a.state.founder!.playerId, hasLength(32));
    });
  });

  group('versions_seen encadeado por hash', () {
    Founder fresh() => Founder.create(randomBytes: bytes, version: '0.11.0+17', utc: 100);

    test('a primeira abertura registra a versão, e reabrir a mesma não acrescenta linha', () {
      final f = fresh();
      expect((f.firstInstallVersion, f.firstSeenUtc, f.versionsSeen.length), ('0.11.0+17', 100, 1));
      expect(f.versionsSeen.single.prev, '');
      expect(f.noteVersion('0.11.0+17', 500), isFalse);
      expect(f.versionsSeen, hasLength(1));
    });

    test('uma linha por versão aberta, cada uma com o hash da anterior', () {
      final f = fresh();
      expect(f.noteVersion('0.12.0+18', 200), isTrue);
      expect(f.noteVersion('0.13.0+19', 300), isTrue);
      expect(f.versionsSeen.map((e) => e.version), ['0.11.0+17', '0.12.0+18', '0.13.0+19']);
      expect(f.versionsSeen[1].prev, f.versionsSeen[0].hash);
      expect(f.versionsSeen[2].prev, f.versionsSeen[1].hash);
      expect(f.chainValid, isTrue);
      expect(f.versionsSeen[0].hash, hasLength(64));
    });

    test('voltar a uma versão antiga também é uma linha nova', () {
      final f = fresh()..noteVersion('0.12.0+18', 200);
      expect(f.noteVersion('0.11.0+17', 300), isTrue);
      expect(f.versionsSeen, hasLength(3));
    });

    test('mudar, apagar ou reordenar uma linha quebra a cadeia', () {
      Founder tampered(void Function(List<VersionEntry>) edit) {
        final f = fresh()..noteVersion('0.12.0+18', 200)..noteVersion('0.13.0+19', 300);
        final list = [...f.versionsSeen];
        edit(list);
        return Founder(playerId: f.playerId, firstInstallVersion: f.firstInstallVersion, firstSeenUtc: f.firstSeenUtc, versionsSeen: list);
      }

      expect(tampered((l) => l[1] = VersionEntry(version: '9.9.9', utc: l[1].utc, prev: l[1].prev, hash: l[1].hash)).chainValid, isFalse);
      expect(tampered((l) => l[1] = VersionEntry(version: l[1].version, utc: 1, prev: l[1].prev, hash: l[1].hash)).chainValid, isFalse);
      expect(tampered((l) => l.removeAt(1)).chainValid, isFalse);
      expect(tampered((l) => l.removeAt(0)).chainValid, isFalse);
      expect(tampered((l) => l.insert(0, l.removeLast())).chainValid, isFalse);
    });

    test('um player_id trocado invalida o log inteiro', () {
      final f = fresh()..noteVersion('0.12.0+18', 200);
      final other = Founder(playerId: 'f' * 32, firstInstallVersion: f.firstInstallVersion, firstSeenUtc: f.firstSeenUtc, versionsSeen: f.versionsSeen);
      expect(other.chainValid, isFalse);
    });

    test('vai e volta no JSON sem perder nada', () {
      final f = fresh()..noteVersion('0.12.0+18', 200);
      final again = Founder.fromJson(f.toJson());
      expect(again.toJson(), f.toJson());
      expect(again.chainValid, isTrue);
    });
  });

  group('pelo save', () {
    test('o registro nasce na primeira abertura, sobrevive a reabrir e ganha uma linha a cada versão nova', () async {
      final store = MemorySaveStore();
      Future<GameSession> open(String version, int t) => GameSession.open(
            store: store,
            startInventory: {},
            balance: loadProgressBalance(),
            nowUtc: () => t,
            nextInt: (n) => 0,
            appVersion: version,
            randomBytes: bytes,
          );
      final a = await open('0.11.0+17', 1000);
      await a.flush();
      final id = a.state.founder!.playerId;
      final b = await open('0.11.0+17', 2000);
      await b.flush();
      expect(b.state.founder!.playerId, id);
      expect(b.state.founder!.versionsSeen, hasLength(1));
      final c = await open('0.12.0+18', 3000);
      await c.flush();
      expect(c.state.founder!.playerId, id);
      expect(c.state.founder!.versionsSeen.map((e) => e.version), ['0.11.0+17', '0.12.0+18']);
      expect(c.state.founder!.firstInstallVersion, '0.11.0+17');
      expect(c.state.founder!.firstSeenUtc, 1000);
      final disk = (store.json!['founder'] as Map<String, dynamic>);
      expect(Founder.fromJson(disk).chainValid, isTrue);
      expect(store.json!['app_version'], '0.12.0+18');
    });

    test('um save sem registro (de antes) ganha um ao abrir, sem perder o jogo', () async {
      final store = MemorySaveStore()
        ..json = {'schema_version': 2, 'group_code': 'AAAAA-BBBBB', 'inventory': {'item.chalk': 3}};
      final s = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 50, nextInt: (n) => 0, appVersion: '0.12.0+18');
      await s.flush();
      expect(s.state.count('item.chalk'), 3);
      expect(s.state.founder!.firstInstallVersion, '0.12.0+18');
    });
  });

  group('cabeçalho e relógio', () {
    test('o cabeçalho tem versão, época, criação e último instante visto', () async {
      final store = MemorySaveStore();
      final s = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1790040000, nextInt: (n) => 0, appVersion: '0.12.0+18', epochOf: (t) => 1);
      await s.flush();
      final j = store.json!;
      expect((j['schema_version'], j['app_version'], j['epoch'], j['created_utc'], j['last_seen_utc']), (5, '0.12.0+18', 1, 1790040000, 1790040000));
    });

    test('o override do debug não empurra o last_seen_utc: ele segue o relógio real', () async {
      final store = MemorySaveStore();
      var game = 1790040000, real = 1790040000;
      final s = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => game, seenUtc: () => real, nextInt: (n) => 0);
      game = 1900000000; // o debug pôs o relógio do jogo no futuro
      real += 60;
      s.state.add('item.chalk', 1);
      await s.flush();
      expect(store.json!['last_seen_utc'], 1790040060);
    });
  });
}
