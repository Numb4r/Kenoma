/// Liga o clima ao mapa: o clima do mundo ([ClimateWorld]), o que se vê (o forçado pelo debug, o da rede se ligado, ou o
/// determinístico), o aviso de quando um clima começa, os eventos do feed assinado e o trovão. Fica fora da tela do mapa
/// para os ganchos lá serem pequenos.
library;

import 'dart:async';

import '../../core/climate.dart';
import '../../core/tiles.dart';
import '../../data/climate_catalog.dart';
import '../../data/game_data.dart';
import '../../net/signed_feed.dart';
import '../../world/climate_world.dart';
import '../../world/weather_source.dart';

class ClimateDriver {
  ClimateDriver({required this.data, required this.world, required bool Function() online, WeatherSource? source})
      : service = WeatherService(
          deterministic: (lat, lon, t) {
            final (cx, cy) = latLonToTile(lat, lon, 20);
            return world.idAt(cx, cy, t);
          },
          source: source ?? OpenMeteoSource(),
          online: online,
        );

  final GameData data;
  final ClimateWorld world;
  final WeatherService service;

  /// O id do clima que se vê agora (HUD e desenho).
  String shown = 'clear';
  String? _noticed;

  ClimateInfo get info => data.climates.of(shown);

  /// Atualiza o que se vê em ([lat], [lon]). Devolve se mudou e o aviso do clima novo (uma vez por clima seguido).
  ({bool changed, String? notice}) update(double lat, double lon, int now) {
    unawaited(service.refresh(lat, lon, now));
    final forced = world.forced();
    var id = forced ?? service.shown(lat, lon, now);
    // Até a época 5 o mundo tem quatro estados: o da rede também é mostrado como um deles.
    if (forced == null && data.schedule.select(now).epoch.climate == null) id = data.climates.of(id).base.id;
    final changed = id != shown;
    shown = id;
    String? notice;
    if (changed && id != _noticed) {
      _noticed = id;
      notice = data.climates.of(id).notice;
    }
    return (changed: changed, notice: notice);
  }

  /// Os climas de evento do `events.json` assinado (o que não é de clima fica de fora). Falhas: nenhum evento.
  Future<void> loadEvents() async {
    final list = await loadSignedEvents();
    world.events = [for (final e in list) ?ClimateEvent.tryParse(e)];
  }
}
