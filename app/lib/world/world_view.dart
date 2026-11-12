/// O que o jogador vê e alcança no mundo agora: os spawns ao redor que ainda não foram coletados, as
/// Fagulhas que a Aura pega sozinha e o toque em cada coisa. Dart puro: o mapa só desenha o que sai
/// daqui e repassa os toques.
library;

import 'dart:math' as math;

import '../core/features.dart';
import '../core/species_ids.dart';
import '../crafting/ritual.dart';
import '../crafting/ritual_data.dart';

import '../core/behavior.dart';
import '../core/tiles.dart';
import '../player/conjurer_balance.dart' show School;
import '../player/circle.dart' show MapAbilities;
import '../player/game_state.dart';
import 'climate_world.dart';
import 'debug_creatures.dart';
import 'debug_force.dart';
import 'radar.dart';
import 'spawn_field.dart';
import 'street_life_balance.dart';
import 'tracker.dart';

/// O que um toque num spawn faz.
enum TouchResult {
  collected,
  encounter,
  tooFar,
  auto,

  /// O Eco está a até 30 m e é `ritualOnly`: a tela abre o ritual em vez da sintonia.
  ritual,
}

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
    this.ritual,
  });

  final SpawnField field;

  /// As receitas de ritual, para a pesquisa por avistamento. `null`: sem pesquisa (testes).
  final RitualBook? ritual;
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

  /// Modo Viagem: em moto, carro e ônibus o mundo fica calado (nada de coleta nem vibração).
  /// Quem é passageiro recebe pelo baú; quem dirige não recebe nada.
  bool Function() quiet = _never;

  /// Modo Viagem: a faixa de coleta ao longo da rota, de bicicleta.
  double Function() travelPickupM = _noPickup;

  /// GPS simulado sem recompensa (o interruptor do debug desligado): o que se pega continua vindo, mas nada conta para XP,
  /// estatísticas nem bestiário, e a captura entra na coleção marcada como debug.
  bool Function() sandbox = _never;

  /// O raio de coleta automática de Fagulhas e materiais: a Aura base mais o Círculo (Aura e coleta) e o Familiar, que
  /// anda ao lado do Conjurador e não ocupa espaço no Círculo. É o ÚNICO valor: a lógica e o círculo desenhado leem este.
  double get auraRadiusM =>
      auraM +
      abilities().auraBonusM +
      abilities().pickupBonusM +
      (streetLifeEnabled ? street.familiarPickupBonusM : 0) +
      travelPickupM() +
      state.cb.auraBonusFor(state.playerLevel) +
      (state.conjurer.school == School.shaman ? state.cb.shamanAuraBonusM : 0) +
      climate.auraAddM;

  /// O que o clima de agora faz com o jogador (Aura, visão, calma, rastros, sintonia). Atualizado em [refresh].
  PlayerClimate climate = PlayerClimate.none;

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

  /// Os rastros que o último pulso deixou no mapa (some quando passa do tempo).
  List<Trace> traces = const [];

  /// Os Ocultos que o último pulso achou e que o jogador ainda não alcançou.
  List<Distortion> distortions = const [];

  /// O último pulso: quando e de onde (células z21) a onda partiu. Só desenho.
  ({int t, double x, double y})? pulse;

  /// Uma Fagulha ou um material foi coletado (sozinho pela Aura ou por toque): a tela mostra o item voando até o Conjurador.
  void Function(WorldSpawn item)? onCollected;

  /// Um Eco Brilhante apareceu à vista (uma vez por Eco): a tela toca um som curto e avisa.
  void Function(WorldSpawn eco)? onShiny;

  /// O jogador tocou num Eco de ritual a até `touchRangeM` (junto com [TouchResult.ritual]): a tela abre o ritual.
  void Function(WorldSpawn eco)? onRitualTarget;
  final _ritualSeen = <int>{};

  /// Um Eco passou a estar a até `touchRangeM` (uma vez por entrada). O modo bolso vibra aqui.
  void Function(WorldSpawn eco)? onEnteredRange;
  final _announced = <int>{};

  /// Os que já apareceram nesta sessão (o debug só força o primeiro Eco *novo*), e o que o debug forçou em cada um.
  final _known = <int>{};
  final _forced = <int, ({EcoBehavior behavior, bool variant, bool shiny, bool spirit, bool ritual})>{};
  final _inAura = <int>{};
  double _px = 0, _py = 0, _mpc = 1;
  bool _hasPlayer = false;

  /// Metros do jogador até o spawn.
  double distanceM(WorldSpawn s) => s.distanceM(_px, _py, _mpc);

  /// O jogador (células z21 fracionárias) e os metros por célula da latitude dele, na última atualização.
  double get playerX => _px;
  double get playerY => _py;
  double get metersPerCell21 => _mpc;

  /// O que o sonar mostra agora: os arcos dos rastros e as distorções, vistos do jogador.
  List<SonarEcho> sonar() {
    if (!_hasPlayer) return const [];
    final byUid = {for (final s in allEcos) s.uid: s};
    return sonarEchoes(traces: traces, distortions: distortions, ecoOf: (uid) => byUid[uid], playerX: _px, playerY: _py, metersPerCell: _mpc, balance: street);
  }

  /// As marcas da borda da tela em [nowUtc]: por `edge_marks_s` depois do último pulso, a direção de cada achado dele que
  /// não está na tela ([onScreen]). Sem pulso, nenhuma.
  List<EdgeMark> edgeMarksAt(double nowUtc, {required bool Function(WorldSpawn) onScreen}) {
    final p = pulse;
    if (!_hasPlayer || p == null || nowUtc - p.t >= street.edgeMarksS) return const [];
    final byUid = {for (final s in allEcos) s.uid: s};
    final finds = [for (final e in sonar()) if (byUid[e.uid] != null) (eco: byUid[e.uid]!, echo: e)];
    return edgeMarks(finds: finds, pulseUtc: p.t, nowUtc: nowUtc, showS: street.edgeMarksS, pulseSpeedMps: street.pulseSpeedMps, onScreen: onScreen);
  }

  bool inAura(WorldSpawn s) => _hasPlayer && distanceM(s) <= auraRadiusM;

  /// Se o Eco está ao alcance de toque (30 m).
  bool inTouchRange(WorldSpawn s) => _hasPlayer && distanceM(s) <= touchRangeM;

  /// Se o jogador alcança o spawn: o Eco, dentro da Aura; Fagulha e material, dentro do alcance de coleta.
  bool canReach(WorldSpawn s) => _hasPlayer && (s.isEco ? inTouchRange(s) : inAura(s));

  void _gainXp(int raw, int tUtc) {
    if (sandbox()) return;
    if (state.gainXp(raw, tUtc) > 0) onMessage?.call('Nível ${state.progress.level}!');
  }

  /// A estatística da coleta, fora do GPS simulado sem recompensa.
  void _record(String kind, String key, int n) {
    if (!sandbox()) state.recordEvent(kind, key, n);
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
    if (f.spirit && tierOfId(s.entryId) == SpeciesTier.eco) {
      final id = '${familyOfId(s.entryId)}.spirit';
      s = s.withSpecies(id, math.min(s.level ?? 1, state.balance.levelCapFor(id)));
    }

    return s.withTraits(
      behavior: f.behavior,
      variant: f.variant ? (s.variant ?? 'urban') : s.variant,
      shiny: f.shiny || s.shiny,
      entryId: f.ritual && !isRitualOnlyId(s.entryId) ? '${familyOfId(s.entryId)}.ritual' : null,
    );
  }

  /// Recalcula os spawns em volta de ([lat], [lon]) em [tUtc], coleta as Fagulhas dentro do alcance e dispara o que a
  /// entrada na Aura faz. Devolve as Fagulhas coletadas agora.
  List<WorldSpawn> refresh({required double lat, required double lon, required int tUtc}) {
    final (px, py) = latLonToTileFraction(lat, lon, biomeZoom);
    _px = px;
    _py = py;
    _mpc = metersPerCell(lat);
    _hasPlayer = true;
    climate = field.climate?.modsAt(px, py, tUtc) ?? PlayerClimate.none;
    syncRitualUnlock(state);
    traces = [for (final t in traces) if (t.untilUtc > tUtc) t];
    _resolveDistortions(tUtc);
    // Os Espíritos só aparecem a partir do nível `spirit_spawn_level`. É individual: o mundo é o mesmo para todos.
    final spiritsOn = state.playerLevel >= state.cb.spiritSpawnLevel;
    final ritualsOn = state.playerLevel >= state.cb.ritualLevel;
    bool visibleTier(WorldSpawn s) =>
        !s.isEco || tierOfId(s.entryId) == SpeciesTier.eco || (isRitualOnlyId(s.entryId) ? ritualsOn : spiritsOn);
    // Neblina e Nevasca: os Ecos só aparecem até a visão do clima (nem no rastreador).
    final viewCap = climate.viewMaxM;
    final all = [
      for (final s in field.around(lat: lat, lon: lon, tUtc: tUtc, radiusM: reachM, playerLevel: state.playerLevel))
        if (visibleTier(s) && (viewCap == null || !s.isEco || distanceM(s) <= viewCap)) _withForce(s),
      // As do "Criar criatura": fora do mundo, valem em qualquer nível.
      ...?force?.creatures.around(px: px, py: py, metersPerCell21: _mpc, radiusM: auraRadiusM, tUtc: tUtc, biomeAt: _biomeKeyAt),
    ];
    allEcos = [for (final s in all) if (s.isEco && !state.isDone(s.uid)) s];
    final collected = <WorldSpawn>[];
    final inAuraNow = <int>{};
    final silent = quiet();
    final visible = <WorldSpawn>[];
    for (final s in all) {
      if (state.isDone(s.uid)) continue;
      final hiddenAway = s.isEco && s.behavior == EcoBehavior.hidden && !state.isHiddenRevealed(s.uid, tUtc);
      if (hiddenAway) continue;
      if (silent) {
        visible.add(s);
        continue;
      }
      if (s.isEco && distanceM(s) <= viewM) {
        if (!isDebugUid(s.uid) && !sandbox()) state.markSeen(s.entryId, variant: s.variant, shiny: s.shiny); // a de debug não entra no bestiário
        if (ritual != null && isRitualOnlyId(s.entryId)) noteRitualSighting(state, ritual!, s.uid, s.entryId, _ritualSeen);
        if (s.shiny && _announced.add(s.uid)) onShiny?.call(s);
      }
      if (s.isEco && inTouchRange(s)) {
        inAuraNow.add(s.uid);
        if (!_inAura.contains(s.uid)) onEnteredRange?.call(s);
      }
      if (!s.isSpark || !canReach(s)) {
        visible.add(s);
        continue;
      }
      if (!sandbox()) state.add(s.entryId, s.quantity); // GPS simulado sem recompensa: nada entra na Bolsa
      state.markDone(s.uid, tUtc);
      _gainXp(state.balance.spark, tUtc);
      _record('spark', s.entryId.replaceFirst('item.dust.', ''), s.quantity);
      collected.add(s);
      onCollected?.call(s);
      onMessage?.call('+${s.quantity} ${itemName(s.entryId)}${sandbox() ? ' (debug, fora da Bolsa)' : ''}');
    }
    _inAura
      ..clear()
      ..addAll(inAuraNow);
    spawns = visible;
    allEcos = [for (final s in allEcos) if (!state.isDone(s.uid)) s]; // o que fugiu ou foi pego neste quadro sai
    return collected;
  }

  /// As distorções vencidas saem; as que o jogador alcançou viram Eco no mapa (o Oculto fica revelado por
  /// `hidden_reveal_s`). Individual: o save guarda só o que este aparelho revelou.
  void _resolveDistortions(int tUtc) {
    if (distortions.isEmpty) return;
    final live = [for (final d in distortions) if (d.untilUtc > tUtc && !state.isDone(d.eco.uid)) d];
    final reached = reachedDistortions(live, distanceM, street);
    distortions = [for (final d in live) if (!reached.contains(d)) d];
    if (reached.isEmpty) return;
    state.revealHidden([for (final d in reached) d.eco.uid], tUtc, tUtc + street.hiddenRevealS.round());
    _record('hidden_revealed', '', reached.where((d) => !isDebugUid(d.eco.uid)).length); // as de debug não contam
  }

  /// Um pulso do Radar em [tUtc]: rastros dos Ecos raros por perto e distorções dos Ocultos bem perto. A recarga é
  /// conferida por quem chama (`radarWaitS`). Um Oculto só aparece no mapa quando o jogador chega à distorção dele.
  RadarOutcome radar(int tUtc) {
    final out = sweep(
      all: [for (final s in allEcos) if (!state.isDone(s.uid)) s],
      distanceM: distanceM,
      typeOf: typeOf,
      seed: field.seed,
      tUtc: tUtc,
      playerLevel: state.playerLevel,
      balance: street,
      showS: (street.traceShowS * climate.traceTimeMult).round(), // o Frio guarda os rastros por mais tempo
    );
    state.recordSweep(tUtc, const [], tUtc);
    traces = out.traces;
    distortions = out.distortions;
    pulse = (t: tUtc, x: _px, y: _py);
    _resolveDistortions(tUtc); // já em cima de uma: aparece na próxima atualização
    return out;
  }

  /// Toque num spawn. Material ao alcance é coletado aqui; Eco dentro da Aura (ou marcado) abre o encontro.
  TouchResult touch(WorldSpawn s, int tUtc) {
    if (s.isSpark) return TouchResult.auto;
    if (s.isEco && isRitualOnlyId(s.entryId)) {
      if (!inTouchRange(s)) return TouchResult.tooFar; // o ritual pede o Eco perto: a marcação não vale
      onRitualTarget?.call(s);
      return TouchResult.ritual;
    }
    if (s.isEco && state.markOf(s.uid) != null) return TouchResult.encounter;
    if (!canReach(s)) return TouchResult.tooFar;
    if (s.isEco) return TouchResult.encounter;
    if (!sandbox()) {
      state.add(s.entryId, s.quantity); // GPS simulado sem recompensa: nada entra na Bolsa
      if (s.tag == 'rune_bonus') state.conjurer.runeBonus++; // a runa guarda o bônus do próximo ritual
    }
    state.markDone(s.uid, tUtc);
    _gainXp(state.balance.material, tUtc);
    _record('material', s.entryId, s.quantity);
    spawns = [for (final o in spawns) if (o.uid != s.uid) o];
    onMessage?.call('+${s.quantity} ${itemName(s.entryId)}${sandbox() ? ' (debug, fora da Bolsa)' : ''}');
    onCollected?.call(s);
    return TouchResult.collected;
  }

  /// A chave de bioma (variante) de uma célula z20, para a criatura de debug com variante de bioma.
  String _biomeKeyAt(int cx, int cy) => field.map.biomes.spawnKey(field.map.spawnBiomeAtCell(cx, cy));

  /// Tira o spawn da vista (o Eco foi capturado ou fugiu).
  void remove(WorldSpawn s) {
    spawns = [for (final o in spawns) if (o.uid != s.uid) o];
    allEcos = [for (final o in allEcos) if (o.uid != s.uid) o];
  }
}

MapAbilities _noAbilities() => MapAbilities.none;
bool _never() => false;
double _noPickup() => 0;
String? _noType(String _) => null;
