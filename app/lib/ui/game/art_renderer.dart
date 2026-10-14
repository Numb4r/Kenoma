/// O mapa do jogo em pixels de arte: o mundo é desenhado em chunks de baixa resolução, em que cada pixel
/// tem um tamanho fixo em metros, e ampliado por vizinho mais próximo. No zoom padrão a ampliação é
/// inteira (em pixels físicos); nos outros zooms o mesmo desenho só cresce ou encolhe.
///
/// Camadas, de baixo para cima: chão neutro com ruído; áreas verdes e água, com borda de 1 pixel de arte;
/// calçada; rua. A Aura, as Fagulhas, os Ecos e o Conjurador são desenhados por quem chama, por cima.
/// Só desenho: a grade de biomas continua sendo a única camada lógica.
library;

import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/fnv.dart';
import '../../core/pcg32.dart';
import '../../data/visual_pack.dart';
import '../../world/map_balance.dart';
import '../../world/map_camera.dart';
import '../../world/visual_map.dart';
import 'art_style.dart';

/// Lado de um chunk, em pixels de arte.
const int chunkArtPx = 128;

/// Quantos pixels de arte cada 100 do chão levam de ruído escuro e claro (porcentagem).
const int _noiseDarkPct = 7;
const int _noiseLightPct = 5;

class ArtRenderer {
  ArtRenderer({
    required this.visual,
    required this.style,
    required this.balance,
    required this.artCells,
    required this.metersPerArtPx,
    this.budgetBytes = 48 << 20,
  });

  final VisualMap visual;
  final ArtStyle style;
  final MapBalance balance;

  /// Células z21 por pixel de arte: o tamanho fixo do pixel de arte em metros, na escala das células.
  final double artCells;

  /// O mesmo tamanho em metros: a largura das ruas vem em metros.
  final double metersPerArtPx;
  final int budgetBytes;

  final LinkedHashMap<(int, int), ui.Image> _cache = LinkedHashMap();
  int _bytes = 0;

  /// Quantos chunks novos o último `paint` montou.
  int lastBuilds = 0;

  int get cachedChunks => _cache.length;

  /// Lado de um chunk em células z21.
  double get chunkCells => chunkArtPx * artCells;

  /// Os chunks `(cx, cy)` que a câmera mostra numa tela de [size].
  List<(int, int)> chunksIn(MapCamera camera, ui.Size size) {
    final (left, top) = camera.screenToCell(0, 0, size.width, size.height);
    final (right, bottom) = camera.screenToCell(size.width, size.height, size.width, size.height);
    return [
      for (var cy = (top / chunkCells).floor(); cy <= (bottom / chunkCells).floor(); cy++)
        for (var cx = (left / chunkCells).floor(); cx <= (right / chunkCells).floor(); cx++) (cx, cy),
    ];
  }

  /// Desenha o mundo em [canvas]. Monta no máximo [maxBuilds] chunks por quadro; os que faltam aparecem
  /// como chão liso e entram nos quadros seguintes. [dpr] alinha as bordas dos chunks aos pixels físicos.
  void paint(ui.Canvas canvas, ui.Size size, MapCamera camera, {double dpr = 1, int maxBuilds = 2}) {
    lastBuilds = 0;
    canvas.drawRect(ui.Offset.zero & size, ui.Paint()..color = style.ground.base);
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.none
      ..isAntiAlias = false;
    double snap(double v) => (v * dpr).floorToDouble() / dpr;
    for (final id in chunksIn(camera, size)) {
      var image = _touch(id);
      if (image == null) {
        if (lastBuilds >= maxBuilds) continue;
        image = _build(id);
        lastBuilds++;
      }
      final (l, t) = camera.cellToScreen(id.$1 * chunkCells, id.$2 * chunkCells, size.width, size.height);
      final (r, b) = camera.cellToScreen((id.$1 + 1) * chunkCells, (id.$2 + 1) * chunkCells, size.width, size.height);
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTRB(snap(l), snap(t), snap(r), snap(b)),
        paint,
      );
    }
  }

  ui.Image? _touch((int, int) id) {
    final image = _cache.remove(id);
    if (image != null) _cache[id] = image;
    return image;
  }

  /// Monta o chunk [id]: chão e ruído, áreas verdes, água, calçadas e ruas, na ordem.
  ui.Image _build((int, int) id) {
    final (cx, cy) = id;
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    final rng = Pcg32(fnv1a64([cx, cy, 0x4152545F]), saltKenoma); // ARTN: ruído do chunk, sempre o mesmo
    _noise(canvas, rng, style.ground);

    final ox = cx * chunkArtPx, oy = cy * chunkArtPx;
    final tiles = visual.tilesIn(cx * chunkCells, cy * chunkCells, (cx + 1) * chunkCells, (cy + 1) * chunkCells);
    final loaded = [
      for (final t in tiles)
        if (visual.tile(t.$1, t.$2) case final tile?) (t.$1, t.$2, tile),
    ];
    // Unidades do tile -> pixels de arte do chunk.
    final perUnit = visual.cellsPerTile / artCells / visual.pack.extent;
    ui.Offset at(int tx, int ty, int ux, int uy) =>
        ui.Offset(tx * visual.cellsPerTile / artCells - ox + ux * perUnit, ty * visual.cellsPerTile / artCells - oy + uy * perUnit);

    for (final kind in [AreaKind.green, AreaKind.water]) {
      final mat = kind == AreaKind.green ? style.green : style.water;
      for (final (tx, ty, tile) in loaded) {
        for (final area in tile.areas) {
          if (area.kind != kind) continue;
          final path = ui.Path()..fillType = ui.PathFillType.evenOdd;
          for (final ring in area.rings) {
            final pts = <ui.Offset>[for (var i = 0; i < ring.length; i += 2) at(tx, ty, ring[i], ring[i + 1])];
            path.addPolygon(pts, true);
          }
          canvas.drawPath(path, ui.Paint()..color = mat.base..isAntiAlias = false);
          canvas.save();
          canvas.clipPath(path, doAntiAlias: false);
          _noise(canvas, rng, mat, fillBase: false);
          canvas.restore();
          canvas.drawPath(
            path,
            ui.Paint()
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = 1
              ..strokeJoin = ui.StrokeJoin.miter
              ..color = mat.edge
              ..isAntiAlias = false,
          );
        }
      }
    }

    // Ruas: primeiro todas as calçadas, depois o asfalto, do mais estreito para o mais largo.
    for (final withSidewalk in [true, false]) {
      for (final cls in RoadClass.values.reversed) {
        final widthArt = (balance.roadWidthM[_roadKey(cls)] ?? 0) / metersPerArtPx;
        if (widthArt <= 0) continue;
        final w = withSidewalk ? widthArt + 2 * balance.sidewalkArtPx : widthArt;
        if (withSidewalk && cls == RoadClass.pedestrian) continue; // trilha de pedestre: sem calçada
        final paint = ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = w < 1 ? 1 : w
          ..strokeCap = ui.StrokeCap.butt
          ..strokeJoin = ui.StrokeJoin.round
          ..color = withSidewalk ? style.sidewalk : (cls == RoadClass.pedestrian ? style.sidewalk : style.asphalt)
          ..isAntiAlias = false;
        final path = ui.Path();
        for (final (tx, ty, tile) in loaded) {
          for (final line in tile.lines) {
            if (line.roadClass != cls) continue;
            final xy = line.xy;
            path.moveTo(at(tx, ty, xy[0], xy[1]).dx, at(tx, ty, xy[0], xy[1]).dy);
            for (var i = 2; i < xy.length; i += 2) {
              final p = at(tx, ty, xy[i], xy[i + 1]);
              path.lineTo(p.dx, p.dy);
            }
          }
        }
        canvas.drawPath(path, paint);
      }
    }

    final image = rec.endRecording().toImageSync(chunkArtPx, chunkArtPx);
    _cache[id] = image;
    _bytes += chunkArtPx * chunkArtPx * 4;
    while (_bytes > budgetBytes && _cache.length > 1) {
      final old = _cache.remove(_cache.keys.first)!;
      _bytes -= old.width * old.height * 4;
      old.dispose();
    }
    return image;
  }

  static String _roadKey(RoadClass c) => switch (c) {
        RoadClass.principal => 'principal',
        RoadClass.secondary => 'secondary',
        RoadClass.local => 'local',
        RoadClass.pedestrian => 'pedestrian',
      };

  /// Ruído do material: pixels de arte escuros e claros espalhados. Sorteia posições, em vez de olhar
  /// os 16 mil pixels do chunk, e usa o mesmo gerador do chunk, então o desenho é sempre o mesmo.
  void _noise(ui.Canvas canvas, Pcg32 rng, Material3 mat, {bool fillBase = true}) {
    if (fillBase) {
      canvas.drawRect(ui.Rect.fromLTWH(0, 0, chunkArtPx.toDouble(), chunkArtPx.toDouble()), ui.Paint()..color = mat.base..isAntiAlias = false);
    }
    void specks(int pct, ui.Color color) {
      final n = chunkArtPx * chunkArtPx * pct ~/ 100;
      final pts = Float32List(n * 2);
      for (var i = 0; i < n; i++) {
        pts[2 * i] = rng.nextInt(chunkArtPx) + 0.5;
        pts[2 * i + 1] = rng.nextInt(chunkArtPx) + 0.5;
      }
      canvas.drawRawPoints(
        ui.PointMode.points,
        pts,
        ui.Paint()
          ..strokeWidth = 1
          ..strokeCap = ui.StrokeCap.square
          ..color = color
          ..isAntiAlias = false,
      );
    }

    specks(_noiseDarkPct, mat.dark);
    specks(_noiseLightPct, mat.light);
  }

  void dispose() {
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
    _bytes = 0;
  }
}
