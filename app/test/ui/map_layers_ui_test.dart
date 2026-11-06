import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/net/feed_config.dart';
import 'package:kenoma/ui/game/art_renderer.dart';
import 'package:kenoma/ui/game/art_style.dart';
import 'package:kenoma/ui/game/veil_badge.dart';
import 'package:kenoma/world/layered_world.dart';
import 'package:kenoma/world/map_balance.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/map_layers.dart';
import 'package:kenoma/world/visual_map.dart';

import '../data/visual_pack_test.dart' show syntheticPack;
import '../support/fake_position_source.dart';
import '../support/fixtures.dart';

void main() {
  test('o Familiar comenta o piso: a fala existe e pede o evento certo', () {
    final script = loadGameData().mentor;
    final line = script.familiar.singleWhere((m) => m.id == 'floor_f01');
    expect(line.requires?.event, kFloorSeenEvent);
    expect(line.text, contains('fino demais para ler as ruas'));
  });

  testWidgets('selo Véu instável: só em bloco overpass, e o toque explica', (tester) async {
    final source = ValueNotifier(MapSourceKind.pack);
    var explained = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: VeilBadge(source: source, onExplain: () => explained++))));
    expect(find.text('VÉU INSTÁVEL'), findsNothing);
    source.value = MapSourceKind.floor;
    await tester.pump();
    expect(find.text('VÉU INSTÁVEL'), findsNothing);
    source.value = MapSourceKind.overpass;
    await tester.pump();
    expect(find.text('VÉU INSTÁVEL'), findsOneWidget);
    await tester.tap(find.text('VÉU INSTÁVEL'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(explained, 1);
  });

  testWidgets('piso sem dados: chão liso com a grade fraca, só nos tiles sem dado', (tester) async {
    await tester.runAsync(() async {
      final balance = MapBalance(loadJson('assets/data/balance.json'));
      final style = ArtStyle(loadBiomes());
      final visual = VisualMap(VisualPack.parse(syntheticPack()));
      const view = ui.Size(200, 200);
      Future<Uint8List> render(bool floor) async {
        final art = ArtRenderer(visual: visual, style: style, balance: balance, floorTile: (_, _) => floor, floorGridCells: 2);
        final rec = ui.PictureRecorder();
        // Longe do tile sintético (5, 7): só chão. Zoom bastante para a grade de 2 células aparecer.
        art.paint(ui.Canvas(rec), view, const MapCamera(centerX: 64 * 900 + 7.3, centerY: 64 * 900 + 7.3, pixelsPerCell: 40), dpr: 1, metersPerCell: metersPerCell(-22.9));
        final image = rec.endRecording().toImageSync(200, 200);
        final px = (await image.toByteData())!.buffer.asUint8List();
        art.dispose();
        return px;
      }

      final plain = await render(false), grid = await render(true);
      var diff = 0;
      for (var i = 0; i < plain.length; i += 4) {
        if (plain[i] != grid[i] || plain[i + 1] != grid[i + 1] || plain[i + 2] != grid[i + 2]) diff++;
      }
      expect(diff, greaterThan(100), reason: 'a grade aparece');
      expect(diff, lessThan(plain.length ~/ 4 ~/ 2), reason: 'é fraca e fina: não cobre o chão');
    });
  });

  test('URL de debug: entra com barra no fim e volta ao publicado', () {
    final t = DevTools(realSource: FakeGps());
    expect(t.feedBaseUrl, kFeedBaseUrl);
    t.setFeedBaseUrl(' http://localhost:8000 ');
    expect(t.feedBaseUrl, 'http://localhost:8000/');
    expect(t.anyForcing, isTrue);
    t.setFeedBaseUrl(null);
    expect(t.feedBaseUrl, kFeedBaseUrl);
    expect(t.anyForcing, isFalse);
  });
}
