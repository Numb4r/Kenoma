import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/game/fx.dart';
import 'package:kenoma/world/map_camera.dart';
import 'package:kenoma/world/spawn_field.dart';

WorldSpawn spawn(int uid, {String kind = 'spark', String entry = 'item.dust.fire', int qty = 1}) =>
    WorldSpawn(uid: uid, kind: kind, entryId: entry, quantity: qty, x: 100, y: 100, cellX: 0, cellY: 0, window: 0);

void main() {
  const fire = ui.Color(0xFFFF7A45);

  test('a coleta voa 300 ms até o Conjurador, vira brilho e depois um "+N" que some em 900 ms', () {
    final fx = Fx();
    fx.collected(spawn(1), fire);
    expect(fx.alive, 1);
    fx.update(0.29);
    expect(fx.alive, 1, reason: 'ainda voando');
    fx.update(0.02);
    expect(fx.alive, 2, reason: 'pousou: brilho + contador');
    fx.update(0.2);
    expect(fx.alive, 1, reason: 'o brilho de 160 ms acabou, o +1 segue');
    fx.update(0.8);
    expect(fx.alive, 0);
  });

  test('coletas seguidas do mesmo item empilham num contador só', () {
    final fx = Fx();
    for (var i = 0; i < 4; i++) {
      fx.collected(spawn(i), fire);
    }
    fx.update(0.29);
    fx.update(0.02);
    // Quatro voos pousaram juntos: um contador "+4" e quatro brilhos.
    expect(fx.plusLabels, ['+4']);
    fx.update(0.01);
    fx.collected(spawn(9), fire);
    fx.update(0.31);
    expect(fx.plusLabels, ['+5'], reason: 'o contador segue vivo e soma');
  });

  test('o Eco tocado pula e volta ao chão em 200 ms', () {
    final fx = Fx();
    fx.hop(7);
    fx.update(0.1);
    expect(fx.hopOffset(7, 8), closeTo(-8, 0.01), reason: 'no topo do pulo');
    expect(fx.hopOffset(8, 8), 0, reason: 'outro Eco não pula');
    fx.update(0.11);
    expect(fx.hopOffset(7, 8), 0);
    expect(fx.alive, 0);
  });

  test('Eco novo surge com a costura em 250 ms; o que já estava no mapa ao abrir não anima', () {
    final fx = Fx();
    fx.observe([spawn(1, kind: 'eco', entry: 'soot.eco')]);
    expect(fx.appear(1), 1, reason: 'primeira lista: sem animação');
    fx.observe([spawn(1, kind: 'eco'), spawn(2, kind: 'eco')]);
    expect(fx.appear(2), 0);
    fx.update(0.125);
    expect(fx.appear(2), closeTo(0.5, 0.01));
    fx.update(0.13);
    expect(fx.appear(2), 1);
    expect(fx.alive, 0);
  });

  test('o Eco que foge se desfaz em 400 ms', () {
    final fx = Fx();
    fx.fled(spawn(3, kind: 'eco'), null, null, 40);
    expect(fx.alive, 1);
    fx.update(0.39);
    expect(fx.alive, 1);
    fx.update(0.02);
    expect(fx.alive, 0);
  });

  test('desenha todos os efeitos sem erro', () {
    final fx = Fx();
    fx.collected(spawn(1), fire);
    fx.collected(spawn(2, kind: 'material', entry: 'item.scrap'), fire);
    fx.fled(spawn(3, kind: 'eco'), null, null, 40);
    fx.update(0.31);
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    fx.paint(canvas, const ui.Size(400, 800), _cam, avatar: const ui.Offset(200, 400), playerSize: 27, sparkSize: 14, dpr: 2);
    rec.endRecording().dispose();
  });
}

final _cam = MapCamera(centerX: 100, centerY: 100, pixelsPerCell: 20, rotation: 0.4);
