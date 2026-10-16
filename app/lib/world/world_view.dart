/// O que o jogador vê e alcança no mundo agora: os spawns ao redor que ainda não foram coletados, as
/// Fagulhas que a Aura pega sozinha e o toque em cada coisa. Dart puro: o mapa só desenha o que sai
/// daqui e repassa os toques.
library;

import 'dart:math' as math;

import '../core/features.dart';

import '../core/behavior.dart';
import '../core/tiles.dart';
import '../player/conjurer_balance.dart' show School;
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
    this.touchRangeM = 30,
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

  /// Alcance de toque dos Ecos, em metros (fixo).
  final double touchRangeM;
  final double viewM;
  final double trackerM;

  /// As habilidades de mapa do Círculo de agora (Aura maior, coleta mais longe, rastreador mais longe).
  final MapAbilities Function() abilities;

  /// O raio de coleta automática de Fagulhas e materiais: a Aura base mais o Círculo (Aura e coleta) e o Familiar, que
  /// anda ao lado do Conjurador e não ocupa espaço no Círculo. É o ÚNICO valor: a lógica e o círculo desenhado leem este.
  double get auraRadiusM =>
      auraM +
      abilities().auraBonusM +
      abilities().pickupBonusM +
      (streetLifeEnabled ? street.familiarPickupBonusM : 0) +
      state.cb.auraBonusFor(state.playerLevel) +
      (state.conjurer.school == School.shaman ? state.cb.shamanAuraBonusM : 0);

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
  /// Devolve `true` se abriu; com `false` (tela ocupada) a chance não se gasta e ele tenta de novo no próximo quadro.
  bool Function(WorldSpawn eco)? onAggressive;

  /// Uma Fagulha ou um material foi coletado (sozinho pela Aura ou por toque): a tela mostra o item voando até o Conjurador.
  void Function(WorldSpawn item)? onCollected;

  /// Um Eco arisco fugiu: a tela o desfaz em pixels onde estava.
  void Function(WorldSpawn eco)? onFled;

  /// Um Eco Brilhante apareceu à vista (uma vez por Eco): a tela toca um som curto e avisa.
  void Function(WorldSpawn eco)? onShiny;
  final _announced = <int>{};

  /// Os que já apareceram nesta sessão (o debug só força o primeiro Eco *novo*), e o que o debug forçou em cada um.
  final _known = <int>{};
  final _forced = <int, ({EcoBehavior behavior, bool variant, bool shiny})>{};
  final _inAura = <int>{};
  final _aggroFired = <int>{};

  /// O percurso recente do jogador, para a velocidade média dos últimos segundos (o Arisco foge de quem chega correndo).
  final _track = <({int t, double x, double y})>[];

  /// A velocidade média do jogador na janela do Arisco, em m/s: o deslocamento do primeiro ao último ponto dividido pelo
  /// tempo (o caminho inteiro somaria o tremor do GPS). 0 com menos de 3 s de percurso.
  double get playerSpeedMps {
    // A fuga do Arisco usa a velocidade do GPS cru (a que o jogador de fato anda); sem leituras cruas, a do marcador.
    final raw = _gpsTrack.length >= 2;
    final track = raw ? _gpsTrack : _track;
    if (track.length < 2) return 0;
    final span = track.last.t - track.first.t;
    if (span < 3) return 0;
    final dx = track.last.x - track.first.x, dy = track.last.y - track.first.y;
    return math.sqrt(dx * dx + dy * dy) * (raw ? _gpsMpc : _mpc) / span;
  }

  /// O percurso do GPS cru, só para a velocidade do Arisco: a coleta e a Aura seguem a posição suavizada do marcador.
  final _gpsTrack = <({int t, double x, double y})>[];
  double _gpsMpc = 1;

  /// Uma leitura nova do GPS, antes de qualquer suavização.
  void noteGps({required double lat, required double lon, required int tUtc}) {
    final (x, y) = latLonToTileFraction(lat, lon, biomeZoom);
    _gpsMpc = metersPerCell(lat);
    if (_gpsTrack.isNotEmpty) {
      final jx = x - _gpsTrack.last.x, jy = y - _gpsTrack.last.y;
      if (math.sqrt(jx * jx + jy * jy) * _gpsMpc > 25) _gpsTrack.clear(); // teleporte ou troca de fonte
    }
    _gpsTrack.add((t: tUtc, x: x, y: y));
    _gpsTrack.removeWhere((p) => tUtc - p.t > street.skittishSpeedWindowS);
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

  /// Se o Eco está ao alcance de toque (30 m).
  bool inTouchRange(WorldSpawn s) => _hasPlayer && distanceM(s) <= touchRangeM;

  /// Se o jogador alcança o spawn: o Eco, dentro da Aura; Fagulha e material, dentro do alcance de coleta.
  bool canReach(WorldSpawn s) => _hasPlayer && (s.isEco ? inTouchRange(s) : inAura(s));

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
    // Um salto de mais de 25 m entre duas leituras é teleporte ou troca de fonte: o percurso recomeça.
    if (_track.isNotEmpty) {
      final jx = px - _track.last.x, jy = py - _track.last.y;
      if (math.sqrt(jx * jx + jy * jy) * _mpc > 25) _track.clear();
    }
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
      if (s.isEco && distanceM(s) <= viewM) {
        state.markSeen(s.entryId, variant: s.variant, shiny: s.shiny);
        if (s.shiny && _announced.add(s.uid)) onShiny?.call(s);
      }
      if (s.isEco && inTouchRange(s)) {
        inAuraNow.add(s.uid);
        if (!_inAura.contains(s.uid) && _entered(s, tUtc)) {
          onFled?.call(s);
          continue; // fugiu
        }
        _tryAggressive(s);
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
      onCollected?.call(s);
      onMessage?.call('+${s.quantity} ${itemName(s.entryId)}');
    }
    _inAura
      ..clear()
      ..addAll(inAuraNow);
    spawns = visible;
    allEcos = [for (final s in allEcos) if (!state.isDone(s.uid)) s]; // o que fugiu ou foi pego neste quadro sai
    return collected;
  }

  /// O Agressivo dentro da Aura abre a folha uma vez por Eco. Se a tela estava ocupada, tenta de novo no próximo quadro.
  void _tryAggressive(WorldSpawn s) {
    if (s.behavior != EcoBehavior.aggressive || _aggroFired.contains(s.uid)) return;
    if (onAggressive?.call(s) ?? false) _aggroFired.add(s.uid);
  }

  /// Um Eco acabou de entrar na Aura. Devolve `true` se ele fugiu (Arisco e o jogador chegou acima da velocidade).
  bool _entered(WorldSpawn s, int tUtc) {
    switch (s.behavior) {
      case EcoBehavior.skittish:
        // O Xamã Urbano conversa com as criaturas: os Ariscos não fogem dele.
        if (state.conjurer.school != School.shaman && playerSpeedMps > street.skittishFleeSpeedMps) {
          state.markDone(s.uid, tUtc); // a fuga entra no registro, como na falha
          onMessage?.call('Um Eco arisco fugiu: você chegou rápido demais');
          return true;
        }
      case EcoBehavior.aggressive || EcoBehavior.passive || EcoBehavior.hidden:
        break; // o Agressivo é tratado a cada quadro em [_tryAggressive]
    }
    return false;
  }

  /// Uma varredura do Radar em [tUtc]: mostra os rastros dos Ecos raros por perto e revela os Ocultos bem perto. A
  /// recarga é conferida por quem chama (`radarWaitS`). Os Ocultos revelados passam a aparecer no mapa na hora.
  RadarOutcome radar(int tUtc) {
    final out = sweep(
      all: [for (final s in allEcos) if (!state.isDone(s.uid)) s],
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
    onCollected?.call(s);
    return TouchResult.collected;
  }

  /// Tira o spawn da vista (o Eco foi capturado ou fugiu).
  void remove(WorldSpawn s) {
    spawns = [for (final o in spawns) if (o.uid != s.uid) o];
    allEcos = [for (final o in allEcos) if (o.uid != s.uid) o];
  }
}

MapAbilities _noAbilities() => MapAbilities.none;
String? _noType(String _) => null;
