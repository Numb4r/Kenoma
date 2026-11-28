/// A Casa da fase 2 (docs/GDD.md, "Casa" e o "Primeiro recorte da casa", rev 400): onde fica, o Armazém (itens e criaturas
/// guardadas), os móveis instalados e o estado de cada estação. A produção está em `crafting/stations.dart`. Dart puro.
///
/// Privacidade: a célula da casa fica fora do bloco `home`, na chave própria [kHomeCellKey], que o backup e a exportação
/// tiram (`exportBackup`) e o QR do grupo nunca leva. O resto da casa vai no backup: sem a célula, a casa volta sem lugar.
library;

import 'dart:math' as math;

import '../core/species_ids.dart';
import '../core/tiles.dart';
import 'lot.dart';

/// A célula z21 da casa no save deste aparelho.
const String kHomeCellKey = 'home_cell';

/// Os números da Casa, por jogador (`balance.json`, `home`).
class HomeBalance {
  const HomeBalance({
    required this.unlockLevel,
    required this.moveCooldownS,
    required this.radiusM,
    required this.storageItems,
    required this.storageCreatures,
    required this.furnitureMax,
    required this.slotLevels,
    required this.periodS,
    required this.levelSpeed,
    required this.depositS,
    required this.archivePointsPerTask,
    this.lotSizes = const [(1, 16)],
    this.walkCps = 4,
    this.wanderCps = 0.6,
  });

  factory HomeBalance.fromJson(Map<String, dynamic> j) => HomeBalance(
        unlockLevel: j['unlock_level'] as int,
        moveCooldownS: (j['move_cooldown_days'] as int) * 86400,
        radiusM: (j['radius_m'] as num).toDouble(),
        storageItems: j['storage_items'] as int,
        storageCreatures: j['storage_creatures'] as int,
        furnitureMax: j['furniture_max'] as int,
        slotLevels: [for (final l in j['slot_levels'] as List<dynamic>) l as int],
        periodS: {for (final e in (j['period_s'] as Map<String, dynamic>).entries) e.key: e.value as int},
        levelSpeed: (j['level_speed'] as num).toDouble(),
        depositS: (j['deposit_h'] as int) * 3600,
        archivePointsPerTask: j['archive_points_per_task'] as int,
        lotSizes: [for (final p in (j['lot_sizes'] as List<dynamic>?) ?? const [[1, 16]]) ((p as List<dynamic>)[0] as int, p[1] as int)],
        walkCps: ((j['walk_cps'] as num?) ?? 4).toDouble(),
        wanderCps: ((j['wander_cps'] as num?) ?? 0.6).toDouble(),
      );

  final int unlockLevel;
  final int moveCooldownS;
  final double radiusM;
  final int storageItems, storageCreatures, furnitureMax;

  /// Os níveis em que cada vaga das estações abre (a primeira com a casa).
  final List<int> slotLevels;

  /// O tempo de um item por camada (`eco`, `spirit`, `ritual`, `major`), antes do nível.
  final Map<String, int> periodS;

  /// Quanto cada nível acima do 1 acelera (0,01: 1%).
  final double levelSpeed;

  /// O depósito guarda a produção deste tempo; cheio, a estação para.
  final int depositS;

  /// Pontos do Arquivo para uma tarefa de pesquisa do Bestiário.
  final int archivePointsPerTask;

  /// 0.29.0: o tamanho do lote por nível, pares (nível, casas).
  final List<(int, int)> lotSizes;

  /// Casas por segundo: o Conjurador andando no lote e as criaturas guardadas passeando.
  final double walkCps, wanderCps;

  int slotsAt(int playerLevel) => slotLevels.where((l) => l <= playerLevel).length;

  /// O tempo de um item da criatura [speciesId] no nível [level], ou `null` se ela não trabalha (o Arquétipo).
  int? periodOf(String speciesId, int level) {
    final key = isRitualOnlyId(speciesId)
        ? 'ritual'
        : switch (tierOfId(speciesId)) {
            SpeciesTier.eco => 'eco',
            SpeciesTier.spirit => 'spirit',
            SpeciesTier.major => 'major',
            SpeciesTier.archetype => null,
          };
    final base = key == null ? null : periodS[key];
    if (base == null) return null;
    return (base / (1 + levelSpeed * (level - 1))).round();
  }
}

/// Uma estação: quem trabalha (e desde quando cada um conta), o que ela faz, o depósito e a carga de insumos.
class StationState {
  StationState({List<String>? workers, Map<String, int>? since, Map<String, int>? stock, Map<String, int>? load, this.choice})
      : workers = workers ?? [],
        since = since ?? {},
        stock = stock ?? {},
        load = load ?? {};

  factory StationState.fromJson(Map<String, dynamic> j) => StationState(
        workers: [for (final w in (j['workers'] as List<dynamic>?) ?? const []) w as String],
        since: _ints(j['since']),
        stock: _ints(j['stock']),
        load: _ints(j['load']),
        choice: j['choice'] as String?,
      );

  final List<String> workers;

  /// Uid -> o instante (UTC) de onde conta o próximo item dele.
  final Map<String, int> since;

  /// O que já saiu e espera ser recolhido: chave de pilha -> quantidade (o Arquivo guarda pontos em `points`).
  final Map<String, int> stock;

  /// Os insumos já tirados do Armazém para as próximas peças: chave de pilha -> quantidade.
  final Map<String, int> load;

  /// O que ela faz agora: a receita (Forja, Fábrica de selos), a pilha de Essência (Adega) ou a espécie (Arquivo).
  String? choice;

  bool get isEmpty => workers.isEmpty && stock.isEmpty && load.isEmpty && choice == null;

  Map<String, dynamic> toJson() => {
        'workers': workers,
        'since': since,
        if (stock.isNotEmpty) 'stock': stock,
        if (load.isNotEmpty) 'load': load,
        if (choice != null) 'choice': choice,
      };
}

Map<String, int> _ints(Object? j) => {for (final e in ((j as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int};

/// A casa do jogador.
class HomeState {
  HomeState({this.cell, this.setUtc, Map<String, int>? storage, List<String>? stored, Map<String, StationState>? stations, LotState? lot})
      : storage = storage ?? {},
        stored = stored ?? [],
        stations = stations ?? {},
        lot = lot ?? LotState();

  /// [cell] vem da chave [kHomeCellKey], fora do bloco.
  factory HomeState.fromJson(Map<String, dynamic>? j, {(int, int)? cell}) => HomeState(
        cell: cell,
        setUtc: j?['set_utc'] as int?,
        storage: _ints(j?['storage']),
        stored: [for (final u in (j?['stored'] as List<dynamic>?) ?? const []) u as String],
        lot: LotState.fromJson(j?['lot'] as Map<String, dynamic>?),
        stations: {for (final e in ((j?['stations'] as Map<String, dynamic>?) ?? const {}).entries) e.key: StationState.fromJson(e.value as Map<String, dynamic>)},
      );

  /// A célula z21 da casa, ou `null` sem casa (ou depois de restaurar um backup, que não a leva).
  (int, int)? cell;

  /// Quando a casa foi definida pela última vez (a espera da troca conta daqui).
  int? setUtc;

  /// O Armazém: chave de pilha -> quantidade.
  final Map<String, int> storage;

  /// As criaturas guardadas no santuário sem trabalhar (uids).
  final List<String> stored;

  /// 0.29.0: o lote no Véu (o que está construído). Os móveis do Armazém e as estações valem colocados nele.
  final LotState lot;

  /// O estado de cada estação, pelo id (`forge`...).
  final Map<String, StationState> stations;

  StationState station(String id) => stations.putIfAbsent(id, StationState.new);

  /// As criaturas em casa: guardadas e trabalhando. Elas não entram no Círculo e não saem da coleção.
  Iterable<String> get creaturesAtHome sync* {
    yield* stored;
    for (final s in stations.values) {
      yield* s.workers;
    }
  }

  bool holds(String uid) => stored.contains(uid) || stations.values.any((s) => s.workers.contains(uid));

  /// A estação em que [uid] trabalha, ou `null`.
  String? stationOf(String uid) => stations.entries.where((e) => e.value.workers.contains(uid)).firstOrNull?.key;

  /// O centro da célula da casa em células z21.
  (double, double)? get center => cell == null ? null : (cell!.$1 + 0.5, cell!.$2 + 0.5);

  /// A distância em metros de ([lat], [lon]) até a casa, ou `null` sem casa.
  double? distanceM(double lat, double lon) {
    final c = center;
    if (c == null) return null;
    final (x, y) = latLonToTileFraction(lat, lon, biomeZoom);
    final dx = x - c.$1, dy = y - c.$2;
    return math.sqrt(dx * dx + dy * dy) * metersPerCell(lat);
  }

  Map<String, dynamic> toJson() => {
        if (setUtc != null) 'set_utc': setUtc,
        if (storage.isNotEmpty) 'storage': storage,
        if (stored.isNotEmpty) 'stored': stored,
        if (!lot.isEmpty) 'lot': lot.toJson(),
        if (stations.values.any((s) => !s.isEmpty)) 'stations': {for (final e in stations.entries) if (!e.value.isEmpty) e.key: e.value.toJson()},
      };
}
