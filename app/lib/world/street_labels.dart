/// Onde pôr o nome de cada rua principal: o trecho mais reto e mais longo de cada linha com nome, em coordenadas
/// de célula z21, e a escolha dos rótulos que cabem na tela sem se sobrepor. Dart puro; o desenho do texto é de
/// quem chama. Só desenho: nada aqui decide o que existe no jogo.
library;

import 'dart:math' as math;

import '../data/visual_pack.dart';

class LabelSpot {
  const LabelSpot({required this.name, required this.x, required this.y, required this.angle, required this.lengthCells});

  final String name;

  /// O meio do trecho, em células z21 fracionárias.
  final double x;
  final double y;

  /// Direção do trecho no mundo, em radianos, com x para leste e y para o sul (sentido horário na tela).
  final double angle;

  /// Comprimento do trecho, em células z21.
  final double lengthCells;
}

/// O trecho mais reto e mais longo de [pts] (`x0, y0, x1, y1, ...` em unidades do tile): segue enquanto a direção
/// não se desvia mais de [maxTurn] radianos da direção do começo do trecho. Devolve `(início, fim)` em índices de
/// ponto e o comprimento em unidades, ou `null` se a linha tem menos de 2 pontos.
({int from, int to, double length})? straightestRun(List<int> pts, {double maxTurn = 0.35}) {
  final n = pts.length ~/ 2;
  if (n < 2) return null;
  ({int from, int to, double length})? best;
  var i = 0;
  while (i < n - 1) {
    final dir = math.atan2((pts[2 * i + 3] - pts[2 * i + 1]).toDouble(), (pts[2 * i + 2] - pts[2 * i]).toDouble());
    var j = i, len = 0.0;
    while (j < n - 1) {
      final dx = (pts[2 * j + 2] - pts[2 * j]).toDouble(), dy = (pts[2 * j + 3] - pts[2 * j + 1]).toDouble();
      var turn = (math.atan2(dy, dx) - dir).abs();
      if (turn > math.pi) turn = 2 * math.pi - turn;
      if (turn > maxTurn) break;
      len += math.sqrt(dx * dx + dy * dy);
      j++;
    }
    if (j == i) j = i + 1; // um segmento sempre cabe (a primeira direção é a dele mesmo)
    if (best == null || len > best.length) best = (from: i, to: j, length: len);
    i = j;
  }
  return best;
}

/// Os pontos de rótulo de um tile: um por linha com nome, no trecho mais reto, e no máximo [perName] por nome
/// (os mais longos). [cellsPerTile] e [extent] convertem as unidades do tile em células z21.
List<LabelSpot> labelSpotsOfTile(VisualTile tile, int tx, int ty, {required int cellsPerTile, required int extent, int perName = 2, double minCells = 0.5}) {
  final unit = cellsPerTile / extent;
  final byName = <String, List<LabelSpot>>{};
  for (final line in tile.lines) {
    final name = line.name;
    if (name == null) continue;
    final run = straightestRun(line.xy);
    if (run == null) continue;
    final len = run.length * unit;
    if (len < minCells) continue;
    final a = run.from, b = run.to;
    final x0 = line.xy[2 * a].toDouble(), y0 = line.xy[2 * a + 1].toDouble();
    final x1 = line.xy[2 * b].toDouble(), y1 = line.xy[2 * b + 1].toDouble();
    byName.putIfAbsent(name, () => []).add(LabelSpot(
      name: name,
      x: tx * cellsPerTile + (x0 + x1) / 2 * unit,
      y: ty * cellsPerTile + (y0 + y1) / 2 * unit,
      angle: math.atan2(y1 - y0, x1 - x0),
      lengthCells: len,
    ));
  }
  return [
    for (final spots in byName.values) ...(spots..sort((p, q) => q.lengthCells.compareTo(p.lengthCells))).take(perName),
  ];
}

/// O ângulo do texto na tela: o do trecho mais a rotação do mapa, virado para o texto nunca ficar de cabeça
/// para baixo (dentro de -90° a 90°).
double labelScreenAngle(double worldAngle, double mapRotation) {
  var a = worldAngle + mapRotation;
  a = math.atan2(math.sin(a), math.cos(a));
  if (a > math.pi / 2) a -= math.pi;
  if (a < -math.pi / 2) a += math.pi;
  return a;
}

class PlacedLabel {
  const PlacedLabel(this.spot, this.sx, this.sy, this.angle);

  final LabelSpot spot;
  final double sx;
  final double sy;
  final double angle;
}

/// Escolhe os rótulos da tela: só os que cabem no trecho (largura do texto + [pad] menor que o comprimento em
/// pixels), sem se sobrepor (círculos de meia largura) e com [sameNameGap] pixels entre dois do mesmo nome, no
/// máximo [max]. A ordem é fixa (os trechos mais longos primeiro, desempate por posição), então os rótulos não
/// pulam de um quadro para o outro. [project] leva uma célula z21 para a tela; [textWidth] mede o texto.
List<PlacedLabel> placeLabels(
  Iterable<LabelSpot> spots, {
  required (double, double) Function(double x, double y) project,
  required double Function(String name) textWidth,
  required double pixelsPerCell,
  required double mapRotation,
  required double viewWidth,
  required double viewHeight,
  double pad = 12,
  double sameNameGap = 140,
  int max = 40,
}) {
  final ordered = [...spots]..sort((p, q) {
      final c = q.lengthCells.compareTo(p.lengthCells);
      if (c != 0) return c;
      final cx = p.x.compareTo(q.x);
      return cx != 0 ? cx : p.y.compareTo(q.y);
    });
  final placed = <PlacedLabel>[];
  final radii = <double>[];
  for (final s in ordered) {
    if (placed.length >= max) break;
    final w = textWidth(s.name);
    if (w + pad > s.lengthCells * pixelsPerCell) continue;
    final (sx, sy) = project(s.x, s.y);
    if (sx < -w || sy < -w || sx > viewWidth + w || sy > viewHeight + w) continue;
    final r = w / 2;
    var clash = false;
    for (var i = 0; i < placed.length && !clash; i++) {
      final o = placed[i];
      final d = math.sqrt((o.sx - sx) * (o.sx - sx) + (o.sy - sy) * (o.sy - sy));
      if (d < (r + radii[i]) * 0.85) clash = true;
      if (o.spot.name == s.name && d < sameNameGap) clash = true;
    }
    if (clash) continue;
    placed.add(PlacedLabel(s, sx, sy, labelScreenAngle(s.angle, mapRotation)));
    radii.add(r);
  }
  return placed;
}
