/// O "antes" do Laboratório visual (só debug): o quarteirão fixo no estilo de hoje, o Simplificado do mapa. O "depois" é o
/// renderizador do mapa no estilo Completo (`ui/city/`, 0.22.0). Desenha em pixels de arte num buffer pequeno, ampliado por
/// vizinho mais próximo por quem chama.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/biomes.dart';
import '../../world/lab_block.dart';
import '../game/art_style.dart';
import 'lab_art.dart';

/// A câmera e a luz de um quadro.
class LabView {
  const LabView({required this.cx, required this.cy, required this.rotation, required this.pxPerM, required this.sunAltDeg, required this.sunAzDeg, required this.localHour});

  /// O centro da tela no quarteirão (metros), o giro do mapa (radianos) e o zoom (pixels de arte por metro).
  final double cx, cy, rotation, pxPerM;
  final double sunAltDeg, sunAzDeg;
  final int localHour;
}

int _h(int a, int b) {
  var x = (a * 73856093) ^ (b * 19349663) ^ 0x2c1b3c6d;
  x = (x * 1103515245 + 12345) & 0x7fffffff;
  return (x * 1103515245 + 12345) & 0x7fffffff;
}

class LabRenderer {
  LabRenderer(this.block, this.art, BiomeSet biomes) : _old = ArtStyle(biomes) {
    // O ruído do chão de hoje: 7% escuro e 5% claro, como o `art_renderer.dart`.
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec)..drawRect(const ui.Rect.fromLTWH(0, 0, 64, 64), ui.Paint()..color = _old.ground.base);
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        final hh = _h(x, y) % 100;
        if (hh < 12) c.drawRect(ui.Rect.fromLTWH(x + 0.0, y + 0.0, 1, 1), ui.Paint()..color = hh < 7 ? _old.ground.dark : _old.ground.light);
      }
    }
    _oldNoise = rec.endRecording().toImageSync(64, 64);
  }

  late final ui.Image _oldNoise;

  final LabBlock block;
  final LabArt art;
  final ArtStyle _old;

  /// Desenha o quarteirão no estilo de hoje (o Simplificado) em [size] pixels de arte. O estilo novo (0.22.0) é o do mapa:
  /// `ui/city/city_renderer.dart`, que o laboratório usa no "depois".
  void paint(ui.Canvas canvas, ui.Size size, LabView v) {
    final cs = math.cos(v.rotation), sn = math.sin(v.rotation), k = v.pxPerM;
    final center = ui.Offset(size.width / 2, size.height / 2);
    ui.Offset s(Pt p) {
      final dx = (p.$1 - v.cx) * k, dy = (p.$2 - v.cy) * k;
      return ui.Offset(center.dx + dx * cs - dy * sn, center.dy + dx * sn + dy * cs);
    }

    ui.Path poly(List<Pt> pts) => ui.Path()..addPolygon([for (final p in pts) s(p)], true);
    ui.Path line(List<Pt> pts) {
      final path = ui.Path()..moveTo(s(pts.first).dx, s(pts.first).dy);
      for (final p in pts.skip(1)) {
        path.lineTo(s(p).dx, s(p).dy);
      }
      return path;
    }

    final o = _old;
    final at = poly(const [(0, 0), (1, 0), (0, 1)]).getBounds().topLeft;
    canvas.drawRect(
      ui.Offset.zero & size,
      ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..shader = ui.ImageShader(_oldNoise, ui.TileMode.repeated, ui.TileMode.repeated, Matrix4Lite.translate(at.dx.roundToDouble(), at.dy.roundToDouble())),
    );
    for (final g in block.greens) {
      canvas.drawPath(poly(g), ui.Paint()..color = o.green.base..isAntiAlias = false);
      canvas.drawPath(poly(g), ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 1..color = o.green.edge..isAntiAlias = false);
    }
    for (final w in block.waters) {
      canvas.drawPath(poly(w), ui.Paint()..color = o.water.base..isAntiAlias = false);
    }
    for (final r in block.roads) {
      canvas.drawPath(line(r.pts), ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = (roadWidthM(r.cls) + 2 * sidewalkWidthM(r.cls)) * v.pxPerM..color = o.sidewalk..isAntiAlias = false);
    }
    for (final r in block.roads) {
      if (r.cls != 'pedestrian') canvas.drawPath(line(r.pts), ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = roadWidthM(r.cls) * v.pxPerM..color = o.asphalt..isAntiAlias = false);
    }
    final night = ((6 - v.sunAltDeg) / 18).clamp(0.0, 1.0);
    if (night > 0) canvas.drawRect(ui.Offset.zero & size, ui.Paint()..color = const ui.Color(0xFF141033).withValues(alpha: 0.55 * night));
  }
}

/// A matriz de translação de um shader (4 × 4, coluna maior).
abstract final class Matrix4Lite {
  static Float64List translate(double x, double y) => Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, 0, 1]);
}
