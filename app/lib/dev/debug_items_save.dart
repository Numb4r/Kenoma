/// Aba Jogador, o save: exportar, importar, migrar e apagar; e a gravação de uma chave dos Ajustes.
library;

import '../core/plural.dart';
import '../save/backup.dart';
import '../save/ksv1.dart' show SaveCorrupt;
import '../save/migrations.dart';
import '../save/save_store.dart';
import '../ui/game/game_map_screen.dart' show liveGameState;
import 'debug_env.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';

/// A palavra que o jogador digita para liberar o botão de apagar o save.
const String kDeleteWord = 'APAGAR';

/// Apaga o save de [store]: as três cópias, o legado e as sobras. Na memória (testes), zera o JSON.
Future<void> deleteSave(SaveStore store) => store.wipe();

/// Grava uma chave dos Ajustes ([value] `null` apaga): no save do mapa aberto (o mapa sobrescreveria uma gravação por
/// baixo) ou, sem mapa, no do disco.
Future<void> writeSetting(Future<SaveStore> Function() openSave, String key, Object? value) async {
  final live = liveGameState();
  if (live != null) {
    value == null ? live.settings.remove(key) : live.settings[key] = value;
    live.changed();
    return;
  }
  final store = await openSave();
  final json = {...?await store.read()};
  final settings = {...?(json['settings'] as Map<String, dynamic>?)};
  value == null ? settings.remove(key) : settings[key] = value;
  json['settings'] = settings;
  await store.write(json);
}

List<DebugEntry> saveEntries(DebugEnv env) => [
      DebugEntry(
        id: 'player.save_export',
        name: 'Exportar backup',
        tab: DebugTab.player,
        kind: DebugKind.action,
        aliases: const ['save.export'],
        keywords: const ['backup', 'compartilhar', 'arquivo', 'ksv', 'save'],
        info: 'O save inteiro num arquivo .ksv para compartilhar (sem a última posição do mapa).',
        run: (_) async {
          final raw = await (await env.openSave()).read();
          if (raw == null) throw const DebugError('Ainda não há jogo salvo.');
          await env.io.share(exportBackup(migrateSave(raw)), backupFileName(env.tools.clock.realNowUtc));
          return null;
        },
      ),
      DebugEntry(
        id: 'player.save_import',
        name: 'Importar backup',
        tab: DebugTab.player,
        kind: DebugKind.action,
        aliases: const ['save.import'],
        touchesSave: true,
        destructive: true,
        selfConfirm: true,
        keywords: const ['backup', 'restaurar', 'arquivo', 'ksv', 'save'],
        info: 'Substitui o jogo que está no aparelho pelo do arquivo, depois de mostrar o que vem nele. Reabra o mapa depois.',
        run: (c) async {
          env.requireMapClosed();
          final screen = c.screen;
          final bytes = await env.io.pick();
          if (bytes == null || !screen.mounted) return 'Nada escolhido';
          final Map<String, dynamic> backup;
          try {
            backup = readBackup(bytes);
          } on SaveCorrupt catch (e) {
            throw DebugError('Esse arquivo não serve: ${e.reason}');
          }
          final p = previewBackup(backup);
          final ok = await debugConfirm(screen,
              title: 'Substituir o jogo?',
              body: 'Nível ${p.level} · ${countText(p.creatures, 'criatura')} · grupo ${p.groupCode}.\nO jogo que está no aparelho será substituído.',
              confirm: 'Importar');
          if (ok != true) return 'Cancelado';
          await restoreBackup(await env.openSave(), backup);
          return 'Backup importado.';
        },
      ),
      DebugEntry(
        id: 'player.save_migrate',
        name: 'Migrar o save',
        tab: DebugTab.player,
        kind: DebugKind.action,
        aliases: const ['save.migrate'],
        touchesSave: true,
        keywords: const ['schema', 'versão', 'migração', 'save'],
        run: (_) async {
          env.requireMapClosed();
          final store = await env.openSave();
          final raw = await store.read();
          if (raw == null) throw const DebugError('Ainda não há jogo salvo.');
          final out = migrateSave(raw);
          await store.write(out);
          return 'Save migrado: schema ${raw['schema_version'] ?? 1} → ${out['schema_version']}.';
        },
      ),
      DebugEntry(
        id: 'player.save_delete',
        name: 'Apagar o save',
        tab: DebugTab.player,
        kind: DebugKind.action,
        aliases: const ['save.delete'],
        touchesSave: true,
        destructive: true,
        confirmWord: kDeleteWord,
        keywords: const ['deletar', 'resetar', 'zerar', 'limpar', 'save'],
        info: 'Apaga o jogo inteiro deste aparelho, sem volta. Exporte um backup antes.',
        run: (_) async {
          env.requireMapClosed();
          await deleteSave(await env.openSave());
          return 'Save apagado.';
        },
      ),
    ];
