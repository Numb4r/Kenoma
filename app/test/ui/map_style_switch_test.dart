import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/game/draw_order.dart';
import 'package:kenoma/world/style_advisor.dart';

import 'game_map_screen_test.dart' show pumpGame;

/// 0.22.0 (GDD, Câmera): os dois estilos do mapa trocam pelos Ajustes sem reiniciar, com a mesma lógica: a camada base de
/// spawn e os spawns à vista não mudam com o estilo.
void main() {
  testWidgets('Completo e Simplificado trocam na hora, e a camada base é a mesma nos dois', (tester) async {
    final env = await pumpGame(tester);
    await env.live(1);
    final g = env.game, w = g.worldView!;
    expect(g.fullStyle, isTrue, reason: 'o Completo é o padrão');
    expect(g.lastLayers, contains(MapLayer.buildings));
    expect(g.city.cachedChunks, greaterThan(0));
    final cx = g.avatar.x.floor() >>> 1, cy = g.avatar.y.floor() >>> 1, t = env.tools.clock.nowUtc;
    final base = w.field.baseHashAt(cx, cy, t);
    final seen = {for (final s in w.spawns) s.uid};

    w.state.setSetting(kSimpleGraphicsSetting, true);
    await env.settle(4);
    expect(g.fullStyle, isFalse);
    expect(g.lastLayers, isNot(contains(MapLayer.buildings)));
    expect(g.lastLayers, containsAll([MapLayer.base, MapLayer.reach, MapLayer.creatures, MapLayer.player]), reason: 'o jogo continua todo no Simplificado');
    expect(g.city.cachedChunks, 0, reason: 'os blocos do Completo saem da memória');
    expect(w.field.baseHashAt(cx, cy, t), base);
    expect({for (final s in w.spawns) s.uid}.intersection(seen), isNotEmpty);

    w.state.setSetting(kSimpleGraphicsSetting, false);
    await env.settle(4);
    expect(g.lastLayers, contains(MapLayer.buildings));
    expect(w.field.baseHashAt(cx, cy, t), base);
  });

  testWidgets('0.22.2: com o Zoom ampliado a pinça vai a 250 m, acima de 120 m fica Simplificado e volta; Ecos só dentro da visão', (tester) async {
    final env = await pumpGame(tester);
    await env.live(1);
    final g = env.game, w = g.worldView!;
    w.state.setSetting(kWideZoomSetting, true);
    await env.settle(2);
    expect(g.maxWidthM, kWideZoomMaxM);
    g.widthM = 250;
    await env.settle(4);
    expect(g.fullStyle, isFalse, reason: 'acima de 120 m');
    expect(g.lastLayers, isNot(contains(MapLayer.buildings)));
    expect(g.lastLayers, isNot(contains(MapLayer.cars)), reason: 'de longe, sem tráfego');
    expect(g.rainCount, 0, reason: 'de longe, sem partículas');
    // O zoom não muda o jogo: os Ecos continuam só dentro da visão (ou presos pelo jogador).
    for (final s in w.spawns.where((s) => s.isEco)) {
      expect(w.distanceM(s) <= w.viewM || w.isPinned(s), isTrue, reason: 'Eco a ${w.distanceM(s).round()} m');
    }
    g.widthM = 60;
    await env.settle(4);
    expect(g.fullStyle, isTrue, reason: 'volta ao Completo ao fechar o zoom');
    expect(g.lastLayers, contains(MapLayer.buildings));
    w.state.setSetting(kWideZoomSetting, false);
    await env.settle(2);
    expect(g.maxWidthM, 80);
  });
}
