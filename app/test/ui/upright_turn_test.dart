import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/city/city_renderer.dart';
import 'package:kenoma/ui/city/turn_category.dart';
import 'package:kenoma/ui/lab/lab_art.dart';
import 'package:kenoma/ui/sprites/map_style.dart';
import 'package:kenoma/world/city_scene.dart';
import 'package:kenoma/world/map_camera.dart';

/// 0.23.1: o que fica de pé não gira. O mesmo trecho desenhado a 0° e a 90° tem os pixels de cada sprite de pé idênticos, só
/// em outra posição: árvores, ipês, poste, ponto de ônibus, banca, caixa d'água, ar-condicionado, antena e letreiros, com a
/// arte em código e com a do Aseprite. Todo carimbo novo entra em `uprightStampKinds` ou `groundStampKinds`, e todo carimbo de
/// pé tem de aparecer aqui.
void main() {
  const view = ui.Size(360, 780);
  const mpc = 17.6;
  const k = 3; // dpr 1, pixel de arte de 3 dp

  // Um prédio quadrado de 12 m a cada 4 células (uns 70 m), cada um com outro hash; os props entre eles.
  final buildings = <CityBuilding>[];
  final props = <CityProp>[];
  final anchors = <(double, double)>[];
  CityBuilding square(double cx, double cy, int hash, String type, String biome) {
    const half = 6 / mpc;
    final xy = Float64List.fromList([cx - half, cy - half, cx + half, cy - half, cx + half, cy + half, cx - half, cy + half]);
    return CityBuilding(xy, buildingLook(type: type, shop: biome == 'lit', areaM2: 144, levels: 3, gridBiome: biome), hash, levels: 3);
  }

  var n = 0;
  (double, double) next() {
    final p = (2.0 + (n % 8) * 4, 2.0 + (n ~/ 8) * 4);
    n++;
    anchors.add(p);
    return p;
  }

  for (var h = 0; h < 16; h++) {
    final (x, y) = next();
    buildings.add(square(x, y, h, h < 8 ? 'apartments' : 'commercial', h < 8 ? 'urban' : 'lit'));
  }
  for (final kind in ['tree', 'tree_a', 'tree_b', 'tree_c', 'ipe_purple', 'ipe_yellow', 'lamp', 'bus_stop', 'newsstand']) {
    final (x, y) = next();
    props.add(CityProp(kind, x, y, hash: n));
  }
  final tile = CityTile(roads: const [], greens: const [], waters: const [], buildings: buildings, props: props);
  CityTile tileAt(int tx, int ty) => tx == 0 && ty == 0 ? tile : CityTile.empty;

  Future<Map<String, ui.Image>> aseprite(WidgetTester tester) async => (await tester.runAsync(() => loadAsepriteArt((p) async {
            final f = File(p);
            return f.existsSync() ? f.readAsBytesSync() : null;
          })))!;

  Future<ByteData> bytesOf(WidgetTester tester, ui.Image img) async => (await tester.runAsync(() => img.toByteData()))!;

  /// Desenha o trecho com a câmera em [at] e o giro [rot]; devolve a imagem e o que o painel registrou.
  (ui.Image, List<({String name, ui.Rect rect, (double, double) anchor})>) render(CityRenderer c, (double, double) at, double rot, int month) {
    final cam = MapCamera(centerX: at.$1, centerY: at.$2, pixelsPerCell: view.width / (50 / mpc), rotation: rot);
    final rec = ui.PictureRecorder();
    c.paintUpright(ui.Canvas(rec), view, cam, dpr: 1, artPixelDp: k.toDouble(), mpc: mpc, sunAltDeg: 40, sunAzDeg: 80, localHour: 10, month: month, snowRoofs: false, items: const []);
    final img = rec.endRecording().toImageSync(view.width.toInt(), view.height.toInt());
    return (img, [...c.upright.drawn]);
  }

  test('todo carimbo é de pé ou de chão, e nenhum é os dois', () {
    final ase = Directory('assets/art/map').listSync().map((f) => f.uri.pathSegments.last).where((n) => n.endsWith('.png')).map((n) => n.replaceAll('.png', ''));
    final all = {...mapStamps.keys, ...ase};
    expect(all.difference({...uprightStampKinds, ...groundStampKinds}), isEmpty, reason: 'classifique o carimbo novo em turn_category.dart');
    expect(uprightStampKinds.intersection(groundStampKinds), isEmpty);
  });

  for (final useAse in [false, true]) {
    testWidgets('${useAse ? 'arte do Aseprite' : 'arte em código'}: cada sprite de pé sai com os mesmos pixels a 0° e a 90°', (tester) async {
      final art = LabArt.build(overrides: useAse ? await aseprite(tester) : const {});
      addTearDown(art.dispose);
      final seen = <String>{};
      for (final month in [7, 9]) {
        // Ipê roxo floresce em julho, o amarelo em setembro; fora disso são verdes.
        final c = CityRenderer(art: art, tileAt: tileAt, biomeAt: (_, _) => 'urban', cellsPerTile: 64, budgetMs: 1000);
        for (final at in anchors) {
          final (img0, d0) = render(c, at, 0, month);
          final (img90, d90) = render(c, at, math.pi / 2, month);
          final b0 = await bytesOf(tester, img0), b90 = await bytesOf(tester, img90);
          int px(ByteData b, int x, int y) => b.getUint32((y * view.width.toInt() + x) * 4);
          bool clean(List<({String name, ui.Rect rect, (double, double) anchor})> d, int i) =>
              d[i].rect.left >= 0 && d[i].rect.top >= 0 && d[i].rect.right * k <= view.width && d[i].rect.bottom * k <= view.height &&
              !d.skip(i + 1).any((o) => o.rect.overlaps(d[i].rect));
          for (var i = 0; i < d0.length; i++) {
            final s = d0[i];
            if (s.name == 'building' || !clean(d0, i)) continue;
            final j = d90.indexWhere((o) => o.name == s.name && o.anchor == s.anchor);
            expect(j, isNot(-1), reason: '${s.name} some ao girar');
            if (!clean(d90, j)) continue;
            final stamp = art.stamp(s.name)!;
            final sb = await bytesOf(tester, stamp);
            var opaque = 0;
            for (var y = 0; y < stamp.height; y++) {
              for (var x = 0; x < stamp.width; x++) {
                if (sb.getUint8((y * stamp.width + x) * 4 + 3) != 255) continue;
                opaque++;
                final a = px(b0, ((s.rect.left + x) * k + 1).toInt(), ((s.rect.top + y) * k + 1).toInt());
                final b = px(b90, ((d90[j].rect.left + x) * k + 1).toInt(), ((d90[j].rect.top + y) * k + 1).toInt());
                expect(b, a, reason: '${s.name}: o pixel ($x, $y) mudou com o giro');
              }
            }
            expect(opaque, greaterThan(0));
            expect(d90[j].rect.size, s.rect.size, reason: '${s.name} mudou de tamanho');
            if (s.name.startsWith('roof_')) {
              // Só a posição muda, e junto com o telhado: com a câmera no centro do prédio, o deslocamento do prop até o centro
              // da tela gira 90° com o mapa (antes ficava parado na tela e o prop corria em volta do telhado).
              final mid = ui.Offset(view.width / k / 2, view.height / k / 2);
              final o0 = s.rect.center - mid, o90 = d90[j].rect.center - mid;
              if (o0.distance > 3) {
                expect(o90.distance, closeTo(o0.distance, 1.5), reason: '${s.name}: a distância ao centro mudou');
                expect((o0.dx * o90.dx + o0.dy * o90.dy).abs() / (o0.distance * o90.distance), lessThan(0.2), reason: '${s.name} não girou com o telhado');
              }
            }
            seen.add(s.name);
          }
          img0.dispose();
          img90.dispose();
        }
      }
      expect(seen, containsAll(uprightStampKinds), reason: 'todo sprite de pé foi desenhado e conferido');
    });
  }
}
