import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/region_loader.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/visual_map.dart';

import '../support/fixtures.dart';

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
  final (ux15, uy15) = latLonToTile(-22.8174, -47.0697, 15);
  final bytes = Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync());
  final epoch = loadEpochs().epochs.first;
  final ref = epoch.visualPacks['campinas']!;

  test('o pacote visual fica em campo separado do pacote lógico na época 0, e o SHA-256 bate', () {
    expect(ref.file, 'campinas_e0_vis.bin');
    expect(sha256Hex(bytes), ref.sha256);
    expect(ref.sha256, isNot(epoch.regionPacks['campinas']!.sha256));
    expect(epoch.regionPacks['campinas']!.file, 'campinas_e0.bin', reason: 'o pacote lógico não mudou');
  });

  test('o pacote real é a versão 2: ruas principais com nome, mão única, e nome só nas principais e secundárias', () {
    final pack = VisualPack.parse(bytes);
    expect(pack.version, 2);
    var named = 0, oneway = 0, namedLocal = 0;
    for (final (x, y) in [for (var dx = -3; dx <= 3; dx++) for (var dy = -3; dy <= 3; dy++) (ux15 + dx, uy15 + dy)]) {
      final t = pack.decode(x, y);
      if (t == null) continue;
      for (final l in t.lines) {
        if (l.name != null) {
          named++;
          if (l.roadClass != RoadClass.principal && l.roadClass != RoadClass.secondary) namedLocal++;
        }
        if (l.oneway != OneWay.twoWay) oneway++;
      }
    }
    expect(named, greaterThan(50));
    expect(oneway, greaterThan(50));
    expect(namedLocal, 0, reason: 'só as principais e secundárias levam o nome');
  });

  test('o arquivo tem o cabeçalho VIS1 e um tamanho pequeno', () {
    final pack = VisualPack.parse(bytes);
    expect((pack.tileZoom, pack.extent), (15, 4096));
    expect(pack.tileCount, greaterThan(1000));
    expect(bytes.length, lessThan(5 << 20), reason: 'compacto: poucos MB para a região inteira');
  });

  test('o tile da Unicamp tem ruas de várias classes e o do Taquaral tem água e verde', () {
    final map = VisualMap(VisualPack.parse(bytes));
    (int, int) tileAt(double lat, double lon) => latLonToTile(lat, lon, 15);

    final (ux, uy) = tileAt(-22.8174, -47.0697);
    final unicamp = map.tile(ux, uy)!;
    expect(unicamp.lines.length, greaterThan(50));
    expect({for (final l in unicamp.lines) l.roadClass}.length, greaterThanOrEqualTo(2));

    final (tx, ty) = tileAt(-22.8660, -47.0535);
    final taquaral = map.tile(tx, ty)!;
    expect({for (final a in taquaral.areas) a.kind}, containsAll([AreaKind.water, AreaKind.green]));
  });

  test('toda coordenada decodificada cai perto do tile: ruas até ~10 m da borda, áreas com anéis fechados de 3 pontos ou mais', () {
    final map = VisualMap(VisualPack.parse(bytes), cacheTiles: 8);
    final (x, y) = latLonToTile(-22.9056, -47.0608, 15);
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final t = map.tile(x + dx, y + dy);
        if (t == null) continue;
        for (final l in t.lines) {
          expect(l.xy.length, greaterThanOrEqualTo(4));
          for (var i = 0; i < l.xy.length; i++) {
            expect(l.xy[i], inInclusiveRange(-100, 4196), reason: 'linha dentro do tile mais a folga');
          }
        }
        for (final a in t.areas) {
          for (final ring in a.rings) {
            expect(ring.length, greaterThanOrEqualTo(6));
          }
        }
      }
    }
  });

  group('loadVisualPack', () {
    test('com o arquivo certo devolve o pacote', () async {
      final r = await loadVisualPack(region: 'campinas', epoch: epoch, bundle: _Bundle({'assets/regions/campinas_e0_vis.bin': bytes}));
      expect(r, isA<VisualPack>());
    });

    test('arquivo adulterado: mensagem com os hashes, sem lançar', () async {
      final bad = Uint8List.fromList(bytes)..[5000] ^= 0xff;
      final r = await loadVisualPack(region: 'campinas', epoch: epoch, bundle: _Bundle({'assets/regions/campinas_e0_vis.bin': bad}));
      expect(r, isA<String>());
      expect(r as String, allOf(contains('SHA-256 esperado'), contains(ref.sha256.substring(0, 12))));
    });

    test('arquivo ausente: mensagem clara', () async {
      final r = await loadVisualPack(region: 'campinas', epoch: epoch, bundle: _Bundle({}));
      expect(r, isA<String>());
      expect(r as String, contains('campinas_e0_vis.bin não está no app'));
    });

    test('região sem pacote visual: mensagem clara', () async {
      final r = await loadVisualPack(region: 'outra', epoch: epoch, bundle: _Bundle({}));
      expect(r as String, contains('não tem pacote visual'));
    });
  });
}
