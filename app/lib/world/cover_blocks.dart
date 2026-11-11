/// O que um bloco da cobertura por campo (`cover_field.dart`) precisa do pacote visual: as ruas e as áreas que o tocam, com
/// o quanto a cobertura pega cada rua ([StreetCover.level], da seed e da rua). Dart puro.
library;

import '../data/visual_pack.dart';
import 'cover_field.dart';
import 'street_cover.dart';
import 'visual_map.dart';

/// A entrada do bloco ([bx], [by]) para a cobertura [cover] com [amount] dela formada. [wearOf] é o desgaste do tráfego
/// local por rua (tile e índice da linha), de 0 a 1.
CoverInput coverInputOf(
  VisualMap vm,
  int bx,
  int by, {
  required StreetCover cover,
  required int seed,
  required int window,
  required double amount,
  required double mpc,
  required Map<String, double> roadWidthM,
  double peak = 1,
  bool melting = false,
  double windX = 0,
  double windY = 0,
  double sunX = -0.7,
  double sunY = -0.7,
  int color = 0xFFFFFFFF,
  double alpha = 1,
  double Function((int, int, int) key)? wearOf,
}) {
  final x0 = bx * coverBlockCells.toDouble(), y0 = by * coverBlockCells.toDouble(), x1 = x0 + coverBlockCells, y1 = y0 + coverBlockCells;
  const m = 1.0; // uma célula de folga: a rua mais larga com calçada e banco
  final unit = vm.cellsPerTile / vm.pack.extent;
  final streets = <CoverStreet>[];
  final green = <List<double>>[], water = <List<double>>[];
  for (final (tx, ty) in vm.tilesIn(x0, y0, x1, y1, marginCells: m + 1)) {
    final tile = vm.tile(tx, ty);
    if (tile == null) continue;
    final ox = tx * vm.cellsPerTile.toDouble(), oy = ty * vm.cellsPerTile.toDouble();
    for (final (i, line) in tile.lines.indexed) {
      if (line.xy.length < 4) continue;
      var lx0 = double.infinity, ly0 = double.infinity, lx1 = -double.infinity, ly1 = -double.infinity;
      final xy = List<double>.filled(line.xy.length, 0);
      for (var k = 0; k + 1 < line.xy.length; k += 2) {
        final x = ox + line.xy[k] * unit, y = oy + line.xy[k + 1] * unit;
        xy[k] = x;
        xy[k + 1] = y;
        if (x < lx0) lx0 = x;
        if (x > lx1) lx1 = x;
        if (y < ly0) ly0 = y;
        if (y > ly1) ly1 = y;
      }
      if (lx1 < x0 - m || lx0 > x1 + m || ly1 < y0 - m || ly0 > y1 + m) continue;
      final key = (tx, ty, i);
      final level = cover.kind == StreetCoverKind.snow ? 1.0 : cover.level(seed, key, line.roadClass, window, amount);
      streets.add(CoverStreet(xy, (roadWidthM[line.roadClass.name] ?? 6) / 2, StreetCover.roadRank(line.roadClass), level: level, wear: wearOf?.call(key) ?? 0));
    }
    if (cover.kind != StreetCoverKind.snow) continue; // só a neve cai fora das ruas
    for (final a in tile.areas) {
      for (final ring in a.rings) {
        if (ring.length < 6) continue;
        // Só os anéis cujo retângulo toca o bloco.
        var rx0 = 1 << 30, ry0 = 1 << 30, rx1 = -(1 << 30), ry1 = -(1 << 30);
        for (var k = 0; k + 1 < ring.length; k += 2) {
          if (ring[k] < rx0) rx0 = ring[k];
          if (ring[k] > rx1) rx1 = ring[k];
          if (ring[k + 1] < ry0) ry0 = ring[k + 1];
          if (ring[k + 1] > ry1) ry1 = ring[k + 1];
        }
        if (ox + rx1 * unit < x0 || ox + rx0 * unit > x1 || oy + ry1 * unit < y0 || oy + ry0 * unit > y1) continue;
        (a.kind == AreaKind.green ? green : water).add([for (var k = 0; k + 1 < ring.length; k += 2) ...[ox + ring[k] * unit, oy + ring[k + 1] * unit]]);
      }
    }
  }
  return CoverInput(bx: bx, by: by, mpc: mpc, kind: cover.kind, amount: amount, seed: seed, streets: streets, green: green, water: water, peak: peak, melting: melting, windX: windX, windY: windY, sunX: sunX, sunY: sunY, color: color, alpha: alpha);
}
