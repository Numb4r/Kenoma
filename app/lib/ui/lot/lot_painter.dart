/// O desenho do lote no Véu (0.29.0, GDD rev 402): o vazio em volta, a borda com a costura, o terreno da dobra, os pisos, e
/// tudo o que fica de pé (paredes, objetos, criaturas, o Conjurador e o Familiar) na ordem da linha de baixo. Depois a
/// noite do mapa (o mesmo tom, pela hora real; sem clima), as luzes e os efeitos das estações. A arte vem de
/// `assets/art/ui/lot/` (o executor gera por script); sem ela, blocos de cor no lugar. Câmera fixa, sem giro.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/astro.dart' show DayLight;
import '../../core/fnv.dart';
import '../../player/lot.dart';
import '../craft/ui_art.dart';

/// Um ser no lote: a imagem (quadro já recortado), o lugar dos pés em casas e para que lado olha.
class LotBeing {
  const LotBeing({required this.image, required this.src, required this.x, required this.y, required this.sizePx, this.flip = false});

  final ui.Image? image;
  final Rect src;
  final double x, y;

  /// O lado do sprite em pixels de arte.
  final int sizePx;
  final bool flip;
}

/// O que o painel precisa para desenhar um quadro.
class LotFrame {
  const LotFrame({
    required this.grid,
    required this.camX,
    required this.camY,
    required this.time,
    required this.light,
    required this.beings,
    required this.working,
    this.ghost,
    this.ghostOk = true,
    this.selected,
    this.build = false,
  });

  final LotGrid grid;

  /// O centro da tela, em casas.
  final double camX, camY;

  /// Segundos (para as animações e efeitos).
  final double time;
  final DayLight light;
  final List<LotBeing> beings;

  /// As estações com alguém trabalhando agora (uid da peça): só elas mostram o efeito.
  final Set<int> working;

  /// O modo construir: a pegada fantasma (casas) e se a peça cabe ali; a peça escolhida para mover ou guardar.
  final List<(int, int)>? ghost;
  final bool ghostOk;
  final int? selected;
  final bool build;
}

/// Pixel de arte em dp, como o mapa (0.25.0).
const double kLotArtDp = 2;
const int kLotCellPx = 16;
const double kLotCellDp = kLotCellPx * kLotArtDp;

const _nightTint = Color(0xFF3F4A8C);
const _lampGlow = Color(0xFFFFD98A);

class LotPainter extends CustomPainter {
  LotPainter(this.f);

  final LotFrame f;

  ui.Image? _img(String name) => UiArt.instance?.image('lot/$name');

  Offset _screen(Size view, double x, double y) => Offset((x - f.camX) * kLotCellDp + view.width / 2, (y - f.camY) * kLotCellDp + view.height / 2);

  /// A casa da tela sob [p].
  static (int, int) cellAt(Size view, double camX, double camY, Offset p) =>
      (((p.dx - view.width / 2) / kLotCellDp + camX).floor(), ((p.dy - view.height / 2) / kLotCellDp + camY).floor());

  final _plain = Paint()..filterQuality = FilterQuality.none;

  /// Uma imagem com o canto de baixo à esquerda em [bottomLeft] (pixels de arte inteiros), ou o bloco de cor sem a arte.
  void _sprite(Canvas c, String name, Offset bottomLeft, {int fallbackW = 16, int fallbackH = 16, Color fallback = const Color(0xFF6E6658)}) {
    final img = _img(name);
    final x = bottomLeft.dx.roundToDouble(), y = bottomLeft.dy.roundToDouble();
    if (img == null) {
      c.drawRect(Rect.fromLTWH(x, y - fallbackH * kLotArtDp, fallbackW * kLotArtDp, fallbackH * kLotArtDp), Paint()..color = fallback);
      return;
    }
    c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromLTWH(x, y - img.height * kLotArtDp, img.width * kLotArtDp, img.height * kLotArtDp), _plain);
  }

  void _tile(Canvas c, Size view, String name, int cells, Rect area, Color fallback) {
    final img = _img(name);
    if (img == null) {
      c.drawRect(area, Paint()..color = fallback);
      return;
    }
    final side = cells * kLotCellDp;
    final origin = _screen(view, 0, 0);
    final x0 = origin.dx + ((area.left - origin.dx) / side).floor() * side, y0 = origin.dy + ((area.top - origin.dy) / side).floor() * side;
    c.save();
    c.clipRect(area);
    for (var y = y0; y < area.bottom; y += side) {
      for (var x = x0; x < area.right; x += side) {
        c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromLTWH(x, y, side, side), _plain);
      }
    }
    c.restore();
  }

  @override
  void paint(Canvas c, Size view) {
    final g = f.grid;
    final lot = Rect.fromPoints(_screen(view, g.min.toDouble(), g.min.toDouble()), _screen(view, g.max + 1.0, g.max + 1.0));
    // O vazio, a borda com a costura (que pulsa) e o terreno da dobra.
    _tile(c, view, 'void', 2, Offset.zero & view, const Color(0xFF120E1A));
    final pulse = 0.85 + 0.15 * math.sin(f.time * 2 * math.pi / 2.4);
    c.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, pulse));
    for (var i = g.min; i <= g.max; i++) {
      _sprite(c, 'edge_n', _screen(view, i.toDouble(), g.min.toDouble()), fallback: const Color(0xFF5A4A9E));
      _sprite(c, 'edge_s', _screen(view, i.toDouble(), g.max + 2.0), fallback: const Color(0xFF5A4A9E));
      _sprite(c, 'edge_o', _screen(view, g.min - 1.0, i + 1.0), fallback: const Color(0xFF5A4A9E));
      _sprite(c, 'edge_l', _screen(view, g.max + 1.0, i + 1.0), fallback: const Color(0xFF5A4A9E));
    }
    _sprite(c, 'edge_corner_no', _screen(view, g.min - 1.0, g.min.toDouble()), fallback: const Color(0xFF5A4A9E));
    _sprite(c, 'edge_corner_nl', _screen(view, g.max + 1.0, g.min.toDouble()), fallback: const Color(0xFF5A4A9E));
    _sprite(c, 'edge_corner_sl', _screen(view, g.max + 1.0, g.max + 2.0), fallback: const Color(0xFF5A4A9E));
    _sprite(c, 'edge_corner_so', _screen(view, g.min - 1.0, g.max + 2.0), fallback: const Color(0xFF5A4A9E));
    c.restore();
    // Tudo o que é do lote leva o tom da hora; o vazio e a costura, não.
    final lit = lot.inflate(0).expandToInclude(lot.shift(Offset(0, -2 * kLotCellDp)));
    c.saveLayer(lit, Paint());
    _tile(c, view, 'fold', 2, lot, const Color(0xFF48425E));
    for (final p in g.floor.values) {
      final d = g.defs[p.item]!;
      _sprite(c, d.spriteFor(p.rot), _screen(view, p.x.toDouble(), p.y + 1.0), fallback: const Color(0xFF9A6A3E));
    }
    for (final p in {...g.flat.values}) {
      final d = g.defs[p.item]!;
      final (_, h) = d.size(p.rot);
      _sprite(c, d.spriteFor(p.rot), _screen(view, p.x.toDouble(), p.y + h.toDouble()), fallbackW: d.size(p.rot).$1 * 16, fallbackH: h * 16, fallback: const Color(0xFF2F5FA8));
    }
    if (f.build) _gridLines(c, view, g);
    // De pé, pela linha de baixo: paredes (com o que está nelas), objetos e seres.
    final upright = <(double, void Function())>[];
    for (final w in g.wall.values) {
      upright.add((w.y + 1.0, () => _wall(c, view, g, w)));
    }
    for (final p in {...g.object.values}) {
      final d = g.defs[p.item]!;
      final (_, h) = d.size(p.rot);
      upright.add((p.y + h.toDouble(), () => _object(c, view, d, p)));
    }
    for (final b in f.beings) {
      upright.add((b.y, () => _being(c, view, b)));
    }
    upright.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, draw) in upright) {
      draw();
    }
    if (f.light.night > 0.004) c.drawRect(lit, Paint()..color = Color.lerp(const Color(0xFFFFFFFF), _nightTint, f.light.night)!..blendMode = BlendMode.multiply);
    if (f.light.warm > 0.004) c.drawRect(lit, Paint()..color = Color.fromRGBO(255, 138, 64, 0.17 * f.light.warm)..blendMode = BlendMode.srcATop);
    c.restore();
    if (f.light.night > 0.35) _lights(c, view, g);
    _effects(c, view, g);
    _buildOverlay(c, view, g);
  }

  void _gridLines(Canvas c, Size view, LotGrid g) {
    final p = Paint()..color = const Color(0x339B7BFF);
    for (var i = g.min; i <= g.max + 1; i++) {
      final a = _screen(view, i.toDouble(), g.min.toDouble()), b = _screen(view, i.toDouble(), g.max + 1.0);
      c.drawRect(Rect.fromLTWH(a.dx, a.dy, 1, b.dy - a.dy), p);
      final d = _screen(view, g.min.toDouble(), i.toDouble()), e = _screen(view, g.max + 1.0, i.toDouble());
      c.drawRect(Rect.fromLTWH(d.dx, d.dy, e.dx - d.dx, 1), p);
    }
  }

  void _wall(Canvas c, Size view, LotGrid g, Placement w) {
    final m = g.wallMask(w.x, w.y);
    final a = g.attach[(w.x, w.y)];
    final d = a == null ? null : g.defs[a.item];
    final at = _screen(view, w.x.toDouble(), w.y + 1.0);
    final on = f.light.night > 0.35;
    final name = switch (d?.sprite) {
      'door' => m == 5 ? 'door_v' : 'door_h',
      'window' => '${m == 5 ? 'window_v' : 'window_h'}_${on ? 'on' : 'off'}',
      _ => 'wall_${m.toString().padLeft(2, '0')}',
    };
    _sprite(c, name, at, fallbackH: 28, fallback: d?.walk ?? false ? const Color(0xFF9A6A3E) : const Color(0xFFA8A092));
    if (d?.sprite == 'picture') _sprite(c, 'picture', at.translate(4 * kLotArtDp, -7 * kLotArtDp), fallbackW: 8, fallbackH: 8, fallback: const Color(0xFFE8E4F4));
  }

  String _objectSprite(PieceDef d, Placement p) {
    final base = d.spriteFor(p.rot);
    if (d.light != null) return '${d.sprite}_${f.light.night > 0.35 ? 'on' : 'off'}';
    // A horta mexe as folhas e a prensa desce, de tempos em tempos, só com alguém trabalhando.
    if (f.working.contains(p.uid) && (d.effect == 'leaves' || d.effect == 'press')) {
      final period = d.effect == 'leaves' ? 2.5 + hashMod(fnv1a64([p.uid, 3]), 15) / 10 : 1.5;
      final on = d.effect == 'leaves' ? 0.3 : 0.2;
      if ((f.time + p.uid * 0.37) % period < on) return base.replaceFirst(d.sprite, '${d.sprite}_b');
    }
    return base;
  }

  void _object(Canvas c, Size view, PieceDef d, Placement p) {
    final (w, h) = d.size(p.rot);
    _sprite(c, _objectSprite(d, p), _screen(view, p.x.toDouble(), p.y + h.toDouble()), fallbackW: w * 16, fallbackH: h * 16 + 8, fallback: d.station != null ? const Color(0xFF7E8A94) : const Color(0xFF9A6A3E));
  }

  void _being(Canvas c, Size view, LotBeing b) {
    final img = b.image;
    final side = b.sizePx * kLotArtDp;
    final feet = _screen(view, b.x, b.y);
    final dst = Rect.fromLTWH((feet.dx - side / 2).roundToDouble(), (feet.dy - side).roundToDouble(), side, side);
    c.drawOval(Rect.fromCenter(center: feet, width: side * 0.5, height: side * 0.12), Paint()..color = const Color(0x731A1424));
    if (img == null) return;
    if (b.flip) {
      c.save();
      c.translate(dst.center.dx, 0);
      c.scale(-1, 1);
      c.translate(-dst.center.dx, 0);
    }
    c.drawImageRect(img, b.src, dst, _plain);
    if (b.flip) c.restore();
  }

  void _halo(Canvas c, Offset at, List<double> radii) {
    const alphas = [0.34, 0.2, 0.1];
    for (var i = radii.length - 1; i >= 0; i--) {
      c.drawCircle(at, radii[i] * kLotArtDp, Paint()..color = _lampGlow.withValues(alpha: alphas[i] * f.light.night));
    }
  }

  void _lights(Canvas c, Size view, LotGrid g) {
    for (final p in {...g.object.values}) {
      final d = g.defs[p.item]!;
      if (d.light == null) continue;
      final at = _screen(view, p.x.toDouble(), p.y + 1.0);
      final wobble = d.light == 'candle' ? (math.sin(f.time * (5 + p.uid % 3)) > 0 ? 1.0 : 0.0) : 0.0;
      _halo(c, at.translate(8 * kLotArtDp, -(d.light == 'lamp' ? 18 : 8) * kLotArtDp), d.light == 'lamp' ? [16, 28, 40] : [8 + wobble, 14 + wobble, 20 + wobble]);
      _sprite(c, '${d.sprite}_on', at); // a chama e o vidro, sem o tom da noite
    }
    for (final w in g.wall.values) {
      final a = g.attach[(w.x, w.y)];
      if (a == null || g.defs[a.item]?.sprite != 'window') continue;
      _sprite(c, '${g.wallMask(w.x, w.y) == 5 ? 'window_v' : 'window_h'}_on', _screen(view, w.x.toDouble(), w.y + 1.0), fallbackH: 28);
    }
  }

  /// Os efeitos das estações com alguém trabalhando (a spec do criativo): partículas de 1 pixel de arte, pelo relógio.
  void _effects(Canvas c, Size view, LotGrid g) {
    void px(Offset at, Color col) => c.drawRect(Rect.fromLTWH(at.dx.roundToDouble(), at.dy.roundToDouble(), kLotArtDp, kLotArtDp), Paint()..color = col);
    for (final p in {...g.object.values}) {
      if (!f.working.contains(p.uid)) continue;
      final d = g.defs[p.item]!;
      final (w, h) = d.size(p.rot);
      final base = _screen(view, p.x.toDouble(), p.y + h.toDouble());
      final mid = base.translate(w * kLotCellDp / 2, -h * kLotCellDp * 0.6);
      switch (d.effect) {
        case 'ember':
          for (var k = 0; k < 3; k++) {
            final life = 0.8 + hashMod(fnv1a64([p.uid, k]), 5) / 10;
            final u = ((f.time + k / 3) % life) / life;
            const cols = [Color(0xFFFF9C7A), Color(0xFFF0502E), Color(0xFFA82E1C)];
            final drift = math.sin((f.time + k) * 3) * 2;
            px(mid.translate(drift * kLotArtDp, -(6 + 4 * u) * u * kLotArtDp), cols[(u * 3).floor().clamp(0, 2)]);
          }
          if (f.light.night > 0.35) c.drawCircle(mid, 14 * kLotArtDp, Paint()..color = const Color(0xFFF0502E).withValues(alpha: 0.25 * f.light.night));
        case 'drip':
          final u = (f.time % 1.6);
          final spout = base.translate(w * kLotCellDp * 0.8, -h * kLotCellDp * 0.55);
          if (u < 0.4) px(spout.translate(0, u / 0.4 * 5 * kLotArtDp), const Color(0xFFA4D0FF));
          if (u >= 0.4 && u < 0.5) {
            px(spout.translate(-kLotArtDp, 5 * kLotArtDp), const Color(0xFF4A9CFF));
            px(spout.translate(kLotArtDp, 5 * kLotArtDp), const Color(0xFF4A9CFF));
          }
        case 'mote':
          final u = (f.time % 3) / 2;
          if (u < 1) px(mid.translate(0, -4 * u * kLotArtDp), const Color(0xFFD2ABD6).withValues(alpha: 0.6));
        case 'card':
          final u = f.time % 4;
          if (u < 1) {
            c.drawRect(Rect.fromLTWH(mid.dx.roundToDouble(), (mid.dy - 3 * u * kLotArtDp).roundToDouble(), kLotArtDp, 2 * kLotArtDp), Paint()..color = const Color(0xFFF2F7FF));
          }
        case 'press':
          if ((f.time + p.uid * 0.37) % 1.5 < 0.2) {
            px(mid.translate(-2 * kLotArtDp, 0), const Color(0xFFCCD6E2));
            px(mid.translate(3 * kLotArtDp, -kLotArtDp), const Color(0xFFCCD6E2));
          }
      }
    }
  }

  void _buildOverlay(Canvas c, Size view, LotGrid g) {
    final ghost = f.ghost;
    if (ghost != null) {
      final col = (f.ghostOk ? const Color(0xFF5FD3C6) : const Color(0xFFFF7A45)).withValues(alpha: 0.45);
      for (final (x, y) in ghost) {
        c.drawRect(Rect.fromPoints(_screen(view, x.toDouble(), y.toDouble()), _screen(view, x + 1.0, y + 1.0)), Paint()..color = col);
      }
    }
    final sel = f.selected;
    if (sel != null) {
      final p = g.state.placed.where((q) => q.uid == sel).firstOrNull;
      final d = p == null ? null : g.defs[p.item];
      if (p != null && d != null) {
        final (w, h) = d.layer == PieceLayer.object || d.layer == PieceLayer.flat ? d.size(p.rot) : (1, 1);
        final r = Rect.fromPoints(_screen(view, p.x.toDouble(), p.y.toDouble()), _screen(view, p.x + w.toDouble(), p.y + h.toDouble()));
        c.drawRect(r, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = kLotArtDp
          ..color = const Color(0xFF9B7BFF));
      }
    }
  }

  @override
  bool shouldRepaint(LotPainter old) => true;
}
