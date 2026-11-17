/// O mapa que responde ao toque, na tela (0.24.2): que objeto está sob o dedo (ponto de ônibus, banca, árvore, poste,
/// placa de rua, bando, gato, poça) e as reações curtas desenhadas pelo `criativo` (pena e folha caindo, onda na poça,
/// poste piscando, coração do gato), presas ao mapa e por cima de tudo que é do mundo.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../world/city_scene.dart';
import '../../world/map_camera.dart';
import '../../world/map_touch.dart';
import '../../world/sim/birds.dart';
import '../craft/ui_art.dart';

/// Um objeto tocado: o tipo, a posição (células z21), a chave estável e, nos props, o tipo do carimbo.
typedef TouchHit = ({TouchKind kind, double x, double y, String key, String prop, BirdFlock? flock, (int, int)? cat});

TouchKind? _propKind(String kind) => switch (kind) {
      'bus_stop' => TouchKind.busStop,
      'newsstand' => TouchKind.newsstand,
      'lamp' => TouchKind.lamp,
      'street_sign' => TouchKind.sign,
      _ when kind.startsWith('tree') || kind.startsWith('ipe') => TouchKind.tree,
      _ => null,
    };

/// O objeto mais perto de [screen] a até [radiusPx]: os props dos [tiles] à vista, os bandos, os gatos e as poças
/// ([puddles], em células). Bichos ganham dos props (eles se mexem por cima).
TouchHit? touchHitAt(ui.Offset screen, ui.Size view, MapCamera cam, {required Iterable<CityTile> tiles, required BirdFlocks? birds, Iterable<(double, double)> puddles = const [], double radiusPx = 36}) {
  TouchHit? best;
  var bestD = radiusPx;
  void consider(TouchHit h, double sx, double sy, {double bias = 0}) {
    final d = (ui.Offset(sx, sy) - screen).distance - bias;
    if (d < bestD) {
      bestD = d;
      best = h;
    }
  }

  for (final t in tiles) {
    for (final p in t.props) {
      final k = _propKind(p.kind);
      if (k == null) continue;
      final (sx, sy) = cam.cellToScreen(p.x, p.y, view.width, view.height);
      consider((kind: k, x: p.x, y: p.y, key: '${p.kind}:${placeKey(p.x, p.y)}', prop: p.kind, flock: null, cat: null), sx, sy - 12);
    }
  }
  for (final (x, y) in puddles) {
    final (sx, sy) = cam.cellToScreen(x, y, view.width, view.height);
    consider((kind: TouchKind.puddle, x: x, y: y, key: 'puddle:${placeKey(x, y)}', prop: 'puddle', flock: null, cat: null), sx, sy);
  }
  if (birds != null) {
    for (final f in birds.flocks.values) {
      for (final b in f.birds) {
        final (sx, sy) = cam.cellToScreen(b.x, b.y, view.width, view.height);
        consider((kind: TouchKind.flock, x: f.x, y: f.y, key: 'flock:${placeKey(f.x, f.y)}', prop: 'flock', flock: f, cat: null), sx, sy, bias: 6);
      }
    }
    for (final c in birds.cats.entries) {
      final (sx, sy) = cam.cellToScreen(c.value.$1, c.value.$2, view.width, view.height);
      consider((kind: TouchKind.cat, x: c.value.$1, y: c.value.$2, key: 'cat:${c.key.$1}:${c.key.$2}', prop: 'cat', flock: null, cat: c.key), sx, sy, bias: 6);
    }
  }
  return best;
}

/// Quanto dura o balanço da copa tocada (0.24.3), em segundos.
const double kTreeSwayS = 1.4;

/// A copa da árvore tocada (0.24.3): quanto o topo sai do lugar, em pixels de arte, [age] segundos depois do toque. Um
/// balanço de 2 idas e voltas por segundo que amortece até parar em [kTreeSwayS]. Só desenho.
double treeSwayPx(double age) => age < 0 || age >= kTreeSwayS ? 0 : 3 * math.exp(-1.5 * age) * math.sin(2 * math.pi * 2 * age);

/// Uma reação na tela: a tira de quadros, onde (células) e desde quando (segundos de jogo). [fall] faz descer (pena, folha);
/// [lift] sobe a reação em pixels da tela (o clarão no alto do poste).
class TouchFx {
  TouchFx(this.strip, this.x, this.y, this.t0, {this.frames = 3, this.fps = 6, this.life = 1.2, this.fall = 0, this.lift = 0});

  final String strip;
  final double x, y, t0;
  final int frames;
  final double fps, life, fall, lift;
}

/// As reações vivas: acrescente com [add], desenhe com [paint] na camada do ar.
class TouchFxLayer {
  final _list = <TouchFx>[];

  void add(TouchFx f) => _list.add(f);

  bool get isEmpty => _list.isEmpty;

  /// Desenha as reações em [time], cada pixel de arte com [px] dp.
  void paint(ui.Canvas canvas, ui.Size view, MapCamera cam, double time, double px) {
    _list.removeWhere((f) => time - f.t0 > f.life);
    final art = UiArt.instance;
    if (art == null) return;
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
    for (final f in _list) {
      final img = art.image(f.strip);
      if (img == null) continue;
      final age = time - f.t0;
      final fw = img.width / f.frames, fh = img.height.toDouble();
      final k = math.min(f.frames - 1, (age * f.fps).floor() % (f.fall > 0 ? f.frames : f.frames + 1));
      final (sx, sy) = cam.cellToScreen(f.x, f.y, view.width, view.height);
      final dy = f.fall > 0 ? -f.fall * px * (1 - age / f.life) : 0.0;
      final dst = ui.Rect.fromLTWH((sx - fw * px / 2).roundToDouble(), (sy - fh * px - f.lift + dy).roundToDouble(), fw * px, fh * px);
      canvas.drawImageRect(img, ui.Rect.fromLTWH(k * fw, 0, fw, fh), dst, paint);
    }
  }
}
