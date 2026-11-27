/// Retorno visual do mapa de jogo: o item que voa até o Conjurador, o brilho da coleta, o "+N" que sobe, o pulo do Eco
/// tocado, a costura do Véu quando um Eco aparece e o Eco que se desfaz em pixels ao fugir. Só desenho: a lógica de
/// coleta e de fuga vive em `world/`. Cada efeito é curto (80 a 400 ms) para o jogador ver o resultado na hora.
library;

import 'creature_anim.dart';
import 'creature_art.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection;

import '../../world/map_camera.dart';
import '../../world/spawn_field.dart';
import '../colors.dart';
import '../flashes.dart';
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
  _Dissolve(this.uid, this.x, this.y, this.sprite, this.tint, this.size);
  final int uid;
  final double x, y;
  final ui.Image? sprite;
  final int? tint;
  final double size;
  double t = 0;
}

/// 0.25.0: a saída animada de uma criatura com arte animada: fuga (sobe e sai de lado) ou sintonizada (se desfaz em
/// faíscas que vão para o Conjurador).
class _Exit {
  _Exit(this.uid, this.entryId, this.x, this.y, this.variant, this.tuned, this.left);
  final int uid;
  final String entryId;
  final double x, y;
  final String? variant;
  final bool tuned, left;
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

  final _exits = <_Exit>[];

  /// 0.25.0: a criatura [s] sai do mapa animada (se tiver arte animada): [tuned] é a sintonia que deu certo, senão a fuga.
  void exit(WorldSpawn s, {required bool tuned, bool facingLeft = false}) {
    if (CreatureArt.of(s.entryId) == null) return;
    _exits.add(_Exit(s.uid, s.entryId, s.x, s.y, s.shiny ? null : s.variant, tuned, facingLeft));
  }

  /// O Eco [uid] foi tocado: dá um pulo curto.
  void hop(int uid) => _hops[uid] = 0;

  /// O Eco fugiu: se desfaz para cima em pixels onde estava.
  void fled(WorldSpawn s, ui.Image? sprite, int? tint, double size) => _dissolves.add(_Dissolve(s.uid, s.x, s.y, sprite, tint, size));

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
    for (final e in _exits) {
      e.t += dt;
    }
    _exits.removeWhere((e) => e.t >= _exitS(e));
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
  /// [anchorOf]: onde o Eco foi desenhado por último (com o vento); o desfazer sai ali, não na posição crua.
  void paint(ui.Canvas canvas, ui.Size view, MapCamera cam, {required ui.Offset avatar, required double playerSize, required double sparkSize, required double dpr, ui.Offset? Function(int uid)? anchorOf, double? ecoSize, List<void Function()>? emissive, ui.Color? tone}) {
    for (final e in _exits) {
      final (sx, sy) = cam.cellToScreen(e.x, e.y, view.width, view.height);
      _paintExit(canvas, anchorOf?.call(e.uid) ?? ui.Offset(sx, sy), e, ecoSize ?? playerSize, avatar, emissive, tone);
    }
    for (final d in _dissolves) {
      final (sx, sy) = cam.cellToScreen(d.x, d.y, view.width, view.height);
      _paintDissolve(canvas, anchorOf?.call(d.uid) ?? ui.Offset(sx, sy), d);
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
      final alpha = (1 - u).clamp(0.0, 1.0) * (reduceFlashes.value ? 0.35 : 1); // reduzir clarões: brilho fraco
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


/// A duração da saída: os quadros da animação a [fps], e na sintonia mais o voo das faíscas até o Conjurador.
double _exitS(_Exit e) {
  final a = CreatureArt.of(e.entryId)?.anims[e.tuned ? CreatureAnim.tuned : CreatureAnim.flee];
  final anim = a == null ? 0.6 : a.frames / a.fps;
  return anim + (e.tuned ? 0.45 : 0);
}

void _paintExit(ui.Canvas canvas, ui.Offset c0, _Exit e, double size, ui.Offset avatar, List<void Function()>? emissive, ui.Color? tone) {
  final art = CreatureArt.of(e.entryId);
  final kind = e.tuned ? CreatureAnim.tuned : CreatureAnim.flee;
  final strip = art?.anims[kind];
  if (art == null || strip == null) return;
  final animS = strip.frames / strip.fps, u = (e.t / animS).clamp(0.0, 1.0);
  // A fuga sobe e sai de lado; a sintonia fica no lugar.
  final c = e.tuned ? c0 : c0.translate((e.left ? -1 : 1) * size * 1.6 * u * u, -size * 1.2 * u);
  final body = art.bodyOf(kind, e.variant);
  if (e.t < animS && body != null) {
    final frame = onceFrame(u, strip.frames), f = art.frame.toDouble();
    final src = ui.Rect.fromLTWH(frame * f, 0, f, f), dst = ui.Rect.fromCenter(center: c, width: size, height: size);
    void draw(ui.Image img, {ui.Color? tone}) {
      canvas.save();
      if (e.left) {
        canvas.translate(dst.center.dx, 0);
        canvas.scale(-1, 1);
        canvas.translate(-dst.center.dx, 0);
      }
      canvas.drawImageRect(img, src, dst, ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..colorFilter = tone == null ? null : ui.ColorFilter.mode(tone, ui.BlendMode.modulate));
      canvas.restore();
    }

    draw(body, tone: tone); // o corpo no tom da noite, como no mapa
    void light() {
      if (strip.glow case final g?) draw(g);
      if (strip.leds case final l?) draw(l);
    }

    emissive == null ? light() : emissive.add(light);
    return;
  }
  // Sintonizada: as faíscas vão da criatura até o Conjurador.
  final v = ((e.t - animS) / 0.45).clamp(0.0, 1.0), ease = v * v * (3 - 2 * v);
  final target = avatar.translate(0, -size * 0.3);
  void sparks() {
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + e.uid % 7;
      final from = c.translate(math.cos(a) * size * 0.3, math.sin(a) * size * 0.3);
      final p = ui.Offset.lerp(from, target, (ease * (1 + i * 0.06)).clamp(0.0, 1.0))!;
      final px = (size / 14).roundToDouble().clamp(2.0, 6.0);
      canvas.drawRect(ui.Rect.fromCenter(center: ui.Offset(p.dx.roundToDouble(), p.dy.roundToDouble()), width: px, height: px), ui.Paint()..color = (i.isEven ? kSignal : const ui.Color(0xFFFFD84A)).withValues(alpha: 1 - v * 0.5));
    }
  }

  emissive == null ? sparks() : emissive.add(sparks);
}
