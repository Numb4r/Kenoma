/// Aba Visual: as camadas de debug por cima do mapa, a arte em código, o giro dos objetos, a câmera que segue a peça, a
/// largura da tela, o giro do mapa, o estilo dos gráficos e o laboratório visual. Só neste aparelho; o estilo dos
/// gráficos é a preferência dos Ajustes (fica no save).
library;

import 'package:flutter/material.dart';

import '../ui/game/game_map_screen.dart' show liveGameState;
import '../ui/lab/visual_lab_screen.dart';
import '../world/style_advisor.dart' show kSimpleGraphicsSetting;
import 'debug_env.dart';
import 'debug_items_save.dart' show writeSetting;
import 'debug_registry.dart';

List<DebugEntry> visualEntries(DebugEnv env) {
  final tools = env.tools;
  DebugEntry layer(String id, String name, String chip, List<String> aliases, bool Function() get, void Function(bool v) set, {String? info, List<String> keywords = const []}) => DebugEntry(
        id: 'visual.$id',
        name: name,
        tab: DebugTab.visual,
        kind: DebugKind.toggle,
        aliases: aliases,
        keywords: ['camada', 'sobreposição', 'overlay', ...keywords],
        info: info,
        read: () => get() ? 'on' : 'off',
        run: (c) => set(c.value == 'on'),
        offReal: () => get() ? chip : null,
        toReal: () => set(false),
      );
  return [
    layer('biome_grid', 'Grade de biomas', 'camada de biomas', const ['map.biome_grid'], () => tools.showBiomeGrid, (v) => tools.setOverlays(biomes: v), info: 'A camada lógica, translúcida por cima do desenho.'),
    layer('grid20', 'Grade das células de spawn (z20)', 'grade z20', const ['map.grid20'], () => tools.showGrid20, (v) => tools.setOverlays(grid20: v), keywords: const ['z20', 'células']),
    layer('relief', 'Relevo como mapa de calor', 'relevo', const ['map.relief'], () => tools.showRelief, tools.setRelief,
        info: 'Azul: baixo. Vermelho: alto, dentro do que está na tela. O número é a altura em metros.', keywords: const ['altura', 'srtm', 'morro']),
    layer('radii', 'Raios lógicos', 'raios lógicos', const ['map.radii'], () => tools.showRadii, (v) => tools.setOverlays(radii: v),
        info: 'Coleta (laranja) e toque de 30 m (ciano).', keywords: const ['alcance', '30 m', 'aura']),
    layer('puddles', 'Marcar as poças', 'poças marcadas', const [], () => tools.showPuddles, tools.setShowPuddles,
        info: 'Alvo em cada poça na tela: laranja as da camada pessoal (Rill), ciano as do mundo (água do relevo).', keywords: const ['poça', 'rill', 'água']),
    layer('traffic_area', 'Área do tráfego e semáforos', 'área do tráfego', const [], () => tools.showTraffic, (v) => tools.setTraffic(show: v),
        info: 'Círculo: o raio. Pontos: a luz de cada acesso. Quadrados: entradas (estacionamentos).', keywords: const ['tráfego', 'semáforo', 'carros']),
    layer('code_art', 'Arte em código', 'arte em código', const ['map.code_art'], () => tools.codeArt, tools.setCodeArt,
        info: 'O mapa Completo volta aos carimbos desenhados em código no lugar dos do Aseprite, que são o padrão. Só para comparar.', keywords: const ['aseprite', 'carimbo', 'sprite']),
    layer('turn_labels', 'Giro dos objetos', 'giro dos objetos', const ['map.turn_labels', 'labels'], () => tools.turnLabels, tools.setTurnLabels,
        info: 'Escreve sobre cada objeto do mapa o tipo e se ele gira com o chão, fica de pé ou gira com o rumo.', keywords: const ['rotação', 'de pé', 'rótulo']),
    layer('follow_piece', 'Câmera segue a peça', 'câmera na peça', const ['map.follow_piece'], () => tools.followPiece, tools.setFollowPiece,
        info: 'A câmera vai até a peça do clima que se move mais perto (funil, Procissão, olhar, prédio da Maré) e a acompanha. O jogo continua medindo no Conjurador.',
        keywords: const ['tornado', 'procissão', 'gif', 'workbench']),
    DebugEntry(
      id: 'visual.width',
      name: 'Largura da tela',
      tab: DebugTab.visual,
      kind: DebugKind.choice,
      aliases: const ['map.width', 'width'],
      keywords: const ['zoom', 'largura', 'pinça', 'metros'],
      info: 'O zoom do mapa sem pinça, até o limite de agora (80 m, ou 250 m com o Zoom ampliado).',
      options: const [DebugOption('auto', 'Pinça'), DebugOption('50', '50 m'), DebugOption('80', '80 m'), DebugOption('120', '120 m'), DebugOption('250', '250 m')],
      read: () => tools.forcedWidthM == null ? 'auto' : '${tools.forcedWidthM!.round()}',
      run: (c) => tools.setWidthM(c.value == 'auto' ? null : c.numberOf('')),
      offReal: () => tools.forcedWidthM == null ? null : 'largura ${tools.forcedWidthM!.round()} m',
      toReal: () => tools.setWidthM(null),
    ),
    DebugEntry(
      id: 'visual.turn',
      name: 'Girar o mapa',
      tab: DebugTab.visual,
      kind: DebugKind.action,
      aliases: const ['turn'],
      keywords: const ['giro', 'rotação', 'graus', 'rumo'],
      info: 'Gira o mapa até o ângulo, na hora (sentido horário, 0 = norte). Com o mapa aberto.',
      params: const [DebugParam('deg', 'graus', kind: DebugParamKind.number, min: 0, max: 359, fallback: '30')],
      run: (c) {
        final turn = tools.turnMapTo;
        if (turn == null) throw const DebugError('abra o mapa antes');
        turn(c.numberOf('deg'));
        return 'Mapa a ${c['deg']}°';
      },
    ),
    DebugEntry(
      id: 'visual.style',
      name: 'Gráficos do mapa',
      tab: DebugTab.visual,
      kind: DebugKind.choice,
      aliases: const ['style'],
      touchesSave: true,
      keywords: const ['estilo', 'simplificado', 'completo', 'ajustes'],
      info: 'A preferência dos Ajustes (Completo ou Simplificado), gravada no save.',
      options: const [DebugOption('full', 'Completo'), DebugOption('simple', 'Simplificado')],
      read: () => switch (liveGameState()?.setting(kSimpleGraphicsSetting)) { true => 'simple', false => 'full', null => null },
      run: (c) async {
        final simple = c.value == 'simple', live = liveGameState();
        live != null ? live.setSetting(kSimpleGraphicsSetting, simple) : await writeSetting(env.openSave, kSimpleGraphicsSetting, simple);
        return 'Gráficos ${simple ? 'simplificados' : 'completos'}';
      },
    ),
    DebugEntry(
      id: 'visual.lab',
      name: 'Laboratório visual',
      tab: DebugTab.visual,
      kind: DebugKind.action,
      aliases: const ['map.visual_lab'],
      keywords: const ['laboratório', 'estilo', 'prédios', 'arte', 'antes e depois', 'céu', 'horizonte'],
      info: 'O quarteirão da Praça Ramos de Azevedo no estilo de hoje e no novo, com a hora, o clima e até dois eventos. Nada entra no mapa até o estilo ser aprovado.',
      run: (c) {
        Navigator.of(c.screen).push(MaterialPageRoute<void>(builder: (_) => VisualLabScreen(nowUtc: () => tools.clock.nowUtc)));
        return null;
      },
    ),
  ];
}
