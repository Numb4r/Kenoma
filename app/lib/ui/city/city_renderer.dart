/// O mapa no estilo Completo (0.22.0): o chão parado em blocos de cache e o que fica de pé por cima, a cada quadro.
///
/// **Giro.** O chão gira com o mapa, mas nunca como imagem pronta: cada bloco (4 × 4 células z21) é rasterizado já girado,
/// em pixels de arte alinhados à tela. Com o mapa parado, todo bloco está no giro e no zoom exatos e só desliza por pixels
/// inteiros (nenhum pixel fora da grade). Durante o arrasto ou a pinça os blocos são do ângulo mais próximo, em passos de
/// [angleStepDeg] graus, e do zoom do começo do gesto, desenhados com o resto do giro e da escala; quando o dedo solta, são
/// refeitos no ângulo exato. Tudo que tem altura (prédios, árvores, postes, props) é desenhado de pé, na tela.
///
/// **Cache.** Um bloco só é refeito quando entra na tela, quando muda o giro ou o zoom do alvo, a faixa da luz, a chuva no
/// asfalto ou o nível de detalhe ([GroundKey]); cada quadro refaz no máximo o que cabe em [budgetMs] (os que faltam saem
/// primeiro). Só desenho.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../world/city_scene.dart';
import '../../world/map_camera.dart';
import '../lab/lab_art.dart';
import 'city_ground.dart';
import 'city_upright.dart';

/// O passo do giro dos blocos durante o gesto.
const double angleStepDeg = 3;

/// O passo do zoom dos blocos durante a pinça (0.23.2): 6%, então o chão estica no máximo uns 3% até o passo seguinte.
const double zoomStep = 1.06;

/// Acima disto (metros de largura da tela) o mapa usa o nível de detalhe de longe.
const double farWidthM = 65;

class CityRenderer {
  CityRenderer({required this.art, required this.tileAt, required this.biomeAt, required this.cellsPerTile, this.chunkCells = 4, this.budgetMs = 4, this.maxChunks = 160, this.nowUs}) : upright = CityUpright(art);

  final LabArt art;

  /// A cena de um tile z15 (o chamador guarda o cache dos tiles).
  final CityTile Function(int tx, int ty) tileAt;

  /// A altura (metros de desenho, `fakeHeightPx`) do prédio sob o ponto ([x], [y], células z21), ou `null` se é chão. O pássaro
  /// que pousa ali fica no telhado (0.24.2).
  double? roofHeightAt(double x, double y) {
    final t = tileAt((x / cellsPerTile).floor(), (y / cellsPerTile).floor());
    for (final b in t.buildings) {
      final xy = b.xy;
      var inside = false;
      for (var i = 0, j = xy.length - 2; i < xy.length; j = i, i += 2) {
        if ((xy[i + 1] > y) != (xy[j + 1] > y) && x < (xy[j] - xy[i]) * (y - xy[i + 1]) / (xy[j + 1] - xy[i + 1]) + xy[i]) inside = !inside;
      }
      if (inside) return b.look.fakeHeightPx.toDouble();
    }
    return null;
  }
  final String Function(int cx, int cy) biomeAt;
  final int cellsPerTile;
  final int chunkCells;
  final double budgetMs;
  final int maxChunks;
  final CityUpright upright;

  final _chunks = <(int, int), GroundChunk>{}; // na ordem de uso (o mapa do Dart guarda a ordem)
  double? _lastAngle, _lastKc;
  double _targetKc = 0;
  final _clock = Stopwatch()..start();

  /// O relógio em microssegundos (o teste passa o dele).
  final int Function()? nowUs;
  int _movedAtUs = -1 << 40;

  /// Estatísticas do último quadro (debug, teste e números do workbench).
  int rebuiltLastFrame = 0, rebuiltTotal = 0, drawnChunks = 0;
  double groundMs = 0, uprightMs = 0, rasterChunkMs = 0;

  /// No último quadro, todo bloco estava no giro e no zoom exatos e num deslocamento inteiro: nenhum pixel fora da grade.
  bool onGrid = false;

  /// O giro e o zoom de alvo do último quadro (teste).
  double targetAngle = 0, targetKc = 0;

  int get cachedChunks => _chunks.length;

  /// Pixels físicos por pixel de arte.
  static int pixelSize(double artPixelDp, double dpr) => math.max(1, (artPixelDp * dpr).round());

  /// A âncora do quadro: muda só a cada 1024 células (~18 km), então os blocos quase nunca perdem o quadro por ela.
  static (double, double) anchorOf(MapCamera cam) => ((cam.centerX / 1024).floor() * 1024.0, (cam.centerY / 1024).floor() * 1024.0);

  double _kcHeld = 0;

  /// O zoom do quadro, preso enquanto o de verdade não sair 0,3% dele: andando, a escala muda em frações ínfimas com a
  /// latitude, e cada fração refazia um bloco por quadro. O chão e o que fica de pé usam o mesmo valor (menos de 1 pixel de
  /// diferença na borda da tela).
  double stableKc(double kc) {
    if (_kcHeld == 0 || (kc / _kcHeld - 1).abs() > 0.003) _kcHeld = kc;
    return _kcHeld;
  }

  /// O giro e o zoom que os blocos devem ter agora: os exatos com o mapa parado; no gesto, o passo do giro e o zoom de antes.
  (double, double) target(double angle, double kc, {required bool touching}) {
    final now = nowUs?.call() ?? _clock.elapsedMicroseconds;
    final rotating = _lastAngle != null && (angle - _lastAngle!).abs() > 1e-7;
    final zooming = _lastKc != null && (kc - _lastKc!).abs() > 1e-7;
    if (rotating || zooming) _movedAtUs = now;
    _lastAngle = angle;
    _lastKc = kc;
    final settled = !touching && now - _movedAtUs > 250000;
    if (settled || _targetKc == 0) {
      _targetKc = kc;
      return (angle, kc);
    }
    final step = angleStepDeg * math.pi / 180;
    // 0.23.2: na pinça o zoom também anda em passos (`zoomStep`, a partir do zoom do começo do gesto): o bloco é refeito a
    // cada passo e só estica até meio passo, em vez de esticar o gesto inteiro.
    final lz = math.log(zoomStep);
    final k = (math.log(kc / _targetKc) / lz).round();
    return ((angle / step).round() * step, _targetKc * math.exp(k * lz));
  }

  /// Desenha o chão. [touching]: o dedo está na tela. [wet]: o asfalto está molhado.
  void paintGround(ui.Canvas canvas, ui.Size size, MapCamera cam, {required double dpr, required double artPixelDp, required double mpc, required double sunAltDeg, required double sunAzDeg, required bool wet, required bool touching}) {
    final sw = Stopwatch()..start();
    final k = pixelSize(artPixelDp, dpr);
    final kc = stableKc(cam.pixelsPerCell * dpr / k);
    final (ox, oy) = anchorOf(cam);
    final exact = CityFrame(angle: cam.rotation, kc: kc, ox: ox, oy: oy);
    final (ta, tk) = target(cam.rotation, kc, touching: touching);
    targetAngle = ta;
    targetKc = tk;
    final goal = CityFrame(angle: ta, kc: tk, ox: ox, oy: oy);
    final far = size.width / cam.pixelsPerCell * mpc > farWidthM;
    final key = groundKeyFor(sunAltDeg: sunAltDeg, sunAzDeg: sunAzDeg, wet: wet, far: far);
    final off = _offset(size, dpr, k, cam, exact);
    // Os blocos que a tela toca (com um bloco de folga), do centro para fora.
    final (l, t, r, b) = cam.visibleBounds(size.width, size.height);
    final ids = <(int, int)>[];
    for (var y = (t / chunkCells).floor() - 1; y <= (b / chunkCells).floor() + 1; y++) {
      for (var x = (l / chunkCells).floor() - 1; x <= (r / chunkCells).floor() + 1; x++) {
        ids.add((x, y));
      }
    }
    final ccx = cam.centerX / chunkCells, ccy = cam.centerY / chunkCells;
    double dist((int, int) id) => (id.$1 + 0.5 - ccx) * (id.$1 + 0.5 - ccx) + (id.$2 + 0.5 - ccy) * (id.$2 + 0.5 - ccy);
    final missing = [for (final id in ids) if (!_chunks.containsKey(id)) id]..sort((a, b) => dist(a).compareTo(dist(b)));
    final stale = [for (final id in ids) if (_chunks[id] case final c? when c.frame != goal || c.key != key || _dirty.contains(id)) id]..sort((a, b) => dist(a).compareTo(dist(b)));
    rebuiltLastFrame = 0;
    final rs = Stopwatch()..start();
    for (final id in [...missing, ...stale]) {
      final isMissing = !_chunks.containsKey(id);
      if (!isMissing && rebuiltLastFrame > 0 && rs.elapsedMicroseconds > budgetMs * 1000) break;
      _build(id, goal, key, sunAltDeg, sunAzDeg, mpc);
      rebuiltLastFrame++;
    }
    rasterChunkMs = rs.elapsedMicroseconds / 1000;
    rebuiltTotal += rebuiltLastFrame;
    if (prefetch) _prefetch(cam, size, goal, key, sunAltDeg, sunAzDeg, mpc);
    // Desenha: o bloco exato só desliza por pixels inteiros; o de outro giro ou zoom leva o resto do giro e da escala.
    canvas.save();
    canvas.scale(k / dpr);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
    onGrid = true;
    drawnChunks = 0;
    for (final id in ids) {
      final c = _chunks[id];
      if (c == null) continue;
      _chunks.remove(id);
      _chunks[id] = c; // o mais usado por último
      drawnChunks++;
      if (c.frame == exact) {
        canvas.drawImage(c.image, ui.Offset(off.dx + c.left, off.dy + c.top), paint);
        continue;
      }
      onGrid = false;
      canvas.save();
      canvas.translate(off.dx, off.dy);
      canvas.rotate(exact.angle - c.frame.angle);
      final sc = exact.kc / c.frame.kc;
      canvas.scale(sc);
      canvas.drawImage(c.image, ui.Offset(c.left.toDouble(), c.top.toDouble()), paint);
      canvas.restore();
    }
    canvas.restore();
    while (_chunks.length > maxChunks) {
      _chunks.remove(_chunks.keys.first)?.image.dispose();
    }
    groundMs = sw.elapsedMicroseconds / 1000;
  }

  /// 0.22.2: monta fora do quadro os blocos em volta da tela (um anel de 2 blocos além da folga), do mais perto para o mais
  /// longe: a gravação roda depois do quadro (`scheduleMicrotask`, fora da fase de desenho) e a rasterização no thread de raster (`toImage`, assíncrono). Um
  /// por vez. Quando o jogador anda, o bloco que vai entrar na tela já está pronto e o quadro não tem tranco.
  bool prefetch = true;
  final _pending = <(int, int)>{};
  final _dirty = <(int, int)>{};
  int prefetchedTotal = 0;

  /// O anel em volta da tela está todo pronto (teste).
  bool prefetchDone = false;

  void _prefetch(MapCamera cam, ui.Size size, CityFrame goal, GroundKey key, double sunAltDeg, double sunAzDeg, double mpc) {
    if (_pending.isNotEmpty) return;
    final (l, t, r, b) = cam.visibleBounds(size.width, size.height);
    final ccx = cam.centerX / chunkCells, ccy = cam.centerY / chunkCells;
    (int, int)? best;
    var bd = double.infinity;
    for (var y = (t / chunkCells).floor() - 3; y <= (b / chunkCells).floor() + 3; y++) {
      for (var x = (l / chunkCells).floor() - 3; x <= (r / chunkCells).floor() + 3; x++) {
        final c = _chunks[(x, y)];
        if (c != null && c.frame == goal && c.key == key && !_dirty.contains((x, y))) continue;
        final d = (x + 0.5 - ccx) * (x + 0.5 - ccx) + (y + 0.5 - ccy) * (y + 0.5 - ccy);
        if (d < bd) (best, bd) = ((x, y), d);
      }
    }
    final id = best;
    prefetchDone = id == null;
    if (id == null) return;
    _pending.add(id);
    scheduleMicrotask(() {
      final x0 = id.$1 * chunkCells, y0 = id.$2 * chunkCells;
      final l = x0 - 3.0, t = y0 - 3.0, r = x0 + chunkCells + 3.0, b = y0 + chunkCells + 3.0;
      final tiles = [for (final tile in _tilesAround(l, t, r, b)) tile.within(l, t, r, b)];
      final rec = recordGroundChunk(cx0: x0, cy0: y0, size: chunkCells, f: goal, key: key, sunAltDeg: sunAltDeg, sunAzDeg: sunAzDeg, mpc: mpc, art: art, tiles: tiles, biomeAt: biomeAt);
      rec.toImage().then((c) {
        _pending.remove(id);
        final old = _chunks[id];
        // Só entra se ainda vale e se ninguém montou o mesmo bloco no quadro enquanto rasterizava.
        if (_disposed || (old != null && old.frame == c.frame && old.key == c.key && !_dirty.contains(id))) {
          c.image.dispose();
          return;
        }
        _chunks.remove(id)?.image.dispose();
        _chunks[id] = c;
        _dirty.remove(id);
        prefetchedTotal++;
      });
    });
  }

  bool _disposed = false;

  /// O deslocamento inteiro (pixels de arte) do quadro até a tela: o centro da câmera cai no centro da tela.
  ui.Offset _offset(ui.Size size, double dpr, int k, MapCamera cam, CityFrame f) {
    final cam0 = f.map(cam.centerX, cam.centerY);
    return ui.Offset((size.width * dpr / 2 / k - cam0.dx).roundToDouble(), (size.height * dpr / 2 / k - cam0.dy).roundToDouble());
  }

  void _build((int, int) id, CityFrame goal, GroundKey key, double sunAltDeg, double sunAzDeg, double mpc) {
    final x0 = id.$1 * chunkCells, y0 = id.$2 * chunkCells;
    _chunks.remove(id)?.image.dispose();
    _dirty.remove(id);
    // Só o que toca o bloco, com 3 células de folga (a sombra de um prédio alto ao lado, uma rua larga na borda).
    final l = x0 - 3.0, t = y0 - 3.0, r = x0 + chunkCells + 3.0, b = y0 + chunkCells + 3.0;
    final tiles = [for (final tile in _tilesAround(l, t, r, b)) tile.within(l, t, r, b)];
    _chunks[id] = rasterGroundChunk(cx0: x0, cy0: y0, size: chunkCells, f: goal, key: key, sunAltDeg: sunAltDeg, sunAzDeg: sunAzDeg, mpc: mpc, art: art, tiles: tiles, biomeAt: biomeAt);
  }

  List<CityTile> _tilesAround(double l, double t, double r, double b) => [
        for (var ty = (t / cellsPerTile).floor(); ty <= (b / cellsPerTile).floor(); ty++)
          for (var tx = (l / cellsPerTile).floor(); tx <= (r / cellsPerTile).floor(); tx++) tileAt(tx, ty),
      ];

  /// Desenha o que fica de pé, num buffer de pixels de arte ampliado por vizinho mais próximo. [items]: onde estão as
  /// coisas do jogo na tela (pixels lógicos): o telhado ou a copa por cima delas fica translúcido. [skyFraction]: a altura
  /// da faixa do céu na tela (0 a 0,10).
  void paintUpright(ui.Canvas canvas, ui.Size size, MapCamera cam, {required double dpr, required double artPixelDp, required double mpc, required double sunAltDeg, required double sunAzDeg, required int localHour, required int month, required bool snowRoofs, required List<ui.Offset> items, double skyFraction = 0, String skyClimate = 'clear', double Function(double x, double y)? sway}) {
    final sw = Stopwatch()..start();
    final k = pixelSize(artPixelDp, dpr);
    final lowW = (size.width * dpr / k).ceil(), lowH = (size.height * dpr / k).ceil();
    if (lowW <= 0 || lowH <= 0) return;
    final kc = stableKc(cam.pixelsPerCell * dpr / k);
    final (ox, oy) = anchorOf(cam);
    final f = CityFrame(angle: cam.rotation, kc: kc, ox: ox, oy: oy);
    final off = _offset(size, dpr, k, cam, f);
    final far = size.width / cam.pixelsPerCell * mpc > farWidthM;
    final (l, t, r, b) = cam.visibleBounds(size.width, size.height);
    final tiles = _tilesAround(l - 3, t - 3, r + 3, b + 3);
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec, ui.Rect.fromLTWH(0, 0, lowW.toDouble(), lowH.toDouble()));
    upright.paint(
      c,
      UprightView(
        frame: f,
        offset: off,
        size: ui.Size(lowW.toDouble(), lowH.toDouble()),
        mpc: mpc,
        sunAltDeg: sunAltDeg,
        sunAzDeg: sunAzDeg,
        localHour: localHour,
        month: month,
        far: far,
        snowRoofs: snowRoofs,
        items: [for (final p in items) p * dpr / k.toDouble()],
        skyPx: (lowH * skyFraction.clamp(0.0, 0.10)).floor(),
        skyClimate: skyClimate,
        sway: sway,
      ),
      tiles,
    );
    final pic = rec.endRecording();
    final img = pic.toImageSync(lowW, lowH);
    pic.dispose();
    canvas.drawImageRect(img, ui.Rect.fromLTWH(0, 0, lowW.toDouble(), lowH.toDouble()), ui.Rect.fromLTWH(0, 0, lowW * k / dpr, lowH * k / dpr), ui.Paint()..filterQuality = ui.FilterQuality.none);
    img.dispose();
    uprightMs = sw.elapsedMicroseconds / 1000;
  }

  /// Esquece os blocos que tocam o retângulo (células z21), com a folga de 3 células que cada bloco lê em volta: chegaram os
  /// prédios desse pedaço.
  void invalidateArea(double l, double t, double r, double b) {
    for (final id in [..._chunks.keys]) {
      final x0 = id.$1 * chunkCells - 3.0, y0 = id.$2 * chunkCells - 3.0;
      if (x0 + chunkCells + 6 < l || x0 > r || y0 + chunkCells + 6 < t || y0 > b) continue;
      _dirty.add(id); // continua desenhado até ser refeito (no orçamento do quadro ou em segundo plano)
    }
  }

  /// Esquece todos os blocos (chegou bloco ou região nova, ou trocou o estilo).
  void clear() {
    for (final c in _chunks.values) {
      c.image.dispose();
    }
    _chunks.clear();
  }

  void dispose() {
    _disposed = true;
    clear();
  }
}
