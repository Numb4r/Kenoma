/// O clima no mundo: qual clima vale numa célula e hora, o que as peças fazem nascer (Eco do raio, granizo, poças...), a
/// deriva e o sumiço das Fagulhas e os modificadores do jogador. Tudo determinístico (seed, época, célula z17 e janela):
/// amigos juntos veem o mesmo raio no mesmo ponto. O que é de cada aparelho (o clima forçado pelo debug, o efeito tocado no
/// mapa) entra por [forced] e [debugDrops] e não vai para mais ninguém. Dart puro.
library;

import '../data/relief_pack.dart';
import '../core/astro.dart' show sunAltitudeDeg;
import '../core/tiles.dart';
import 'water_field.dart';
import 'dart:math' as math;

import '../core/climate.dart';
import '../core/epochs.dart';
import '../core/fnv.dart';
import '../core/walkable.dart';
import '../core/weather.dart';
import '../core/windows.dart';
import 'spawn_field.dart';

/// Uma poça agora (época 7): centro (células z21, já na rua), raio em metros, tamanho de 0 a 1 (cresce na chuva, encolhe
/// secando), se ainda chove ([wet]) e os sorteios da janela de chuva dela.
class Puddle {
  const Puddle({required this.piece, required this.index, required this.x, required this.y, required this.radiusM, required this.size, required this.wet, required this.rolls});

  final PuddlePiece piece;
  final int index;
  final double x, y;
  final double radiusM;
  final double size;
  final bool wet;
  final ({double itemRoll, double spawnRoll, double pick, int uid}) rolls;

  bool get frozen => piece.frozen;
}

/// O que o clima de agora faz com o jogador (Aura, visão, sintonia, calma, rastros, tráfego, vento).
class PlayerClimate {
  const PlayerClimate({
    this.id = 'clear',
    this.auraAddM = 0,
    this.viewMaxM,
    this.toleranceMult = 1,
    this.wanderMult = 1,
    this.immuneSchool,
    this.calm = false,
    this.traceTimeMult = 1,
    this.playerTrails = false,
    this.ecoTracksM = 0,
    this.trafficMult = 1,
    this.walkerMult = 1,
    this.windHeadingRad = 0,
    this.windWindowStart = 0,
    this.runStartUtc = 0,
    this.prevId,
    this.prevStartUtc = 0,
    this.prevEndUtc = 0,
  });

  final String id;
  final double auraAddM;
  final double? viewMaxM;
  final double toleranceMult;
  final double wanderMult;
  final String? immuneSchool;
  final bool calm;
  final double traceTimeMult;
  final bool playerTrails;
  final double ecoTracksM;
  final double trafficMult;

  /// Os passantes fantasmas andam isto vezes mais devagar além de [trafficMult] (Geada forte).
  final double walkerMult;

  /// Direção do vento (radianos a partir do norte, sentido horário) e o começo da janela do clima (o tráfego lento conta
  /// daqui, igual em todos os aparelhos).
  final double windHeadingRad;
  final int windWindowStart;

  /// Desde quando (UTC) este clima vale sem parar aqui: o começo da primeira das janelas seguidas com ele.
  final int runStartUtc;

  /// O clima de antes deste no lugar e quando ele valeu: o que ele deixou no chão seca ou derrete depois do fim
  /// (`climate_form.dart`). `null`: nenhum.
  final String? prevId;
  final int prevStartUtc, prevEndUtc;

  /// A deriva do sinal na sintonia para a escola [school] (`null`: sem escola).
  double wanderFor(String? school) => school != null && school == immuneSchool ? 1 : wanderMult;

  static const none = PlayerClimate();
}

class ClimateWorld {
  ClimateWorld({
    required this.seed,
    required this.schedule,
    required this.speciesOfType,
    required this.itemExists,
    this.biomeAt,
    this.snapper,
    this.itemSince,
    this.water,
    this.relief,
    String? Function()? forced,
    this.forcedPhase,
  }) : forced = forced ?? _none;

  final int seed;
  final EpochSchedule schedule;

  /// O clima forçado pelo debug (qualquer id), ou `null`.
  final String? Function() forced;

  /// Há quanto tempo (segundos de clima, já com a velocidade do debug) o clima forçado começa do zero, e o forçado de antes
  /// dele, secando. Só neste aparelho. `null`: o forçado vale inteiro, como antes.
  final ForcedPhase Function()? forcedPhase;

  /// A espécie de Eco de um tipo (`water`; `any` para qualquer), escolhida por [pick] em `[0, 1)`. `null`: não há.
  final String? Function(String type, double pick) speciesOfType;
  final bool Function(String itemId) itemExists;

  /// A primeira época em que o item existe para o mundo (`since_epoch` do `items.json`; `null`: sempre). Antes dela o
  /// item vale como inexistente e a peça usa o fallback: criar o item numa versão nova não muda as épocas publicadas.
  final int? Function(String itemId)? itemSince;

  /// A chave de bioma de spawn da célula z20, para itens que só nascem em alguns biomas.
  final String? Function(int cx20, int cy20)? biomeAt;

  /// Os caminhos andáveis (o mesmo `WalkPaths` dos spawns): poças e zonas paradas da época 7 vão para a rua mais próxima.
  final PathSnapper? snapper;

  /// A água no relevo da época (`null` sem relevo ou em época sem `water`): onde as poças ficam.
  final WaterField? Function(Epoch epoch)? water;

  /// O relevo (`null`: terreno plano, a neblina vale igual em todo lugar).
  final ReliefSource? relief;

  /// Climas forçados por evento (`events.json` assinado). Trocados quando o feed chega.
  List<ClimateEvent> events = const [];

  /// Efeitos disparados pelo debug num ponto tocado: só neste aparelho.
  final debugDrops = <ClimateDrop>[];
  final debugZones = <ClimateZone>[];
  final debugArcs = <RainbowArc>[];

  final _dropCache = <(int, int, int, int, int), List<ClimateDrop>>{};
  final _zoneCache = <(int, int, int, int, int), List<ClimateZone>>{};
  final _spotCache = <(int, int, int, int), List<({int index, double x, double y, double radiusM, double depth})>>{};
  final _arcCache = <(int, int, int, int, bool), RainbowArc?>{};

  /// O modelo e a época que valem em [t]: os da época; com o clima forçado pelo debug numa época sem modelo, o da época mais
  /// nova que tem (só neste aparelho, para dar para testar antes da época 6 começar).
  /// Também quando o clima forçado só existe numa época mais nova (os climas da época 7 antes dela começar).
  (Epoch, ClimateModel)? modelAt(int t) {
    final e = schedule.select(t).epoch;
    final f = forced();
    if (e.climate != null && (f == null || e.climate!.defs.containsKey(f))) return (e, e.climate!);
    if (f == null) return null;
    for (final o in schedule.epochs.reversed) {
      if (o.climate != null && o.climate!.defs.containsKey(f)) return (e, o.climate!);
    }
    return e.climate == null ? null : (e, e.climate!);
  }

  /// O id do clima na célula z20 em [t]: o forçado, o do modelo completo (épocas 6+) ou o de quatro estados (épocas 3 a 5).
  /// É o que pesa nos spawns.
  String idAt(int cx20, int cy20, int t) => forced() ?? climateIdOfCell(schedule, seed, cx20, cy20, t, events: events);

  /// De onde vem o clima da célula z20 em [t]: debug, feed, calendário, astronomia ou estação. Sem modelo completo (épocas
  /// até a 5), o sorteio de quatro estados conta como estação.
  ClimateCause causeAt(int cx20, int cy20, int t) {
    final f = forced();
    if (f != null) return ClimateCause(f, source: ClimateSource.debug);
    final m = schedule.select(t).epoch.climate;
    if (m == null) return ClimateCause(idAt(cx20, cy20, t));
    final (rx, ry) = weatherRegionOfCell(cx20, cy20);
    return m.resolve(seed: seed, tUtc: t, rx: rx, ry: ry, events: events);
  }

  /// A definição do clima da célula z17 em [t], com o modelo e a época. `null` sem modelo.
  ({Epoch epoch, ClimateModel model, ClimateDef def, int window})? _defAt17(int cx17, int cy17, int t) {
    final me = modelAt(t);
    if (me == null) return null;
    final (epoch, model) = me;
    final id = forced() ?? model.at(seed: seed, tUtc: t, rx: cx17 >>> 5, ry: cy17 >>> 5, events: events);
    final def = model.def(id);
    return def == null ? null : (epoch: epoch, model: model, def: def, window: model.windowOf(t));
  }

  /// A definição do clima na célula z20 em [t] (o mesmo da z17 que a contém).
  ClimateDef? defAt(int cx20, int cy20, int t) => _defAt17(cx20 >>> 3, cy20 >>> 3, t)?.def;

  /// A neblina no lugar (células z21) em [t], da época 9 em diante e só nos climas de neblina: quão baixo é o lugar, a
  /// densidade (0 a 1) e o multiplicador da visão dos Ecos. `null` sem relevo ali, fora desses climas ou em época sem `fog`.
  ({double low, double density, double viewMult})? fogAt(double x21, double y21, int t, Epoch epoch, String climateId) {
    final fog = epoch.fog, r = relief;
    if (fog == null || r == null || !fog.climates.contains(climateId)) return null;
    final cx = x21.floor(), cy = y21.floor(), k = fog.ringCells, kd = (k * 0.7071).round();
    final h = r.h16At(cx, cy);
    if (h == null) return null;
    var ring = 0;
    for (final (dx, dy) in [(k, 0), (-k, 0), (0, k), (0, -k), (kd, kd), (-kd, kd), (kd, -kd), (-kd, -kd)]) {
      final v = r.h16At(cx + dx, cy + dy);
      if (v == null) return null;
      ring += v;
    }
    final low = fog.lowness(h, ring, water?.call(epoch)?.floodAt(cx, cy) ?? 0);
    final (lat, lon) = tileFractionToLatLon(x21, y21, biomeZoom);
    final sun = sunAltitudeDeg(lat, lon, t);
    return (low: low, density: fog.density(low, sun), viewMult: fog.viewMult(low, sun));
  }

  /// O que o clima da posição (células z21 fracionárias) faz com o jogador agora.
  PlayerClimate modsAt(double x21, double y21, int t) {
    final cx17 = x21.floor() >>> 4, cy17 = y21.floor() >>> 4;
    final d = _defAt17(cx17, cy17, t);
    if (d == null) return PlayerClimate(id: forced() ?? 'clear');
    final mod = d.def.modifier, mov = d.def.movement, tr = d.def.trails;
    final windowStart = d.window * d.model.windowS;
    final fp = forced() == null ? null : forcedPhase?.call();
    final int runStart, prevStart, prevEnd;
    final String? prevId;
    if (fp != null) {
      runStart = t - fp.ageS.round();
      prevId = fp.prevId;
      prevEnd = t - fp.prevSinceEndS.round();
      prevStart = prevEnd - fp.prevFormedS.round();
    } else {
      runStart = _runStart(cx17, cy17, d.def.id, windowStart, d.model.windowS);
      prevId = _defAt17(cx17, cy17, runStart - 1)?.def.id;
      prevEnd = runStart;
      prevStart = prevId == null ? runStart : _runStart(cx17, cy17, prevId, runStart - d.model.windowS, d.model.windowS);
    }
    return PlayerClimate(
      id: d.def.id,
      auraAddM: mod?.auraAddM ?? 0,
      viewMaxM: mod?.viewMaxM == null ? null : mod!.viewMaxM! * (fogAt(x21, y21, t, d.epoch, d.def.id)?.viewMult ?? 1),
      toleranceMult: mod?.toleranceMult ?? 1,
      wanderMult: mod?.wanderMult ?? 1,
      immuneSchool: mod?.immuneSchool,
      calm: mod?.calm ?? false,
      traceTimeMult: tr?.traceTimeMult ?? 1,
      playerTrails: tr?.player ?? false,
      ecoTracksM: tr?.ecoTracksM ?? 0,
      trafficMult: mov?.trafficMult ?? 1,
      walkerMult: mov?.walkerMult ?? 1,
      windHeadingRad: _heading(d, cx17, cy17, mov),
      windWindowStart: windowStart,
      runStartUtc: runStart,
      prevId: prevId,
      prevStartUtc: prevStart,
      prevEndUtc: prevEnd,
    );
  }

  /// O começo das janelas seguidas com o clima [id] (até 8 para trás): a neve que acumula não zera na virada da janela.
  int _runStart(int cx17, int cy17, String id, int start, int windowS) {
    var s = start;
    for (var k = 0; k < 8 && _defAt17(cx17, cy17, s - 1)?.def.id == id; k++) {
      s -= windowS;
    }
    return s;
  }

  double _heading(({Epoch epoch, ClimateModel model, ClimateDef def, int window}) d, int cx17, int cy17, MovementPiece? mov) =>
      mov?.headingDeg != null ? mov!.headingDeg! * math.pi / 180 : d.model.windHeading(seed, d.epoch.id, cx17 >>> 5, cy17 >>> 5, d.window);

  /// O relógio do tráfego do Véu (só desenho) na posição (células z21) em [t]: o tempo real, mais lento com `traffic_mult`
  /// (contado do começo da janela, igual em todos os aparelhos) e parado nos climas de `traffic_mult` 0 (o Silêncio). A parada
  /// congela no instante em que o Silêncio começa ali (o começo das janelas seguidas dele, ou o `starts_utc` do evento do
  /// feed, se for mais tarde) e acaba no fim delas (ou no `ends_utc`). Depois o relógio volta à hora real; quem estava
  /// parado volta a andar de onde parou ([trafficStopAt]: a simulação local só pausa). [sinceUtc]: o clima foi forçado pelo debug neste instante (a parada não
  /// começa antes). Com [walker], o dos passantes (Geada forte).
  double trafficClock(double x21, double y21, double t, {bool walker = false, double? sinceUtc}) {
    final cx = x21.floor() >>> 4, cy = y21.floor() >>> 4;
    final d = _defAt17(cx, cy, t.floor());
    if (d == null) return t;
    final ws = d.model.windowS, t0 = d.window * ws;
    final mov = d.def.movement;
    final mult = (mov?.trafficMult ?? 1) * (walker ? mov?.walkerMult ?? 1 : 1);
    final stop = _stopFor(cx, cy, d.window, ws, sinceUtc);
    if (stop != null && t >= stop.s && t < stop.e) return stop.s.toDouble();
    if (mult == 0) return t; // janela de Silêncio antes do começo do evento
    return mult == 1 ? t : t0 + (t - t0) * mult;
  }

  /// A parada do tráfego `[s, e)` (segundos UTC) que vale na posição (células z21) em [t]: a que está em curso ou a que
  /// acabou nesta janela ou na anterior. `null`: nenhuma. Igual em todos os aparelhos.
  ({int s, int e})? trafficStopAt(double x21, double y21, double t, {double? sinceUtc}) {
    final cx = x21.floor() >>> 4, cy = y21.floor() >>> 4;
    final d = _defAt17(cx, cy, t.floor());
    return d == null ? null : _stopFor(cx, cy, d.window, d.model.windowS, sinceUtc);
  }

  ({int s, int e})? _stopFor(int cx, int cy, int window, int ws, double? sinceUtc) {
    final key = (cx, cy, window, sinceUtc?.floor(), events);
    if (key != _stopKey) {
      _stopKey = key;
      _stop = _trafficStop(cx, cy, window, ws, sinceUtc?.floor());
    }
    return _stop;
  }

  (int, int, int, int?, List<ClimateEvent>)? _stopKey;
  ({int s, int e})? _stop;

  bool _stopped(int cx17, int cy17, int t) => (_defAt17(cx17, cy17, t)?.def.movement?.trafficMult ?? 1) == 0;

  /// A parada do tráfego `[s, e)` que vale na janela [window]: a da própria janela ou a que acabou na anterior (até 8 janelas
  /// seguidas para trás e para a frente). `null`: nenhuma.
  ({int s, int e})? _trafficStop(int cx17, int cy17, int window, int ws, int? since) {
    final int last;
    if (_stopped(cx17, cy17, window * ws)) {
      last = window;
    } else if (_stopped(cx17, cy17, (window - 1) * ws)) {
      last = window - 1;
    } else {
      return null;
    }
    var first = last, end = last;
    while (first > last - 8 && _stopped(cx17, cy17, (first - 1) * ws)) {
      first--;
    }
    while (end < last + 8 && _stopped(cx17, cy17, (end + 1) * ws)) {
      end++;
    }
    var s = first * ws, e = (end + 1) * ws;
    if (forced() == null) {
      final id = _defAt17(cx17, cy17, last * ws)!.def.id;
      // O feed manda na janela cujo meio cai no evento: o horário dele é o começo e o fim de verdade.
      for (final ev in events) {
        if (ev.climate != id) continue;
        final m0 = first * ws + ws ~/ 2, m1 = end * ws + ws ~/ 2;
        if (m0 >= ev.startsUtc && m0 < ev.endsUtc) s = math.max(s, ev.startsUtc);
        if (m1 >= ev.startsUtc && m1 < ev.endsUtc) e = math.min(e, ev.endsUtc);
      }
    }
    if (since != null) s = math.max(s, since);
    return e > s ? (s: s, e: e) : null;
  }

  /// Níveis a mais nos Ecos da célula z20 (Tempestade de Ecos).
  int levelAddAt(int cx20, int cy20, int t) => defAt(cx20, cy20, t)?.modifier?.levelAdd ?? 0;

  /// A Fagulha do sorteio normal com o clima: deriva com o vento ou some depois do tempo de vida. [windowStart] é o começo da
  /// janela de 20 minutos da célula dela. `null`: sumiu.
  WorldSpawn? adjustSpark(WorldSpawn s, int windowStart, int t, double metersPerCell21) {
    if (!s.isSpark) return s;
    final d = _defAt17(s.cellX >>> 3, s.cellY >>> 3, t);
    final mov = d?.def.movement;
    if (d == null || mov == null) return s;
    final age = t - windowStart;
    if (mov.sparkTtlS != null && age > mov.sparkTtlS!) return null;
    if (mov.sparkDriftMps <= 0) return s;
    final m = math.min(mov.sparkDriftMps * age, mov.driftMaxM) / metersPerCell21;
    final h = _heading(d, s.cellX >>> 3, s.cellY >>> 3, mov);
    return s.movedTo(s.x + math.sin(h) * m, s.y - math.cos(h) * m);
  }

  Iterable<(int, int)> _cells17(double x21, double y21, double r21) sync* {
    for (var cy = ((y21 - r21) / 16).floor(); cy <= ((y21 + r21) / 16).floor(); cy++) {
      for (var cx = ((x21 - r21) / 16).floor(); cx <= ((x21 + r21) / 16).floor(); cx++) {
        yield (cx, cy);
      }
    }
  }

  void _trim() {
    // A camada do mapa lê até 1,5 km e 3 h para trás (crateras): cabe com folga, sem esvaziar a cada leitura.
    if (_dropCache.length > 320) _dropCache.clear();
    if (_zoneCache.length > 1200) _zoneCache.clear(); // a Procissão é lida até ~1 km em volta
  }

  /// Os acontecimentos das quedas (raio, granizo, meteoro...) perto de (x21, y21) com tempo em `[tFrom, tTo]`, das janelas
  /// do clima que tocam esse intervalo. Inclui os disparados pelo debug.
  List<ClimateDrop> dropsNear(double x21, double y21, double radius21, int tFrom, int tTo) {
    _trim();
    final out = <ClimateDrop>[];
    final seen = <int>{};
    for (final t in {tFrom, tTo}) {
      for (final (cx, cy) in _cells17(x21, y21, radius21)) {
        final d = _defAt17(cx, cy, t);
        if (d == null) continue;
        for (var i = 0; i < d.def.pieces.length; i++) {
          final p = d.def.pieces[i];
          if (p is! DropPiece) continue;
          final list = _dropCache.putIfAbsent((d.epoch.id * 64 + i, cx, cy, d.window, d.def.id.hashOfId), () => d.model.drops(seed, d.epoch.id, cx, cy, d.window, i, p));
          // A lista está em ordem de tempo: começa do primeiro a partir de tFrom (busca binária).
          var lo = 0, hi = list.length;
          while (lo < hi) {
            final mid = (lo + hi) ~/ 2;
            if (list[mid].tUtc < tFrom) {
              lo = mid + 1;
            } else {
              hi = mid;
            }
          }
          for (var k = lo; k < list.length && list[k].tUtc <= tTo; k++) {
            if (seen.add(list[k].uid)) out.add(list[k]);
          }
        }
      }
    }
    for (final drop in debugDrops) {
      if (drop.tUtc >= tFrom && drop.tUtc <= tTo) out.add(drop);
    }
    return out;
  }

  /// As zonas ativas em [t] perto de (x21, y21), mais as do debug. Para o desenho: [movingExtra21] procura as zonas que
  /// andam (a Procissão, o funil) também nas células mais longe, de onde elas podem ter vindo andando, e [lookBackS] traz
  /// as que andam e acabaram há até isso (o rastro de velas que fica). Os padrões são os do mundo (`extras`).
  List<ClimateZone> zonesNear(double x21, double y21, double radius21, int t, {double movingExtra21 = 0, int lookBackS = 0}) {
    _trim();
    final out = <ClimateZone>[];
    final seen = <int>{};
    final memo = <(int, int, int), ({Epoch epoch, ClimateModel model, ClimateDef def, int window})?>{};
    bool keep(ClimateZone z) {
      if (z.activeAt(t)) return true;
      return lookBackS > 0 && z.piece.speedMps > 0 && t >= z.startUtc && t < z.endUtc + lookBackS;
    }

    for (final tt in {t, if (lookBackS > 0) t - lookBackS}) {
      for (final (cx, cy) in _cells17(x21, y21, radius21 + movingExtra21)) {
        final far = movingExtra21 > 0 && ((cx + 0.5) * 16 - x21).abs() > radius21 + 8 || movingExtra21 > 0 && ((cy + 0.5) * 16 - y21).abs() > radius21 + 8;
        final d = forced() != null ? _defAt17(cx, cy, tt) : memo.putIfAbsent((cx >>> 5, cy >>> 5, tt), () => _defAt17(cx, cy, tt));
        if (d == null) continue;
        for (var i = 0; i < d.def.pieces.length; i++) {
          final p = d.def.pieces[i];
          if (p is! ZonePiece || (far && p.speedMps <= 0)) continue;
          final list = _zoneCache.putIfAbsent((d.epoch.id * 64 + i, cx, cy, d.window, d.def.id.hashOfId), () => [for (final z in d.model.zones(seed, d.epoch.id, cx, cy, d.window, i, p)) ?_snapZone(z)]);
          for (final z in list) {
            if (keep(z) && seen.add(z.uidBase)) out.add(z);
          }
        }
      }
    }
    out.addAll(debugZones.where(keep));
    for (final a in rainbowsNear(x21, y21, radius21, t)) {
      out.add(a.foot);
    }
    return out;
  }

  /// Época 8: o arco-íris da região z12 `(rx, ry)` em [t], com o pé já na rua (o primeiro candidato que cai a menos de
  /// 35 m de um caminho; sem nenhum, o primeiro). Com o clima do arco-íris forçado pelo debug, vale a janela inteira, só
  /// neste aparelho. `null`: sem arco agora.
  RainbowArc? rainbowIn(int rx, int ry, int t) {
    final me = modelAt(t);
    if (me == null) return null;
    var (epoch, model) = me;
    final f = forced();
    // Forçado pelo debug antes da época 8: o arco da época mais nova que tem (só neste aparelho).
    if (f != null && model.rainbow == null) model = schedule.epochs.reversed.map((e) => e.climate).firstWhere((m) => m?.rainbow != null, orElse: () => model) ?? model;
    final rb = model.rainbow;
    if (rb == null || (f != null && f != rb.$1)) return null;
    final w = model.windowOf(t);
    if (_arcCache.length > 64) _arcCache.clear();
    final arc = _arcCache.putIfAbsent((epoch.id, rx, ry, w, f != null), () {
      final a = model.rainbowAt(seed, epoch.id, rx, ry, w, events: events, forcedRainbow: f != null);
      if (a == null) return null;
      for (final (x, y) in a.spots) {
        if (_toStreet(x, y) case final p?) return a.placed(p.$1, p.$2);
      }
      return a;
    });
    return arc != null && arc.activeAt(t) ? arc : null;
  }

  /// Os arcos ativos em [t] com o pé a até [radius21] células z21 de (x21, y21), mais os do debug.
  List<RainbowArc> rainbowsNear(double x21, double y21, double radius21, int t) {
    final out = <RainbowArc>[];
    for (var ry = (y21 - radius21).floor() >>> 9; ry <= (y21 + radius21).floor() >>> 9; ry++) {
      for (var rx = (x21 - radius21).floor() >>> 9; rx <= (x21 + radius21).floor() >>> 9; rx++) {
        final a = rainbowIn(rx, ry, t);
        if (a != null) out.add(a);
      }
    }
    out.addAll(debugArcs.where((a) => a.activeAt(t)));
    return [for (final a in out) if (math.sqrt((a.footX - x21) * (a.footX - x21) + (a.footY - y21) * (a.footY - y21)) <= radius21) a];
  }

  /// A zona parada com `snap` vai para a rua mais próxima (como os spawns); sem rua a menos de 35 m, ela não existe.
  ClimateZone? _snapZone(ClimateZone z) {
    if (!z.piece.snap || z.piece.speedMps > 0) return z;
    final p = _toStreet(z.x0, z.y0);
    if (p == null) return null;
    return ClimateZone(piece: z.piece, pieceIndex: z.pieceIndex, index: z.index, x0: p.$1, y0: p.$2, headingRad: z.headingRad, startUtc: z.startUtc, endUtc: z.endUtc, slots: z.slots, uidBase: z.uidBase);
  }

  /// O ponto (células z21) levado ao caminho andável mais próximo da célula z20 dele. Sem caminhos ligados (testes), fica onde
  /// está; `null`: a célula não tem rua, só tem rodovia, ou nada a menos de 35 m (poça e duna só existem na rua).
  (double, double)? _toStreet(double x21, double y21) {
    final s = snapper;
    if (s == null) return (x21, y21);
    final cx20 = x21.floor() >>> 1, cy20 = y21.floor() >>> 1;
    final snap = s.snap(cx20, cy20, x21 / 2 - cx20, y21 / 2 - cy20);
    if (snap == null || !snap.keep) return null;
    return ((cx20 + snap.px) * 2, (cy20 + snap.py) * 2);
  }

  /// As poças (época 7) perto de (x21, y21) em [t]: as da chuva desta janela, crescendo, e as da janela anterior, secando.
  /// Os pontos são fixos por célula; o tamanho e os sorteios saem da janela de chuva. Sem modelo ou sem poças: nenhuma.
  List<Puddle> puddlesNear(double x21, double y21, double radius21, int t) {
    final out = <Puddle>[];
    if (_spotCache.length > 256) _spotCache.clear();
    for (final (cx, cy) in _cells17(x21, y21, radius21)) {
      final d = _defAt17(cx, cy, t);
      if (d == null) continue;
      final start = d.window * d.model.windowS;
      final cur = d.def.puddles;
      final PuddlePiece piece;
      final int wetWindow;
      final double size;
      double? dried; // quanto já secou (só depois da chuva)
      final fp = forced() == null ? null : forcedPhase?.call();
      if (fp != null) {
        // O clima forçado começa do zero quando foi forçado, e o de antes seca a partir dali (só neste aparelho).
        final prev = fp.prevId == null ? null : d.model.def(fp.prevId!)?.puddles;
        if (cur != null) {
          piece = cur;
          size = cur.always ? 1.0 : math.min(1.0, fp.ageS / cur.growS);
        } else if (prev != null && !prev.always) {
          piece = prev;
          dried = fp.prevSinceEndS / prev.dryS;
          size = math.min(1.0, fp.prevFormedS / prev.growS) - dried;
        } else {
          continue;
        }
        wetWindow = d.window;
      } else if (cur != null) {
        piece = cur;
        wetWindow = d.window;
        final before = cur.always ? null : _defAt17(cx, cy, start - 1)?.def.puddles;
        size = cur.always || (before != null && !before.always) ? 1.0 : math.min(1.0, (t - start) / cur.growS);
      } else {
        final before = _defAt17(cx, cy, start - 1)?.def.puddles;
        if (before == null || before.always) continue; // o gelo derrete junto com a Geada
        piece = before;
        wetWindow = d.window - 1;
        dried = (t - start) / before.dryS;
        size = 1 - dried;
      }
      if (size <= 0 && (dried == null || d.epoch.water == null)) continue;
      final epochId = d.epoch.id;
      // Da época 9 em diante, com relevo: as poças ficam onde a água para de verdade; a mais funda é a maior. Sem relevo
      // no lugar, os pontos sorteados pela seed de antes.
      final wet = d.epoch.water == null ? null : water?.call(d.epoch)?.spots(cx, cy, piece.perCell);
      final (rLo, rHi) = piece.radiusM;
      final spots = _spotCache.putIfAbsent((epochId, cx, cy, piece.perCell), () => [
            for (final s in wet ?? const <WaterSpot>[])
              if (_toStreet(s.x, s.y) case final p?) (index: s.index, x: p.$1, y: p.$2, radiusM: rLo + (rHi - rLo) * s.depth, depth: s.depth),
            if (wet == null)
              for (final s in puddleSpots(seed, epochId, cx, cy, piece))
                if (_toStreet(s.x, s.y) case final p?) (index: s.index, x: p.$1, y: p.$2, radiusM: s.radiusM, depth: 0.0),
          ]);
      final bonus = d.epoch.water?.dryDepthBonus ?? 0;
      for (final s in spots) {
        // Secando, as baixadas mais fundas duram mais.
        final sz = dried == null ? size : size + dried * (1 - 1 / (1 + bonus * s.depth));
        if (sz <= 0) continue;
        out.add(Puddle(piece: piece, index: s.index, x: s.x, y: s.y, radiusM: s.radiusM, size: math.min(1.0, sz), wet: cur != null, rolls: puddleRolls(seed, epochId, cx, cy, wetWindow, s.index)));
      }
    }
    return out;
  }

  /// O que as peças fazem nascer em volta de (x21, y21) em [t]: Ecos e itens com uid próprio, como os spawns normais.
  /// [levelOf] dá o nível do Eco a partir do acréscimo sorteado (o nível é individual).
  List<WorldSpawn> extras({
    required double x21,
    required double y21,
    required double radiusM,
    required int t,
    required double metersPerCell21,
    required int Function(String speciesId, int levelAdd, int uid) levelOf,
  }) {
    final r21 = radiusM / metersPerCell21;
    final out = <WorldSpawn>[];
    // Quedas: vivem do instante da queda até o fim do tempo de vida (até 3 h, então basta olhar a janela anterior).
    for (final drop in dropsNear(x21, y21, r21, t - 3 * 3600, t)) {
      final p = drop.piece;
      final spawn = p.spawn, item = p.item;
      if (spawn != null && drop.spawnRoll < spawn.chance && t < drop.tUtc + spawn.ttlS) {
        final s = _eco(spawn, drop.pick, drop.x, drop.y, fnv1a64([drop.uid, 1]), t, levelOf);
        if (s != null) out.add(s);
      }
      if (item != null && drop.itemRoll < item.chance && t < drop.tUtc + item.ttlS) {
        final s = _item(item, drop.pick, drop.x + 0.3, drop.y + 0.3, fnv1a64([drop.uid, 2]), drop.tUtc);
        if (s != null) out.add(s);
      }
      final item2 = p.item2; // a cratera: o mesmo sorteio do item, outro uid
      if (item2 != null && drop.itemRoll < item2.chance && t < drop.tUtc + item2.ttlS) {
        final s = _item(item2, drop.pick, drop.x - 0.3, drop.y + 0.2, fnv1a64([drop.uid, 3]), drop.tUtc);
        if (s != null) out.add(s);
      }
    }
    final linger = _lingerS(t);
    for (final z in zonesNear(x21, y21, r21, t, lookBackS: linger, movingExtra21: linger > 0 ? 1200 / metersPerCell21 : 0)) {
      final p = z.piece;
      final n = z.slots.length;
      for (var j = 0; j < n; j++) {
        final slot = z.slots[j];
        // Zona que anda deixa o que nasce pelo caminho: a vaga j aparece na fração (j + 0,5) / n do percurso.
        // Com `slot_at` (época 7), todas aparecem naquele ponto do percurso: o fim do rastro da Procissão.
        final tj = p.speedMps > 0 ? z.startUtc + ((p.slotAt ?? (j + 0.5) / n) * p.durationS).floor() : z.startUtc;
        if (t < tj) continue;
        if (!z.activeAt(t) && !(p.streetRoute && t < tj + (p.spawn?.ttlS ?? 0))) continue;
        var (cx, cy) = z.centerAt(tj.toDouble(), metersPerCell21);
        if (p.streetRoute) (cx, cy) = _toStreet(cx, cy) ?? (cx, cy);
        final rr = p.streetRoute ? 0.0 : p.radiusM / metersPerCell21; // pela rua: no fim da rota, em cima das velas
        final x = cx + slot.dx * rr, y = cy + slot.dy * rr;
        final spawn = p.spawn, item = p.item;
        if (spawn != null && j < spawn.perZone && slot.roll < spawn.chance) {
          final s = _eco(spawn, slot.pick, x, y, fnv1a64([z.uidBase, j, 1]), t, levelOf);
          if (s != null) out.add(s);
        }
        if (item != null && j < item.perZone && slot.roll2 < item.chance) {
          final s = _item(item, slot.pick, x + 0.3, y + 0.3, fnv1a64([z.uidBase, j, 2]), z.startUtc);
          if (s != null && (item.revealM == null || s.distanceM(x21, y21, metersPerCell21) <= item.revealM!)) out.add(s); // a duna esconde
        }
      }
    }
    // Poças: água pura (ou o cristal da poça congelada) enquanto têm água, e o Eco de Água enquanto chove.
    for (final pd in puddlesNear(x21, y21, r21, t)) {
      final spawn = pd.piece.spawn, item = pd.piece.item, r = pd.rolls;
      if (spawn != null && pd.wet && r.spawnRoll < spawn.chance) {
        final s = _eco(spawn, r.pick, pd.x, pd.y, fnv1a64([r.uid, 1]), t, levelOf);
        if (s != null) out.add(s);
      }
      if (item != null && pd.size >= 0.3 && r.itemRoll < item.chance) {
        final s = _item(item, r.pick, pd.x + 0.3, pd.y + 0.3, fnv1a64([r.uid, 2]), t);
        if (s != null) out.add(s);
      }
    }
    return [for (final s in out) if (s.distanceM(x21, y21, metersPerCell21) <= radiusM) s];
  }

  /// Quanto (s) as zonas com `street_route` do clima de agora mantêm o que nasceu depois de acabar: 0 até a época 7.
  int _lingerS(int t) {
    var m = 0;
    for (final def in modelAt(t)?.$2.defs.values ?? const <ClimateDef>[]) {
      for (final p in def.pieces) {
        if (p is ZonePiece && p.streetRoute) m = math.max(m, p.durationS + (p.spawn?.ttlS ?? 0));
      }
    }
    return m;
  }

  WorldSpawn? _eco(PieceSpawn spawn, double pick, double x, double y, int uid, int t, int Function(String, int, int) levelOf) {
    final species = speciesOfType(spawn.type, pick) ?? spawn.fallbackSpecies;
    if (species == null) return null; // tipo sem espécie no jogo e sem fallback: o dado fica sem efeito
    final (lo, hi) = spawn.levelAdd;
    final add = lo + (pick * 1000).floor() % (hi - lo + 1);
    final cx20 = x.floor() >>> 1, cy20 = y.floor() >>> 1;
    return WorldSpawn(
      uid: uid,
      kind: 'eco',
      entryId: species,
      quantity: 1,
      x: x,
      y: y,
      cellX: cx20,
      cellY: cy20,
      window: windowIndex(seed, cx20, cy20, t),
      level: levelOf(species, add, uid),
      tag: spawn.tag,
    );
  }

  /// O item existe para o mundo na época de [t] (ver [itemSince]).
  bool _exists(String id, int t) {
    if (!itemExists(id)) return false;
    final since = itemSince?.call(id);
    return since == null || schedule.select(t).epoch.id >= since;
  }

  WorldSpawn? _item(PieceItem item, double pick, double x, double y, int uid, int t) {
    final cx20 = x.floor() >>> 1, cy20 = y.floor() >>> 1;
    if (item.biomes != null && !item.biomes!.contains(biomeAt?.call(cx20, cy20))) return null;
    var id = item.ids[(pick * item.ids.length).floor().clamp(0, item.ids.length - 1)];
    if (!_exists(id, t)) {
      final f = item.fallback;
      if (f == null || !_exists(f, t)) return null; // item que ainda não existe e sem fallback: sem efeito
      id = f;
    }
    final (lo, hi) = item.qty;
    return WorldSpawn(
      uid: uid,
      kind: item.kind == 'spark' ? 'spark' : 'material',
      entryId: id,
      quantity: lo + (pick * 997).floor() % (hi - lo + 1),
      x: x,
      y: y,
      cellX: cx20,
      cellY: cy20,
      window: 0,
      tag: item.tag,
    );
  }

  /// Debug: dispara a peça [pieceName] (de qualquer clima) no ponto (x21, y21) em [t], só neste aparelho. Com criatura ou
  /// item, eles nascem com certeza. Devolve `false` se nenhum clima tem a peça.
  bool debugTrigger(String pieceName, double x21, double y21, int t) {
    // O modelo de agora primeiro; depois os das outras épocas, do mais novo (as peças da época 7 antes dela começar).
    final models = {?modelAt(t)?.$2, for (final e in schedule.epochs.reversed) ?e.climate};
    for (final def in models.expand((m) => m.defs.values)) {
      for (var p in def.pieces) {
        if (p.name != pieceName) continue;
        final uid = fnv1a64([seed, t, (x21 * 1000).round(), (y21 * 1000).round(), salt('DBGFX')]);
        if (p is RainbowPiece) {
          // O arco do debug: o pé no ponto tocado, com o material e o Eco certos, pelo tempo mais longo do arco.
          debugArcs.add(RainbowArc(
            piece: p, startUtc: t, endUtc: t + p.durationS.$2, headingRad: (uid >>> 40) / (1 << 24) * 2 * math.pi, uid: uid,
            spots: [(x21, y21)], slot: (dx: 0.0, dy: 0.0, roll: 0.0, roll2: 0.0, pick: 0.5),
          ));
          return true;
        }
        if (p is PuddlePiece) {
          p = ZonePiece(p.name, ghost: false, perCell: 1, radiusM: p.radiusM.$2.toDouble(), durationS: 1800, speedMps: 0, spawn: p.spawn, item: p.item);
        }
        if (p is DropPiece) {
          debugDrops.add(ClimateDrop(piece: p, pieceIndex: -1, index: debugDrops.length, tUtc: t, x: x21, y: y21, spawnRoll: 0, itemRoll: 0, pick: (uid >>> 40) / (1 << 24), uid: uid));
          return true;
        }
        if (p is ZonePiece) {
          debugZones.add(ClimateZone(
            piece: p, pieceIndex: -1, index: debugZones.length, x0: x21, y0: y21, headingRad: (uid >>> 40) / (1 << 24) * 2 * math.pi,
            startUtc: t, endUtc: t + p.durationS, uidBase: uid,
            slots: [for (var j = 0; j < math.max(p.spawn?.perZone ?? 0, p.item?.perZone ?? 0); j++) (dx: 0.3 * j, dy: 0.0, roll: 0.0, roll2: 0.0, pick: 0.5)],
          ));
          return true;
        }
      }
    }
    return false;
  }
}

String? _none() => null;

/// O clima forçado pelo debug no tempo: há quanto ele vale ([ageS]) e o forçado de antes ([prevId]), que formou por
/// [prevFormedS] e acabou há [prevSinceEndS]. Segundos de clima (a velocidade do debug já entra).
typedef ForcedPhase = ({double ageS, String? prevId, double prevFormedS, double prevSinceEndS});

/// O clima determinístico (id) da célula z20 em [t], sem o debug: o do modelo completo da época ativa (6 em diante, com os
/// eventos do feed) ou o de quatro estados (épocas 3 a 5). O modelo é o da época ATIVA naquele instante, nunca o da mais
/// nova. O app e a Patrulha chegam aqui por `seedWeatherOfCell` (`ui/map/map_assets.dart`).
String climateIdOfCell(EpochSchedule schedule, int seed, int cx20, int cy20, int t, {List<ClimateEvent> events = const []}) {
  final e = schedule.select(t).epoch;
  final (rx, ry) = weatherRegionOfCell(cx20, cy20);
  final m = e.climate;
  if (m != null) return m.at(seed: seed, tUtc: t, rx: rx, ry: ry, events: events);
  return e.ecoV2?.weather.at(seed: seed, tUtc: t, regionX: rx, regionY: ry).id ?? 'clear';
}

extension on String {
  /// Chave estável do id do clima para os caches (FNV dos bytes, estável entre execuções).
  int get hashOfId => fnv1a64Bytes(codeUnits);
}
