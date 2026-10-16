/// Operações puras sobre o save para a "Rua viva" do menu de debug: revelar ou limpar a névoa e zerar a recarga do
/// Radar. Os itens que as chamam estão em `debug_items_world.dart`.
library;

import '../core/tiles.dart';
import '../save/migrations.dart';
import '../world/fog.dart';

/// Revela a névoa num círculo de [radiusM] em torno de ([lat], [lon]) no conjunto de debug (que dá para limpar). Devolve
/// o save novo. Puro: o menu só lê e grava.
Map<String, dynamic> revealDebugFog(Map<String, dynamic> save, double lat, double lon, double radiusM) {
  final out = migrateSave(save);
  final fog = FogState.fromJson(out['fog'] as Map<String, dynamic>?);
  final (x, y) = latLonToTileFraction(lat, lon, biomeZoom);
  fog.reveal(x, y, radiusM, metersPerCell(lat), debug: true);
  return {...out, 'fog': fog.toJson()};
}

/// Apaga só a névoa que veio do simulador ou do debug: o caminho real fica.
Map<String, dynamic> clearDebugFog(Map<String, dynamic> save) {
  final out = migrateSave(save);
  final fog = FogState.fromJson(out['fog'] as Map<String, dynamic>?)..clearDebug();
  return {...out, 'fog': fog.toJson()};
}

/// Zera a recarga do Radar e esquece os Ocultos que ele tinha revelado.
Map<String, dynamic> resetRadar(Map<String, dynamic> save) => {
      ...migrateSave(save),
      'radar': {'last_utc': 0, 'revealed': <String, dynamic>{}},
    };
