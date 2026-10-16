/// Itens do menu de debug para a escola do nível 3: escolher ou limpar a escola, zerar `testsOffered` (o mentor manda o
/// convite de novo na próxima abertura do mapa) e abrir os testes e o fluxo completo. Mexem no bloco `conjurer` do save,
/// como o item do nível: valem na próxima vez que o mapa abrir.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../player/conjurer_balance.dart';
import '../player/school_tests.dart';
import '../ui/school/school_flow.dart';
import '../ui/school/sealer_test.dart';
import '../ui/school/shaman_test.dart';
import '../ui/school/techno_test.dart';
import '../ui/school/test_shell.dart';
import '../ui/tema.dart';
import 'debug_env.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';

List<DebugItem> schoolItems(DebugEnv env) => [
      DebugItem(
        id: 'player.school',
        title: 'Escola do Conjurador',
        section: DebugSection.player,
        keywords: const ['escola', 'school', 'tecnomante', 'xamã', 'selador', 'testes', 'nível 3', 'familiar'],
        builder: (_) => _SchoolSave(env: env),
      ),
      DebugItem(
        id: 'player.school_tests',
        title: 'Abrir os testes de escola',
        section: DebugSection.player,
        keywords: const ['escola', 'testes', 'tecnomante', 'xamã', 'selador', 'sigilo', 'sinal', 'calma'],
        builder: (_) => const _SchoolTestsOpen(),
      ),
    ];

/// Lê o `balance.json` e o `mentor.json` dos assets (o fluxo de debug não tem GameState).
Future<(ConjurerBalance, Map<String, dynamic>)> _loadBalance() async {
  final b = jsonDecode(await rootBundle.loadString('assets/data/balance.json')) as Map<String, dynamic>;
  final mentor = jsonDecode(await rootBundle.loadString('assets/data/mentor.json')) as Map<String, dynamic>;
  return (ConjurerBalance(b), mentor);
}

class _SchoolSave extends StatefulWidget {
  const _SchoolSave({required this.env});

  final DebugEnv env;

  @override
  State<_SchoolSave> createState() => _SchoolSaveState();
}

class _SchoolSaveState extends State<_SchoolSave> {
  String _status = 'Lendo o save...';

  @override
  void initState() {
    super.initState();
    _edit((_) {});
  }

  /// Aplica [change] ao bloco `conjurer` do save e escreve de volta. Sem save ainda, não cria um.
  Future<void> _edit(void Function(Map<String, dynamic> conjurer) change) async {
    String status;
    try {
      final store = await widget.env.openSave();
      final json = await store.read();
      if (json == null) {
        status = 'Sem save ainda: abra o mapa uma vez.';
      } else {
        final c = {...(json['conjurer'] as Map<String, dynamic>? ?? const {})};
        change(c);
        await store.write({...json, 'conjurer': c});
        final school = School.parse(c['school'] as String?);
        status = 'Escola: ${school?.label ?? 'nenhuma'}. Testes oferecidos: ${(c['tests_offered'] as bool?) ?? false ? 'sim' : 'não'}. Notas: ${c['test_scores'] ?? const {}}';
      }
    } catch (_) {
      status = 'Sem disco: nada guardado.';
    }
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) => DebugColumn([
        Text(_status, style: KTexto.corpo),
        DebugWrap([
          for (final s in School.values) DebugButton(label: s.label, color: schoolColor(s), onTap: () => _edit((c) => c['school'] = s.id)),
          DebugButton(label: 'Limpar escola', color: KCores.falha, onTap: () => _edit((c) => c.remove('school'))),
        ]),
        DebugButton(label: 'Zerar convite dos testes', color: KCores.sinalCiano, onTap: () => _edit((c) => c['tests_offered'] = false)),
        DebugButton(label: 'Zerar notas dos testes', color: KCores.textoMudo, onTap: () => _edit((c) => c['test_scores'] = <String, dynamic>{})),
        const DebugNote('Vale na próxima vez que abrir o mapa. Zerar o convite faz o mentor mandar a mensagem dos testes de novo (nível 3 ou mais, sem escola).'),
      ]);
}

class _SchoolTestsOpen extends StatelessWidget {
  const _SchoolTestsOpen();

  Future<void> _open(BuildContext context, Widget Function(SchoolTestsBalance) screen) async {
    final (cb, _) = await _loadBalance();
    if (!context.mounted) return;
    final score = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => screen(cb.schoolTests)));
    if (context.mounted && score != null) debugSnack(context, 'Nota: $score');
  }

  Future<void> _flow(BuildContext context) async {
    final (cb, mentor) = await _loadBalance();
    if (!context.mounted) return;
    String line(School s) => [for (final m in mentor['familiar'] as List<dynamic>) if ((m as Map<String, dynamic>)['id'] == 'school_best_${s.id}') m['text'] as String].firstOrNull ?? '';
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SchoolFlow(
        tests: cb.schoolTests,
        cb: cb,
        initialScores: const {},
        bestLine: line,
        onRecord: (_, _) {},
        onChoose: (s) {
          debugSnack(context, 'Escolheu ${s.label} (nada gravado)');
          return true;
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => DebugColumn([
        DebugWrap([
          DebugButton(label: 'Sinal', color: KCores.sinalCiano, onTap: () => _open(context, (b) => TechnoTestScreen(balance: b.techno))),
          DebugButton(label: 'Calma', color: KCores.brasaLaranja, onTap: () => _open(context, (b) => ShamanTestScreen(balance: b.shaman))),
          DebugButton(label: 'Sigilo', color: KCores.veuVioleta, onTap: () => _open(context, (b) => SealerTestScreen(balance: b.sealer))),
        ]),
        DebugButton(label: 'Fluxo completo (sem gravar)', onTap: () => _flow(context)),
        const DebugNote('Abre as cenas sem mexer no save. Para o fluxo de verdade, use o botão da mensagem do mentor no Chat.'),
      ]);
}
