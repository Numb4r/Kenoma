/// O nome da rua perto de um ponto, para o aviso de Eco raro da Patrulha ("na R. Barão de Jaguara"). Vem das linhas com
/// nome do pacote visual (só as principais e secundárias têm). Dart puro; só texto, nada aqui decide o mundo.
library;

import 'dart:math' as math;

import '../world/visual_map.dart';

/// A rua com nome mais perto de ([x], [y]) (células z21), a até [maxCells] células, ou `null`.
String? nearestStreetName(VisualMap visual, double x, double y, double maxCells) {
  final n = visual.cellsPerTile.toDouble();
  final unit = n / visual.pack.extent;
  String? best;
  var bestD = maxCells;
  for (final (tx, ty) in visual.tilesIn(x, y, x, y, marginCells: maxCells)) {
    final tile = visual.tile(tx, ty);
    if (tile == null) continue;
    // O ponto em unidades do tile, para comparar sem converter cada vértice.
    final px = (x - tx * n) / unit, py = (y - ty * n) / unit;
    for (final line in tile.lines) {
      final name = line.name;
      if (name == null) continue;
      final xy = line.xy;
      for (var i = 0; i + 3 < xy.length; i += 2) {
        final d = _segmentDistance(px, py, xy[i].toDouble(), xy[i + 1].toDouble(), xy[i + 2].toDouble(), xy[i + 3].toDouble()) * unit;
        if (d < bestD) {
          bestD = d;
          best = name;
        }
      }
    }
  }
  return best;
}

double _segmentDistance(double px, double py, double ax, double ay, double bx, double by) {
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  final t = len2 == 0 ? 0.0 : (((px - ax) * dx + (py - ay) * dy) / len2).clamp(0.0, 1.0);
  final qx = ax + t * dx - px, qy = ay + t * dy - py;
  return math.sqrt(qx * qx + qy * qy);
}

const _short = {'Rua': 'R.', 'Avenida': 'Av.', 'Travessa': 'Tv.', 'Alameda': 'Al.', 'Rodovia': 'Rod.', 'Praça': 'Pça.', 'Estrada': 'Estr.'};
const _masculine = {'Largo', 'Viaduto', 'Parque', 'Caminho', 'Beco', 'Túnel', 'Acesso', 'Anel', 'Complexo', 'Corredor'};

/// "na R. Barão de Jaguara", "no Viaduto Miguel Vicente Cury"; sem nome, "por perto".
String streetPhrase(String? name) {
  if (name == null || name.trim().isEmpty) return 'por perto';
  final parts = name.trim().split(' ');
  final first = parts.first;
  final prep = _masculine.contains(first) ? 'no' : 'na';
  final shortened = _short[first];
  return '$prep ${shortened == null ? name.trim() : [shortened, ...parts.skip(1)].join(' ')}';
}
