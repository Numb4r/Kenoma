/// O que o app Céu mostra (docs/GDD.md, "Celular mágico"): o clima de agora e das próximas janelas num lugar, o evento que
/// força o clima e o motivo numa frase, e o efeito de cada clima no spawn numa linha. É o clima do MUNDO (o que pesa nos
/// spawns), o mesmo para todos; o da rede (Open-Meteo) só muda o desenho e não entra aqui. Dart puro.
library;

import '../core/climate.dart';
import '../core/tiles.dart';
import '../data/climate_catalog.dart';
import 'climate_world.dart';

/// Época 12: um evento por cima do clima, com o nome, o efeito, o motivo, até quando vale e se esperou a vaga.
class OutlookEvent {
  const OutlookEvent({required this.id, required this.name, required this.effect, required this.reason, required this.startUtc, required this.endUtc, required this.waited, required this.source});

  final String id, name, effect, reason;
  final int startUtc, endUtc;
  final bool waited;
  final EventSource source;
}

/// Uma janela de clima: quando, qual, o efeito no spawn, de onde veio e o motivo.
class OutlookWindow {
  const OutlookWindow({
    required this.startUtc,
    required this.endUtc,
    required this.climate,
    required this.name,
    required this.effect,
    required this.source,
    this.eventId,
    this.eventName,
    required this.reason,
    this.events = const [],
  });

  /// Época 12: os eventos que valem na janela (o de agora: os ativos neste instante).
  final List<OutlookEvent> events;

  final int startUtc, endUtc;

  /// O id do clima (`rain`) e o nome dele (`Chuva`).
  final String climate;
  final String name;

  /// O efeito no spawn e no mapa, numa linha (a linha do HUD no `clima.json`).
  final String effect;
  final ClimateSource source;

  /// O evento que forçou o clima (`finados`, `perseids`...), com o nome. `null` no clima da estação e no debug.
  final String? eventId;
  final String? eventName;

  /// O motivo numa frase ("É Finados: a Procissão anda na névoa.").
  final String reason;

  /// Um evento (ou o debug) forçou este clima.
  bool get forced => source != ClimateSource.season;
}

class ClimateOutlook {
  const ClimateOutlook({required this.now, required this.next});

  final OutlookWindow now;

  /// As próximas janelas, em ordem.
  final List<OutlookWindow> next;

  /// A janela de agora se um evento força o clima; `null` no clima da estação.
  OutlookWindow? get event => now.forced ? now : null;

  /// O efeito no spawn de cada clima que aparece de agora em diante, uma linha por clima, na ordem em que aparecem.
  Map<String, String> get effects => {for (final w in [now, ...next]) w.climate: w.effect};
}

/// O clima de agora e das [windows] janelas seguintes em ([lat], [lon]) no instante [nowUtc].
ClimateOutlook climateOutlook({required ClimateWorld world, required ClimateCatalog catalog, required double lat, required double lon, required int nowUtc, int windows = 4}) {
  final (cx, cy) = latLonToTile(lat, lon, 20);
  final model = world.modelAt(nowUtc)?.$2;
  final windowS = model?.windowS ?? 10800;
  final start = nowUtc - nowUtc % windowS;
  String eventReason(ActiveEvent a) {
    final ev = a.cause == null ? null : catalog.events[a.cause];
    final max = a.maxUtc;
    return switch (a.source) {
      EventSource.debug => catalog.reasons['debug'] ?? 'Forçado pelo debug.',
      EventSource.feed => a.reason ?? ev?.reason ?? catalog.reasons['feed'] ?? 'Evento do feed.',
      EventSource.draw => catalog.reasons['draw_${a.id}'] ?? catalog.reasons['draw'] ?? 'Sorteio do Véu.',
      EventSource.calendar || EventSource.astro => [ev?.reason ?? a.cause ?? '', if (max != null) 'Máximo às ${_localHm(max, model?.localOffsetH ?? -3)}.'].join(' '),
    };
  }

  List<OutlookEvent> eventsOf(List<ActiveEvent> list) => [
        for (final a in list)
          OutlookEvent(id: a.id, name: catalog.of(a.id).name, effect: catalog.of(a.id).hud, reason: eventReason(a), startUtc: a.startUtc, endUtc: a.endUtc, waited: a.waited, source: a.source),
      ];

  OutlookWindow at(int s, {bool now = false}) {
    final cause = world.causeAt(cx, cy, s + windowS ~/ 2);
    final info = catalog.of(cause.climate);
    final ev = cause.event == null ? null : catalog.events[cause.event];
    final max = cause.maxUtc;
    final reason = switch (cause.source) {
      ClimateSource.season => catalog.reasons['season'] ?? 'O clima da estação.',
      ClimateSource.debug => catalog.reasons['debug'] ?? 'Forçado pelo debug.',
      ClimateSource.feed => cause.reason ?? ev?.reason ?? catalog.reasons['feed'] ?? 'Evento do feed.',
      ClimateSource.calendar || ClimateSource.astro => [ev?.reason ?? cause.event ?? '', if (max != null) 'Máximo às ${_localHm(max, model?.localOffsetH ?? -3)}.'].join(' '),
    };
    return OutlookWindow(
      startUtc: s,
      endUtc: s + windowS,
      climate: cause.climate,
      name: info.name,
      effect: info.hud,
      source: cause.source,
      eventId: cause.event,
      eventName: ev?.name,
      reason: reason,
      events: eventsOf(now ? world.causeAt(cx, cy, nowUtc).events : world.eventsBetween(cx, cy, s, s + windowS)),
    );
  }

  return ClimateOutlook(now: at(start, now: true), next: [for (var k = 1; k <= windows; k++) at(start + k * windowS)]);
}

/// O próximo evento do calendário do Véu (o app Céu): o nome do evento, o do clima e o começo, ou `null` sem calendário.
({String event, String climate, int startUtc})? nextCalendarEvent({required ClimateWorld world, required ClimateCatalog catalog, required int nowUtc}) {
  final m = world.schedule.select(nowUtc).epoch.climate;
  final n = m?.nextCalendar(world.seed, nowUtc, events: world.events);
  if (n == null) return null;
  return (event: catalog.events[n.rule.id]?.name ?? n.rule.id, climate: catalog.of(n.climate).name, startUtc: n.startUtc);
}

/// Época 12: os próximos [count] itens do calendário do Véu depois de [nowUtc], cada um com o nome do evento do
/// calendário, o do clima ou do evento que ele traz, se é evento e o começo. Varre até [days] dias, de janela em janela.
List<({String event, String what, bool isEvent, int startUtc})> nextCalendarItems({required ClimateWorld world, required ClimateCatalog catalog, required int nowUtc, int count = 3, int days = 400}) {
  final m = world.schedule.select(nowUtc).epoch.climate ?? world.modelAt(nowUtc)?.$2;
  if (m == null || m.calendar.isEmpty) return const [];
  final out = <({String event, String what, bool isEvent, int startUtc})>[];
  int mid(int w) => w * m.windowS + m.windowS ~/ 2;
  final w0 = m.windowOf(nowUtc);
  var running = {for (final h in m.veil.allAt(world.seed, w0, mid(w0))) '${h.rule.id}/${h.climate}'};
  for (var w = w0 + 1; w <= w0 + days * 86400 ~/ m.windowS && out.length < count; w++) {
    final hits = m.veil.allAt(world.seed, w, mid(w));
    final keys = <String>{};
    for (final h in hits) {
      final k = '${h.rule.id}/${h.climate}';
      keys.add(k);
      if (running.contains(k) || out.length >= count) continue;
      out.add((event: catalog.events[h.rule.id]?.name ?? h.rule.id, what: catalog.of(h.climate).name, isEvent: m.eventDefs.containsKey(h.climate), startUtc: w * m.windowS));
    }
    running = keys;
  }
  return out;
}

/// `14h05`: a hora local (o fuso fixo do modelo do clima, como o resto do clima) de [utc].
String _localHm(int utc, int offsetH) {
  final d = DateTime.fromMillisecondsSinceEpoch((utc + offsetH * 3600) * 1000, isUtc: true);
  return '${d.hour}h${d.minute.toString().padLeft(2, '0')}';
}

/// Época 12: a linha do debug com a pilha do clima (o clima, cada evento com a origem e as combinações). `null` sem evento
/// e sem nada forçado.
String? stackLine(ClimateCause cause, ClimateCatalog catalog, ClimateModel? model, {bool forced = false}) {
  if (cause.events.isEmpty && !forced) return null;
  String src(EventSource s) => switch (s) {
        EventSource.feed => 'FEED',
        EventSource.astro => 'ASTRO',
        EventSource.calendar => 'CALENDÁRIO',
        EventSource.draw => 'SORTEIO',
        EventSource.debug => 'DEBUG',
      };
  final ids = {for (final e in cause.events) e.id};
  final combos = [for (final k in model?.combos ?? const <ComboDef>[]) if (k.climate == cause.climate && ids.contains(k.event)) catalog.combos[k.id]?.name ?? k.id];
  return [
    'PILHA ${catalog.of(cause.climate).name.toUpperCase()}${cause.source == ClimateSource.debug ? ' (DEBUG)' : ''}',
    if (cause.events.isNotEmpty) 'EVENTOS ${[for (final e in cause.events) '${catalog.of(e.id).name.toUpperCase()} (${src(e.source)}${e.waited ? ', ESPEROU' : ''})'].join(', ')}',
    if (combos.isNotEmpty) 'COMBINAÇÃO ${combos.join(', ').toUpperCase()}',
  ].join(' · ');
}
