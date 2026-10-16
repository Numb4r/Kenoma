import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/net/signed_epochs.dart';
import 'package:kenoma/net/signed_feed.dart';

const _fx = 'test/net/fixtures';
final _pub = File('$_fx/test_pub.hex').readAsStringSync().trim();
const _rfcPub = 'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a'; // outra chave

class _Assets extends CachingAssetBundle {
  _Assets({this.packs = true});
  final bool packs;
  @override
  Future<ByteData> load(String key) async {
    if (key == 'assets/data/epochs.json') {
      return ByteData.sublistView(Uint8List.fromList(File('assets/data/epochs.json').readAsBytesSync()));
    }
    if (packs) return ByteData(1);
    throw Exception('sem $key');
  }
}

Map<String, dynamic> _json(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Directory _cache({bool epochs = true, bool events = true, void Function(Directory)? tamper}) {
  final d = Directory.systemTemp.createTempSync('feed');
  for (final (ok, n) in [(epochs, 'epochs'), (events, 'events')]) {
    if (!ok) continue;
    File('$_fx/${n}_feed.json').copySync('${d.path}/$n.json');
    File('$_fx/${n}_feed.json.sig').copySync('${d.path}/$n.json.sig');
  }
  tamper?.call(d);
  return d;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bundled = _json('assets/data/epochs.json');

  test('os arquivos reais de docs/pages conferem com a chave embutida (openssl -> Dart)', () {
    for (final n in ['epochs.json', 'events.json']) {
      final data = File('../docs/pages/$n').readAsBytesSync();
      expect(verifySigned(data, File('../docs/pages/$n.sig').readAsStringSync()), isTrue, reason: n);
      expect(verifySigned([...data, 32], File('../docs/pages/$n.sig').readAsStringSync()), isFalse);
    }
  });

  group('mergeSigned', () {
    final feed = _json('$_fx/epochs_feed.json');

    test('acrescenta época nova e estende valid_until_utc', () {
      final merged = mergeSigned(EpochSchedule.fromJson(bundled), feed);
      expect(merged.epochs.map((e) => e.id), contains(4));
      final e3 = EpochSchedule.fromJson(feed).epochs.firstWhere((e) => e.id == 3);
      expect(merged.epochs.firstWhere((e) => e.id == 3).validUntilUtc, e3.validUntilUtc);
      expect(merged.epochs.firstWhere((e) => e.id == 3).validUntilUtc, greaterThan(EpochSchedule.fromJson(bundled).epochs.firstWhere((e) => e.id == 3).validUntilUtc));
    });

    test('rejeita alterar o conteúdo de época publicada', () {
      final bad = jsonDecode(jsonEncode(feed)) as Map<String, dynamic>;
      ((bad['epochs'] as List)[0] as Map)['starts_utc'] = '2026-01-01T00:00:00Z';
      expect(() => mergeSigned(EpochSchedule.fromJson(bundled), bad), throwsFormatException);
      final bad2 = jsonDecode(jsonEncode(feed)) as Map<String, dynamic>;
      (((bad2['epochs'] as List)[2] as Map)['spawn'] as Map)['items'] = [];
      expect(() => mergeSigned(EpochSchedule.fromJson(bundled), bad2), throwsFormatException);
    });

    test('rejeita encurtar a época e id novo que não é maior que o maior embutido', () {
      final short = jsonDecode(jsonEncode(feed)) as Map<String, dynamic>;
      ((short['epochs'] as List)[3] as Map)['valid_until_utc'] = '2027-01-14T18:19:00Z';
      expect(() => mergeSigned(EpochSchedule.fromJson(bundled), short), throwsFormatException);
      expect(() => mergeSignedJson({'epochs': [(bundled['epochs'] as List)[0], (bundled['epochs'] as List)[3]]}, {'epochs': [(bundled['epochs'] as List)[2]]}), throwsFormatException);
    });

    test('ignora época nova cujo pacote não existe no app', () {
      final merged = mergeSigned(EpochSchedule.fromJson(bundled), feed, hasPack: (_) => false);
      expect(merged.epochs.map((e) => e.id), isNot(contains(4)));
      expect(merged.epochs.map((e) => e.id), contains(3));
    });
  });

  group('cache assinado', () {
    test('assinatura válida: funde no carregamento', () async {
      final json = await loadEpochsJson(bundle: _Assets(), dir: _cache(), publicKeyHex: _pub);
      expect((json['epochs'] as List).length, 5);
    });

    test('chave errada, arquivo adulterado, .sig ausente ou ruim: volta ao embutido', () async {
      Future<int> n(Directory d, {String key = ''}) async =>
          ((await loadEpochsJson(bundle: _Assets(), dir: d, publicKeyHex: key.isEmpty ? _pub : key))['epochs'] as List).length;
      expect(await n(_cache(), key: _rfcPub), 4);
      expect(await n(_cache(tamper: (d) => File('${d.path}/epochs.json').writeAsStringSync(File('${d.path}/epochs.json').readAsStringSync().replaceFirst('2027-06-01', '2027-07-01')))), 4);
      expect(await n(_cache(tamper: (d) => File('${d.path}/epochs.json.sig').deleteSync())), 4);
      expect(await n(_cache(tamper: (d) => File('${d.path}/epochs.json.sig').writeAsStringSync('zz'))), 4);
      expect(await n(_cache(tamper: (d) => File('${d.path}/epochs.json').writeAsStringSync('{'))), 4);
    });

    test('pacote ausente nos assets: época nova ignorada', () async {
      final json = await loadEpochsJson(bundle: _Assets(packs: false), dir: _cache(), publicKeyHex: _pub);
      expect((json['epochs'] as List).length, 4);
    });

    test('loadSignedEvents: lista com assinatura boa, vazia sem cache, com adulteração ou chave errada', () async {
      expect((await loadSignedEvents(dir: _cache(), publicKeyHex: _pub)).single['id'], 'ev.test');
      expect(await loadSignedEvents(dir: _cache(events: false), publicKeyHex: _pub), isEmpty);
      expect(await loadSignedEvents(dir: _cache(), publicKeyHex: _rfcPub), isEmpty);
      expect(await loadSignedEvents(dir: _cache(tamper: (d) => File('${d.path}/events.json').writeAsStringSync('{"events":[]}')), publicKeyHex: _pub), isEmpty);
    });
  });

  group('refreshSignedFeed', () {
    Future<Uint8List?> served(Uri u) async => Uint8List.fromList(File('$_fx/${u.pathSegments.last.replaceFirst('.json', '_feed.json')}').readAsBytesSync());
    final t0 = DateTime.utc(2026, 10, 16, 12).millisecondsSinceEpoch ~/ 1000;

    test('aceita arquivos assinados, grava cache e só tenta uma vez por dia', () async {
      final d = Directory.systemTemp.createTempSync('feed');
      var calls = 0;
      Future<Uint8List?> fetch(Uri u) {
        calls++;
        return served(u);
      }

      expect(await refreshSignedFeed(nowUtc: t0, dir: d, fetch: fetch, bundle: _Assets(), publicKeyHex: _pub), 2);
      final calls1 = calls;
      expect(await refreshSignedFeed(nowUtc: t0 + 3600, dir: d, fetch: fetch, bundle: _Assets(), publicKeyHex: _pub), 0);
      expect(calls, calls1);
      expect(await refreshSignedFeed(nowUtc: t0 + 86400, dir: d, fetch: fetch, bundle: _Assets(), publicKeyHex: _pub), 2);
      expect((await loadSignedEvents(dir: d, publicKeyHex: _pub)), hasLength(1));
    });

    test('rede fora, assinatura ruim ou chave errada: nada entra e nada lança', () async {
      for (final fetch in <FeedFetch>[(u) async => null, (u) async => throw const SocketException('x'), served]) {
        final d = Directory.systemTemp.createTempSync('feed');
        final key = identical(fetch, served) ? _rfcPub : _pub;
        expect(await refreshSignedFeed(nowUtc: t0, dir: d, fetch: fetch, bundle: _Assets(), publicKeyHex: key), 0);
        expect(File('${d.path}/epochs.json').existsSync(), isFalse);
      }
    });
  });
}
