import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/map/biome_textures.dart';
import 'package:kenoma/ui/map/map_renderer.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/region_map.dart';

import '../support/fixtures.dart';

/// Cores do preview do M1 (`PREVIEW_COLORS` em pipeline/build_region.py), por id de bioma.
const previewColors = {
  0: (40, 36, 48), // Vazio
  1: (150, 150, 160), // Urbano
  2: (70, 150, 80), // Verde
  3: (60, 110, 200), // Água
  4: (215, 190, 140), // Residencial
};

Future<({Uint8List rgba, int width, int height})> loadPreview() async {
  final bytes = File('test/fixtures/campinas_e0_preview.png').readAsBytesSync();
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  final data = (await image.toByteData())!.buffer.asUint8List();
  final out = (rgba: data, width: image.width, height: image.height);
  image.dispose();
  codec.dispose();
  return out;
}

/// O id de bioma de uma cor do preview. `-1` se a cor não é de nenhum bioma.
int biomeOfPreviewPixel(Uint8List rgba, int i) {
  for (final e in previewColors.entries) {
    if (rgba[i] == e.value.$1 && rgba[i + 1] == e.value.$2 && rgba[i + 2] == e.value.$3) return e.key;
  }
  return -1;
}

void main() {
  final pack = loadCampinasPack();

  testWidgets('os biomes lidos do .bin são exatamente os pixels do preview do M1, em todas as células', (tester) async {
    await tester.runAsync(() async {
      final preview = await loadPreview();
      expect((preview.width, preview.height), (pack.width, pack.height), reason: 'um pixel do preview por célula z21');
      var mismatches = 0, unknown = 0;
      int? firstBad;
      final counts = List.filled(5, 0);
      for (var j = 0; j < pack.height; j++) {
        for (var i = 0; i < pack.width; i++) {
          final id = biomeOfPreviewPixel(preview.rgba, (j * pack.width + i) * 4);
          if (id < 0) {
            unknown++;
            continue;
          }
          counts[id]++;
          if (id != pack.biomeAt(pack.x0 + i, pack.y0 + j)) {
            mismatches++;
            firstBad ??= j * pack.width + i;
          }
        }
      }
      expect(unknown, 0, reason: 'todo pixel do preview é a cor de um bioma');
      expect(mismatches, 0, reason: 'primeira diferença no pixel $firstBad');
      // Os mesmos números que o pipeline imprimiu (docs/marcos.md, M1): Vazio 53,7%, Urbano 7,1%,
      // Verde 30,6%, Água 1,6%, Residencial 6,9%.
      final total = pack.width * pack.height;
      for (final (id, pct) in [(0, 53.7), (1, 7.1), (2, 30.6), (3, 1.6), (4, 6.9)]) {
        expect(100 * counts[id] / total, closeTo(pct, 0.05), reason: 'bioma $id');
      }
    });
  });

  testWidgets('o mapa renderizado bate com o preview: cada pixel da tela tem a cor do bioma que o preview mostra ali', (tester) async {
    await tester.runAsync(() async {
      final preview = await loadPreview();
      final biomes = loadBiomes();
      final map = RegionMap(pack: pack, biomes: biomes);
      final renderer = MapRenderer(map: map, atlas: await buildBiomeAtlas(biomes));
      const view = ui.Size(540, 1200);
      var checked = 0, regions = 0;
      for (final (lat, lon, scale) in [
        (-22.8174, -47.0697, 2.0), // Unicamp, a ~270 x 600 células
        (-22.9056, -47.0608, 2.0), // centro de Campinas
        (-22.8174, -47.0697, 5.0),
        (-22.9056, -47.0608, 12.0),
      ]) {
        final cam = MapCamera.atLatLon(lat, lon, pixelsPerCell: scale);
        final rec = ui.PictureRecorder();
        renderer.paint(ui.Canvas(rec), view, camera: cam, maxBuilds: 100000);
        final image = rec.endRecording().toImageSync(view.width.toInt(), view.height.toInt());
        final px = (await image.toByteData())!.buffer.asUint8List();
        for (var y = 4; y < view.height.toInt() - 4; y += 9) {
          for (var x = 4; x < view.width.toInt() - 4; x += 6) {
            if ((x - 270).abs() < 12 && (y - 600).abs() < 12) continue; // a mira do centro
            final (fx, fy) = cam.screenToCell(x + 0.5, y + 0.5, view.width, view.height);
            // O cantinho de uma célula pode vir da vizinha (corte do chunk em pixel inteiro): vale a 3 x 3.
            final allowed = <int>{};
            for (var dy = -1; dy <= 1; dy++) {
              for (var dx = -1; dx <= 1; dx++) {
                final col = fx.floor() + dx - pack.x0, row = fy.floor() + dy - pack.y0;
                final id = (col < 0 || row < 0 || col >= pack.width || row >= pack.height)
                    ? 0
                    : biomeOfPreviewPixel(preview.rgba, (row * pack.width + col) * 4);
                allowed.addAll(biomes.byId(id).palette);
              }
            }
            final i = (y * view.width.toInt() + x) * 4;
            final c = (px[i] << 16) | (px[i + 1] << 8) | px[i + 2];
            expect(allowed.contains(c), isTrue, reason: '($lat,$lon) x$scale pixel ($x,$y): #${c.toRadixString(16)}');
            checked++;
          }
        }
        image.dispose();
        regions++;
      }
      expect(regions, 4);
      expect(checked, greaterThan(8000));
      renderer.dispose();
    });
  });
}
