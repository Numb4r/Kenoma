/// A cobertura das ruas e do chão (camada do mapa do clima): água nas ruas baixas, neve, dunas, gelo e fuligem, desenhadas
/// sobre as linhas e as áreas do pacote visual. Quanto de cada uma existe vem de [StreetCover.level] com a fase do clima
/// (`climate_form.dart`): nada aparece pronto. O canvas já está na câmera (células z21, gira e dá zoom com o mapa).
///
/// A cobertura acompanha a geometria da rua (largura e curvas), nunca a grade de células: pontas e esquinas redondas, e a
/// borda se mistura com o chão por um degradê curto (três degraus) e por pontilhado em pixel ([_ribbon]).
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
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;
  final _fill = ui.Paint()..isAntiAlias = false;
  final _dots = ui.Paint()
    ..isAntiAlias = false
    ..strokeCap = ui.StrokeCap.square;

  /// Acima disto de ruas na tela (zoom muito aberto), a borda fica só com o degradê: o pontilhado nem se veria.
  static const int ditherMaxStreets = 220;

  /// A faixa de cobertura ao longo da rua: três degraus de largura (o degradê curto da borda) e, se [dither], pixels
  /// soltos em volta da borda e das pontas, em lugares presos à rua ([h]). Com [blend] `dstOut`, recorta em vez de pintar.
  void _ribbon(ui.Canvas canvas, ui.Path path, List<ui.Offset> pts, double w, double q, int color, double alpha, int h, {bool dither = true, ui.BlendMode blend = ui.BlendMode.srcOver}) {
    if (alpha <= 0 || w <= 0) return;
    _stroke.blendMode = blend;
    // Somados no miolo, os três degraus dão perto de [alpha].
    canvas.drawPath(path, _stroke..strokeWidth = w + 2 * q..color = _c(color, alpha * 0.3));
    canvas.drawPath(path, _stroke..strokeWidth = w..color = _c(color, alpha * 0.45));
    canvas.drawPath(path, _stroke..strokeWidth = math.max(q, w - 2 * q)..color = _c(color, alpha * 0.6));
    _stroke.blendMode = ui.BlendMode.srcOver;
    if (!dither) return;
    final dots = edgeDither(pts, w, q, h);
    if (dots.isEmpty) return;
    canvas.drawRawPoints(ui.PointMode.points, dots, _dots..strokeWidth = q..color = _c(color, alpha * 0.55)..blendMode = blend);
    _dots.blendMode = ui.BlendMode.srcOver;
  }

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
    final dither = streets.length <= ditherMaxStreets;
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
          _ribbon(canvas, path, pts, w * (0.6 + 0.55 * lv), q, color, alpha * (0.4 + 0.6 * lv), _h(seed, key), dither: dither);
          canvas.drawPath(path, _stroke..strokeWidth = math.max(q, w * 0.18)..color = _c(0xFFE8E4F4, 0.16 * lv * (0.6 + 0.4 * math.sin(t * 1.5 + i))));
        case StreetCoverKind.snow:
          _snowStreet(canvas, path, pts, line.roadClass, lv, w, q, cover.tracks, seed, key, dither);
        case StreetCoverKind.sand:
          _dune(canvas, pts, lv, w, q, color, alpha, _h(seed, key));
        case StreetCoverKind.ice:
          _ribbon(canvas, path, pts, w, q, color, alpha * lv, _h(seed, key), dither: dither);
          _glints(canvas, pts, w, q, lv, t, seed, key, 0xFFFFFFFF);
        case StreetCoverKind.soot:
          _ribbon(canvas, path, pts, w * 1.2, q, color, alpha * lv, _h(seed, key), dither: dither);
          _glints(canvas, pts, w, q, lv * 0.7, 0, seed, key, 0xFF1A1424);
      }
      final unit = visual.cellsPerTile / visual.pack.extent;
      placed.add((kind: 'street_${cover.kind.name}', x: tx * visual.cellsPerTile + line.xy[0] * unit, y: ty * visual.cellsPerTile + line.xy[1] * unit));
    }
  }

  static int _h(int seed, (int, int, int) key) => fnv1a64Of3(seed ^ key.$1, key.$2, key.$3);

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
        // Um monte de neve por célula: uma sombra azulada larga, em degraus de pixel, com o lado de cima claro.
        final dh = fnv1a64Of3(base, 99, 1);
        final dx = cx + ((dh >>> 40) & 0xffff) / 65536, dy = cy + ((dh >>> 24) & 0xffff) / 65536;
        if ((dh & 7) < 3) continue; // nem toda célula tem monte: sem grade aparente
        final len = (2.5 + ((dh >>> 8) & 0xff) / 40) / mpc, wid = len * (0.22 + ((dh >>> 16) & 0xff) / 900);
        final d0 = at(dx, dy);
        for (var k = -len; k <= len; k += q) {
          final hw = (wid * math.sqrt(math.max(0, 1 - (k / len) * (k / len))) / q).floor() * q;
          if (hw <= 0) continue;
          canvas.drawRect(ui.Rect.fromLTRB(d0.dx + k, d0.dy, d0.dx + k + q, d0.dy + hw), _fill..color = _c(_snowShadow, 0.22 * cover));
          canvas.drawRect(ui.Rect.fromLTRB(d0.dx + k, d0.dy - hw * 0.6, d0.dx + k + q, d0.dy), _fill..color = _c(_snowLight, 0.3 * cover));
        }
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
    // O recorte segue a rua (pontas e esquinas redondas) e a borda se desfaz em degraus e pontilhado.
    final dither = streets.length <= ditherMaxStreets;
    for (final (tx, ty, i, line, pts) in streets) {
      final w = _w(line.roadClass, mpc);
      final path = ui.Path()..addPolygon(pts, false);
      canvas.drawPath(path, _stroke..strokeWidth = w + 4 * q..color = _c(_snowShadow, 0.35 * cover));
      _ribbon(canvas, path, pts, w, q, 0xFF000000, 1, _h(seed, (tx, ty, i)) ^ 0x5A0, dither: dither, blend: ui.BlendMode.dstOut);
      canvas.drawPath(path, _stroke..strokeWidth = math.max(q, w - 2 * q)..color = const ui.Color(0xFF000000)..blendMode = ui.BlendMode.dstOut);
      _stroke.blendMode = ui.BlendMode.srcOver;
    }
    canvas.restore();
  }

  /// Neve na rua: neve suja, mais escura onde o tráfego passa (duas trilhas nas avenidas, uma no meio das ruas locais).
  void _snowStreet(ui.Canvas canvas, ui.Path path, List<ui.Offset> pts, RoadClass cls, double lv, double w, double q, bool tracks, int seed, (int, int, int) key, bool dither) {
    _ribbon(canvas, path, pts, w, q, _slush, 0.9 * lv, _h(seed, key), dither: dither);
    canvas.drawPath(path, _stroke..strokeWidth = math.max(q, w * 0.12)..color = _c(_snow, 0.5 * lv)); // o monte no meio
    if (!tracks || cls == RoadClass.pedestrian) return;
    final avenue = cls == RoadClass.principal || cls == RoadClass.secondary;
    final tw = math.max(q, w * (avenue ? 0.16 : 0.12));
    for (final d in avenue ? const [-0.24, 0.24] : const [0.0]) {
      canvas.drawPath(ui.Path()..addPolygon(offsetPolyline(pts, d * w), false), _stroke..strokeWidth = tw..color = _c(_slushTrack, (avenue ? 0.75 : 0.45) * lv));
    }
  }

  /// A duna: um monte comprido que afina nas pontas, com a borda ondulada pelo hash [h] (cada duna com a sua forma), franja
  /// que se mistura com a rua, crista com lado claro e lado sombreado e ondulações do vento.
  void _dune(ui.Canvas canvas, List<ui.Offset> pts, double lv, double w, double q, int color, double alpha, int h) {
    final shape = duneOutline(pts, w, lv, h, step: math.max(q, w * 0.25));
    if (shape.left.length < 2) return;
    ui.Path poly(double k) => ui.Path()
      ..addPolygon([
        for (final (i, p) in shape.mid.indexed) p + (shape.left[i] - p) * k,
        for (var i = shape.mid.length - 1; i >= 0; i--) shape.mid[i] + (shape.right[i] - shape.mid[i]) * k,
      ], true);
    canvas.drawPath(poly(1.3), _fill..color = _c(color, alpha * 0.25 * lv));
    canvas.drawPath(poly(1.12), _fill..color = _c(color, alpha * 0.4 * lv));
    canvas.drawPath(poly(1), _fill..color = _c(color, alpha * lv));
    final dots = Float32List(shape.mid.length * 4);
    for (final (i, p) in shape.mid.indexed) {
      final u = 1.2 + ((fnv1a64Of3(h, i, 0xD07) >>> 32) & 0xff) / 255 * 0.5;
      final a = p + (shape.left[i] - p) * u, b = p + (shape.right[i] - p) * u;
      dots.setAll(i * 4, [a.dx, a.dy, b.dx, b.dy]);
    }
    canvas.drawRawPoints(ui.PointMode.points, dots, _dots..strokeWidth = q..color = _c(color, alpha * 0.6 * lv));
    // A crista (claro) e o lado da sombra, seguindo o contorno.
    canvas.drawPath(ui.Path()..addPolygon([for (final (i, p) in shape.mid.indexed) p + (shape.right[i] - p) * 0.55], false), _stroke..strokeWidth = math.max(q, w * 0.22)..color = _c(_sandShadow, 0.5 * lv));
    canvas.drawPath(ui.Path()..addPolygon([for (final (i, p) in shape.mid.indexed) p + (shape.left[i] - p) * 0.15], false), _stroke..strokeWidth = math.max(q, w * 0.1)..color = _c(_sandLight, 0.8 * lv));
    // Ondulações: riscos curtos de través, claro e sombra lado a lado, do tamanho da duna naquele ponto.
    for (var i = 2; i + 2 < shape.mid.length; i += 3) {
      final a = shape.mid[i] + (shape.left[i] - shape.mid[i]) * 0.6, b = shape.mid[i] + (shape.right[i] - shape.mid[i]) * 0.6;
      final d = shape.mid[i + 1] - shape.mid[i], len = d.distance;
      if (len <= 0) continue;
      canvas.drawLine(a, b, _stroke..strokeWidth = q..color = _c(_sandLight, 0.6 * lv));
      canvas.drawLine(a + d / len * q, b + d / len * q, _stroke..color = _c(_sandShadow, 0.5 * lv));
    }
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

/// Os pixels soltos da borda de uma faixa de largura [w] ao longo de [pts] (pares x, y): de cada lado, a cada pixel e meio,
/// uns ficam e outros não, um pouco para fora da borda; e um punhado em volta de cada ponta. Presos à rua pelo hash [h].
Float32List edgeDither(List<ui.Offset> pts, double w, double q, int h) {
  if (pts.length < 2 || q <= 0) return Float32List(0);
  final out = <double>[];
  var k = 0;
  _along(pts, q * 1.5, (o, tx, ty) {
    final r = fnv1a64Of3(h, k++, 0xD17);
    for (final (side, bits) in [(1.0, r >>> 32), (-1.0, r >>> 44)]) {
      if ((bits & 3) == 0) continue; // três em quatro ficam
      final d = w / 2 + q * (0.5 + ((bits >>> 2) & 0xff) / 255 * 2);
      out..add(o.dx - ty * d * side)..add(o.dy + tx * d * side);
    }
  });
  for (final (end, next, salt) in [(pts.first, pts[1], 1), (pts.last, pts[pts.length - 2], 2)]) {
    final v = end - next, len = v.distance;
    if (len <= 0) continue;
    final base = math.atan2(v.dy, v.dx);
    for (var i = 0; i < 7; i++) {
      final r = fnv1a64Of3(h, i, 0xE0D + salt);
      final a = base + (((r >>> 32) & 0xff) / 255 - 0.5) * math.pi, d = w / 2 + q * (0.5 + ((r >>> 40) & 0xff) / 255 * 2);
      out..add(end.dx + math.cos(a) * d)..add(end.dy + math.sin(a) * d);
    }
  }
  return Float32List.fromList(out);
}

/// O contorno de uma duna ao longo de [pts]: o eixo reamostrado a cada [step] e as duas bordas. A largura afina até zero
/// nas pontas e ondula pelo hash [h] (cada lado com o seu ruído, o lado do vento mais largo).
({List<ui.Offset> mid, List<ui.Offset> left, List<ui.Offset> right}) duneOutline(List<ui.Offset> pts, double w, double lv, int h, {required double step}) {
  final mid = <ui.Offset>[], dir = <ui.Offset>[];
  _along(pts, step, (o, tx, ty) {
    mid.add(o);
    dir.add(ui.Offset(tx, ty));
  });
  final left = <ui.Offset>[], right = <ui.Offset>[];
  final n = mid.length;
  double u8(int shift) => ((h >>> shift) & 0xff) / 255;
  final pa = u8(0) * 6.28, pb = u8(8) * 6.28, fa = 2 + u8(16) * 4, fb = 2 + u8(24) * 4;
  final skew = 0.6 + u8(32) * 0.8, peak = 0.3 + u8(40) * 0.4; // o lado do vento e onde a duna é mais gorda
  for (var i = 0; i < n; i++) {
    final s = n < 2 ? 0.5 : i / (n - 1);
    final x = s < peak ? s / peak : (1 - s) / (1 - peak);
    final body = math.pow(math.sin(x * math.pi / 2), 0.7) * w * (0.45 + 0.4 * lv);
    final nrm = ui.Offset(-dir[i].dy, dir[i].dx);
    left.add(mid[i] - nrm * (body * skew * (1 + 0.28 * math.sin(fa * s * 6.28 + pa))));
    right.add(mid[i] + nrm * (body * (2 - skew) * (1 + 0.28 * math.sin(fb * s * 6.28 + pb))));
  }
  return (mid: mid, left: left, right: right);
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
