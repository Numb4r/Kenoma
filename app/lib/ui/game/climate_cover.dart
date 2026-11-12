/// A cobertura das ruas e do chão (camada do mapa do clima): neve, gelo, fuligem e a água do Dilúvio saem de um campo por
/// pixel (`world/cover_field.dart`): uma máscara única das ruas por bloco e a cor por faixas de profundidade, com a borda
/// em pontilhado ordenado. Cada bloco vira uma imagem, refeita só quando a fase do clima muda de faixa (nunca a cada
/// quadro) e fora da thread do desenho. As dunas continuam sendo montes desenhados sobre trechos de rua. O canvas já está na
/// câmera (células z21, gira e dá zoom com o mapa).
library;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;

import '../../core/fnv.dart';
import '../../data/visual_pack.dart';
import '../../world/cover_blocks.dart';
import '../../world/cover_field.dart';
import '../../world/street_cover.dart';
import '../../world/visual_map.dart';
import 'climate_ground.dart' show PlacedMark;

ui.Color _c(int argb, double a) => ui.Color(argb).withValues(alpha: a.clamp(0.0, 1.0));

const int _sandLight = 0xFFF2DCA4, _sandShadow = 0xFFA9824E;

/// Uma rua à vista: tile, índice, a linha e os pontos já na câmera.
typedef _Street = (int tx, int ty, int i, VisualLine line, List<ui.Offset> pts);

class ClimateCover {
  ClimateCover({required this.visual, required this.roadWidthM});

  final VisualMap visual;
  final Map<String, double> roadWidthM;

  // Por tile (o mesmo objeto enquanto o tile fica no cache do pacote): o retângulo de cada linha e as áreas em caminho.
  final _boxes = Expando<Int32List>();

  final _stroke = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..isAntiAlias = false
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;
  final _fill = ui.Paint()..isAntiAlias = false;
  final _dots = ui.Paint()
    ..isAntiAlias = false
    ..strokeCap = ui.StrokeCap.square;

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

  // Os blocos do campo: a imagem de agora, a chave com que foi feita e a que está sendo feita.
  final LinkedHashMap<(StreetCoverKind, int, int), _FieldBlock> _blocks = LinkedHashMap();
  int _building = 0;
  final ui.Paint _image = ui.Paint()
    ..isAntiAlias = false
    ..filterQuality = ui.FilterQuality.none;

  /// Quantos blocos foram refeitos desde o começo, quanto levou o último (ms, fora da thread do desenho) e quantos foram
  /// desenhados no último quadro (debug e medição).
  int fieldBuilds = 0, fieldDrawn = 0;
  double fieldLastMs = 0;

  /// O desgaste do tráfego local por rua (tile e índice da linha), de 0 a 1, e um carimbo que muda quando ele muda.
  double Function((int, int, int) key)? wearOf;
  int wearStamp = 0;

  /// Sobe quando um tile da água no relevo chega do cálculo de fundo: os blocos do Dilúvio são refeitos com as ruas que
  /// alagam de verdade.
  int waterStamp = 0;

  /// Refaz os blocos na hora, sem isolate (testes e exportação de imagens).
  static bool buildInline = false;

  void dispose() {
    for (final b in _blocks.values) {
      b.image?.dispose();
    }
    _blocks.clear();
  }

  void _field(ui.Canvas canvas, StreetCover cover, {required int color, required double alpha, required int seed, required int window, required double amount, required double peak, required bool melting, required double mpc, required double windRad, required int hour, required double l, required double top, required double r, required double b, required ui.Offset Function(double, double) at}) {
    // O sol nasce a leste e passa ao norte (hemisfério sul); de noite, a luz fixa de cima à esquerda.
    final day = hour >= 6 && hour < 18, ang = math.pi * (hour - 6) / 12;
    final sunX = day ? math.cos(ang) : -0.7, sunY = day ? -0.3 - 0.7 * math.sin(ang) : -0.7;
    final snow = cover.kind == StreetCoverKind.snow;
    final wind = (windRad / (math.pi / 8)).round() % 16;
    // A fase em faixas: o bloco só é refeito quando ela muda de faixa.
    final key = (seed, window, (amount * 64).round(), melting, (peak * 16).round(), snow ? wind : 0, snow ? ((sunX * 2).round(), (sunY * 2).round()) : null, snow && cover.tracks ? wearStamp : 0, cover.floods == null ? 0 : waterStamp, visual.pack.revision, color, (alpha * 100).round());
    const n = coverBlockCells;
    final cx = (l + r) / 2, cy = (top + b) / 2;
    fieldDrawn = 0;
    // Zoom muito aberto (o mapa livre do debug): blocos demais e pequenos demais para se ver; fica sem a cobertura.
    final count = ((r / n).floor() - (l / n).floor() + 3) * ((b / n).floor() - (top / n).floor() + 3);
    if (count > 400) return;
    _FieldBlock? stale;
    (int, int)? staleAt;
    var best = double.infinity;
    // Uma volta de blocos além da tela, para o mapa não mostrar buraco ao andar.
    for (var by = (top / n).floor() - 1; by <= (b / n).floor() + 1; by++) {
      for (var bx = (l / n).floor() - 1; bx <= (r / n).floor() + 1; bx++) {
        final id = (cover.kind, bx, by);
        var blk = _blocks.remove(id);
        blk ??= _FieldBlock();
        _blocks[id] = blk;
        final img = blk.image;
        if (img != null) {
          final o = at(bx * n.toDouble(), by * n.toDouble());
          canvas.drawImageRect(img, const ui.Rect.fromLTWH(0, 0, coverSize * 1.0, coverSize * 1.0), ui.Rect.fromLTWH(o.dx, o.dy, n.toDouble(), n.toDouble()), _image);
          fieldDrawn++;
        }
        if (blk.key != key && blk.pending == null) {
          final d = (bx * n + n / 2 - cx) * (bx * n + n / 2 - cx) + (by * n + n / 2 - cy) * (by * n + n / 2 - cy);
          if (d < best) {
            best = d;
            stale = blk;
            staleAt = (bx, by);
          }
        }
      }
    }
    while (_blocks.length > math.max(96, count * 2)) {
      _blocks.remove(_blocks.keys.first)?.image?.dispose();
    }
    // Um bloco por quadro entra na fila (o mais perto do meio da tela), no máximo dois sendo feitos ao mesmo tempo.
    if (stale == null || _building >= 2) return;
    final blk = stale;
    final (bx, by) = staleAt!;
    final input = coverInputOf(visual, bx, by, cover: cover, seed: seed, window: window, amount: amount, peak: peak, melting: melting, mpc: mpc, roadWidthM: roadWidthM, windX: math.sin(wind * math.pi / 8), windY: -math.cos(wind * math.pi / 8), sunX: sunX, sunY: sunY, color: color, alpha: alpha, wearOf: snow && cover.tracks ? wearOf : null);
    blk.pending = key;
    _building++;
    final sw = Stopwatch()..start();
    void done(Uint8List? rgba) {
      _building--;
      fieldLastMs = sw.elapsedMicroseconds / 1000;
      if (rgba == null) {
        blk.pending = null;
        return;
      }
      fieldBuilds++;
      ui.decodeImageFromPixels(rgba, coverSize, coverSize, ui.PixelFormat.rgba8888, (img) {
        blk.image?.dispose();
        blk
          ..image = img
          ..key = key
          ..pending = null;
      });
    }

    if (buildInline) {
      done(buildCover(input).rgba);
    } else {
      // Função de topo e mensagem só com dados: nada do desenho (imagens, canvas) vai junto para o isolate.
      compute(_coverRgba, input).then(done, onError: (Object _) => done(null));
    }
  }

  /// Desenha a cobertura [cover] com [amount] dela formada ([peak]: o máximo a que chegou; [melting]: já está sumindo).
  /// [px] é um ponto de tela em células, [artPx] o pixel de arte.
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
    double peak = 1,
    bool melting = false,
    double windRad = 0,
    int hour = 12,
    double duneMps = 0.02,
  }) {
    if (amount <= 0) return;
    final streets = _streets(l, top, r, b, at);
    final q = artPx * px;
    if (cover.kind != StreetCoverKind.sand) {
      _field(canvas, cover, color: color, alpha: alpha, seed: seed, window: window, amount: amount, peak: peak, melting: melting, mpc: mpc, windRad: windRad, hour: hour, l: l, top: top, r: r, b: b, at: at);
    }
    for (final (tx, ty, i, line, pts0) in streets) {
      final lv = cover.level(seed, (tx, ty, i), line.roadClass, window, amount);
      if (lv <= 0) continue;
      final w = _w(line.roadClass, mpc);
      final key = (tx, ty, i);
      var pts = pts0;
      if (cover.kind == StreetCoverKind.sand) {
        // A duna anda devagar pela rua, para o lado do vento, enquanto o clima dura; no fim da rua ela se amontoa.
        final span = cover.duneSpan(seed, key, window, lv);
        var len = 0.0;
        for (var k = 1; k < pts0.length; k++) {
          len += (pts0[k] - pts0[k - 1]).distance;
        }
        final along = (pts0.last.dx - pts0.first.dx) * math.sin(windRad) - (pts0.last.dy - pts0.first.dy) * math.cos(windRad);
        final shift = (along >= 0 ? 1 : -1) * duneMps * math.max(0.0, t - window * 10800.0) / math.max(1.0, len * mpc);
        final wSpan = span.$2 - span.$1, a = (span.$1 + shift).clamp(0.0, 1 - wSpan);
        pts = spanOf(pts, (a, a + wSpan));
      }
      if (pts.length < 2) continue;
      switch (cover.kind) {
        case StreetCoverKind.flood:
          // O brilho que corre no meio da água (a água em si é do campo).
          canvas.drawPath(ui.Path()..addPolygon(pts, false), _stroke..strokeWidth = math.max(q, w * 0.18)..color = _c(0xFFE8E4F4, 0.16 * lv * (0.6 + 0.4 * math.sin(t * 1.5 + i))));
        case StreetCoverKind.snow:
          break;
        case StreetCoverKind.sand:
          _dune(canvas, pts, lv, w, q, color, alpha, _h(seed, key));
        case StreetCoverKind.ice:
          _glints(canvas, pts, w, q, lv, t, seed, key, 0xFFFFFFFF);
        case StreetCoverKind.soot:
          _glints(canvas, pts, w, q, lv * 0.7, 0, seed, key, 0xFF1A1424);
      }
      final unit = visual.cellsPerTile / visual.pack.extent;
      placed.add((kind: 'street_${cover.kind.name}', x: tx * visual.cellsPerTile + line.xy[0] * unit, y: ty * visual.cellsPerTile + line.xy[1] * unit));
    }
  }

  static int _h(int seed, (int, int, int) key) => fnv1a64Of3(seed ^ key.$1, key.$2, key.$3);

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

Uint8List _coverRgba(CoverInput input) => buildCover(input).rgba;

class _FieldBlock {
  ui.Image? image;
  Object? key, pending;
}
