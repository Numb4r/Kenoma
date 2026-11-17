import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/data/climate_catalog.dart';
import 'package:kenoma/ui/city/city_renderer.dart';
import 'package:kenoma/ui/city/city_sources.dart';
import 'package:kenoma/ui/game/climate_painter.dart';
import 'package:kenoma/ui/lab/lab_art.dart';
import 'package:kenoma/ui/sprites/map_style.dart';
import 'package:kenoma/world/city_scene.dart';
import 'package:kenoma/world/lab_block.dart';
import 'package:kenoma/world/map_camera.dart';

import '../support/fixtures.dart';

/// 0.22.0: o estilo Completo no mapa. O chão em blocos de cache girados na grade da tela, o que tem altura de pé, o cache
/// refeito só quando precisa, o nível de detalhe, o telhado translúcido, a neve no telhado e o orçamento de partículas.
void main() {
  const view = ui.Size(360, 780);
  final block = LabBlock.fromJson(jsonDecode(File('assets/lab/centro_bloco.json').readAsStringSync()) as Map<String, dynamic>);
  final tiles = LabCityTiles(block);
  late LabArt art;
  setUpAll(() => art = LabArt.build());
  tearDownAll(() => art.dispose());

  double ppcFor(double widthM) => view.width / (widthM / tiles.mpc);
  MapCamera camAt(double xm, double ym, {double rot = 0, double widthM = 50}) {
    final (x, y) = tiles.toCells(xm, ym);
    return MapCamera(centerX: x, centerY: y, pixelsPerCell: ppcFor(widthM), rotation: rot);
  }

  var nowUs = 0;
  CityRenderer make({CityTile Function(int, int)? tileAt, bool prefetch = false}) => CityRenderer(art: art, tileAt: tileAt ?? tiles.tileAt, biomeAt: tiles.biomeAt, cellsPerTile: 64, budgetMs: 1000, nowUs: () => nowUs)..prefetch = prefetch;

  ui.Image ground(CityRenderer c, MapCamera cam, {double alt = 39, double az = 80, bool wet = false, bool touching = false}) {
    final rec = ui.PictureRecorder();
    c.paintGround(ui.Canvas(rec), view, cam, dpr: 1, artPixelDp: 3, mpc: tiles.mpc, sunAltDeg: alt, sunAzDeg: az, wet: wet, touching: touching);
    return rec.endRecording().toImageSync(view.width.toInt(), view.height.toInt());
  }

  ui.Image upright(CityRenderer c, MapCamera cam, {List<ui.Offset> items = const [], bool snow = false}) {
    final rec = ui.PictureRecorder();
    c.paintUpright(ui.Canvas(rec), view, cam, dpr: 1, artPixelDp: 3, mpc: tiles.mpc, sunAltDeg: 40, sunAzDeg: 80, localHour: 10, month: 11, snowRoofs: snow, items: items);
    return rec.endRecording().toImageSync(view.width.toInt(), view.height.toInt());
  }

  Future<ByteData> bytes(WidgetTester tester, ui.Image img) async => (await tester.runAsync(() => img.toByteData()))!;
  int px(ByteData b, int x, int y) {
    final i = (y * view.width.toInt() + x) * 4;
    return (b.getUint8(i + 3) << 24) | (b.getUint8(i) << 16) | (b.getUint8(i + 1) << 8) | b.getUint8(i + 2);
  }

  test('com o mapa parado todo bloco está no giro exato e nenhum pixel fica fora da grade; no arrasto, passos de 3 graus', () {
    nowUs = 0;
    final c = make();
    ground(c, camAt(0, 0, rot: 0.7)).dispose();
    expect(c.onGrid, isTrue);
    expect(c.targetAngle, 0.7);
    // Arrasto: o ângulo muda a cada quadro; os blocos ficam no passo mais perto, desenhados com o resto do giro.
    for (var i = 1; i <= 5; i++) {
      nowUs += 16000;
      ground(c, camAt(0, 0, rot: 0.7 + i * 0.013), touching: true).dispose();
      final step = angleStepDeg * math.pi / 180;
      expect((c.targetAngle / step - (c.targetAngle / step).round()).abs(), lessThan(1e-9));
      expect(c.onGrid, isFalse);
    }
    // Soltou o dedo: um quarto de segundo parado e o chão é refeito no ângulo exato.
    nowUs += 300000;
    ground(c, camAt(0, 0, rot: 0.7 + 5 * 0.013)).dispose();
    expect(c.targetAngle, 0.7 + 5 * 0.013);
    expect(c.onGrid, isTrue);
    c.dispose();
  });

  test('o cache só é refeito quando um bloco entra na tela, a luz muda de faixa, a chuva molha o asfalto ou o zoom assenta', () {
    nowUs = 0;
    final c = make();
    ground(c, camAt(0, 0)).dispose();
    expect(c.rebuiltLastFrame, greaterThan(0));
    nowUs += 300000;
    ground(c, camAt(0, 0)).dispose();
    expect(c.rebuiltLastFrame, 0, reason: 'nada mudou');
    ground(c, camAt(0.3, 0.2)).dispose();
    expect(c.rebuiltLastFrame, 0, reason: 'andar um pouco não refaz o que já está pronto');
    // Andando, a escala muda em frações ínfimas com a latitude: nada é refeito (no moto g54 isso refazia um bloco por quadro).
    for (var i = 1; i <= 5; i++) {
      nowUs += 16000;
      final cam = camAt(0.3, 0.2 + i * 0.001);
      ground(c, MapCamera(centerX: cam.centerX, centerY: cam.centerY, pixelsPerCell: cam.pixelsPerCell * (1 + i * 1e-6))).dispose();
      expect(c.rebuiltLastFrame, 0, reason: 'passo $i');
    }
    ground(c, camAt(0.3, 0.2), alt: 39.9).dispose();
    expect(c.rebuiltLastFrame, 0, reason: 'a mesma faixa de luz');
    ground(c, camAt(0.3, 0.2), alt: 47).dispose();
    expect(c.rebuiltLastFrame, greaterThan(0), reason: 'a luz mudou de faixa');
    ground(c, camAt(0.3, 0.2), alt: 47, wet: true).dispose();
    expect(c.rebuiltLastFrame, greaterThan(0), reason: 'a chuva molhou o asfalto');
    nowUs += 300000;
    ground(c, camAt(0.3, 0.2, widthM: 60), alt: 47, wet: true, touching: true).dispose();
    expect(c.rebuiltLastFrame, 0, reason: 'na pinça vale a imagem pronta, esticada');
    nowUs += 300000;
    ground(c, camAt(0.3, 0.2, widthM: 60), alt: 47, wet: true).dispose();
    expect(c.rebuiltLastFrame, greaterThan(0), reason: 'o zoom assentou');
    final before = c.rebuiltTotal;
    ground(c, camAt(120, 0, widthM: 60), alt: 47, wet: true).dispose();
    expect(c.rebuiltTotal, greaterThan(before), reason: 'blocos novos entraram na tela');
    c.dispose();
  });

  testWidgets('a rua desenhada fica onde a câmera do jogo (toque, Aura, spawns) diz que ela está, com o mapa girado', (tester) async {
    final road = block.roads.firstWhere((r) => r.cls == 'local' && r.pts.length >= 2);
    final a = road.pts[0], b = road.pts[1];
    final mid = ((a.$1 + b.$1) / 2, (a.$2 + b.$2) / 2);
    for (final rot in [0.0, 1.1]) {
      nowUs += 1000000;
      final c = make();
      final cam = camAt(mid.$1 + 8, mid.$2 - 5, rot: rot);
      final img = ground(c, cam);
      final data = await bytes(tester, img);
      final (cx, cy) = tiles.toCells(mid.$1, mid.$2);
      final (sx, sy) = cam.cellToScreen(cx, cy, view.width, view.height);
      final argb = px(data, sx.round(), sy.round());
      final luma = (((argb >> 16) & 0xff) * 299 + ((argb >> 8) & 0xff) * 587 + (argb & 0xff) * 114) ~/ 1000;
      expect(luma, lessThan(95), reason: 'asfalto no centro da rua (giro $rot): ${argb.toRadixString(16)}');
      img.dispose();
      c.dispose();
    }
  });

  testWidgets('o chão cobre a tela inteira, sem emenda entre os blocos, parado e girado', (tester) async {
    for (final rot in [0.0, 0.37]) {
      nowUs += 1000000;
      final c = make();
      final img = ground(c, camAt(10, 4, rot: rot));
      final data = await bytes(tester, img);
      var holes = 0;
      for (var y = 0; y < view.height.toInt(); y++) {
        for (var x = 0; x < view.width.toInt(); x++) {
          if ((px(data, x, y) >>> 24) != 0xff) holes++;
        }
      }
      expect(holes, 0, reason: 'giro $rot');
      img.dispose();
      c.dispose();
    }
  });

  testWidgets('0.22.2: os blocos em volta da tela são montados fora do quadro; ao andar até eles, nada é refeito no quadro', (tester) async {
    nowUs += 1000000;
    final c = make(prefetch: true);
    ground(c, camAt(0, 0)).dispose();
    for (var i = 0; i < 400 && !c.prefetchDone; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      ground(c, camAt(0, 0)).dispose();
    }
    expect(c.prefetchedTotal, greaterThanOrEqualTo(6));
    // Andar um bloco (4 células, uns 70 m) para o leste: o bloco novo já estava pronto.
    ground(c, camAt(4 * tiles.mpc, 0)).dispose();
    expect(c.rebuiltLastFrame, 0, reason: 'o bloco que entrou na tela veio do segundo plano');
    c.dispose();
  });

  CityTile oneHouse(double cx, double cy, {double half = 0.4}) => CityTile(
        roads: const [],
        greens: const [],
        waters: const [],
        buildings: [CityBuilding(Float64List.fromList([cx - half, cy - half, cx + half, cy - half, cx + half, cy + half, cx - half, cy + half]), buildingLook(type: 'apartments', shop: false, areaM2: 200, levels: 6, gridBiome: 'urban'), 7, levels: 6)],
        props: [CityProp('tree_b', cx + 2, cy + 2)],
      );

  test('o telhado sobre o avatar ou um Eco fica translúcido; sem nada embaixo, opaco', () {
    final (x, y) = tiles.toCells(0, 0);
    final c = make(tileAt: (tx, ty) => tx == 0 && ty == 0 ? oneHouse(x, y) : CityTile.empty);
    final cam = camAt(0, 0);
    upright(c, cam, items: [view.center(ui.Offset.zero)]).dispose();
    expect(c.upright.translucentOf, hasLength(1));
    upright(c, cam).dispose();
    expect(c.upright.translucentOf, isEmpty);
    // Um Eco embaixo da copa da árvore também a deixa translúcida.
    final (tx, ty) = cam.cellToScreen(x + 2, y + 2, view.width, view.height);
    upright(c, cam, items: [ui.Offset(tx, ty)]).dispose();
    expect(c.upright.stats.props, 1);
  });

  testWidgets('a neve acumula no telhado deslocado, que sai do centro da tela para fora', (tester) async {
    final (x, y) = tiles.toCells(0, 0);
    final c = make(tileAt: (tx, ty) => tx == 0 && ty == 0 ? oneHouse(x + 0.6, y - 1.4) : CityTile.empty);
    final cam = camAt(0, 0);
    final snowImg = upright(c, cam, snow: true);
    final b = c.upright.roofs.keys.single;
    final roof = c.upright.roofs[b]!.getBounds();
    final (bx, by) = cam.cellToScreen(b.centroid.$1, b.centroid.$2, view.width, view.height);
    final k = CityRenderer.pixelSize(3, 1).toDouble();
    expect(roof.center.dx * k, greaterThan(bx), reason: 'o telhado sai para a direita (prédio à direita do centro)');
    expect(roof.center.dy * k, lessThan(by), reason: 'e para cima (prédio acima do centro)');
    final plain = upright(c, cam);
    final s = await bytes(tester, snowImg), p = await bytes(tester, plain);
    // Onde a neve muda o telhado, o pixel fica claro (a neve debaixo do tom da hora).
    var changed = 0, bright = 0;
    for (var yy = math.max(0, (roof.top * k).floor()); yy < math.min(view.height, roof.bottom * k).ceil(); yy++) {
      for (var xx = math.max(0, (roof.left * k).floor()); xx < math.min(view.width, roof.right * k).ceil(); xx++) {
        final a = px(s, xx, yy), q = px(p, xx, yy);
        if (a == q) continue;
        changed++;
        final luma = (((a >> 16) & 0xff) * 299 + ((a >> 8) & 0xff) * 587 + (a & 0xff) * 114) ~/ 1000;
        if (luma > 170) bright++;
      }
    }
    expect(changed, greaterThan(0));
    expect(bright / changed, greaterThan(0.8));
  });

  // O teste da árvore de pé em dois giros virou test/ui/upright_turn_test.dart (0.23.1): todo sprite de pé, nas duas artes.

  test('zoom aberto: sem janelas e sem props de telhado; zoom fechado: com janelas', () {
    final c = make();
    upright(c, camAt(0, 0, widthM: 80)).dispose();
    expect(c.upright.stats.buildings, greaterThan(0));
    expect((c.upright.stats.windows, c.upright.stats.roofProps), (0, 0));
    upright(c, camAt(0, 0, widthM: 40)).dispose();
    expect(c.upright.stats.windows, greaterThan(0));
  });

  test('ipê floresce na época real: roxo em junho e julho, amarelo em agosto e setembro, verde no resto', () {
    expect(ipeStamp('purple', 6), 'ipe_purple');
    expect(ipeStamp('yellow', 9), 'ipe_yellow');
    expect(ipeStamp('purple', 11), 'ipe_green');
    expect(ipeStamp('yellow', 11), 'ipe_green');
  });

  test('o orçamento de partículas é um só: clima e dois eventos dividem o teto, que nenhuma pilha passa', () {
    final catalog = ClimateCatalog.fromJson(loadJson('assets/data/clima.json'), loadJson('assets/data/eventos.json'));
    final stacks = <String>[];
    for (final c in ['storm', 'blizzard', 'rain', 'snow']) {
      for (final e1 in catalog.eventInfos.keys) {
        for (final e2 in catalog.eventInfos.keys) {
          if (e1.compareTo(e2) < 0) stacks.add('$c+$e1+$e2');
        }
      }
    }
    var shared = 0;
    for (final id in stacks) {
      final p = ClimatePainter(cap: 120);
      final info = catalog.of(id);
      for (var i = 0; i < 90; i++) {
        p.update(1 / 30, const ui.Size(400, 800), info);
      }
      expect(p.count, lessThanOrEqualTo(120), reason: id);
      final counts = p.layerCounts;
      if (counts.length >= 2 && counts.every((n) => n > 0)) shared++;
    }
    expect(shared, greaterThan(0), reason: 'quando duas camadas pedem partículas, as duas recebem');
  });
}
