/// O arco-íris da época 8 na camada do MUNDO (docs/clima-auditoria.md): um objeto de pé sobre um ponto do mapa. A base vai
/// de um pé ao outro no chão, na direção que a seed sorteou, e gira, move e dá zoom com o mapa; a altura sobe na tela,
/// como os sprites, então ele se encurta quando a base aponta para cima da tela (perspectiva). Some aos poucos no fim. O
/// ponto, a hora e a direção vêm do mundo ([ClimateWorld.rainbowsNear], iguais para amigos juntos); tamanho, cores e
/// esmaecer são só desenho (`clima.json`, `rainbow_arc`).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/climate.dart' show RainbowArc;
import '../../world/climate_world.dart';
import '../../world/map_camera.dart';

double _n(Map<String, dynamic> v, String k, double d) => (v[k] as num?)?.toDouble() ?? d;

/// A opacidade do arco em [t]: sobe em [fadeInS] desde o começo e desce nos últimos [fadeOutS].
double rainbowFade(RainbowArc a, double t, {required double fadeInS, required double fadeOutS}) {
  if (t < a.startUtc || t >= a.endUtc) return 0;
  final up = fadeInS <= 0 ? 1.0 : (t - a.startUtc) / fadeInS, down = fadeOutS <= 0 ? 1.0 : (a.endUtc - t) / fadeOutS;
  return math.min(1.0, math.min(up, down)).clamp(0.0, 1.0);
}

/// Pixels por célula z21 na tela, em qualquer rotação.
double _ppc(MapCamera cam, ui.Size view) {
  final (ox, oy) = cam.cellToScreen(0, 0, view.width, view.height);
  final (px, py) = cam.cellToScreen(1, 0, view.width, view.height);
  return math.sqrt((px - ox) * (px - ox) + (py - oy) * (py - oy));
}

/// Os pontos do arco na tela, de um pé ao outro ([steps] + 1). O arco de fora tem [outerM] metros de raio e o primeiro
/// ponto dele é o pé do mundo ([RainbowArc.footX], [RainbowArc.footY]) no chão; as faixas de dentro ([radiusM] menor) têm
/// o mesmo centro. A altura de cada ponto sobe na tela (`-y`) na mesma escala do chão vezes [lift].
List<ui.Offset> rainbowScreenPoints(RainbowArc a, MapCamera cam, ui.Size view, {required double outerM, double? radiusM, required double metersPerCell21, int steps = 32, double lift = 0.8}) {
  final r0 = outerM / metersPerCell21, r = (radiusM ?? outerM) / metersPerCell21;
  final ux = math.sin(a.headingRad), uy = -math.cos(a.headingRad);
  final cx = a.footX + ux * r0, cy = a.footY + uy * r0;
  final ppc = _ppc(cam, view);
  return [
    for (var i = 0; i <= steps; i++)
      () {
        final th = math.pi * i / steps;
        final (sx, sy) = cam.cellToScreen(cx - ux * r * math.cos(th), cy - uy * r * math.cos(th), view.width, view.height);
        return ui.Offset(sx, sy - r * math.sin(th) * ppc * lift);
      }(),
  ];
}

class RainbowPainter {
  RainbowPainter(this.visual);

  /// O bloco `rainbow_arc` do `clima.json`.
  final Map<String, dynamic> visual;

  List<RainbowArc> arcs = const [];

  double get radiusM => _n(visual, 'arc_m', 90);

  /// A cada meio segundo: os arcos ativos que podem aparecer na tela (o pé até a diagonal da tela mais o arco).
  void observe(ClimateWorld world, {required double px, required double py, required double radius21, required double metersPerCell21, required int t}) =>
      arcs = world.rainbowsNear(px, py, radius21 + 2 * radiusM / metersPerCell21, t);

  void paint(ui.Canvas canvas, ui.Size view, MapCamera cam, {required double metersPerCell21, required double exactUtc}) {
    if (arcs.isEmpty) return;
    final colors = [for (final c in (visual['colors'] as List<dynamic>?) ?? const ['#ff5a36', '#ffe9a8', '#6bd36a', '#4aa8ff', '#9b7bff']) 0xFF000000 | int.parse((c as String).substring(1), radix: 16)];
    final bandM = _n(visual, 'band_m', 3), alpha = _n(visual, 'alpha', 0.55);
    for (final a in arcs) {
      final f = rainbowFade(a, exactUtc, fadeInS: _n(visual, 'fade_in_s', 90), fadeOutS: _n(visual, 'fade_out_s', 300));
      if (f <= 0.01) continue;
      final w = math.max(2.0, bandM / metersPerCell21 * _ppc(cam, view));
      for (var i = 0; i < colors.length; i++) {
        final pts = rainbowScreenPoints(a, cam, view, outerM: radiusM, radiusM: radiusM - (i + 0.5) * bandM, metersPerCell21: metersPerCell21);
        final path = ui.Path()..moveTo(pts.first.dx, pts.first.dy);
        for (final p in pts.skip(1)) {
          path.lineTo(p.dx.roundToDouble(), p.dy.roundToDouble());
        }
        canvas.drawPath(path, ui.Paint()
          ..isAntiAlias = false
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = w
          ..color = ui.Color(colors[i]).withValues(alpha: alpha * f));
      }
    }
  }
}
