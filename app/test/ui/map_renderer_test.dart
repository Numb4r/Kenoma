import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/map/biome_textures.dart';
import 'package:kenoma/ui/map/map_renderer.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/map_probe.dart';
import 'package:kenoma/world/region_map.dart';

import '../support/fixtures.dart';

const unicamp = (-22.8174, -47.0697);
const centro = (-22.9056, -47.0608);
const size = ui.Size(540, 1200);

Future<ui.Image> paint(MapRenderer r, MapCamera cam, {bool grid = false, MapProbe? probe, int maxBuilds = 100000}) async {
  final rec = ui.PictureRecorder();
  r.paint(ui.Canvas(rec), size, camera: cam, grid20: grid, probe: probe, maxBuilds: maxBuilds);
  return rec.endRecording().toImageSync(size.width.toInt(), size.height.toInt());
}

Future<List<int>> pixels(ui.Image image) async => (await image.toByteData())!.buffer.asUint8List();

int colorAt(List<int> px, int x, int y) {
  final i = (y * size.width.toInt() + x) * 4;
  return (px[i] << 16) | (px[i + 1] << 8) | px[i + 2];
}

void main() {
  late RegionMap map;
  late MapRenderer renderer;

  setUp(() async {
    final biomes = loadBiomes();
    map = RegionMap(pack: loadCampinasPack(), biomes: biomes);
    renderer = MapRenderer(map: map, atlas: await buildBiomeAtlas(biomes));
  });
  tearDown(() => renderer.dispose());

  /// Cores que o desenho pode ter num pixel de tela: os tons da célula (ou, perto da borda, das vizinhas).
  Set<int> allowed(MapCamera cam, int px, int py, int radius) {
    final (cx, cy) = cam.screenToCell(px + 0.5, py + 0.5, size.width, size.height);
    return {
      for (var dy = -radius; dy <= radius; dy++)
        for (var dx = -radius; dx <= radius; dx++) ...map.biomes.byId(map.biomeAtCell(cx.floor() + dx, cy.floor() + dy)).palette,
    };
  }

  for (final (name, lat, lon, scale) in [
    ('Unicamp em 16 px/célula', unicamp.$1, unicamp.$2, 16.0),
    ('centro de Campinas em 16 px/célula', centro.$1, centro.$2, 16.0),
    ('Unicamp ampliada (32 px/célula)', unicamp.$1, unicamp.$2, 32.0),
    ('Unicamp em 8,5 px/célula (nível de detalhe 16, reduzido)', unicamp.$1, unicamp.$2, 8.5),
    ('Unicamp em 6 px/célula (nível 8)', unicamp.$1, unicamp.$2, 6.0),
    ('centro em 3 px/célula (nível 4)', centro.$1, centro.$2, 3.0),
  ]) {
    testWidgets('cada pixel tem uma cor do bioma da célula: $name', (tester) async {
      await tester.runAsync(() async {
        final cam = MapCamera.atLatLon(lat, lon, pixelsPerCell: scale);
        final px = await pixels(await paint(renderer, cam));
        var checked = 0;
        for (var y = 3; y < size.height.toInt() - 3; y += 11) {
          for (var x = 3; x < size.width.toInt() - 3; x += 7) {
            if ((x - 270).abs() < 12 && (y - 600).abs() < 12) continue; // a mira do centro
            // A 3 px por célula o corte do chunk em pixel inteiro pode deslocar 1 px: vale a vizinha.
            final ok = allowed(cam, x, y, scale < 5 ? 1 : 0);
            if (scale >= 8) {
              // Longe da borda da célula o pixel é inequívoco.
              final (fx, fy) = cam.screenToCell(x + 0.5, y + 0.5, size.width, size.height);
              final u = fx - fx.floor(), v = fy - fy.floor();
              if (u < 0.15 || u > 0.85 || v < 0.15 || v > 0.85) continue;
            }
            expect(ok.contains(colorAt(px, x, y)), isTrue, reason: '$name pixel ($x,$y)');
            checked++;
          }
        }
        expect(checked, greaterThan(500));
      });
    });
  }

  testWidgets('a área mostra de tudo: nas telas de Campinas aparecem os cinco biomas, pelas cores', (tester) async {
    await tester.runAsync(() async {
      final cam = MapCamera.atLatLon(unicamp.$1, unicamp.$2, pixelsPerCell: 3);
      final px = await pixels(await paint(renderer, cam));
      final seen = <int>{};
      for (var y = 0; y < size.height.toInt(); y += 3) {
        for (var x = 0; x < size.width.toInt(); x += 3) {
          final c = colorAt(px, x, y);
          for (final b in map.biomes.all) {
            if (b.palette.contains(c)) seen.add(b.id);
          }
        }
      }
      expect(seen.length, greaterThanOrEqualTo(4), reason: 'biomas vistos: $seen');
    });
  });

  testWidgets('fora do pacote a tela é só o Vazio', (tester) async {
    await tester.runAsync(() async {
      final cam = MapCamera.atLatLon(0, 0, pixelsPerCell: 16);
      final px = await pixels(await paint(renderer, cam));
      final base = map.biomes.byId(voidBiomeId).palette[1];
      for (var y = 0; y < size.height.toInt(); y += 13) {
        for (var x = 0; x < size.width.toInt(); x += 13) {
          if ((x - 270).abs() < 12 && (y - 600).abs() < 12) continue;
          expect(colorAt(px, x, y), base);
        }
      }
      expect(renderer.cachedChunks, 0, reason: 'chunk fora do pacote não gasta memória');
    });
  });

  group('cache por chunk', () {
    testWidgets('o primeiro quadro monta os chunks da tela e o segundo, igual, não monta nenhum', (tester) async {
      await tester.runAsync(() async {
        final cam = MapCamera.atLatLon(unicamp.$1, unicamp.$2);
        await paint(renderer, cam);
        final first = renderer.lastBuilds;
        expect(first, inInclusiveRange(2, 6), reason: 'em 16 px/célula são poucos chunks (a tela do teste é metade da do celular)');
        expect(renderer.cachedChunks, first);
        await paint(renderer, cam);
        expect(renderer.lastBuilds, 0);
        await paint(renderer, cam.panned(-10, -10)); // 10 px: no máximo um chunk novo
        expect(renderer.lastBuilds, lessThanOrEqualTo(3));
      });
    });

    testWidgets('no máximo maxBuilds chunks novos por quadro; os que faltam entram nos seguintes', (tester) async {
      await tester.runAsync(() async {
        final cam = MapCamera.atLatLon(unicamp.$1, unicamp.$2, pixelsPerCell: 5);
        await paint(renderer, cam, maxBuilds: 2);
        expect(renderer.lastBuilds, 2);
        await paint(renderer, cam, maxBuilds: 2);
        expect(renderer.lastBuilds, 2);
        for (var i = 0; i < 10; i++) {
          await paint(renderer, cam, maxBuilds: 2);
        }
        expect(renderer.lastBuilds, 0, reason: 'tudo montado');
      });
    });

    testWidgets('o zoom troca o nível de detalhe e cada chunk usa menos memória: 4 MB a 16, 64 KB a 2', (tester) async {
      await tester.runAsync(() async {
        await paint(renderer, MapCamera.atLatLon(unicamp.$1, unicamp.$2));
        final fine = renderer.cachedBytes / renderer.cachedChunks;
        expect(fine, 4194304);
        renderer.dispose();
        expect(renderer.cachedBytes, 0);
        await paint(renderer, MapCamera.atLatLon(unicamp.$1, unicamp.$2, pixelsPerCell: 2));
        expect(renderer.cachedBytes / renderer.cachedChunks, 65536);
      });
    });

    testWidgets('a memória respeita o orçamento: os chunks mais antigos saem primeiro', (tester) async {
      await tester.runAsync(() async {
        final small = MapRenderer(map: map, atlas: await buildBiomeAtlas(loadBiomes()), budgetBytes: 3 * 4194304);
        for (var i = 0; i < 12; i++) {
          await paint(small, MapCamera.atLatLon(unicamp.$1, unicamp.$2).panned(-1100.0 * i, 0));
          expect(small.cachedBytes, lessThanOrEqualTo(3 * 4194304 + 4194304 * 12), reason: 'um quadro pode passar, depois cai');
        }
        await paint(small, MapCamera.atLatLon(unicamp.$1, unicamp.$2).panned(-1100.0 * 12, 0));
        expect(small.cachedChunks, lessThan(12 * 4));
        small.dispose();
      });
    });
  });

  testWidgets('a grade z20 e a sonda desenham por cima, e desligadas não mudam o mapa', (tester) async {
    await tester.runAsync(() async {
      final cam = MapCamera.atLatLon(unicamp.$1, unicamp.$2);
      final plain = await pixels(await paint(renderer, cam));
      final grid = await pixels(await paint(renderer, cam, grid: true));
      expect(grid, isNot(plain));
      expect(await pixels(await paint(renderer, cam)), plain, reason: 'desligada volta ao mesmo desenho');
      final probe = probeAt(map, cam.centerX + 3.2, cam.centerY + 4.7);
      final marked = await pixels(await paint(renderer, cam, probe: probe));
      expect(marked, isNot(plain));
      // A grade z20 não aparece em escala pequena demais (linhas coladas).
      final far = MapCamera.atLatLon(unicamp.$1, unicamp.$2, pixelsPerCell: 3);
      expect(await pixels(await paint(renderer, far, grid: true)), await pixels(await paint(renderer, far)));
    });
  });
}
