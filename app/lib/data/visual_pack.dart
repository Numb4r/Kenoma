// ignore_for_file: prefer_initializing_formals
/// Leitor do pacote visual `.bin` (docs/fase0-spec.md, seção 1, "Pacote visual").
///
/// Cabeçalho de 13 bytes, little-endian: magic `VIS1`, version u16, tile_zoom u8, extent u16, tiles u32.
/// Depois, um stream gzip com os tiles z15 em ordem de (x, y): `x u32, y u32, len u32` e `len` bytes de
/// carga. Coordenadas inteiras relativas ao canto do tile, em `extent` unidades por tile, em deltas com
/// zigzag e varint. Só desenho: a grade de biomas é a única camada lógica.
library;

import 'dart:io' show gzip;
import 'dart:typed_data';

const int _headerSize = 13;

/// Classe da rua, do mais largo para o mais estreito.
enum RoadClass { principal, secondary, local, pedestrian }

enum AreaKind { water, green }

class VisualLine {
  const VisualLine(this.roadClass, this.xy);

  final RoadClass roadClass;

  /// Pontos `x0, y0, x1, y1, ...` em unidades do tile.
  final Int32List xy;
}

class VisualArea {
  const VisualArea(this.kind, this.rings);

  final AreaKind kind;

  /// O primeiro anel é o contorno; os outros são buracos. Cada um é `x0, y0, x1, y1, ...`.
  final List<Int32List> rings;
}

class VisualTile {
  const VisualTile({required this.lines, required this.areas});

  final List<VisualLine> lines;
  final List<VisualArea> areas;

  bool get isEmpty => lines.isEmpty && areas.isEmpty;
}

class VisualPack {
  VisualPack._({required this.tileZoom, required this.extent, required Uint8List body, required Map<(int, int), (int, int)> index})
      : _body = body,
        _index = index;

  factory VisualPack.parse(Uint8List bytes) {
    if (bytes.length < _headerSize) throw const FormatException('Pacote visual menor que o cabeçalho');
    final header = ByteData.sublistView(bytes, 0, _headerSize);
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'VIS1') throw const FormatException('Magic do pacote visual diferente de VIS1');
    final version = header.getUint16(4, Endian.little);
    if (version != 1) throw FormatException('Versão $version do pacote visual não é suportada');
    final zoom = header.getUint8(6);
    final extent = header.getUint16(7, Endian.little);
    final count = header.getUint32(9, Endian.little);
    final body = Uint8List.fromList(gzip.decode(Uint8List.sublistView(bytes, _headerSize)));
    final view = ByteData.sublistView(body);
    final index = <(int, int), (int, int)>{};
    var i = 0;
    for (var t = 0; t < count; t++) {
      if (i + 12 > body.length) throw const FormatException('Pacote visual cortado no meio de um tile');
      final x = view.getUint32(i, Endian.little), y = view.getUint32(i + 4, Endian.little), len = view.getUint32(i + 8, Endian.little);
      i += 12;
      if (i + len > body.length) throw const FormatException('Pacote visual cortado no meio de um tile');
      index[(x, y)] = (i, len);
      i += len;
    }
    return VisualPack._(tileZoom: zoom, extent: extent, body: body, index: index);
  }

  /// Zoom dos tiles (15) e unidades por tile (4096).
  final int tileZoom;
  final int extent;
  final Uint8List _body;
  final Map<(int, int), (int, int)> _index;

  int get tileCount => _index.length;

  bool hasTile(int x, int y) => _index.containsKey((x, y));

  /// Decodifica o tile `(x, y)`. `null` se o pacote não tem esse tile (não há nada para desenhar ali).
  VisualTile? decode(int x, int y) {
    final entry = _index[(x, y)];
    if (entry == null) return null;
    final r = _Reader(_body, entry.$1);
    final lines = <VisualLine>[];
    for (var n = r.varint(); n > 0; n--) {
      final cls = r.byte();
      lines.add(VisualLine(RoadClass.values[cls], r.points()));
    }
    final areas = <VisualArea>[];
    for (var n = r.varint(); n > 0; n--) {
      final kind = r.byte();
      final rings = [for (var k = r.varint(); k > 0; k--) r.points()];
      areas.add(VisualArea(kind == 1 ? AreaKind.water : AreaKind.green, rings));
    }
    if (r.pos != entry.$1 + entry.$2) throw const FormatException('Tile do pacote visual com tamanho errado');
    return VisualTile(lines: lines, areas: areas);
  }
}

class _Reader {
  _Reader(this.buf, this.pos);

  final Uint8List buf;
  int pos;

  int byte() => buf[pos++];

  int varint() {
    var n = 0, shift = 0;
    while (true) {
      final b = buf[pos++];
      n |= (b & 0x7F) << shift;
      if (b & 0x80 == 0) return n;
      shift += 7;
    }
  }

  Int32List points() {
    final n = varint();
    final out = Int32List(n * 2);
    var x = 0, y = 0;
    for (var i = 0; i < n; i++) {
      final dx = varint(), dy = varint();
      x += (dx >>> 1) ^ -(dx & 1);
      y += (dy >>> 1) ^ -(dy & 1);
      out[2 * i] = x;
      out[2 * i + 1] = y;
    }
    return out;
  }
}
