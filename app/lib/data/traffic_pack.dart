/// Leitor do arquivo de pontos do tráfego (`campinas_e0_traffic.bin`, de `pipeline/build_traffic.py`): semáforos, pare, dê a
/// preferência, faixas de pedestre e entradas fora da rua (estacionamentos e garagens) do OSM. `TRF1` + gzip(varint pontos;
/// por ponto tipo u8 e x, y em 1/64 de célula z21, em deltas com zigzag). Só a simulação local do tráfego lê: é cenário, não
/// muda o mundo e não entra em época.
library;

import 'dart:io' show gzip;
import 'dart:typed_data';

/// A ordem é a do arquivo.
enum TrafficPointKind { signal, stop, giveWay, crossing, entry, busStop, shop, bar, school, square }

typedef TrafficPoint = ({TrafficPointKind kind, double x, double y});

/// Quem entrega os pontos do tráfego de um retângulo em células z21.
abstract interface class TrafficPointSource {
  List<TrafficPoint> pointsIn(double left, double top, double right, double bottom);
}

class TrafficPack implements TrafficPointSource {
  TrafficPack._(this._buckets, this.count);

  /// De uma lista pronta (testes e o fallback).
  factory TrafficPack.of(Iterable<TrafficPoint> points) {
    final b = <int, List<TrafficPoint>>{};
    var n = 0;
    for (final p in points) {
      (b[_key(p.x, p.y)] ??= []).add(p);
      n++;
    }
    return TrafficPack._(b, n);
  }

  factory TrafficPack.parse(Uint8List bytes) {
    if (bytes.length < 4 || String.fromCharCodes(bytes.sublist(0, 4)) != 'TRF1') throw const FormatException('Magic diferente de TRF1');
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

    final n = varint();
    var x = 0, y = 0;
    return TrafficPack.of([
      for (var i = 0; i < n; i++)
        () {
          final k = body[pos++];
          final kind = k < TrafficPointKind.values.length ? TrafficPointKind.values[k] : null; // tipo de uma versão mais nova: ignora
          final dx = varint(), dy = varint();
          x += (dx >>> 1) ^ -(dx & 1);
          y += (dy >>> 1) ^ -(dy & 1);
          return kind == null ? null : (kind: kind, x: x / 64, y: y / 64);
        }(),
    ].nonNulls);
  }

  /// Baldes de 16 células.
  final Map<int, List<TrafficPoint>> _buckets;
  final int count;

  static int _key(double x, double y) => (x ~/ 16) * 4194304 + (y ~/ 16);

  @override
  List<TrafficPoint> pointsIn(double left, double top, double right, double bottom) => [
        for (var bx = left ~/ 16; bx <= right ~/ 16; bx++)
          for (var by = top ~/ 16; by <= bottom ~/ 16; by++)
            for (final p in _buckets[bx * 4194304 + by] ?? const <TrafficPoint>[])
              if (p.x >= left && p.x <= right && p.y >= top && p.y <= bottom) p,
      ];
}
