/// O que fica de pé no estilo Completo (0.22.0), desenhado a cada quadro por cima do chão do cache, na orientação da tela:
/// paredes e telhados com altura falsa (GTA 2: o telhado sai do centro da tela para fora, em qualquer giro), janelas por
/// andar, platibanda, caixa d'água, ar-condicionado e antena, letreiro e neon, neve no telhado, árvores (ipê pela época
/// do ano), postes, ponto de ônibus e banca. Um telhado ou copa sobre algo do jogo fica translúcido. Por último, a faixa do
/// céu com a névoa ao longe. Só desenho; desenha em pixels de arte (o buffer é ampliado por quem chama).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../world/city_scene.dart';
import '../../world/lab_block.dart' show facesSun, isClockwise, roofPoint, shadowOffset, wallVisible;
import '../lab/lab_art.dart';
import '../lab/lab_renderer.dart' show Matrix4Lite;
import '../sprites/map_style.dart';
import 'city_ground.dart';

ui.Paint _fill(int argb) => ui.Paint()
  ..color = ui.Color(argb)
  ..isAntiAlias = false;

/// O estado de um quadro do que fica de pé.
class UprightView {
  const UprightView({
    required this.frame,
    required this.offset,
    required this.size,
    required this.mpc,
    required this.sunAltDeg,
    required this.sunAzDeg,
    required this.localHour,
    required this.month,
    required this.far,
    required this.snowRoofs,
    required this.items,
    this.skyPx = 0,
    this.skyClimate = 'clear',
  });

  /// O quadro exato (o giro e o zoom de agora) e o deslocamento inteiro dele até o buffer.
  final CityFrame frame;
  final ui.Offset offset;
  final ui.Size size;
  final double mpc, sunAltDeg, sunAzDeg;
  final int localHour, month;

  /// Nível de detalhe do zoom aberto: sem janelas, props de telhado, letreiros e detalhes finos.
  final bool far;

  /// Neve e geada acumulam também nos telhados.
  final bool snowRoofs;

  /// Onde estão as coisas do jogo (avatar, Ecos, Fagulhas, materiais), em pixels de arte do buffer.
  final List<ui.Offset> items;

  /// A altura da faixa do céu em pixels de arte (0: sem faixa) e o clima de base (o céu muda de cor).
  final int skyPx;
  final String skyClimate;

  ui.Offset at(double x, double y) => frame.map(x, y) + offset;
  double get kpm => frame.kc / mpc;
}

/// Quantos prédios, árvores e props saíram no último quadro, e quantos ficaram translúcidos (debug e teste).
class UprightStats {
  int buildings = 0, translucent = 0, props = 0, windows = 0, roofProps = 0;
}

class CityUpright {
  CityUpright(this.art);

  final LabArt art;
  final stats = UprightStats();
  final _lit = <(ui.Rect, int)>[];
  final _neon = <(ui.Offset, int)>[];

  /// Os telhados do último quadro (teste: o telhado translúcido e a neve deslocada).
  final roofs = <CityBuilding, ui.Path>{};
  final translucentOf = <CityBuilding>{};

  void paint(ui.Canvas c, UprightView v, List<CityTile> tiles) {
    stats
      ..buildings = 0
      ..translucent = 0
      ..props = 0
      ..windows = 0
      ..roofProps = 0;
    _lit.clear();
    _neon.clear();
    roofs.clear();
    translucentOf.clear();
    final view = (ui.Offset.zero & v.size).inflate(40);
    final center = ui.Offset(v.size.width / 2, v.size.height / 2);
    final kpm = v.kpm;
    final lights = lightsOn(v.sunAltDeg);
    final split = sceneLightSplit(v.sunAltDeg);
    final shadowDir = shadowOffset(v.sunAltDeg, v.sunAzDeg, 1, rotationRad: v.frame.angle);
    // Prédios do mais longe do centro da tela para o mais perto (o perto cobre o longe).
    final order = <(CityBuilding, List<ui.Offset>, double)>[];
    for (final t in tiles) {
      for (final b in t.buildings) {
        final (cx, cy) = b.centroid;
        final cp = v.at(cx, cy);
        if (!view.contains(cp)) continue;
        order.add((b, [for (var i = 0; i < b.xy.length; i += 2) v.at(b.xy[i], b.xy[i + 1])], (cp - center).distanceSquared));
      }
    }
    order.sort((a, b) => b.$3.compareTo(a.$3));
    final camPx = 160 * kpm / 1.1, maxPx = 16 * kpm / 1.1;
    c.saveLayer(null, ui.Paint()); // o tom da hora vai por cima de tudo isto (srcATop), antes das luzes
    for (final (b, base, _) in order) {
      final h = b.look.fakeHeightPx * kpm;
      final roof = [for (final p in base) () { final r = roofPoint((p.dx, p.dy), (center.dx, center.dy), h, cameraPx: camPx, maxPx: maxPx); return ui.Offset(r.$1, r.$2); }()];
      final roofPath = ui.Path()..addPolygon(roof, true);
      roofs[b] = roofPath;
      // Só os itens dentro da caixa do prédio (base e telhado) chegam ao teste do contorno.
      var l = double.infinity, t = double.infinity, r = -double.infinity, bt = -double.infinity;
      for (final p in [...base, ...roof]) {
        l = math.min(l, p.dx);
        r = math.max(r, p.dx);
        t = math.min(t, p.dy);
        bt = math.max(bt, p.dy);
      }
      final see = v.items.any((p) => p.dx >= l && p.dx <= r && p.dy >= t && p.dy <= bt && (_inside(p, roof) || _inside(p, base)));
      if (see) {
        translucentOf.add(b);
        stats.translucent++;
        c.saveLayer(null, ui.Paint()..color = const ui.Color(0x73FFFFFF)); // 45%
      }
      _building(c, b, base, roof, roofPath, center, kpm, v, lights, split, shadowDir);
      if (see) c.restore();
      stats.buildings++;
    }
    // Árvores (a copa sobe um pouco, como um telhado baixo), postes, ponto de ônibus e banca: de pé, na tela.
    final stamps = <(String, ui.Offset, bool)>[];
    for (final t in tiles) {
      for (final p in t.props) {
        if (p.kind == 'crosswalk') continue;
        final q = v.at(p.x, p.y);
        if (!view.contains(q)) continue;
        if (p.kind == 'lamp' || p.kind == 'bus_stop' || p.kind == 'newsstand') {
          stamps.add((p.kind, q, false));
          continue;
        }
        final kind = switch (p.kind) { 'ipe_purple' => ipeStamp('purple', v.month), 'ipe_yellow' => ipeStamp('yellow', v.month), _ => p.kind };
        final r = roofPoint((q.dx, q.dy), (center.dx, center.dy), 6 * kpm, cameraPx: camPx, maxPx: maxPx);
        final at = ui.Offset(r.$1, r.$2);
        final img = art.stamp(kind) ?? art.stamp('tree');
        final half = img == null ? 6.0 : img.width / 2 + 1;
        stamps.add((kind, at, v.items.any((i) => (i - at).dx.abs() < half && (i - at).dy.abs() < half)));
      }
    }
    // Os mais baixos na tela por cima: a copa da frente cobre a de trás.
    stamps.sort((a, b) => a.$2.dy.compareTo(b.$2.dy));
    for (final (kind, at, see) in stamps) {
      if (see) c.saveLayer(null, ui.Paint()..color = const ui.Color(0x73FFFFFF));
      _stamp(c, art.stamp(kind) != null ? kind : 'tree', at, lights);
      if (see) c.restore();
      stats.props++;
    }
    // O tom da hora: quente no que está de pé (o lado de sombra já saiu frio nas paredes).
    c.drawRect(ui.Offset.zero & v.size, ui.Paint()..color = ui.Color(split.warm).withValues(alpha: split.warmAlpha)..blendMode = ui.BlendMode.srcATop);
    c.restore();
    // As luzes, sem tom por cima: janelas acesas e neon.
    for (final (r, col) in _lit) {
      c.drawRect(r, _fill(col));
    }
    for (final (p, col) in _neon) {
      c.drawCircle(p, 6, ui.Paint()..color = ui.Color(col).withValues(alpha: 0.35));
      c.drawRect(ui.Rect.fromCenter(center: p, width: 3, height: 2), _fill(col));
    }
    if (v.skyPx > 0) _skyBand(c, v);
  }

  ui.Image? _sky;
  String? _skyKey;

  /// A faixa do céu fica numa imagem, refeita só quando muda a largura, a altura, o sol (1 grau), o clima ou o rumo (2 graus).
  void _skyBand(ui.Canvas c, UprightView v) {
    final w = v.size.width.ceil();
    final key = '$w|${v.skyPx}|${v.sunAltDeg.round()}|${(v.sunAzDeg / 2).round()}|${v.skyClimate}|${(v.frame.angle * 90 / math.pi).round()}';
    if (key != _skyKey) {
      _skyKey = key;
      final rec = ui.PictureRecorder();
      paintSkyBand(ui.Canvas(rec), w.toDouble(), v);
      _sky?.dispose();
      _sky = rec.endRecording().toImageSync(w, v.skyPx * 4 + 2);
    }
    c.drawImage(_sky!, ui.Offset.zero, ui.Paint()..filterQuality = ui.FilterQuality.none);
  }

  static bool _inside(ui.Offset p, List<ui.Offset> poly) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) && p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) inside = !inside;
    }
    return inside;
  }

  void _stamp(ui.Canvas c, String name, ui.Offset at, bool lights) {
    final img = art.stamp(name, lightsOn: lights);
    if (img == null) return;
    c.drawImage(img, ui.Offset((at.dx - img.width / 2).roundToDouble(), (at.dy - img.height / 2).roundToDouble()), ui.Paint()..filterQuality = ui.FilterQuality.none);
  }

  void _building(ui.Canvas c, CityBuilding b, List<ui.Offset> base, List<ui.Offset> rp, ui.Path roofPath, ui.Offset center, double kpm, UprightView v, bool lights, ({int warm, double warmAlpha, int cool, double coolAlpha}) split, (double, double)? shadowDir) {
    final variants = roofVariantsFor(b.look.styleType, b.look.biome);
    final st = variants.isEmpty ? wallStyleFor(b.look.styleType, b.look.biome) : variants[b.hash % variants.length];
    final altWall = b.look.biome == 'residential' && b.hash % 3 == 0;
    final wall = altWall ? labColor('wall_res_b') : st.wall, shade = mixArgb(altWall ? labColor('wall_res_b_shade') : st.wallShade, split.cool, split.coolAlpha);
    final bp = [for (final p in base) (p.dx, p.dy)];
    final cw = isClockwise(bp);
    final litPct = switch (b.look.biome) { 'residential' => 45, 'urban' => 30, 'lit' => 85, 'sacred' => 15, _ => 20 };
    final floorH = floorPx * kpm;
    for (var i = 0; i < base.length; i++) {
      final j = (i + 1) % base.length;
      if (!wallVisible(bp[i], bp[j], (center.dx, center.dy), clockwise: cw)) continue;
      final sunny = v.sunAltDeg > 0 && facesSun(bp[i], bp[j], shadowDir, clockwise: cw);
      c.drawPath(ui.Path()..addPolygon([base[i], base[j], rp[j], rp[i]], true), _fill(sunny ? wall : shade));
      if (v.far || st.window.isEmpty) continue;
      // Janelas: uma fileira por andar que aparece; fachada baixa (menos de 2 andares à vista) leva uma fileira no meio.
      final hv = (((rp[i] + rp[j]) / 2) - ((base[i] + base[j]) / 2)).distance;
      if (hv < 3) continue;
      final floors = math.max(1, b.look.fakeHeightPx ~/ floorPx);
      final rows = hv >= 2 * floorH && floors >= 2 ? math.min(floors, (hv / math.max(3, hv / floors)).floor()) : 1;
      final len = (base[j] - base[i]).distance, shop = st.window == 'window_shop';
      final step = shop ? 7.0 : 5.0;
      for (var row = 0; row < rows; row++) {
        final up = rows == 1 ? 0.5 : (row + 0.55) / rows;
        if (shop && row > 0) continue; // vitrine só no térreo
        for (var u = step / 2; u < len - 1; u += step) {
          final t = u / len;
          final p = ui.Offset.lerp(ui.Offset.lerp(base[i], base[j], t), ui.Offset.lerp(rp[i], rp[j], t), up)!;
          final r = ui.Rect.fromCenter(center: ui.Offset(p.dx.roundToDouble(), p.dy.roundToDouble()), width: shop ? 3 : 2, height: rows > 1 ? 1 : 2);
          final hh = cityHash([b.hash, (u * 10).round(), i, row]);
          final on = lights && hh % 100 < litPct && !(b.look.biome == 'residential' && v.localHour < 5 && cityHash([b.hash, i]) % 2 == 0);
          stats.windows++;
          if (on) {
            _lit.add((r, labColor(shop ? 'window_on_cool' : 'window_on')));
          } else {
            c.drawRect(r, _fill(labColor('window_off')));
          }
        }
      }
    }
    c.drawPath(
      roofPath,
      ui.Paint()
        ..isAntiAlias = false
        ..filterQuality = ui.FilterQuality.none
        ..shader = ui.ImageShader(art.stamp(st.roofPattern) ?? art.pattern('urban'), ui.TileMode.repeated, ui.TileMode.repeated, Matrix4Lite.translate(rp.first.dx.roundToDouble(), rp.first.dy.roundToDouble())),
    );
    if (st.parapet != 0 && !v.far) {
      // A platibanda: 1 px por dentro da borda.
      c.save();
      c.clipPath(roofPath, doAntiAlias: false);
      c.drawPath(roofPath, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 3..isAntiAlias = false..color = ui.Color(st.parapet));
      c.restore();
    }
    c.drawPath(roofPath, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 1..isAntiAlias = false..color = ui.Color(st.roofEdge));
    final rc = rp.fold(ui.Offset.zero, (a, p) => a + p) / rp.length.toDouble();
    if (v.snowRoofs) _snow(c, roofPath, rp.first);
    final area = b.length < 3 ? 0.0 : _area(rp);
    if (!v.far && st.roofProps.isNotEmpty && area >= 60) {
      // De um a três props, perto do centro do telhado e dentro dele (hash do prédio).
      final n = area >= 400 ? 3 : (area >= 150 ? 2 : 1);
      for (var k = 0; k < n; k++) {
        final hh = cityHash([b.hash, k, 7]);
        final name = st.roofProps[hh % st.roofProps.length];
        final spread = math.sqrt(area) * 0.25;
        final at = rc + ui.Offset(((hh >>> 4) % 100 / 50 - 1) * spread, ((hh >>> 11) % 100 / 50 - 1) * spread);
        if (!roofPath.contains(at)) continue;
        _stamp(c, name, at, lights);
        stats.roofProps++;
      }
    }
    if (b.look.biome == 'lit' && !v.far) {
      var best = 0, far = -1.0;
      for (var i = 0; i < rp.length; i++) {
        final m = (rp[i] + rp[(i + 1) % rp.length]) / 2;
        final d = (m - center).distanceSquared;
        if (d > far) (best, far) = (i, d);
      }
      final m = (rp[best] + rp[(best + 1) % rp.length]) / 2;
      const signs = ['sign_bar', 'sign_blade', 'neon_ring', 'neon_arrow'];
      _stamp(c, signs[b.hash % signs.length], m, lights);
      if (lights) _neon.add((m, labColor(const ['neon_a', 'neon_b', 'neon_c'][b.hash % 3])));
    }
  }

  /// A neve no telhado: um módulo pontilhado claro, ancorado no telhado deslocado (acumula onde o telhado está na tela).
  late final ui.Image _snowTex = () {
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    final snow = _fill(labColor('snow')), shade = _fill(labColor('snow_shade'));
    for (var y = 0; y < 32; y++) {
      for (var x = 0; x < 32; x++) {
        final h = cityHash([x, y, 0x534e]) % 10;
        if (h < 7) c.drawRect(ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), h < 6 ? snow : shade);
      }
    }
    return rec.endRecording().toImageSync(32, 32);
  }();

  void _snow(ui.Canvas c, ui.Path roof, ui.Offset at) => c.drawPath(
        roof,
        ui.Paint()
          ..isAntiAlias = false
          ..filterQuality = ui.FilterQuality.none
          ..shader = ui.ImageShader(_snowTex, ui.TileMode.repeated, ui.TileMode.repeated, Matrix4Lite.translate(at.dx.roundToDouble(), at.dy.roundToDouble())),
      );

  static double _area(List<ui.Offset> p) {
    var a = 0.0;
    for (var i = 0; i < p.length; i++) {
      final q = p[(i + 1) % p.length];
      a += p[i].dx * q.dy - q.dx * p[i].dy;
    }
    return a.abs() / 2;
  }
}

/// A faixa do céu no topo (no máximo 10% da tela) e, embaixo dela, a névoa de distância que dissolve o topo do mapa no céu:
/// a cor da névoa pontilhada, cada vez mais rala, sem linha dura.
void paintSkyBand(ui.Canvas c, double w, UprightView v) {
  final (mix, force) = switch (v.skyClimate) {
    'cloudy' => (0xFF8A8FA3, 0.45),
    'drizzle' || 'rain' => (0xFF6C7186, 0.60),
    'storm' => (0xFF3D4254, 0.75),
    'fog' => (0xFFC2C0D2, 0.70),
    'strong_sun' => (0xFFFFF0D0, 0.15),
    _ => (0, 0.0),
  };
  final cols = [for (final g in skyGradient(v.sunAltDeg)) force > 0 ? mixArgb(g, mix, force) : g];
  final sky = v.skyPx;
  final band = sky / cols.length;
  final p = ui.Paint()..isAntiAlias = false;
  for (var i = 0; i < cols.length; i++) {
    c.drawRect(ui.Rect.fromLTWH(0, (i * band).floorToDouble(), w, band.ceilToDouble() + 1), p..color = ui.Color(cols[i]));
  }
  // Pontilhado entre as bandas (sem gradiente contínuo).
  for (var i = 1; i < cols.length; i++) {
    final y = (i * band).floorToDouble();
    for (var x = 0.0; x < w; x += 2) {
      c.drawRect(ui.Rect.fromLTWH(x + (i.isEven ? 0 : 1), y - 1, 1, 1), p..color = ui.Color(cols[i]));
    }
  }
  // Sol no azimute dele, quando o céu está aberto: -60 a +60 graus em volta do topo da tela ocupam a largura.
  final heading = -v.frame.angle * 180 / math.pi;
  final d = ((v.sunAzDeg - heading + 540) % 360) - 180;
  if (v.sunAltDeg > -4 && force < 0.45 && d.abs() <= 60) {
    c.drawCircle(ui.Offset((d / 120 + 0.5) * w, (sky - 3 - v.sunAltDeg.clamp(-4, 60) / 60 * (sky - 6)).toDouble()), math.min(4, sky / 4), p..color = const ui.Color(0xFFFFF4C8));
  }
  // A névoa: a cor de baixo do céu sobre o mapa, de 85% a 5%, num pontilhado ordenado (Bayer 4 × 4), por [fogRows].
  final fog = ui.Color(force > 0 ? mixArgb(horizonFog(v.sunAltDeg), mix, force) : horizonFog(v.sunAltDeg));
  // A névoa começa da cor do céu (sem linha) e rareia devagar, numa curva: nenhuma fileira cheia, nenhuma borda dura.
  final fogRows = math.max(6, (sky * (v.skyClimate == 'fog' ? 2.4 : 1.4)).round());
  const bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
  final fp = ui.Paint()..isAntiAlias = false..color = fog;
  for (var y = 0; y < fogRows; y++) {
    final u = 1 - y / fogRows;
    final keep = 0.94 * u * u;
    for (var x = 0; x < w; x++) {
      if (bayer[(y % 4) * 4 + x % 4] / 16 < keep) c.drawRect(ui.Rect.fromLTWH(x.toDouble(), sky + y.toDouble(), 1, 1), fp);
    }
  }
}
