/// O que fica de pé no estilo Completo (0.22.0), desenhado a cada quadro por cima do chão do cache, na orientação da tela:
/// paredes e telhados com altura falsa (GTA 2: o telhado sai do centro da tela para fora, em qualquer giro), janelas por
/// andar, platibanda, caixa d'água, ar-condicionado e antena, letreiro e neon, neve no telhado, árvores (ipê pela época
/// do ano), postes, ponto de ônibus e banca. Um telhado ou copa sobre algo do jogo fica translúcido. Por último, a faixa do
/// céu com a névoa ao longe. Só desenho; desenha em pixels de arte (o buffer é ampliado por quem chama).
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../world/city_scene.dart';
import '../../world/lab_block.dart' show facesSun, isClockwise, roofPoint, shadowOffset, wallVisible;
import '../lab/lab_art.dart';
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

  /// 0.23.1: tudo o que saiu no último quadro, na ordem do desenho: o nome do carimbo (ou `building`), o retângulo no buffer
  /// e o ponto do chão (células z21) a que ele pertence. O teste de giro compara os pixels de cada sprite de pé em dois giros.
  final drawn = <({String name, ui.Rect rect, (double, double) anchor})>[];

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
    drawn.clear();
    final view = (ui.Offset.zero & v.size).inflate(40);
    final center = ui.Offset(v.size.width / 2, v.size.height / 2);
    final kpm = v.kpm;
    final lights = lightsOn(v.sunAltDeg);
    final split = sceneLightSplit(v.sunAltDeg);
    final shadowDir = shadowOffset(v.sunAltDeg, v.sunAzDeg, 1, rotationRad: v.frame.angle);
    // Prédios do mais longe do centro da tela para o mais perto (o perto cobre o longe).
    final order = <(CityBuilding, List<ui.Offset>, double)>[];
    // 0.23.2: entra todo prédio cujo contorno toca a tela (com a folga do maior deslocamento do telhado), não só o de centro
    // na tela: um shopping com o centro fora dela perdia telhado e parede e sobrava só a planta escura no chão.
    final lean = 16 * kpm / 1.1;
    final reach = view.inflate(lean);
    for (final t in tiles) {
      for (final b in t.buildings) {
        final (cx, cy) = b.centroid;
        final cp = v.at(cx, cy);
        if (!reach.contains(cp)) {
          final (l, tp, r, bt) = b.bounds;
          final cs = [v.at(l, tp), v.at(r, tp), v.at(r, bt), v.at(l, bt)];
          final box = ui.Rect.fromLTRB(cs.map((p) => p.dx).reduce(math.min), cs.map((p) => p.dy).reduce(math.min), cs.map((p) => p.dx).reduce(math.max), cs.map((p) => p.dy).reduce(math.max));
          if (!box.overlaps(reach)) continue;
        }
        order.add((b, [for (var i = 0; i < b.xy.length; i += 2) v.at(b.xy[i], b.xy[i + 1])], (cp - center).distanceSquared));
      }
    }
    order.sort((a, b) => b.$3.compareTo(a.$3));
    final camPx = 160 * kpm / 1.1, maxPx = 16 * kpm / 1.1;
    _treeShadows(c, v, tiles, view, split);
    c.saveLayer(null, ui.Paint()); // o tom da hora vai por cima de tudo isto (srcATop), antes das luzes
    for (final (b, base, _) in order) {
      final h = b.look.fakeHeightPx * kpm;
      final roof = [for (final p in base) () { final r = roofPoint((p.dx, p.dy), (center.dx, center.dy), h, cameraPx: camPx, maxPx: maxPx, halfScreen: (center.dx, center.dy)); return ui.Offset(r.$1, r.$2); }()];
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
      drawn.add((name: 'building', rect: ui.Rect.fromPoints(ui.Offset(l, t), ui.Offset(r, bt)), anchor: b.centroid));
      _building(c, b, base, roof, roofPath, center, kpm, v, lights, split, shadowDir, camPx, maxPx);
      if (see) c.restore();
      stats.buildings++;
    }
    // Árvores (a copa sobe um pouco, como um telhado baixo), postes, ponto de ônibus e banca: de pé, na tela.
    final stamps = <(String, ui.Offset, bool, (double, double))>[];
    for (final t in tiles) {
      for (final p in t.props) {
        if (p.kind == 'crosswalk') continue;
        final q = v.at(p.x, p.y);
        if (!view.contains(q)) continue;
        if (p.kind == 'lamp' || p.kind == 'bus_stop' || p.kind == 'newsstand' || p.kind == 'street_sign') {
          stamps.add((p.kind, q, false, (p.x, p.y)));
          continue;
        }
        final kind = switch (p.kind) { 'ipe_purple' => ipeStamp('purple', v.month), 'ipe_yellow' => ipeStamp('yellow', v.month), _ => p.kind };
        final r = roofPoint((q.dx, q.dy), (center.dx, center.dy), 6 * kpm, cameraPx: camPx, maxPx: maxPx, halfScreen: (center.dx, center.dy));
        final at = ui.Offset(r.$1, r.$2);
        final img = art.stamp(kind) ?? art.stamp('tree');
        final half = img == null ? 6.0 : img.width / 2 + 1;
        stamps.add((kind, at, v.items.any((i) => (i - at).dx.abs() < half && (i - at).dy.abs() < half), (p.x, p.y)));
      }
    }
    // Os mais baixos na tela por cima: a copa da frente cobre a de trás.
    stamps.sort((a, b) => a.$2.dy.compareTo(b.$2.dy));
    for (final (kind, at, see, anchor) in stamps) {
      if (see) c.saveLayer(null, ui.Paint()..color = const ui.Color(0x73FFFFFF));
      _stamp(c, art.stamp(kind) != null ? kind : 'tree', at, lights, anchor);
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

  /// Um carimbo de pé: a imagem sem giro nem escala, só na posição. [anchor]: o ponto do chão dele (células z21).
  void _stamp(ui.Canvas c, String name, ui.Offset at, bool lights, (double, double) anchor) {
    final img = art.stamp(name, lightsOn: lights);
    if (img == null) return;
    final tl = ui.Offset((at.dx - img.width / 2).roundToDouble(), (at.dy - img.height / 2).roundToDouble());
    c.drawImage(img, tl, ui.Paint()..filterQuality = ui.FilterQuality.none);
    drawn.add((name: name, rect: tl & ui.Size(img.width.toDouble(), img.height.toDouble()), anchor: anchor));
  }

  /// 0.23.1: a sombra de cada árvore é a silhueta do próprio carimbo achatada a 70%, de pé como a copa (no chão ela girava com
  /// o mapa e a copa parecia mudar de forma). Sai antes dos prédios, sem o tom quente, num pano só (não escurece duas vezes).
  void _treeShadows(ui.Canvas c, UprightView v, List<CityTile> tiles, ui.Rect view, ({int warm, double warmAlpha, int cool, double coolAlpha}) split) {
    if (v.sunAltDeg <= 0) return;
    final off = shadowOffset(v.sunAltDeg, v.sunAzDeg, 6 * v.kpm, rotationRad: v.frame.angle);
    if (off == null) return;
    final shadowA = ((labColor('shadow') >>> 24) & 0xff) / 255;
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.none
      ..colorFilter = ui.ColorFilter.mode(ui.Color(mixArgb(0xFF000000 | labColor('shadow'), split.cool, split.coolAlpha)), ui.BlendMode.srcIn);
    var open = false;
    for (final t in tiles) {
      for (final p in t.props) {
        if (!p.kind.startsWith('tree') && !p.kind.startsWith('ipe')) continue;
        final q = v.at(p.x, p.y) + ui.Offset(off.$1, off.$2) * 0.5;
        if (!view.contains(q)) continue;
        final kind = switch (p.kind) { 'ipe_purple' => ipeStamp('purple', v.month), 'ipe_yellow' => ipeStamp('yellow', v.month), _ => p.kind };
        final img = art.stamp(kind) ?? art.stamp('tree');
        if (img == null) continue;
        if (!open) {
          c.saveLayer(null, ui.Paint()..color = ui.Color(0xFF000000).withValues(alpha: shadowA));
          open = true;
        }
        final sw = img.width.toDouble(), sh = (img.height * 0.7).roundToDouble();
        c.drawImageRect(img, ui.Rect.fromLTWH(0, 0, sw, img.height.toDouble()), ui.Rect.fromLTWH((q.dx - sw / 2).roundToDouble(), (q.dy - sh / 2).roundToDouble(), sw, sh), paint);
      }
    }
    if (open) c.restore();
  }

  void _building(ui.Canvas c, CityBuilding b, List<ui.Offset> base, List<ui.Offset> rp, ui.Path roofPath, ui.Offset center, double kpm, UprightView v, bool lights, ({int warm, double warmAlpha, int cool, double coolAlpha}) split, (double, double)? shadowDir, double camPx, double maxPx) {
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
        ..shader = ui.ImageShader(art.stamp(st.roofPattern) ?? art.pattern('urban'), ui.TileMode.repeated, ui.TileMode.repeated, roofTextureMatrix(rp)),
    );
    if (st.parapet != 0 && !v.far) {
      // A platibanda: 1 px por dentro da borda.
      c.save();
      c.clipPath(roofPath, doAntiAlias: false);
      c.drawPath(roofPath, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 3..isAntiAlias = false..color = ui.Color(st.parapet));
      c.restore();
    }
    c.drawPath(roofPath, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 1..isAntiAlias = false..color = ui.Color(st.roofEdge));
    if (v.snowRoofs) _snow(c, roofPath, roofTextureMatrix(rp));
    final area = b.length < 3 ? 0.0 : _area(rp);
    if (!v.far && st.roofProps.isNotEmpty && area >= 60) {
      // De um a três props perto do centro do telhado (hash do prédio). 0.23.1: o lugar sai do chão (células z21, em volta do
      // centro do contorno) e sobe como o telhado: gira e anda com o prédio; o carimbo fica de pé (antes o deslocamento era
      // na tela, e o prop corria em volta do telhado ao girar o mapa).
      final n = area >= 400 ? 3 : (area >= 150 ? 2 : 1);
      final (bx, by) = b.centroid;
      final spread = math.sqrt(_cellArea(b.xy)) * 0.25;
      final h = b.look.fakeHeightPx * kpm;
      for (var k = 0; k < n; k++) {
        final hh = cityHash([b.hash, k, 7]);
        final name = st.roofProps[hh % st.roofProps.length];
        final gx = bx + ((hh >>> 4) % 100 / 50 - 1) * spread, gy = by + ((hh >>> 11) % 100 / 50 - 1) * spread;
        final q = v.at(gx, gy);
        final r = roofPoint((q.dx, q.dy), (center.dx, center.dy), h, cameraPx: camPx, maxPx: maxPx, halfScreen: (center.dx, center.dy));
        final at = ui.Offset(r.$1, r.$2);
        if (!roofPath.contains(at)) continue;
        _stamp(c, name, at, lights, (gx, gy));
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
      _stamp(c, signs[b.hash % signs.length], m, lights, b.centroid);
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

  void _snow(ui.Canvas c, ui.Path roof, Float64List m) => c.drawPath(
        roof,
        ui.Paint()
          ..isAntiAlias = false
          ..filterQuality = ui.FilterQuality.none
          ..shader = ui.ImageShader(_snowTex, ui.TileMode.repeated, ui.TileMode.repeated, m),
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

/// 0.22.2: a textura do telhado é do prédio. As linhas do módulo ficam paralelas à aresta mais longa do contorno e a
/// textura gira e anda exatamente com ele, presa no começo dessa aresta: nunca desliza, nunca gira sozinha, nunca fica
/// presa à tela.
/// A área do contorno em células z21 ao quadrado.
double _cellArea(Float64List xy) {
  var a = 0.0;
  for (var i = 0; i < xy.length; i += 2) {
    final j = (i + 2) % xy.length;
    a += xy[i] * xy[j + 1] - xy[j] * xy[i + 1];
  }
  return a.abs() / 2;
}

Float64List roofTextureMatrix(List<ui.Offset> rp) {
  var best = 0, len = -1.0;
  for (var i = 0; i < rp.length; i++) {
    final d = (rp[(i + 1) % rp.length] - rp[i]).distanceSquared;
    if (d > len) (best, len) = (i, d);
  }
  final a = rp[best], b = rp[(best + 1) % rp.length];
  final ang = math.atan2(b.dy - a.dy, b.dx - a.dx), c = math.cos(ang), sn = math.sin(ang);
  return Float64List.fromList([c, sn, 0, 0, -sn, c, 0, 0, 0, 0, 1, 0, a.dx, a.dy, 0, 1]);
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
  // A névoa: a cor de baixo do céu sobre o mapa, rareando até sumir (0.23.2: faixa curta, sem xadrez).
  final fog = ui.Color(force > 0 ? mixArgb(horizonFog(v.sunAltDeg), mix, force) : horizonFog(v.sunAltDeg));
  // 0.23.2 (criativo): a névoa numa faixa curta, um ponto por pixel de arte, com limiar de ruído de gradiente intercalado
  // (IGN) no pixel da tela, sem matriz: sem nível de 50% em xadrez e sem grade de pontos a cada 4 px.
  final fogRows = math.max(5, (sky * (v.skyClimate == 'fog' ? 1.1 : 0.55)).round());
  final fp = ui.Paint()..isAntiAlias = false..color = fog;
  for (var y = 0; y < fogRows; y++) {
    final u = 1 - (y + 0.5) / fogRows;
    final keep = 0.85 * math.pow(u, 1.6);
    for (var x = 0; x < w; x++) {
      final t = (52.9829189 * ((0.06711056 * x + 0.00583715 * y) % 1)) % 1;
      if (t < keep) c.drawRect(ui.Rect.fromLTWH(x.toDouble(), sky + y.toDouble(), 1, 1), fp);
    }
  }
}
