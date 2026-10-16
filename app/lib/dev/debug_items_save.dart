/// Itens das seções Assinaturas, Desempenho e Save: identidade (player_id, log de versões, época), latência do toque
/// e as operações sobre o save (exportar, importar, migrar, apagar).
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../save/backup.dart';
import '../save/ksv1.dart' show SaveCorrupt;
import '../save/ksv_save_store.dart';
import '../save/migrations.dart';
import '../save/save_store.dart';
import '../ui/tema.dart';
import 'debug_env.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';
import 'identity_section.dart';
import 'tap_latency.dart';

/// A palavra que o jogador digita para liberar o botão de apagar o save.
const String kDeleteWord = 'APAGAR';

/// Apaga o save de [store]: as três cópias, o legado e as sobras. Na memória (testes), zera o JSON.
Future<void> deleteSave(SaveStore store) async {
  if (store is MemorySaveStore) {
    store.json = null;
    return;
  }
  if (store is KsvSaveStore) {
    for (final f in [...store.copies, store.legacy, File('${store.current.path}.bad'), File('${store.current.path}.tmp')]) {
      if (await f.exists()) await f.delete();
    }
  }
}

List<DebugItem> signatureItems(DebugEnv env) => [
      DebugItem(
        id: 'sign.identity',
        title: 'Identidade e época',
        section: DebugSection.signatures,
        keywords: const ['player_id', 'versions_seen', 'log de versões', 'época', 'fundador', 'grupo', 'seed', 'schema', 'cadeia', 'hash'],
        builder: (_) => FutureBuilder<SaveStore>(
          future: env.openSave(),
          builder: (context, snap) => snap.hasData
              ? IdentitySection(clock: env.tools.clock, store: snap.data)
              : snap.hasError
                  ? DebugNote('Erro: ${snap.error}')
                  : const DebugNote('Lendo o save...'),
        ),
      ),
    ];

List<DebugItem> performanceItems() => [
      DebugItem(
        id: 'perf.tap_latency',
        title: 'Latência do toque',
        section: DebugSection.performance,
        keywords: const ['fps', 'sonda', 'mediana', 'toque', 'quadro'],
        builder: (_) => StatefulBuilder(
          builder: (context, setState) {
            final t = TapLatency.instance;
            return DebugColumn([
              Text(
                t.samples.isEmpty
                    ? 'Toque em algo e atualize.'
                    : 'Mediana ${t.median!.toStringAsFixed(0)} ms · pior ${t.worst!.toStringAsFixed(0)} ms (${t.samples.length} toques).',
                style: KTexto.corpoPequeno,
              ),
              DebugWrap([
                DebugButton(label: 'Atualizar', color: KCores.textoMudo, onTap: () => setState(() {})),
                DebugButton(label: 'Zerar', color: KCores.textoMudo, onTap: () => setState(t.clear)),
              ]),
            ]);
          },
        ),
      ),
    ];

List<DebugItem> saveItems(DebugEnv env) => [
      DebugItem(
        id: 'save.export',
        title: 'Exportar',
        section: DebugSection.save,
        keywords: const ['backup', 'compartilhar', 'arquivo', 'ksv'],
        builder: (_) => Builder(builder: (context) => DebugButton(label: 'Exportar backup', color: KCores.sinalCiano, onTap: () => _export(context, env))),
      ),
      DebugItem(
        id: 'save.import',
        title: 'Importar',
        section: DebugSection.save,
        keywords: const ['backup', 'restaurar', 'arquivo', 'ksv'],
        builder: (_) => Builder(
          builder: (context) => DebugColumn([
            const DebugNote('Substitui o jogo que está no aparelho. Reabra o mapa depois.'),
            DebugButton(label: 'Importar backup', color: KCores.brasaLaranja, onTap: () => _import(context, env)),
          ]),
        ),
      ),
      DebugItem(
        id: 'save.migrate',
        title: 'Migrar',
        section: DebugSection.save,
        keywords: const ['schema', 'versão', 'migração'],
        builder: (_) => Builder(builder: (context) => DebugButton(label: 'Migrar save', onTap: () => _migrate(context, env))),
      ),
      DebugItem(
        id: 'save.delete',
        title: 'Apagar',
        section: DebugSection.save,
        keywords: const ['deletar', 'resetar', 'zerar', 'limpar'],
        builder: (_) => DeleteSaveBox(env: env),
      ),
    ];

Future<void> _export(BuildContext context, DebugEnv env) async {
  final say = debugSayer(context);
  try {
    final raw = await (await env.openSave()).read();
    if (raw == null) return say('Ainda não há jogo salvo.');
    await env.io.share(exportBackup(migrateSave(raw)), backupFileName(env.tools.clock.realNowUtc));
  } catch (e) {
    say('Não consegui exportar: $e');
  }
}

Future<void> _import(BuildContext context, DebugEnv env) async {
  final say = debugSayer(context);
  final nav = Navigator.of(context);
  try {
    final bytes = await env.io.pick();
    if (bytes == null || !nav.mounted) return;
    final backup = readBackup(bytes);
    final p = previewBackup(backup);
    final ok = await showDialog<bool>(
      context: nav.context,
      builder: (c) => AlertDialog(
        backgroundColor: KCores.superficie1,
        title: const Text('SUBSTITUIR O JOGO?', style: KTexto.titulo),
        content: Text('Nível ${p.level} · ${p.creatures} criaturas · grupo ${p.groupCode}.\nO jogo que está no aparelho será substituído.', style: KTexto.corpo),
        actions: [
          DebugButton(label: 'Cancelar', color: KCores.textoMudo, onTap: () => Navigator.pop(c, false)),
          DebugButton(label: 'Importar', color: KCores.brasaLaranja, onTap: () => Navigator.pop(c, true)),
        ],
      ),
    );
    if (ok != true) return;
    await restoreBackup(await env.openSave(), backup);
    say('Backup importado.');
  } on SaveCorrupt catch (e) {
    say('Esse arquivo não serve: ${e.reason}');
  } catch (e) {
    say('Erro: $e');
  }
}

Future<void> _migrate(BuildContext context, DebugEnv env) async {
  final say = debugSayer(context);
  try {
    final store = await env.openSave();
    final raw = await store.read();
    if (raw == null) return say('Ainda não há jogo salvo.');
    final out = migrateSave(raw);
    await store.write(out);
    say('Save migrado: schema ${raw['schema_version'] ?? 1} → ${out['schema_version']}.');
  } catch (e) {
    say('Erro: $e');
  }
}

/// Apagar o save pede confirmação: o botão só habilita com [kDeleteWord] digitado.
class DeleteSaveBox extends StatefulWidget {
  const DeleteSaveBox({required this.env, super.key});

  final DebugEnv env;

  @override
  State<DeleteSaveBox> createState() => _DeleteSaveBoxState();
}

class _DeleteSaveBoxState extends State<DeleteSaveBox> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final say = debugSayer(context);
    try {
      await deleteSave(await widget.env.openSave());
      _text.clear();
      if (mounted) setState(() {});
      say('Save apagado.');
    } catch (e) {
      say('Erro: $e');
    }
  }

  @override
  Widget build(BuildContext context) => DebugColumn([
        const DebugNote('Apaga o jogo inteiro deste aparelho, sem volta. Exporte um backup antes. Digite $kDeleteWord para liberar o botão.', color: KCores.falha),
        DebugField('Digite $kDeleteWord', _text, onChanged: (_) => setState(() {})),
        DebugButton(label: 'Apagar save', color: KCores.falha, enabled: _text.text == kDeleteWord, onTap: _delete),
      ]);
}
