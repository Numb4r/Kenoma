/// A lógica da Patrulha do Véu, em Dart puro: recebe leituras de GPS, o relógio e a bateria e devolve linhas do diário,
/// vibrações, avisos de Eco raro e o estado da notificação. O serviço (`patrol_service.dart`) só liga isto ao Android;
/// os testes exercitam isto direto.
///
/// O mundo é o MESMO do app: `WorldView` sobre `SpawnField` e o mundo em camadas, com um `GameState` lido do save só para
/// leitura. O que a Patrulha ganha muda esse estado na memória (para não pegar duas vezes) e vira linha no diário; quem
/// grava no save é o app, ao incorporar o diário (`patrol_journal.dart`).
///
/// Regras: Fagulhas e materiais na Aura são coletados; Ecos a até `mark_m` são marcados, com o limite de marcas de sempre,
/// e o celular vibra (outro padrão para Brilhante, variante e Espírito, com aviso). Acima da
/// caminhada valem as regras do Modo Viagem; em carro ou moto a pergunta sai UMA vez, e até
/// a resposta nada rende. Quem dirige só tem a viagem gravada: sem coleta, sem marcas, sem vibração.
library;

import 'dart:math' as math;

import '../core/species_ids.dart';
import '../core/tiles.dart';
import '../player/game_state.dart';
import '../player/mark.dart';
import '../world/geo_fix.dart';
import '../world/spawn_field.dart';
import '../world/world_view.dart';
import 'patrol_balance.dart';
import 'street_name.dart';

/// Por que a Patrulha acabou.
enum PatrolStop { time, battery, gps, user, debug, system }

/// Como a Patrulha trata o movimento agora.
enum PatrolMode {
  /// A pé ou de bicicleta: jogo normal (sem a faixa da rota, que a Patrulha não tem).
  walking,

  /// Carro ou moto, esperando a resposta da notificação. Nada rende.
  asking,

  /// Passageiro: o mundo fica calado e os Ecos do caminho são marcados, como no Modo Viagem.
  passenger,

  /// Ao volante: só a viagem gravada.
  driver,
}

/// O que a notificação fixa mostra.
class PatrolStatus {
  const PatrolStatus({required this.sparks, required this.materials, required this.marks, required this.minutes, required this.asking, required this.mode});

  final int sparks;
  final int materials;
  final int marks;
  final int minutes;

  /// A pergunta "passageiro ou motorista" está na notificação.
  final bool asking;
  final PatrolMode mode;
}

/// O texto da notificação fixa: "12 Fagulhas · 2 Ecos marcados · 34 min".
String patrolNotificationText(PatrolStatus s) {
  if (s.asking) return 'De carro ou moto? Até responder, nada rende.';
  final sparks = s.sparks == 1 ? '1 Fagulha' : '${s.sparks} Fagulhas';
  final marks = s.marks == 1 ? '1 Eco marcado' : '${s.marks} Ecos marcados';
  return '$sparks · $marks · ${s.minutes} min';
}

/// Brilhante, variante ou Espírito: vibração diferente e aviso.
bool isPatrolRare(WorldSpawn s) => s.shiny || s.variant != null || tierOfId(s.entryId) == SpeciesTier.spirit;

/// O que uma chamada produziu. O serviço grava as linhas, toca as vibrações e mostra os avisos.
class PatrolOutput {
  final lines = <Map<String, Object?>>[];
  final vibrations = <List<int>>[];
  final rare = <({int uid, String text})>[];

  /// A pergunta acabou de sair: a notificação troca os botões.
  bool ask = false;

  /// A Patrulha acabou nesta chamada.
  PatrolStop? stop;
}

class PatrolEngine {
  PatrolEngine({
    required this.world,
    required this.state,
    required this.balance,
    required this.startUtc,
    required this.maxDurationS,
    this.streetAt,
    this.recordCells = true,
    this.speciesName,
  }) {
    world.quiet = () => mode != PatrolMode.walking;
    world.onCollected = (s) => _pending?.lines.add({'k': s.kind, 'uid': GameState.uidKey(s.uid), 't': _now, 'item': s.entryId, 'q': s.quantity});
  }

  final WorldView world;

  /// Grava as células visitadas. Desligado na Patrulha simulada do debug: como no app, o simulador não conta.
  final bool recordCells;

  /// O estado lido do save, só na memória deste isolate.
  final GameState state;
  final PatrolBalance balance;
  final int startUtc;
  final int maxDurationS;

  /// O nome da rua perto de um ponto em células z21, ou `null`.
  final String? Function(double x21, double y21)? streetAt;

  /// O nome de uma espécie, para o aviso das marcadas no Bestiário.
  final String Function(String speciesId)? speciesName;

  /// As espécies marcadas que já foram avisadas (uma vez por Eco).
  final _pinNoticed = <int>{};

  PatrolMode mode = PatrolMode.walking;
  bool? _passenger;
  bool _asked = false;
  bool ended = false;

  int sparks = 0, materials = 0, marks = 0;
  GeoFix? _last;
  int? _lastFixUtc;
  double _speedMps = 0;
  int _fast = 0;
  int? _slowSince;
  double _walkAcc = 0;
  double _tripM = 0;
  final _cells = <(int, int)>{};
  PatrolOutput? _pending;
  int _now = 0;

  double get speedMps => _speedMps;

  PatrolStatus status(int nowUtc) => PatrolStatus(
        sparks: sparks,
        materials: materials,
        marks: marks,
        minutes: math.max(0, (nowUtc - startUtc) ~/ 60),
        asking: mode == PatrolMode.asking,
        mode: mode,
      );

  /// A linha que abre a Patrulha no diário. [extra] leva a leitura do contador de passos.
  Map<String, Object?> startLine({Map<String, Object?> extra = const {}}) => {'k': 'start', 't': startUtc, ...extra};

  /// Uma leitura do GPS em [nowUtc].
  PatrolOutput fix(GeoFix f, int nowUtc) {
    final out = PatrolOutput();
    if (ended) return out;
    _now = nowUtc;
    _pending = out;
    final prev = _last;
    var moved = 0.0;
    var jump = false;
    if (prev != null) {
      moved = _distanceM(prev, f);
      final dt = (f.timeMs - prev.timeMs) / 1000;
      jump = moved > balance.maxJumpM;
      _speedMps = f.speedMps ?? (dt > 0 && !jump ? moved / dt : 0);
    } else {
      _speedMps = f.speedMps ?? 0;
    }
    _last = f;
    _lastFixUtc = nowUtc;
    _updateMode(nowUtc, out);
    if (recordCells && mode != PatrolMode.driver && mode != PatrolMode.asking) _visitCell(f, nowUtc, out);
    final collected = world.refresh(lat: f.lat, lon: f.lon, tUtc: nowUtc);
    sparks += collected.fold(0, (n, s) => n + s.quantity);
    if (mode == PatrolMode.walking) {
      for (final s in [...world.spawns]) {
        if (s.isMaterial && world.inAura(s) && world.touch(s, nowUtc) == TouchResult.collected) materials += s.quantity;
      }
    }
    if (mode == PatrolMode.walking || mode == PatrolMode.passenger) {
      _mark(nowUtc, out);
      _pinned(out);
    }
    if (!jump) {
      if (mode == PatrolMode.walking) {
        _walkAcc += moved;
        if (_walkAcc >= balance.walkLineM) _flushWalk(nowUtc, out);
      } else {
        _tripM += moved;
      }
    }
    _pending = null;
    return out;
  }

  /// Uma vez a cada `tick_s`: o tempo máximo e o GPS calado.
  PatrolOutput tick(int nowUtc) {
    if (ended) return PatrolOutput();
    if (nowUtc - startUtc >= maxDurationS) return stop(PatrolStop.time, nowUtc);
    if (nowUtc - (_lastFixUtc ?? startUtc) >= balance.gpsTimeoutS) return stop(PatrolStop.gps, nowUtc);
    return PatrolOutput();
  }

  /// A carga da bateria em %.
  PatrolOutput battery(int pct, int nowUtc) =>
      !ended && pct < balance.batteryMinPct ? stop(PatrolStop.battery, nowUtc) : PatrolOutput();

  /// A resposta da notificação. Vale para o resto da Patrulha.
  void answer({required bool passenger}) {
    _passenger = passenger;
    if (mode == PatrolMode.asking) mode = passenger ? PatrolMode.passenger : PatrolMode.driver;
  }

  /// Fecha a Patrulha: o que falta da caminhada e da viagem, e a linha de fim. [extra] leva a leitura do contador.
  PatrolOutput stop(PatrolStop why, int nowUtc, {Map<String, Object?> extra = const {}}) {
    final out = PatrolOutput();
    if (ended) return out;
    ended = true;
    _flushWalk(nowUtc, out);
    _flushTrip(nowUtc, out);
    out.lines.add({'k': 'end', 't': nowUtc, 'why': why.name, ...extra});
    out.stop = why;
    return out;
  }

  void _updateMode(int now, PatrolOutput out) {
    _fast = _speedMps > balance.vehicleMps ? _fast + 1 : 0;
    if (mode == PatrolMode.walking) {
      if (_fast < balance.vehicleConfirmFixes) return;
      _slowSince = null;
      _walkAcc = 0; // o trecho até perceber o carro não é caminhada
      if (_passenger != null) {
        mode = _passenger! ? PatrolMode.passenger : PatrolMode.driver;
      } else {
        mode = PatrolMode.asking;
        if (!_asked) out.ask = true; // uma vez só: sem resposta, os próximos trechos de carro também não rendem
        _asked = true;
      }
      return;
    }
    if (_speedMps > balance.walkMaxMps) {
      _slowSince = null;
      return;
    }
    _slowSince ??= now;
    if (now - _slowSince! < balance.vehicleExitS) return;
    _flushTrip(now, out);
    mode = PatrolMode.walking;
    _slowSince = null;
  }

  void _visitCell(GeoFix f, int now, PatrolOutput out) {
    final c = latLonToTile(f.lat, f.lon, 17);
    if (_cells.add(c)) out.lines.add({'k': 'cell', 't': now, 'x': c.$1, 'y': c.$2});
  }

  /// Marca os Ecos ao alcance, até o limite. Ritual não responde a marcação.
  void _mark(int now, PatrolOutput out) {
    for (final s in world.spawns) {
      if (!s.isEco || isRitualOnlyId(s.entryId) || state.isDone(s.uid) || state.markOf(s.uid) != null) continue;
      final d = world.distanceM(s);
      if (d > balance.markM) continue;
      final m = Mark.of(s, nowUtc: now, durationS: balance.markDurationS);
      if (!state.addMark(m, now)) return; // limite de marcas
      marks++;
      out.lines.add({'k': 'mark', 'uid': m.uid, 't': now, 'mark': m.toJson()});
      final rare = isPatrolRare(s);
      out.vibrations.add(rare ? balance.vibrateRareMs : balance.vibrateMs);
      if (rare) out.rare.add((uid: s.uid, text: 'Algo raro passou a ${d.round()} m, ${streetPhrase(streetAt?.call(s.x, s.y))}'));
    }
  }

  /// Uma espécie marcada no Bestiário entrou no alcance do Radar: aviso e vibração de raro, uma vez por Eco.
  void _pinned(PatrolOutput out) {
    for (final s in world.spawns) {
      if (!world.isPinned(s) || state.isDone(s.uid)) continue;
      final d = world.distanceM(s);
      if (d > world.street.traceRangeM || !_pinNoticed.add(s.uid)) continue;
      out.vibrations.add(balance.vibrateRareMs);
      out.rare.add((uid: s.uid, text: 'Marcada no Bestiário: ${speciesName?.call(s.entryId) ?? 'uma espécie'} a ${d.round()} m, ${streetPhrase(streetAt?.call(s.x, s.y))}'));
    }
  }

  void _flushWalk(int now, PatrolOutput out) {
    final m = _walkAcc.floor();
    if (m <= 0) return;
    _walkAcc -= m;
    out.lines.add({'k': 'walk', 't': now, 'm': m});
  }

  void _flushTrip(int now, PatrolOutput out) {
    final m = _tripM.floor();
    _tripM = 0;
    if (m <= 0 || mode == PatrolMode.walking) return;
    out.lines.add({'k': 'trip', 't': now, 'm': m, 'driver': _passenger != true});
  }

  static double _distanceM(GeoFix a, GeoFix b) {
    final dy = (b.lat - a.lat) * 111320.0;
    final dx = (b.lon - a.lon) * 111320.0 * math.cos(a.lat * math.pi / 180);
    return math.sqrt(dx * dx + dy * dy);
  }
}
