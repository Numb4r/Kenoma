/// O grafo de ruas do Tráfego do Véu: as polilinhas do pacote visual em células z21, com a ligação entre ruas que se
/// encostam (inclusive de um tile para o vizinho). Dart puro. Só desenho: nada aqui decide spawn nem coleta.
library;

import 'dart:collection';
import 'dart:math' as math;

import '../data/visual_pack.dart';

/// Uma polilinha do pacote visual pronta para o tráfego: pontos em células z21 e o comprimento acumulado.
class GhostLine {
  GhostLine({required this.key, required this.roadClass, required this.oneway, required this.xy, required this.cum})
      : lengthCells = cum.last {
    var x0 = double.infinity, y0 = double.infinity, x1 = -double.infinity, y1 = -double.infinity;
    for (var i = 0; i < xy.length; i += 2) {
      x0 = math.min(x0, xy[i]);
      x1 = math.max(x1, xy[i]);
      y0 = math.min(y0, xy[i + 1]);
      y1 = math.max(y1, xy[i + 1]);
    }
    minX = x0;
    minY = y0;
    maxX = x1;
    maxY = y1;
  }

  /// Retângulo que contém a rua, em células.
  late final double minX, minY, maxX, maxY;

  /// Identifica a rua: tile e índice da linha dentro dele.
  final (int, int, int) key;
  final RoadClass roadClass;
  final OneWay oneway;

  /// Pontos `x0, y0, x1, y1, ...` em células z21 fracionárias.
  final List<double> xy;

  /// Comprimento acumulado até cada ponto, em células.
  final List<double> cum;
  final double lengthCells;

  int get vertexCount => xy.length ~/ 2;
  bool get isPedestrian => roadClass == RoadClass.pedestrian;
}

/// As linhas de tráfego de um tile: cada polilinha com duas ou mais pontas distintas.
List<GhostLine> ghostLinesOfTile(VisualTile tile, int tx, int ty, {required int cellsPerTile, required int extent}) {
  final unit = cellsPerTile / extent;
  final out = <GhostLine>[];
  for (var i = 0; i < tile.lines.length; i++) {
    final l = tile.lines[i];
    final n = l.xy.length ~/ 2;
    if (n < 2) continue;
    final xy = <double>[], cum = <double>[0.0];
    for (var k = 0; k < n; k++) {
      xy
        ..add(tx * cellsPerTile + l.xy[2 * k] * unit)
        ..add(ty * cellsPerTile + l.xy[2 * k + 1] * unit);
      if (k > 0) {
        final dx = xy[2 * k] - xy[2 * k - 2], dy = xy[2 * k + 1] - xy[2 * k - 1];
        cum.add(cum.last + math.sqrt(dx * dx + dy * dy));
      }
    }
    if (cum.last <= 0) continue;
    out.add(GhostLine(key: (tx, ty, i), roadClass: l.roadClass, oneway: l.oneway, xy: xy, cum: cum));
  }
  return out;
}

/// Um vértice de uma rua: onde outra rua pode se ligar.
typedef LineVertex = (GhostLine, int);

/// Distância em células abaixo da qual dois vértices são o mesmo cruzamento (o pacote arredonda em 1/64 de célula).
const double _joinCells = 0.35;

class _TileData {
  _TileData(this.lines, this.vertices);

  final List<GhostLine> lines;

  /// Vértices por balde de 1 célula.
  final Map<int, List<LineVertex>> vertices;
}

class TrafficGraph {
  TrafficGraph({required this.loadTile, required this.cellsPerTile, required this.extent, this.cacheTiles = 96});

  /// Quem entrega o tile do pacote visual (`null` se não há nada nele).
  final VisualTile? Function(int tx, int ty) loadTile;
  final int cellsPerTile;
  final int extent;
  final int cacheTiles;

  final LinkedHashMap<(int, int), _TileData> _tiles = LinkedHashMap();

  static int _bucket(int bx, int by) => bx * 4194304 + by;

  _TileData _data(int tx, int ty) {
    final key = (tx, ty);
    final cached = _tiles.remove(key);
    if (cached != null) {
      _tiles[key] = cached;
      return cached;
    }
    final tile = loadTile(tx, ty);
    final lines = tile == null ? const <GhostLine>[] : ghostLinesOfTile(tile, tx, ty, cellsPerTile: cellsPerTile, extent: extent);
    final vertices = <int, List<LineVertex>>{};
    for (final l in lines) {
      for (var i = 0; i < l.vertexCount; i++) {
        (vertices[_bucket(l.xy[2 * i].floor(), l.xy[2 * i + 1].floor())] ??= []).add((l, i));
      }
    }
    final d = _TileData(lines, vertices);
    _tiles[key] = d;
    while (_tiles.length > cacheTiles) {
      _tiles.remove(_tiles.keys.first);
    }
    return d;
  }

  List<GhostLine> linesOfTile(int tx, int ty) => _data(tx, ty).lines;

  /// Os vértices de outras ruas que caem em [x], [y] (a menos de [_joinCells]), fora [exclude]. A ordem é fixa
  /// (baldes na ordem de varredura, depois a ordem do pacote): dois aparelhos escolhem igual.
  List<LineVertex> joinsAt(double x, double y, {GhostLine? exclude}) {
    final out = <LineVertex>[];
    final bx = x.floor(), by = y.floor();
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final cx = bx + dx, cy = by + dy;
        final list = _data(cx ~/ cellsPerTile - (cx < 0 ? 1 : 0), cy ~/ cellsPerTile - (cy < 0 ? 1 : 0)).vertices[_bucket(cx, cy)];
        if (list == null) continue;
        for (final v in list) {
          if (identical(v.$1, exclude)) continue;
          final ddx = v.$1.xy[2 * v.$2] - x, ddy = v.$1.xy[2 * v.$2 + 1] - y;
          if (ddx * ddx + ddy * ddy <= _joinCells * _joinCells) out.add(v);
        }
      }
    }
    return out;
  }
}
