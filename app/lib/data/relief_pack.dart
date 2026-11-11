/// Leitor do relevo da região (`campinas_e9_relief.bin`, de `pipeline/build_relief.py`): a altura do terreno do SRTM de
/// 30 m numa grade z20 (uma amostra a cada duas células z21), suavizada. `REL1` + `zoom u8, x0 u32, y0 u32, largura u32,
/// altura u32` + gzip(decímetros i16, cada linha em deltas para a esquerda e a primeira coluna para cima).
///
/// **É mundo:** a água da chuva, a neblina e o vento saem daqui, então o SHA-256 do arquivo está na época
/// (`relief_packs`). A altura de um ponto é a interpolação bilinear das quatro amostras em volta, igual em todo aparelho.
library;

import 'dart:io' show gzip;
import 'dart:typed_data';

/// Quem entrega a altura do terreno. Sem relevo no lugar: `null` (terreno plano para quem pergunta).
abstract interface class ReliefSource {
  /// Altura em metros no ponto (células z21 fracionárias), ou `null` fora da grade.
  double? heightAt(double x21, double y21);
}

class ReliefPack implements ReliefSource {
  ReliefPack(this.zoom, this.x0, this.y0, this.width, this.height, this.dm) : assert(dm.length == width * height);

  factory ReliefPack.parse(Uint8List bytes) {
    if (bytes.length < 21 || String.fromCharCodes(bytes.sublist(0, 4)) != 'REL1') throw const FormatException('Magic diferente de REL1');
    final h = ByteData.sublistView(bytes, 4, 21);
    final zoom = h.getUint8(0), x0 = h.getUint32(1, Endian.little), y0 = h.getUint32(5, Endian.little);
    final w = h.getUint32(9, Endian.little), ht = h.getUint32(13, Endian.little);
    final body = Uint8List.fromList(gzip.decode(Uint8List.sublistView(bytes, 21)));
    if (body.length != w * ht * 2) throw const FormatException('Relevo com tamanho diferente do cabeçalho');
    final d = ByteData.sublistView(body);
    final dm = Int16List(w * ht);
    for (var y = 0; y < ht; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        dm[i] = d.getInt16(i * 2, Endian.little) + (x > 0 ? dm[i - 1] : (y > 0 ? dm[i - w] : 0));
      }
    }
    return ReliefPack(zoom, x0, y0, w, ht, dm);
  }

  /// O zoom da grade (20) e o canto dela em células desse zoom.
  final int zoom, x0, y0, width, height;

  /// Alturas em decímetros, linha por linha a partir do norte.
  final Int16List dm;

  @override
  double? heightAt(double x21, double y21) {
    // O centro da amostra (i, j) fica em i + 0,5 na grade.
    final s = 1 << (21 - zoom);
    final gx = x21 / s - x0 - 0.5, gy = y21 / s - y0 - 0.5;
    final ix = gx.floor(), iy = gy.floor();
    if (ix < 0 || iy < 0 || ix >= width - 1 || iy >= height - 1) return null;
    final fx = gx - ix, fy = gy - iy, i = iy * width + ix;
    final top = dm[i] + (dm[i + 1] - dm[i]) * fx, bottom = dm[i + width] + (dm[i + width + 1] - dm[i + width]) * fx;
    return (top + (bottom - top) * fy) / 10;
  }
}
