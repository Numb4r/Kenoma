/// O que o jogador vê e alcança no mundo agora: os spawns ao redor que ainda não foram coletados, as
/// Fagulhas que a Aura pega sozinha e o toque em cada coisa. Dart puro: o mapa só desenha o que sai
/// daqui e repassa os toques.
library;

import 'dart:math' as math;

import '../core/tiles.dart';
import '../player/circle.dart' show MapAbilities;
import '../player/game_state.dart';
import 'spawn_field.dart';
import 'tracker.dart';

/// O que um toque num spawn faz.
enum TouchResult { collected, encounter, tooFar, auto }

class WorldView {
  WorldView({
    required this.field,
    required this.state,
    required this.auraM,
    required this.viewM,
    required this.itemName,
    this.trackerM = 120,
    this.abilities = _noAbilities,
    this.onMessage,
  });

  final SpawnField field;
  final GameState state;

  /// Raio da Aura, raio de visão e alcance do rastreador, em metros, do `balance.json`.
  final double auraM;
  final double viewM;
  final double trackerM;

  /// As habilidades de mapa do Círculo de agora (Aura maior, coleta mais longe, rastreador mais longe).
  final MapAbilities Function() abilities;

  /// Raio da Aura com o Círculo: só dentro dele o jogador encontra um Eco.
  double get auraRadiusM => auraM + abilities().auraBonusM;

  /// Até onde Fagulhas e materiais são pegos: a Aura mais o bônus de coleta.
  double get pickupRadiusM => auraRadiusM + abilities().pickupBonusM;

  /// Alcance do rastreador: o maior entre o padrão e o do Círculo.
  double get trackerRangeM => math.max(trackerM, abilities().trackerRangeM);

  /// Até onde os spawns são gerados: a visão, ou o rastreador se ele vê mais longe.
  double get reachM => math.max(viewM, trackerRangeM);

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

  bool inAura(WorldSpawn s) => _hasPlayer && distanceM(s) <= auraRadiusM;

  /// Se o jogador alcança o spawn: o Eco, dentro da Aura; Fagulha e material, dentro do alcance de coleta.
  bool canReach(WorldSpawn s) => _hasPlayer && distanceM(s) <= (s.isEco ? auraRadiusM : pickupRadiusM);

  void _gainXp(int raw, int tUtc) {
    if (state.gainXp(raw, tUtc) > 0) onMessage?.call('Nível ${state.progress.level}!');
  }

  /// Recalcula os spawns em volta de ([lat], [lon]) em [tUtc] e coleta as Fagulhas dentro da Aura.
  /// Devolve as Fagulhas coletadas agora.
  List<WorldSpawn> refresh({required double lat, required double lon, required int tUtc}) {
    final (px, py) = latLonToTileFraction(lat, lon, biomeZoom);
    _px = px;
    _py = py;
    _mpc = metersPerCell(lat);
    _hasPlayer = true;
    final all = field.around(lat: lat, lon: lon, tUtc: tUtc, radiusM: reachM, playerLevel: state.playerLevel);
    final collected = <WorldSpawn>[];
    for (final s in all) {
      if (state.isDone(s.uid)) continue;
      if (s.isEco && distanceM(s) <= viewM) state.markSeen(s.entryId);
      if (!s.isSpark || !canReach(s)) continue;
      state.add(s.entryId, s.quantity);
      state.markDone(s.uid, tUtc);
      _gainXp(state.balance.spark, tUtc);
      collected.add(s);
      onMessage?.call('+${s.quantity} ${itemName(s.entryId)}');
    }
    spawns = [for (final s in all) if (!state.isDone(s.uid)) s];
    return collected;
  }

  /// Toque num spawn. Material ao alcance é coletado aqui; Eco dentro da Aura (ou marcado) abre o encontro.
  TouchResult touch(WorldSpawn s, int tUtc) {
    if (s.isSpark) return TouchResult.auto;
    if (s.isEco && state.markOf(s.uid) != null) return TouchResult.encounter;
    if (!canReach(s)) return TouchResult.tooFar;
    if (s.isEco) return TouchResult.encounter;
    state.add(s.entryId, s.quantity);
    state.markDone(s.uid, tUtc);
    _gainXp(state.balance.material, tUtc);
    spawns = [for (final o in spawns) if (o.uid != s.uid) o];
    onMessage?.call('+${s.quantity} ${itemName(s.entryId)}');
    return TouchResult.collected;
  }

  /// Tira o spawn da vista (o Eco foi capturado ou fugiu).
  void remove(WorldSpawn s) => spawns = [for (final o in spawns) if (o.uid != s.uid) o];
}

MapAbilities _noAbilities() => MapAbilities.none;
