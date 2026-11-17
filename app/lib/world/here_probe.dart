/// A condição de agora num ponto (docs/GDD.md, "Condições, não lugares"): o mesmo clima, bioma e água que o mapa usa,
/// para a Bancada, os coletores e a qualidade do bruto. Dart puro.
library;

import 'dart:math' as math;

import '../core/astro.dart';
import '../core/tiles.dart';
import '../crafting/conditions.dart';

/// A condição em ([lat], [lon]) no instante [t]. A água mais perto é procurada nas células z20 (uns 38 m) até
/// [waterSearchM]; `waterM` fica `null` se não há.
Here probeHere({
  required double lat,
  required double lon,
  required int t,
  required String? Function(int x20, int y20) biomeAt,
  required String Function(int x20, int y20, int t) climateAt,
  List<String> Function(int x20, int y20, int t)? eventsAt,
  double waterSearchM = 300,
}) {
  final (x, y) = latLonToTile(lat, lon, 20);
  final cellM = metersPerCell(lat) * 2; // a célula z21 vezes 2
  final r = (waterSearchM / cellM).ceil();
  double? water;
  for (var dy = -r; dy <= r; dy++) {
    for (var dx = -r; dx <= r; dx++) {
      final d = math.sqrt((dx * dx + dy * dy).toDouble()) * cellM;
      if (d > waterSearchM || (water != null && d >= water)) continue;
      if (biomeAt(x + dx, y + dy) == 'water') water = d;
    }
  }
  return Here(
    utc: t,
    lat: lat,
    lon: lon,
    sunAltDeg: sunAltitudeDeg(lat, lon, t),
    climate: climateAt(x, y, t),
    events: eventsAt?.call(x, y, t) ?? const [],
    waterM: water,
    biome: biomeAt(x, y),
  );
}
