/// O desenho das poças (camada do mapa do clima): contorno irregular em pixel de arte, cor que parte do asfalto (mais
/// escura e um pouco azulada, ou tingida pela peça), reflexo claro de leve, anéis de gota enquanto chove. Três variantes de
/// tamanho e forma, escolhidas pelo índice da poça: redonda, comprida e de dois lóbulos. Nada de oval liso.
library;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/fnv.dart';

ui.Color _c(int argb, double a) => ui.Color(argb).withValues(alpha: a.clamp(0.0, 1.0));

/// Uma linha da poça em pixels de arte: `y` e o trecho `[x0, x1]`.
typedef PuddleRow = (int y, int x0, int x1);

final LinkedHashMap<(int, int, int), List<PuddleRow>> _rowCache = LinkedHashMap();

/// As linhas da poça [variant] (0 redonda, 1 comprida, 2 dois lóbulos) de raio [n] pixels de arte; [h] dá o contorno
/// irregular. Iguais em todo aparelho (só hash).
List<PuddleRow> puddleRows(int variant, int h, int n) {
  final key = (variant % 3, h & 0xffff, n);
  final hit = _rowCache.remove(key);
  if (hit != null) return _rowCache[key] = hit;
  final a = (h & 0xff) / 255 * 6.28, b = ((h >>> 8) & 0xff) / 255 * 6.28;
  double wobble(double th) => 1 + 0.16 * math.sin(3 * th + a) + 0.09 * math.sin(5 * th + b);
  bool inside(double x, double y) {
    switch (variant % 3) {
      case 1: // comprida, ao longo da rua
        final ex = x / 1.7, ey = y / 0.75;
        return math.sqrt(ex * ex + ey * ey) <= n * wobble(math.atan2(ey, ex));
      case 2: // dois lóbulos
        bool lobe(double cx, double r) => math.sqrt((x - cx) * (x - cx) / 1.2 + y * y) <= r * wobble(math.atan2(y, x - cx));
        return lobe(-0.45 * n, 0.75 * n) || lobe(0.5 * n, 0.55 * n);
      default: // redonda, um pouco larga
        final ex = x / 1.3;
        return math.sqrt(ex * ex + y * y) <= n * wobble(math.atan2(y, ex));
    }
  }

  final w = (n * 2.2).ceil();
  final rows = <PuddleRow>[];
  for (var y = -n; y <= n; y++) {
    int? x0, x1;
    for (var x = -w; x <= w; x++) {
      if (!inside(x.toDouble(), y.toDouble())) continue;
      x0 ??= x;
      x1 = x;
    }
    if (x0 != null) rows.add((y, x0, x1!));
  }
  _rowCache[key] = rows;
  while (_rowCache.length > 256) {
    _rowCache.remove(_rowCache.keys.first);
  }
  return rows;
}

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
  final n = math.max(1, (radius / q).round());
  final variant = index % 3;
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
  final n = math.max(1, (radius / q).round());
  final rows = puddleRows(index % 3, hash, n);
  _rows(canvas, o, puddleRows(index % 3, hash, n + 1), q, _c(0xFF1A1424, 0.35));
  _rows(canvas, o, rows, q, _c(color, alpha));
  for (var j = 1; j < rows.length - 1; j += 3) {
    final (y, x0, x1) = rows[j];
    final x = x0 + (fnv1a64Of3(hash, j, 3) >>> 20) % math.max(1, x1 - x0 + 1);
    canvas.drawRect(ui.Rect.fromLTWH(o.dx + x * q, o.dy + y * q, 2 * q, q), _fill..color = _c(glow, 0.6));
  }
  final k = 0.5 + 0.5 * math.sin(t * 2.5 + index);
  canvas.drawRect(ui.Rect.fromCenter(center: o.translate(n * q * 0.3, -n * q * 0.2), width: 2 * q, height: 2 * q), _fill..color = _c(0xFFFFFFFF, k));
}
