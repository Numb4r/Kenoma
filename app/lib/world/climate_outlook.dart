/// O que o app Céu mostra (docs/GDD.md, "Celular mágico"): o clima de agora e das próximas janelas num lugar, o evento que
/// força o clima e o motivo numa frase, e o efeito de cada clima no spawn numa linha. É o clima do MUNDO (o que pesa nos
/// spawns), o mesmo para todos; o da rede (Open-Meteo) só muda o desenho e não entra aqui. Dart puro.
library;

import '../core/climate.dart';
import '../core/tiles.dart';
import '../data/climate_catalog.dart';
import 'climate_world.dart';

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
  });

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
  OutlookWindow at(int s) {
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
    );
  }

  return ClimateOutlook(now: at(start), next: [for (var k = 1; k <= windows; k++) at(start + k * windowS)]);
}

/// O próximo evento do calendário do Véu (o app Céu): o nome do evento, o do clima e o começo, ou `null` sem calendário.
({String event, String climate, int startUtc})? nextCalendarEvent({required ClimateWorld world, required ClimateCatalog catalog, required int nowUtc}) {
  final m = world.schedule.select(nowUtc).epoch.climate;
  final n = m?.nextCalendar(world.seed, nowUtc, events: world.events);
  if (n == null) return null;
  return (event: catalog.events[n.rule.id]?.name ?? n.rule.id, climate: catalog.of(n.climate).name, startUtc: n.startUtc);
}

/// `14h05`: a hora local (o fuso fixo do modelo do clima, como o resto do clima) de [utc].
String _localHm(int utc, int offsetH) {
  final d = DateTime.fromMillisecondsSinceEpoch((utc + offsetH * 3600) * 1000, isUtc: true);
  return '${d.hour}h${d.minute.toString().padLeft(2, '0')}';
}
