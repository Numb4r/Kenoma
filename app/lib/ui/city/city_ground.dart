/// O chão do estilo Completo (0.22.0) num bloco do cache: chão do bioma, verdes, água, quintal e muro, calçada (portuguesa
/// no Centro), meio-fio, asfalto (molhado na chuva), faixas, faixa de pedestre, a planta dos prédios, as sombras do sol e a
/// luz da hora; à noite, as poças de luz dos postes e, com chuva, o reflexo deles. É o que gira com o mapa: o bloco é
/// rasterizado já girado, em pixels de arte alinhados à tela (`CityFrame`), e só refeito quando muda o giro, o zoom, a
/// faixa da luz, a chuva ou o nível de detalhe. Só desenho.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../world/city_scene.dart';
import '../../world/lab_block.dart' show shadowOffset;
import '../lab/lab_art.dart';
import '../lab/lab_renderer.dart' show Matrix4Lite;
import '../sprites/map_style.dart';

/// O quadro de pixels de arte de um giro e de um zoom: `(x, y)` em células z21 vira `R(angle) · (p − o) · kc`, com o eixo
/// y para baixo (o mesmo do `ArtRenderer`). Dois blocos no mesmo quadro encaixam pixel a pixel.
class CityFrame {
  const CityFrame({required this.angle, required this.kc, required this.ox, required this.oy});

  final double angle;

  /// Pixels de arte por célula z21.
  final double kc;

  /// A âncora do quadro (células z21): a origem dos pixels de arte e dos módulos de chão.
  final double ox, oy;

  ui.Offset map(double x, double y) {
    final c = math.cos(angle), s = math.sin(angle), dx = (x - ox) * kc, dy = (y - oy) * kc;
    return ui.Offset(dx * c - dy * s, dx * s + dy * c);
  }

  @override
  bool operator ==(Object other) => other is CityFrame && other.angle == angle && other.kc == kc && other.ox == ox && other.oy == oy;

  @override
  int get hashCode => Object.hash(angle, kc, ox, oy);
}

/// O que muda a cara do chão além do quadro: a faixa da luz (altitude e azimute do sol em degraus), a chuva e o detalhe.
class GroundKey {
  const GroundKey({required this.sunAltBand, required this.sunAzBand, required this.lights, required this.wet, required this.far});

  final int sunAltBand, sunAzBand;
  final bool lights, wet, far;

  @override
  bool operator ==(Object other) => other is GroundKey && other.sunAltBand == sunAltBand && other.sunAzBand == sunAzBand && other.lights == lights && other.wet == wet && other.far == far;

  @override
  int get hashCode => Object.hash(sunAltBand, sunAzBand, lights, wet, far);
}

/// Degraus da faixa da luz: o sol anda uns 15 graus por hora, então o chão é refeito a cada 15 a 20 minutos.
const double sunAltStepDeg = 3, sunAzStepDeg = 5;

GroundKey groundKeyFor({required double sunAltDeg, required double sunAzDeg, required bool wet, required bool far}) =>
    GroundKey(sunAltBand: (sunAltDeg / sunAltStepDeg).round(), sunAzBand: (sunAzDeg / sunAzStepDeg).round(), lights: lightsOn(sunAltDeg), wet: wet, far: far);

ui.Paint _fill(int argb) => ui.Paint()
  ..color = ui.Color(argb)
  ..isAntiAlias = false;

/// O bloco de chão pronto: a imagem e onde ela fica no quadro (o canto em pixels de arte inteiros).
class GroundChunk {
  GroundChunk(this.image, this.left, this.top, this.frame, this.key);

  final ui.Image image;
  final int left, top;
  final CityFrame frame;
  final GroundKey key;
}

/// Rasteriza o bloco de [size] × [size] células z21 com o canto em `(cx0, cy0)`. [tiles]: os tiles da cena que tocam o
/// retângulo (com folga para as sombras que vêm de fora). [biomeAt]: a chave do bioma da grade numa célula.
GroundChunk rasterGroundChunk({
  required int cx0,
  required int cy0,
  required int size,
  required CityFrame f,
  required GroundKey key,
  required double sunAltDeg,
  required double sunAzDeg,
  required double mpc,
  required LabArt art,
  required List<CityTile> tiles,
  required String Function(int cx, int cy) biomeAt,
}) {
  // O bloco cobre 1 pixel de arte a mais de cada lado: vizinhos se sobrepõem com pixels iguais (mesmo quadro, mesmos módulos
  // ancorados), e a emenda nunca fica sem pixel.
  final e = 1 / f.kc;
  final corners = [f.map(cx0 - e, cy0 - e), f.map(cx0 + size + e, cy0 - e), f.map(cx0 + size + e, cy0 + size + e), f.map(cx0 - e, cy0 + size + e)];
  final left = corners.map((p) => p.dx).reduce(math.min).floor(), top = corners.map((p) => p.dy).reduce(math.min).floor();
  final right = corners.map((p) => p.dx).reduce(math.max).ceil(), bottom = corners.map((p) => p.dy).reduce(math.max).ceil();
  final w = math.max(1, right - left), h = math.max(1, bottom - top);
  final o = ui.Offset(left.toDouble(), top.toDouble());
  ui.Offset s(double x, double y) => f.map(x, y) - o;
  ui.Path poly(Float64List xy) {
    final p = ui.Path();
    for (var i = 0; i < xy.length; i += 2) {
      final q = s(xy[i], xy[i + 1]);
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    return p..close();
  }

  ui.Path rings(List<Float64List> rs) {
    final p = ui.Path()..fillType = ui.PathFillType.evenOdd;
    for (final r in rs) {
      p.addPath(poly(r), ui.Offset.zero);
    }
    return p;
  }

  ui.Path line(Float64List xy) {
    final p = ui.Path();
    for (var i = 0; i < xy.length; i += 2) {
      final q = s(xy[i], xy[i + 1]);
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    return p;
  }

  // Os módulos de chão ancorados na origem do quadro: dois blocos vizinhos continuam o mesmo desenho.
  final shaderM = Matrix4Lite.translate(-left.toDouble(), -top.toDouble());
  ui.Paint ground(String k) => ui.Paint()
    ..isAntiAlias = false
    ..filterQuality = ui.FilterQuality.none
    ..shader = ui.ImageShader(art.pattern(k, far: key.far), ui.TileMode.repeated, ui.TileMode.repeated, shaderM);

  final kpm = f.kc / mpc; // pixels de arte por metro
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec, ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
  c.clipPath(ui.Path()..addPolygon([for (final p in corners) p - o], true), doAntiAlias: false);

  // 1. O chão de cada célula pelo bioma. O Vazio com casa vira bairro (a grade marca quase todo bairro como Vazio).
  final built = <int>{};
  final buildings = [for (final t in tiles) ...t.buildings];
  for (final b in buildings) {
    final (bl, bt, br, bb) = b.bounds;
    if (br < cx0 - 1 || bl > cx0 + size + 1 || bb < cy0 - 1 || bt > cy0 + size + 1) continue;
    built.add(b.centroid.$1.floor() * 0x100000 + b.centroid.$2.floor());
  }
  // O Vazio cercado de cidade (3 ou mais vizinhos de cidade) pega o chão mais comum deles: terra batida só onde é campo
  // aberto de verdade, não no meio do Centro. Só desenho; a grade lógica não muda.
  const city = {'urban', 'residential', 'lit', 'sacred'};
  String groundOf(int x, int y) {
    final k = biomeAt(x, y);
    if (k != 'void') return groundRecipes.containsKey(k) ? k : 'urban';
    if (built.contains(x * 0x100000 + y)) return 'residential';
    final near = <String, int>{};
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final n = (dx == 0 && dy == 0) ? 'void' : biomeAt(x + dx, y + dy);
        if (city.contains(n)) near[n] = (near[n] ?? 0) + 1;
      }
    }
    final total = near.values.fold(0, (a, b) => a + b);
    if (total < 3) return 'empty';
    return near.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  final mosaicCells = ui.Path();
  for (var y = cy0 - 1; y <= cy0 + size; y++) {
    for (var x = cx0 - 1; x <= cx0 + size; x++) {
      final g = groundOf(x, y);
      final cell = ui.Path()..addPolygon([s(x + 0.0, y + 0.0), s(x + 1.0, y + 0.0), s(x + 1.0, y + 1.0), s(x + 0.0, y + 1.0)], true);
      c.drawPath(cell, ground(g));
      if (g == 'urban' || g == 'lit') mosaicCells.addPath(cell, ui.Offset.zero);
    }
  }
  // 2. Verdes (com a borda de 1 px) e água.
  for (final t in tiles) {
    for (final g in t.greens) {
      final p = rings(g);
      c.drawPath(p, ground('green'));
      c.drawPath(p, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 1..isAntiAlias = false..color = ui.Color(labColor('grass_dark')));
    }
    for (final g in t.waters) {
      c.drawPath(rings(g), ground('water'));
    }
  }
  // 3. O lote dos prédios: quintal com muro e portão no Residencial, a frente clara da loja no Iluminado.
  for (final b in buildings) {
    final ring = switch (b.look.biome) { 'residential' => 'yard', 'lit' => 'lit', 'sacred' => 'sacred', 'empty' => 'lot', _ => null };
    if (ring == null) continue;
    final wpx = (ring == 'yard' ? 4 + b.hash % 3 : 2) * kpm * 0.9;
    final path = poly(b.xy);
    if (ring == 'yard') {
      c.drawPath(path, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 2 * wpx + 2..strokeJoin = ui.StrokeJoin.miter..isAntiAlias = false..color = ui.Color(labColor('fence')));
    }
    c.drawPath(path, ground(ring)..style = ui.PaintingStyle.stroke..strokeWidth = 2 * wpx..strokeJoin = ui.StrokeJoin.miter);
    if (ring == 'yard' && !key.far) _gate(c, b, s, wpx);
  }
  // 4. Ruas: calçada (a portuguesa por cima nas células do Centro), meio-fio, asfalto, faixa central e faixa de pedestre.
  final roads = [for (final t in tiles) ...t.roads];
  final sidewalks = ui.Path();
  for (final r in roads) {
    final sw = sidewalkWidthM(r.cls);
    if (sw <= 0) continue;
    c.drawPath(line(r.xy), ground('sidewalk')..style = ui.PaintingStyle.stroke..strokeWidth = (roadWidthM(r.cls) + 2 * sw) * kpm..strokeCap = ui.StrokeCap.square);
    sidewalks.addPath(line(r.xy), ui.Offset.zero);
  }
  if (!key.far) {
    c.save();
    c.clipPath(mosaicCells, doAntiAlias: false);
    for (final r in roads) {
      final sw = sidewalkWidthM(r.cls);
      if (sw > 0) c.drawPath(line(r.xy), ground('sidewalk_mosaic')..style = ui.PaintingStyle.stroke..strokeWidth = (roadWidthM(r.cls) + 2 * sw) * kpm..strokeCap = ui.StrokeCap.square);
    }
    c.restore();
  }
  for (final r in roads) {
    if (r.cls == 'pedestrian') {
      c.drawPath(line(r.xy), ground('sidewalk')..style = ui.PaintingStyle.stroke..strokeWidth = math.max(2, roadWidthM(r.cls) * kpm));
      continue;
    }
    c.drawPath(line(r.xy), ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = roadWidthM(r.cls) * kpm + 2..isAntiAlias = false..color = ui.Color(labColor('sidewalk_dark')));
  }
  final asphalt = key.wet ? 'road_wet' : 'road';
  for (final r in roads) {
    if (r.cls != 'pedestrian') c.drawPath(line(r.xy), ground(asphalt)..style = ui.PaintingStyle.stroke..strokeWidth = roadWidthM(r.cls) * kpm..strokeCap = ui.StrokeCap.round);
  }
  if (!key.far) {
    for (final (ri, r) in roads.indexed) {
      if (r.cls == 'principal' || r.cls == 'secondary') _lanes(c, [for (var i = 0; i < r.xy.length; i += 2) s(r.xy[i], r.xy[i + 1])], ri + r.xy.length);
    }
  }
  for (final t in tiles) {
    for (final p in t.props) {
      if (p.kind == 'crosswalk') _crosswalk(c, p, s, kpm, f.angle);
    }
  }
  // 5. A planta dos prédios (por baixo das paredes e do telhado, desenhados a cada quadro).
  for (final b in buildings) {
    c.drawPath(poly(b.xy), _fill(wallStyleFor(b.look.styleType, b.look.biome).wallShade));
  }
  // 6. A luz quente da hora sobre o chão iluminado; depois as sombras, frias, num pano só (nunca escurecem duas vezes).
  final split = sceneLightSplit(sunAltDeg);
  c.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = ui.Color(split.warm).withValues(alpha: split.warmAlpha));
  if (sunAltDeg > 0) {
    final shadowA = ((labColor('shadow') >>> 24) & 0xff) / 255;
    c.saveLayer(null, ui.Paint()..color = ui.Color(0xFF000000).withValues(alpha: shadowA));
    final sp = _fill(mixArgb(0xFF1A1424, split.cool, split.coolAlpha));
    for (final b in buildings) {
      final off = shadowOffset(sunAltDeg, sunAzDeg, b.look.fakeHeightPx * kpm, rotationRad: f.angle);
      if (off == null) continue;
      final base = [for (var i = 0; i < b.xy.length; i += 2) s(b.xy[i], b.xy[i + 1])];
      final d = ui.Offset(off.$1, off.$2);
      c.drawPath(ui.Path()..addPolygon([for (final p in base) p + d], true), sp);
      for (var i = 0; i < base.length; i++) {
        final a = base[i], q = base[(i + 1) % base.length];
        c.drawPath(ui.Path()..addPolygon([a, q, q + d, a + d], true), sp);
      }
    }
    final tOff = shadowOffset(sunAltDeg, sunAzDeg, 6 * kpm, rotationRad: f.angle);
    if (tOff != null) {
      for (final t in tiles) {
        for (final p in t.props) {
          if (!p.kind.startsWith('tree') && !p.kind.startsWith('ipe')) continue;
          // A sombra da copa: do tamanho do carimbo (pixels de arte, como a copa, que não cresce com o zoom), deslocada pelo
          // sol a partir do pé da árvore.
          final img = art.stamp(p.kind) ?? art.stamp('tree');
          final r = (img?.width ?? 12) / 2 - 1;
          final q = s(p.x, p.y) + ui.Offset(tOff.$1, tOff.$2) * 0.5;
          c.drawOval(ui.Rect.fromCenter(center: q, width: 2 * r, height: 1.4 * r), sp);
        }
      }
    }
    c.restore();
  }
  // 7. À noite, as poças de luz dos postes no chão (sem o tom da hora por cima) e, com chuva, o reflexo no asfalto molhado.
  if (key.lights) {
    final glow = labColor('lamp_glow'), z = (kpm * 0.8).clamp(1.0, 1.5);
    for (final t in tiles) {
      for (final p in t.props) {
        if (p.kind != 'lamp') continue;
        final l = s(p.x, p.y);
        if (!key.far) {
          final r0 = 8 * z;
          final dot = _fill(glow)..color = ui.Color(glow).withValues(alpha: 0.10);
          for (var y = -r0; y <= r0; y++) {
            for (var x = -r0; x <= r0; x++) {
              final d = math.sqrt(x * x + y * y);
              if (d > r0 || d < 5 * z || (x + y).toInt().isOdd) continue;
              c.drawRect(ui.Rect.fromLTWH((l.dx + x).floorToDouble(), (l.dy + y).floorToDouble(), 1, 1), dot);
            }
          }
        }
        c.drawCircle(l, 5 * z, ui.Paint()..color = ui.Color(glow).withValues(alpha: 0.20));
        c.drawCircle(l, 3 * z, ui.Paint()..color = ui.Color(glow).withValues(alpha: 0.34));
        if (key.wet) {
          // O reflexo: uma faixa vertical curta e quebrada embaixo do poste (vertical na tela, como a luz refletida).
          final refl = _fill(labColor('lamp_reflect'));
          for (var y = 2; y < 2 + 7 * z; y++) {
            if ((y + p.hash) % 3 == 0) continue;
            final wv = y < 5 ? 2.0 : 1.0;
            c.drawRect(ui.Rect.fromLTWH(l.dx.floorToDouble() - (wv > 1 ? 1 : 0), l.dy.floorToDouble() + y, wv, 1), refl..color = ui.Color(labColor('lamp_reflect')).withValues(alpha: 0.55 - y * 0.04));
          }
        }
      }
    }
  }
  final pic = rec.endRecording();
  final img = pic.toImageSync(w, h);
  pic.dispose();
  return GroundChunk(img, left, top, f, key);
}

/// O portão no muro da casa: 3 a 4 px no meio da aresta mais longa (quase sempre a da rua nos lotes do bairro).
void _gate(ui.Canvas c, CityBuilding b, ui.Offset Function(double, double) s, double wpx) {
  var best = 0, bestL = -1.0;
  final n = b.length;
  for (var i = 0; i < n; i++) {
    final j = (i + 1) % n, dx = b.xy[2 * j] - b.xy[2 * i], dy = b.xy[2 * j + 1] - b.xy[2 * i + 1], l = dx * dx + dy * dy;
    if (l > bestL) (best, bestL) = (i, l);
  }
  final j = (best + 1) % n;
  final a = s(b.xy[2 * best], b.xy[2 * best + 1]), q = s(b.xy[2 * j], b.xy[2 * j + 1]);
  final mid = (a + q) / 2, dir = q - a, len = dir.distance;
  if (len < 4) return;
  final u = dir / len;
  final cen = (a + q) / 2;
  // A normal para fora do prédio: do centro do prédio para o meio da aresta.
  final cc = s(b.centroid.$1, b.centroid.$2);
  var nrm = ui.Offset(-u.dy, u.dx);
  if ((nrm.dx * (cen.dx - cc.dx) + nrm.dy * (cen.dy - cc.dy)) < 0) nrm = -nrm;
  final at = mid + nrm * (wpx + 0.5);
  final gw = 3 + b.hash % 2;
  for (var k = -gw ~/ 2; k <= gw ~/ 2; k++) {
    final p = at + u * k.toDouble();
    c.drawRect(ui.Rect.fromLTWH(p.dx.floorToDouble(), p.dy.floorToDouble(), 1, 1), _fill(labColor(k.isEven ? 'gate' : 'gate_dark')));
  }
}

/// Faixa central tracejada: 4 px aceso, 6 apagado, um em quatro gasto e um em sete faltando (hash do traço).
void _lanes(ui.Canvas canvas, List<ui.Offset> pts, int road) {
  final lane = _fill(labColor('lane')), worn = _fill(labColor('lane_worn'));
  var d = 0.0, n = 0;
  for (var i = 0; i + 1 < pts.length; i++) {
    final a = pts[i], b = pts[i + 1], len = (b - a).distance;
    if (len < 1) continue;
    final dir = (b - a) / len;
    for (var u = 0.0; u < len; u += 1) {
      final phase = (d + u) % 10;
      if (phase < 1) n++;
      if (phase >= 4) continue;
      final h = cityHash([road, n]);
      if (h % 7 == 0) continue;
      final p = a + dir * u;
      canvas.drawRect(ui.Rect.fromLTWH(p.dx.floorToDouble(), p.dy.floorToDouble(), 1, 1), h % 4 == 0 ? worn : lane);
    }
    d += len;
  }
}

/// A faixa de pedestre: barras de 1 px no sentido da rua, a cada 2 px através do asfalto, com uns 3 m de comprimento.
void _crosswalk(ui.Canvas c, CityProp p, ui.Offset Function(double, double) s, double kpm, double frameAngle) {
  final center = s(p.x, p.y);
  final a = p.angle + frameAngle;
  final along = ui.Offset(math.cos(a), math.sin(a)), across = ui.Offset(-along.dy, along.dx);
  final half = p.widthM / 2 * kpm, depth = 1.5 * kpm;
  final paint = _fill(labColor('crosswalk'));
  for (var v = -half + 1; v <= half - 1; v += 1) {
    if (((v + half).round()).isOdd) continue; // as barras correm ao longo da rua e se repetem através dela
    for (var u = -depth; u <= depth; u += 1) {
      final q = center + along * u + across * v;
      c.drawRect(ui.Rect.fromLTWH(q.dx.floorToDouble(), q.dy.floorToDouble(), 1, 1), paint);
    }
  }
}
