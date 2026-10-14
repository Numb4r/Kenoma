/// As geometrias do pacote visual por tile z15: carrega sob demanda, guarda as mais recentes e diz quais
/// tiles cobrem um retângulo do mundo. Dart puro. Só desenho: nada aqui decide o que existe no jogo.
library;

import 'dart:collection';

import '../data/visual_pack.dart';

class VisualMap {
  VisualMap(this.pack, {this.cacheTiles = 64});

  final VisualPack pack;
  final int cacheTiles;

  /// Tiles decodificados, do menos para o mais recentemente usado. Tile sem geometria entra como `null`.
  final LinkedHashMap<(int, int), VisualTile?> _cache = LinkedHashMap();

  int get cachedTiles => _cache.length;

  /// Células z21 por tile z15: 2^(21-15).
  int get cellsPerTile => 1 << (21 - pack.tileZoom);

  /// O tile `(x, y)`, ou `null` se não há nada nele.
  VisualTile? tile(int x, int y) {
    final key = (x, y);
    if (_cache.containsKey(key)) {
      final t = _cache.remove(key);
      _cache[key] = t;
      return t;
    }
    final t = pack.decode(x, y);
    _cache[key] = t;
    while (_cache.length > cacheTiles) {
      _cache.remove(_cache.keys.first);
    }
    return t;
  }

  /// Os tiles z15 que tocam o retângulo em células z21 fracionárias, com [marginCells] de folga. As
  /// geometrias dos tiles vizinhos passam um pouco da borda, então a folga evita emenda.
  List<(int, int)> tilesIn(double x0, double y0, double x1, double y1, {double marginCells = 0}) {
    final n = cellsPerTile.toDouble();
    return [
      for (var ty = ((y0 - marginCells) / n).floor(); ty <= ((y1 + marginCells) / n).floor(); ty++)
        for (var tx = ((x0 - marginCells) / n).floor(); tx <= ((x1 + marginCells) / n).floor(); tx++)
          if (pack.hasTile(tx, ty)) (tx, ty),
    ];
  }

  /// Posição de um ponto do tile `(tx, ty)` em células z21 fracionárias.
  (double, double) toCell(int tx, int ty, int ux, int uy) {
    final n = cellsPerTile.toDouble();
    return ((tx + ux / pack.extent) * n, (ty + uy / pack.extent) * n);
  }
}
