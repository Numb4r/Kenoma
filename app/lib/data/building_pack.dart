/// Leitor do arquivo de prédios e árvores `<região>_e0_bldg.bin` (0.22.0, `pipeline/build_buildings.py`): só cenário do estilo
/// Completo do mapa. Nada da lógica lê; não é mundo e não entra em época. Coordenadas em células z21 (com fração).
library;

import 'dart:io' show gzip;
import 'dart:typed_data';
import 'dart:convert' show utf8;

/// Um prédio: o contorno em células z21, o tipo do OSM (`house`, `yes`...), os andares (0 = sem dado) e se é comércio.
class PackBuilding {
  PackBuilding(this.xy, this.type, this.levels, this.shop, this.index);

  /// `x0, y0, x1, y1, ...` em células z21.
  final Float64List xy;
  final String type;
  final int levels;
  final bool shop;

  /// A posição no arquivo: o hash do prédio (estilo, janelas, props) sai dela e do contorno, igual em todo aparelho.
  final int index;

  int get length => xy.length ~/ 2;

  late final (double, double) centroid = () {
    var x = 0.0, y = 0.0;
    for (var i = 0; i < xy.length; i += 2) {
      x += xy[i];
      y += xy[i + 1];
    }
    return (x / length, y / length);
  }();

  /// A área em células² (o sinal some).
  late final double areaCells = () {
    var a = 0.0;
    for (var i = 0; i < length; i++) {
      final j = (i + 1) % length;
      a += xy[2 * i] * xy[2 * j + 1] - xy[2 * j] * xy[2 * i + 1];
    }
    return a.abs() / 2;
  }();

  late final (double, double, double, double) bounds = () {
    var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
    for (var i = 0; i < xy.length; i += 2) {
      if (xy[i] < l) l = xy[i];
      if (xy[i] > r) r = xy[i];
      if (xy[i + 1] < t) t = xy[i + 1];
      if (xy[i + 1] > b) b = xy[i + 1];
    }
    return (l, t, r, b);
  }();
}

/// A fonte de prédios e árvores do mapa (o arquivo de uma região, ou várias).
abstract interface class BuildingSource {
  /// Os prédios cujo centro cai no retângulo (células z21), com folga de [margin] células.
  Iterable<PackBuilding> buildingsIn(double l, double t, double r, double b, {double margin = 2});

  /// As árvores do OSM no retângulo (células z21).
  Iterable<(double, double)> treesIn(double l, double t, double r, double b);
}

const int _unit = 64;

/// O índice: baldes de 16 × 16 células z21 (um tile z17).
const int _bucketShift = 4;

class BuildingPack implements BuildingSource {
  BuildingPack._(this.buildings, this._byBucket, this._trees);

  factory BuildingPack.parse(Uint8List bytes) {
    if (bytes.length < 4 || String.fromCharCodes(bytes.sublist(0, 4)) != 'BLD1') throw const FormatException('Arquivo de prédios sem o magic BLD1');
    final body = Uint8List.fromList(gzip.decode(Uint8List.sublistView(bytes, 4)));
    var i = 0;
    int varint() {
      var v = 0, shift = 0;
      while (true) {
        if (i >= body.length) throw const FormatException('Arquivo de prédios cortado');
        final b = body[i++];
        v |= (b & 0x7f) << shift;
        if (b < 0x80) return v;
        shift += 7;
      }
    }

    int zz() {
      final v = varint();
      return (v >>> 1) ^ -(v & 1);
    }

    final types = <String>[];
    for (var n = varint(); n > 0; n--) {
      final len = varint();
      types.add(utf8.decode(body.sublist(i, i + len)));
      i += len;
    }
    final buildings = <PackBuilding>[];
    final byBucket = <int, List<int>>{};
    var px = 0, py = 0;
    final count = varint();
    for (var k = 0; k < count; k++) {
      final type = types[varint()];
      final levels = body[i], flags = body[i + 1];
      i += 2;
      final n = varint();
      final xy = Float64List(n * 2);
      var x0 = 0, y0 = 0;
      for (var j = 0; j < n; j++) {
        px += zz();
        py += zz();
        if (j == 0) (x0, y0) = (px, py);
        xy[2 * j] = px / _unit;
        xy[2 * j + 1] = py / _unit;
      }
      (px, py) = (x0, y0);
      final b = PackBuilding(xy, type, levels, flags & 1 == 1, k);
      buildings.add(b);
      final (cx, cy) = b.centroid;
      byBucket.putIfAbsent(_key(cx.floor() >>> _bucketShift, cy.floor() >>> _bucketShift), () => []).add(k);
    }
    final trees = <int, List<(double, double)>>{};
    px = py = 0;
    for (var n = varint(); n > 0; n--) {
      px += zz();
      py += zz();
      final p = (px / _unit, py / _unit);
      trees.putIfAbsent(_key(p.$1.floor() >>> _bucketShift, p.$2.floor() >>> _bucketShift), () => []).add(p);
    }
    return BuildingPack._(buildings, byBucket, trees);
  }

  final List<PackBuilding> buildings;
  final Map<int, List<int>> _byBucket;
  final Map<int, List<(double, double)>> _trees;

  int get treeCount => _trees.values.fold(0, (a, l) => a + l.length);

  static int _key(int bx, int by) => bx * 0x100000 + by;

  @override
  Iterable<PackBuilding> buildingsIn(double l, double t, double r, double b, {double margin = 2}) sync* {
    final x0 = (l - margin).floor() >>> _bucketShift, x1 = (r + margin).floor() >>> _bucketShift;
    final y0 = (t - margin).floor() >>> _bucketShift, y1 = (b + margin).floor() >>> _bucketShift;
    for (var bx = x0; bx <= x1; bx++) {
      for (var by = y0; by <= y1; by++) {
        for (final k in _byBucket[_key(bx, by)] ?? const <int>[]) {
          final p = buildings[k];
          final (cx, cy) = p.centroid;
          if (cx >= l - margin && cx <= r + margin && cy >= t - margin && cy <= b + margin) yield p;
        }
      }
    }
  }

  @override
  Iterable<(double, double)> treesIn(double l, double t, double r, double b) sync* {
    for (var bx = l.floor() >>> _bucketShift; bx <= r.floor() >>> _bucketShift; bx++) {
      for (var by = t.floor() >>> _bucketShift; by <= b.floor() >>> _bucketShift; by++) {
        for (final p in _trees[_key(bx, by)] ?? const <(double, double)>[]) {
          if (p.$1 >= l && p.$1 <= r && p.$2 >= t && p.$2 <= b) yield p;
        }
      }
    }
  }
}
