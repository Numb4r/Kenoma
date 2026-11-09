/// O que as peças do clima desenham no mapa: o raio (traço do céu ao chão, clarão, poeira e faíscas, marca queimada), o
/// coletável caindo do céu, as zonas (poça, miragem, redemoinho, construção fantasma), as pegadas na neve e o trovão. O
/// ponto de cada acontecimento vem de [ClimateWorld] (o mundo, igual para todos); a animação é deste aparelho.
///
/// O raio a menos de [ClimateBalance.strikeMinPlayerM] do jogador não aparece para ele: o sorteio é do mundo e não pode
/// depender de onde cada um está, então quem está perto demais simplesmente não vê esse raio (o Eco que nasce ali continua
/// lá, igual para todos).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/climate.dart';
import '../../data/climate_catalog.dart';
import '../../world/climate_world.dart';
import '../../world/map_camera.dart';
import '../../world/spawn_field.dart';

class _Strike {
  _Strike(this.drop, this.visual, this.distM);
  final ClimateDrop drop;
  final PieceVisual visual;
  final double distM;
  double age = 0;
  final List<double> bolt = [];
}

class _Mark {
  _Mark(this.x, this.y);
  final double x, y;
  double age = 0;
}

/// Se o acontecimento [d] (células z21) aparece para o jogador em (px, py): nunca a menos de [minM] metros.
bool strikeVisibleFor(ClimateDrop d, double px, double py, double metersPerCell21, double minM) {
  final dx = d.x - px, dy = d.y - py;
  return math.sqrt(dx * dx + dy * dy) * metersPerCell21 >= minM;
}

class ClimateFx {
  ClimateFx({required this.catalog, required this.balance});

  final ClimateCatalog catalog;
  final ClimateBalance balance;

  final _seen = <int>{};
  final _strikes = <_Strike>[];
  final _marks = <_Mark>[];
  final _steps = <(double, double)>[];
  double _flash = 0, _flashPeak = 0;
  double _time = 0;
  int _seed = 777;

  /// O trovão: chamado com a distância (m) quando o raio cai; quem chama atrasa o som pela distância.
  void Function(double distM)? onThunder;

  /// Uma peça fez nascer um Eco aqui perto (o Eco carregado do raio): a tela avisa.
  void Function(ClimateDrop drop)? onEcoBorn;

  /// Reduzir clarões: o clarão vira um escurecimento leve.
  bool reduceFlashes = false;

  /// Quantos raios e quedas estão animando e o clarão de agora (testes e debug).
  int get animating => _strikes.length;
  double get flash => _flash;

  double _next() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff; // só o zigue-zague do traço
    return _seed / 0x7fffffff;
  }

  /// Lê os acontecimentos dos últimos segundos em volta do jogador ([px], [py] em células z21) e começa os novos.
  void observe(ClimateWorld world, {required double px, required double py, required double metersPerCell21, required double exactUtc}) {
    final now = exactUtc.floor();
    for (final d in world.dropsNear(px, py, balance.thunderMaxM / metersPerCell21, now - 2, now)) {
      if (!_seen.add(d.uid)) continue;
      if (!strikeVisibleFor(d, px, py, metersPerCell21, balance.strikeMinPlayerM)) continue;
      final dist = math.sqrt((d.x - px) * (d.x - px) + (d.y - py) * (d.y - py)) * metersPerCell21;
      final v = catalog.piece(d.piece.name);
      final s = _Strike(d, v, dist)..age = (exactUtc - d.tUtc).clamp(0.0, 2.0);
      if (s.age > 1.0) continue; // chegou atrasado (o app estava fechado): não anima
      for (var i = 0; i < 9; i++) {
        s.bolt.add(_next() - 0.5);
      }
      _strikes.add(s);
      if (d.piece.impact) {
        if (v.flash && dist <= balance.flashMaxM) _flashPeak = _flash = math.max(_flash, 1 - dist / balance.flashMaxM * 0.6);
        if (v.flash) onThunder?.call(dist);
        _marks.add(_Mark(d.x, d.y));
        final sp = d.piece.spawn;
        if (sp != null && d.spawnRoll < sp.chance) onEcoBorn?.call(d);
      }
    }
    if (_seen.length > 4000) _seen.clear();
  }

  /// Pegadas do jogador na neve: uma a cada poucos metros.
  void noteStep(double x21, double y21, double metersPerCell21) {
    if (_steps.isNotEmpty) {
      final (lx, ly) = _steps.last;
      if (math.sqrt((x21 - lx) * (x21 - lx) + (y21 - ly) * (y21 - ly)) * metersPerCell21 < balance.footprintEveryM) return;
    }
    _steps.add((x21, y21));
    if (_steps.length > balance.footprintMax) _steps.removeAt(0);
  }

  void update(double dt) {
    _time += dt;
    for (final s in _strikes) {
      s.age += dt;
    }
    _strikes.removeWhere((s) => s.age > 1.2);
    for (final m in _marks) {
      m.age += dt;
    }
    _marks.removeWhere((m) => m.age > balance.burnMarkS);
    if (_flash > 0) _flash = math.max(0, _flash - dt / (balance.flashMs / 1000) * _flashPeak);
  }

  static final _px = ui.Paint()..isAntiAlias = false;

  /// O chão: zonas, marcas queimadas e pegadas. Vai antes dos spawns.
  void paintGround(ui.Canvas canvas, ui.Size view, MapCamera cam, {required List<ClimateZone> zones, required double metersPerCell21, required double exactUtc, PlayerClimate climate = PlayerClimate.none, List<WorldSpawn> ecos = const []}) {
    for (final z in zones) {
      final v = catalog.piece(z.piece.name);
      final (cx, cy) = z.centerAt(exactUtc, metersPerCell21);
      final (sx, sy) = cam.cellToScreen(cx, cy, view.width, view.height);
      final r = z.piece.radiusM / metersPerCell21 * cam.pixelsPerCell;
      final fade = math.min(1.0, math.min(exactUtc - z.startUtc, z.endUtc - exactUtc) / 20).clamp(0.0, 1.0);
      final c = ui.Color(v.color).withValues(alpha: v.alpha * fade);
      final o = ui.Offset(sx, sy);
      switch (v.style) {
        case 'puddle':
          canvas.drawOval(ui.Rect.fromCenter(center: o, width: r * 2, height: r * 1.3), ui.Paint()..color = c);
          canvas.drawOval(ui.Rect.fromCenter(center: o.translate(-r * 0.3, -r * 0.15), width: r * 0.5, height: r * 0.15), ui.Paint()..color = const ui.Color(0xFFE8E4F4).withValues(alpha: 0.3 * fade));
        case 'glow':
          final k = 0.7 + 0.3 * math.sin(_time * 2);
          canvas.drawCircle(o, r * k, ui.Paint()..color = c);
          canvas.drawCircle(o, r * 0.3, ui.Paint()..color = c.withValues(alpha: math.min(1, v.alpha * 1.6 * fade)));
        case 'whirl':
          for (var i = 0; i < 5; i++) {
            final a = _time * 4 + i * 1.2;
            canvas.drawCircle(o.translate(math.cos(a) * r * 0.5 * (1 - i / 6), -i * r * 0.35 + math.sin(a) * r * 0.2), r * (0.25 + i * 0.08), ui.Paint()
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = c);
          }
        case 'ghost':
          final w = r * 1.4, h = r * 1.1;
          final p = ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = c;
          canvas.drawRect(ui.Rect.fromCenter(center: o, width: w, height: h), p);
          canvas.drawRect(ui.Rect.fromCenter(center: o, width: w, height: h), ui.Paint()..color = c.withValues(alpha: v.alpha * 0.3 * fade));
          canvas.drawLine(o.translate(-w / 2, -h / 2), o.translate(0, -h), p);
          canvas.drawLine(o.translate(w / 2, -h / 2), o.translate(0, -h), p);
        case 'figures':
          for (var i = 0; i < 5; i++) {
            final f = o.translate(-math.sin(z.headingRad) * i * 10, math.cos(z.headingRad) * i * 10);
            canvas.drawRect(ui.Rect.fromLTWH(f.dx - 3, f.dy - 14, 6, 14), _px..color = c);
          }
        default: // zone
          canvas.drawCircle(o, r, ui.Paint()..color = c);
      }
    }
    for (final m in _marks) {
      final (sx, sy) = cam.cellToScreen(m.x, m.y, view.width, view.height);
      final a = 0.55 * (1 - m.age / balance.burnMarkS);
      canvas.drawOval(ui.Rect.fromCenter(center: ui.Offset(sx, sy), width: 18, height: 9), _px..color = const ui.Color(0xFF1A1424).withValues(alpha: a));
      canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset(sx, sy), width: 4, height: 2), _px..color = const ui.Color(0xFFFF7A45).withValues(alpha: a * 0.6));
    }
    if (climate.playerTrails) {
      for (final (x, y) in _steps) {
        final (sx, sy) = cam.cellToScreen(x, y, view.width, view.height);
        canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset(sx, sy), width: 3, height: 2), _px..color = const ui.Color(0xFF8A8FA3).withValues(alpha: 0.6));
      }
    }
    if (climate.ecoTracksM > 0) {
      // Pegadas que levam ao Eco: saem dele numa direção fixa pelo uid, até a distância do dado.
      for (final e in ecos) {
        final h = (e.uid >>> 20 & 0xffff) / 0xffff * 2 * math.pi;
        final n = (climate.ecoTracksM / 4).floor();
        for (var i = 1; i <= n; i++) {
          final d = i * 4 / metersPerCell21;
          final (sx, sy) = cam.cellToScreen(e.x + math.sin(h) * d, e.y - math.cos(h) * d, view.width, view.height);
          canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset(sx + (i.isEven ? 2 : -2), sy), width: 2, height: 2), _px..color = const ui.Color(0xFF8A8FA3).withValues(alpha: 0.5 * (1 - i / (n + 1))));
        }
      }
    }
  }

  /// Por cima de tudo (menos o HUD): o traço do raio, a poeira, a queda do coletável e o clarão.
  void paintSky(ui.Canvas canvas, ui.Size view, MapCamera cam) {
    for (final s in _strikes) {
      final (sx, sy) = cam.cellToScreen(s.drop.x, s.drop.y, view.width, view.height);
      final ground = ui.Offset(sx, sy);
      final color = ui.Color(s.visual.color), glow = ui.Color(s.visual.glow);
      if (s.drop.piece.impact) {
        final boltS = balance.boltMs / 1000;
        if (s.age < boltS) {
          final a = 1 - s.age / boltS;
          final path = ui.Path()..moveTo(sx + s.bolt[0] * 30, 0);
          final top = s.visual.style == 'meteor' ? sy - 80 : 0.0;
          if (s.visual.style == 'meteor') path.moveTo(sx - 60, top);
          for (var i = 1; i < s.bolt.length; i++) {
            final y = top + (sy - top) * i / (s.bolt.length - 1);
            path.lineTo(s.visual.style == 'meteor' ? sx - 60 + 60 * i / (s.bolt.length - 1) : sx + s.bolt[i] * 26 * (1 - i / s.bolt.length), y);
          }
          canvas.drawPath(path, ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = glow.withValues(alpha: 0.45 * a));
          canvas.drawPath(path, ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color.withValues(alpha: a));
        }
        // Impacto: poeira que abre e faíscas que sobem.
        final u = (s.age / 1.2).clamp(0.0, 1.0);
        for (var i = 0; i < 8; i++) {
          final ang = i / 8 * 2 * math.pi;
          final p = ground.translate(math.cos(ang) * u * 18, math.sin(ang) * u * 7 - (i.isEven ? u * 14 : 0));
          canvas.drawRect(ui.Rect.fromCenter(center: p, width: 2, height: 2), _px..color = (i.isEven ? glow : const ui.Color(0xFFC9A46B)).withValues(alpha: 1 - u));
        }
      } else {
        // Coletável do céu: cai do alto da tela até o ponto.
        final fallS = balance.fallMs / 1000, u = (s.age / fallS).clamp(0.0, 1.0);
        if (u < 1) canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset(sx, sy * u), width: 3, height: 3), _px..color = color);
      }
    }
    if (_flash > 0.01) {
      final rect = ui.Offset.zero & view;
      canvas.drawRect(
        rect,
        _px
          ..color = reduceFlashes
              ? const ui.Color(0xFF1A1424).withValues(alpha: balance.dimAlpha * _flash)
              : const ui.Color(0xFFE8E4F4).withValues(alpha: balance.flashAlpha * _flash),
      );
    }
  }
}
