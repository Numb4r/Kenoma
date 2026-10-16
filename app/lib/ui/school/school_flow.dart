/// A sequência da escolha de escola no nível 3: os três testes (qualquer ordem, repetíveis), depois a tela de escolha com o
/// comentário do Familiar sobre o teste em que o jogador foi melhor, a descrição de cada escola e o botão de confirmar, que
/// avisa que a escolha é definitiva até o nível 30. Abre pelo botão da mensagem do mentor no Chat e pelo menu de debug.
library;

import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../../player/conjurer_balance.dart';
import '../../player/game_state.dart';
import '../../player/school_tests.dart';
import '../menu/phone_shell.dart';
import '../tema.dart';
import 'sealer_test.dart';
import 'shaman_test.dart';
import 'techno_test.dart';
import 'test_shell.dart';

/// Abre o fluxo ligado ao [state]: as notas e a escolha vão para o save, e o Familiar comenta o melhor teste.
Future<void> openSchoolFlow(BuildContext context, GameState state, GameData data) => Navigator.of(context).push(phoneRoute(SchoolFlow(
      tests: state.cb.schoolTests,
      cb: state.cb,
      initialScores: state.conjurer.testScores,
      bestLine: (s) => data.mentor.byId('school_best_${s.id}')?.text ?? '',
      onRecord: state.recordSchoolTest,
      onChoiceShown: (best) => state.recordEvent('school_best_${best.id}', '', 1),
      onChoose: state.chooseSchool,
    )));

String schoolTestName(School s) => switch (s) {
      School.technomancer => 'Estabilizar um sinal',
      School.shaman => 'Acalmar um Eco arisco',
      School.sealer => 'Traçar um sigilo',
    };

/// A descrição curta de cada escola, com os números do `balance.json`.
String schoolBlurb(School s, ConjurerBalance cb) => switch (s) {
      School.technomancer => 'Trabalha com o sinal. A tolerância da sintonia fica ${_pct(cb.techToleranceMult)} maior. Mais tarde fabrica Artificiais e instala Implantes.',
      School.shaman => 'Conversa com os lugares. Ecos Ariscos não fogem de você e a Aura ganha +${_m(cb.shamanAuraBonusM)} m. Mais tarde vincula Guardiões de Lugar.',
      School.sealer => 'Costura o Véu. O progresso da sintonia sobe ${_pct(cb.sealerProgressMult)} mais rápido. Mais tarde cria Quimeras e Relicários.',
    };

String _pct(double mult) => '${((mult - 1) * 100).round()}%';
String _m(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toString();

class SchoolFlow extends StatefulWidget {
  const SchoolFlow({
    required this.tests,
    required this.cb,
    required this.initialScores,
    required this.bestLine,
    required this.onRecord,
    required this.onChoose,
    this.onChoiceShown,
    super.key,
  });

  final SchoolTestsBalance tests;
  final ConjurerBalance cb;
  final Map<String, int> initialScores;

  /// O comentário do Familiar sobre o teste da escola em que o jogador foi melhor.
  final String Function(School best) bestLine;
  final void Function(School school, int score) onRecord;
  final bool Function(School school) onChoose;

  /// A tela de escolha apareceu com a escola [best] em primeiro (o Familiar também comenta no Chat).
  final void Function(School best)? onChoiceShown;

  @override
  State<SchoolFlow> createState() => _SchoolFlowState();
}

class _SchoolFlowState extends State<SchoolFlow> {
  late final Map<String, int> _scores = {...widget.initialScores};
  bool _choosing = false;
  School? _picked;

  bool get _allDone => School.values.every((s) => _scores.containsKey(s.id));

  School? get _best {
    School? best;
    var top = -1;
    for (final s in School.values) {
      final v = _scores[s.id];
      if (v != null && v > top) {
        best = s;
        top = v;
      }
    }
    return best;
  }

  Future<void> _runTest(School s) async {
    final screen = switch (s) {
      School.technomancer => TechnoTestScreen(balance: widget.tests.techno),
      School.shaman => ShamanTestScreen(balance: widget.tests.shaman),
      School.sealer => SealerTestScreen(balance: widget.tests.sealer),
    };
    final score = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => screen));
    if (score == null || !mounted) return;
    widget.onRecord(s, score);
    setState(() => _scores[s.id] = score);
  }

  void _toChoice() {
    final best = _best;
    if (best != null) widget.onChoiceShown?.call(best);
    setState(() => _choosing = true);
  }

  Future<void> _confirm(School s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KCores.superficie1,
        title: Text('Ser ${s.label}?', style: KTexto.titulo.copyWith(color: schoolColor(s))),
        content: const Text('A escolha é definitiva até o nível 30.', style: KTexto.corpo),
        actions: [
          TextButton(key: const Key('school-cancel'), onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR', style: KTexto.rotulo)),
          TextButton(key: const Key('school-confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text('CONFIRMAR', style: KTexto.rotulo.copyWith(color: schoolColor(s)))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    widget.onChoose(s);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PhoneScreen(
        title: _choosing ? 'Escolha' : 'Testes',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(KEspaco.s2, KEspaco.s1, KEspaco.s2, KEspaco.s4),
          children: _choosing ? _choice() : _testList(),
        ),
      );

  List<Widget> _testList() => [
        const Text('Faça os três testes, na ordem que quiser. Dá para repetir antes de escolher.', style: KTexto.corpoPequeno),
        const SizedBox(height: KEspaco.s2),
        for (final s in School.values) ...[
          _Card(
            key: Key('school-test-${s.id}'),
            color: schoolColor(s),
            title: schoolTestName(s),
            body: _scores[s.id] == null ? 'Ainda não feito.' : 'Sua nota: ${_scores[s.id]}',
            action: SchoolButton(label: _scores.containsKey(s.id) ? 'Repetir' : 'Fazer', color: schoolColor(s), onTap: () => _runTest(s)),
          ),
          const SizedBox(height: KEspaco.s2),
        ],
        Align(alignment: Alignment.centerRight, child: SchoolButton(label: 'Escolher escola', onTap: _allDone ? _toChoice : null)),
      ];

  List<Widget> _choice() {
    final best = _best;
    return [
      if (best != null)
        Container(
          key: const Key('school-familiar-line'),
          padding: const EdgeInsets.all(KEspaco.s2),
          decoration: BoxDecoration(color: KCores.superficie1, border: Border.all(color: KCores.sinalCiano, width: kContornoDp)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FAMILIAR', style: KTexto.rotulo.copyWith(color: KCores.sinalCiano)),
            const SizedBox(height: KEspaco.s1),
            Text(widget.bestLine(best), style: KTexto.corpo),
          ]),
        ),
      const SizedBox(height: KEspaco.s2),
      for (final s in School.values) ...[
        GestureDetector(
          key: Key('school-pick-${s.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _picked = s),
          child: _Card(color: schoolColor(s), title: s.label, body: schoolBlurb(s, widget.cb), selected: _picked == s, note: 'Nota no teste: ${_scores[s.id] ?? '-'}'),
        ),
        const SizedBox(height: KEspaco.s2),
      ],
      const Text('A escolha é definitiva até o nível 30.', style: KTexto.corpoPequeno),
      const SizedBox(height: KEspaco.s2),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        SchoolButton(label: 'Voltar', color: KCores.textoMudo, onTap: () => setState(() => _choosing = false)),
        SchoolButton(label: 'Confirmar', color: _picked == null ? KCores.textoMudo : schoolColor(_picked!), onTap: _picked == null ? null : () => _confirm(_picked!)),
      ]),
    ];
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.color, required this.title, required this.body, this.action, this.note, this.selected = false, super.key});

  final Color color;
  final String title, body;
  final String? note;
  final Widget? action;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(KEspaco.s2),
        decoration: BoxDecoration(color: selected ? KCores.superficie2 : KCores.superficie1, border: Border.all(color: selected ? color : KCores.contorno, width: kContornoDp)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title.toUpperCase(), style: KTexto.rotulo.copyWith(color: color)),
              const SizedBox(height: 4),
              Text(body, style: KTexto.corpo),
              if (note != null) Text(note!, style: KTexto.corpoPequeno),
            ]),
          ),
          if (action != null) ...[const SizedBox(width: KEspaco.s2), action!],
        ]),
      );
}
