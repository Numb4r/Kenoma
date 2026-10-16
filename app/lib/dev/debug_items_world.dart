/// Itens das seções Spawns, Mapa e câmera e Jogador: forçar o próximo Eco, sobreposições do mapa, névoa, Radar,
/// mapa livre, mapa do jogo e o nível do Conjurador. Forçar vale para o próximo Eco novo desta sessão; a névoa, o
/// Radar e o nível mexem no save (valem na próxima vez que o mapa abrir).
library;

import 'package:flutter/material.dart';

import '../core/behavior.dart';
import '../save/ksv_save_store.dart';
import '../ui/game/game_map_screen.dart';
import '../ui/map/map_screen.dart';
import '../ui/tema.dart';
import '../world/places.dart';
import 'debug_env.dart';
import 'debug_items_fusion.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';
import 'street_debug_section.dart';

List<DebugItem> spawnItems(DebugEnv env) {
  final force = env.tools.force;
  Widget listen(Widget Function() build) => ListenableBuilder(listenable: force, builder: (_, _) => build());
  return [
    DebugItem(
      id: 'spawn.behavior',
      title: 'Forçar comportamento',
      section: DebugSection.spawns,
      keywords: const ['eco', 'arisco', 'agressivo', 'passivo', 'próximo spawn'],
      builder: (_) => listen(() => DebugColumn([
            const DebugNote('ATENÇÃO: o que for forçado e capturado fica no seu save como se fosse de verdade.', color: KCores.brasaLaranja),
            const DebugNote('Próximo Eco novo à vista.'),
            DebugWrap([for (final b in EcoBehavior.values) DebugChip(b.label, on: force.nextBehavior == b, color: KCores.brasaLaranja, onTap: () => force.set(behavior: b))]),
          ])),
    ),
    DebugItem(
      id: 'spawn.variant',
      title: 'Forçar variante de bioma',
      section: DebugSection.spawns,
      keywords: const ['variante', 'bioma', 'próximo spawn'],
      builder: (_) => listen(() => DebugChip('Variante de bioma', on: force.nextVariant, onTap: () => force.set(variant: !force.nextVariant))),
    ),
    DebugItem(
      id: 'spawn.shiny',
      title: 'Forçar Brilhante',
      section: DebugSection.spawns,
      keywords: const ['shiny', 'brilhante', 'raro', 'próximo spawn'],
      builder: (_) => listen(() => DebugChip('Brilhante', on: force.nextShiny, onTap: () => force.set(shiny: !force.nextShiny))),
    ),
    DebugItem(
      id: 'spawn.spirit',
      title: 'Forçar Espírito',
      section: DebugSection.spawns,
      keywords: const ['espírito', 'spirit', 'fusão', 'próximo spawn'],
      builder: (_) => listen(() => DebugColumn([
            const DebugNote('O próximo Eco novo à vista vira o Espírito da família dele, mesmo abaixo do nível 8.'),
            DebugChip('Espírito', on: force.nextSpirit, color: KCores.veuVioleta, onTap: () => force.set(spirit: !force.nextSpirit)),
          ])),
    ),
    DebugItem(
      id: 'spawn.clear',
      title: 'Pedidos forçados',
      section: DebugSection.spawns,
      keywords: const ['zerar', 'resetar', 'forçar'],
      builder: (_) => DebugButton(
        label: 'Limpar pedidos',
        color: KCores.textoMudo,
        onTap: () {
          force.nextBehavior = null;
          force.set(variant: false, shiny: false, spirit: false);
        },
      ),
    ),
  ];
}

List<DebugItem> mapItems(DebugEnv env) {
  final tools = env.tools;
  Widget overlay(String title, String? subtitle, bool Function() get, void Function(bool) set) => ListenableBuilder(
        listenable: tools,
        builder: (_, _) => DebugSwitch(title: title, subtitle: subtitle, value: get(), onChanged: set),
      );
  return [
    DebugItem(
      id: 'map.open_game',
      title: 'Mapa do jogo',
      section: DebugSection.map,
      keywords: const ['abrir', 'jogar', 'mapa', 'gps'],
      builder: (_) => ListenableBuilder(
        listenable: tools,
        builder: (context, _) => DebugButton(
          label: 'Abrir mapa do jogo',
          color: KCores.sinalCiano,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GameMapScreen(tools: tools, openStore: KsvSaveStore.inDocuments))),
        ),
      ),
    ),
    DebugItem(
      id: 'map.biome_grid',
      title: 'Grade de biomas',
      section: DebugSection.map,
      keywords: const ['sobreposição', 'camada lógica', 'overlay'],
      builder: (_) => overlay('Grade de biomas no mapa do jogo', 'A camada lógica, translúcida por cima do desenho.', () => tools.showBiomeGrid, (v) => tools.setOverlays(biomes: v)),
    ),
    DebugItem(
      id: 'map.grid20',
      title: 'Grade das células de spawn',
      section: DebugSection.map,
      keywords: const ['z20', 'células', 'sobreposição', 'overlay'],
      builder: (_) => overlay('Grade das células de spawn (z20)', null, () => tools.showGrid20, (v) => tools.setOverlays(grid20: v)),
    ),
    DebugItem(
      id: 'map.radii',
      title: 'Raios lógicos',
      section: DebugSection.map,
      keywords: const ['alcance', '30 m', 'toque', 'coleta', 'aura', 'sobreposição', 'overlay'],
      builder: (_) => overlay('Raios lógicos: coleta (laranja) e toque 30 m (ciano)', null, () => tools.showRadii, (v) => tools.setOverlays(radii: v)),
    ),
    DebugItem(
      id: 'map.fog_reveal',
      title: 'Revelar névoa',
      section: DebugSection.map,
      keywords: const ['névoa', 'fog', 'explorar', '600 m'],
      builder: (_) => Builder(
        builder: (context) => DebugButton(
          label: 'Revelar névoa (600 m)',
          color: KCores.sinalCiano,
          onTap: () {
            final (lat, lon) = env.center();
            _editSave(context, env, (j) => revealDebugFog(j, lat, lon, 600), 'Névoa revelada em 600 m (debug).');
          },
        ),
      ),
    ),
    DebugItem(
      id: 'map.fog_clear',
      title: 'Névoa de debug',
      section: DebugSection.map,
      keywords: const ['névoa', 'fog', 'apagar'],
      builder: (_) => Builder(
        builder: (context) => DebugButton(
          label: 'Limpar névoa de debug',
          color: KCores.textoMudo,
          onTap: () => _editSave(context, env, clearDebugFog, 'Névoa de debug apagada; o caminho real ficou.'),
        ),
      ),
    ),
    DebugItem(
      id: 'map.radar_reset',
      title: 'Recarga do Radar',
      section: DebugSection.map,
      keywords: const ['radar', 'ocultos', 'zerar'],
      builder: (_) => Builder(
        builder: (context) => DebugButton(label: 'Zerar recarga do Radar', color: KCores.brasaLaranja, onTap: () => _editSave(context, env, resetRadar, 'Radar pronto.')),
      ),
    ),
    DebugItem(
      id: 'map.free',
      title: 'Mapa livre',
      section: DebugSection.map,
      keywords: const ['coordenada', 'latitude', 'longitude', 'unicamp', 'centro', 'abrir mapa'],
      builder: (_) => _FreeMap(env: env),
    ),
  ];
}

/// Lê o save, aplica [change] e grava. Avisa por snackbar; sem jogo salvo, não grava.
Future<void> _editSave(BuildContext context, DebugEnv env, Map<String, dynamic> Function(Map<String, dynamic>) change, String done) async {
  final say = debugSayer(context);
  try {
    final store = await env.openSave();
    final raw = await store.read();
    if (raw == null) return say('Ainda não há jogo salvo: abra o mapa uma vez.');
    await store.write(change(raw));
    say(done);
  } catch (e) {
    say('Erro: $e');
  }
}

class _FreeMap extends StatefulWidget {
  const _FreeMap({required this.env});

  final DebugEnv env;

  @override
  State<_FreeMap> createState() => _FreeMapState();
}

class _FreeMapState extends State<_FreeMap> {
  void _preset((double, double) c) => setState(() {
        widget.env.lat.text = c.$1.toString();
        widget.env.lon.text = c.$2.toString();
      });

  void _open() {
    final c = parseCoord(widget.env.lat.text, widget.env.lon.text);
    if (c == null) return debugSnack(context, 'Coordenada inválida');
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MapScreen(lat: c.$1, lon: c.$2, nowUtc: widget.env.tools.clock.nowUtc)));
  }

  @override
  Widget build(BuildContext context) => DebugColumn([
        Row(children: [
          Expanded(child: DebugField('Latitude', widget.env.lat, numeric: true)),
          const SizedBox(width: KEspaco.s1),
          Expanded(child: DebugField('Longitude', widget.env.lon, numeric: true)),
        ]),
        DebugWrap([
          DebugButton(label: 'Unicamp', color: KCores.textoMudo, onTap: () => _preset(kUnicamp)),
          DebugButton(label: 'Centro', color: KCores.textoMudo, onTap: () => _preset(kCentroCampinas)),
        ]),
        DebugButton(label: 'Abrir mapa', color: KCores.sinalCiano, onTap: _open),
      ]);
}

List<DebugItem> playerItems(DebugEnv env) => [
      DebugItem(
        id: 'player.level',
        title: 'Nível do Conjurador no jogo',
        section: DebugSection.player,
        keywords: const ['nível', 'level', 'override', 'conjurador', 'forçar'],
        builder: (_) => _LevelOverride(env: env),
      ),
      ...fusionItems(env),
    ];

/// Override do nível (1 a 15) guardado no save; 0 deixa valer o nível real. Os Ecos do mapa e a resistência usam o
/// override. Sem pasta de documentos (testes), vive só na memória do [DevTools].
class _LevelOverride extends StatelessWidget {
  const _LevelOverride({required this.env});

  final DebugEnv env;

  Future<void> _set(int level) async {
    env.tools.setLevelOverride(level);
    try {
      final store = await env.openSave();
      final json = {...?await store.read()}..remove('player_level');
      level == 0 ? json.remove('level_override') : json['level_override'] = level;
      await store.write(json);
    } catch (_) {
      // sem disco, o nível vale só até fechar o menu
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: env.tools,
        builder: (context, _) {
          final l = env.tools.levelOverride;
          return DebugColumn([
            Text(l == 0 ? 'Nível do Conjurador no jogo: real' : 'Nível do Conjurador no jogo: $l (override)', style: KTexto.corpo),
            const DebugNote('0 usa o nível real. Um valor aqui manda nos Ecos do mapa e na resistência. Vale na próxima vez que abrir o mapa.'),
            Slider(value: l.toDouble(), min: 0, max: 15, divisions: 15, label: l == 0 ? 'real' : '$l', activeColor: KCores.sinalCiano, onChanged: (v) => _set(v.round())),
          ]);
        },
      );
}
