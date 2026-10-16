/// Etiqueta "DEBUG" do HUD do mapa: aparece enquanto qualquer forçamento estiver ativo (simulador de GPS, relógio,
/// nível, comportamento/variante/Brilhante, clima, sobreposições) e some sozinha quando nada está. Não recebe toque.
library;

import 'package:flutter/widgets.dart';

import '../ui/tema.dart';
import '../world/debug_force.dart';
import 'dev_tools.dart';

class DebugTag extends StatelessWidget {
  const DebugTag({required this.tools, super.key});

  final DevTools tools;

  DebugForce get force => tools.force;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([tools, tools.clock, force]),
        builder: (context, _) {
          if (!tools.anyForcing) return const SizedBox.shrink();
          return IgnorePointer(
            child: Container(
              key: const Key('debug-tag'),
              padding: const EdgeInsets.symmetric(horizontal: KEspaco.s1, vertical: 3),
              decoration: BoxDecoration(color: KCores.fundo.withValues(alpha: 0.85), border: Border.all(color: KCores.brasaLaranja, width: kContornoDp)),
              child: Text('DEBUG', style: KTexto.rotulo.copyWith(color: KCores.brasaLaranja, fontSize: 9)),
            ),
          );
        },
      );
}
