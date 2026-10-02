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

/// Posição fracionária em tiles (x para leste, y para o sul) de uma coordenada: o tile é a parte inteira.
(double, double) latLonToTileFraction(double lat, double lon, int zoom) {
  final n = (1 << zoom).toDouble();
  final x = (lon + 180.0) / 360.0 * n;
  final tan = math.tan(lat * math.pi / 180.0);
  final asinh = math.log(tan + math.sqrt(tan * tan + 1.0));
  final y = (1.0 - asinh / math.pi) / 2.0 * n;
  return (x, y);
}

/// Inverso de [latLonToTileFraction]: latitude e longitude de uma posição fracionária em tiles.
(double, double) tileFractionToLatLon(double x, double y, int zoom) {
  final n = (1 << zoom).toDouble();
  final lon = x / n * 360.0 - 180.0;
  final sinh = (math.exp(math.pi * (1 - 2 * y / n)) - math.exp(-math.pi * (1 - 2 * y / n))) / 2;
  final lat = math.atan(sinh) * 180.0 / math.pi;
  return (lat, lon);
}

/// Circunferência da Terra no equador, em metros (Web Mercator).
const double earthCircumferenceM = 40075016.686;

/// Metros que uma célula (um tile) de [zoom] mede de lado, na latitude [lat]. Na z21 em Campinas são
/// ~17,6 m, e a célula de spawn z20, ~35 m.
double metersPerCell(double lat, {int zoom = biomeZoom}) =>
    earthCircumferenceM * math.cos(lat * math.pi / 180.0) / (1 << zoom);
