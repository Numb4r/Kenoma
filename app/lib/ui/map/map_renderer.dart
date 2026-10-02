/// Desenho do mapa: a grade z21 em tiles com a cor e a textura de cada bioma. Só desenha o que a
/// câmera mostra, com cache por chunk de 64 x 64 células e nível de detalhe que cai com o zoom.
/// Nenhuma regra do jogo mora aqui: o bioma vem de `RegionMap`, as células visíveis de `MapCamera`.
library;

import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../world/chunks.dart';
import '../../world/map_camera.dart';
import '../../world/map_probe.dart';
import '../../world/region_map.dart';
import '../colors.dart';
import 'biome_textures.dart';

typedef _Key = (int lod, int cx, int cy);

class MapRenderer {
  MapRenderer({required this.map, required this.atlas, this.budgetBytes = 96 << 20})
      : _voidColor = ui.Color(0xFF000000 | map.biomes.byId(voidBiomeId).palette[1]),
        _packCells = CellRange(map.pack.x0, map.pack.y0, map.pack.x0 + map.pack.width - 1, map.pack.y0 + map.pack.height - 1);

  final RegionMap map;

  /// O atlas de `buildBiomeAtlas`.
  final ui.Image atlas;

  /// Memória máxima das imagens de chunk guardadas.
  final int budgetBytes;
  final ui.Color _voidColor;
  final CellRange _packCells;

  /// Chunks montados, do menos para o mais recentemente usado. Chunk fora do pacote não entra: é o Vazio liso.
  final LinkedHashMap<_Key, ui.Image> _cache = LinkedHashMap();
  int _bytes = 0;

  /// Células z21 que o pacote cobre. O centro da câmera fica dentro delas.
  CellRange get packCells => _packCells;

  int get cachedChunks => _cache.length;
  int get cachedBytes => _bytes;

  /// Quantos chunks novos foram montados no último `paint`.
  int lastBuilds = 0;

  /// Desenha o mapa em [canvas], numa tela de [size]. Monta no máximo [maxBuilds] chunks por quadro
  /// (os que faltam aparecem como Vazio e entram nos quadros seguintes).
  void paint(
    ui.Canvas canvas,
    ui.Size size, {
    required MapCamera camera,
    bool grid20 = false,
    MapProbe? probe,
    int maxBuilds = 8,
  }) {
    lastBuilds = 0;
    canvas.drawRect(ui.Offset.zero & size, ui.Paint()..color = _voidColor);
    final w = size.width, h = size.height;
    final range = camera.visibleRange(w, h);
    final lod = lodFor(camera.pixelsPerCell);
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.none
      ..isAntiAlias = false;
    for (final id in chunksIn(range)) {
      final cells = cellsOfChunk(id);
      if (cells.intersect(_packCells).isEmpty) continue; // fora do pacote é Vazio, já pintado
      final key = (lod, id.$1, id.$2);
      var image = _touch(key);
      if (image == null) {
        if (lastBuilds >= maxBuilds) continue;
        image = _build(key, id);
        lastBuilds++;
      }
      final (l, t) = camera.cellToScreen(cells.x0.toDouble(), cells.y0.toDouble(), w, h);
      final (r, b) = camera.cellToScreen(cells.x1 + 1.0, cells.y1 + 1.0, w, h);
      // Bordas inteiras em pixels de tela: dois chunks vizinhos dividem a mesma borda e não deixam fresta.
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTRB(l.floorToDouble(), t.floorToDouble(), r.floorToDouble(), b.floorToDouble()),
        paint,
      );
    }
    if (grid20) _grid20(canvas, camera, size, range);
    if (probe != null) _probe(canvas, camera, size, probe);
    _crosshair(canvas, size);
  }

  /// Marca o chunk como o mais recente. Devolve a imagem, ou `null` se não está no cache.
  ui.Image? _touch(_Key key) {
    final image = _cache.remove(key);
    if (image != null) _cache[key] = image;
    return image;
  }

  ui.Image _build(_Key key, ChunkId id) {
    final lod = key.$1;
    final cells = cellsOfChunk(id);
    const n = chunkCells;
    final transforms = Float32List(n * n * 4);
    final rects = Float32List(n * n * 4);
    final scale = lod / tileSize;
    var k = 0;
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        final x = cells.x0 + i, y = cells.y0 + j;
        final biome = map.biomeAtCell(x, y);
        final v = cellVariant(x, y);
        transforms[k] = scale;
        transforms[k + 1] = 0;
        transforms[k + 2] = (i * lod).toDouble();
        transforms[k + 3] = (j * lod).toDouble();
        rects[k] = (v * tileSize).toDouble();
        rects[k + 1] = (biome * tileSize).toDouble();
        rects[k + 2] = ((v + 1) * tileSize).toDouble();
        rects[k + 3] = ((biome + 1) * tileSize).toDouble();
        k += 4;
      }
    }
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRawAtlas(
      atlas,
      transforms,
      rects,
      null,
      null,
      null,
      ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..isAntiAlias = false,
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(n * lod, n * lod);
    picture.dispose();
    _cache[key] = image;
    _bytes += n * lod * n * lod * 4;
    _evict();
    return image;
  }

  void _evict() {
    while (_bytes > budgetBytes && _cache.length > 1) {
      final image = _cache.remove(_cache.keys.first)!;
      _bytes -= image.width * image.height * 4;
      image.dispose();
    }
  }

  /// Grade das células de spawn (z20): uma linha a cada duas células z21. Some quando as linhas ficam
  /// coladas demais para ler.
  void _grid20(ui.Canvas canvas, MapCamera camera, ui.Size size, CellRange range) {
    if (camera.pixelsPerCell < 4) return;
    final path = ui.Path();
    for (var x = range.x0 + (range.x0 & 1); x <= range.x1 + 1; x += 2) {
      final (sx, _) = camera.cellToScreen(x.toDouble(), 0, size.width, size.height);
      final px = sx.roundToDouble() + 0.5;
      path.moveTo(px, 0);
      path.lineTo(px, size.height);
    }
    for (var y = range.y0 + (range.y0 & 1); y <= range.y1 + 1; y += 2) {
      final (_, sy) = camera.cellToScreen(0, y.toDouble(), size.width, size.height);
      final py = sy.roundToDouble() + 0.5;
      path.moveTo(0, py);
      path.lineTo(size.width, py);
    }
    canvas.drawPath(
      path,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1
        ..isAntiAlias = false
        ..color = kText.withValues(alpha: 0.28),
    );
  }

  /// Contorno da célula z21 e da z20 sob o dedo.
  void _probe(ui.Canvas canvas, MapCamera camera, ui.Size size, MapProbe p) {
    ui.Rect cell(int x, int y, int side) {
      final (l, t) = camera.cellToScreen(x.toDouble(), y.toDouble(), size.width, size.height);
      final (r, b) = camera.cellToScreen(x + side.toDouble(), y + side.toDouble(), size.width, size.height);
      return ui.Rect.fromLTRB(l, t, r, b);
    }

    ui.Paint line(ui.Color c, double w) => ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = w
      ..isAntiAlias = false
      ..color = c;
    canvas.drawRect(cell(p.x20 * 2, p.y20 * 2, 2), line(kVeil, 2));
    canvas.drawRect(cell(p.x21, p.y21, 1), line(kText, 1));
  }

  /// Mira pequena no centro da câmera.
  void _crosshair(ui.Canvas canvas, ui.Size size) {
    final c = ui.Offset((size.width / 2).roundToDouble(), (size.height / 2).roundToDouble());
    final p = ui.Paint()
      ..strokeWidth = 2
      ..isAntiAlias = false
      ..color = kSignal;
    canvas.drawLine(c.translate(-8, 0), c.translate(8, 0), p);
    canvas.drawLine(c.translate(0, -8), c.translate(0, 8), p);
  }

  void dispose() {
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
    _bytes = 0;
  }
}
