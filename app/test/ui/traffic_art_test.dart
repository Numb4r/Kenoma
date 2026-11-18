import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/ui/game/ghost_sprites.dart';
import 'package:kenoma/ui/game/traffic_art.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/ui/game/traffic_painter.dart';
import 'package:kenoma/world/veil_traffic.dart';
import 'package:kenoma/world/visual_map.dart';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(Uint8List.fromList(await File(key).readAsBytes()));
}

/// 0.25.1: o tráfego e as Fagulhas saíram do desenho em código para o Aseprite, na grade de 2 dp, com as cores trocadas
/// pela paleta de cada fantasma e as roupas do clima como camadas.
void main() {
  testWidgets('todo modelo tem sprite, os de pé têm as nove roupas, e as medidas de referência são as de 2 dp', (tester) async {
    await tester.runAsync(() => TrafficArt.load(_DiskBundle()));
    final art = TrafficArt.current!;
    expect((art.carRefPx, art.pedRefPx), (24, 20), reason: '1,5 × as matrizes de 3 dp (16 e 13)');
    for (final m in GhostModel.values) {
      final s = art.sprites[artNameOf(m)];
      expect(s, isNotNull, reason: m.name);
      expect(s!.body.frames, framesOf(m), reason: m.name);
      if (isUpright(m)) {
        for (final o in GhostOutfit.values.where((o) => o != GhostOutfit.none)) {
          final piece = art.outfits['${artNameOf(m)}_${o.name}'];
          expect(piece, isNotNull, reason: '${m.name} ${o.name}');
          expect((piece!.width, piece.height), (s.body.width, s.body.height), reason: '${m.name} ${o.name}: a peça no quadro do corpo');
        }
      }
    }
    expect(art.sprites['bus_city']?.glow, isNotNull, reason: 'o ônibus acende as janelas de noite');
  });

  testWidgets('as cores-chave viram a cor da paleta do fantasma, e os derivados saem dela', (tester) async {
    await tester.runAsync(() => TrafficArt.load(_DiskBundle()));
    final art = TrafficArt.current!;
    const red = ui.Color(0xFFCC2233);
    final map = art.remap(const ['vehicle'], {'body': red});
    expect(map[0xB8BCC8], red, reason: 'o corpo');
    expect(map[0x8E92A4], isNot(red), reason: 'o teto é o corpo sombreado');
    expect(map[0x8E92A4], isNotNull);
    expect(map.containsKey(0xBFE9F0), isFalse, reason: 'o vidro é fixo');
    // Duas paletas do mesmo carro dão corpos diferentes.
    final a = artRolesOf(GhostModel.sedan, 0)['body'], b = artRolesOf(GhostModel.sedan, 1)['body'];
    expect(a, isNot(b));
    final ped = art.remap(const ['pedestrian', 'outfit'], artRolesOf(GhostModel.adult, 2));
    expect(ped[0x8A3B6B], artRolesOf(GhostModel.adult, 2)['umbrella'], reason: 'o guarda-chuva na cor da paleta');
  });

  testWidgets('uma Fagulha por tipo, em laço, no quadro de 12', (tester) async {
    await tester.runAsync(() => SparkArt.load(_DiskBundle()));
    final art = SparkArt.current!;
    expect(art.frame, 12);
    expect(art.strips.keys.toSet(), {for (final t in EcoType.values) t.name});
    for (final e in art.strips.entries) {
      expect((e.value.$1.width, e.value.$1.height), (12 * art.frames, 12), reason: e.key);
    }
  });

  testWidgets('com a arte carregada, cada fantasma desenha na tela, de pé pelos pés e de cima pelo centro', (tester) async {
    await tester.runAsync(() => TrafficArt.load(_DiskBundle()));
    final painter = TrafficPainter(VisualMap(VisualPack.parse(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync()), cacheTiles: 4), carM: 6, pedestrianM: 4.5);
    for (final m in GhostModel.values) {
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      painter.drawGhost(c, Ghost(id: 7, model: m, palette: 1, x: 0, y: 0, heading: 0, speedMps: 3, phase: GhostPhase.alive, phaseT: 0, travelledM: 0), 100, 100, 0, 8, 0, outfit: 'rain');
      final img = (await tester.runAsync(() => rec.endRecording().toImage(200, 200)))!;
      final px = (await tester.runAsync(() => img.toByteData()))!.buffer.asUint8List();
      var n = 0, minY = 200, maxY = 0;
      for (var i = 0; i < px.length; i += 4) {
        if (px[i + 3] > 0) {
          n++;
          final y = (i ~/ 4) ~/ 200;
          minY = y < minY ? y : minY;
          maxY = y > maxY ? y : maxY;
        }
      }
      expect(n, greaterThan(100), reason: '${m.name}: desenhou $n pixels');
      if (isUpright(m)) expect(maxY, inInclusiveRange(98, 101), reason: '${m.name}: os pés na posição');
    }
  });
}
