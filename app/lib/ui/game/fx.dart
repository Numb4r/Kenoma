/// Retorno visual do mapa de jogo: o item que voa até o Conjurador, o brilho da coleta, o "+N" que sobe, o pulo do Eco
/// tocado, a costura do Véu quando um Eco aparece e o Eco que se desfaz em pixels ao fugir. Só desenho: a lógica de
/// coleta e de fuga vive em `world/`. Cada efeito é curto (80 a 400 ms) para o jogador ver o resultado na hora.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection;

import '../../world/map_camera.dart';
import '../../world/spawn_field.dart';
import '../colors.dart';
import 'spawn_painter.dart' show paintMaterialIcon, paintSparkIcon;

/// Durações dos efeitos, em segundos.
const double fxFlyS = 0.30, fxGlintS = 0.16, fxPlusS = 0.90, fxHopS = 0.20, fxAppearS = 0.25, fxDissolveS = 0.40;

class _Fly {
  _Fly(this.x, this.y, this.color, this.isSpark, this.entryId, this.qty);
  final double x, y;
  final ui.Color color;
  final bool isSpark;
  final String entryId;
  final int qty;
  double t = 0;
}

class _Plus {
  _Plus(this.entryId, this.color, this.n);
  final String entryId;
  final ui.Color color;
  int n;
  double t = 0;
}

class _Dissolve {
  _Dissolve(this.x, this.y, this.sprite, this.tint, this.size);
  final double x, y;
  final ui.Image? sprite;
  final int? tint;
  final double size;
  double t = 0;
}

class Fx {
  final _flies = <_Fly>[];
  final _glints = <double>[]; // idade de cada brilho, no avatar
  final _plus = <_Plus>[];
  final _hops = <int, double>{};
  final _appear = <int, double>{};
  final _dissolves = <_Dissolve>[];
  final _known = <int>{};
  bool _primed = false;

  /// Quantos efeitos estão vivos (testes e a sobrecarga de debug).
  int get alive => _flies.length + _glints.length + _plus.length + _hops.length + _appear.length + _dissolves.length;

  /// Os contadores "+N" na tela agora.
  List<String> get plusLabels => [for (final p in _plus) '+${p.n}'];

  /// Uma Fagulha ou material foi coletado em ([x], [y]) (células z21): voa até o Conjurador e vira "+N".
  void collected(WorldSpawn s, ui.Color color) =>
      _flies.add(_Fly(s.x, s.y, color, s.isSpark, s.entryId, s.quantity));

  /// O Eco [uid] foi tocado: dá um pulo curto.
  void hop(int uid) => _hops[uid] = 0;

  /// O Eco fugiu: se desfaz para cima em pixels onde estava.
  void fled(WorldSpawn s, ui.Image? sprite, int? tint, double size) => _dissolves.add(_Dissolve(s.x, s.y, sprite, tint, size));

  /// Os Ecos à vista agora. Os que não estavam na lista anterior surgem com a costura do Véu; a primeira lista (o que já
  /// estava no mapa ao abrir) não anima.
  void observe(Iterable<WorldSpawn> spawns) {
    for (final s in spawns) {
      if (!s.isEco) continue;
      if (_known.add(s.uid) && _primed) _appear[s.uid] = 0;
    }
    _primed = true;
    if (_known.length > 4000) {
      // Esquece os antigos sem reabrir a costura dos que estão à vista agora.
      _known
        ..clear()
        ..addAll([for (final s in spawns) if (s.isEco) s.uid]);
    }
  }

  /// Quanto do pulo do Eco [uid] em pixels (negativo = para cima). 0 sem pulo.
  double hopOffset(int uid, double heightPx) {
    final t = _hops[uid];
    return t == null ? 0 : -math.sin(math.pi * (t / fxHopS)) * heightPx;
  }

  /// A abertura do Eco [uid]: de 0 (costura fechada) a 1 (pronto). 1 se não há efeito.
  double appear(int uid) {
    final t = _appear[uid];
    return t == null ? 1 : (t / fxAppearS).clamp(0.0, 1.0);
  }

  void update(double dt) {
    for (final f in _flies) {
      f.t += dt;
    }
    final landed = _flies.where((f) => f.t >= fxFlyS).toList();
    for (final f in landed) {
      _glints.add(0);
      final same = _plus.where((p) => p.entryId == f.entryId && p.t < fxPlusS * 0.6);
      if (same.isNotEmpty) {
        same.first
          ..n += f.qty
          ..t = 0;
      } else {
        _plus.add(_Plus(f.entryId, f.color, f.qty));
      }
    }
    _flies.removeWhere((f) => f.t >= fxFlyS);
    for (var i = 0; i < _glints.length; i++) {
      _glints[i] += dt;
    }
    _glints.removeWhere((t) => t >= fxGlintS);
    for (final p in _plus) {
      p.t += dt;
    }
    _plus.removeWhere((p) => p.t >= fxPlusS);
    for (final k in _hops.keys.toList()) {
      final t = _hops[k]! + dt;
      if (t >= fxHopS) {
        _hops.remove(k);
      } else {
        _hops[k] = t;
      }
    }
    for (final k in _appear.keys.toList()) {
      final t = _appear[k]! + dt;
      if (t >= fxAppearS) {
        _appear.remove(k);
      } else {
        _appear[k] = t;
      }
    }
    for (final d in _dissolves) {
      d.t += dt;
    }
    _dissolves.removeWhere((d) => d.t >= fxDissolveS);
  }

  static final _flat = ui.Paint()..isAntiAlias = false;

  /// Desenha por cima dos spawns: voos, brilhos, "+N" e Ecos se desfazendo. [avatar] é o centro do Conjurador na tela.
  void paint(ui.Canvas canvas, ui.Size view, MapCamera cam, {required ui.Offset avatar, required double playerSize, required double sparkSize, required double dpr}) {
    for (final d in _dissolves) {
      final (sx, sy) = cam.cellToScreen(d.x, d.y, view.width, view.height);
      _paintDissolve(canvas, ui.Offset(sx, sy), d);
    }
    for (final f in _flies) {
      final (sx, sy) = cam.cellToScreen(f.x, f.y, view.width, view.height);
      final u = (f.t / fxFlyS).clamp(0.0, 1.0);
      final e = u * u * (3 - 2 * u); // suaviza o começo e o fim
      final target = avatar.translate(0, -playerSize * 0.3);
      final arc = -math.sin(math.pi * e) * math.min(36.0, (target - ui.Offset(sx, sy)).distance * 0.5 + 8);
      final p = ui.Offset.lerp(ui.Offset(sx, sy), target, e)!.translate(0, arc);
      final size = sparkSize * (1 - 0.5 * e);
      if (f.isSpark) {
        paintSparkIcon(canvas, p, f.color, size, dpr);
      } else {
        paintMaterialIcon(canvas, p, f.color, size);
      }
    }
    for (final age in _glints) {
      final u = age / fxGlintS;
      final r = 3 + u * 9;
      final alpha = (1 - u).clamp(0.0, 1.0);
      final c = avatar.translate(0, -playerSize * 0.3);
      for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)]) {
        final diag = dx != 0 && dy != 0 ? 0.7 : 1.0;
        canvas.drawRect(
          ui.Rect.fromCenter(center: c.translate(dx * r * diag, dy * r * diag), width: 2, height: 2),
          _flat..color = ui.Color.fromRGBO(255, 255, 255, alpha),
        );
      }
    }
    var slot = 0;
    for (final p in _plus) {
      final u = p.t / fxPlusS;
      final alpha = u < 0.7 ? 1.0 : (1 - (u - 0.7) / 0.3);
      final base = avatar.translate(slot * 0.0, -playerSize * 0.7 - u * 22 - slot * 12);
      slot++;
      final tp = TextPainter(
        text: TextSpan(text: '+${p.n}', style: TextStyle(fontFamily: 'Silkscreen', fontSize: 10, color: kText.withValues(alpha: alpha))),
        textDirection: TextDirection.ltr,
      )..layout();
      final left = base.dx - (tp.width + 12) / 2;
      canvas.drawRect(ui.Rect.fromLTWH(left, base.dy + 1, 8, 8).inflate(1), _flat..color = kOutline.withValues(alpha: alpha));
      canvas.drawRect(ui.Rect.fromLTWH(left, base.dy + 1, 8, 8), _flat..color = p.color.withValues(alpha: alpha));
      tp.paint(canvas, ui.Offset(left + 12, base.dy));
      tp.dispose();
    }
  }

  void _paintDissolve(ui.Canvas canvas, ui.Offset c, _Dissolve d) {
    final u = (d.t / fxDissolveS).clamp(0.0, 1.0);
    final sprite = d.sprite;
    const bands = 10;
    final size = d.size;
    for (var k = 0; k < bands; k++) {
      // As faixas de cima saem primeiro; cada uma sobe e some.
      final delay = (bands - 1 - k) / bands * 0.35;
      final v = ((u - delay) / (1 - 0.35)).clamp(0.0, 1.0);
      final alpha = 1 - v;
      if (alpha <= 0) continue;
      final dy = -v * size * 0.7;
      final dx = ((k * 7 + d.size.round()) % 5 - 2) * v * 3;
      final dst = ui.Rect.fromLTWH(c.dx - size / 2 + dx, c.dy - size / 2 + k * size / bands + dy, size, size / bands);
      if (sprite != null) {
        final src = ui.Rect.fromLTWH(0, k * sprite.height / bands, sprite.width.toDouble(), sprite.height / bands);
        canvas.drawImageRect(
          sprite,
          src,
          dst,
          ui.Paint()
            ..filterQuality = ui.FilterQuality.none
            ..isAntiAlias = false
            ..color = ui.Color.fromRGBO(255, 255, 255, alpha)
            ..colorFilter = d.tint == null ? null : ui.ColorFilter.mode(ui.Color(d.tint!).withValues(alpha: 0.4), ui.BlendMode.srcATop),
        );
      } else {
        canvas.drawRect(dst.deflate(size * 0.05), _flat..color = kVeil.withValues(alpha: alpha));
      }
    }
  }
}
