/// O que os itens do menu de debug compartilham: as ferramentas de dev, o estado da sintonia, onde mora o save e o
/// centro do mapa livre. Quem monta o menu cria um [DebugEnv] e passa a `buildDefaultRegistry`.
library;

import 'package:flutter/widgets.dart';

import '../save/backup_io.dart';
import '../save/ksv_save_store.dart';
import '../save/save_store.dart';
import '../world/places.dart';
import 'debug_capture.dart';
import 'dev_tools.dart';

class DebugEnv {
  DebugEnv({required this.tools, required this.capture, this.saveStore, this.io = const DeviceBackupIo()});

  final DevTools tools;
  final CaptureDebug capture;
  final BackupIo io;
  final SaveStore? saveStore;

  /// Centro do mapa livre e da névoa revelada. O padrão é a Unicamp.
  final lat = TextEditingController(text: kUnicamp.$1.toString());
  final lon = TextEditingController(text: kUnicamp.$2.toString());

  /// O save: o injetado (testes) ou o do app nos documentos.
  Future<SaveStore> openSave() async => saveStore ?? await KsvSaveStore.inDocuments();

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

  (double, double) center() => (double.tryParse(lat.text.trim().replaceAll(',', '.')) ?? kUnicamp.$1, double.tryParse(lon.text.trim().replaceAll(',', '.')) ?? kUnicamp.$2);

  void dispose() {
    lat.dispose();
    lon.dispose();
    capture.dispose();
  }
}

/// Lê uma coordenada digitada (vírgula decimal vale). `null` se não for número ou estiver fora do alcance.
(double, double)? parseCoord(String lat, String lon) {
  final a = double.tryParse(lat.trim().replaceAll(',', '.'));
  final b = double.tryParse(lon.trim().replaceAll(',', '.'));
  if (a == null || b == null || a.abs() > 85 || b.abs() > 180) return null;
  return (a, b);
}
