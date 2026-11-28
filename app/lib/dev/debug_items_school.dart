/// Aba Jogador, a escola do nível 3: escolher ou limpar a escola, zerar `testsOffered` (o mentor manda o convite de novo na
/// próxima abertura do mapa) e as notas, e abrir os testes e o fluxo completo. Mexem no bloco `conjurer` do save: valem
/// na próxima vez que o mapa abrir.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../player/conjurer_balance.dart';
import '../ui/school/school_flow.dart';
import '../ui/school/sealer_test.dart';
import '../ui/school/shaman_test.dart';
import '../ui/school/techno_test.dart';
import 'debug_env.dart';
import 'debug_registry.dart';

/// Lê o `balance.json` e o `mentor.json` dos assets (o fluxo de debug não tem GameState).
Future<(ConjurerBalance, Map<String, dynamic>)> _loadBalance() async {
  final b = jsonDecode(await rootBundle.loadString('assets/data/balance.json')) as Map<String, dynamic>;
  final mentor = jsonDecode(await rootBundle.loadString('assets/data/mentor.json')) as Map<String, dynamic>;
  return (ConjurerBalance(b), mentor);
}

/// O que o save diz da escola agora (a tela e o `cmd` leem; [_SchoolState.refresh] atualiza depois de cada mudança).
class _SchoolState {
  String text = 'Escola: abra a aba de novo para ler o save.';
  String? school;

  Future<void> refresh(DebugEnv env) async {
    try {
      final json = await (await env.openSave()).read();
      final c = (json?['conjurer'] as Map<String, dynamic>?) ?? const {};
      school = c['school'] as String?;
      text = json == null ? 'Sem save ainda: abra o mapa uma vez.' : _describe(c);
    } catch (_) {
      text = 'Sem disco: nada guardado.';
    }
  }
}

String _describe(Map<String, dynamic> c) {
  final school = School.parse(c['school'] as String?);
  return 'Escola: ${school?.label ?? 'nenhuma'}. Testes oferecidos: ${(c['tests_offered'] as bool?) ?? false ? 'sim' : 'não'}. Notas: ${c['test_scores'] ?? const {}}';
}

List<DebugEntry> schoolEntries(DebugEnv env) {
  final st = _SchoolState();

  /// Aplica [change] ao bloco `conjurer` do save. Sem save ainda, não cria um.
  Future<String> edit(void Function(Map<String, dynamic> conjurer) change) async {
    await env.editSave((json) {
      final c = {...(json['conjurer'] as Map<String, dynamic>? ?? const {})};
      change(c);
      return {...json, 'conjurer': c};
    });
    await st.refresh(env);
    return st.text;
  }

  DebugEntry entry(String id, String name, String info, void Function(Map<String, dynamic> c) change, {bool destructive = false}) => DebugEntry(
        id: 'player.$id',
        name: name,
        tab: DebugTab.player,
        kind: DebugKind.action,
        touchesSave: true,
        destructive: destructive,
        keywords: const ['escola', 'testes', 'convite', 'notas'],
        info: info,
        run: (_) => edit(change),
      );

  return [
    DebugEntry(
      id: 'player.school',
      name: 'Escola do Conjurador',
      tab: DebugTab.player,
      kind: DebugKind.choice,
      touchesSave: true,
      keywords: const ['escola', 'school', 'tecnomante', 'xamã', 'selador', 'nível 3', 'familiar'],
      info: 'Vale na próxima vez que abrir o mapa.',
      options: [for (final s in School.values) DebugOption(s.id, s.label)],
      load: () => st.refresh(env),
      autoLoad: true,
      read: () => st.school,
      status: () => st.text,
      run: (c) => edit((conj) => conj['school'] = c.value),
    ),
    entry('school_clear', 'Limpar a escola', 'O Conjurador volta a não ter escola.', (c) => c.remove('school'), destructive: true),
    entry('school_invite', 'Zerar o convite dos testes', 'O mentor manda a mensagem dos testes de novo na próxima abertura do mapa (nível 3 ou mais, sem escola).', (c) => c['tests_offered'] = false),
    entry('school_scores', 'Zerar as notas dos testes', 'Esquece as notas dos três testes.', (c) => c['test_scores'] = <String, dynamic>{}, destructive: true),
    DebugEntry(
      id: 'player.school_tests',
      name: 'Abrir um teste de escola',
      tab: DebugTab.player,
      kind: DebugKind.action,
      keywords: const ['escola', 'testes', 'tecnomante', 'xamã', 'selador', 'sigilo', 'sinal', 'calma', 'fluxo'],
      info: 'Abre as cenas sem mexer no save. Para o fluxo de verdade, use o botão da mensagem do mentor no Chat.',
      params: const [DebugParam('test', 'teste', options: [DebugOption('sinal', 'Sinal'), DebugOption('calma', 'Calma'), DebugOption('sigilo', 'Sigilo'), DebugOption('fluxo', 'Fluxo completo')], fallback: 'sinal')],
      run: (c) async {
        final screen = c.screen;
        final (cb, mentor) = await _loadBalance();
        if (!screen.mounted) return null;
        final nav = Navigator.of(screen);
        if (c['test'] == 'fluxo') {
          String line(School s) => [for (final m in mentor['familiar'] as List<dynamic>) if ((m as Map<String, dynamic>)['id'] == 'school_best_${s.id}') m['text'] as String].firstOrNull ?? '';
          unawaited(nav.push(MaterialPageRoute<void>(
            builder: (_) => SchoolFlow(tests: cb.schoolTests, cb: cb, initialScores: const {}, bestLine: line, onRecord: (_, _) {}, onChoose: (_) => true),
          )));
          return 'Fluxo completo (nada gravado)';
        }
        final b = cb.schoolTests;
        unawaited(nav.push<int>(MaterialPageRoute(
          builder: (_) => switch (c['test']) {
            'calma' => ShamanTestScreen(balance: b.shaman),
            'sigilo' => SealerTestScreen(balance: b.sealer),
            _ => TechnoTestScreen(balance: b.techno),
          },
        )));
        return 'Teste ${c['test']}';
      },
    ),
  ];
}
