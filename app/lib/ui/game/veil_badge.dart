/// O selo "Véu instável": aparece só com o jogador num bloco da Overpass, onde amigos em versões diferentes podem ver coisas
/// diferentes. Um toque explica.
library;

import 'package:flutter/material.dart';

import '../../world/layered_world.dart';
import '../colors.dart';
import '../pressable.dart';

const String kVeilBadgeHelp = 'Aqui o mapa veio da rede: amigos em versões diferentes do app podem ver coisas diferentes.';

class VeilBadge extends StatelessWidget {
  const VeilBadge({required this.source, required this.onExplain, super.key});

  final ValueNotifier<MapSourceKind> source;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: source,
        builder: (context, kind, _) => kind != MapSourceKind.overpass
            ? const SizedBox.shrink()
            : Pressable(
                onTap: onExplain,
                child: Container(
                  key: const Key('veil-badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.85), border: Border.all(color: kVeil, width: 2)),
                  child: const Text('VÉU INSTÁVEL', style: TextStyle(fontSize: 8, color: kVeil)),
                ),
              ),
      );
}
