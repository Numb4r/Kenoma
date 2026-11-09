/// Operações puras sobre o save para a "Rua viva" do menu de debug: zerar a recarga do Radar. O item que a chama está em
/// `debug_items_world.dart`.
library;

import '../save/migrations.dart';

/// Zera a recarga do Radar e esquece os Ocultos que ele tinha revelado.
Map<String, dynamic> resetRadar(Map<String, dynamic> save) => {
      ...migrateSave(save),
      'radar': {'last_utc': 0, 'revealed': <String, dynamic>{}},
    };
