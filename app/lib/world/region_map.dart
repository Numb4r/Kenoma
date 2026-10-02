/// Consulta de bioma sobre o pacote de região: por célula z21, por célula de spawn z20 e por
/// lat/lon. Dart puro. Fora do pacote tudo vale Vazio (docs/fase0-spec.md, seção 1).
library;

import '../core/biomes.dart';
import '../core/tiles.dart';
import '../data/region_pack.dart';

/// Id do Vazio em `biomes.json`.
const int voidBiomeId = 0;

class RegionMap {
  const RegionMap({required this.pack, required this.biomes});

  final RegionPack pack;
  final BiomeSet biomes;

  /// Se a célula z21 `(x, y)` está dentro da grade do pacote.
  bool containsCell(int x, int y) => x >= pack.x0 && y >= pack.y0 && x < pack.x0 + pack.width && y < pack.y0 + pack.height;

  /// Bioma da célula z21 `(x, y)`. Vazio fora do pacote.
  int biomeAtCell(int x, int y) => pack.biomeAt(x, y);

  /// Bioma da célula z21 que contém a coordenada. Vazio fora do pacote.
  int biomeAtLatLon(double lat, double lon) {
    final (x, y) = latLonToTile(lat, lon, biomeZoom);
    return pack.biomeAt(x, y);
  }

  /// Bioma de spawn da célula z20 `(x, y)`: a moda das quatro células z21 dela, com a maior prioridade
  /// no empate (a mesma regra que gera os spawns).
  int spawnBiomeAtCell(int x, int y) => biomes.spawnCellBiome(pack.quadOf(x, y));

  /// Bioma de spawn da célula z20 que contém a coordenada.
  int spawnBiomeAtLatLon(double lat, double lon) {
    final (x, y) = spawnCellAt(lat, lon);
    return spawnBiomeAtCell(x, y);
  }
}
