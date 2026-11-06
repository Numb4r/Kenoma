/// Cache em disco do bloco do fallback. Cabeçalho de 18 bytes, little-endian: magic `FBK1`, version u16, tx u32, ty u32,
/// epochId u32. Depois, gzip de: `blockCells^2` bytes de bioma; varint linhas, cada uma `classe u8, sentido u8, varint
/// tamanho do nome, nome UTF-8, pontos`; varint áreas, cada uma `tipo u8, varint anéis, pontos`; varint n e `n` doubles
/// do noWalk. Pontos: varint n e pares em deltas com zigzag, como no pacote visual.
library;

import 'dart:convert' show utf8;
import 'dart:io' show gzip;
import 'dart:typed_data';

import '../../data/visual_pack.dart';
import 'block.dart';

const int _version = 1;
const int _headerSize = 18;

void _varint(BytesBuilder out, int n) {
  while (n >= 0x80) {
    out.addByte((n & 0x7F) | 0x80);
    n >>>= 7;
  }
  out.addByte(n);
}

void _points(BytesBuilder out, Int32List xy) {
  _varint(out, xy.length ~/ 2);
  var px = 0, py = 0;
  for (var i = 0; i + 1 < xy.length; i += 2) {
    final dx = xy[i] - px, dy = xy[i + 1] - py;
    _varint(out, (dx << 1) ^ (dx >> 63));
    _varint(out, (dy << 1) ^ (dy >> 63));
    px = xy[i];
    py = xy[i + 1];
  }
}

Uint8List encodeBlock(FallbackBlock b) {
  final body = BytesBuilder(copy: false)..add(b.cells);
  _varint(body, b.visual.lines.length);
  for (final line in b.visual.lines) {
    body
      ..addByte(line.roadClass.index)
      ..addByte(line.oneway.index);
    final name = utf8.encode(line.name ?? '');
    _varint(body, name.length);
    body.add(name);
    _points(body, line.xy);
  }
  _varint(body, b.visual.areas.length);
  for (final area in b.visual.areas) {
    body.addByte(area.kind.index);
    _varint(body, area.rings.length);
    for (final ring in area.rings) {
      _points(body, ring);
    }
  }
  _varint(body, b.noWalk.length);
  final noWalk = Float64List.fromList(b.noWalk);
  body.add(noWalk.buffer.asUint8List());

  final header = ByteData(_headerSize);
  for (var i = 0; i < 4; i++) {
    header.setUint8(i, 'FBK1'.codeUnitAt(i));
  }
  header
    ..setUint16(4, _version, Endian.little)
    ..setUint32(6, b.tx, Endian.little)
    ..setUint32(10, b.ty, Endian.little)
    ..setUint32(14, b.epochId, Endian.little);
  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(gzip.encode(body.takeBytes())))
      .takeBytes();
}

FallbackBlock decodeBlock(Uint8List bytes) {
  if (bytes.length < _headerSize || String.fromCharCodes(bytes.sublist(0, 4)) != 'FBK1') {
    throw const FormatException('Bloco do fallback sem o magic FBK1');
  }
  final header = ByteData.sublistView(bytes, 0, _headerSize);
  final version = header.getUint16(4, Endian.little);
  if (version != _version) throw FormatException('Versão $version do bloco do fallback não é suportada');
  final body = Uint8List.fromList(gzip.decode(Uint8List.sublistView(bytes, _headerSize)));
  const cellCount = blockCells * blockCells;
  var pos = cellCount;

  int varint() {
    var n = 0, shift = 0;
    while (true) {
      final b = body[pos++];
      n |= (b & 0x7F) << shift;
      if (b & 0x80 == 0) return n;
      shift += 7;
    }
  }

  Int32List points() {
    final out = Int32List(varint() * 2);
    var x = 0, y = 0;
    for (var i = 0; i < out.length; i += 2) {
      final dx = varint(), dy = varint();
      x += (dx >>> 1) ^ -(dx & 1);
      y += (dy >>> 1) ^ -(dy & 1);
      out[i] = x;
      out[i + 1] = y;
    }
    return out;
  }

  final lines = <VisualLine>[];
  for (var n = varint(); n > 0; n--) {
    final cls = body[pos++], oneway = body[pos++];
    final len = varint();
    final name = len == 0 ? null : utf8.decode(body.sublist(pos, pos + len));
    pos += len;
    lines.add(VisualLine(RoadClass.values[cls], points(), oneway: OneWay.values[oneway], name: name));
  }
  final areas = <VisualArea>[];
  for (var n = varint(); n > 0; n--) {
    final kind = AreaKind.values[body[pos++]];
    areas.add(VisualArea(kind, [for (var k = varint(); k > 0; k--) points()]));
  }
  final count = varint();
  final view = ByteData.sublistView(body, pos);
  final noWalk = [for (var i = 0; i < count; i++) view.getFloat64(i * 8, Endian.host)];
  return FallbackBlock(
    tx: header.getUint32(6, Endian.little),
    ty: header.getUint32(10, Endian.little),
    epochId: header.getUint32(14, Endian.little),
    cells: Uint8List.sublistView(body, 0, cellCount),
    visual: VisualTile(lines: lines, areas: areas),
    noWalk: noWalk,
  );
}
