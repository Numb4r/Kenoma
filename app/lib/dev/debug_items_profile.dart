/// Itens da seção Jogador para o Perfil: conceder níveis, XP e pontos de talento. Editam o save em disco (o mapa
/// fechado); reabra o mapa depois. O teto de nível e os talentos devidos por nível voltam a valer no carregamento.
library;

import 'package:flutter/material.dart';

import '../ui/tema.dart';
import 'debug_env.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';

/// Devolve o JSON do save com [levels] níveis a mais (XP do nível zerado), [xp] a mais e [talent] pontos de talento.
/// O teto de nível e os pontos devidos por nível são aplicados por `GameState.fromJson`.
Map<String, dynamic> grantProfile(Map<String, dynamic> save, {int levels = 0, int xp = 0, int talent = 0}) {
  final player = {...?(save['player'] as Map<String, dynamic>?)};
  player['level'] = ((player['level'] as int?) ?? 1) + levels;
  if (levels > 0) player['xp'] = 0;
  player['xp'] = ((player['xp'] as int?) ?? 0) + xp;
  final conjurer = {...?(save['conjurer'] as Map<String, dynamic>?)};
  conjurer['talent_earned'] = ((conjurer['talent_earned'] as int?) ?? 0) + talent;
  return {...save, 'player': player, 'conjurer': conjurer};
}

List<DebugItem> profileItems(DebugEnv env) => [
      DebugItem(
        id: 'player.grant',
        title: 'Conceder nível, XP e talento',
        section: DebugSection.player,
        keywords: const ['xp', 'nível', 'level', 'talento', 'perfil', 'conceder'],
        builder: (_) => Builder(
          builder: (context) => DebugColumn([
            const DebugNote('Edita o save. Reabra o mapa depois. O nível para no teto.'),
            DebugWrap([
              DebugButton(label: '+1 nível', onTap: () => _grant(context, env, levels: 1)),
              DebugButton(label: '+5 níveis', onTap: () => _grant(context, env, levels: 5)),
              DebugButton(label: '+500 XP', onTap: () => _grant(context, env, xp: 500)),
              DebugButton(label: '+1 ponto de talento', color: KCores.sinalCiano, onTap: () => _grant(context, env, talent: 1)),
            ]),
          ]),
        ),
      ),
    ];

Future<void> _grant(BuildContext context, DebugEnv env, {int levels = 0, int xp = 0, int talent = 0}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final store = await env.openSave();
    final json = await store.read();
    if (json == null) {
      messenger?.showSnackBar(const SnackBar(content: Text('Sem save ainda: abra o mapa uma vez.')));
      return;
    }
    await store.write(grantProfile(json, levels: levels, xp: xp, talent: talent));
    messenger?.showSnackBar(const SnackBar(content: Text('Concedido. Reabra o mapa.')));
  } catch (_) {
    messenger?.showSnackBar(const SnackBar(content: Text('Não consegui editar o save.')));
  }
}
