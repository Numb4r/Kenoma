/// Coordenadas de tile Web Mercator (slippy map). Inteiras e determinísticas.
library;

import 'dart:math' as math;

/// Tile `(x, y)`, com y crescendo para o sul.
typedef Tile = (int x, int y);

const int biomeZoom = 21;
const int spawnZoom = 20;

/// Tile que contém a coordenada, em qualquer zoom.
Tile latLonToTile(double lat, double lon, int zoom) {
  final n = 1 << zoom;
  final x = ((lon + 180.0) / 360.0 * n).floor();
  final tan = math.tan(lat * math.pi / 180.0);
  final asinh = math.log(tan + math.sqrt(tan * tan + 1.0));
  final y = ((1.0 - asinh / math.pi) / 2.0 * n).floor();
  return (x.clamp(0, n - 1), y.clamp(0, n - 1));
}

/// Célula de spawn (z20) que contém a coordenada.
Tile spawnCellAt(double lat, double lon) => latLonToTile(lat, lon, spawnZoom);

/// Tile pai, um zoom abaixo.
Tile parentTile(Tile t) => (t.$1 >>> 1, t.$2 >>> 1);
