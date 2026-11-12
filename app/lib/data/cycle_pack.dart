/// Leitor das ciclovias da região (`campinas_e0_cycle.bin`, de `pipeline/build_cycle.py`): `CYC1` + gzip(varint linhas;
/// por linha bits u8, varint pontos e pares x, y em 1/64 de célula z21, em deltas com zigzag). Bit 1: ciclovia própria;
/// bit 2: ciclofaixa numa rua. Só os ciclistas da simulação local leem: é cenário, fora das épocas (o pacote visual não
/// muda).
library;

import 'dart:io' show gzip;
import 'dart:typed_data';

class CycleLine {
  CycleLine(this.onRoad, this.xy);

  /// Ciclofaixa numa rua (o ciclista anda encostado na borda dela); senão, ciclovia própria.
  final bool onRoad;

  /// Pontos `x0, y0, x1, y1, ...` em células z21.
  final Float64List xy;

  double get midX => (xy[0] + xy[xy.length - 2]) / 2;
  double get midY => (xy[1] + xy[xy.length - 1]) / 2;
}

class CyclePack {
  CyclePack(this.lines) {
    for (final l in lines) {
      for (var i = 0; i < l.xy.length; i += 2) {
        final k = (l.xy[i] ~/ 16) * 4194304 + (l.xy[i + 1] ~/ 16);
        final b = _buckets[k] ??= [];
        if (b.isEmpty || !identical(b.last, l)) b.add(l);
      }
    }
  }

  factory CyclePack.parse(Uint8List bytes) {
    if (bytes.length < 4 || String.fromCharCodes(bytes.sublist(0, 4)) != 'CYC1') throw const FormatException('Magic diferente de CYC1');
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

    final out = <CycleLine>[];
    final count = varint();
    for (var l = 0; l < count; l++) {
      final bits = body[pos++], n = varint();
      final xy = Float64List(n * 2);
      var x = 0, y = 0;
      for (var i = 0; i < n; i++) {
        final dx = varint(), dy = varint();
        x += (dx >>> 1) ^ -(dx & 1);
        y += (dy >>> 1) ^ -(dy & 1);
        xy[2 * i] = x / 64;
        xy[2 * i + 1] = y / 64;
      }
      if (n >= 2) out.add(CycleLine(bits & 2 != 0 && bits & 1 == 0, xy));
    }
    return CyclePack(out);
  }

  final List<CycleLine> lines;
  final Map<int, List<CycleLine>> _buckets = {};

  /// As ciclovias com algum vértice no retângulo (células z21), sem repetir.
  List<CycleLine> linesIn(double left, double top, double right, double bottom) {
    final seen = <CycleLine>{};
    for (var bx = left ~/ 16; bx <= right ~/ 16; bx++) {
      for (var by = top ~/ 16; by <= bottom ~/ 16; by++) {
        seen.addAll(_buckets[bx * 4194304 + by] ?? const []);
      }
    }
    return seen.toList();
  }
}
