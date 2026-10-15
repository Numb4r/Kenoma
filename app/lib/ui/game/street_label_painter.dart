/// Desenha os nomes das ruas principais por cima do mapa: texto pequeno e discreto, rente à rua, que gira com o
/// mapa e nunca fica de cabeça para baixo. A escolha de onde pôr cada nome é de `world/street_labels.dart`.
library;

import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection;

import '../../world/map_camera.dart';
import '../../world/street_labels.dart';
import '../../world/visual_map.dart';
import '../colors.dart';

class StreetLabelPainter {
  StreetLabelPainter(this.visual, {this.cacheTiles = 96});

  final VisualMap visual;
  final int cacheTiles;

  final LinkedHashMap<(int, int), List<LabelSpot>> _spots = LinkedHashMap();
  final Map<String, (TextPainter, TextPainter)> _text = {};

  static const double _fontSize = 8;

  List<LabelSpot> _spotsOf(int tx, int ty) {
    final key = (tx, ty);
    final cached = _spots.remove(key);
    if (cached != null) {
      _spots[key] = cached;
      return cached;
    }
    final tile = visual.tile(tx, ty);
    final out = tile == null ? const <LabelSpot>[] : labelSpotsOfTile(tile, tx, ty, cellsPerTile: visual.cellsPerTile, extent: visual.pack.extent);
    _spots[key] = out;
    while (_spots.length > cacheTiles) {
      _spots.remove(_spots.keys.first);
    }
    return out;
  }

  (TextPainter, TextPainter) _painters(String name) => _text.putIfAbsent(name, () {
        final fill = TextPainter(
          text: TextSpan(text: name, style: TextStyle(fontFamily: 'Silkscreen', fontSize: _fontSize, color: kText.withValues(alpha: 0.82))),
          textDirection: TextDirection.ltr,
        )..layout();
        final outline = TextPainter(
          text: TextSpan(
            text: name,
            style: TextStyle(
              fontFamily: 'Silkscreen',
              fontSize: _fontSize,
              foreground: ui.Paint()
                ..style = ui.PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = kOutline.withValues(alpha: 0.85),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        return (fill, outline);
      });

  void paint(ui.Canvas canvas, ui.Size view, MapCamera cam) {
    if (visual.pack.version < 2) return; // pacote antigo: não tem nomes
    final (l, t, r, b) = cam.visibleBounds(view.width, view.height);
    final spots = <LabelSpot>[for (final id in visual.tilesIn(l, t, r, b, marginCells: 2)) ..._spotsOf(id.$1, id.$2)];
    if (spots.isEmpty) return;
    final placed = placeLabels(
      spots,
      project: (x, y) => cam.cellToScreen(x, y, view.width, view.height),
      textWidth: (n) => _painters(n).$1.width,
      pixelsPerCell: cam.pixelsPerCell,
      mapRotation: cam.rotation,
      viewWidth: view.width,
      viewHeight: view.height,
    );
    for (final p in placed) {
      final (fill, outline) = _painters(p.spot.name);
      canvas.save();
      canvas.translate(p.sx, p.sy);
      canvas.rotate(p.angle);
      final at = ui.Offset(-fill.width / 2, -fill.height / 2);
      outline.paint(canvas, at);
      fill.paint(canvas, at);
      canvas.restore();
    }
  }
}
