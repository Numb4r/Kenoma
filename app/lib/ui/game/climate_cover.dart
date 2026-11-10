/// A cobertura das ruas e do chão (camada do mapa do clima): água nas ruas baixas, neve, dunas, gelo e fuligem, desenhadas
/// sobre as linhas e as áreas do pacote visual. Quanto de cada uma existe vem de [StreetCover.level] com a fase do clima
/// (`climate_form.dart`): nada aparece pronto. O canvas já está na câmera (células z21, gira e dá zoom com o mapa).
///
/// Neve: primeiro a grama, o chão e os telhados (tudo fora das ruas e da água: o pacote não tem prédios, então "telhado" é o
/// que sobra), em branco azulado com sombra e textura de pixel; as ruas por último, em neve suja com as trilhas do tráfego.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/fnv.dart';
import '../../data/visual_pack.dart';
import '../../world/climate_form.dart';
import '../../world/street_cover.dart';
import '../../world/visual_map.dart';
import 'climate_ground.dart' show PlacedMark;

ui.Color _c(int argb, double a) => ui.Color(argb).withValues(alpha: a.clamp(0.0, 1.0));

const int _snow = 0xFFE9EEF8, _snowShadow = 0xFFA9B5CF, _snowLight = 0xFFFFFFFF, _slush = 0xFFB9BECE, _slushTrack = 0xFF5E6478;
const int _sandLight = 0xFFF2DCA4, _sandShadow = 0xFFA9824E;

/// Uma rua à vista: tile, índice, a linha e os pontos já na câmera.
typedef _Street = (int tx, int ty, int i, VisualLine line, List<ui.Offset> pts);

class ClimateCover {
  ClimateCover({required this.visual, required this.roadWidthM});

  final VisualMap visual;
  final Map<String, double> roadWidthM;

  // Por tile (o mesmo objeto enquanto o tile fica no cache do pacote): o retângulo de cada linha e as áreas em caminho.
  final _boxes = Expando<Int32List>();
  final _green = Expando<ui.Path>();
  final _water = Expando<ui.Path>();

  final _stroke = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..isAntiAlias = false
    ..strokeCap = ui.StrokeCap.square
    ..strokeJoin = ui.StrokeJoin.miter;
  final _fill = ui.Paint()..isAntiAlias = false;

  Int32List _boxesOf(VisualTile tile) => _boxes[tile] ??= () {
        final out = Int32List(tile.lines.length * 4);
        for (final (i, l) in tile.lines.indexed) {
          var x0 = 1 << 30, y0 = 1 << 30, x1 = -(1 << 30), y1 = -(1 << 30);
          for (var k = 0; k + 1 < l.xy.length; k += 2) {
            x0 = math.min(x0, l.xy[k]);
            x1 = math.max(x1, l.xy[k]);
            y0 = math.min(y0, l.xy[k + 1]);
            y1 = math.max(y1, l.xy[k + 1]);
          }
          out.setAll(i * 4, [x0, y0, x1, y1]);
        }
        return out;
      }();

  ui.Path _areas(VisualTile tile, AreaKind kind) {
    final cache = kind == AreaKind.green ? _green : _water;
    return cache[tile] ??= () {
      final p = ui.Path()..fillType = ui.PathFillType.evenOdd;
      for (final a in tile.areas) {
        if (a.kind != kind) continue;
        for (final ring in a.rings) {
          if (ring.length < 6) continue;
          p.addPolygon([for (var k = 0; k + 1 < ring.length; k += 2) ui.Offset(ring[k].toDouble(), ring[k + 1].toDouble())], true);
        }
      }
      return p;
    }();
  }

  /// As ruas cujo retângulo cruza a tela (com folga). O corte pelas pontas e pelo meio deixava de fora a rua comprida que
  /// atravessa a tela com os vértices longe (a "uma avenida alagada só" da 0.17.0).
  List<_Street> _streets(double l, double top, double r, double b, ui.Offset Function(double, double) at) {
    final vm = visual;
    final unit = vm.cellsPerTile / vm.pack.extent;
    final out = <_Street>[];
    for (final (tx, ty) in vm.tilesIn(l, top, r, b, marginCells: 2)) {
      final tile = vm.tile(tx, ty);
      if (tile == null) continue;
      final x0 = tx * vm.cellsPerTile.toDouble(), y0 = ty * vm.cellsPerTile.toDouble();
      final ul = (l - 1 - x0) / unit, ut = (top - 1 - y0) / unit, ur = (r + 1 - x0) / unit, ub = (b + 1 - y0) / unit;
      final box = _boxesOf(tile);
      for (final (i, line) in tile.lines.indexed) {
        if (line.xy.length < 4) continue;
        if (box[i * 4] > ur || box[i * 4 + 2] < ul || box[i * 4 + 1] > ub || box[i * 4 + 3] < ut) continue;
        out.add((tx, ty, i, line, [for (var k = 0; k + 1 < line.xy.length; k += 2) at(x0 + line.xy[k] * unit, y0 + line.xy[k + 1] * unit)]));
      }
    }
    return out;
  }

  double _w(RoadClass c, double mpc) => (roadWidthM[c.name] ?? 6) / mpc;

  /// Desenha a cobertura [cover] com [amount] dela formada. [px] é um ponto de tela em células, [artPx] o pixel de arte.
  void paint(
    ui.Canvas canvas,
    StreetCover cover, {
    required int color,
    required double alpha,
    required int seed,
    required int window,
    required double amount,
    required double t,
    required double mpc,
    required double px,
    required double artPx,
    required double l,
    required double top,
    required double r,
    required double b,
    required double camX,
    required double camY,
    required ui.Offset Function(double, double) at,
    required List<PlacedMark> placed,
  }) {
    if (amount <= 0) return;
    final streets = _streets(l, top, r, b, at);
    final q = artPx * px;
    if (cover.kind == StreetCoverKind.snow) _snowGround(canvas, streets, amount, seed, q, mpc, l, top, r, b, camX, camY, at);
    for (final (tx, ty, i, line, pts0) in streets) {
      final lv = cover.level(seed, (tx, ty, i), line.roadClass, window, amount);
      if (lv <= 0) continue;
      final w = _w(line.roadClass, mpc);
      final key = (tx, ty, i);
      var pts = pts0;
      if (cover.kind == StreetCoverKind.sand) pts = spanOf(pts, cover.duneSpan(seed, key, window, lv));
      if (pts.length < 2) continue;
      final path = ui.Path()..addPolygon(pts, false);
      switch (cover.kind) {
        case StreetCoverKind.flood:
          // A água sobe: estreita e rala no começo, depois cobre a rua de borda a borda.
          canvas.drawPath(path, _stroke..strokeWidth = w * (0.6 + 0.55 * lv)..color = _c(color, alpha * (0.4 + 0.6 * lv)));
          canvas.drawPath(path, _stroke..strokeWidth = math.max(q, w * 0.18)..color = _c(0xFFE8E4F4, 0.16 * lv * (0.6 + 0.4 * math.sin(t * 1.5 + i))));
        case StreetCoverKind.snow:
          _snowStreet(canvas, path, pts, line.roadClass, lv, w, q, cover.tracks, seed, key);
        case StreetCoverKind.sand:
          _dune(canvas, path, pts, lv, w, q, color, alpha);
        case StreetCoverKind.ice:
          canvas.drawPath(path, _stroke..strokeWidth = w..color = _c(color, alpha * lv));
          _glints(canvas, pts, w, q, lv, t, seed, key, 0xFFFFFFFF);
        case StreetCoverKind.soot:
          canvas.drawPath(path, _stroke..strokeWidth = w * 1.2..color = _c(color, alpha * lv));
          _glints(canvas, pts, w, q, lv * 0.7, 0, seed, key, 0xFF1A1424);
      }
      final unit = visual.cellsPerTile / visual.pack.extent;
      placed.add((kind: 'street_${cover.kind.name}', x: tx * visual.cellsPerTile + line.xy[0] * unit, y: ty * visual.cellsPerTile + line.xy[1] * unit));
    }
  }

  /// A neve fora das ruas: a grama primeiro, depois o chão e os telhados; as ruas e a água ficam de fora, com uma sombra
  /// azulada na borda. Textura de pixel presa ao chão (células e hash).
  void _snowGround(ui.Canvas canvas, List<_Street> streets, double amount, int seed, double q, double mpc, double l, double top, double r, double b, double camX, double camY, ui.Offset Function(double, double) at) {
    final st = snowStages(amount);
    if (st.ground <= 0 && st.green <= 0) return;
    final rect = ui.Rect.fromPoints(at(l - 2, top - 2), at(r + 2, b + 2));
    canvas.saveLayer(rect, ui.Paint());
    canvas.drawRect(rect, _fill..color = _c(_snow, 0.8 * st.ground));
    final vm = visual, unit = vm.cellsPerTile / vm.pack.extent;
    for (final (tx, ty) in vm.tilesIn(l, top, r, b, marginCells: 2)) {
      final tile = vm.tile(tx, ty);
      if (tile == null || tile.areas.isEmpty) continue;
      canvas.save();
      canvas.translate(tx * vm.cellsPerTile - camX, ty * vm.cellsPerTile - camY);
      canvas.scale(unit);
      final green = _areas(tile, AreaKind.green);
      canvas.drawPath(green, _fill..color = _c(_snow, 0.85 * st.green * (1 - 0.8 * st.ground)));
      canvas.drawPath(_areas(tile, AreaKind.water), _fill..color = const ui.Color(0xFF000000)..blendMode = ui.BlendMode.dstOut);
      _fill.blendMode = ui.BlendMode.srcOver;
      canvas.restore();
    }
    // Textura: sombras e brilhos de pixel, mais densos quanto mais neve.
    final cover = math.max(st.ground, st.green);
    final cells = (b.ceil() - top.floor() + 2) * (r.ceil() - l.floor() + 2);
    final per = math.min(24.0, 1200 / math.max(1, cells)) * cover;
    for (var cy = top.floor() - 1; cy <= b.ceil(); cy++) {
      for (var cx = l.floor() - 1; cx <= r.ceil(); cx++) {
        final base = fnv1a64Of3(cx ^ seed, cy, 0x5A0);
        final n = per.round();
        for (var k = 0; k < n; k++) {
          final h = fnv1a64Of3(base, k, 7);
          final x = cx + ((h >>> 40) & 0xffff) / 65536, y = cy + ((h >>> 24) & 0xffff) / 65536;
          final o = at(x, y);
          final light = (h & 1) == 0;
          canvas.drawRect(ui.Rect.fromLTWH(o.dx, o.dy, q * (light ? 1 : 3), q), _fill..color = _c(light ? _snowLight : _snowShadow, (light ? 0.8 : 0.55) * cover));
        }
      }
    }
    // As ruas ficam de fora (a neve delas vem por último): a borda da neve faz sombra.
    for (final (_, _, _, line, pts) in streets) {
      final w = _w(line.roadClass, mpc);
      final path = ui.Path()..addPolygon(pts, false);
      canvas.drawPath(path, _stroke..strokeWidth = w + 2 * q..color = _c(_snowShadow, 0.7 * cover));
      canvas.drawPath(path, _stroke..strokeWidth = w..color = const ui.Color(0xFF000000)..blendMode = ui.BlendMode.dstOut);
      _stroke.blendMode = ui.BlendMode.srcOver;
    }
    canvas.restore();
  }

  /// Neve na rua: neve suja, mais escura onde o tráfego passa (duas trilhas nas avenidas, uma no meio das ruas locais).
  void _snowStreet(ui.Canvas canvas, ui.Path path, List<ui.Offset> pts, RoadClass cls, double lv, double w, double q, bool tracks, int seed, (int, int, int) key) {
    canvas.drawPath(path, _stroke..strokeWidth = w..color = _c(_slush, 0.9 * lv));
    canvas.drawPath(path, _stroke..strokeWidth = math.max(q, w * 0.12)..color = _c(_snow, 0.5 * lv)); // o monte no meio
    if (!tracks || cls == RoadClass.pedestrian) return;
    final avenue = cls == RoadClass.principal || cls == RoadClass.secondary;
    final tw = math.max(q, w * (avenue ? 0.16 : 0.12));
    for (final d in avenue ? const [-0.24, 0.24] : const [0.0]) {
      canvas.drawPath(ui.Path()..addPolygon(offsetPolyline(pts, d * w), false), _stroke..strokeWidth = tw..color = _c(_slushTrack, (avenue ? 0.75 : 0.45) * lv));
    }
  }

  /// A duna: borda que se mistura com a rua, crista com lado claro e lado sombreado, ondulações do vento.
  void _dune(ui.Canvas canvas, ui.Path path, List<ui.Offset> pts, double lv, double w, double q, int color, double alpha) {
    canvas.drawPath(path, _stroke..strokeWidth = w * 1.6..color = _c(color, alpha * 0.25 * lv)..strokeCap = ui.StrokeCap.round);
    canvas.drawPath(path, _stroke..strokeWidth = w * 1.3..color = _c(color, alpha * 0.55 * lv));
    canvas.drawPath(path, _stroke..strokeWidth = w * (0.5 + 0.5 * lv)..color = _c(color, alpha * lv));
    _stroke.strokeCap = ui.StrokeCap.square;
    canvas.drawPath(ui.Path()..addPolygon(offsetPolyline(pts, w * 0.22), false), _stroke..strokeWidth = w * 0.3..color = _c(_sandShadow, 0.5 * lv));
    canvas.drawPath(ui.Path()..addPolygon(offsetPolyline(pts, -w * 0.08), false), _stroke..strokeWidth = math.max(q, w * 0.1)..color = _c(_sandLight, 0.8 * lv));
    // Ondulações: riscos curtos de través, claro e sombra lado a lado, a cada ~2 m.
    _along(pts, w * 0.35, (o, tx, ty) {
      final nx = -ty, ny = tx, h = w * 0.35 * lv;
      canvas.drawLine(o - ui.Offset(nx, ny) * h, o + ui.Offset(nx, ny) * h, _stroke..strokeWidth = q..color = _c(_sandLight, 0.6 * lv));
      canvas.drawLine(o - ui.Offset(nx, ny) * h + ui.Offset(tx, ty) * q, o + ui.Offset(nx, ny) * h + ui.Offset(tx, ty) * q, _stroke..color = _c(_sandShadow, 0.5 * lv));
    });
  }

  /// Pontos que brilham (gelo) ou sujam (fuligem) ao longo da rua, em lugares presos a ela.
  void _glints(ui.Canvas canvas, List<ui.Offset> pts, double w, double q, double lv, double t, int seed, (int, int, int) key, int color) {
    var k = 0;
    _along(pts, w * 0.8, (o, tx, ty) {
      final h = fnv1a64Of3(seed ^ key.$1, key.$2 * 4096 + key.$3, k++);
      final side = (((h >>> 20) & 0xff) / 255 - 0.5) * w * 0.8;
      final a = t == 0 ? 0.6 : 0.5 + 0.5 * math.sin(t * 3 + (h & 0xff));
      canvas.drawRect(ui.Rect.fromCenter(center: o + ui.Offset(-ty, tx) * side, width: q, height: q), _fill..color = _c(color, a * lv));
    });
  }
}

/// Chama [f] a cada [step] (células) ao longo da polilinha, com a direção do trecho.
void _along(List<ui.Offset> pts, double step, void Function(ui.Offset o, double tx, double ty) f) {
  if (step <= 0) return;
  var carry = 0.0;
  for (var k = 1; k < pts.length; k++) {
    final d = pts[k] - pts[k - 1], len = d.distance;
    if (len <= 0) continue;
    final tx = d.dx / len, ty = d.dy / len;
    var s = carry;
    for (; s < len; s += step) {
      f(pts[k - 1] + d * (s / len), tx, ty);
    }
    carry = s - len;
  }
}

/// A polilinha deslocada [d] para a direita (pelo sentido dos pontos).
List<ui.Offset> offsetPolyline(List<ui.Offset> p, double d) {
  final n = p.length;
  return [
    for (var i = 0; i < n; i++)
      () {
        final v = p[math.min(i + 1, n - 1)] - p[math.max(i - 1, 0)];
        final len = v.distance;
        return len <= 0 ? p[i] : p[i] + ui.Offset(-v.dy / len, v.dx / len) * d;
      }(),
  ];
}

/// O trecho [span] (frações do comprimento) da polilinha.
List<ui.Offset> spanOf(List<ui.Offset> pts, (double, double) span) {
  var total = 0.0;
  for (var k = 1; k < pts.length; k++) {
    total += (pts[k] - pts[k - 1]).distance;
  }
  final a = span.$1 * total, b = span.$2 * total;
  final out = <ui.Offset>[];
  var s = 0.0;
  for (var k = 1; k < pts.length; k++) {
    final seg = (pts[k] - pts[k - 1]).distance;
    if (seg <= 0) continue;
    final s0 = s, s1 = s + seg;
    s = s1;
    if (s1 < a || s0 > b) continue;
    ui.Offset lerp(double v) => ui.Offset.lerp(pts[k - 1], pts[k], ((v - s0) / seg).clamp(0.0, 1.0))!;
    if (out.isEmpty) out.add(lerp(math.max(a, s0)));
    out.add(lerp(math.min(b, s1)));
  }
  return out;
}
