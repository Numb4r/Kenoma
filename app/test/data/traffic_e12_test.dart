import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/data/region_loader.dart';
import 'package:kenoma/data/traffic_pack.dart';

import '../support/fixtures.dart';

class _Bundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final f = File(key);
    if (!f.existsSync()) throw StateError('sem $key');
    return ByteData.sublistView(f.readAsBytesSync());
  }
}

/// A época 12: o pacote de São Paulo com Iluminado e Sagrado e os arquivos de pontos do OSM com os becos (tipo 11).
void main() {
  final epochs = loadEpochs().epochs;
  final e11 = epochs.firstWhere((e) => e.id == 11), e12 = epochs.firstWhere((e) => e.id == 12);
  // A área da região embutida, em células z21 (os pontos do arquivo caem dentro dela).
  final grid = loadCampinasPack();
  List<TrafficPoint> all(TrafficPack p) => p.pointsIn(grid.x0.toDouble(), grid.y0.toDouble(), (grid.x0 + grid.width).toDouble(), (grid.y0 + grid.height).toDouble());
  TrafficPack read(String name) => TrafficPack.parse(Uint8List.fromList(File('assets/regions/$name').readAsBytesSync()));

  test('a época 12 é a 11 com o pacote novo de São Paulo e os pontos das duas regiões', () {
    expect(e12.startsUtc, greaterThan(e11.startsUtc));
    expect(e12.regionPacks['sao_paulo']!.file, 'sao_paulo_e12.bin');
    expect(e12.regionPacks['campinas']!.sha256, e11.regionPacks['campinas']!.sha256, reason: 'Campinas não muda');
    expect(e12.visualPacks.map((k, v) => MapEntry(k, v.sha256)), e11.visualPacks.map((k, v) => MapEntry(k, v.sha256)));
    expect(e12.trafficPacks.keys, {'campinas', 'sao_paulo'});
    expect(e11.trafficPacks, isEmpty, reason: 'a época 11 continua como foi publicada');
    expect(sha256Hex(File('assets/regions/campinas_e12_traffic.bin').readAsBytesSync()), e12.trafficPacks['campinas']!.sha256);
  });

  test('o arquivo da época 12 de Campinas tem os mesmos pontos de antes e os becos a mais', () {
    final e0 = read('campinas_e0_traffic.bin'), e12 = read('campinas_e12_traffic.bin');
    final all0 = all(e0), all12 = all(e12);
    String key(TrafficPoint p) => '${p.kind.index}|${p.x}|${p.y}';
    expect({for (final p in all12) if (p.kind != TrafficPointKind.alley) key(p)}, {for (final p in all0) key(p)});
    expect(all12.where((p) => p.kind == TrafficPointKind.alley).length, greaterThan(1000));
    expect(all0.where((p) => p.kind == TrafficPointKind.alley), isEmpty);
  });

  test('a época escolhe o arquivo de pontos: antes da 12 o da época 0, na 12 o com becos; SHA errado não entra', () async {
    final bundle = _Bundle();
    final before = (await loadTrafficPack(region: 'campinas', epoch: e11, bundle: bundle))!;
    final after = (await loadTrafficPack(region: 'campinas', epoch: e12, bundle: bundle))!;
    bool alleys(TrafficPack p) => all(p).any((x) => x.kind == TrafficPointKind.alley);
    expect((alleys(before), alleys(after)), (false, true));
    expect(await loadTrafficPack(region: 'sao_paulo', epoch: e12, bundle: bundle), isNull, reason: 'o de São Paulo é baixado, não embutido');
  });
}
