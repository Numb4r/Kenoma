/// Leitor do arquivo de rota (`campinas_e0_noaccess.bin`, de `pipeline/build_noaccess.py`): as vias do pacote visual
/// fechadas a pé, de bicicleta ou motorizado, e os viadutos. `NAC1` + gzip(varint linhas; por linha bits u8, varint pontos
/// e pares x, y em 1/64 de célula z21, em deltas com zigzag). Só a rota lê: não muda o mundo e não entra em época.
library;

import 'dart:io' show gzip;
import 'dart:math' as math;
import 'dart:typed_data';

import 'map_sources.dart';

class AccessPack implements RouteAccessSource {
  AccessPack._(this._byCell, this.lineCount);

  factory AccessPack.parse(Uint8List bytes) {
    if (bytes.length < 4 || String.fromCharCodes(bytes.sublist(0, 4)) != 'NAC1') throw const FormatException('Magic diferente de NAC1');
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
    final lines = varint();
    for (var l = 0; l < lines; l++) {
      final mask = body[pos++].toDouble();
      final n = varint();
      var x = 0, y = 0;
      double? ax, ay;
      for (var i = 0; i < n; i++) {
        final dx = varint(), dy = varint();
        x += (dx >>> 1) ^ -(dx & 1);
        y += (dy >>> 1) ^ -(dy & 1);
        final bx = x / 64, by = y / 64;
        if (ax != null) addAccessSegment(index, ax, ay!, bx, by, mask);
        ax = bx;
        ay = by;
      }
    }
    return AccessPack._(index, lines);
  }

  final Map<(int, int), List<double>> _byCell;
  final int lineCount;

  @override
  List<double> accessNear(int cx, int cy) => _byCell[(cx, cy)] ?? const [];
}

/// Põe o trecho em todas as células z20 que a caixa dele (com uma célula de folga) toca, como o `NoWalkPack`.
void addAccessSegment(Map<(int, int), List<double>> index, double ax, double ay, double bx, double by, double mask) {
  final x0 = (math.min(ax, bx) / 2).floor() - 1, x1 = (math.max(ax, bx) / 2).floor() + 1;
  final y0 = (math.min(ay, by) / 2).floor() - 1, y1 = (math.max(ay, by) / 2).floor() + 1;
  for (var cy = y0; cy <= y1; cy++) {
    for (var cx = x0; cx <= x1; cx++) {
      (index[(cx, cy)] ??= []).addAll([ax, ay, bx, by, mask]);
    }
  }
}
