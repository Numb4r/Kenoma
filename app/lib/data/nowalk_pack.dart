/// Leitor do pacote das vias onde não se anda (`campinas_e2_nowalk.bin`): rodovias e vias expressas do extrato da época 0.
/// `NWK1` + gzip(varint linhas; por linha varint pontos e pares x, y em 1/64 de célula z21, em deltas com zigzag). Só a
/// geografia: a época 2 fixa o SHA-256 dele.
library;

import 'dart:io' show gzip;
import 'dart:typed_data';

class NoWalkPack {
  NoWalkPack._(this._byCell);

  factory NoWalkPack.parse(Uint8List bytes) {
    if (bytes.length < 4 || String.fromCharCodes(bytes.sublist(0, 4)) != 'NWK1') throw const FormatException('Magic diferente de NWK1');
    final body = Uint8List.fromList(gzip.decode(Uint8List.sublistView(bytes, 4)));
    var pos = 0;
    int varint() {
      var n = 0, shift = 0;
      while (true) {
        final b = body[pos++];
        n |= (b & 0x7F) << shift;
        if (b & 0x80 == 0) return n;
        shift += 7;
      }
    }

    final index = <(int, int), List<double>>{};
    for (var l = varint(); l > 0; l--) {
      final n = varint();
      var x = 0, y = 0;
      double? ax, ay;
      for (var i = 0; i < n; i++) {
        final dx = varint(), dy = varint();
        x += (dx >>> 1) ^ -(dx & 1);
        y += (dy >>> 1) ^ -(dy & 1);
        final bx = x / 64, by = y / 64; // células z21 fracionárias
        if (ax != null) {
          // Cada segmento entra em todas as células z20 que a caixa dele (com uma célula de folga) toca.
          final x0 = (_min(ax, bx) / 2).floor() - 1, x1 = (_max(ax, bx) / 2).floor() + 1;
          final y0 = (_min(ay!, by) / 2).floor() - 1, y1 = (_max(ay, by) / 2).floor() + 1;
          for (var cy = y0; cy <= y1; cy++) {
            for (var cx = x0; cx <= x1; cx++) {
              (index[(cx, cy)] ??= []).addAll([ax, ay, bx, by]);
            }
          }
        }
        ax = bx;
        ay = by;
      }
    }
    return NoWalkPack._(index);
  }

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;

  final Map<(int, int), List<double>> _byCell;

  /// Os segmentos `x0, y0, x1, y1, ...` (células z21 fracionárias) perto da célula z20 `(cx, cy)`. Vazio se nenhum.
  List<double> near(int cx, int cy) => _byCell[(cx, cy)] ?? const [];
}
