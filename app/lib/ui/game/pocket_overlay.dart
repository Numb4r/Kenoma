import 'package:flutter/widgets.dart';

import '../../world/pocket_mode.dart';

/// Sobreposição preta com 95% de opacidade sobre o mapa quando o modo bolso está ligado e o sensor coberto.
/// Não desliga nada por baixo (o mapa, o wakelock e a Aura continuam) e absorve toques acidentais.
class PocketOverlay extends StatelessWidget {
  const PocketOverlay({required this.mode, required this.enabled, super.key});

  final PocketMode mode;
  final bool Function() enabled;

  static const opacity = 0.95;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: mode,
        builder: (context, _) => mode.covered && enabled()
            ? const Positioned.fill(
                child: AbsorbPointer(child: ColoredBox(key: ValueKey('pocket-dark'), color: Color.fromRGBO(0, 0, 0, opacity))),
              )
            : const SizedBox.shrink(),
      );
}
