import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/building_pack.dart';
import 'package:kenoma/world/city_scene.dart';

/// O arquivo de prédios de Campinas (`pipeline/build_buildings.py`, `BLD2` por tile z15 desde a 0.22.2), só cenário do
/// estilo Completo: o índice na memória, os tiles sob demanda, o teto de memória.
void main() {
  final bytes = File('assets/regions/campinas_e0_bldg.bin').readAsBytesSync();
  BuildingPack open({int maxBytes = 1 << 40}) => BuildingPack.fromBytes(bytes, decodeInBackground: false, maxBytes: maxBytes);
  final (cx, cy) = latLonToTileFraction(-22.9041, -47.0687, biomeZoom); // a Praça Ramos de Azevedo

  test('o índice tem os 676 tiles; carregados todos, estão os 32.116 prédios e as 1.760 árvores do extrato da época 0', () async {
    final pack = open();
    expect(pack.tileCount, 676);
    expect(pack.loadedTiles, 0, reason: 'nada carrega antes de pedir');
    await pack.loadAll();
    expect(pack.buildingsIn(0, 0, 1e7, 1e7, margin: 0).length, 32116);
    expect(pack.treesIn(0, 0, 1e7, 1e7).length, 1760);
  });

  test('o tile só aparece depois de carregar; até lá o pedaço fica sem prédio, e a revisão sobe quando ele chega', () async {
    final pack = open();
    expect(pack.readyAt(cx, cy), isFalse);
    expect(pack.buildingsIn(cx - 4, cy - 4, cx + 4, cy + 4), isEmpty, reason: 'pedido: começa a carregar');
    expect(pack.loadingTiles + pack.loadedTiles, greaterThan(0));
    final rev = pack.buildingRevision;
    await Future<void>.delayed(Duration.zero);
    await pack.load(cx.floor() >>> 6, cy.floor() >>> 6);
    expect(pack.readyAt(cx, cy), isTrue);
    expect(pack.buildingRevision, greaterThan(rev));
    expect(pack.buildingsIn(cx - 4, cy - 4, cx + 4, cy + 4), isNotEmpty);
  });

  test('o teto de memória descarta os tiles usados há mais tempo e guarda o mais recente', () async {
    final pack = open(maxBytes: 300 * 1024);
    final keys = <(int, int)>[];
    final tx = cx.floor() >>> 6, ty = cy.floor() >>> 6;
    for (var dy = -6; dy <= 6; dy++) {
      for (var dx = -6; dx <= 6; dx++) {
        keys.add((tx + dx, ty + dy));
      }
    }
    for (final (x, y) in keys) {
      await pack.load(x, y);
    }
    expect(pack.loadedBytes, lessThanOrEqualTo(300 * 1024));
    expect(pack.loadedTiles, lessThan(keys.length));
    expect(pack.readyAt((keys.last.$1 << 6) + 1.0, (keys.last.$2 << 6) + 1.0), isTrue, reason: 'o último carregado fica');
  });

  test('a cena do tile sai sem prédio enquanto o tile de prédios carrega, e com eles depois', () async {
    final pack = open();
    final tx = cx.floor() >>> 6, ty = cy.floor() >>> 6;
    CityTile scene() => buildCityTile(tx: tx, ty: ty, visual: null, cellsPerTile: 64, extent: 4096, mpc: 17.6, biomeAt: (_, _) => 'urban', buildings: pack);
    expect(scene().buildings, isEmpty);
    await pack.load(tx, ty);
    expect(scene().buildings, isNotEmpty);
  });

  test('magic errado é recusado, e tile maior que o limite também', () {
    expect(() => BuildingPack.fromBytes(File('assets/regions/campinas_e0_cycle.bin').readAsBytesSync()), throwsFormatException);
    final bad = Uint8List.fromList(bytes);
    // O primeiro tile do índice com 1 MB de tamanho declarado.
    final first = BuildingPack.headerLength(bad) - 20 * 676;
    ByteData.sublistView(bad).setUint32(first + 12, 1024 * 1024, Endian.little);
    expect(() => BuildingPack.fromBytes(bad), throwsFormatException);
  });
}
