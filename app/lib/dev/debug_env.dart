/// O que as entradas do menu de debug compartilham: as ferramentas de dev, o estado da sintonia e onde mora o save. Quem
/// monta o menu cria um [DebugEnv] e passa a `buildDefaultRegistry`.
library;


import '../save/backup_io.dart';
import '../save/ksv_save_store.dart';
import '../save/save_store.dart';
import '../ui/game/game_map_screen.dart' show liveGameState;
import 'debug_capture.dart';
import 'debug_prefs.dart';
import 'debug_registry.dart';
import 'dev_tools.dart';

class DebugEnv {
  DebugEnv({required this.tools, required this.capture, this.saveStore, this.io = const DeviceBackupIo()});

  final DevTools tools;
  final CaptureDebug capture;
  final BackupIo io;
  final SaveStore? saveStore;

  /// As preferências do menu (o último "Criar criatura"). O menu põe aqui quando termina de carregar; `null` antes disso.
  DebugPrefs? prefs;

  /// O save: o injetado (testes) ou o do app nos documentos.
  Future<SaveStore> openSave() async => saveStore ?? await KsvSaveStore.inDocuments();

  /// O save em disco só se edita com o mapa fechado: o mapa aberto grava o dele por cima.
  void requireMapClosed() {
    if (liveGameState() != null) throw const DebugError('feche o mapa antes (Menu de debug): ele grava o save por cima');
  }

  /// Lê o save, aplica [change] e grava. Sem jogo salvo, ou com o mapa aberto (ele gravaria por cima), é erro de uso.
  Future<void> editSave(Map<String, dynamic> Function(Map<String, dynamic> save) change) async {
    requireMapClosed();
    final store = await openSave();
    final raw = await store.read();
    if (raw == null) throw const DebugError('Ainda não há jogo salvo: abra o mapa uma vez.');
    await store.write(change(raw));
  }

  /// Lê o nível forçado do save para o [DevTools] (a etiqueta DEBUG e o item do nível usam). Sem disco, fica 0.
  Future<void> loadLevelOverride() async {
    try {
      final json = await (await openSave()).read();
      final v1 = (json?['schema_version'] ?? 1) == 1;
      final level = (json?['level_override'] as int?) ?? (v1 ? (json?['player_level'] as int?) : null);
      if (level != null) tools.setLevelOverride(level.clamp(0, 15));
    } catch (_) {
      // sem pasta de documentos (testes): vale só na memória
    }
  }

  void dispose() {
    capture.dispose();
  }
}
