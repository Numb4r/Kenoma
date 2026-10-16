/// O que o jogador vê e alcança no mundo agora: os spawns ao redor que ainda não foram coletados, as
/// Fagulhas que a Aura pega sozinha e o toque em cada coisa. Dart puro: o mapa só desenha o que sai
/// daqui e repassa os toques.
library;

import 'dart:math' as math;

import '../core/behavior.dart';
import '../core/tiles.dart';
import '../player/circle.dart' show MapAbilities;
import '../player/game_state.dart';
import 'debug_force.dart';
import 'radar.dart';
import 'spawn_field.dart';
import 'street_life_balance.dart';
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
    required this.street,
    this.force,
    this.typeOf = _noType,
    this.trackerM = 120,
    this.abilities = _noAbilities,
    this.onMessage,
  });

  final SpawnField field;
  final GameState state;

  /// Comportamentos, Radar e Familiar do `balance.json`.
  final StreetLifeBalance street;

  /// O debug que força o próximo spawn. `null` fora do debug.
  final DebugForce? force;

  /// O tipo (`fire`, `plant`, `water`) de uma espécie, para o scanner de nível 2.
  final String? Function(String entryId) typeOf;

  /// Raio da Aura, raio de visão e alcance do rastreador, em metros, do `balance.json`.
  final double auraM;
  final double viewM;
  final double trackerM;

  /// As habilidades de mapa do Círculo de agora (Aura maior, coleta mais longe, rastreador mais longe).
  final MapAbilities Function() abilities;

  /// Raio da Aura com o Círculo: só dentro dele o jogador encontra um Eco.
  double get auraRadiusM => auraM + abilities().auraBonusM;

  /// Até onde Fagulhas e materiais são pegos: a Aura mais o bônus de coleta do Círculo e o do Familiar, que anda ao
  /// lado do Conjurador e não ocupa espaço no Círculo.
  double get pickupRadiusM => auraRadiusM + abilities().pickupBonusM + street.familiarPickupBonusM;

  /// Alcance do rastreador: o maior entre o padrão e o do Círculo.
  double get trackerRangeM => math.max(trackerM, abilities().trackerRangeM);

  /// Até onde os spawns são gerados: a visão, ou o rastreador se ele vê mais longe.
  double get reachM => math.max(viewM, trackerRangeM);

  /// Nome do item na interface.
  final String Function(String id) itemName;

  /// Aviso para o jogador ("+1 Pó de Essência de Fogo").
  final void Function(String message)? onMessage;

  /// Os spawns visíveis, ainda não coletados. Atualizados por [refresh]. Os Ecos Ocultos só entram depois de uma
  /// varredura do Radar.
  List<WorldSpawn> spawns = const [];

  /// Todos os Ecos ao redor, inclusive os Ocultos que ainda ninguém revelou: o Radar varre estes.
  List<WorldSpawn> allEcos = const [];

  /// Os rastros que a última varredura deixou no mapa (some quando passa do tempo).
  List<Trace> traces = const [];

  /// Um Agressivo entrou na Aura: a tela abre a folha de preparo sozinha (e o celular vibra).
  void Function(WorldSpawn eco)? onAggressive;

  /// Os que já apareceram nesta sessão (o debug só força o primeiro Eco *novo*), e o que o debug forçou em cada um.
  final _known = <int>{};
  final _forced = <int, ({EcoBehavior behavior, bool variant, bool shiny})>{};
  final _inAura = <int>{};
  final _aggroFired = <int>{};

  /// O percurso recente do jogador, para a velocidade média dos últimos segundos (o Arisco foge de quem chega correndo).
  final _track = <({int t, double x, double y})>[];

  /// A velocidade média do jogador na janela do Arisco, em m/s. 0 com menos de 2 s de percurso.
  double get playerSpeedMps {
    if (_track.length < 2) return 0;
    final span = _track.last.t - _track.first.t;
    if (span < 2) return 0;
    var path = 0.0;
    for (var i = 1; i < _track.length; i++) {
      final dx = _track[i].x - _track[i - 1].x, dy = _track[i].y - _track[i - 1].y;
      path += math.sqrt(dx * dx + dy * dy);
    }
    return path * _mpc / span;
  }

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

  /// O Eco do debug: se o menu pediu para forçar o próximo Eco novo, é este (uma vez só); se já foi forçado, continua.
  WorldSpawn _withForce(WorldSpawn s) {
    if (!s.isEco) return s;
    var f = _forced[s.uid];
    if (f == null && force != null && force!.pendingEco && !_known.contains(s.uid)) {
      f = force!.take();
      _forced[s.uid] = f;
    }
    _known.add(s.uid);
    if (f == null) return s;
    return s.withTraits(behavior: f.behavior, variant: f.variant ? (s.variant ?? 'urban') : s.variant, shiny: f.shiny || s.shiny);
  }

  /// Recalcula os spawns em volta de ([lat], [lon]) em [tUtc], coleta as Fagulhas dentro do alcance e dispara o que a
  /// entrada na Aura faz (o Arisco foge, o Agressivo abre a folha). Devolve as Fagulhas coletadas agora.
  List<WorldSpawn> refresh({required double lat, required double lon, required int tUtc}) {
    final (px, py) = latLonToTileFraction(lat, lon, biomeZoom);
    _px = px;
    _py = py;
    _mpc = metersPerCell(lat);
    _hasPlayer = true;
    _track.add((t: tUtc, x: px, y: py));
    _track.removeWhere((p) => tUtc - p.t > street.skittishSpeedWindowS);
    traces = [for (final t in traces) if (t.untilUtc > tUtc) t];
    final all = [for (final s in field.around(lat: lat, lon: lon, tUtc: tUtc, radiusM: reachM, playerLevel: state.playerLevel)) _withForce(s)];
    allEcos = [for (final s in all) if (s.isEco && !state.isDone(s.uid)) s];
    final collected = <WorldSpawn>[];
    final inAuraNow = <int>{};
    final visible = <WorldSpawn>[];
    for (final s in all) {
      if (state.isDone(s.uid)) continue;
      final hiddenAway = s.isEco && s.behavior == EcoBehavior.hidden && !state.isHiddenRevealed(s.uid, tUtc);
      if (hiddenAway) continue;
      if (s.isEco && distanceM(s) <= viewM) state.markSeen(s.entryId, variant: s.variant, shiny: s.shiny);
      if (s.isEco && inAura(s)) {
        inAuraNow.add(s.uid);
        if (!_inAura.contains(s.uid) && _entered(s, tUtc)) continue; // fugiu
      }
      if (!s.isSpark || !canReach(s)) {
        visible.add(s);
        continue;
      }
      state.add(s.entryId, s.quantity);
      state.markDone(s.uid, tUtc);
      _gainXp(state.balance.spark, tUtc);
      state.recordEvent('spark', s.entryId.replaceFirst('item.dust.', ''), s.quantity);
      collected.add(s);
      onMessage?.call('+${s.quantity} ${itemName(s.entryId)}');
    }
    _inAura
      ..clear()
      ..addAll(inAuraNow);
    spawns = visible;
    return collected;
  }

  /// Um Eco acabou de entrar na Aura. Devolve `true` se ele fugiu (Arisco e o jogador chegou acima da velocidade).
  bool _entered(WorldSpawn s, int tUtc) {
    switch (s.behavior) {
      case EcoBehavior.skittish:
        if (playerSpeedMps > street.skittishFleeSpeedMps) {
          state.markDone(s.uid, tUtc); // a fuga entra no registro, como na falha
          onMessage?.call('Um Eco arisco fugiu: você chegou rápido demais');
          return true;
        }
      case EcoBehavior.aggressive:
        if (_aggroFired.add(s.uid)) onAggressive?.call(s);
      case EcoBehavior.passive || EcoBehavior.hidden:
        break;
    }
    return false;
  }

  /// Uma varredura do Radar em [tUtc]: mostra os rastros dos Ecos raros por perto e revela os Ocultos bem perto. A
  /// recarga é conferida por quem chama (`radarWaitS`). Os Ocultos revelados passam a aparecer no mapa na hora.
  RadarOutcome radar(int tUtc) {
    final out = sweep(
      all: allEcos,
      distanceM: distanceM,
      typeOf: typeOf,
      seed: field.seed,
      tUtc: tUtc,
      playerLevel: state.playerLevel,
      balance: street,
    );
    state.recordSweep(tUtc, [for (final s in out.revealed) s.uid], tUtc + street.hiddenRevealS.round());
    if (out.revealed.isNotEmpty) state.recordEvent('hidden_revealed', '', out.revealed.length);
    traces = out.traces;
    spawns = [...spawns, for (final s in out.revealed) if (!spawns.any((o) => o.uid == s.uid)) s];
    return out;
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
    state.recordEvent('material', s.entryId, s.quantity);
    spawns = [for (final o in spawns) if (o.uid != s.uid) o];
    onMessage?.call('+${s.quantity} ${itemName(s.entryId)}');
    return TouchResult.collected;
  }

  /// Tira o spawn da vista (o Eco foi capturado ou fugiu).
  void remove(WorldSpawn s) => spawns = [for (final o in spawns) if (o.uid != s.uid) o];
}

MapAbilities _noAbilities() => MapAbilities.none;
String? _noType(String _) => null;
