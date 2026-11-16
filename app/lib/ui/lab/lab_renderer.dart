/// O desenho do Laboratório visual (0.21.0, só debug): o quarteirão fixo no estilo de hoje ("antes") e no estilo novo
/// ("depois", `docs/art/estilo-mapa.md`): chão com pontilhado e carimbos por bioma, rua com faixa, calçada, quintal e muro,
/// prédios com altura falsa (GTA 2) e sombra pelo sol, árvores, postes, a luz da hora e, à noite, poças de luz, janelas e
/// neon. Desenha em pixels de arte num buffer pequeno, ampliado por vizinho mais próximo por quem chama.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/biomes.dart';
import '../../world/lab_block.dart';
import '../game/art_style.dart';
import '../sprites/map_style.dart';
import 'lab_art.dart';

/// A câmera e a luz de um quadro.
class LabView {
  const LabView({required this.cx, required this.cy, required this.rotation, required this.pxPerM, required this.sunAltDeg, required this.sunAzDeg, required this.localHour});

  /// O centro da tela no quarteirão (metros), o giro do mapa (radianos) e o zoom (pixels de arte por metro).
  final double cx, cy, rotation, pxPerM;
  final double sunAltDeg, sunAzDeg;
  final int localHour;
}

ui.Paint _fill(int argb) => ui.Paint()
  ..color = ui.Color(argb)
  ..isAntiAlias = false;

int _h(int a, int b) {
  var x = (a * 73856093) ^ (b * 19349663) ^ 0x2c1b3c6d;
  x = (x * 1103515245 + 12345) & 0x7fffffff;
  return (x * 1103515245 + 12345) & 0x7fffffff;
}

class LabRenderer {
  LabRenderer(this.block, this.art, BiomeSet biomes) : _old = ArtStyle(biomes) {
    _trees = _plantTrees();
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
  late final List<Pt> _trees;

  /// O que acende à noite, recolhido no quadro (desenhado depois do tom da hora).
  final _windows = <(ui.Rect, int)>[];
  final _neon = <(ui.Offset, int)>[];
  final _lamps = <ui.Offset>[];

  /// O telhado de cada prédio no quadro (a sombra do vizinho e as poças de luz são recortadas por eles).
  final _roofs = <LabBuilding, ui.Path>{};

  /// Árvores do OSM e, sem elas, plantadas por hash nos verdes (uma a cada ~500 px² de arte, em grupos) e ao longo das
  /// ruas principais.
  List<Pt> _plantTrees() {
    final out = [...block.trees];
    for (final (gi, g) in block.greens.indexed) {
      var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
      for (final p in g) {
        minX = math.min(minX, p.$1);
        minY = math.min(minY, p.$2);
        maxX = math.max(maxX, p.$1);
        maxY = math.max(maxY, p.$2);
      }
      for (var y = minY; y < maxY; y += 14) {
        for (var x = minX; x < maxX; x += 14) {
          final h = _h((x * 10).round() + gi, (y * 10).round());
          if (h % 100 > 38) continue;
          final p = (x + (h >> 8) % 9 - 4.0, y + (h >> 12) % 9 - 4.0);
          if (_inside(p, g)) out.add(p);
        }
      }
    }
    return out;
  }

  static bool _inside(Pt p, List<Pt> poly) {
    var c = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.$2 > p.$2) != (b.$2 > p.$2) && p.$1 < (b.$1 - a.$1) * (p.$2 - a.$2) / (b.$2 - a.$2) + a.$1) c = !c;
    }
    return c;
  }

  /// Desenha o quarteirão em [size] pixels de arte. [after]: o estilo novo; senão o de hoje.
  /// [baseGround]: o chão de fundo (o Urbano no quarteirão; a cena de um bioma no catálogo usa o dele).
  void paint(ui.Canvas canvas, ui.Size size, LabView v, {required bool after, String baseGround = 'urban'}) {
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

    if (!after) return _before(canvas, size, v, poly, line);
    final origin = s((0, 0));
    ui.Paint ground(String key, [ui.Offset? at]) {
      final img = art.patterns[key] ?? art.patterns['urban']!;
      final o = at ?? origin;
      return ui.Paint()
        ..isAntiAlias = false
        ..filterQuality = ui.FilterQuality.none
        ..shader = ui.ImageShader(img, ui.TileMode.repeated, ui.TileMode.repeated, (Matrix4Lite.translate(o.dx.roundToDouble(), o.dy.roundToDouble())));
    }

    final lights = lightsOn(v.sunAltDeg);
    _windows.clear();
    _neon.clear();
    _lamps.clear();
    // 1. Chão: concreto do Urbano, lotes vazios, verdes, água.
    canvas.drawRect(ui.Offset.zero & size, ground(baseGround));
    for (final l in block.lots) {
      canvas.drawPath(poly(l), ground('lot'));
    }
    for (final g in block.greens) {
      canvas.drawPath(poly(g), ground('green'));
      canvas.drawPath(poly(g), ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 1..isAntiAlias = false..color = ui.Color(labColor('grass_dark')));
    }
    for (final w in block.waters) {
      canvas.drawPath(poly(w), ground('water'));
    }
    // 2. O lote de cada prédio pelo bioma dele: quintal com muro no Residencial, piso claro no Iluminado.
    for (final b in block.buildings) {
      final ring = switch (b.biome) {
        'residential' => 'yard',
        'lit' => 'lit',
        'sacred' => 'sacred',
        'empty' => 'lot',
        _ => null,
      };
      if (ring == null) continue;
      // O quintal tem de 4 a 6 px; o piso claro do Iluminado é só a frente da loja (2 px), senão cobre o Centro inteiro.
      final w = (ring == 'yard' ? 4 + b.hash % 3 : 2) * k;
      final path = poly(b.pts);
      if (ring == 'yard') {
        canvas.drawPath(path, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 2 * w + 2..strokeJoin = ui.StrokeJoin.miter..isAntiAlias = false..color = ui.Color(labColor('fence')));
      }
      canvas.drawPath(path, ground(ring)..style = ui.PaintingStyle.stroke..strokeWidth = 2 * w..strokeJoin = ui.StrokeJoin.miter);
    }
    // 3. Ruas: calçada, meio-fio, asfalto e faixa, cada camada em todas as ruas antes da próxima (os cruzamentos fecham).
    for (final r in block.roads) {
      final sw = sidewalkWidthM(r.cls);
      if (sw > 0) canvas.drawPath(line(r.pts), ground('sidewalk')..style = ui.PaintingStyle.stroke..strokeWidth = (roadWidthM(r.cls) + 2 * sw) * k..strokeCap = ui.StrokeCap.square);
    }
    for (final r in block.roads) {
      if (r.cls == 'pedestrian') {
        canvas.drawPath(line(r.pts), ground('sidewalk')..style = ui.PaintingStyle.stroke..strokeWidth = math.max(2, roadWidthM(r.cls) * k));
        continue;
      }
      canvas.drawPath(line(r.pts), ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = roadWidthM(r.cls) * k + 2..isAntiAlias = false..color = ui.Color(labColor('sidewalk_dark')));
    }
    for (final r in block.roads) {
      if (r.cls != 'pedestrian') canvas.drawPath(line(r.pts), ground('road')..style = ui.PaintingStyle.stroke..strokeWidth = roadWidthM(r.cls) * k..strokeCap = ui.StrokeCap.round);
    }
    for (final (ri, r) in block.roads.indexed) {
      if (r.cls == 'principal' || r.cls == 'secondary') _lanes(canvas, [for (final p in r.pts) s(p)], ri);
      if (r.cls != 'pedestrian') _lampsAlong(r, ri, s, k);
    }
    // 4. Sombras (do sol, no chão), num só pano para não escurecer duas vezes onde se cruzam.
    // Cada pedaço da sombra é um caminho próprio: num caminho só, as faces de sentidos opostos se anulam.
    final shadows = <ui.Path>[];
    final sun = v.sunAltDeg > 0;
    for (final b in block.buildings) {
      final off = shadowOffset(v.sunAltDeg, v.sunAzDeg, b.fakeHeightPx * k, rotationRad: v.rotation);
      if (off == null) continue;
      final base = [for (final p in b.pts) s(p)];
      final o = ui.Offset(off.$1, off.$2);
      shadows.add(ui.Path()..addPolygon([for (final p in base) p + o], true));
      for (var i = 0; i < base.length; i++) {
        final a = base[i], c = base[(i + 1) % base.length];
        shadows.add(ui.Path()..addPolygon([a, c, c + o, a + o], true));
      }
    }
    if (sun) {
      canvas.saveLayer(ui.Offset.zero & size, ui.Paint()..color = ui.Color(labColor('shadow') & 0xFF000000));
      final sp = _fill(0xFF1A1424);
      for (final p in shadows) {
        canvas.drawPath(p, sp);
      }
      final tOff = shadowOffset(v.sunAltDeg, v.sunAzDeg, 6 * k, rotationRad: v.rotation);
      for (final t in _trees) {
        final p = s(t);
        if (tOff != null) canvas.drawOval(ui.Rect.fromCenter(center: p + ui.Offset(tOff.$1, tOff.$2) * 0.6, width: 12 * k, height: 9 * k), sp);
      }
      canvas.restore();
    }
    // 5. Prédios do mais longe do centro da tela para o mais perto: paredes visíveis, janelas, telhado, letreiro.
    final c0 = (center.dx, center.dy);
    final order = [...block.buildings]..sort((a, b) {
        final pa = s(a.centroid) - center, pb = s(b.centroid) - center;
        return pb.distanceSquared.compareTo(pa.distanceSquared);
      });
    _roofs.clear();
    for (final b in order) {
      _building(canvas, b, [for (final p in b.pts) s(p)], c0, k, v, lights, ground);
    }
    // A sombra do prédio alto sobre o telhado do vizinho mais baixo (o `criativo`): a planta de A na altura de C, varrida
    // pelo sol pela diferença de altura, recortada no telhado de C.
    if (sun) {
      canvas.saveLayer(ui.Offset.zero & size, ui.Paint()..color = ui.Color(labColor('shadow') & 0xFF000000));
      final sp = _fill(0xFF1A1424);
      // Os centros na tela uma vez só; só os prédios que aparecem projetam (e recebem) a sombra.
      final view = (ui.Offset.zero & size).inflate(60);
      final on = [for (final b in block.buildings) if (_roofs.containsKey(b) && view.contains(s(b.centroid))) (b, s(b.centroid))];
      for (final (a, ca) in on) {
        final reach = 3 * a.fakeHeightPx * k + 40;
        for (final (c, cc) in on) {
          if (identical(a, c) || c.fakeHeightPx > a.fakeHeightPx - 3) continue;
          if ((cc - ca).distanceSquared > reach * reach) continue;
          final roofC = _roofs[c];
          final off = shadowOffset(v.sunAltDeg, v.sunAzDeg, (a.fakeHeightPx - c.fakeHeightPx) * k, rotationRad: v.rotation);
          if (roofC == null || off == null) continue;
          final o = ui.Offset(off.$1, off.$2);
          final at = [for (final p in a.pts) () { final q = s(p); final r = roofPoint((q.dx, q.dy), c0, c.fakeHeightPx * k); return ui.Offset(r.$1, r.$2); }()];
          canvas.save();
          canvas.clipPath(roofC);
          canvas.drawPath(ui.Path()..addPolygon([for (final p in at) p + o], true), sp);
          for (var i = 0; i < at.length; i++) {
            final p = at[i], q = at[(i + 1) % at.length];
            canvas.drawPath(ui.Path()..addPolygon([p, q, q + o, p + o], true), sp);
          }
          canvas.restore();
        }
      }
      canvas.restore();
    }
    // 6. Árvores e postes, em pé (a copa sobe um pouco, como um telhado baixo).
    for (final t in _trees) {
      final p = s(t);
      final r = roofPoint((p.dx, p.dy), c0, 6 * k);
      _stamp(canvas, 'tree', ui.Offset(r.$1, r.$2), lightsOn: lights);
    }
    for (final l in _lamps) {
      _stamp(canvas, 'lamp', l, lightsOn: lights);
    }
    // 7. A luz da hora por cima de tudo; o que acende vem depois, sem tom.
    final light = sceneLight(v.sunAltDeg);
    canvas.drawRect(ui.Offset.zero & size, ui.Paint()..color = ui.Color(light.argb).withValues(alpha: light.alpha));
    if (lights) {
      // Poças de luz pequenas, só no chão (fora dos telhados), com o anel de fora em xadrez de 1 px.
      final glow = labColor('lamp_glow'), z = (k * 0.8).clamp(1.0, 1.5);
      final ground = ui.Path()..fillType = ui.PathFillType.evenOdd..addRect(ui.Offset.zero & size);
      for (final r in _roofs.values) {
        ground.addPath(r, ui.Offset.zero);
      }
      canvas.save();
      canvas.clipPath(ground);
      final checker = _fill(glow);
      for (final l in _lamps) {
        final r0 = 8 * z;
        for (var y = -r0; y <= r0; y++) {
          for (var x = -r0; x <= r0; x++) {
            final d = math.sqrt(x * x + y * y);
            if (d > r0 || d < 5 * z || (x + y).toInt().isOdd) continue;
            canvas.drawRect(ui.Rect.fromLTWH((l.dx + x).floorToDouble(), (l.dy + y).floorToDouble(), 1, 1), checker..color = ui.Color(glow).withValues(alpha: 0.10));
          }
        }
        canvas.drawCircle(l, 5 * z, ui.Paint()..color = ui.Color(glow).withValues(alpha: 0.20));
        canvas.drawCircle(l, 3 * z, ui.Paint()..color = ui.Color(glow).withValues(alpha: 0.34));
      }
      canvas.restore();
      for (final (r, c) in _windows) {
        canvas.drawRect(r, _fill(c));
      }
      for (final (p, c) in _neon) {
        canvas.drawCircle(p, 6, ui.Paint()..color = ui.Color(c).withValues(alpha: 0.35));
        canvas.drawRect(ui.Rect.fromCenter(center: p, width: 3, height: 2), _fill(c));
      }
    }
  }

  void _stamp(ui.Canvas canvas, String name, ui.Offset at, {bool lightsOn = true}) {
    final img = art.stamp(name, lightsOn: lightsOn);
    if (img == null) return;
    canvas.drawImage(img, ui.Offset((at.dx - img.width / 2).roundToDouble(), (at.dy - img.height / 2).roundToDouble()), ui.Paint()..filterQuality = ui.FilterQuality.none);
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
        final h = _h(road, n);
        if (h % 7 == 0) continue;
        final p = a + dir * u;
        canvas.drawRect(ui.Rect.fromLTWH(p.dx.floorToDouble(), p.dy.floorToDouble(), 1, 1), h % 4 == 0 ? worn : lane);
      }
      d += len;
    }
  }

  /// Postes nas calçadas: um a cada 30 m nas principais e secundárias (lados alternados), 45 m nas locais.
  void _lampsAlong(({String cls, List<Pt> pts}) r, int ri, ui.Offset Function(Pt) s, double k) {
    final every = r.cls == 'local' ? 60.0 : 40.0, side = roadWidthM(r.cls) / 2 + sidewalkWidthM(r.cls) / 2;
    var acc = 15.0, n = 0;
    for (var i = 0; i + 1 < r.pts.length; i++) {
      final a = r.pts[i], b = r.pts[i + 1];
      final dx = b.$1 - a.$1, dy = b.$2 - a.$2, len = math.sqrt(dx * dx + dy * dy);
      if (len < 0.5) continue;
      while (acc < len) {
        final t = acc / len, sign = n.isEven ? 1 : -1;
        final p = s((a.$1 + dx * t - dy / len * side * sign, a.$2 + dy * t + dx / len * side * sign));
        if (!_lamps.any((o) => (o - p).distance < 18 * k)) _lamps.add(p);
        n++;
        acc += every;
      }
      acc -= len;
    }
  }

  void _building(ui.Canvas canvas, LabBuilding b, List<ui.Offset> base, Pt center, double k, LabView v, bool lights, ui.Paint Function(String, [ui.Offset?]) ground) {
    final st = wallStyleFor(b.styleType, b.biome);
    final altWall = b.biome == 'residential' && b.hash % 3 == 0;
    final wall = altWall ? labColor('wall_res_b') : st.wall, shade = altWall ? labColor('wall_res_b_shade') : st.wallShade;
    final h = b.fakeHeightPx * k;
    final roof = [for (final p in base) roofPoint((p.dx, p.dy), center, h)];
    final rp = [for (final r in roof) ui.Offset(r.$1, r.$2)];
    final bp = [for (final p in base) (p.dx, p.dy)];
    final cw = isClockwise(bp);
    final off = shadowOffset(v.sunAltDeg, v.sunAzDeg, 1, rotationRad: v.rotation);
    final litPct = switch (b.biome) {
      'residential' => 45,
      'urban' => 30,
      'lit' => 85,
      'sacred' => 15,
      _ => 20,
    };
    for (var i = 0; i < base.length; i++) {
      final j = (i + 1) % base.length;
      if (!wallVisible(bp[i], bp[j], center, clockwise: cw)) continue;
      final quad = ui.Path()..addPolygon([base[i], base[j], rp[j], rp[i]], true);
      final sunny = v.sunAltDeg > 0 && facesSun(bp[i], bp[j], off, clockwise: cw);
      canvas.drawPath(quad, _fill(sunny ? wall : shade));
      // Janelas no meio da parede, se ela aparece com 3 px ou mais.
      final mid = (base[i] + base[j]) / 2, top = (rp[i] + rp[j]) / 2;
      if ((top - mid).distance < 3 || st.window.isEmpty) continue;
      final len = (base[j] - base[i]).distance, shop = st.window == 'window_shop';
      final step = shop ? 7.0 : 5.0;
      for (var u = step / 2; u < len - 1; u += step) {
        final t = u / len;
        final p = ui.Offset.lerp(ui.Offset.lerp(base[i], base[j], t), ui.Offset.lerp(rp[i], rp[j], t), 0.5)!;
        final r = ui.Rect.fromCenter(center: ui.Offset(p.dx.roundToDouble(), p.dy.roundToDouble()), width: shop ? 3 : 2, height: 2);
        final on = lights && _h(b.hash, (u * 10).round() + i * 997) % 100 < litPct && !(b.biome == 'residential' && (v.localHour >= 0 && v.localHour < 5) && _h(b.hash, i) % 2 == 0);
        if (on) {
          _windows.add((r, labColor(shop ? 'window_on_cool' : 'window_on')));
        } else {
          canvas.drawRect(r, _fill(labColor('window_off')));
        }
      }
    }
    final roofPath = ui.Path()..addPolygon(rp, true);
    _roofs[b] = roofPath;
    canvas.drawPath(
      roofPath,
      ui.Paint()
        ..isAntiAlias = false
        ..filterQuality = ui.FilterQuality.none
        ..shader = ui.ImageShader(art.stamp(st.roofPattern) ?? art.patterns['urban']!, ui.TileMode.repeated, ui.TileMode.repeated, Matrix4Lite.translate(rp.first.dx.roundToDouble(), rp.first.dy.roundToDouble())),
    );
    canvas.drawPath(roofPath, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 1..isAntiAlias = false..color = ui.Color(st.roofEdge));
    // A caixa d'água na laje grande (o `criativo`).
    if (st.roofPattern == 'roof_slab' && b.areaM2 * k * k >= 150) {
      final c = rp.fold(ui.Offset.zero, (a, p) => a + p) / rp.length.toDouble();
      _stamp(canvas, 'roof_tank', c + ui.Offset((b.hash % 7 - 3).toDouble(), ((b.hash >> 3) % 7 - 3).toDouble()), lightsOn: lights);
    }
    // Letreiro no Iluminado: na borda do telhado mais longe do centro da tela; a cor do neon sai do prédio.
    if (b.biome == 'lit') {
      var best = 0, far = -1.0;
      for (var i = 0; i < rp.length; i++) {
        final m = (rp[i] + rp[(i + 1) % rp.length]) / 2;
        final d = (m - ui.Offset(center.$1, center.$2)).distanceSquared;
        if (d > far) (best, far) = (i, d);
      }
      final m = (rp[best] + rp[(best + 1) % rp.length]) / 2;
      const signs = ['sign_bar', 'sign_blade', 'neon_ring', 'neon_arrow'];
      _stamp(canvas, signs[b.hash % signs.length], m, lightsOn: lights);
      if (lights) _neon.add((m, labColor(const ['neon_a', 'neon_b', 'neon_c'][b.hash % 3])));
    }
  }

  /// O estilo de hoje (`art_renderer.dart`): chão neutro, verdes e água com borda, calçada e rua, sem prédio; a noite é um
  /// tom escuro por cima.
  void _before(ui.Canvas canvas, ui.Size size, LabView v, ui.Path Function(List<Pt>) poly, ui.Path Function(List<Pt>) line) {
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
