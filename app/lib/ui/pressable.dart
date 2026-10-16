/// Toque com retorno na hora: o filho afunda 2 dp ao encostar o dedo e volta em 80 ms. O retorno não espera o resultado
/// do toque (abrir tela, salvar): ele aparece no primeiro quadro depois do dedo.
library;

import 'package:flutter/material.dart' show AnimationStyle;
import 'package:flutter/widgets.dart';

const Duration pressDuration = Duration(milliseconds: 80);
const double pressDepth = 2;

/// As folhas de baixo (celular, preparo do encontro) deslizam em 200 ms ao abrir e ao fechar.
const AnimationStyle sheetSlide = AnimationStyle(duration: Duration(milliseconds: 200), reverseDuration: Duration(milliseconds: 200));

class Pressable extends StatefulWidget {
  const Pressable({required this.child, this.onTap, this.onDoubleTap, super.key});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: AnimatedContainer(
          duration: pressDuration,
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _down ? pressDepth : 0, 0),
          child: widget.child,
        ),
      );
}
