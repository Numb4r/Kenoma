/// O mundo da Patrulha, aberto no isolate do serviço: os dados do jogo, o pacote da região e os blocos em disco (sem rede:
/// bloco não baixado é piso), e o save lido SÓ PARA LEITURA (nível, registro de coletas, marcas). O `WorldView` é montado
/// pelo mesmo `worldViewFor` do mapa do jogo.
library;

import 'dart:io';

import '../core/tiles.dart';
import '../data/game_data.dart';
import '../player/game_state.dart';
import '../save/ksv_save_store.dart';
import '../save/migrations.dart';
import '../ui/map/map_assets.dart';
import '../world/fallback_service.dart';
import '../world/map_layers.dart';
import '../world/world_view.dart';
import 'patrol_balance.dart';
import 'street_name.dart';

class PatrolWorld {
  PatrolWorld({required this.data, required this.state, required this.assets, required this.layers, required this.world, required this.balance});

  final GameData data;
  final GameState state;
  final MapAssets assets;
  final MapLayers layers;
  final WorldView world;
  final PatrolBalance balance;

  /// O nome da rua perto de um ponto em células z21, a até `street_m`.
  String? streetAt(double x21, double y21) {
    final (lat, _) = tileFractionToLatLon(x21, y21, biomeZoom);
    return nearestStreetName(assets.visual!, x21, y21, balance.streetM / metersPerCell(lat));
  }

  void dispose() => layers.dispose();
}

/// Sem rede na Patrulha: toda consulta à Overpass falha na hora e o bloco fica no piso.
Future<HttpReply> _offline(Uri url, String body, {required String userAgent, required Duration timeout, required int maxBytes}) =>
    Future.error(const SocketException('sem rede na Patrulha'));

/// Abre o mundo em [nowUtc]. `null` se não há save com jogo ou o mapa não abre.
Future<PatrolWorld?> openPatrolWorld({required int Function() nowUtc, required int Function() realNowUtc}) async {
  final data = await GameData.load();
  final raw = await (await KsvSaveStore.inDocuments()).read(); // nunca grava
  if (raw == null) return null;
  final json = migrateSave(raw);
  if (json['group_code'] == null) return null;
  final state = GameState.fromJson(json, data.progress);
  final loaded = await loadMapAssets(nowUtc: nowUtc(), withVisual: true, withAtlas: false);
  if (loaded is! MapAssets) return null;
  final layers = await openMapLayers(
    assets: loaded,
    schedule: data.schedule,
    appVersion: 'patrulha',
    nowUtc: nowUtc,
    realNowUtc: realNowUtc,
    baseUrl: () => '',
    post: _offline,
  );
  final world = worldViewFor(
    state: state,
    data: data,
    assets: loaded,
    weatherAt: (cx, cy, t) => seedWeatherOfCell(data.schedule, state.seed, cx, cy, t),
  );
  return PatrolWorld(data: data, state: state, assets: loaded, layers: layers, world: world, balance: data.patrol);
}
