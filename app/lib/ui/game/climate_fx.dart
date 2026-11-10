/// O que as peças do clima desenham no céu, no espaço da tela: o traço do raio do céu ao chão, o risco do meteoro, a poeira
/// do impacto, o coletável caindo, o clarão e o tremor do impacto, e o trovão. O ponto de cada acontecimento vem de
/// [ClimateWorld] (o mundo, igual para todos); a animação é deste aparelho. O que fica no chão depois (marca queimada,
/// cratera, brasa, poças, zonas, pegadas) é do mapa: `climate_ground.dart`.
///
/// O raio a menos de [ClimateBalance.strikeMinPlayerM] do jogador não aparece para ele: o sorteio é do mundo e não pode
/// depender de onde cada um está, então quem está perto demais simplesmente não vê esse raio (o Eco que nasce ali continua
/// lá, igual para todos). O raio do debug ("Raio aqui", no toque) cai mesmo do lado do jogador.
///
/// O Eco carregado que nasce do raio não tem aviso (nem toast, nem notificação, nem Chat): ele só aparece no mapa, com a
/// faísca em volta.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/climate.dart';
import '../../data/climate_catalog.dart';
import '../../world/climate_world.dart';
import '../../world/map_camera.dart';

class _Strike {
  _Strike(this.drop, this.visual, this.distM);
  final ClimateDrop drop;
  final PieceVisual visual;
  final double distM;
  double age = 0;
  final List<double> bolt = [];
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
  final _steps = <(double, double)>[];
  double _flash = 0, _flashPeak = 0;
  double _shake = 0;
  double _time = 0;
  int _seed = 777;

  /// O trovão: chamado com a distância (m) quando o raio cai; quem chama atrasa o som pela distância.
  void Function(double distM)? onThunder;

  /// Reduzir clarões: o clarão vira um escurecimento leve e o impacto não treme a tela.
  bool reduceFlashes = false;

  /// Quantos raios e quedas estão animando, o clarão e o tremor de agora (testes e debug).
  int get animating => _strikes.length;
  double get flash => _flash;
  double get shake => _shake;

  /// As pegadas do jogador na neve (células z21), da mais velha para a mais nova. O mapa desenha.
  List<(double, double)> get steps => _steps;

  /// Quanto a tela anda agora com o tremor do impacto (pixels). Zero sem tremor.
  ui.Offset get shakeOffset => _shake <= 0.01 || reduceFlashes ? ui.Offset.zero : ui.Offset(math.sin(_time * 63) * 3 * _shake, math.cos(_time * 47) * 2 * _shake);

  double _next() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff; // só o zigue-zague do traço
    return _seed / 0x7fffffff;
  }

  /// Lê os acontecimentos dos últimos segundos em volta do jogador ([px], [py] em células z21) e começa os novos.
  void observe(ClimateWorld world, {required double px, required double py, required double metersPerCell21, required double exactUtc}) {
    final now = exactUtc.floor();
    for (final d in world.dropsNear(px, py, balance.thunderMaxM / metersPerCell21, now - 2, now)) {
      if (!_seen.add(d.uid)) continue;
      final debug = d.pieceIndex < 0; // tocado no debug: só neste aparelho, cai onde o dedo tocou e anima inteiro
      if (!debug && !strikeVisibleFor(d, px, py, metersPerCell21, balance.strikeMinPlayerM)) continue;
      final dist = math.sqrt((d.x - px) * (d.x - px) + (d.y - py) * (d.y - py)) * metersPerCell21;
      final v = catalog.piece(d.piece.name);
      final s = _Strike(d, v, dist)..age = debug ? 0 : (exactUtc - d.tUtc).clamp(0.0, 2.0);
      if (s.age > 1.0) continue; // chegou atrasado (o app estava fechado): não anima
      for (var i = 0; i < 9; i++) {
        s.bolt.add(_next() - 0.5);
      }
      _strikes.add(s);
      if (d.piece.impact) {
        if (v.flash && dist <= balance.flashMaxM) _flashPeak = _flash = math.max(_flash, 1 - dist / balance.flashMaxM * 0.6);
        if (v.flash) onThunder?.call(dist);
        if (v.shake && dist <= balance.flashMaxM) _shake = math.max(_shake, 1 - dist / balance.flashMaxM * 0.7);
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
    if (_flash > 0) _flash = math.max(0, _flash - dt / (balance.flashMs / 1000) * _flashPeak);
    if (_shake > 0) _shake = math.max(0, _shake - dt / 0.45); // um tremor curto, de menos de meio segundo
  }

  static final _px = ui.Paint()..isAntiAlias = false;

  /// Por cima de tudo (menos o HUD): o traço do raio, o risco do meteoro, a poeira, a queda do coletável e o clarão.
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
