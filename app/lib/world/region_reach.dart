/// 0.26.4: quais regiões além da do jogador ficam no mundo. Uma região entra a menos de [loadM] da borda dela e sai a mais
/// de [unloadM] (a folga evita entrar e sair na divisa). No Modo Viagem tudo fica: o destino pode estar em qualquer uma.
/// Dart puro.
library;

import 'dart:math' as math;

/// O retângulo de uma região em graus.
class GeoBox {
  const GeoBox({required this.south, required this.west, required this.north, required this.east});

  /// O `bbox` do catálogo: oeste, sul, leste, norte.
  factory GeoBox.fromBbox(List<double> b) => GeoBox(west: b[0], south: b[1], east: b[2], north: b[3]);

  final double south, west, north, east;
}

/// Distância em metros de ([lat], [lon]) até o ponto mais perto de [b] (0 dentro dela).
double distanceToBoxM(double lat, double lon, GeoBox b) {
  final la = lat.clamp(b.south, b.north).toDouble(), lo = lon.clamp(b.west, b.east).toDouble();
  const r = 6371000.0, rad = math.pi / 180;
  final dLat = (la - lat) * rad, dLon = (lo - lon) * rad;
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(lat * rad) * math.cos(la * rad) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

enum RegionMove { load, unload, keep }

/// O que fazer com uma região a [distM] metros do jogador, já [loaded] ou não; com [travel] (Modo Viagem) tudo entra e
/// nada sai.
RegionMove regionMove({required double distM, required bool loaded, required double loadM, required double unloadM, bool travel = false}) {
  if (travel) return loaded ? RegionMove.keep : RegionMove.load;
  if (!loaded && distM < loadM) return RegionMove.load;
  if (loaded && distM > unloadM) return RegionMove.unload;
  return RegionMove.keep;
}
