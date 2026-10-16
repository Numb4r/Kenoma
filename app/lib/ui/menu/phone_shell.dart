/// O esqueleto comum das telas do celular: fundo, barra de status fina, cabeçalho com o botão de voltar de 48 dp e o
/// título, e a transição de página (desliza da direita em 200 ms). Telas novas usam [PhoneScreen]; as antigas passam
/// por `ScreenFrame`, que já usa esta.
library;

import 'package:flutter/material.dart';

import '../tema.dart';
import 'phone_status.dart';

const Duration phonePageDuration = Duration(milliseconds: 200);

/// A rota padrão das telas do celular (e do Perfil aberto pelo retrato).
Route<T> phoneRoute<T>(Widget screen) => PageRouteBuilder<T>(
      opaque: true,
      transitionDuration: phonePageDuration,
      reverseTransitionDuration: phonePageDuration,
      pageBuilder: (_, _, _) => screen,
      transitionsBuilder: (_, anim, _, child) =>
          SlideTransition(position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)), child: child),
    );

class PhoneScreen extends StatelessWidget {
  const PhoneScreen({required this.title, required this.child, this.actions = const [], super.key});

  final String title;
  final Widget child;

  /// Botões à direita do título (cada um com pelo menos 48 dp de toque).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KCores.fundo,
      body: SafeArea(
        child: Column(children: [
          const PhoneStatusBar(compact: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(KEspaco.s1, KEspaco.s1, KEspaco.s2, KEspaco.s1),
            child: Row(children: [
              GestureDetector(
                key: const Key('phone-back'),
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: const SizedBox(width: kToqueMinDp, height: kToqueMinDp, child: Center(child: Text('<', style: KTexto.titulo))),
              ),
              Expanded(child: Text(title.toUpperCase(), style: KTexto.titulo.copyWith(color: KCores.veuVioleta))),
              ...actions,
            ]),
          ),
          Expanded(child: child),
        ]),
      ),
    );
  }
}
