import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/visual_map.dart';

int _zig(int n) => (n << 1) ^ (n >> 63);

List<int> _varint(int n) {
  final out = <int>[];
  do {
    var b = n & 0x7F;
    n >>>= 7;
    if (n != 0) b |= 0x80;
    out.add(b);
  } while (n != 0);
  return out;
}

List<int> _points(List<(int, int)> pts) {
  final out = <int>[..._varint(pts.length)];
  var px = 0, py = 0;
  for (final (x, y) in pts) {
    out..addAll(_varint(_zig(x - px)))..addAll(_varint(_zig(y - py)));
    px = x;
    py = y;
  }
  return out;
}

/// Um pacote VIS1 pequeno, montado à mão: um tile com duas ruas e um lago com uma ilha.
Uint8List syntheticPack() {
  final tile = <int>[
    ..._varint(2),
    0, ..._points([(0, 0), (4096, 0), (4100, -30)]), // principal, passa da borda e volta negativo
    3, ..._points([(10, 10), (5, 20)]), // pedestre
    ..._varint(1),
    1, ..._varint(2), ..._points([(100, 100), (900, 100), (900, 900), (100, 900)]), ..._points([(400, 400), (600, 400), (600, 600)]),
  ];
  final body = <int>[
    ...(ByteData(12)
          ..setUint32(0, 5, Endian.little)
          ..setUint32(4, 7, Endian.little)
          ..setUint32(8, tile.length, Endian.little))
        .buffer
        .asUint8List(),
    ...tile,
  ];
  final header = ByteData(13)
    ..setUint8(0, 0x56) // V
    ..setUint8(1, 0x49) // I
    ..setUint8(2, 0x53) // S
    ..setUint8(3, 0x31) // 1
    ..setUint16(4, 1, Endian.little)
    ..setUint8(6, 15)
    ..setUint16(7, 4096, Endian.little)
    ..setUint32(9, 1, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...gzip.encode(body)]);
}

void main() {
  test('lê o cabeçalho, o índice e decodifica ruas e áreas com deltas e zigzag', () {
    final pack = VisualPack.parse(syntheticPack());
    expect((pack.tileZoom, pack.extent, pack.tileCount), (15, 4096, 1));
    expect(pack.hasTile(5, 7), isTrue);
    expect(pack.hasTile(5, 8), isFalse);
    expect(pack.decode(5, 8), isNull);

    final t = pack.decode(5, 7)!;
    expect(t.lines.length, 2);
    expect(t.lines[0].roadClass, RoadClass.principal);
    expect(t.lines[0].xy, [0, 0, 4096, 0, 4100, -30]);
    expect(t.lines[1].roadClass, RoadClass.pedestrian);
    expect(t.lines[1].xy, [10, 10, 5, 20]);
    expect(t.areas.single.kind, AreaKind.water);
    expect(t.areas.single.rings.length, 2, reason: 'contorno e uma ilha');
    expect(t.areas.single.rings[1], [400, 400, 600, 400, 600, 600]);
  });

  test('pacote com magic errado, versão desconhecida ou cortado é recusado', () {
    final ok = syntheticPack();
    expect(() => VisualPack.parse(Uint8List.fromList([...ok]..[0] = 0x58)), throwsFormatException);
    expect(() => VisualPack.parse(Uint8List.fromList([...ok]..[4] = 9)), throwsFormatException);
    expect(() => VisualPack.parse(Uint8List(5)), throwsFormatException);
  });

  group('VisualMap: tiles por retângulo e cache', () {
    final map = VisualMap(VisualPack.parse(syntheticPack()), cacheTiles: 2);

    test('um tile z15 tem 64 células z21; só entram os tiles que existem', () {
      expect(map.cellsPerTile, 64);
      expect(map.tilesIn(5 * 64 + 1.0, 7 * 64 + 1.0, 5 * 64 + 10.0, 7 * 64 + 10.0), [(5, 7)]);
      expect(map.tilesIn(0, 0, 10, 10), isEmpty);
      // Atravessando a borda com o vizinho que não existe: só o que existe volta.
      expect(map.tilesIn(5 * 64 + 60.0, 7 * 64 + 60.0, 6 * 64 + 5.0, 8 * 64 + 5.0), [(5, 7)]);
    });

    test('a folga puxa o tile vizinho', () {
      expect(map.tilesIn(4 * 64 + 62.0, 7 * 64 + 10.0, 4 * 64 + 63.0, 7 * 64 + 20.0), isEmpty);
      expect(map.tilesIn(4 * 64 + 62.0, 7 * 64 + 10.0, 4 * 64 + 63.0, 7 * 64 + 20.0, marginCells: 3), [(5, 7)]);
    });

    test('toCell converte unidades do tile em células z21', () {
      final (x, y) = map.toCell(5, 7, 2048, 1024);
      expect((x, y), (5 * 64 + 32.0, 7 * 64 + 16.0));
    });

    test('o cache guarda no máximo cacheTiles tiles e devolve o mesmo objeto enquanto o guarda', () {
      final a = map.tile(5, 7);
      expect(a, isNotNull);
      expect(identical(map.tile(5, 7), a), isTrue);
      map.tile(1, 1);
      map.tile(2, 2);
      map.tile(3, 3);
      expect(map.cachedTiles, lessThanOrEqualTo(2));
    });
  });
}
