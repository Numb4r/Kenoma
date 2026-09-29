import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/region_pack.dart';

import '../support/fixtures.dart';

// ids de shared/biomes.json
const void_ = 0, urban = 1, green = 2, water = 3, residential = 4;

void main() {
  final pack = loadCampinasPack();
  final biomes = loadBiomes();

  test('cabeçalho do pacote de Campinas', () {
    expect(pack.zoom, 21);
    expect((pack.x0, pack.y0), (773324, 1184541));
    expect((pack.width, pack.height), (2331, 2404));
  });

  test('a célula do vetor fica dentro do pacote', () {
    final (x, y) = latLonToTile(vectorLat, vectorLon, biomeZoom);
    expect(x, inInclusiveRange(pack.x0, pack.x0 + pack.width - 1));
    expect(y, inInclusiveRange(pack.y0, pack.y0 + pack.height - 1));
  });

  test('fora do pacote vale Vazio', () {
    expect(pack.biomeAt(0, 0), void_);
    expect(pack.biomeAt(pack.x0 - 1, pack.y0), void_);
    expect(pack.biomeAt(pack.x0, pack.y0 - 1), void_);
    expect(pack.biomeAt(pack.x0 + pack.width, pack.y0), void_);
    expect(pack.biomeAt(pack.x0, pack.y0 + pack.height), void_);
  });

  test('só aparecem ids de bioma conhecidos', () {
    final seen = <int>{};
    for (var y = pack.y0; y < pack.y0 + pack.height; y += 7) {
      for (var x = pack.x0; x < pack.x0 + pack.width; x += 7) {
        seen.add(pack.biomeAt(x, y));
      }
    }
    expect(seen, {void_, urban, green, water, residential});
  });

  test('rejeita pacote com magic errado, versão desconhecida ou tamanho incoerente', () {
    final good = Uint8List(23)
      ..setRange(0, 4, 'VEU1'.codeUnits)
      ..[4] = 1;
    expect(() => RegionPack.parse(Uint8List(10)), throwsFormatException);
    expect(() => RegionPack.parse(Uint8List.fromList(good)..[0] = 0x58), throwsFormatException);
    expect(() => RegionPack.parse(Uint8List.fromList(good)..[4] = 2), throwsFormatException);
  });

  // Células z20 reais de Campinas com empate 2 contra 2 entre dois biomas, achadas no pacote
  // (uma para cada par). Vence a maior prioridade: Água 4 > Verde 3 > Urbano 2 > Residencial 1 > Vazio 0.
  group('empate 2 contra 2 em células reais do pacote', () {
    final cases = <(String, int, int, List<int>, int)>[
      ('Vazio x Urbano', 386828, 592271, [urban, void_, urban, void_], urban),
      ('Vazio x Verde', 386712, 592271, [green, void_, green, void_], green),
      ('Vazio x Água', 387415, 592271, [void_, water, void_, water], water),
      ('Vazio x Residencial', 387228, 592271, [void_, void_, residential, residential], residential),
      ('Urbano x Verde', 386983, 592271, [urban, green, urban, green], green),
      ('Urbano x Água', 387698, 592292, [urban, water, water, urban], water),
      ('Urbano x Residencial', 386871, 592272, [urban, urban, residential, residential], urban),
      ('Verde x Água', 387542, 592271, [green, green, water, water], water),
      ('Verde x Residencial', 386885, 592271, [green, green, residential, residential], green),
      ('Água x Residencial', 386882, 592305, [residential, residential, water, water], water),
    ];
    for (final (name, cx, cy, quad, winner) in cases) {
      test(name, () {
        expect(pack.quadOf(cx, cy), quad, reason: 'as quatro células z21 do pacote');
        expect(biomes.spawnCellBiome(pack.quadOf(cx, cy)), winner);
      });
    }
  });

  test('quadOf lê (noroeste, nordeste, sudoeste, sudeste) da célula z20', () {
    const cx = 386871, cy = 592272;
    expect(pack.quadOf(cx, cy), [
      pack.biomeAt(2 * cx, 2 * cy),
      pack.biomeAt(2 * cx + 1, 2 * cy),
      pack.biomeAt(2 * cx, 2 * cy + 1),
      pack.biomeAt(2 * cx + 1, 2 * cy + 1),
    ]);
  });
}
