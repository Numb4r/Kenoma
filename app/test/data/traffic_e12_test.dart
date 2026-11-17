import 'dart:convert';
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

/// A época 12: o pacote de São Paulo com Iluminado e Sagrado, os arquivos de pontos do OSM com os becos (tipo 11) e, desde a
/// 0.23.0, o Overture (release 2026-10-21.0) nos pacotes de Campinas: biomas, POIs e becos.
void main() {
  final epochs = loadEpochs().epochs;
  final e11 = epochs.firstWhere((e) => e.id == 11), e12 = epochs.firstWhere((e) => e.id == 12);
  // A área da região embutida, em células z21 (os pontos do arquivo caem dentro dela).
  final grid = loadCampinasPack();
  List<TrafficPoint> all(TrafficPack p) => p.pointsIn(grid.x0.toDouble(), grid.y0.toDouble(), (grid.x0 + grid.width).toDouble(), (grid.y0 + grid.height).toDouble());
  TrafficPack read(String name) => TrafficPack.parse(Uint8List.fromList(File('assets/regions/$name').readAsBytesSync()));

  test('a época 12 é a 11 com o pacote novo de São Paulo e os pontos das duas regiões', () {
    expect(e12.startsUtc, greaterThan(e11.startsUtc));
    expect(e12.regionPacks['sao_paulo']!.file, 'sao_paulo_e12_ov.bin');
    expect(e12.regionPacks['campinas']!.file, 'campinas_e12_ov.bin', reason: 'Campinas com o Overture');
    expect(sha256Hex(File('assets/regions/campinas_e12_ov.bin').readAsBytesSync()), e12.regionPacks['campinas']!.sha256);
    expect(e11.regionPacks['campinas']!.file, 'campinas_e11.bin', reason: 'a época 11 continua como foi publicada');
    expect(e12.visualPacks.map((k, v) => MapEntry(k, v.sha256)), e11.visualPacks.map((k, v) => MapEntry(k, v.sha256)));
    expect(e12.trafficPacks.keys, {'campinas', 'sao_paulo'});
    expect(e11.trafficPacks, isEmpty, reason: 'a época 11 continua como foi publicada');
    expect(sha256Hex(File('assets/regions/campinas_e12_ov_traffic.bin').readAsBytesSync()), e12.trafficPacks['campinas']!.sha256);
  });

  test('a época 12 registra a release do Overture', () {
    final raw = jsonDecode(File('assets/data/epochs.json').readAsStringSync()) as Map<String, dynamic>;
    final eps = {for (final e in raw['epochs'] as List<dynamic>) (e as Map<String, dynamic>)['id']: e};
    expect(eps[12]!['overture_release'], '2026-10-21.0');
    expect(eps[11]!.containsKey('overture_release'), isFalse);
  });

  test('o arquivo da época 12 de Campinas: os pontos de rua iguais, os POIs do OSM todos lá, mais os do Overture e mais becos', () {
    final e0 = read('campinas_e0_traffic.bin'), e12 = read('campinas_e12_ov_traffic.bin');
    final all0 = all(e0), all12 = all(e12);
    String key(TrafficPoint p) => '${p.kind.index}|${p.x}|${p.y}';
    const street = {TrafficPointKind.signal, TrafficPointKind.stop, TrafficPointKind.giveWay, TrafficPointKind.crossing, TrafficPointKind.entry, TrafficPointKind.busStop};
    Set<String> of(List<TrafficPoint> ps, bool Function(TrafficPointKind) f) => {for (final p in ps) if (f(p.kind)) key(p)};
    expect(of(all12, street.contains), of(all0, street.contains), reason: 'o Overture não traz semáforo nem ponto de ônibus');
    final pois12 = of(all12, (k) => !street.contains(k) && k != TrafficPointKind.alley);
    expect(pois12.containsAll(of(all0, (k) => !street.contains(k))), isTrue, reason: 'o OSM tem prioridade: nenhum POI dele sai');
    int n(List<TrafficPoint> ps, TrafficPointKind k) => ps.where((p) => p.kind == k).length;
    expect(n(all12, TrafficPointKind.shop), greaterThan(3 * n(all0, TrafficPointKind.shop)));
    expect(n(all12, TrafficPointKind.bar), greaterThan(3 * n(all0, TrafficPointKind.bar)));
    expect(n(all12, TrafficPointKind.alley), greaterThan(4000), reason: 'os prédios do Overture fecham mais caminhos entre construções');
    expect(n(all0, TrafficPointKind.alley), 0);
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
