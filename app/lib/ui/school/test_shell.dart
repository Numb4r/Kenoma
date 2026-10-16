/// A moldura comum das três cenas de teste de escola: abertura (o que fazer), a cena e o resultado com a nota. Fecha com
/// `Navigator.pop(nota)`; sair no meio fecha com `null` e a nota não conta. Só desenho: a regra de nota mora em `player/school_tests.dart`.
library;

import 'package:flutter/material.dart';

import '../../player/conjurer_balance.dart';
import '../pressable.dart';
import '../tema.dart';

/// A cor da escola (docs/GDD.md, "Escolas de Conjuração").
Color schoolColor(School s) => switch (s) {
      School.technomancer => KCores.sinalCiano,
      School.shaman => KCores.brasaLaranja,
      School.sealer => KCores.veuVioleta,
    };

/// Botão de pixel das telas de escola.
class SchoolButton extends StatelessWidget {
  const SchoolButton({required this.label, required this.onTap, this.color = KCores.veuVioleta, super.key});

  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Pressable(
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            constraints: const BoxConstraints(minHeight: kToqueMinDp, minWidth: 120),
            padding: const EdgeInsets.symmetric(horizontal: KEspaco.s2, vertical: KEspaco.s1),
            decoration: BoxDecoration(color: KCores.superficie2, border: Border.all(color: color, width: kContornoDp), boxShadow: KSombra.pixel),
            child: Text(label.toUpperCase(), style: KTexto.rotulo.copyWith(color: color)),
          ),
        ),
      );
}

class SchoolTestShell extends StatefulWidget {
  const SchoolTestShell({required this.school, required this.title, required this.intro, required this.scene, super.key});

  final School school;
  final String title;
  final String intro;

  /// A cena em andamento; chama `finish(nota)` quando acaba.
  final Widget Function(void Function(int score) finish) scene;

  @override
  State<SchoolTestShell> createState() => _SchoolTestShellState();
}

enum _Phase { intro, run, result }

class _SchoolTestShellState extends State<SchoolTestShell> {
  _Phase _phase = _Phase.intro;
  int _score = 0;

  @override
  Widget build(BuildContext context) {
    final color = schoolColor(widget.school);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0812), // o mapa escurecido ao fundo
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(KEspaco.s1, KEspaco.s1, KEspaco.s2, KEspaco.s1),
            child: Row(children: [
              GestureDetector(
                key: const Key('school-test-back'),
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox(width: kToqueMinDp, height: kToqueMinDp, child: Center(child: Text('<', style: KTexto.titulo))),
              ),
              Expanded(child: Text(widget.title.toUpperCase(), style: KTexto.titulo.copyWith(color: color))),
            ]),
          ),
          Expanded(
            child: switch (_phase) {
              _Phase.intro => Padding(
                  padding: const EdgeInsets.all(KEspaco.s3),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(widget.intro, style: KTexto.corpo, textAlign: TextAlign.center),
                    const SizedBox(height: KEspaco.s4),
                    SchoolButton(label: 'Começar', color: color, onTap: () => setState(() => _phase = _Phase.run)),
                  ]),
                ),
              _Phase.run => widget.scene((score) => setState(() {
                    _score = score.clamp(0, 100);
                    _phase = _Phase.result;
                  })),
              _Phase.result => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('NOTA', style: KTexto.rotulo),
                    Text('$_score', key: const Key('school-test-score'), style: KTexto.display.copyWith(color: color)),
                    const SizedBox(height: KEspaco.s4),
                    SchoolButton(label: 'Concluir', color: color, onTap: () => Navigator.of(context).pop(_score)),
                  ]),
                ),
            },
          ),
        ]),
      ),
    );
  }
}
