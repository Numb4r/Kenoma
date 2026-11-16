/// Clima e evento em camadas (época 12 em diante; docs/GDD.md, "Tempo, astronomia e clima", rev 356). O clima é um de cada
/// vez, por janela de 3 h (`climate.dart`). O evento fica por cima de qualquer clima, com duração própria: até
/// [ClimateModel.maxEvents] ao mesmo tempo, e um a mais espera o fim de um deles, com prioridade feed, astronomia,
/// calendário e sorteio. Cada evento declara o que precisa (dia ou noite, climas); sem isso ele espera. A pilha de um lugar
/// e instante é o id `clima+evento+evento` ([stackIdOf]), que [mergeStack] monta numa definição só: as peças do clima com os
/// fluxos de sempre, as de cada evento com fluxo próprio, o spawn somado com teto e os modificadores juntos. Dart puro.
///
/// Tudo é função da seed, da região do clima (tile z12), do relógio e do feed assinado: amigos na mesma região veem os
/// mesmos eventos, com o mesmo começo e o mesmo fim.
library;

import 'dart:math' as math;

import 'astro.dart' show sunAltitudeDeg;
import 'climate.dart';
import 'fnv.dart';
import 'pcg32.dart';
import 'tiles.dart';
import 'veil_calendar.dart' show saltCalendar;

/// Sal do sorteio dos eventos que vêm do sorteio (o Tornado raro na Tempestade e no Vendaval, a chance do arco-íris).
final int saltEventDraw = salt('EVD12');

/// O clima de uma pilha (`storm+vigil` → `storm`).
String climateOfStack(String id) {
  final i = id.indexOf('+');
  return i < 0 ? id : id.substring(0, i);
}

/// Os eventos de uma pilha (`storm+vigil` → `[vigil]`).
List<String> eventsOfStack(String id) {
  final parts = id.split('+');
  return parts.length < 2 ? const [] : parts.sublist(1);
}

/// O id canônico da pilha: o clima e os eventos na ordem dos dados (a mesma pilha dá sempre o mesmo id, venha o evento de
/// onde vier). Eventos desconhecidos ou repetidos ficam de fora.
String stackIdOf(ClimateModel m, String climate, Iterable<String> events) {
  final evs = {for (final e in events) if (m.eventDefs.containsKey(e)) e}.toList()..sort((a, b) => m.eventDefs[a]!.ordinal - m.eventDefs[b]!.ordinal);
  return evs.isEmpty ? climate : [climate, ...evs].join('+');
}

/// De onde veio um evento, na ordem da prioridade da vaga.
enum EventSource { feed, astro, calendar, draw, debug }

/// O que o evento precisa para acontecer: dia ou noite ([light], pelo sol no centro da região) e um dos [climates].
class EventRequirement {
  const EventRequirement({this.light, this.climates});

  factory EventRequirement.fromJson(Map<String, dynamic>? j) => j == null
      ? const EventRequirement()
      : EventRequirement(light: j['light'] as String?, climates: (j['climates'] as List<dynamic>?)?.cast<String>().toSet());

  /// `day` ou `night`; `null`: qualquer hora.
  final String? light;
  final Set<String>? climates;

  bool get any => light == null && climates == null;

  bool holds(double sunAltDeg, String climate) {
    if (light == 'day' && sunAltDeg <= 0) return false;
    if (light == 'night' && sunAltDeg >= 0) return false;
    return climates == null || climates!.contains(climate);
  }
}

/// O tingimento que o evento aplica à precipitação de alguns climas (a Lua Carmim na chuva e na garoa vira a Chuva Carmim):
/// as poças desses climas viram [puddles]. O desenho do tingimento mora no `eventos.json`.
class EventTint {
  const EventTint({required this.climates, this.puddles});

  final Set<String> climates;
  final PuddlePiece? puddles;
}

/// Um evento da época: o spawn e as peças (no mesmo formato dos climas), o requisito, o tingimento e, para os que vêm do
/// sorteio, a chance por janela de 3 h nos climas pedidos e a duração. [ordinal] é a posição nos dados (o id da pilha e o
/// fluxo dos sorteios das peças dele).
class EventDef {
  const EventDef({required this.id, required this.ordinal, required this.def, this.requires = const EventRequirement(), this.tint, this.draw});

  factory EventDef.fromJson(String id, int ordinal, Map<String, dynamic> j) {
    final t = j['tint'] as Map<String, dynamic>?;
    final d = j['draw'] as Map<String, dynamic>?;
    final puddles = t?['puddles'] == null ? null : ClimatePiece.fromJson({'piece': 'puddles', ...t!['puddles'] as Map<String, dynamic>});
    return EventDef(
      id: id,
      ordinal: ordinal,
      def: ClimateDef.fromJson(id, {...j, 'category': 'event'}),
      requires: EventRequirement.fromJson(j['requires'] as Map<String, dynamic>?),
      tint: t == null ? null : EventTint(climates: (t['climates'] as List<dynamic>).cast<String>().toSet(), puddles: puddles as PuddlePiece?),
      draw: d == null
          ? null
          : (
              chance: (d['chance'] as num).toDouble(),
              climates: (d['climates'] as List<dynamic>).cast<String>().toSet(),
              durationS: ((d['duration_s'] as List<dynamic>)[0] as num).toInt(),
              durationMaxS: ((d['duration_s'] as List<dynamic>)[1] as num).toInt(),
            ),
    );
  }

  final String id;
  final int ordinal;
  final ClimateDef def;
  final EventRequirement requires;
  final EventTint? tint;
  final ({double chance, Set<String> climates, int durationS, int durationMaxS})? draw;
}

/// Uma combinação de clima e evento com efeito próprio (só as três do GDD): o raio cai na zona do evento ([boltsAt]: peça
/// do clima → zona do evento), troca o que nasce de algumas peças ([spawnPatch]) e soma peças e spawn.
class ComboDef {
  const ComboDef({required this.id, required this.climate, required this.event, this.boltsAt = const {}, this.spawnPatch = const {}, this.pieces = const [], this.spawn = const {}, this.visual = const {}});

  factory ComboDef.fromJson(Map<String, dynamic> j) => ComboDef(
        id: j['id'] as String,
        climate: j['climate'] as String,
        event: j['event'] as String,
        boltsAt: {for (final e in ((j['bolts_at'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as String},
        spawnPatch: {for (final e in ((j['spawn_patch'] as Map<String, dynamic>?) ?? const {}).entries) e.key: PieceSpawn.fromJson(e.value as Map<String, dynamic>)},
        pieces: [for (final p in (j['pieces'] as List<dynamic>?) ?? const []) ClimatePiece.fromJson(p as Map<String, dynamic>)],
        spawn: {for (final e in ((j['spawn'] as Map<String, dynamic>?) ?? const {}).entries) e.key: (e.value as num).toDouble()},
        visual: {for (final e in ((j['visual'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as String},
      );

  final String id;
  final String climate;
  final String event;
  final Map<String, String> boltsAt;
  final Map<String, PieceSpawn> spawnPatch;
  final List<ClimatePiece> pieces;
  final Map<String, double> spawn;

  /// A peça do clima ganha outro visual na combinação (`lightning` → `lightning_crimson`: o raio vermelho). Só desenho.
  final Map<String, String> visual;

  ClimatePiece apply(ClimatePiece p) {
    final patch = spawnPatch[p.name];
    final zone = boltsAt[p.name];
    if (p is DropPiece && (patch != null || zone != null || visual[p.name] != null)) return p.copyWith(spawn: patch, atZone: zone, name: visual[p.name]);
    if (p is ZonePiece && patch != null) return p.copyWith(spawn: patch);
    return p;
  }
}

/// Um evento em curso: o id, de onde veio, a regra ou o evento do feed que o trouxe ([cause]: `sexta_dos_olhos`,
/// `crimson_moon`...), o começo e o fim de verdade (com a espera pela vaga e pelo requisito) e o começo natural.
class ActiveEvent {
  const ActiveEvent({required this.id, required this.source, this.cause, required this.startUtc, required this.endUtc, required this.naturalStartUtc, this.reason, this.maxUtc});

  final String id;
  final EventSource source;
  final String? cause;
  final int startUtc, endUtc, naturalStartUtc;
  final String? reason;
  final int? maxUtc;

  /// Esperou a vaga ou o requisito.
  bool get waited => startUtc > naturalStartUtc;

  bool activeAt(num t) => t >= startUtc && t < endUtc;
}

/// O clima e os eventos de um lugar num instante.
class ClimateStack {
  ClimateStack(this.model, this.cause, this.events);

  final ClimateModel model;
  final ClimateCause cause;
  final List<ActiveEvent> events;

  String get climate => cause.climate;
  late final String id = stackIdOf(model, climate, events.map((e) => e.id));

  /// As combinações com efeito próprio que valem agora.
  List<ComboDef> get combos => [for (final c in model.combos) if (c.climate == climate && events.any((e) => e.id == c.event)) c];
}

/// Monta a pilha [id] (`clima+evento+evento`). `null` se alguma parte não existe.
ClimateDef? mergeStack(ClimateModel m, String id) {
  final parts = id.split('+');
  final c = m.defs[parts.first];
  if (c == null) return null;
  final evs = <EventDef>[];
  for (final e in parts.skip(1)) {
    final ev = m.eventDefs[e];
    if (ev == null) return null;
    evs.add(ev);
  }
  final combos = [for (final k in m.combos) if (k.climate == c.id && evs.any((e) => e.id == k.event)) k];
  final tint = [for (final e in evs) if (e.tint case final t? when t.climates.contains(c.id) && t.puddles != null) t].firstOrNull;
  ClimatePiece patch(ClimatePiece p) => combos.fold(p, (q, k) => k.apply(q));
  final pieces = <ClimatePiece>[], streams = <int>[], owners = <String?>[];
  for (final (i, p) in c.pieces.indexed) {
    pieces.add(patch(p is PuddlePiece && tint != null ? tint.puddles! : p));
    streams.add(i);
    owners.add(null);
  }
  for (final e in evs) {
    for (final (k, p) in e.def.pieces.indexed) {
      pieces.add(patch(p));
      streams.add(64 + e.ordinal * 8 + k);
      owners.add(e.id);
    }
  }
  for (final (n, k) in combos.indexed) {
    for (final (j, p) in k.pieces.indexed) {
      pieces.add(p);
      streams.add(4096 + n * 8 + j);
      owners.add(k.event);
    }
  }
  // A soma dos multiplicadores: cada + conta o quanto passa de 1, com o teto de +++ por tipo.
  final terms = <String, List<double>>{};
  for (final s in [c.spawn, for (final e in evs) e.def.spawn, for (final k in combos) k.spawn]) {
    for (final e in s.entries) {
      (terms[e.key] ??= []).add(e.value);
    }
  }
  // Um termo só: o número do dado, exato (sem o erro de somar e tirar 1).
  final spawn = {for (final e in terms.entries) e.key: e.value.length == 1 ? e.value.first : e.value.fold(1.0, (a, v) => a + v - 1)};
  return ClimateDef(
    id: id,
    category: c.category,
    spawn: {for (final e in spawn.entries) e.key: e.value.clamp(m.spawnFloor, m.spawnCap).toDouble()},
    pieces: pieces,
    streams: streams,
    owners: owners,
    merged: (modifier: _mergeModifiers([for (final p in pieces) if (p is ModifierPiece) p]), movement: _mergeMovement(pieces, owners)),
  );
}

ModifierPiece? _mergeModifiers(List<ModifierPiece> ms) {
  if (ms.isEmpty) return null;
  if (ms.length == 1) return ms.first;
  double prod(double Function(ModifierPiece) f) => ms.fold(1.0, (a, p) => a * f(p));
  final views = [for (final p in ms) ?p.viewMaxM];
  final shinyTypes = <String, double>{};
  for (final p in ms) {
    for (final e in p.shinyTypeMult.entries) {
      shinyTypes[e.key] = (shinyTypes[e.key] ?? 1) * e.value;
    }
  }
  return ModifierPiece(
    'modifier',
    auraAddM: ms.fold(0.0, (a, p) => a + p.auraAddM),
    viewMaxM: views.isEmpty ? null : views.reduce(math.min),
    toleranceMult: prod((p) => p.toleranceMult),
    wanderMult: prod((p) => p.wanderMult),
    immuneSchool: [for (final p in ms) ?p.immuneSchool].firstOrNull,
    calm: ms.any((p) => p.calm),
    levelAdd: ms.fold(0, (a, p) => a + p.levelAdd),
    shinyMult: prod((p) => p.shinyMult),
    variantMult: prod((p) => p.variantMult),
    shinyTypeMult: shinyTypes,
    effects: [for (final p in ms) ...p.effects],
  );
}

/// O movimento da pilha: o tráfego multiplica; a deriva das Fagulhas é a do evento que tem a dele (o Vento das Fendas
/// substitui o vento do clima), senão a do clima.
MovementPiece? _mergeMovement(List<ClimatePiece> pieces, List<String?> owners) {
  final ms = [for (final (i, p) in pieces.indexed) if (p is MovementPiece) (p, owners[i])];
  if (ms.isEmpty) return null;
  if (ms.length == 1) return ms.first.$1;
  final drift = [for (final (p, o) in ms) if (o != null && (p.sparkDriftMps > 0 || p.headingDeg != null)) p].firstOrNull ?? [for (final (p, o) in ms) if (o == null) p].firstOrNull ?? ms.first.$1;
  final ttls = [for (final (p, _) in ms) ?p.sparkTtlS];
  return MovementPiece(
    'movement',
    sparkDriftMps: drift.sparkDriftMps,
    driftMaxM: drift.driftMaxM,
    headingDeg: drift.headingDeg,
    trafficMult: ms.fold(1.0, (a, m) => a * m.$1.trafficMult),
    walkerMult: ms.fold(1.0, (a, m) => a * m.$1.walkerMult),
    sparkTtlS: ttls.isEmpty ? null : ttls.reduce(math.min),
  );
}

class _Cand {
  _Cand(this.id, this.source, this.cause, this.s, this.e, {this.reason, this.maxUtc, required this.order});

  final String id;
  final EventSource source;
  final String? cause;
  final int s;
  int e;
  final String? reason;
  final int? maxUtc;

  /// Desempate na fila: a ordem dos dados.
  final int order;
}

/// A agenda dos eventos de uma época, por região z12 e dia local: quem entra na vaga, quando e até quando.
class EventSchedule {
  EventSchedule(this.model);

  final ClimateModel model;

  // ponytail: 24 dias-região guardados; o jogo lê um ou dois por vez, o debug que pula o relógio refaz.
  final _days = <(int, int, int, int, List<ClimateEvent>), List<ActiveEvent>>{};
  final _climates = <(int, int, int, int, List<ClimateEvent>), String>{};

  int localDay(int t) => (t + model.localOffsetH * 3600) ~/ 86400;
  int dayStartUtc(int day) => day * 86400 - model.localOffsetH * 3600;

  /// Os eventos ativos em [t] na região, na ordem da vaga (prioridade, depois quem começou antes).
  List<ActiveEvent> activeAt(int seed, int t, int rx, int ry, List<ClimateEvent> feed) {
    final out = [for (final a in dayOf(seed, localDay(t), rx, ry, feed)) if (a.activeAt(t)) a];
    out.sort((a, b) => a.source.index != b.source.index ? a.source.index - b.source.index : a.startUtc - b.startUtc);
    return out;
  }

  /// Os eventos que começam em `(fromUtc, toUtc]` na região (o app Céu), em ordem.
  List<ActiveEvent> upcoming(int seed, int fromUtc, int toUtc, int rx, int ry, List<ClimateEvent> feed) {
    final seen = <(String, int)>{};
    final out = <ActiveEvent>[];
    for (var d = localDay(fromUtc); d <= localDay(toUtc); d++) {
      for (final a in dayOf(seed, d, rx, ry, feed)) {
        if (a.startUtc > fromUtc && a.startUtc <= toUtc && seen.add((a.id, a.startUtc))) out.add(a);
      }
    }
    out.sort((a, b) => a.startUtc - b.startUtc);
    return out;
  }

  String _climateAt(int seed, int t, int rx, int ry, List<ClimateEvent> feed) {
    if (_climates.length > 4096) _climates.clear();
    final w = model.windowOf(t);
    return _climates.putIfAbsent((seed, w, rx, ry, feed), () => model.resolve(seed: seed, tUtc: w * model.windowS, rx: rx, ry: ry, events: feed).climate);
  }

  /// O dia local [day]: simula a partir do começo do dia anterior (quem já estava na vaga à meia-noite continua) e guarda os
  /// trechos que tocam o dia.
  List<ActiveEvent> dayOf(int seed, int day, int rx, int ry, List<ClimateEvent> feed) {
    final key = (seed, day, rx, ry, feed);
    final hit = _days[key];
    if (hit != null) return hit;
    if (_days.length > 24) _days.clear();
    final d0 = dayStartUtc(day), s = d0 - 86400, e = d0 + 86400;
    return _days[key] = [for (final a in _simulate(seed, s, e, rx, ry, feed)) if (a.endUtc > d0 && a.startUtc < e) a];
  }

  List<_Cand> _candidates(int seed, int s, int e, int rx, int ry, List<ClimateEvent> feed) {
    final m = model, out = <_Cand>[];
    int order(String id) => m.eventDefs[id]!.ordinal;
    for (final f in feed) {
      if (f.skipsCalendar || !m.eventDefs.containsKey(f.climate) || f.endsUtc <= s || f.startsUtc >= e) continue;
      out.add(_Cand(f.climate, EventSource.feed, f.id, f.startsUtc, f.endsUtc, reason: f.reason, order: order(f.climate)));
    }
    for (final r in m.eclipses) {
      if (!m.eventDefs.containsKey(r.climate)) continue;
      final v = r.visibleIn(s, e, rx, ry);
      if (v != null) out.add(_Cand(r.climate, EventSource.astro, r.id, v.startUtc, v.endUtc, maxUtc: v.maxUtc, order: order(r.climate)));
    }
    // Calendário e astronomia de hora em hora (as regras têm horas inteiras); a chance é sorteada por janela de 3 h.
    final open = <(EventSource, String, String), _Cand>{};
    for (var h = s; h < e; h += 3600) {
      final mid = h + 1800, w = m.windowOf(mid);
      final local = DateTime.fromMillisecondsSinceEpoch((mid + m.localOffsetH * 3600) * 1000, isUtc: true);
      final now = <(EventSource, String, String)>[];
      for (final hit in m.veil.allAt(seed, w, mid, skipped: _skips(feed, mid))) {
        if (m.eventDefs.containsKey(hit.climate)) now.add((EventSource.calendar, hit.rule.id, hit.climate));
      }
      for (final r in m.astro) {
        if (!m.eventDefs.containsKey(r.climate) || !r.matches(mid, local)) continue;
        if (r.chance >= 1 || Pcg32(fnv1a64([seed, w, fnv1a64Bytes(r.id.codeUnits), saltCalendar]), saltKenoma).nextFloat() < r.chance) now.add((EventSource.astro, r.id, r.climate));
      }
      for (final k in now) {
        final c = open[k];
        if (c != null && c.e == h) {
          c.e = h + 3600;
        } else {
          final n = _Cand(k.$3, k.$1, k.$2, h, h + 3600, order: order(k.$3));
          open[k] = n;
          out.add(n);
        }
      }
    }
    // Sorteio, por janela de 3 h: o arco-íris na passagem da chuva para o sol e os eventos com `draw` (o Tornado raro).
    final rb = m.rainbow;
    for (var w = m.windowOf(s); w * m.windowS < e; w++) {
      final ws = w * m.windowS;
      if (rb != null && m.eventDefs.containsKey(rb.$1)) {
        final a = rainbowDraw(seed, rx, ry, w, feed);
        if (a != null) out.add(_Cand(rb.$1, EventSource.draw, rb.$1, a.$1, a.$2, order: order(rb.$1)));
      }
      for (final ev in m.eventDefs.values) {
        final d = ev.draw;
        if (d == null || !d.climates.contains(_climateAt(seed, ws, rx, ry, feed))) continue;
        final rng = Pcg32(fnv1a64([seed, w, rx, ry, fnv1a64Bytes(ev.id.codeUnits), saltEventDraw]), saltKenoma);
        if (rng.nextFloat() >= d.chance) continue;
        final dur = d.durationS + rng.nextInt(d.durationMaxS - d.durationS + 1);
        final start = ws + rng.nextInt(math.max(1, m.windowS - dur));
        out.add(_Cand(ev.id, EventSource.draw, ev.id, start, start + dur, order: ev.ordinal));
      }
    }
    return out;
  }

  /// O arco-íris do sorteio na janela [w]: começa no começo da primeira janela de sol depois da chuva, de dia, com a chance
  /// e a duração da peça. `(início, fim)`, ou `null`.
  (int, int)? rainbowDraw(int seed, int rx, int ry, int w, List<ClimateEvent> feed) {
    final rb = model.rainbow;
    if (rb == null) return null;
    final p = rb.$2, ws = w * model.windowS;
    if (!model.rainbowTo.contains(_climateAt(seed, ws, rx, ry, feed)) || !p.after.contains(_climateAt(seed, ws - 1, rx, ry, feed))) return null;
    final (lat, lon) = tileFractionToLatLon(rx + 0.5, ry + 0.5, 12);
    if (sunAltitudeDeg(lat, lon, ws) <= 0) return null;
    final rng = Pcg32(fnv1a64([seed, w, rx, ry, fnv1a64Bytes(rb.$1.codeUnits), saltEventDraw]), saltKenoma);
    if (rng.nextFloat() >= p.chance) return null;
    final (lo, hi) = p.durationS;
    return (ws, ws + lo + rng.nextInt(hi - lo + 1));
  }

  static bool Function(String id)? _skips(List<ClimateEvent> events, int mid) {
    final off = {for (final e in events) if (e.skipsCalendar && mid >= e.startsUtc && mid < e.endsUtc) ?e.id};
    return off.isEmpty ? null : off.contains;
  }

  List<ActiveEvent> _simulate(int seed, int s, int e, int rx, int ry, List<ClimateEvent> feed) {
    final cands = _candidates(seed, s, e, rx, ry, feed);
    if (cands.isEmpty) return const [];
    final (lat, lon) = tileFractionToLatLon(rx + 0.5, ry + 0.5, 12);
    final points = <int>{s, e};
    for (final c in cands) {
      points
        ..add(c.s.clamp(s, e))
        ..add(c.e.clamp(s, e));
    }
    for (var w = m0(s); w < e; w += model.windowS) {
      points.add(w); // o clima muda na virada da janela: o requisito de clima também
    }
    if (cands.any((c) => model.eventDefs[c.id]!.requires.light != null)) points.addAll(_sunCrossings(lat, lon, s, e));
    final ts = points.where((t) => t >= s && t <= e).toList()..sort();
    final active = <(_Cand, int)>[];
    final out = <ActiveEvent>[];
    bool ok(_Cand c, int t) => c.s <= t && t < c.e && model.eventDefs[c.id]!.requires.holds(sunAltitudeDeg(lat, lon, t), _climateAt(seed, t, rx, ry, feed));
    void close((_Cand, int) a, int t) {
      if (t > a.$2) out.add(ActiveEvent(id: a.$1.id, source: a.$1.source, cause: a.$1.cause, startUtc: a.$2, endUtc: t, naturalStartUtc: a.$1.s, reason: a.$1.reason, maxUtc: a.$1.maxUtc));
    }

    for (final t in ts) {
      for (final a in [...active]) {
        if (t == e || !ok(a.$1, t)) {
          close(a, t);
          active.remove(a);
        }
      }
      if (t == e) break;
      final waiting = [for (final c in cands) if (!active.any((a) => identical(a.$1, c) || a.$1.id == c.id) && ok(c, t)) c]
        ..sort((a, b) => a.source.index != b.source.index ? a.source.index - b.source.index : (a.s != b.s ? a.s - b.s : a.order - b.order));
      for (final c in waiting) {
        if (active.length >= model.maxEvents) break;
        if (active.any((a) => a.$1.id == c.id)) continue; // o mesmo evento por duas origens: um só
        active.add((c, t));
      }
    }
    return out;
  }

  int m0(int s) => s - s % model.windowS + (s % model.windowS == 0 ? 0 : model.windowS);

  /// Os instantes em que o sol cruza o horizonte em `[s, e)`, a ~10 s.
  List<int> _sunCrossings(double lat, double lon, int s, int e) {
    final out = <int>[];
    var t0 = s, a0 = sunAltitudeDeg(lat, lon, s);
    for (var t1 = s + 600; t1 <= e; t1 += 600) {
      final a1 = sunAltitudeDeg(lat, lon, t1);
      if ((a0 <= 0) != (a1 <= 0)) {
        var lo = t0, hi = t1;
        while (hi - lo > 10) {
          final mid = (lo + hi) ~/ 2;
          if ((sunAltitudeDeg(lat, lon, mid) <= 0) == (a0 <= 0)) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        out.add(hi);
      }
      t0 = t1;
      a0 = a1;
    }
    return out;
  }
}
