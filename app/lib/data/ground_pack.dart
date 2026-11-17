/// Leitor do uso do solo da região (`campinas_e0_ground.bin`, de `pipeline/build_ground.py`, 0.23.1): `GRD1` + gzip(varint
/// áreas; por área u8 tipo, varint pontos e pares x, y em 1/64 de célula z21, em deltas com zigzag a partir do primeiro ponto
/// da área anterior). Só o chão do estilo Completo lê: é cenário, fora das épocas.
library;

import 'dart:io' show gzip;
import 'dart:typed_data';

/// O tipo de cada área, na ordem do desenho (do maior para o mais específico). [mosaic] é a zona da calçada portuguesa.
enum GroundKind { residential, commercial, vacant, parking, paved, mosaic }

/// O chão (`groundRecipes`) de cada tipo; a zona da calçada portuguesa não pinta chão, só recorta a calçada.
const Map<GroundKind, String> groundRecipeOf = {
  GroundKind.residential: 'lot_res',
  GroundKind.commercial: 'commercial',
  GroundKind.vacant: 'vacant',
  GroundKind.parking: 'parking',
  GroundKind.paved: 'paved',
};

class GroundArea {
  GroundArea(this.kind, this.xy) {
    for (var i = 0; i < xy.length; i += 2) {
      if (xy[i] < l) l = xy[i];
      if (xy[i] > r) r = xy[i];
      if (xy[i + 1] < t) t = xy[i + 1];
      if (xy[i + 1] > b) b = xy[i + 1];
    }
  }

  final GroundKind kind;

  /// O contorno `x0, y0, x1, y1, ...` em células z21.
  final Float64List xy;
  double l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
}

class GroundPack {
  GroundPack(List<GroundArea> areas, {this.cellsPerTile = 64}) {
    for (final a in areas) {
      for (var ty = a.t ~/ cellsPerTile; ty <= a.b ~/ cellsPerTile; ty++) {
        for (var tx = a.l ~/ cellsPerTile; tx <= a.r ~/ cellsPerTile; tx++) {
          (_byTile[(tx, ty)] ??= []).add(a);
        }
      }
    }
  }

  /// Células z21 por tile do índice (o tile z15 da cena).
  final int cellsPerTile;
  final _byTile = <(int, int), List<GroundArea>>{};

  /// As áreas que tocam o tile `(tx, ty)`, na ordem do arquivo (por tipo).
  List<GroundArea> areasIn(int tx, int ty) => _byTile[(tx, ty)] ?? const [];

  factory GroundPack.parse(Uint8List bytes) {
    if (bytes.length < 4 || String.fromCharCodes(bytes.sublist(0, 4)) != 'GRD1') throw const FormatException('Magic diferente de GRD1');
    final body = Uint8List.fromList(gzip.decode(Uint8List.sublistView(bytes, 4)));
    var pos = 0;
    int varint() {
      var n = 0, shift = 0;
      while (true) {
        final c = body[pos++];
        n |= (c & 0x7f) << shift;
        if (c < 0x80) return n;
        shift += 7;
      }
    }

    int zz() {
      final v = varint();
      return (v >>> 1) ^ -(v & 1);
    }

    final n = varint();
    final areas = <GroundArea>[];
    var px = 0, py = 0;
    for (var i = 0; i < n; i++) {
      final k = body[pos++];
      final count = varint();
      final xy = Float64List(count * 2);
      var x0 = 0, y0 = 0;
      for (var j = 0; j < count; j++) {
        px += zz();
        py += zz();
        if (j == 0) (x0, y0) = (px, py);
        xy[j * 2] = px / 64;
        xy[j * 2 + 1] = py / 64;
      }
      (px, py) = (x0, y0);
      if (k < GroundKind.values.length) areas.add(GroundArea(GroundKind.values[k], xy)); // tipo de uma versão mais nova: ignora
    }
    return GroundPack(areas);
  }
}
