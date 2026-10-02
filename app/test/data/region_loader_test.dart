import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/data/region_loader.dart';

import '../support/fixtures.dart';

/// Assets em memória: devolve o que o teste pôs, e falha como o app falharia no que faltar.
class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);

  final Map<String, List<int>> files;

  @override
  Future<ByteData> load(String key) async {
    final data = files[key];
    if (data == null) throw FlutterError('Unable to load asset: "$key".');
    return ByteData.sublistView(Uint8List.fromList(data));
  }
}

void main() {
  final bytes = Uint8List.fromList(File('assets/regions/campinas_e0.bin').readAsBytesSync());
  final epoch = loadEpochs().epochs.first;
  final expectedSha = epoch.regionPacks['campinas']!.sha256;

  group('verifyRegionPack', () {
    test('o .bin do repositório bate com o SHA-256 da época 0 e é lido', () {
      expect(sha256Hex(bytes), expectedSha);
      final r = verifyRegionPack(bytes: bytes, epoch: epoch, region: 'campinas');
      expect(r, isA<RegionLoaded>());
      final ok = r as RegionLoaded;
      expect(ok.pack.zoom, 21);
      expect((ok.pack.width, ok.pack.height), (2331, 2404));
      expect(ok.epoch.id, 0);
      expect(ok.sha256, expectedSha);
      expect(ok.stale, isFalse);
    });

    test('um byte diferente no meio do arquivo não bate: erro claro com os dois hashes, sem lançar', () {
      final tampered = Uint8List.fromList(bytes)..[1000] ^= 0xff;
      final r = verifyRegionPack(bytes: tampered, epoch: epoch, region: 'campinas');
      expect(r, isA<RegionLoadError>());
      final err = r as RegionLoadError;
      expect(err.kind, RegionLoadErrorKind.shaMismatch);
      expect(err.message, contains('campinas_e0.bin'));
      expect(err.message, contains('época 0'));
      expect(err.message, contains(expectedSha.substring(0, 12)));
      expect(err.message, contains(sha256Hex(tampered).substring(0, 12)));
    });

    test('arquivo truncado e arquivo vazio também não batem', () {
      for (final broken in [bytes.sublist(0, bytes.length - 1), bytes.sublist(0, 23), Uint8List(0)]) {
        final r = verifyRegionPack(bytes: broken, epoch: epoch, region: 'campinas');
        expect((r as RegionLoadError).kind, RegionLoadErrorKind.shaMismatch);
      }
    });

    test('o SHA-256 da época em maiúsculas também vale', () {
      final upper = _epochWithSha(expectedSha.toUpperCase());
      expect(verifyRegionPack(bytes: bytes, epoch: upper, region: 'campinas'), isA<RegionLoaded>());
    });

    test('um pacote que bate o SHA mas não é VEU1 vira erro de formato, não exceção', () {
      final fake = Uint8List.fromList(List.filled(100, 7));
      final e = _epochWithSha(sha256Hex(fake));
      final r = verifyRegionPack(bytes: fake, epoch: e, region: 'campinas') as RegionLoadError;
      expect(r.kind, RegionLoadErrorKind.badFormat);
      expect(r.message, contains('corrompido'));
    });

    test('região que a época não lista: erro claro', () {
      final r = verifyRegionPack(bytes: bytes, epoch: epoch, region: 'sao_paulo') as RegionLoadError;
      expect(r.kind, RegionLoadErrorKind.noPackForRegion);
      expect(r.message, contains('sao_paulo'));
    });

    test('o relógio fora das épocas marca o mundo como desatualizado, sem erro', () {
      final r = verifyRegionPack(bytes: bytes, epoch: epoch, region: 'campinas', stale: true) as RegionLoaded;
      expect(r.stale, isTrue);
    });
  });

  group('loadRegion', () {
    final epochsText = File('assets/data/epochs.json').readAsStringSync();
    // 2026-10-02: dentro da época 0.
    final inEpoch = epoch.startsUtc + 10 * 86400;

    test('com os assets certos carrega e valida', () async {
      final bundle = _Bundle({'assets/data/epochs.json': utf8.encode(epochsText), 'assets/regions/campinas_e0.bin': bytes});
      final r = await loadRegion(region: 'campinas', nowUtc: inEpoch, bundle: bundle);
      expect(r, isA<RegionLoaded>());
      expect((r as RegionLoaded).stale, isFalse);
    });

    test('com o relógio depois do fim da época carrega e avisa que está desatualizado', () async {
      final bundle = _Bundle({'assets/data/epochs.json': utf8.encode(epochsText), 'assets/regions/campinas_e0.bin': bytes});
      final r = await loadRegion(region: 'campinas', nowUtc: epoch.validUntilUtc + 1, bundle: bundle);
      expect((r as RegionLoaded).stale, isTrue);
    });

    test('pacote adulterado nos assets: erro claro e o app segue vivo', () async {
      final bad = Uint8List.fromList(bytes)..[500] ^= 1;
      final bundle = _Bundle({'assets/data/epochs.json': utf8.encode(epochsText), 'assets/regions/campinas_e0.bin': bad});
      final r = await loadRegion(region: 'campinas', nowUtc: inEpoch, bundle: bundle);
      expect((r as RegionLoadError).kind, RegionLoadErrorKind.shaMismatch);
    });

    test('arquivo do pacote ausente e epochs.json ilegível viram erros, não exceções', () async {
      final noBin = _Bundle({'assets/data/epochs.json': utf8.encode(epochsText)});
      expect(((await loadRegion(region: 'campinas', nowUtc: inEpoch, bundle: noBin)) as RegionLoadError).kind, RegionLoadErrorKind.missingFile);
      final noEpochs = _Bundle({});
      expect(((await loadRegion(region: 'campinas', nowUtc: inEpoch, bundle: noEpochs)) as RegionLoadError).kind, RegionLoadErrorKind.epochs);
      final garbage = _Bundle({'assets/data/epochs.json': utf8.encode('{não é json')});
      expect(((await loadRegion(region: 'campinas', nowUtc: inEpoch, bundle: garbage)) as RegionLoadError).kind, RegionLoadErrorKind.epochs);
    });

    test('os assets reais do app (rootBundle) carregam e batem', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final r = await loadRegion(region: 'campinas', nowUtc: inEpoch);
      expect(r, isA<RegionLoaded>(), reason: r is RegionLoadError ? r.message : '');
    });
  });
}

Epoch _epochWithSha(String sha) {
  final json = epochsJson();
  final e = (json['epochs'] as List<dynamic>).first as Map<String, dynamic>;
  ((e['region_packs'] as Map<String, dynamic>)['campinas'] as Map<String, dynamic>)['sha256'] = sha;
  return Epoch.fromJson(e);
}
