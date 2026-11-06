/// Bloco do fallback sob demanda (docs/GDD.md, "Fallback sob demanda"): um tile z15 (~1,1 km) classificado no aparelho a
/// partir da Overpass, com as mesmas regras do pipeline. Dart puro.
library;

import 'dart:typed_data';

import '../../data/visual_pack.dart';

/// Zoom do bloco: o tile z15 do pacote visual.
const int blockZoom = 15;

/// Células z21 por lado do bloco: 2^(21-15).
const int blockCells = 64;

class FallbackBlock {
  const FallbackBlock({
    required this.tx,
    required this.ty,
    required this.epochId,
    required this.cells,
    required this.visual,
    required this.noWalk,
  });

  /// O tile z15.
  final int tx, ty;

  /// A época cujo início fixou a data da consulta.
  final int epochId;

  /// `blockCells * blockCells` ids de bioma, row-major a partir do canto noroeste do tile.
  final Uint8List cells;

  /// Ruas, água e verde do bloco, no mesmo formato do pacote visual (extent 4096).
  final VisualTile visual;

  /// Rodovias e vias expressas: `x0, y0, x1, y1, ...` em células z21 fracionárias.
  final List<double> noWalk;

  /// Bioma da célula z21 `(x, y)`, que tem de estar dentro do bloco.
  int biomeAt(int x, int y) => cells[(y - ty * blockCells) * blockCells + (x - tx * blockCells)];
}
