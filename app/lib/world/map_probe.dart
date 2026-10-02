/// O que há sob um ponto do mapa: coordenada, célula z21 e z20 e os biomas delas. É o que o menu de
/// debug mostra sob o dedo. Dart puro.
library;

import '../core/tiles.dart';
import 'region_map.dart';

class MapProbe {
  const MapProbe({
    required this.lat,
    required this.lon,
    required this.x21,
    required this.y21,
    required this.x20,
    required this.y20,
    required this.biome21,
    required this.spawnBiome20,
  });

  final double lat;
  final double lon;

  /// Célula z21 (a do bioma) e a célula z20 que a contém (a do spawn).
  final int x21;
  final int y21;
  final int x20;
  final int y20;

  /// Bioma da célula z21.
  final int biome21;

  /// Bioma de spawn da célula z20: a moda das quatro células z21 dela.
  final int spawnBiome20;
}

/// A sonda no ponto de mundo `(cellX, cellY)`, em células z21 fracionárias.
MapProbe probeAt(RegionMap map, double cellX, double cellY) {
  final x21 = cellX.floor();
  final y21 = cellY.floor();
  final x20 = x21 >>> 1;
  final y20 = y21 >>> 1;
  final (lat, lon) = tileFractionToLatLon(cellX, cellY, biomeZoom);
  return MapProbe(
    lat: lat,
    lon: lon,
    x21: x21,
    y21: y21,
    x20: x20,
    y20: y20,
    biome21: map.biomeAtCell(x21, y21),
    spawnBiome20: map.spawnBiomeAtCell(x20, y20),
  );
}
