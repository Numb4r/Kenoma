/// O que a tela do jogo liga: o mundo em camadas, o fallback e os pacotes baixáveis, com um passo só. Sem fallback ou sem
/// disco, o jogo segue com o que há.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier;

import '../net/region_manager.dart';
import 'fallback_service.dart';
import 'geo_fix.dart';
import 'layered_world.dart';

/// Chave em `GameState.settings`: a fala do Familiar sobre o piso já saiu.
const kFloorSeenSetting = 'map_floor_seen';

/// O evento que libera a fala do Familiar (`floor_f01` em `mentor.json`).
const kFloorSeenEvent = 'map_floor_seen';

class MapLayers {
  MapLayers({required this.world, this.fallback, this.regions});

  final LayeredWorld world;
  final FallbackService? fallback;
  final RegionManager? regions;

  /// De onde vem o mapa sob o jogador: o selo do HUD e a fala do Familiar leem daqui.
  final source = ValueNotifier<MapSourceKind>(MapSourceKind.pack);

  void noteFix(GeoFix? fix) {
    if (fix != null) fallback?.noteFix(fix);
  }

  /// Um passo por segundo, com a posição do jogador.
  Future<void> tick(double lat, double lon) async {
    source.value = world.sourceAt(lat, lon);
    await Future.wait([if (fallback != null) fallback!.tick(lat, lon), if (regions != null) regions!.tick(lat, lon)]);
  }

  void dispose() {
    source.dispose();
    regions?.dispose();
  }
}
