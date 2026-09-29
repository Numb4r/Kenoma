/// Leitor do pacote de região `.bin` (docs/fase0-spec.md, seção 1).
///
/// Cabeçalho de 23 bytes, little-endian: magic `VEU1`, version u16, zoom u8, x0 u32, y0 u32,
/// width u32, height u32. Depois, um stream gzip com `width x height` bytes, um id de bioma por
/// célula, em ordem row-major a partir de `(x0, y0)`.
library;

import 'dart:io' show gzip;
import 'dart:typed_data';

const int _headerSize = 23;
const int _voidBiome = 0;

class RegionPack {
  RegionPack._({
    required this.zoom,
    required this.x0,
    required this.y0,
    required this.width,
    required this.height,
    required this._cells,
  });

  factory RegionPack.parse(Uint8List bytes) {
    if (bytes.length < _headerSize) throw const FormatException('Pacote menor que o cabeçalho');
    final header = ByteData.sublistView(bytes, 0, _headerSize);
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'VEU1') {
      throw const FormatException('Magic do pacote diferente de VEU1');
    }
    final version = header.getUint16(4, Endian.little);
    if (version != 1) throw FormatException('Versão de pacote não suportada: $version');
    final width = header.getUint32(15, Endian.little);
    final height = header.getUint32(19, Endian.little);
    final cells = Uint8List.fromList(gzip.decode(bytes.sublist(_headerSize)));
    if (cells.length != width * height) {
      throw FormatException('Pacote com ${cells.length} células, esperado ${width * height}');
    }
    return RegionPack._(
      zoom: header.getUint8(6),
      x0: header.getUint32(7, Endian.little),
      y0: header.getUint32(11, Endian.little),
      width: width,
      height: height,
      cells: cells,
    );
  }

  final int zoom;
  final int x0;
  final int y0;
  final int width;
  final int height;
  final Uint8List _cells;

  /// Id do bioma da célula z21 `(x, y)`. Fora do pacote vale Vazio.
  int biomeAt(int x, int y) {
    final col = x - x0;
    final row = y - y0;
    if (col < 0 || row < 0 || col >= width || row >= height) return _voidBiome;
    return _cells[row * width + col];
  }

  /// As quatro células z21 de uma célula z20, na ordem (noroeste, nordeste, sudoeste, sudeste).
  List<int> quadOf(int cellX, int cellY) {
    final x = cellX * 2;
    final y = cellY * 2;
    return [biomeAt(x, y), biomeAt(x + 1, y), biomeAt(x, y + 1), biomeAt(x + 1, y + 1)];
  }
}
