/// O desenho das poças (camada do mapa do clima): contorno irregular em pixel de arte, cor que parte do asfalto (mais
/// escura e um pouco azulada, ou tingida pela peça), reflexo claro de leve, anéis de gota enquanto chove. O contorno é
/// procedural ([blobRows]): seis famílias de forma, cada marca com rotação, tamanho e ruído do próprio hash. Nada de oval
/// liso nem de duas iguais lado a lado. As outras marcas do chão (crateras, manchas, brasas) usam o mesmo contorno.
library;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/fnv.dart';
import '../../world/cover_field.dart' show coverDither;

ui.Color _c(int argb, double a) => ui.Color(argb).withValues(alpha: a.clamp(0.0, 1.0));

/// Um trecho de uma linha da marca em pixels de arte: `y` e o trecho `[x0, x1]`. Uma linha pode ter mais de um trecho
/// (contornos com reentrância ou respingos soltos).
typedef PuddleRow = (int y, int x0, int x1);

/// Quantas famílias de contorno existem (redonda, comprida, dois lóbulos, feijão, três pontas, respingada). Cada marca
/// ainda gira, estica e ondula pelo próprio hash: duas da mesma família não saem iguais.
const int blobFamilies = 6;

final LinkedHashMap<(int, int, int), List<PuddleRow>> _rowCache = LinkedHashMap();

/// A família de contorno que o hash [h] escolhe.
int blobFamilyOf(int h) => ((h >>> 40) & 0xffff) % blobFamilies;

/// O fator de tamanho (0,75 a 1,3) que o hash [h] dá à marca: só desenho.
double blobScaleOf(int h) => 0.75 + ((h >>> 56) & 0xff) / 255 * 0.55;

/// O contorno procedural de uma marca no chão (poça, cratera, mancha, brasa, pingo de cera): as linhas, em pixels de
/// arte, de uma forma de raio [n], com ruído no contorno. A [family] (por omissão, a do hash), a rotação, o alongamento e a
/// irregularidade saem de [h]: iguais em todo aparelho (só hash), diferentes de marca para marca.
List<PuddleRow> blobRows(int h, int n, {int? family, bool dither = false}) {
  final f = (family ?? blobFamilyOf(h)) % blobFamilies;
  final key = (dither ? f + blobFamilies : f, h & 0xffffffffff, n);
  final hit = _rowCache.remove(key);
  if (hit != null) return _rowCache[key] = hit;
  double u8(int shift) => ((h >>> shift) & 0xff) / 255;
  final a = u8(0) * 6.28, b = u8(8) * 6.28, c = u8(16) * 6.28;
  final rot = u8(24) * math.pi, cr = math.cos(rot), sr = math.sin(rot);
  final rough = 0.10 + u8(32) * 0.14; // irregularidade do contorno
  final stretch = 0.85 + u8(12) * 0.3; // estica ou encolhe o eixo comprido
  double wobble(double th) => 1 + rough * math.sin(3 * th + a) + rough * 0.6 * math.sin(5 * th + b) + rough * 0.35 * math.sin(8 * th + c);
  // Cada forma é um campo: a distância (em raios) até o contorno, negativa dentro. Juntar duas é o mínimo; morder, o máximo.
  double ell(double x, double y, double cx, double cy, double rx, double ry) {
    final ex = (x - cx) / rx, ey = (y - cy) / ry;
    return math.sqrt(ex * ex + ey * ey) - wobble(math.atan2(ey, ex));
  }

  double field(double px, double py) {
    final x = px * cr + py * sr, y = -px * sr + py * cr;
    switch (f) {
      case 1: // comprida
        return ell(x, y, 0, 0, n * 1.7 * stretch, n * 0.7);
      case 2: // dois lóbulos
        return math.min(ell(x, y, -0.5 * n, 0, 0.85 * n, 0.75 * n), ell(x, y, 0.6 * n * stretch, 0.1 * n, 0.6 * n, 0.55 * n));
      case 3: // feijão: uma oval com uma mordida de lado
        return math.max(ell(x, y, 0, 0, n * 1.4 * stretch, n * 0.95), -ell(x, y, 0.15 * n, 1.05 * n, 0.75 * n, 0.6 * n));
      case 4: // três pontas
        final th = math.atan2(y, x);
        return math.sqrt(x * x + y * y) / (n * (0.78 + 0.3 * math.cos(3 * th + a))) - wobble(th);
      case 5: // respingada: a mancha e dois pingos soltos
        return math.min(
            ell(x, y, 0, 0, n * 0.95 * stretch, n * 0.8),
            math.min(ell(x, y, math.cos(b) * n * 1.35, math.sin(b) * n * 1.1, n * 0.32, n * 0.28),
                ell(x, y, math.cos(b + 2.4 + c * 0.2) * n * 1.3, math.sin(b + 2.4 + c * 0.2) * n * 1.15, n * 0.24, n * 0.22)));
      default: // redonda, um pouco larga
        return ell(x, y, 0, 0, n * 1.2 * stretch, n.toDouble());
    }
  }

  // A borda é o limiar do campo; com [dither] (as poças), o pontilhado ordenado da cobertura por campo desfaz a beirada.
  bool inside(double px, double py) => field(px, py) <= (dither ? (coverDither(px.round(), py.round()) - 0.5) * 0.32 : 0);

  final w = (n * 2.2).ceil() + 1;
  final rows = <PuddleRow>[];
  for (var y = -w; y <= w; y++) {
    int? x0;
    for (var x = -w; x <= w + 1; x++) {
      final hit = x <= w && inside(x.toDouble(), y.toDouble());
      if (hit) {
        x0 ??= x;
      } else if (x0 != null) {
        rows.add((y, x0, x - 1));
        x0 = null;
      }
    }
  }
  _rowCache[key] = rows;
  while (_rowCache.length > 512) {
    _rowCache.remove(_rowCache.keys.first);
  }
  return rows;
}

/// As linhas da poça da família [variant] de raio [n] pixels de arte; [h] dá o contorno. Ver [blobRows].
List<PuddleRow> puddleRows(int variant, int h, int n) => blobRows(h, n, family: variant, dither: true);

/// Desenha as linhas de [blobRows] em [o], com o pixel de arte [q] (nas unidades do canvas).
void paintBlobRows(ui.Canvas canvas, ui.Offset o, List<PuddleRow> rows, double q, ui.Color color) => _rows(canvas, o, rows, q, color);

final _fill = ui.Paint()..isAntiAlias = false;

void _rows(ui.Canvas canvas, ui.Offset o, List<PuddleRow> rows, double q, ui.Color color) {
  _fill.color = color;
  final path = ui.Path();
  for (final (y, x0, x1) in rows) {
    path.addRect(ui.Rect.fromLTWH(o.dx + x0 * q, o.dy + y * q, (x1 - x0 + 1) * q, q));
  }
  canvas.drawPath(path, _fill);
}

/// Desenha a poça em [o] (já na câmera) com raio [radius] (células) e pixel de arte [q] (células). [size] é quanto ela já
/// cresceu (0 a 1): pequena, ela é só pontos molhados. [tint] é a cor da peça; [asphalt], a da rua.
void paintPuddle(
  ui.Canvas canvas,
  ui.Offset o, {
  required double radius,
  required double q,
  required int index,
  required int hash,
  required double size,
  required int tint,
  required int asphalt,
  required double alpha,
  required bool raining,
  required bool reflect,
  required bool prism,
  required double night,
  required double t,
}) {
  final n = math.max(1, (radius * blobScaleOf(hash) / q).round());
  final variant = blobFamilyOf(hash);
  final wet = ui.Color.lerp(ui.Color(asphalt), const ui.Color(0xFF000000), 0.3)!;
  final body = ui.Color.lerp(ui.Color.lerp(ui.Color(asphalt), const ui.Color(0xFF0A0E1C), 0.35)!, ui.Color(tint), 0.3)!;
  final k = math.min(1.0, alpha / 0.35);
  if (size < 0.35) {
    // Começo da chuva: pontos molhados que vão se juntando.
    for (var s = 0; s < 4; s++) {
      final h = fnv1a64Of3(hash, s, 0x77);
      final dx = (((h >>> 16) & 0xff) / 255 - 0.5) * 2 * n * q, dy = (((h >>> 24) & 0xff) / 255 - 0.5) * 1.2 * n * q;
      final m = math.max(1, (n * (0.15 + size) * (0.6 + ((h >>> 32) & 0xff) / 640)).round());
      _rows(canvas, o.translate(dx * (1 - size), dy * (1 - size)), puddleRows(s, h, m), q, wet.withValues(alpha: 0.6 * k));
    }
    if (size < 0.12) return;
  }
  final rows = puddleRows(variant, hash, n);
  _rows(canvas, o, puddleRows(variant, hash, n + 1), q, wet.withValues(alpha: 0.55 * k)); // o asfalto molhado em volta
  _rows(canvas, o, rows, q, body.withValues(alpha: 0.9 * k));
  if (reflect) {
    // O céu na poça, de leve: claro de dia, escuro com uma estrela à noite.
    final sky = ui.Color.lerp(const ui.Color(0xFFE8E4F4), const ui.Color(0xFF2A2236), night)!;
    final top = rows.length ~/ 4;
    for (var j = top; j < math.min(rows.length, top + math.max(1, rows.length ~/ 6)); j++) {
      final (y, x0, x1) = rows[j];
      final len = math.max(1, (x1 - x0) ~/ 3);
      canvas.drawRect(ui.Rect.fromLTWH(o.dx + (x0 + 1) * q, o.dy + y * q, len * q, q), _fill..color = sky.withValues(alpha: 0.3));
    }
    if (night > 0.5 && rows.length > 2) {
      final (y, x0, x1) = rows[rows.length ~/ 2];
      canvas.drawRect(ui.Rect.fromLTWH(o.dx + ((x0 + x1) ~/ 2 + 1) * q, o.dy + y * q, q, q), _fill..color = _c(0xFFE8E4F4, 0.8));
    }
  }
  if (prism && rows.isNotEmpty) {
    const cs = [0xFFFF5A36, 0xFFFFE9A8, 0xFF6BD36A, 0xFF4AA8FF];
    final (y, x0, x1) = rows[rows.length * 2 ~/ 3];
    final step = math.max(1, (x1 - x0) ~/ 6);
    for (var i = 0; i < cs.length; i++) {
      canvas.drawRect(ui.Rect.fromLTWH(o.dx + (x0 + 1 + i * step) * q, o.dy + y * q, step * q, q), _fill..color = _c(cs[i], 0.6));
    }
  }
  if (raining && rows.length > 2) {
    // Anéis de gota: cada um nasce num ponto da poça, abre em 1 s e some.
    for (var r = 0; r < 1 + n ~/ 6; r++) {
      final cycle = (t / 1.1 + r * 0.37 + (hash & 0xf) / 16).floor();
      final ph = (t / 1.1 + r * 0.37 + (hash & 0xf) / 16) - cycle;
      final h = fnv1a64Of3(hash, r, cycle);
      final (y, x0, x1) = rows[1 + (h >>> 8) % (rows.length - 2)];
      final x = x0 + (h >>> 24) % math.max(1, x1 - x0 + 1);
      final rr = 1 + (ph * 2.5).floor();
      final c = _c(0xFFE8E4F4, 0.45 * (1 - ph));
      final ox = o.dx + x * q, oy = o.dy + y * q;
      canvas.drawRect(ui.Rect.fromLTWH(ox - rr * q, oy, q, q), _fill..color = c);
      canvas.drawRect(ui.Rect.fromLTWH(ox + rr * q, oy, q, q), _fill);
      canvas.drawRect(ui.Rect.fromLTWH(ox, oy - rr * q, q, q), _fill);
      canvas.drawRect(ui.Rect.fromLTWH(ox, oy + rr * q, q, q), _fill);
    }
  }
}

/// A poça congelada: a mesma forma, gelo claro com rachaduras de pixel e o cristal piscando.
void paintIcePuddle(ui.Canvas canvas, ui.Offset o, {required double radius, required double q, required int index, required int hash, required int color, required int glow, required double alpha, required double t}) {
  final n = math.max(1, (radius * blobScaleOf(hash) / q).round());
  final rows = blobRows(hash, n);
  _rows(canvas, o, blobRows(hash, n + 1), q, _c(0xFF1A1424, 0.35));
  _rows(canvas, o, rows, q, _c(color, alpha));
  for (var j = 1; j < rows.length - 1; j += 3) {
    final (y, x0, x1) = rows[j];
    final x = x0 + (fnv1a64Of3(hash, j, 3) >>> 20) % math.max(1, x1 - x0 + 1);
    canvas.drawRect(ui.Rect.fromLTWH(o.dx + x * q, o.dy + y * q, 2 * q, q), _fill..color = _c(glow, 0.6));
  }
  final k = 0.5 + 0.5 * math.sin(t * 2.5 + index);
  canvas.drawRect(ui.Rect.fromCenter(center: o.translate(n * q * 0.3, -n * q * 0.2), width: 2 * q, height: 2 * q), _fill..color = _c(0xFFFFFFFF, k));
}
