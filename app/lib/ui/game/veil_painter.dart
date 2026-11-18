/// O desenho dos Outros Veilbreakers e do Ônibus Espectral (0.24.5): quem decide onde e quando é o mundo
/// (`world/veilbreakers.dart`, `world/spectral_bus.dart`); aqui só se desenha.
library;

import 'dart:math' as math;
import 'dart:ui';

import '../../world/city_scene.dart' show CityTile;
import '../../world/map_camera.dart';
import '../../world/map_touch.dart' show TouchBalance, placeKey;
import '../../world/spectral_bus.dart';
import '../../world/veilbreakers.dart';
import '../colors.dart';
import '../craft/ui_art.dart';
import 'spawn_painter.dart' show anchoredRect;

final _px = Paint()
  ..filterQuality = FilterQuality.none
  ..isAntiAlias = false;

/// Um quadro de uma tira de quadros quadrados, de pé, com os pés em [foot] (tela), [size] de altura, espelhado se [left].
void _strip(Canvas c, Image img, int frame, Offset foot, double size, {bool left = false, double alpha = 1}) {
  final fw = img.height.toDouble(), n = (img.width / fw).floor();
  final dst = Rect.fromLTWH((foot.dx - size / 2).roundToDouble(), (foot.dy - size).roundToDouble(), size, size);
  final p = alpha >= 1 ? _px : (Paint()..filterQuality = FilterQuality.none..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0, 1)));
  c.save();
  if (left) {
    c.translate(dst.center.dx, 0);
    c.scale(-1, 1);
    c.translate(-dst.center.dx, 0);
  }
  c.drawImageRect(img, Rect.fromLTWH((frame % n) * fw, 0, fw, fw), dst, p);
  c.restore();
}

/// Os NPCs presentes em [t] e a sintonia de cada um (o anel fechando no Eco e o fio do sinal até ele). [fallback]: os quadros
/// do Conjurador, se a arte do NPC faltar.
void paintVeilbreakers(Canvas c, Size view, MapCamera cam, List<Veilbreaker> npcs, double t, {required double size, required List<Image> fallback, Offset? Function(int uid)? anchorOf, double? ecoSize}) {
  final art = UiArt.instance;
  for (final n in npcs) {
    if (!n.presentAt(t)) continue;
    final p = n.at(t);
    final (sx, sy) = cam.cellToScreen(p.x, p.y, view.width, view.height);
    if (sx < -size || sy < -size || sx > view.width + size || sy > view.height + size * 2) continue;
    final screenHeading = p.heading + cam.rotation;
    final left = math.cos(screenHeading) < 0;
    final img = art?.image('npc_${n.school}_${n.outfit}');
    final frame = p.walking ? 1 + (t * 4).floor() % 2 : 0;
    // Sombra nos pés, como a do Conjurador.
    c.drawOval(Rect.fromCenter(center: Offset(sx, sy - size * 0.04), width: size * 0.62, height: size * 0.14), Paint()..color = kOutline.withValues(alpha: 0.45));
    if (img != null) {
      _strip(c, img, frame, Offset(sx, sy), size, left: left);
    } else if (fallback.isNotEmpty) {
      _strip(c, fallback[frame % fallback.length], 0, Offset(sx, sy), size, left: left, alpha: 0.85);
    }
    final tu = n.tuningAt(t);
    if (tu == null) continue;
    // 0.25.0: o anel e o fio se centram no ponto de ancoragem do Eco (onde ele foi desenhado, com o vento).
    final (rx, ry) = cam.cellToScreen(tu.eco.x, tu.eco.y, view.width, view.height);
    final eco = anchorOf?.call(tu.eco.uid) ?? Offset(rx.roundToDouble(), ry.roundToDouble());
    final k = ((t - tu.atUtc) / n.animS).clamp(0.0, 0.999);
    c.drawLine(Offset(sx, sy - size * 0.6), eco, Paint()
      ..color = kSignal.withValues(alpha: 0.5 * (1 - k))
      ..strokeWidth = math.max(1, size / 16));
    final fx = art?.image('fx_npc_tune');
    if (fx != null) {
      final fw = fx.height.toDouble(), frame = (k * 4).floor() % (fx.width / fw).floor();
      c.drawImageRect(fx, Rect.fromLTWH(frame * fw, 0, fw, fw), anchoredRect(eco, (ecoSize ?? size) * 1.2), _px);
    }
  }
}

/// O Ônibus Espectral nos pontos de [tiles] em [t] (segundos UTC com fração), com o passageiro que desce ou embarca.
/// [pxPerM]: pixels de tela por metro; [mpc]: metros por célula z21.
void paintSpectralBuses(Canvas c, Size view, MapCamera cam, Iterable<CityTile> tiles, double t, {required int seed, required TouchBalance b, required double pxPerM, required double mpc, required double carM, required double figure}) {
  final art = UiArt.instance;
  final bus = art?.image('bus_spectral'), rider = art?.image('spectral_passenger');
  for (final tile in tiles) {
    for (final p in tile.props) {
      if (p.kind != 'bus_stop' || p.roadX == null) continue;
      final pass = spectralBusAt(seed: seed, stopKey: placeKey(p.x, p.y), t: t, b: b);
      if (pass == null) continue;
      // A mão: o ponto fica à direita de quem passa. A faixa fica entre o eixo da rua e o ponto.
      var a = p.angle;
      final vx = p.x - p.roadX!, vy = p.y - p.roadY!, vl = math.sqrt(vx * vx + vy * vy);
      if (vx * -math.sin(a) + vy * math.cos(a) < 0) a += math.pi;
      final off = vl <= 0 ? 0.0 : math.min(vl * 0.5, 2.2 / mpc) / vl;
      final lx = p.roadX! + vx * off, ly = p.roadY! + vy * off;
      final bx = lx + math.cos(a) * pass.alongM / mpc, by = ly + math.sin(a) * pass.alongM / mpc;
      final (sx, sy) = cam.cellToScreen(bx, by, view.width, view.height);
      final len = carM * 2.2 * pxPerM;
      if (sx < -len || sy < -len || sx > view.width + len || sy > view.height + len) continue;
      // Some e aparece nas pontas do trajeto, em vez de surgir do nada.
      final edge = (1 - pass.alongM.abs() / b.busRunM).clamp(0.0, 1.0);
      final alpha = 0.85 * math.min(1, edge * 4);
      if (bus != null) {
        c.save();
        c.translate(sx, sy);
        c.rotate(a + cam.rotation);
        final w = len * bus.height / bus.width;
        c.drawImageRect(bus, Rect.fromLTWH(0, 0, bus.width.toDouble(), bus.height.toDouble()), Rect.fromCenter(center: Offset.zero, width: len, height: w), Paint()
          ..filterQuality = FilterQuality.none
          ..color = Color.fromRGBO(255, 255, 255, alpha));
        c.restore();
      } else {
        c.drawCircle(Offset(sx, sy), len / 4, Paint()..color = kVeil.withValues(alpha: alpha * 0.5));
      }
      final r = spectralRiderAt(pass.rider, t - pass.arriveUtc, b);
      if (r == null || rider == null) continue;
      final px = lx + (p.x - lx) * r.t, py = ly + (p.y - ly) * r.t;
      final (rx, ry) = cam.cellToScreen(px, py, view.width, view.height);
      _strip(c, rider, (t * 3).floor() % 2, Offset(rx, ry), figure, left: rx < sx, alpha: r.alpha * 0.85);
    }
  }
}
