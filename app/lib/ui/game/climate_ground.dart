/// A camada do MAPA do clima (docs/GDD.md, "Tempo, astronomia e clima": duas camadas). Tudo que está no chão: poças,
/// crateras, brasas e marcas queimadas, zonas (sombras de nuvem, do Sol Negro, prédios da Maré, olhares, runas, o olho do
/// furacão), a Procissão, a cobertura das ruas (água, neve, dunas, gelo, fuligem), a decoração presa ao chão, as pegadas e
/// os pares de sombra da Lua Dupla. Desenha em células z21 com a transformação da câmera (gira, move e dá zoom com o mapa),
/// em posições que saem do mundo ([ClimateWorld]) ou do hash da seed e do lugar: dois aparelhos veem tudo no mesmo ponto.
///
/// Os tamanhos de enfeite ficam em pixels de tela (como os spawns); os de mundo (poça, zona, cratera, rua), em metros.
///
/// Nada aparece pronto (`climate_form.dart`): cada camada se forma em `grow_s` desde o começo do clima no lugar e, quando ele
/// acaba, seca ou derrete em `fade_s`. O começo e o fim vêm do mundo ([PlayerClimate]), iguais em dois aparelhos.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/climate.dart';
import '../../core/fnv.dart';
import '../../data/climate_catalog.dart';
import '../../world/climate_form.dart';
import '../../world/climate_world.dart';
import '../../world/map_camera.dart';
import '../../world/procession.dart';
import '../../world/spawn_field.dart';
import '../../world/street_cover.dart';
import '../../world/traffic_graph.dart';
import '../../world/visual_map.dart';
import 'climate_cover.dart';
import 'climate_procession.dart';
import 'climate_puddle.dart';

/// Os tipos da camada `ground` do `clima.json` que este arquivo desenha (o teste do catálogo confere).
const Set<String> groundLayerKinds = {'scatter', 'bands', 'streets', 'twins'};

/// Os estilos de peça desenhados no chão (zonas e poças) e as marcas dos impactos.
const Set<String> groundStyles = {'zone', 'puddle', 'ice', 'glow', 'whirl', 'ghost', 'figures', 'rune', 'eye', 'gaze', 'shadow'};
const Set<String> markStyles = {'burn', 'burn_violet', 'crater', 'ember'};

/// Alcance do mundo lido em volta do jogador (poças, marcas): basta o que cabe na tela de perto.
const double groundReadMaxM = 1500;

/// Uma coisa desenhada neste quadro, no mundo (células z21): os testes conferem que a posição não depende da câmera.
typedef PlacedMark = ({String kind, double x, double y});

ui.Color _c(int argb, double a) => ui.Color(argb).withValues(alpha: a.clamp(0.0, 1.0));

class ClimateGround {
  ClimateGround({
    required this.catalog,
    this.visual,
    this.roadWidthM = const {'principal': 12, 'secondary': 9, 'local': 6, 'pedestrian': 2},
    this.artPixelDp = 3,
    this.asphalt = 0xFF272A37,
    this.figureM = 4.5,
  });

  final ClimateCatalog catalog;
  final VisualMap? visual;
  final Map<String, double> roadWidthM;

  /// O pixel de arte (dp), a cor do asfalto (de onde a poça parte) e a altura de uma figura da Procissão (a do passante).
  final double artPixelDp;
  final int asphalt;
  final double figureM;

  late final ClimateCover? _cover = visual == null ? null : ClimateCover(visual: visual!, roadWidthM: roadWidthM);

  /// O grafo costurado das rotas (o mesmo do Modo Viagem), para a fila da Procissão andar pelas ruas.
  late final TrafficGraph? _graph = visual == null ? null : TrafficGraph(loadTile: visual!.tile, cellsPerTile: visual!.cellsPerTile, extent: visual!.pack.extent, cacheTiles: 128, stitch: true);
  late final ProcessionLook look = processionLookOf(catalog.procession);

  /// As rotas das Procissões já calculadas (uid da zona). `null`: sem rua, ela anda em reta como antes.
  final processionPlans = <int, ProcessionPlan?>{};
  final _planning = <int>{};

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

  /// Lê do mundo as zonas, as poças e os impactos que ainda deixam marca, em volta de (px, py) (células z21). A Procissão é
  /// procurada também longe (ela pode ter vindo andando de até ~1 km) e fica até 30 min depois do fim (as velas).
  void observe(ClimateWorld w, {required double px, required double py, required double radius21, required double mpc, required int t}) {
    zones = w.zonesNear(px, py, radius21, t, movingExtra21: 1100 / mpc, lookBackS: look.candleS.ceil() + 60);
    for (final z in zones) {
      if (catalog.piece(z.piece.name).style == 'figures') _plan(z, mpc);
    }
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

  /// Calcula a rota da Procissão [z] uma vez, em fatias (não trava a tela).
  void _plan(ClimateZone z, double mpc) {
    final g = _graph;
    if (g == null || processionPlans.containsKey(z.uidBase) || !_planning.add(z.uidBase)) return;
    if (processionPlans.length > 64) processionPlans.clear();
    planProcessionAsync(g, z, mpc: mpc, look: look)
        .then((p) => processionPlans[z.uidBase] = p, onError: (Object _) => processionPlans[z.uidBase] = null)
        .whenComplete(() => _planning.remove(z.uidBase));
  }

  // O clima que se vê quando não é o do mundo (o da rede): desde quando, neste aparelho, e o de antes dele.
  String? _seenId, _lastId;
  double _seenSince = 0, _lastStart = 0, _lastEnd = 0;

  /// O começo do clima que se vê e o clima de antes (id, começo e fim): os do mundo se é ele que se vê; senão, os deste
  /// aparelho (o clima da rede não é do mundo).
  ({double start, String? prevId, double prevStart, double prevEnd}) _timing(ClimateInfo shown, PlayerClimate c, double t) {
    if (_seenId != shown.id) {
      if (_seenId != null) {
        _lastId = _seenId;
        _lastStart = _seenSince;
        _lastEnd = t;
      }
      _seenId = shown.id;
      _seenSince = t;
    }
    if (shown.id == c.id) return (start: c.runStartUtc.toDouble(), prevId: c.prevId, prevStart: c.prevStartUtc.toDouble(), prevEnd: c.prevEndUtc.toDouble());
    return (start: _seenSince, prevId: _lastId, prevStart: _lastStart, prevEnd: _lastEnd);
  }

  /// Quanto a camada [g] já se formou (ou ainda resta depois do fim).
  static double _amount(ClimateLayer g, double sinceStart, double? sinceEnd) {
    final grow = g.raw.containsKey('grow_s') ? g.val('grow_s') : (g.kind == 'twins' ? 0.0 : 900.0);
    return formAmount(sinceStartS: sinceStart, sinceEndS: sinceEnd, growS: grow, fadeS: g.val('fade_s', 1800));
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
    final tm = _timing(shown, c, exactUtc);
    final prev = tm.prevId == null || tm.prevId == shown.id ? null : catalog.of(tm.prevId!);
    // [decor] falso (o clima no mapa desligado nos Ajustes): só o que é do mundo (poças, zonas, marcas) continua.
    // O clima de antes primeiro (secando, por baixo), depois o de agora (formando).
    for (final (info, start, end) in [if (decor && prev != null) (prev, tm.prevStart, tm.prevEnd), if (decor) (shown, tm.start, null)]) {
      for (final (i, g) in info.ground.indexed) {
        if (!g.showsAtHour(localHour)) continue;
        final amount = _amount(g, exactUtc - start, end == null ? null : exactUtc - end);
        if (amount <= 0) continue;
        final layer = (fnv1a64Bytes(info.id.codeUnits) & 0xffff) * 8 + i; // a mesma camada, as mesmas posições, formando ou secando
        switch (g.kind) {
          case 'streets' when ppc >= 2:
            _streets(canvas, g, seed, c, amount, exactUtc, mpc, px, l, top, r, b, cam, at);
          case 'bands':
            _bands(canvas, g, exactUtc, amount, l, top, r, b, at);
          case 'scatter' when ppc >= 3:
            if (g.str('shape') == 'figure') {
              upright.add(() => _figures(canvas, view, cam, g, layer, seed, amount, playerX, playerY, mpc, l, top, r, b));
            } else {
              _scatter(canvas, g, layer, seed, exactUtc, amount, c, px, mpc, l, top, r, b, at);
            }
          case 'twins':
            upright.add(() => _twins(canvas, view, cam, g, amount, ecos, sprites, ecoSizePx, mpc));
        }
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
        final plan = processionPlans[z.uidBase];
        // As velas no chão (giram com o mapa); as figuras em pé, depois.
        if (plan != null) paintCandles(canvas, plan.candlesAt(exactUtc), t: exactUtc, q: artPixelDp * px, candleS: look.candleS, inView: inView, at: at, placed: placed);
        upright.add(() => _procession(canvas, view, cam, z, v, plan, exactUtc, mpc, playerX, playerY));
      } else if (z.activeAt(exactUtc.floor())) {
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

  void _streets(ui.Canvas canvas, ClimateLayer g, int seed, PlayerClimate c, double amount, double t, double mpc, double px, double l, double top, double r, double b, MapCamera cam, ui.Offset Function(double, double) at) {
    _cover?.paint(canvas, StreetCover.fromLayer(g),
        color: g.color(), alpha: g.val('alpha', 0.6), seed: seed, window: c.windWindowStart ~/ 10800, amount: amount, t: t, mpc: mpc, px: px, artPx: artPixelDp,
        l: l, top: top, r: r, b: b, camX: cam.centerX, camY: cam.centerY, at: at, placed: placed);
  }

  void _bands(ui.Canvas canvas, ClimateLayer g, double t, double amount, double l, double top, double r, double b, ui.Offset Function(double, double) at) {
    const s = 6.0; // células (~100 m) entre faixas, presas ao chão
    final cs = g.colors.isEmpty ? [g.color()] : g.colors;
    final a = g.val('alpha', 0.12) * amount, speed = g.val('speed', 0.1);
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

  void _scatter(ui.Canvas canvas, ClimateLayer g, int layer, int seed, double t, double amount, PlayerClimate c, double px, double mpc, double l, double top, double r, double b, ui.Offset Function(double, double) at) {
    final shape = g.str('shape') ?? 'glint', twinkle = g.flag('twinkle');
    final cs = g.colors.isEmpty ? [g.color()] : g.colors;
    final a0 = g.val('alpha', 0.5);
    for (final (x, y, ph) in _spots(g, layer, seed, l, top, r, b)) {
      // Formando, aparecem aos poucos (sempre os mesmos primeiro); secando, somem na ordem contrária.
      if ((ph * 7919) % 1 >= amount) continue;
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
        case 'shadow':
          // Sombra invertida do Sol Negro: clara, comprida, com a borda em pixel (meio-tom).
          final len = (3 + ph * 4) / mpc, wid = (1 + ph) / mpc, q = 3 * px;
          for (var k = -len; k <= len; k += q) {
            final f = 1 - (k / len) * (k / len);
            final hw = (wid * math.sqrt(f) / q).floor() * q;
            if (hw <= 0) continue;
            canvas.drawRect(ui.Rect.fromLTRB(o.dx + k, o.dy - hw, o.dx + k + q, o.dy + hw), _fill);
          }
        case 'pixel':
          if (((t * 4).floor() + (ph * 1000).floor()) % 3 == 0) continue; // falha: some e volta
          canvas.drawRect(ui.Rect.fromCenter(center: o, width: 2 * px, height: 2 * px), _fill);
        default: // glint, hailstone, dust, ash
          canvas.drawRect(ui.Rect.fromCenter(center: o, width: 2 * px, height: 2 * px), _fill);
      }
    }
  }

  /// Vultos ao longe (Neblina): em pé na tela, num ponto do chão; somem perto do jogador ([near_m]).
  void _figures(ui.Canvas canvas, ui.Size view, MapCamera cam, ClimateLayer g, int layer, int seed, double amount, double px0, double py0, double mpc, double l, double top, double r, double b) {
    final near = g.val('near_m', 60);
    for (final (x, y, _) in _spots(g, layer, seed, l, top, r, b)) {
      final dM = math.sqrt((x - px0) * (x - px0) + (y - py0) * (y - py0)) * mpc;
      final k = ((dM - near * 0.6) / (near * 0.6)).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final (sx, sy) = cam.cellToScreen(x, y, view.width, view.height);
      _fill.color = _c(g.color(), g.val('alpha', 0.3) * k * amount);
      canvas.drawRect(ui.Rect.fromLTWH(sx - 3, sy - 14, 6, 14), _fill);
      canvas.drawRect(ui.Rect.fromLTWH(sx - 2, sy - 19, 4, 4), _fill);
      placed.add((kind: 'figure', x: x, y: y));
    }
  }

  void _twins(ui.Canvas canvas, ui.Size view, MapCamera cam, ClimateLayer g, double amount, List<WorldSpawn> ecos, Map<String, ui.Image> sprites, double size, double mpc) {
    final chance = g.val('chance', 0.5);
    for (final e in ecos) {
      if (((e.uid >>> 16) & 0xffff) / 65536 >= chance) continue;
      // O par de sombra fica a 2 m a leste do Eco, no chão: gira com o mapa.
      final (sx, sy) = cam.cellToScreen(e.x + 2 / mpc, e.y, view.width, view.height);
      final img = sprites[e.entryId];
      final p = ui.Paint()..colorFilter = ui.ColorFilter.mode(_c(g.color(), g.val('alpha', 0.45) * amount), ui.BlendMode.srcIn);
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
    final q = artPixelDp * px;
    final r = math.max(2 * q, p.radiusM * p.size / mpc);
    final o = at(p.x, p.y);
    final h = fnv1a64Of3(p.rolls.uid, p.index, 0xF0D);
    placed.add((kind: 'puddle', x: p.x, y: p.y));
    if (v.style == 'ice') {
      paintIcePuddle(canvas, o, radius: r, q: q, index: p.index, hash: h, color: v.color, glow: v.glow, alpha: v.alpha, t: t);
      return;
    }
    paintPuddle(canvas, o,
        radius: p.radiusM / mpc * math.max(p.size, 0.35), q: q, index: p.index, hash: h, size: p.size, tint: v.color, asphalt: asphalt, alpha: v.alpha,
        raining: p.wet, reflect: v.reflect, prism: v.prism, night: night, t: t);
  }

  void _zone(ui.Canvas canvas, ClimateZone z, PieceVisual v, double t, double mpc, double px, ui.Offset Function(double, double) at) {
    final (cx, cy) = z.centerAt(t, mpc);
    final o = at(cx, cy);
    final r = z.piece.radiusM / mpc;
    final span = (z.endUtc - z.startUtc) / 3;
    final fade = math.min(((t - z.startUtc) / math.min(v.growS, span)).clamp(0.0, 1.0), ((z.endUtc - t) / math.min(v.fadeS, span)).clamp(0.0, 1.0));
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
        // A água do Dilúvio sobe com a zona: começa em pontos molhados e cresce até o raio.
        paintPuddle(canvas, o,
            radius: r * math.max(0.35, fade), q: artPixelDp * px, index: z.index, hash: z.uidBase, size: fade, tint: v.color, asphalt: asphalt, alpha: v.alpha,
            raining: true, reflect: true, prism: false, night: 0, t: t);
      case 'shadow':
        // A sombra invertida do Sol Negro: uma mancha clara de borda em pixel, que aparece e some aos poucos.
        final q = artPixelDp * px;
        for (var k = -r; k <= r; k += q) {
          final hw = (r * 0.55 * math.sqrt(math.max(0, 1 - (k / r) * (k / r))) / q).floor() * q;
          if (hw > 0) canvas.drawRect(ui.Rect.fromLTRB(o.dx + k, o.dy - hw, o.dx + k + q, o.dy + hw), _fill..color = c);
        }
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

  /// A Procissão: a fila de figuras encapuzadas pela rota das ruas, em pé na tela, visível até [ProcessionLook.visibleM]. Sem
  /// rota (sem rua perto), a fila anda na reta da zona, como antes.
  void _procession(ui.Canvas canvas, ui.Size view, MapCamera cam, ClimateZone z, PieceVisual v, ProcessionPlan? plan, double t, double mpc, double px0, double py0) {
    final List<ProcessionFigure> figs;
    if (plan != null) {
      figs = plan.figuresAt(t);
    } else {
      if (!z.activeAt(t.floor())) return;
      final (cx, cy) = z.centerAt(t, mpc);
      final fade = (math.min(t - z.startUtc, z.endUtc - t) / 20).clamp(0.0, 1.0);
      final n = processionSize(z.uidBase, look);
      final hd = math.atan2(-math.cos(z.headingRad), math.sin(z.headingRad));
      figs = [for (var i = 0; i < n; i++) (x: cx - math.sin(z.headingRad) * i * look.spacingM / mpc, y: cy + math.cos(z.headingRad) * i * look.spacingM / mpc, heading: hd, alpha: fade)];
    }
    if (figs.isEmpty) return;
    final pxPerM = cam.pixelsPerCell / mpc;
    final near = <(ProcessionFigure, double, double, double)>[];
    for (final (i, f) in figs.indexed) {
      final dM = math.sqrt((f.x - px0) * (f.x - px0) + (f.y - py0) * (f.y - py0)) * mpc;
      final a = f.alpha * (1 - (dM - look.visibleM) / 15).clamp(0.0, 1.0);
      if (a <= 0) continue;
      final (sx, sy) = cam.cellToScreen(f.x, f.y, view.width, view.height);
      if (sx < -40 || sy < -60 || sx > view.width + 40 || sy > view.height + 40) continue;
      near.add((f, sx, sy + (math.sin(t * 2.2 + i * 0.9) * pxPerM * 0.06).roundToDouble(), a));
    }
    near.sort((a, b) => a.$3.compareTo(b.$3)); // de trás para a frente na tela
    for (final (f, sx, sy, a) in near) {
      paintHoodedFigure(canvas, sx, sy, heightPx: figureM * pxPerM, artPx: artPixelDp, robe: v.color, glow: v.glow, alpha: a, flicker: math.sin(t * 9 + f.x * 3), screenHeading: f.heading + cam.rotation);
    }
    final head = figs.first;
    placed.add((kind: 'procession', x: head.x, y: head.y));
    for (final f in figs) {
      placed.add((kind: 'procession_figure', x: f.x, y: f.y));
    }
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
