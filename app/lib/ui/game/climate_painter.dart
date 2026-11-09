/// O clima no espaço da tela: as camadas do `clima.json` (partículas, tinta, véu nas bordas, sombras de nuvem, arco-íris,
/// aurora, glitch...) desenhadas por cima do mapa e por baixo do HUD, cobrindo a tela inteira em qualquer rotação, zoom e
/// proporção (não dependem da câmera). Cada camada sobe e desce devagar quando o clima muda. Só visual.
///
/// As partículas nascem do lado de onde vêm: pela borda de cima se caem, pela de baixo se sobem, e pela lateral contra o
/// vento, na proporção do fluxo por cada borda. Assim toda inclinação cobre a tela toda, inclusive os cantos.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../data/climate_catalog.dart';
import 'climate_layers.dart';

class _P {
  double x = 0, y = 0, vx = 0, vy = 0, phase = 0, floor = 0, life = 0;
  int color = 0;
  bool bounced = false;
}

class _Pool {
  _Pool(this.layer);

  final ClimateLayer layer;
  final parts = <_P>[];
  double level = 0;
  double target = 1;
}

class ClimatePainter {
  ClimatePainter({this.cap = 260, this.pocketRate = 0.2});

  /// Teto de partículas do aparelho (somando as camadas) e a fração delas no modo bolso.
  int cap;
  double pocketRate;

  /// Modo bolso: menos partículas (o agente da Patrulha liga).
  bool lowRate = false;
  void setPocket(bool on) => lowRate = on;

  /// Reduzir clarões: o glitch pisca devagar e fraco.
  bool reduceFlashes = false;

  final _pools = <ClimateLayer, _Pool>{};
  ClimateInfo? _info;
  double _time = 0;
  int _seed = 12345;

  /// Direção do vento na tela (vetor unitário) e a hora local, para as camadas que dependem delas.
  ui.Offset wind = const ui.Offset(1, 0);
  int localHour = 12;

  /// Partículas na tela agora.
  int get count => _pools.values.fold(0, (a, p) => a + p.parts.length);

  /// Onde estão as partículas (testes de cobertura).
  Iterable<ui.Offset> get positions => _pools.values.expand((p) => p.parts.map((q) => ui.Offset(q.x, q.y)));

  double _next() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff; // só posições na tela, nada do mundo
    return _seed / 0x7fffffff;
  }

  /// Avança [dt] segundos com o clima [info]. Com [enabled] falso (o interruptor dos Ajustes), tudo some devagar.
  void update(double dt, ui.Size view, ClimateInfo info, {bool enabled = true}) {
    _time += dt;
    if (!identical(info, _info)) {
      _info = info;
      for (final p in _pools.values) {
        p.target = 0;
      }
      for (final l in info.layers) {
        _pools.putIfAbsent(l, () => _Pool(l)).target = 1;
      }
    }
    final budget = lowRate ? pocketRate : 1.0;
    var left = cap;
    for (final p in _pools.values.toList()) {
      final target = enabled ? p.target : 0.0;
      p.level += (target - p.level) * (1 - math.exp(-dt / 1.2));
      if (p.level < 0.02 && target == 0) {
        _pools.remove(p.layer);
        continue;
      }
      if (p.layer.kind != 'particles' || view.isEmpty) continue;
      final want = math.min(left, (p.layer.count('count') * p.level * budget).round());
      left -= want;
      _step(p, dt, view, want);
    }
  }

  ui.Offset _velocity(ClimateLayer l) {
    final (lo, hi) = l.range('speed', (300, 500));
    final s = lo + _next() * (hi - lo);
    if (l.flag('wind')) return ui.Offset(wind.dx * s, wind.dy * s + s * 0.12); // atravessa a tela com o vento, caindo um pouco
    final up = l.flag('up') ? -1.0 : 1.0;
    return ui.Offset(-l.val('slant') * s, up * s);
  }

  /// Nasce fora da tela, na borda de onde vem, escolhida pelo fluxo de cada borda.
  void _spawn(_P q, ClimateLayer l, ui.Size view, {bool inside = false}) {
    final v = _velocity(l);
    q
      ..vx = v.dx
      ..vy = v.dy
      ..phase = _next() * 6.28
      ..bounced = false
      ..life = 0
      ..floor = view.height * (0.15 + 0.85 * _next());
    final cs = l.colors;
    q.color = cs.isEmpty ? l.color() : cs[(_next() * cs.length).floor() % cs.length];
    if (inside) {
      q
        ..x = _next() * view.width
        ..y = _next() * view.height;
      return;
    }
    final fy = v.dy.abs() * view.width, fx = v.dx.abs() * view.height;
    if (_next() * (fx + fy) < fy) {
      q
        ..x = _next() * view.width
        ..y = v.dy >= 0 ? -6 - _next() * 30 : view.height + 6 + _next() * 30;
      // Começa um pouco contra o vento para entrar na tela já inclinada.
      q.x -= v.dx / (v.dy.abs() + 1e-6) * 18;
    } else {
      q
        ..y = _next() * view.height
        ..x = v.dx >= 0 ? -6 - _next() * 30 : view.width + 6 + _next() * 30;
    }
  }

  void _step(_Pool p, double dt, ui.Size view, int want) {
    final l = p.layer;
    while (p.parts.length < want) {
      final q = _P();
      _spawn(q, l, view, inside: p.level > 0.5); // ao abrir com o clima já ativo, a tela já começa cheia
      p.parts.add(q);
    }
    if (p.parts.length > want + 6) p.parts.removeRange(want, p.parts.length);
    final sway = l.flag('sway'), bounce = l.flag('bounce');
    for (final q in p.parts) {
      q.x += q.vx * dt + (sway ? math.sin(_time * 2 + q.phase) * 18 * dt : 0);
      q.y += q.vy * dt;
      if (bounce) {
        if (!q.bounced && q.y >= q.floor) {
          q
            ..bounced = true
            ..vy = -q.vy * 0.3
            ..vx *= 0.5;
        }
        if (q.bounced) q.life += dt;
        if (q.bounced && q.life > 0.35) _spawn(q, l, view);
      }
      if (q.x < -40 || q.x > view.width + 40 || q.y < -40 || q.y > view.height + 40) _spawn(q, l, view);
    }
  }

  static final _paint = ui.Paint()..isAntiAlias = false;

  /// Desenha as camadas. [player] é o Conjurador na tela (o sopro do Frio sai dali).
  void paint(ui.Canvas canvas, ui.Size view, {ui.Offset? player}) {
    for (final p in _pools.values) {
      final l = p.layer;
      final a = l.val('alpha', 0.4) * p.level;
      if (a <= 0.003 || !l.showsAtHour(localHour)) continue;
      if (l.kind == 'particles') {
        _paintParticles(canvas, p, a);
      } else {
        paintClimateLayer(canvas, view, l, a, _time, player: player ?? view.center(ui.Offset.zero), reduceFlashes: reduceFlashes);
      }
    }
  }

  void _paintParticles(ui.Canvas canvas, _Pool p, double a) {
    final l = p.layer;
    final shape = l.str('shape') ?? 'streak';
    final size = l.val('size', 2), len = l.val('len', 9);
    for (final q in p.parts) {
      final alpha = q.bounced ? a * (1 - q.life / 0.35).clamp(0.0, 1.0) : a;
      _paint
        ..color = ui.Color(q.color).withValues(alpha: alpha)
        ..strokeWidth = 2
        ..style = ui.PaintingStyle.fill;
      switch (shape) {
        case 'streak' || 'wisp':
          final sp = math.sqrt(q.vx * q.vx + q.vy * q.vy) + 1e-6;
          canvas.drawLine(ui.Offset(q.x, q.y), ui.Offset(q.x + q.vx / sp * len, q.y + q.vy / sp * len), _paint);
        case 'leaf':
          canvas.drawRect(ui.Rect.fromLTWH(q.x, q.y, size + (math.sin(_time * 6 + q.phase) > 0 ? 1 : 0), size / 2 + 1), _paint);
        case 'ember':
          canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset(q.x, q.y), width: size + 4, height: size + 4), _paint..color = ui.Color(q.color).withValues(alpha: alpha * 0.25));
          canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset(q.x, q.y), width: size, height: size), _paint..color = ui.Color(q.color).withValues(alpha: alpha));
        default: // flake, hail, dust, ash, pixel: um quadrado de pixels
          canvas.drawRect(ui.Rect.fromLTWH(q.x.roundToDouble(), q.y.roundToDouble(), size, size), _paint);
      }
    }
  }
}
