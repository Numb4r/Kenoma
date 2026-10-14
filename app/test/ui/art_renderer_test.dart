import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/ui/game/art_renderer.dart';
import 'package:kenoma/ui/game/art_style.dart';
import 'package:kenoma/world/map_balance.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/visual_map.dart';

import '../data/visual_pack_test.dart' show syntheticPack;
import '../support/fixtures.dart';

const size = ui.Size(200, 200);
const lat = -22.9;

void main() {
  final balance = MapBalance(loadJson('assets/data/balance.json'));
  final style = ArtStyle(loadBiomes());
  final mpc = metersPerCell(lat);
  const artM = 0.75; // 90 m em 120 pixels de arte
  final artCells = artM / mpc;

  ArtRenderer make() =>
      ArtRenderer(visual: VisualMap(VisualPack.parse(syntheticPack())), style: style, balance: balance, artCells: artCells, metersPerArtPx: artM);

  Future<List<int>> render(ArtRenderer r, MapCamera cam) async {
    final rec = ui.PictureRecorder();
    r.paint(ui.Canvas(rec), size, cam, maxBuilds: 100);
    final image = rec.endRecording().toImageSync(200, 200);
    return (await image.toByteData())!.buffer.asUint8List();
  }

  int colorAt(List<int> px, int x, int y) {
    final i = (y * 200 + x) * 4;
    return (px[i] << 16) | (px[i + 1] << 8) | px[i + 2];
  }

  // O tile (5, 7) do pacote sintético: rua principal de (0,0) a (4096,0) na borda de cima, e o lago em
  // x 100..900, y 100..900 (com uma ilha). 1 unidade = 1/4096 tile = ~0,25 m.
  MapCamera over(double ux, double uy, {double widthM = 90}) => MapCamera(
        centerX: (5 + ux / 4096) * 64,
        centerY: (7 + uy / 4096) * 64,
        pixelsPerCell: size.width * mpc / widthM,
      );

  testWidgets('a água cobre o lago e o buraco da ilha fica de fora', (tester) async {
    await tester.runAsync(() async {
      final r = make();
      // Lago: 800 unidades = ~200 m. Centro do lago é a ilha (triângulo 400..600), então olhe um canto.
      final px = await render(r, over(250, 250));
      final water = {style.water.dark, style.water.base, style.water.light}.map((c) => c.toARGB32() & 0xFFFFFF).toSet();
      expect(water.contains(colorAt(px, 100, 100)), isTrue, reason: 'no meio do lago, fora da ilha');
      r.dispose();
    });
  });

  testWidgets('o desenho é o mesmo de uma vez para outra: o ruído de cada chunk é fixo', (tester) async {
    await tester.runAsync(() async {
      final a = await render(make(), over(250, 250));
      final b = await render(make(), over(250, 250));
      expect(a, b);
    });
  });

  testWidgets('a rua tem asfalto no meio, calçada de 1 pixel de arte de cada lado e chão fora', (tester) async {
    await tester.runAsync(() async {
      final r = make();
      // A rua principal corre pela borda de cima do tile (y = 0); câmera sobre ela, no meio do tile.
      final px = await render(r, over(2048, 0));
      final asphalt = style.asphalt.toARGB32() & 0xFFFFFF;
      final sidewalk = style.sidewalk.toARGB32() & 0xFFFFFF;
      final ground = {style.ground.dark, style.ground.base, style.ground.light}.map((c) => c.toARGB32() & 0xFFFFFF).toSet();
      expect(colorAt(px, 100, 100), asphalt);
      // 12 m de rua = 16 pixels de arte (0,75 m); com 120 pixels de arte na largura, 1 pixel de arte = 1,67 px de tela.
      final halfRoad = 12 / 2 / artM * (200 / (90 / artM));
      expect(colorAt(px, 100, 100 + (halfRoad - 3).round()), asphalt, reason: 'ainda no asfalto');
      expect(colorAt(px, 100, 100 + (halfRoad + 1).round()), sidewalk, reason: 'na calçada');
      expect(ground.contains(colorAt(px, 100, 100 + (halfRoad + 8).round())), isTrue, reason: 'depois da calçada é chão');
      r.dispose();
    });
  });

  testWidgets('só os chunks visíveis são montados e voltam do cache', (tester) async {
    await tester.runAsync(() async {
      final r = make();
      await render(r, over(2048, 2048));
      final first = r.lastBuilds;
      expect(first, inInclusiveRange(1, 4), reason: '90 m de largura cabem em 1 a 4 chunks de ${chunkArtPx * artM} m');
      await render(r, over(2048, 2048));
      expect(r.lastBuilds, 0, reason: 'segunda vez sai tudo do cache');
      r.dispose();
    });
  });

  test('o chunk tem o tamanho fixo de $chunkArtPx pixels de arte, e o limite de montagem por quadro vale', () async {
    final r = make();
    final rec = ui.PictureRecorder();
    r.paint(ui.Canvas(rec), size, over(2048, 2048), maxBuilds: 1);
    expect(r.lastBuilds, 1);
    expect(r.chunkCells, closeTo(chunkArtPx * artCells, 1e-12));
    r.dispose();
  });
}
