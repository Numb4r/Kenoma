import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/map/map_assets.dart';

import '../support/fixtures.dart';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(Uint8List.fromList(await File(key).readAsBytes()));
}

/// 0.25.2 (modo de desenvolvimento): São Paulo vem no APK, como Campinas, enquanto não houver publicação.
void main() {
  final epoch = loadShippedEpochs().epochs.single;

  test('São Paulo sai dos assets, confere com a época e vem com tudo que a região baixada tinha', () async {
    final r = await loadEmbeddedRegion(region: 'sao_paulo', epoch: epoch, bundle: _DiskBundle());
    expect(r, isNotNull, reason: 'pacote lógico e visual no APK, com o SHA da época');
    expect(r!.id, 'sao_paulo');
    expect(r.noWalk, isNotNull, reason: 'as vias onde não se anda');
    expect(r.relief, isNotNull);
    expect(r.access, isNotNull, reason: 'a rota (sao_paulo_e5_noaccess.bin)');
    expect(r.traffic, isNotNull, reason: 'os pontos do OSM da época');
    expect(r.buildings, isNotNull, reason: 'os prédios do Completo');
  });

  test('toda região da época está no APK (nada a baixar até a distribuição)', () {
    for (final ref in [...epoch.regionPacks.values, ...epoch.visualPacks.values, ...epoch.reliefPacks.values, ...epoch.trafficPacks.values]) {
      expect(File('assets/regions/${ref.file}').existsSync(), isTrue, reason: ref.file);
    }
  });

  test('sem o pacote nos assets, a região fica para o catálogo (sem erro)', () async {
    expect(await loadEmbeddedRegion(region: 'rio', epoch: epoch, bundle: _DiskBundle()), isNull);
  });
}
