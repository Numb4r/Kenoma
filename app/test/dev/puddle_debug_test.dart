import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/climate.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/ui/game/game_map_game.dart' show paintPuddleMarkers;
import 'package:kenoma/world/climate_world.dart';
import 'package:kenoma/world/map_camera.dart';

import '../support/fake_position_source.dart';

/// 0.20.3: o marcador de poças do debug e o "ir até a poça mais próxima".
void main() {
  const piece = PuddlePiece('puddle', perCell: 1, radiusM: (2, 4), growS: 600, dryS: 600, frozen: false, always: false);
  Puddle at(double x, double y, {bool personal = false}) => Puddle(
        piece: piece,
        index: 0,
        x: x,
        y: y,
        radiusM: 3,
        size: 1,
        wet: true,
        rolls: (itemRoll: 0.5, spawnRoll: 0.5, pick: 0.5, uid: x.toInt()),
        personal: personal,
      );

  test('a poça mais próxima, das duas camadas; sem poça, nenhuma', () {
    final ps = [at(100, 100), at(10, 12, personal: true), at(-50, 0)];
    expect(nearestPuddle(ps, 0, 0)!.personal, isTrue);
    expect(nearestPuddle(ps, 90, 95)!.x, 100);
    expect(nearestPuddle(const [], 0, 0), isNull);
  });

  test('ir até a poça: liga o GPS simulado sem recompensa e leva o simulador até ela; sem mapa ou sem poça, só avisa', () async {
    final tools = DevTools(realSource: FakeGps())..setSimRewards(true);
    expect(await tools.goToNearestPuddle(), 'Abra o mapa do jogo antes');
    expect(tools.useSimulator, isFalse);
    tools.nearestPuddle = () => null;
    expect(await tools.goToNearestPuddle(), contains('Nenhuma poça'));
    expect(tools.useSimulator, isFalse, reason: 'sem poça, nada muda');
    tools.nearestPuddle = () => (-22.86, -47.05);
    expect(await tools.goToNearestPuddle(), contains('sem recompensa'));
    expect((tools.useSimulator, tools.simRewards, tools.sandboxed), (true, false, true));
    expect((tools.simulator.lat, tools.simulator.lon), (-22.86, -47.05));
    expect(tools.anyForcing, isTrue);
  });

  test('o marcador fica ligado no DevTools e desenha um alvo por poça na tela, de cores diferentes por camada', () {
    final tools = DevTools(realSource: FakeGps());
    expect(tools.showPuddles, isFalse);
    tools.setShowPuddles(true);
    expect((tools.showPuddles, tools.anyForcing), (true, true));
    final rec = PictureRecorder();
    final canvas = Canvas(rec);
    final cam = MapCamera(centerX: 0, centerY: 0, pixelsPerCell: 20);
    // Uma do Rill e uma do mundo na tela, e uma longe (fora da tela): só as duas primeiras viram alvo.
    expect(paintPuddleMarkers(canvas, const Size(400, 800), cam, [at(1, 1, personal: true), at(-2, 3), at(900, 900)]), 2);
    rec.endRecording();
  });
}
