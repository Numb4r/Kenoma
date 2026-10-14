/// O que o jogador vê e alcança no mundo agora: os spawns ao redor que ainda não foram coletados, as
/// Fagulhas que a Aura pega sozinha e o toque em cada coisa. Dart puro: o mapa só desenha o que sai
/// daqui e repassa os toques.
library;

import '../core/tiles.dart';
import 'tracker.dart';
import '../player/game_state.dart';
import 'spawn_field.dart';

/// O que um toque num spawn faz.
enum TouchResult { collected, encounter, tooFar, auto }

class WorldView {
  WorldView({
    required this.field,
    required this.state,
    required this.auraM,
    required this.viewM,
    required this.itemName,
    this.onMessage,
  });

  final SpawnField field;
  final GameState state;

  /// Raio da Aura e raio de visão, em metros, do `balance.json`.
  final double auraM;
  final double viewM;

  /// Nome do item na interface.
  final String Function(String id) itemName;

  /// Aviso para o jogador ("+1 Pó de Essência de Fogo").
  final void Function(String message)? onMessage;

  /// Os spawns visíveis, ainda não coletados. Atualizados por [refresh].
  List<WorldSpawn> spawns = const [];

  double _px = 0, _py = 0, _mpc = 1;
  bool _hasPlayer = false;

  /// Metros do jogador até o spawn.
  double distanceM(WorldSpawn s) => s.distanceM(_px, _py, _mpc);

  /// Os Ecos fora da tela que o rastreador mostra: até [max], a até [trackerM] metros.
  List<TrackedEco> tracked({required bool Function(WorldSpawn) offScreen, required double trackerM, required int max}) => !_hasPlayer
      ? const []
      : trackEcos(spawns: spawns, playerX: _px, playerY: _py, metersPerCell21: _mpc, trackerM: trackerM, offScreen: offScreen, max: max);

  bool inAura(WorldSpawn s) => _hasPlayer && distanceM(s) <= auraM;

  /// Recalcula os spawns em volta de ([lat], [lon]) em [tUtc] e coleta as Fagulhas dentro da Aura.
  /// Devolve as Fagulhas coletadas agora.
  List<WorldSpawn> refresh({required double lat, required double lon, required int tUtc}) {
    final (px, py) = latLonToTileFraction(lat, lon, biomeZoom);
    _px = px;
    _py = py;
    _mpc = metersPerCell(lat);
    _hasPlayer = true;
    final all = field.around(lat: lat, lon: lon, tUtc: tUtc, radiusM: viewM, playerLevel: state.playerLevel);
    final collected = <WorldSpawn>[];
    for (final s in all) {
      if (state.isDone(s.uid) || !s.isSpark || !inAura(s)) continue;
      state.add(s.entryId, s.quantity);
      state.markDone(s.uid, tUtc);
      collected.add(s);
      onMessage?.call('+${s.quantity} ${itemName(s.entryId)}');
    }
    spawns = [for (final s in all) if (!state.isDone(s.uid)) s];
    return collected;
  }

  /// Toque num spawn. Material dentro da Aura é coletado aqui; Eco dentro da Aura abre o encontro.
  TouchResult touch(WorldSpawn s, int tUtc) {
    if (s.isSpark) return TouchResult.auto;
    if (!inAura(s)) return TouchResult.tooFar;
    if (s.isEco) return TouchResult.encounter;
    state.add(s.entryId, s.quantity);
    state.markDone(s.uid, tUtc);
    spawns = [for (final o in spawns) if (o.uid != s.uid) o];
    onMessage?.call('+${s.quantity} ${itemName(s.entryId)}');
    return TouchResult.collected;
  }

  /// Tira o spawn da vista (o Eco foi capturado ou fugiu).
  void remove(WorldSpawn s) => spawns = [for (final o in spawns) if (o.uid != s.uid) o];
}
