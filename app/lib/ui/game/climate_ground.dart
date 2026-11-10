/// A camada do MAPA do clima (docs/GDD.md, "Tempo, astronomia e clima": duas camadas). Tudo que está no chão: poças,
/// crateras, brasas e marcas queimadas, zonas (sombras de nuvem, do Sol Negro, prédios da Maré, olhares, runas, o olho do
/// furacão), a Procissão, a cobertura das ruas (água, neve, dunas, gelo, fuligem), a decoração presa ao chão, as pegadas e
/// os pares de sombra da Lua Dupla. Desenha em células z21 com a transformação da câmera (gira, move e dá zoom com o mapa),
/// em posições que saem do mundo ([ClimateWorld]) ou do hash da seed e do lugar: dois aparelhos veem tudo no mesmo ponto.
///
/// Os tamanhos de enfeite ficam em pixels de tela (como os spawns); os de mundo (poça, zona, cratera, rua), em metros.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/climate.dart';
import '../../core/fnv.dart';
import '../../data/climate_catalog.dart';
import '../../data/visual_pack.dart';
import '../../world/climate_world.dart';
import '../../world/map_camera.dart';
import '../../world/spawn_field.dart';
import '../../world/street_cover.dart';
import '../../world/veil_traffic.dart' show GhostLine;
import '../../world/visual_map.dart';

/// Os tipos da camada `ground` do `clima.json` que este arquivo desenha (o teste do catálogo confere).
const Set<String> groundLayerKinds = {'scatter', 'bands', 'streets', 'twins'};

/// Os estilos de peça desenhados no chão (zonas e poças) e as marcas dos impactos.
const Set<String> groundStyles = {'zone', 'puddle', 'ice', 'glow', 'whirl', 'ghost', 'figures', 'rune', 'eye', 'gaze'};
const Set<String> markStyles = {'burn', 'burn_violet', 'crater', 'ember'};

/// Alcance do mundo lido em volta do jogador (poças, marcas): basta o que cabe na tela de perto.
const double groundReadMaxM = 1500;

/// Uma coisa desenhada neste quadro, no mundo (células z21): os testes conferem que a posição não depende da câmera.
typedef PlacedMark = ({String kind, double x, double y});

ui.Color _c(int argb, double a) => ui.Color(argb).withValues(alpha: a.clamp(0.0, 1.0));

class ClimateGround {
  ClimateGround({required this.catalog, this.visual, this.roadWidthM = const {'principal': 12, 'secondary': 9, 'local': 6, 'pedestrian': 2}});

  final ClimateCatalog catalog;
  final VisualMap? visual;
  final Map<String, double> roadWidthM;

  /// O que o mundo tem em volta agora (lido a cada meio segundo por [observe]).
  List<ClimateZone> zones = const [];
  List<Puddle> puddles = const [];
  List<ClimateDrop> marks = const [];

  /// O que foi desenhado no último quadro, em coordenadas do mundo.
  final placed = <PlacedMark>[];

  final _fill = ui.Paint()..isAntiAlias = false;
  final _stroke = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;

  /// Lê do mundo as zonas, as poças e os impactos que ainda deixam marca, em volta de (px, py) (células z21).
  void observe(ClimateWorld w, {required double px, required double py, required double radius21, required double mpc, required int t}) {
    zones = w.zonesNear(px, py, radius21, t);
    final near = math.min(radius21, groundReadMaxM / mpc);
    puddles = w.puddlesNear(px, py, near, t);
    // Só olha para trás o tempo da marca mais longa dos climas daqui (agora e na janela anterior): a do raio é curta, a da
    // cratera dura horas.
    final cx20 = px.floor() >>> 1, cy20 = py.floor() >>> 1;
    var markS = 0.0;
    for (final def in [w.defAt(cx20, cy20, t), w.defAt(cx20, cy20, t - 10800)]) {
      for (final p in def?.pieces ?? const <ClimatePiece>[]) {
        if (p is DropPiece && p.impact) markS = math.max(markS, catalog.piece(p.name).markS);
      }
    }
    marks = markS <= 0
        ? const []
        : [
            for (final d in w.dropsNear(px, py, near, t - markS.ceil(), t))
              if (d.piece.impact && t - d.tUtc < catalog.piece(d.piece.name).markS) d,
          ];
  }

  /// A função de estado das ruas para o Tráfego do Véu com o clima [shown] (Dilúvio e areia), ou `null` se ele não mexe nas
  /// ruas; e a chave que muda quando ela muda (o tráfego refaz os caminhos).
  ({StreetState Function(GhostLine, double)? state, Object? key, bool skid}) trafficCover(int seed, ClimateInfo shown, PlayerClimate c) {
    final cover = streetCoverOf(shown);
    if (cover == null) return (state: null, key: null, skid: false);
    final window = c.windWindowStart ~/ 10800, start = c.runStartUtc;
    return (
      state: (line, t) => cover.stateOf(seed, line.key, line.roadClass, window, t - start),
      key: (shown.id, window),
      skid: cover.skid,
    );
  }

  /// Desenha a camada do mapa. [shown] é o clima que se vê (o mesmo da camada da tela); [c], o do mundo no jogador.
  void paint(
    ui.Canvas canvas,
    ui.Size view,
    MapCamera cam, {
    required double mpc,
    required double exactUtc,
    required int seed,
    required ClimateInfo shown,
    PlayerClimate c = PlayerClimate.none,
    List<WorldSpawn> ecos = const [],
    List<(double, double)> steps = const [],
    double playerX = 0,
    double playerY = 0,
    double night = 0,
    int localHour = 12,
    Map<String, ui.Image> sprites = const {},
    double ecoSizePx = 24,
    bool decor = true,
  }) {
    placed.clear();
    final ppc = cam.pixelsPerCell, px = 1 / ppc;
    final (l, top, r, b) = cam.visibleBounds(view.width, view.height);
    ui.Offset at(double x, double y) => ui.Offset(x - cam.centerX, y - cam.centerY);
    canvas.save();
    canvas.translate(view.width / 2, view.height / 2);
    canvas.rotate(cam.rotation);
    canvas.scale(ppc);
    final upright = <void Function()>[];
    // [decor] falso (o clima no mapa desligado nos Ajustes): só o que é do mundo (poças, zonas, marcas) continua.
    for (final (i, g) in decor ? shown.ground.indexed : const <(int, ClimateLayer)>[]) {
      if (!g.showsAtHour(localHour)) continue;
      switch (g.kind) {
        case 'streets' when ppc >= 2:
          _streets(canvas, g, seed, c, exactUtc, mpc, l, top, r, b, at);
        case 'bands':
          _bands(canvas, g, exactUtc, l, top, r, b, at);
        case 'scatter' when ppc >= 3:
          if (g.str('shape') == 'figure') {
            upright.add(() => _figures(canvas, view, cam, g, i, seed, playerX, playerY, mpc, l, top, r, b));
          } else {
            _scatter(canvas, g, i, seed, exactUtc, c, px, l, top, r, b, at);
          }
        case 'twins':
          upright.add(() => _twins(canvas, view, cam, g, ecos, sprites, ecoSizePx, mpc));
      }
    }
    // Só o que cai na tela (com folga): o mundo é lido num raio maior, para o pan não mostrar buraco.
    bool inView(double x, double y, double m) => x >= l - m && x <= r + m && y >= top - m && y <= b + m;
    for (final p in puddles) {
      if (inView(p.x, p.y, 2)) _puddle(canvas, p, catalog.piece(p.piece.name), mpc, px, night, exactUtc, at);
    }
    for (final z in zones) {
      final v = catalog.piece(z.piece.name);
      if (v.style == 'figures') {
        upright.add(() => _procession(canvas, view, cam, z, v, exactUtc, mpc));
      } else {
        _zone(canvas, z, v, exactUtc, mpc, px, at);
      }
    }
    for (final d in marks) {
      if (inView(d.x, d.y, 2)) _mark(canvas, d, catalog.piece(d.piece.name), exactUtc, mpc, px, at);
    }
    if (c.playerTrails) {
      for (final (x, y) in steps) {
        canvas.drawRect(ui.Rect.fromCenter(center: at(x, y), width: 3 * px, height: 2 * px), _fill..color = const ui.Color(0xFF8A8FA3).withValues(alpha: 0.6));
      }
    }
    if (c.ecoTracksM > 0) {
      // Pegadas que levam ao Eco: saem dele numa direção fixa pelo uid, até a distância do dado.
      for (final e in ecos) {
        final h = (e.uid >>> 20 & 0xffff) / 0xffff * 2 * math.pi;
        final n = (c.ecoTracksM / 4).floor();
        for (var i = 1; i <= n; i++) {
          final d = i * 4 / mpc;
          canvas.drawRect(ui.Rect.fromCenter(center: at(e.x + math.sin(h) * d + (i.isEven ? 2 : -2) * px, e.y - math.cos(h) * d), width: 2 * px, height: 2 * px), _fill..color = const ui.Color(0xFF8A8FA3).withValues(alpha: 0.5 * (1 - i / (n + 1))));
        }
      }
    }
    canvas.restore();
    // O que fica em pé na tela (figuras, pares de sombra): o ponto é do mundo, o desenho não gira.
    for (final f in upright) {
      f();
    }
  }

  void _streets(ui.Canvas canvas, ClimateLayer g, int seed, PlayerClimate c, double t, double mpc, double l, double top, double r, double b, ui.Offset Function(double, double) at) {
    final vm = visual;
    if (vm == null) return;
    final cover = StreetCover.fromLayer(g);
    final window = c.windWindowStart ~/ 10800, since = t - c.runStartUtc;
    final unit = vm.cellsPerTile / vm.pack.extent;
    final color = g.color(), alpha = g.val('alpha', 0.6);
    for (final (tx, ty) in vm.tilesIn(l, top, r, b, marginCells: 4)) {
      final tile = vm.tile(tx, ty);
      if (tile == null) continue;
      final x0 = tx * vm.cellsPerTile.toDouble(), y0 = ty * vm.cellsPerTile.toDouble();
      bool near(List<int> xy, int k) {
        final x = x0 + xy[2 * k] * unit, y = y0 + xy[2 * k + 1] * unit;
        return x >= l - 8 && x <= r + 8 && y >= top - 8 && y <= b + 8;
      }

      for (final (i, line) in tile.lines.indexed) {
        if (line.xy.length < 4) continue;
        // Corte rápido: a ponta, o meio ou a outra ponta perto da tela (os trechos do OSM são curtos).
        final n = line.xy.length ~/ 2;
        if (!near(line.xy, 0) && !near(line.xy, n - 1) && !near(line.xy, n ~/ 2)) continue;
        final lv = cover.level(seed, (tx, ty, i), line.roadClass, window, since);
        if (lv <= 0) continue;
        final w = (roadWidthM[line.roadClass.name] ?? 6) / mpc;
        var pts = [for (var k = 0; k + 1 < line.xy.length; k += 2) at(tx * vm.cellsPerTile + line.xy[k] * unit, ty * vm.cellsPerTile + line.xy[k + 1] * unit)];
        if (cover.kind == StreetCoverKind.sand) pts = _span(pts, cover.duneSpan(seed, (tx, ty, i), window));
        if (pts.length < 2) continue;
        final path = ui.Path()..addPolygon(pts, false);
        switch (cover.kind) {
          case StreetCoverKind.flood:
            canvas.drawPath(path, _stroke..strokeWidth = w * 1.15..color = _c(color, alpha * lv));
            canvas.drawPath(path, _stroke..strokeWidth = w * 0.25..color = _c(0xFFE8E4F4, 0.18 * lv * (0.6 + 0.4 * math.sin(t * 1.5 + i))));
          case StreetCoverKind.snow:
            final avenue = line.roadClass == RoadClass.principal || line.roadClass == RoadClass.secondary;
            if (cover.tracks && avenue && lv > 0.3) {
              // O tráfego abre duas trilhas: neve nas bordas, asfalto escuro nas trilhas, neve no meio.
              canvas.drawPath(path, _stroke..strokeWidth = w..color = _c(color, alpha * lv));
              canvas.drawPath(path, _stroke..strokeWidth = w * 0.6..color = _c(0xFF3A3350, 0.7));
              canvas.drawPath(path, _stroke..strokeWidth = w * 0.25..color = _c(color, alpha * lv));
            } else {
              canvas.drawPath(path, _stroke..strokeWidth = w..color = _c(color, alpha * lv));
            }
          case StreetCoverKind.sand:
            canvas.drawPath(path, _stroke..strokeWidth = w * 1.3..color = _c(color, alpha));
            canvas.drawPath(path, _stroke..strokeWidth = w * 0.3..color = _c(0xFFC9A46B, alpha * 0.8));
          case StreetCoverKind.ice:
            canvas.drawPath(path, _stroke..strokeWidth = w..color = _c(color, alpha * lv));
          case StreetCoverKind.soot:
            canvas.drawPath(path, _stroke..strokeWidth = w * 1.2..color = _c(color, alpha * lv));
        }
        placed.add((kind: 'street_${cover.kind.name}', x: tx * vm.cellsPerTile + line.xy[0] * unit, y: ty * vm.cellsPerTile + line.xy[1] * unit));
      }
    }
  }

  /// O trecho [span] (frações do comprimento) da polilinha.
  static List<ui.Offset> _span(List<ui.Offset> pts, (double, double) span) {
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

  void _bands(ui.Canvas canvas, ClimateLayer g, double t, double l, double top, double r, double b, ui.Offset Function(double, double) at) {
    const s = 6.0; // células (~100 m) entre faixas, presas ao chão
    final cs = g.colors.isEmpty ? [g.color()] : g.colors;
    final a = g.val('alpha', 0.12), speed = g.val('speed', 0.1);
    final drift = (t * speed) % s;
    for (var k = (top / s).floor() - 1; k <= (b / s).ceil(); k++) {
      final y = k * s + drift;
      final wave = math.sin(t * 0.6 + k) * 0.8;
      canvas.drawRect(ui.Rect.fromPoints(at(l - 2 + wave, y), at(r + 2 + wave, y + s * 0.3)), _fill..color = _c(cs[k.abs() % cs.length], a * (0.6 + 0.4 * math.sin(t * 1.1 + k * 1.7))));
    }
  }

  Iterable<(double, double, double)> _spots(ClimateLayer g, int layer, int seed, double l, double top, double r, double b) sync* {
    final cells = ((b / 4).floor() - (top / 4).floor() + 1) * ((r / 4).floor() - (l / 4).floor() + 1);
    // Teto de enfeites por camada e quadro (fps no celular): longe, a densidade cai por igual, e os pontos que ficam são
    // os mesmos de perto (os primeiros de cada célula).
    final per = math.min(g.val('per_cell', 3), 700 / math.max(1, cells));
    if (per <= 0) return;
    final n = per.floor(), frac = per - n;
    for (var cy = (top / 4).floor(); cy <= (b / 4).floor(); cy++) {
      for (var cx = (l / 4).floor(); cx <= (r / 4).floor(); cx++) {
        final base = fnv1a64Of3(cx ^ seed, cy, layer * 7919);
        final count = n + (((base >>> 8) & 0xffff) / 65536 < frac ? 1 : 0);
        for (var k = 0; k < count; k++) {
          final h = fnv1a64Of3(base, k, layer);
          yield ((cx + ((h >>> 40) & 0xffff) / 65536) * 4, (cy + ((h >>> 24) & 0xffff) / 65536) * 4, ((h >>> 8) & 0xffff) / 65536);
        }
      }
    }
  }

  void _scatter(ui.Canvas canvas, ClimateLayer g, int layer, int seed, double t, PlayerClimate c, double px, double l, double top, double r, double b, ui.Offset Function(double, double) at) {
    final shape = g.str('shape') ?? 'glint', twinkle = g.flag('twinkle');
    final cs = g.colors.isEmpty ? [g.color()] : g.colors;
    final a0 = g.val('alpha', 0.5);
    for (final (x, y, ph) in _spots(g, layer, seed, l, top, r, b)) {
      final a = twinkle ? a0 * (0.5 + 0.5 * math.sin(t * 3 + ph * 6.28)) : a0;
      if (a <= 0.02) continue;
      _fill.color = _c(cs[(ph * 97).floor() % cs.length], a);
      final o = at(x, y);
      switch (shape) {
        case 'frost':
          canvas.drawRect(ui.Rect.fromCenter(center: o, width: 3 * px, height: px), _fill);
          canvas.drawRect(ui.Rect.fromCenter(center: o, width: px, height: 3 * px), _fill);
        case 'leaf':
          canvas.drawRect(ui.Rect.fromCenter(center: o, width: (ph > 0.5 ? 3 : 2) * px, height: 2 * px), _fill);
        case 'branch':
          canvas.drawLine(o, o + ui.Offset(math.cos(ph * 6.28), math.sin(ph * 6.28)) * 6 * px, _stroke..strokeWidth = px..color = _fill.color);
        case 'ember':
          canvas.drawRect(ui.Rect.fromCenter(center: o, width: 5 * px, height: 5 * px), ui.Paint()..color = _fill.color.withValues(alpha: a * 0.25));
          canvas.drawRect(ui.Rect.fromCenter(center: o, width: 2 * px, height: 2 * px), _fill);
        case 'streak':
          final h = c.windHeadingRad;
          canvas.drawLine(o, o + ui.Offset(math.sin(h), -math.cos(h)) * 8 * px, _stroke..strokeWidth = px..color = _fill.color);
        case 'float':
          final k = 0.7 + 0.3 * math.sin(t * 1.4 + ph * 6.28);
          canvas.drawOval(ui.Rect.fromCenter(center: o, width: 6 * px * k, height: 3 * px * k), _fill);
        case 'glyph':
          canvas.drawRect(ui.Rect.fromLTWH(o.dx, o.dy, px, 4 * px), _fill);
          canvas.drawRect(ui.Rect.fromLTWH(o.dx + px, o.dy + px, px, px), _fill);
        case 'pixel':
          if (((t * 4).floor() + (ph * 1000).floor()) % 3 == 0) continue; // falha: some e volta
          canvas.drawRect(ui.Rect.fromCenter(center: o, width: 2 * px, height: 2 * px), _fill);
        default: // glint, hailstone, dust, ash
          canvas.drawRect(ui.Rect.fromCenter(center: o, width: 2 * px, height: 2 * px), _fill);
      }
    }
  }

  /// Vultos ao longe (Neblina): em pé na tela, num ponto do chão; somem perto do jogador ([near_m]).
  void _figures(ui.Canvas canvas, ui.Size view, MapCamera cam, ClimateLayer g, int layer, int seed, double px0, double py0, double mpc, double l, double top, double r, double b) {
    final near = g.val('near_m', 60);
    for (final (x, y, _) in _spots(g, layer, seed, l, top, r, b)) {
      final dM = math.sqrt((x - px0) * (x - px0) + (y - py0) * (y - py0)) * mpc;
      final k = ((dM - near * 0.6) / (near * 0.6)).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final (sx, sy) = cam.cellToScreen(x, y, view.width, view.height);
      _fill.color = _c(g.color(), g.val('alpha', 0.3) * k);
      canvas.drawRect(ui.Rect.fromLTWH(sx - 3, sy - 14, 6, 14), _fill);
      canvas.drawRect(ui.Rect.fromLTWH(sx - 2, sy - 19, 4, 4), _fill);
      placed.add((kind: 'figure', x: x, y: y));
    }
  }

  void _twins(ui.Canvas canvas, ui.Size view, MapCamera cam, ClimateLayer g, List<WorldSpawn> ecos, Map<String, ui.Image> sprites, double size, double mpc) {
    final chance = g.val('chance', 0.5);
    for (final e in ecos) {
      if (((e.uid >>> 16) & 0xffff) / 65536 >= chance) continue;
      // O par de sombra fica a 2 m a leste do Eco, no chão: gira com o mapa.
      final (sx, sy) = cam.cellToScreen(e.x + 2 / mpc, e.y, view.width, view.height);
      final img = sprites[e.entryId];
      final p = ui.Paint()..colorFilter = ui.ColorFilter.mode(_c(g.color(), g.val('alpha', 0.45)), ui.BlendMode.srcIn);
      final dst = ui.Rect.fromCenter(center: ui.Offset(sx, sy - size / 2), width: size, height: size);
      if (img != null) {
        canvas.drawImageRect(img, ui.Offset.zero & ui.Size(img.width.toDouble(), img.height.toDouble()), dst, p);
      } else {
        canvas.drawOval(dst.deflate(size * 0.2), ui.Paint()..color = _c(g.color(), g.val('alpha', 0.45)));
      }
      placed.add((kind: 'twin', x: e.x + 2 / mpc, y: e.y));
    }
  }

  void _puddle(ui.Canvas canvas, Puddle p, PieceVisual v, double mpc, double px, double night, double t, ui.Offset Function(double, double) at) {
    final r = math.max(2 * px, p.radiusM * p.size / mpc);
    final o = at(p.x, p.y);
    final rect = ui.Rect.fromCenter(center: o, width: r * 2, height: r * 1.3);
    placed.add((kind: 'puddle', x: p.x, y: p.y));
    if (v.style == 'ice') {
      canvas.drawOval(rect, _fill..color = _c(v.color, v.alpha));
      canvas.drawLine(o.translate(-r * 0.6, -r * 0.1), o.translate(r * 0.5, r * 0.2), _stroke..strokeWidth = px..color = _c(v.glow, 0.7));
      canvas.drawLine(o.translate(-r * 0.1, -r * 0.5), o.translate(r * 0.1, r * 0.4), _stroke..strokeWidth = px..color = _c(v.glow, 0.6));
      final k = 0.5 + 0.5 * math.sin(t * 2.5 + p.index);
      canvas.drawRect(ui.Rect.fromCenter(center: o.translate(r * 0.3, -r * 0.2), width: 2 * px, height: 2 * px), _fill..color = _c(0xFFFFFFFF, k)); // o cristal
      return;
    }
    if (!p.wet) canvas.drawOval(rect.inflate(px), _stroke..strokeWidth = px..color = _c(0xFF3A3350, 0.35)); // a marca de água secando
    canvas.drawOval(rect, _fill..color = _c(v.color, v.alpha));
    if (v.reflect) {
      // O céu na poça: claro de dia, escuro com uma estrela à noite.
      final sky = ui.Color.lerp(const ui.Color(0xFFE8E4F4), const ui.Color(0xFF2A2236), night)!;
      canvas.drawOval(ui.Rect.fromCenter(center: o.translate(-r * 0.25, -r * 0.12), width: r * 0.9, height: r * 0.35), _fill..color = sky.withValues(alpha: 0.35));
      if (night > 0.5) canvas.drawRect(ui.Rect.fromCenter(center: o.translate(r * 0.2, 0), width: px, height: px), _fill..color = _c(0xFFE8E4F4, 0.8));
    }
    if (v.prism) {
      const cs = [0xFFFF5A36, 0xFFFFE9A8, 0xFF6BD36A, 0xFF4AA8FF];
      for (var i = 0; i < cs.length; i++) {
        canvas.drawRect(ui.Rect.fromLTWH(o.dx - r * 0.5 + i * r * 0.25, o.dy + r * 0.1, r * 0.22, px), _fill..color = _c(cs[i], 0.6));
      }
    }
  }

  void _zone(ui.Canvas canvas, ClimateZone z, PieceVisual v, double t, double mpc, double px, ui.Offset Function(double, double) at) {
    final (cx, cy) = z.centerAt(t, mpc);
    final o = at(cx, cy);
    final r = z.piece.radiusM / mpc;
    final fade = (math.min(t - z.startUtc, z.endUtc - t) / 20).clamp(0.0, 1.0);
    final c = _c(v.color, v.alpha * fade);
    placed.add((kind: 'zone_${z.piece.name}', x: cx, y: cy));
    if (v.trail && z.piece.speedMps > 0) {
      // O rastro: pontos do começo até onde a zona está.
      final (x0, y0) = (z.x0, z.y0);
      final d = math.sqrt((cx - x0) * (cx - x0) + (cy - y0) * (cy - y0));
      for (var s = 0.0; s < d; s += 1.5) {
        canvas.drawRect(ui.Rect.fromCenter(center: at(x0 + (cx - x0) * s / d, y0 + (cy - y0) * s / d), width: 2 * px, height: 2 * px), _fill..color = _c(v.color, 0.35 * fade));
      }
    }
    switch (v.style) {
      case 'puddle':
        canvas.drawOval(ui.Rect.fromCenter(center: o, width: r * 2, height: r * 1.3), _fill..color = c);
        canvas.drawOval(ui.Rect.fromCenter(center: o.translate(-r * 0.3, -r * 0.15), width: r * 0.5, height: r * 0.15), _fill..color = _c(0xFFE8E4F4, 0.3 * fade));
      case 'glow':
        final k = 0.7 + 0.3 * math.sin(t * 2);
        canvas.drawCircle(o, r * k, _fill..color = c);
        canvas.drawCircle(o, r * 0.3, _fill..color = _c(v.color, math.min(1, v.alpha * 1.6 * fade)));
      case 'whirl':
        for (var i = 0; i < 5; i++) {
          final a = t * 4 + i * 1.2;
          canvas.drawCircle(o.translate(math.cos(a) * r * 0.5 * (1 - i / 6), math.sin(a) * r * 0.2 - i * r * 0.15), r * (0.25 + i * 0.08), _stroke..strokeWidth = 2 * px..color = c);
        }
      case 'ghost':
        final w = r * 1.4, h = r * 1.1;
        canvas.drawRect(ui.Rect.fromCenter(center: o, width: w, height: h), _fill..color = _c(v.color, v.alpha * 0.3 * fade));
        canvas.drawRect(ui.Rect.fromCenter(center: o, width: w, height: h), _stroke..strokeWidth = 2 * px..color = c);
        canvas.drawLine(o.translate(-w / 2, -h / 2), o.translate(0, -h), _stroke);
        canvas.drawLine(o.translate(w / 2, -h / 2), o.translate(0, -h), _stroke);
      case 'rune':
        final k = 0.6 + 0.4 * math.sin(t * 2 + z.index);
        canvas.drawCircle(o, r, _fill..color = _c(v.glow, 0.15 * fade));
        canvas.drawLine(o.translate(0, -r * 0.7), o.translate(0, r * 0.7), _stroke..strokeWidth = 2 * px..color = _c(v.color, v.alpha * k * fade));
        canvas.drawLine(o.translate(-r * 0.4, -r * 0.2), o.translate(r * 0.4, r * 0.3), _stroke);
      case 'eye':
        // O olho do furacão: o centro calmo e as bandas de chuva girando em volta.
        canvas.drawCircle(o, r, _fill..color = _c(v.glow, 0.08 * fade));
        for (var i = 0; i < 3; i++) {
          final rr = r * (1.4 + i * 0.6);
          canvas.drawArc(ui.Rect.fromCircle(center: o, radius: rr), t * (0.3 - i * 0.05) + i * 2.1, 2.2, false, _stroke..strokeWidth = r * 0.25..color = c);
        }
      case 'gaze':
        final k = 0.75 + 0.25 * math.sin(t * 1.8 + z.index);
        canvas.drawCircle(o, r * k, _fill..color = c);
        canvas.drawCircle(o, r * 0.35 * k, _fill..color = _c(v.glow, math.min(1, v.alpha * 1.5) * fade));
      default: // zone: sombra de nuvem, fuligem, cinza, sombra do Sol Negro
        canvas.drawCircle(o, r, _fill..color = c);
    }
  }

  /// A Procissão: figuras em fila atrás do centro da zona, em pé na tela.
  void _procession(ui.Canvas canvas, ui.Size view, MapCamera cam, ClimateZone z, PieceVisual v, double t, double mpc) {
    final (cx, cy) = z.centerAt(t, mpc);
    final fade = (math.min(t - z.startUtc, z.endUtc - t) / 20).clamp(0.0, 1.0);
    _fill.color = _c(v.color, v.alpha * fade);
    for (var i = 0; i < 6; i++) {
      final d = i * 1.6 / mpc;
      final (sx, sy) = cam.cellToScreen(cx - math.sin(z.headingRad) * d, cy + math.cos(z.headingRad) * d, view.width, view.height);
      final bob = (math.sin(t * 3 + i) * 1).roundToDouble();
      canvas.drawRect(ui.Rect.fromLTWH(sx - 3, sy - 14 + bob, 6, 14), _fill);
      canvas.drawRect(ui.Rect.fromLTWH(sx - 2, sy - 19 + bob, 4, 4), _fill);
    }
    placed.add((kind: 'procession', x: cx, y: cy));
  }

  void _mark(ui.Canvas canvas, ClimateDrop d, PieceVisual v, double t, double mpc, double px, ui.Offset Function(double, double) at) {
    final age = t - d.tUtc;
    if (age < 0 || v.markS <= 0 || age >= v.markS) return;
    final o = at(d.x, d.y);
    final glowing = age < v.glowS;
    placed.add((kind: glowing ? '${v.mark}_glow' : v.mark!, x: d.x, y: d.y));
    switch (v.mark) {
      case 'crater':
        // A cratera: um anel escuro que brilha por dentro por algumas horas e depois some aos poucos.
        final r = math.max(6 * px, 5 / mpc);
        final fade = glowing ? 1.0 : 1 - (age - v.glowS) / (v.markS - v.glowS);
        canvas.drawOval(ui.Rect.fromCenter(center: o, width: r * 2.4, height: r * 1.6), _fill..color = _c(0xFF1A1424, 0.6 * fade));
        canvas.drawOval(ui.Rect.fromCenter(center: o, width: r * 2.4, height: r * 1.6), _stroke..strokeWidth = 2 * px..color = _c(0xFFC9A46B, 0.5 * fade));
        if (glowing) {
          final k = 0.7 + 0.3 * math.sin(t * 2 + d.index) - 0.3 * age / v.glowS;
          canvas.drawOval(ui.Rect.fromCenter(center: o, width: r * 1.2, height: r * 0.8), _fill..color = _c(v.glow, 0.75 * k));
          canvas.drawRect(ui.Rect.fromCenter(center: o, width: 3 * px, height: 3 * px), _fill..color = _c(v.color, 0.95));
        }
      case 'ember' when glowing:
        final k = 0.6 + 0.4 * math.sin(t * 9 + d.index * 3);
        canvas.drawRect(ui.Rect.fromCenter(center: o, width: 8 * px, height: 5 * px), _fill..color = _c(0xFF1A1424, 0.6));
        canvas.drawRect(ui.Rect.fromCenter(center: o, width: 6 * px, height: 3 * px), _fill..color = _c(v.glow, 0.8 * k));
        canvas.drawRect(ui.Rect.fromCenter(center: o.translate(0, -3 * px - (t * 6 % 6) * px), width: px, height: px), _fill..color = _c(v.color, 0.7)); // fagulha subindo
      default: // marca queimada (raio, raio violeta, brasa apagada)
        final a = 0.55 * (1 - age / v.markS);
        canvas.drawOval(ui.Rect.fromCenter(center: o, width: 18 * px, height: 9 * px), _fill..color = _c(0xFF1A1424, a));
        canvas.drawRect(ui.Rect.fromCenter(center: o, width: 4 * px, height: 2 * px), _fill..color = _c(v.mark == 'burn_violet' ? 0xFF9B7BFF : 0xFFFF7A45, a * 0.6));
    }
  }
}
