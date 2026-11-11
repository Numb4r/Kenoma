/// A direção da rua em cada célula z21, tirada do pacote visual que a época fixa (por tile z15): o que canaliza o vento
/// local. Determinístico (só o pacote, na ordem das linhas; ganha a rua de classe mais alta), então serve ao que é mundo: a
/// deriva das Fagulhas. Dart puro.
library;

import 'dart:collection';
import 'dart:math' as math;

import '../data/visual_pack.dart';
import 'visual_map.dart';

export '../core/wind_model.dart';

class StreetDirs {
  StreetDirs(this.visual, {this.cacheTiles = 16});

  final VisualMap visual;
  final int cacheTiles;
  final LinkedHashMap<(int, int), Map<int, (double, double, int)>> _tiles = LinkedHashMap();

  Map<int, (double, double, int)> _tile(int tx, int ty) {
    final key = (tx, ty);
    final hit = _tiles.remove(key);
    if (hit != null) return _tiles[key] = hit;
    final out = <int, (double, double, int)>{};
    final n = visual.cellsPerTile, unit = n / visual.pack.extent;
    // As linhas do próprio tile e as dos vizinhos que passam da borda.
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final vt = visual.tile(tx + dx, ty + dy);
        if (vt == null) continue;
        for (final line in vt.lines) {
          final r = switch (line.roadClass) { RoadClass.pedestrian => 0, RoadClass.local => 1, RoadClass.secondary => 2, RoadClass.principal => 3 };
          for (var i = 0; i + 3 < line.xy.length; i += 2) {
            final ax = line.xy[i] * unit + dx * n, ay = line.xy[i + 1] * unit + dy * n;
            final ex = line.xy[i + 2] * unit + dx * n - ax, ey = line.xy[i + 3] * unit + dy * n - ay, len = math.sqrt(ex * ex + ey * ey);
            if (len <= 0) continue;
            final steps = (len * 2).ceil();
            for (var s = 0; s <= steps; s++) {
              final cx = (ax + ex * s / steps).floor(), cy = (ay + ey * s / steps).floor();
              if (cx < 0 || cy < 0 || cx >= n || cy >= n) continue;
              final old = out[cy * n + cx];
              if (old == null || r > old.$3) out[cy * n + cx] = (ex / len, ey / len, r);
            }
          }
        }
      }
    }
    _tiles[key] = out;
    while (_tiles.length > cacheTiles) {
      _tiles.remove(_tiles.keys.first);
    }
    return out;
  }

  /// A direção (vetor unitário, sem sentido) da rua na célula z21 ([cx], [cy]), ou `null` fora das ruas.
  (double, double)? at(int cx, int cy) {
    final n = visual.cellsPerTile;
    final d = _tile(cx ~/ n, cy ~/ n)[(cy % n) * n + cx % n];
    return d == null ? null : (d.$1, d.$2);
  }
}
