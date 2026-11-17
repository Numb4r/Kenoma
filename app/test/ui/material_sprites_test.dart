import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/game/spawn_painter.dart';
import 'package:kenoma/ui/sprites/material_sprites.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/spawn_field.dart';

/// 0.23.1: os materiais no mapa têm sprite (antes eram caixinhas cinza e brancas) e ficam de pé: o mesmo sprite, pixel a pixel,
/// com o mapa a 0° e a 90°.
void main() {
  test('todo material que as épocas sorteiam tem sprite, com a legenda e as cores completas', () {
    final epochs = File('assets/data/epochs.json').readAsStringSync();
    final ids = {for (final m in RegExp(r'"(item\.[a-z_.]+)"').allMatches(epochs)) m.group(1)!}.where((id) => !id.startsWith('item.dust.'));
    expect(materialSprites.keys, containsAll(ids));
    for (final MapEntry(key: id, value: rows) in materialSprites.entries) {
      final legend = materialSpriteLegend[id]!;
      for (final row in rows) {
        for (final ch in row.split('')) {
          if (ch == '.') continue;
          expect(materialPalette.containsKey(legend[ch]), isTrue, reason: '$id: "$ch" sem cor');
        }
      }
      expect(rows.join().contains(legend.entries.firstWhere((e) => e.value == 'outline').key), isTrue, reason: '$id: tem contorno');
    }
    expect(jsonDecode(epochs), isA<Map>());
  });

  testWidgets('o material sai igual com o mapa girado (de pé), 3 dp por pixel do sprite', (tester) async {
    const view = ui.Size(200, 200);
    final spawn = WorldSpawn(uid: 1, kind: 'material', entryId: 'item.scrap', quantity: 1, x: 10.5, y: 10.5, cellX: 10, cellY: 10, window: 0);
    Future<List<int>> draw(double rot) async {
      final rec = ui.PictureRecorder();
      paintSpawns(ui.Canvas(rec), view, MapCamera(centerX: 10.5, centerY: 10.5, pixelsPerCell: 40, rotation: rot), [spawn],
          sprites: const {}, typeOf: (_) => null, inAura: (_) => true, time: 0, avoid: ui.Rect.zero, spriteSize: 40, sparkSize: 12, artPixelDp: 3);
      final img = rec.endRecording().toImageSync(200, 200);
      final b = (await tester.runAsync(() => img.toByteData()))!;
      return [for (var i = 0; i < b.lengthInBytes; i += 4) b.getUint32(i)];
    }

    final a = await draw(0), b = await draw(math.pi / 2);
    expect(a.where((p) => p & 0xff != 0), isNotEmpty);
    expect(b, a, reason: 'o sprite não gira');
    final rows = materialSprites['item.scrap']!;
    final opaque = a.where((p) => p & 0xff != 0).length;
    final pixels = rows.join().replaceAll('.', '').length;
    expect(opaque, pixels * 9, reason: 'cada pixel do sprite vira 3 × 3');
  });
}
