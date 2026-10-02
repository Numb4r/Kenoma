/// Chunks do mapa: blocos de células z21 desenhados e guardados em cache juntos. Dart puro.
library;

import 'map_camera.dart';

/// Lado de um chunk, em células z21.
const int chunkCells = 64;

/// Chunk `(cx, cy)`: cobre as células `cx*64 .. cx*64+63` e `cy*64 .. cy*64+63`.
typedef ChunkId = (int cx, int cy);

/// Pixels por célula de cada nível de detalhe do chunk, do mais fino ao mais grosso. Longe do mapa o
/// chunk é desenhado com menos pixels, e a memória não cresce com a área visível.
const List<int> lodLevels = [16, 8, 4, 2];

ChunkId chunkOfCell(int x, int y) => (x >>> 6, y >>> 6);

/// As células z21 que o chunk cobre.
CellRange cellsOfChunk(ChunkId id) =>
    CellRange(id.$1 * chunkCells, id.$2 * chunkCells, id.$1 * chunkCells + chunkCells - 1, id.$2 * chunkCells + chunkCells - 1);

/// Chunks que tocam [range], de cima para baixo e da esquerda para a direita. Vazio se [range] é vazio.
List<ChunkId> chunksIn(CellRange range) {
  if (range.isEmpty) return const [];
  final c0 = range.x0 >>> 6, c1 = range.x1 >>> 6, r0 = range.y0 >>> 6, r1 = range.y1 >>> 6;
  return [for (var cy = r0; cy <= r1; cy++) for (var cx = c0; cx <= c1; cx++) (cx, cy)];
}

/// Nível de detalhe para a escala da tela: o menor que ainda tem ao menos um pixel por pixel de tela.
/// Acima de 16 px por célula usa o 16 e a tela amplia.
int lodFor(double pixelsPerCell) {
  for (final p in lodLevels.reversed) {
    if (p >= pixelsPerCell) return p;
  }
  return lodLevels.first;
}
