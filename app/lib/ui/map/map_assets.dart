/// Tudo que os mapas precisam para desenhar: o pacote da região (conferido contra a época), as
/// texturas dos biomas e os raios do `balance.json`. Compartilhado pelo mapa livre do debug e pelo mapa
/// do jogo.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:io' show Directory;
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show AssetBundle, AssetManifest, rootBundle;
import 'package:path_provider/path_provider.dart';

import '../../core/biomes.dart';
import '../../core/epochs.dart';
import '../../core/tiles.dart' show tileFractionToLatLon;
import '../../world/region_reach.dart';
import '../../core/climate.dart' show ClimateEvent;
import '../../world/climate_world.dart';
import '../../data/game_data.dart';
import '../../player/circle.dart' show MapAbilities, abilitiesOf;
import '../../player/game_state.dart';
import '../../world/debug_force.dart';
import '../../world/personal_layer.dart';
import '../../world/spawn_field.dart';
import '../../world/street_dirs.dart';
import '../../world/walk_paths.dart';
import '../../world/water_field.dart';
import '../../crafting/bag.dart';
import '../../crafting/conditions.dart';
import '../../world/world_view.dart';
import '../../net/signed_feed.dart';
import '../../data/block_cache.dart';
import '../../data/map_sources.dart';
import '../../data/cycle_pack.dart';
import '../../data/nowalk_pack.dart';
import '../../data/relief_pack.dart';
import '../../data/traffic_pack.dart';
import '../../data/visual_pack.dart';
import '../../world/visual_map.dart';
import '../../data/building_pack.dart';
import '../../data/region_loader.dart';
import '../../net/map_http.dart';
import '../../net/region_manager.dart';
import '../../world/fallback_service.dart';
import '../../world/layered_world.dart';
import '../../world/fallback/block_builder.dart';
import '../../world/fallback/block_codec.dart';
import '../../world/map_balance.dart';
import '../../world/map_fallback_balance.dart';
import '../../travel/system_bridge.dart';
import '../../world/map_layers.dart';
import '../../world/region_map.dart';
import 'biome_textures.dart';
import 'map_renderer.dart';
import '../../data/ground_pack.dart';

/// Região da Fase 0: a única com pacote.
const String kRegion = kBundledRegion;

class MapAssets {
  MapAssets({required this.map, required this.atlas, required this.balance, required this.stale, this.visual, this.noWalk, this.epoch, this.world, this.fallback, this.codec, this.trafficPoints, this.relief, this.cycleways, this.buildings, this.ground});

  /// As ciclovias do OSM para os ciclistas da simulação local (`null`: ficam nos caminhos de pedestre).
  final CyclePack? cycleways;

  /// 0.22.0: os prédios e as árvores do estilo Completo (só cenário).
  final BuildingSource? buildings;

  /// 0.23.1: o uso do solo da região embutida, para o chão do Completo (só cenário).
  final GroundPack? ground;

  /// O relevo da região (da primeira época que o lista). `null`: terreno plano.
  final ReliefSource? relief;

  final Map<int, WaterField> _water = {};

  /// A água da chuva no relevo com os números de [epoch] (`water`), ou `null` se a época não a usa ou não há relevo.
  WaterField? waterFor(Epoch epoch) => epoch.water == null || relief == null || visual == null
      ? null
      : _water[epoch.id] ??= (WaterField(relief: relief!, visual: visual!, model: epoch.water!)
        ..background = waterInBackground
        ..onTile = () => onWaterTile?.call());

  /// O mapa do jogo liga: a água de cada tile é calculada fora da thread do desenho e o bloco aparece sem água até ela
  /// chegar. A Patrulha (que não desenha e anda rápido no tempo) deixa desligado e calcula na hora.
  bool waterInBackground = false;

  /// Um tile da água chegou do cálculo de fundo.
  void Function()? onWaterTile;

  /// Semáforos, faixas e entradas do OSM para a simulação local do tráfego (`null`: regra pela classe da rua).
  final TrafficPointSource? trafficPoints;

  final RegionMap map;

  /// O atlas de texturas. Quem carrega é quem descarta ([dispose]). `null` no serviço da Patrulha, que não desenha.
  final ui.Image? atlas;
  final MapBalance balance;

  /// O relógio está fora das épocas: o mapa funciona, mas o mundo está desatualizado.
  final bool stale;

  /// As geometrias do pacote visual (ruas, água, verde). Só o mapa do jogo as carrega.
  final VisualMap? visual;

  /// As rodovias e vias expressas, onde Fagulhas, materiais e Ecos da época 2 não nascem. Só com o pacote visual.
  final NoWalkSource? noWalk;
  final Epoch? epoch;

  /// O mundo em camadas. Só com o pacote visual: o mapa livre do debug lê o pacote puro.
  final LayeredWorld? world;
  final MapFallbackBalance? fallback;

  /// `null`: sem consultas à Overpass, só pacotes e piso.
  final FallbackCodec? codec;

  BiomeSet get biomes => map.biomes;

  MapRenderer makeRenderer() => MapRenderer(map: map, atlas: atlas!);

  void dispose() => atlas?.dispose();
}

/// O clima determinístico (o da seed) da célula z20 `(cx, cy)` em [t]: o que pesa nos spawns e o que se vê sem a rede. O
/// modelo é o da época ATIVA naquele instante (nunca o da mais nova): o mundo de cada época é só dela. O app e a Patrulha
/// usam esta mesma função: da época 6 em diante, o clima completo (36 climas e os eventos do feed); antes, o de quatro estados.
String seedWeatherOfCell(EpochSchedule schedule, int seed, int cx, int cy, int t, {List<ClimateEvent> events = const []}) =>
    climateIdOfCell(schedule, seed, cx, cy, t, events: events);

/// As peças do clima (o Eco do raio, granizo, poças...) do mundo de [state]: as mesmas no mapa e na Patrulha.
ClimateWorld climateWorldFor({required GameState state, required GameData data, required MapAssets assets, String? Function()? forced, List<String> Function()? forcedEvents, ForcedPhase Function()? forcedPhase}) => ClimateWorld(
      seed: state.seed,
      schedule: data.schedule,
      speciesOfType: data.ecoOfType,
      speciesOfTypeAt: data.ecoOfType,
      itemExists: data.itemNames.containsKey,
      itemSince: (id) => data.itemSinceEpoch[id],
      biomeAt: (cx, cy) {
        try {
          return assets.map.biomes.spawnKey(assets.map.spawnBiomeAtCell(cx, cy));
        } catch (_) {
          return null;
        }
      },
      // Poças e zonas paradas da época 7 vão para a rua pelos mesmos caminhos dos spawns (o app e a Patrulha).
      snapper: assets.visual == null ? null : WalkPaths(assets.visual!, blocked: assets.noWalk),
      water: assets.waterFor,
      relief: assets.relief,
      typeOf: (id) => data.species(id)?.type.name,
      streets: assets.visual == null ? null : StreetDirs(assets.visual!),
      forced: forced,
      forcedEvents: forcedEvents,
      forcedPhase: forcedPhase,
    );

/// O mundo que o jogador vê e alcança, montado do mesmo jeito no mapa do jogo e no serviço da Patrulha (o mesmo código de
/// geração nos dois: Fagulhas, materiais e Ecos iguais). [weatherAt] é o id do clima de cada célula (o debug pode forçar no
/// app) e [climate], as peças do clima; sem ele, um [climateWorldFor] sem debug.
WorldView worldViewFor({
  required GameState state,
  required GameData data,
  required MapAssets assets,
  required String Function(int cx, int cy, int t) weatherAt,
  ClimateWorld? climate,
  DebugForce? force,
  void Function(String message)? onMessage,
  bool Function()? personalHidden,
  MapAbilities Function()? abilities,
}) {
  final cw = climate ?? climateWorldFor(state: state, data: data, assets: assets);
  final field = SpawnField(
    seed: state.seed,
    schedule: data.schedule,
    map: assets.map,
    typeOf: (id) => data.species(id)?.type.name,
    snapper: WalkPaths(assets.visual!, blocked: assets.noWalk),
    weatherAt: weatherAt,
    climate: cw,
    levelCapOf: data.progress.levelCapFor,
    relief: assets.relief,
  );
  // A camada pessoal: o que o Círculo acrescenta só para este jogador, por cima do mesmo mundo.
  final personal = PersonalLayer(
    field: field,
    playerKey: playerKeyOf(state.founder?.playerId ?? state.groupCode),
    builds: () => state.builds,
    balance: data.personal,
    points: assets.trafficPoints,
    hidden: personalHidden ?? () => false,
  );
  cw.personalPuddles = personal.puddlesAt;
  return WorldView(
    field: field,
    personal: personal,
    state: state,
    street: data.street,
    force: force,
    typeOf: (id) => data.species(id)?.type.name,
    auraM: assets.balance.auraM,
    touchRangeM: assets.balance.touchRangeM,
    viewM: assets.balance.viewM,
    trackerM: assets.balance.trackerM,
    abilities: abilities ?? () => abilitiesOf(state, data),
    ritual: data.ritual,
    itemName: data.itemName,
    onMessage: onMessage,
  )
    // O crafting da fase 1: a qualidade do bruto vem da condição e do lugar, e a bolsa cheia deixa o material no mapa.
    ..pickupQuality = ((id, here) => rawQuality(id, here, data.craft.balance))
    ..bagFits = ((key, n, t) => fits(state, data.craft, t, key, n))
    ..itemPlural = ((id) => data.itemPlurals[id]);
}

/// As funções do bloco com as regras do OSM ligadas.
FallbackCodec fallbackCodec(Map<String, dynamic> biomesJson) {
  // `build`, `encode` e `decode` rodam em Isolate: `OsmRules` é só dados.
  final rules = OsmRules.fromJson(biomesJson);
  return FallbackCodec(
    query: ({required tx, required ty, required dateIso}) => overpassQuery(tx: tx, ty: ty, dateIso: dateIso, rules: rules),
    build: ({required overpassJson, required tx, required ty, required epochId}) =>
        buildBlock(overpassJson: overpassJson, tx: tx, ty: ty, epochId: epochId, rules: rules),
    encode: encodeBlock,
    decode: decodeBlock,
  );
}

/// Liga o fallback e os pacotes baixáveis ao mundo de [assets] e recarrega o que está no disco, em segundo plano. Sem pasta de
/// suporte (testes), o mundo fica só com a região embutida.
Future<MapLayers> openMapLayers({
  required MapAssets assets,
  required EpochSchedule schedule,
  required String appVersion,
  required int Function() nowUtc,
  required int Function() realNowUtc,
  required String Function() baseUrl,
  void Function(String message)? onNotice,
  RegionConfirm? confirm,
  PostForm post = httpPostForm,
}) async {
  final world = assets.world!, balance = assets.fallback!;
  final Directory support;
  try {
    support = await getApplicationSupportDirectory();
  } catch (_) {
    return MapLayers(world: world);
  }
  final regions = RegionManager(
    world: world,
    loadM: balance.regionLoadM,
    unloadM: balance.regionUnloadM,
    schedule: schedule,
    dir: Directory('${support.path}/regions'),
    confirmBytes: balance.regionConfirmBytes,
    retryS: balance.retryS,
    nowUtc: nowUtc,
    realNowUtc: realNowUtc,
    baseUrl: baseUrl,
    onNotice: onNotice,
    confirm: confirm,
  );
  unawaited(regions.loadInstalled());
  final codec = assets.codec;
  return MapLayers(
    world: world,
    regions: regions,
    readUnmetered: const SystemBridge().unmeteredWifi,
    networkCheckS: balance.networkCheckS,
    fallback: codec == null
        ? null
        : FallbackService(
            world: world,
            schedule: schedule,
            codec: codec,
            balance: balance,
            post: post,
            cache: BlockCache(Directory('${support.path}/blocks'), limitBytes: balance.diskLimitBytes),
            appVersion: appVersion,
            nowUtc: nowUtc,
            realNowUtc: realNowUtc,
          ),
  );
}

/// Carrega os assets do mapa em [nowUtc] (segundos UTC). Devolve [MapAssets] ou, se o pacote não bate
/// com a época vigente (ou falta algo), a mensagem de erro em português: nunca lança.
///
/// 0.26.2: sem [withOtherRegions], só a região da casa; as outras embutidas (São Paulo, 2,4 s no g54) entram depois, com
/// [loadOtherRegion], quando o jogador chega perto delas (0.26.4).
Future<Object> loadMapAssets({required int nowUtc, AssetBundle? bundle, bool withVisual = false, bool withAtlas = true, bool withOtherRegions = true}) async {
  final assets = bundle ?? rootBundle;
  final region = await loadRegion(region: kRegion, nowUtc: nowUtc, bundle: assets);
  if (region is RegionLoadError) return region.message;
  final loaded = region as RegionLoaded;
  try {
    final biomesJson = jsonDecode(await assets.loadString('assets/data/biomes.json')) as Map<String, dynamic>;
    final biomes = BiomeSet.fromJson(biomesJson);
    final balanceJson = jsonDecode(await assets.loadString('assets/data/balance.json')) as Map<String, dynamic>;
    final balance = MapBalance(balanceJson);
    VisualMap? visual;
    NoWalkPack? noWalk;
    LayeredWorld? world;
    TrafficPack? trafficPoints;
    CyclePack? cycleways;
    GroundPack? ground;
    ReliefPack? relief;
    BuildingPack? buildings;
    
    if (withVisual) {
      final pack = await loadVisualPack(region: kRegion, epoch: loaded.epoch, bundle: assets);
      if (pack is! VisualPack) return pack as String;
      // A época 2 em diante fixa as vias bloqueadas; vale o pacote da primeira época que o lista, mesmo antes dela começar.
      final schedule = EpochSchedule.fromJson(await loadEpochsJson(bundle: assets));
      final withNoWalk = schedule.epochs.where((e) => e.walkable?.exclude != null).toList();
      if (withNoWalk.isNotEmpty) {
        final nw = await loadNoWalkPack(epoch: withNoWalk.first, bundle: assets);
        if (nw is String) return nw;
        noWalk = nw as NoWalkPack?;
      }
      // O relevo vale o da primeira época que o lista, como as vias bloqueadas.
      final withRelief = schedule.epochs.where((e) => e.reliefPacks.containsKey(kRegion)).toList();
      if (withRelief.isNotEmpty) {
        final rp = await loadReliefPack(epoch: withRelief.first, region: kRegion, bundle: assets);
        if (rp is String) return rp;
        relief = rp as ReliefPack?;
      }
      final access = await loadAccessPack(region: kRegion, bundle: assets);
      trafficPoints = await loadTrafficPack(region: kRegion, epoch: loaded.epoch, bundle: assets);
      cycleways = await loadCyclePack(region: kRegion, bundle: assets);
      buildings = await loadBuildingPack(region: kRegion, bundle: assets);
      ground = await loadGroundPack(region: kRegion, bundle: assets);
      world = LayeredWorld(regions: [
        LoadedRegion(id: kRegion, grid: loaded.pack, visual: pack, noWalk: noWalk, access: access, relief: relief, traffic: trafficPoints, buildings: buildings),
        // 0.25.2 (modo de desenvolvimento): as outras regiões da época que vêm no APK (São Paulo), sem baixar nada.
        if (withOtherRegions)
          for (final id in loaded.epoch.regionPacks.keys.where((id) => id != kRegion)) ?await loadEmbeddedRegion(region: id, epoch: loaded.epoch, bundle: assets),
      ], maxBlocks: MapFallbackBalance(balanceJson).memoryBlocks);
      visual = VisualMap(world);
    }
    final atlas = withAtlas ? await buildBiomeAtlas(biomes) : null;
    return MapAssets(
      map: RegionMap(pack: world ?? loaded.pack, biomes: biomes),
      atlas: atlas,
      balance: balance,
      stale: loaded.stale,
      visual: visual,
      noWalk: world ?? noWalk,
      epoch: loaded.epoch,
      world: world,
      fallback: world == null ? null : MapFallbackBalance(balanceJson),
      codec: world == null ? null : fallbackCodec(biomesJson),
      trafficPoints: world ?? trafficPoints, // com as regiões baixadas: os pontos de cada uma
      cycleways: cycleways,
      ground: ground,
      buildings: world ?? buildings, // com as regiões baixadas: os prédios de cada uma
      relief: world ?? relief, // com as regiões baixadas: o relevo de cada uma
    );
  } catch (e) {
    return 'Não consegui ler os dados do mapa: $e';
  }
}

/// 0.26.4: o retângulo da região embutida [region] em graus, pelo cabeçalho do pacote lógico (sem descompactar as células
/// nem conferir o SHA). `null` sem o pacote.
Future<GeoBox?> embeddedRegionBox(String region, Epoch epoch, {AssetBundle? bundle}) async {
  final ref = epoch.regionPacks[region];
  if (ref == null) return null;
  try {
    final data = await (bundle ?? rootBundle).load('assets/regions/${ref.file}');
    if (data.lengthInBytes < 23) return null;
    final zoom = data.getUint8(6), x0 = data.getUint32(7, Endian.little), y0 = data.getUint32(11, Endian.little);
    final w = data.getUint32(15, Endian.little), h = data.getUint32(19, Endian.little);
    final (north, west) = tileFractionToLatLon(x0.toDouble(), y0.toDouble(), zoom);
    final (south, east) = tileFractionToLatLon((x0 + w).toDouble(), (y0 + h).toDouble(), zoom);
    return GeoBox(south: south, west: west, north: north, east: east);
  } catch (_) {
    return null;
  }
}

/// 0.26.4: a região embutida [id] montada noutro isolate (ou aqui, se não der), para entrar no mundo quando o jogador chega a
/// menos de `region_load_km` dela.
Future<LoadedRegion?> loadOtherRegion(String id, Epoch epoch, {AssetBundle? bundle}) async =>
    await _embeddedInIsolate(id, epoch, bundle ?? rootBundle) ?? await loadEmbeddedRegion(region: id, epoch: epoch, bundle: bundle);

/// A região [id] montada noutro isolate: os bytes dos pacotes `assets/regions/<id>_*` saem do APK aqui (leitura
/// assíncrona), a conferência dos SHA e a leitura dos pacotes correm lá (2,8 s de thread da interface no g54 com São
/// Paulo) e a região volta sem cópia. `null` se não deu (sem os pacotes, ou algo que não atravessa isolates): quem chama
/// monta aqui mesmo.
Future<LoadedRegion?> _embeddedInIsolate(String id, Epoch epoch, AssetBundle bundle) async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final files = <String, Uint8List>{
      for (final k in manifest.listAssets().where((k) => k.startsWith('assets/regions/${id}_')))
        k: (await bundle.load(k)).buffer.asUint8List(),
    };
    if (files.isEmpty) return null;
    return await Isolate.run(() => loadEmbeddedRegion(region: id, epoch: epoch, bundle: _MemoryBundle(files)));
  } catch (_) {
    return null;
  }
}

/// Os assets de [files], em memória (para montar uma região noutro isolate, onde não há o bundle do app).
class _MemoryBundle extends AssetBundle {
  _MemoryBundle(this.files);

  final Map<String, Uint8List> files;

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(files[key] ?? (throw StateError('Sem o asset $key')));

  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) async => parser(await loadString(key));
}

/// 0.25.2 (modo de desenvolvimento): uma região além de Campinas embutida no APK (São Paulo), montada como a embutida e
/// conferida pelos SHA-256 da época. `null` se o pacote lógico ou o visual não estão nos assets ou não conferem: a região
/// continua baixável pelo catálogo, como antes. O relevo, as vias, a rota, os pontos e os prédios são opcionais.
Future<LoadedRegion?> loadEmbeddedRegion({required String region, required Epoch epoch, AssetBundle? bundle}) async {
  final assets = bundle ?? rootBundle;
  final ref = epoch.regionPacks[region];
  if (ref == null) return null;
  final Uint8List bytes;
  try {
    final data = await assets.load('assets/regions/${ref.file}');
    bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } catch (_) {
    return null; // não veio no APK
  }
  final grid = verifyRegionPack(bytes: bytes, epoch: epoch, region: region);
  if (grid is! RegionLoaded) return null;
  final visual = await loadVisualPack(region: region, epoch: epoch, bundle: assets);
  if (visual is! VisualPack) return null;
  final noWalk = await loadNoWalkPack(epoch: epoch, bundle: assets, region: region);
  final relief = await loadReliefPack(epoch: epoch, region: region, bundle: assets);
  final access = await loadAccessPack(region: region, bundle: assets);
  final traffic = await loadTrafficPack(region: region, epoch: epoch, bundle: assets);
  final buildings = await loadBuildingPack(region: region, bundle: assets);
  return LoadedRegion(
    id: region,
    grid: grid.pack,
    visual: visual,
    noWalk: noWalk is NoWalkPack ? noWalk : null,
    access: access,
    relief: relief is ReliefPack ? relief : null,
    traffic: traffic,
    buildings: buildings,
  );
}
