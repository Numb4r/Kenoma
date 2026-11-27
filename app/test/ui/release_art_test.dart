import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/game/spawn_painter.dart';
import 'package:kenoma/ui/menu/screen_frame.dart';
import 'package:kenoma/ui/sprites/sprite_image.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/spawn_field.dart';

/// 0.26.2: o sprite provisório (o gerado por código) nunca é desenhado na build de release. Sem a arte do Aseprite (ainda
/// carregando), o Bestiário mostra a silhueta escura e o mapa não desenha a criatura. `provisionalArt` é `kDebugMode`
/// (falso na release e na profile); aqui ele é trocado para conferir.
void main() {
  final species = [
    for (final s in (jsonDecode(File('assets/data/creatures.json').readAsStringSync()) as Map<String, dynamic>)['species'] as List<dynamic>)
      (s as Map<String, dynamic>)['id'] as String,
  ];

  void release(bool on) {
    provisionalArt = !on;
    addTearDown(() => provisionalArt = true);
  }

  /// As cores opacas de [img] (ARGB), sem repetir.
  Future<Set<int>> colorsOf(WidgetTester tester, ui.Image img) async {
    final b = (await tester.runAsync(() => img.toByteData()))!;
    return {
      for (var i = 0; i < b.lengthInBytes; i += 4)
        if (b.getUint8(i + 3) > 0) (b.getUint8(i + 3) << 24) | (b.getUint8(i) << 16) | (b.getUint8(i + 1) << 8) | b.getUint8(i + 2),
    };
  }

  testWidgets('na release o EcoSprite de toda espécie é só a silhueta escura, também com as costuras acesas', (tester) async {
    release(true);
    for (final id in species) {
      final s = (await tester.runAsync(() => EcoSprite.load(id)))!;
      expect(await colorsOf(tester, s.normal), {kSilhouetteArgb}, reason: '$id: o provisório colorido foi desenhado');
      expect(await colorsOf(tester, s.bright), {kSilhouetteArgb}, reason: '$id: as costuras acesas');
    }
  });

  testWidgets('fora da release (testes, debug) o provisório continua colorido', (tester) async {
    final s = (await tester.runAsync(() => EcoSprite.load('soot.eco')))!;
    expect((await colorsOf(tester, s.normal)).length, greaterThan(3));
  });

  testWidgets('na release a célula do Bestiário sem a arte carregada mostra a silhueta, como a não vista', (tester) async {
    release(true);
    final sprite = (await tester.runAsync(() => EcoSprite.load('soot.eco')))!;
    await tester.pumpWidget(MaterialApp(home: Center(child: SpeciesImage(sprite: sprite, speciesId: 'soot.eco'))));
    final shown = tester.widget<RawImage>(find.byType(RawImage)).image!;
    expect(await colorsOf(tester, shown), {kSilhouetteArgb});
  });

  /// Quantos pixels o pintor do mapa desenha para um Eco sem a arte do Aseprite, com o provisório à mão em [sprites].
  Future<int> paintedPixels(WidgetTester tester) async {
    final eco = WorldSpawn(uid: 7, kind: 'eco', entryId: 'soot.eco', quantity: 1, x: 10.5, y: 10.5, cellX: 5, cellY: 5, window: 0, level: 1);
    final provisional = (await tester.runAsync(() => EcoSprite.loadMap('soot.eco')))!.normal;
    final rec = ui.PictureRecorder();
    paintSpawns(ui.Canvas(rec), const ui.Size(120, 120), MapCamera(centerX: 10.5, centerY: 10.5, pixelsPerCell: 40), [eco],
        sprites: {'soot.eco': provisional}, typeOf: (_) => null, inAura: (_) => true, time: 0, avoid: ui.Rect.zero, spriteSize: 40, sparkSize: 12);
    final img = (await tester.runAsync(() => rec.endRecording().toImage(120, 120)))!;
    final b = (await tester.runAsync(() => img.toByteData()))!;
    var n = 0;
    for (var i = 3; i < b.lengthInBytes; i += 4) {
      if (b.getUint8(i) > 0) n++;
    }
    return n;
  }

  testWidgets('na release o mapa não desenha o Eco sem a arte (o provisório nunca aparece); fora dela desenha', (tester) async {
    expect(await paintedPixels(tester), greaterThan(100), reason: 'controle: fora da release o provisório aparece');
    release(true);
    expect(await paintedPixels(tester), 0, reason: 'o provisório foi desenhado no mapa da release');
  });
}
