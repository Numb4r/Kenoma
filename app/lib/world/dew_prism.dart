/// O Prisma de orvalho (docs/GDD.md, "Tempo, astronomia e clima", Arco-íris): o item fabricado na Bancada que aponta o
/// pé do arco-íris ativo mais perto, com a direção e a distância, e se gasta ao usar. Sem arco ativo, ele não é gasto.
/// Dart puro.
library;

import 'dart:math' as math;

import '../core/climate.dart' show RainbowArc;
import 'climate_world.dart';

const String dewPrismId = 'item.dew_prism';

/// A direção (graus a partir do norte, sentido horário) e a distância (m) do jogador ao pé do arco.
typedef PrismReading = ({double bearingDeg, double distanceM});

PrismReading prismReading(RainbowArc arc, double x21, double y21, double metersPerCell21) {
  final dx = arc.footX - x21, dy = arc.footY - y21;
  final deg = math.atan2(dx, -dy) * 180 / math.pi;
  return (bearingDeg: (deg + 360) % 360, distanceM: math.sqrt(dx * dx + dy * dy) * metersPerCell21);
}

/// Usa um prisma em (x21, y21) no instante [t]: o arco ativo mais perto a até [searchM] metros. Só com arco [take] gasta
/// o item; `null` se não há arco (nada gasto) ou se [take] falhou (não há prisma).
PrismReading? useDewPrism({required ClimateWorld world, required bool Function() take, required double x21, required double y21, required int t, required double metersPerCell21, double searchM = 6000}) {
  final arcs = world.rainbowsNear(x21, y21, searchM / metersPerCell21, t);
  if (arcs.isEmpty) return null;
  final best = arcs.map((a) => prismReading(a, x21, y21, metersPerCell21)).reduce((a, b) => a.distanceM <= b.distanceM ? a : b);
  return take() ? best : null;
}

/// O nome do rumo (oito direções): "norte", "nordeste"...
String compassPoint(double deg) => const ['norte', 'nordeste', 'leste', 'sudeste', 'sul', 'sudoeste', 'oeste', 'noroeste'][((deg % 360) / 45 + 0.5).floor() % 8];
