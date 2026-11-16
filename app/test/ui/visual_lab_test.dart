import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/lab/lab_art.dart';
import 'package:kenoma/ui/lab/lab_renderer.dart';
import 'package:kenoma/ui/sprites/map_style.dart';
import 'package:kenoma/ui/sprites/phase1_masks.dart';
import 'package:kenoma/ui/sprites/phase1_sprites.dart';
import 'package:kenoma/ui/sprites/sprite_image.dart';
import 'package:kenoma/ui/sprites/variant_art.dart';
import 'package:kenoma/world/lab_block.dart';

import '../support/fixtures.dart';

/// O Laboratório visual (0.21.0) e os dados de arte do `criativo` (`map_style.dart`, `variant_art.dart`).
void main() {
  test('todo caractere dos carimbos tem legenda, e toda legenda aponta para uma cor da paleta', () {
    for (final e in mapStamps.entries) {
      final legend = mapStampLegend[e.key];
      expect(legend, isNotNull, reason: e.key);
      for (final row in e.value) {
        for (final ch in row.split('')) {
          if (ch != '.') expect(legend, contains(ch), reason: '${e.key}: $ch');
        }
      }
    }
    for (final l in mapStampLegend.entries) {
      for (final key in l.value.values) {
        expect(mapPalette, contains(key), reason: '${l.key} → $key');
      }
    }
    for (final r in groundRecipes.values) {
      for (final s in r.stamps) {
        expect(mapStamps, contains(s));
      }
    }
  });

  test('toda variante de toda forma dá 48 linhas de 48 e toda cor existe na paleta da variante', () {
    for (final key in phase1Masks.keys) {
      final rows = phase1Rows(key);
      for (final v in const ['urban', 'green', 'water', 'residential', 'lit', 'sacred', 'crimson', 'shiny']) {
        final out = variantRows(rows, v);
        expect((out.length, out.every((r) => r.length == 48)), (48, true), reason: '$key@$v');
        final pal = variantPalette(spritePaletteOf(key), v);
        for (final r in out) {
          for (final ch in r.split('')) {
            if (ch != '.') expect(pal, contains(ch), reason: '$key@$v: $ch');
          }
        }
        final glow = variantGlowRows(rows, v);
        if (v != 'lit') expect(glow, isNull);
      }
    }
  });

  test('o quarteirão carrega e o estilo de antes desenha de dia e de noite, girando (o de depois está em city_renderer_test)', () {
    final block = LabBlock.fromJson(jsonDecode(File('assets/lab/centro_bloco.json').readAsStringSync()) as Map<String, dynamic>);
    expect(block.buildings, isNotEmpty);
    expect(block.roads, isNotEmpty);
    final art = LabArt.build();
    final r = LabRenderer(block, art, loadBiomes());
    for (final (alt, rot) in [(40.0, 0.0), (-20.0, 1.2)]) {
      final rec = ui.PictureRecorder();
      r.paint(ui.Canvas(rec), const ui.Size(137, 260), LabView(cx: 0, cy: 0, rotation: rot, pxPerM: 1.2, sunAltDeg: alt, sunAzDeg: 80, localHour: alt > 0 ? 10 : 22));
      final img = rec.endRecording().toImageSync(137, 260);
      expect(img.width, 137);
      img.dispose();
    }
    art.dispose();
  });
}
