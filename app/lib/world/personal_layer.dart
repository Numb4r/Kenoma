/// A camada pessoal de spawn (GDD, "Geração determinística"): por cima do mundo base, que continua igual para todos, o que
/// as habilidades de mapa do Círculo acrescentam só para este jogador. Ela só ACRESCENTA (Ecos, poças, material, chance de
/// variante e de Oculto nos Ecos dela) e nunca tira nada da base.
///
/// Estável: os sorteios saem de `hash(seed, player_id, época, célula, janela)` e sempre na mesma ordem, nasça algo ou não;
/// a build que vale numa célula é a do começo da janela dela (`personal_build.dart`), então trocar o Círculo só muda a
/// janela seguinte, e voltar à mesma build devolve o mesmo resultado. Uma faixa maior de uma habilidade só acrescenta ao que
/// a menor dava. Os números ficam no `balance.json` (`personal_layer`), fora das épocas: só afetam o próprio jogador.
/// Dart puro.
library;

import 'dart:convert' show utf8;

import '../core/astro.dart';
import '../core/behavior.dart';
import '../core/epochs.dart';
import '../core/fnv.dart';
import '../core/pcg32.dart';
import '../core/tiles.dart';
import '../core/windows.dart';
import '../data/traffic_pack.dart';
import '../player/personal_build.dart';
import 'spawn_field.dart';

/// As chaves das habilidades que mexem na camada pessoal (`creatures.json`, `ability.kind`).
const kRainPuddles = 'rain_puddles'; // Rill: poças a mais na chuva
const kStormNightEco = 'storm_night_eco_pct'; // Hum: Elétricos perto de postes à noite e na tempestade
const kExtraMaterial = 'extra_material_pct'; // Clod: material a mais na coleta
const kNightEco = 'night_eco_pct'; // Shade: um Eco sob as marquises à noite
const kFogEco = 'fog_eco_pct'; // Wisp: Espectrais na neblina e no Sagrado
const kHiddenChance = 'hidden_chance_pct'; // Bit: Oculto a mais nos Ecos da camada pessoal
const kVariantChance = 'variant_chance_pct'; // Sprig: variante a mais nos Ecos da camada pessoal

final int _saltEco = salt('pers_eco');
final int _saltPuddle = salt('pers_pud');
final int _saltClod = salt('pers_mat');

/// O bloco `personal_layer` do `balance.json`.
class PersonalBalance {
  const PersonalBalance({
    this.nightSunDeg = -6,
    this.stormClimates = const {'storm'},
    this.fogClimates = const {'fog'},
    this.fogBiomes = const {'sacred'},
    this.poleKinds = const {TrafficPointKind.signal, TrafficPointKind.busStop},
    this.marqueeKinds = const {TrafficPointKind.shop, TrafficPointKind.bar},
    this.wispTraceMult = 1.5,
    this.hiddenEssenceBonus = 2,
    this.buildKeepS = 86400,
  });

  factory PersonalBalance.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const PersonalBalance();
    Set<String> ids(String k) => {for (final v in j[k] as List<dynamic>) v as String};
    Set<TrafficPointKind> kinds(String k) => {for (final v in j[k] as List<dynamic>) TrafficPointKind.values.byName(v as String)};
    return PersonalBalance(
      nightSunDeg: (j['night_sun_deg'] as num).toDouble(),
      stormClimates: ids('storm_climates'),
      fogClimates: ids('fog_climates'),
      fogBiomes: ids('fog_biomes'),
      poleKinds: kinds('pole_points'),
      marqueeKinds: kinds('marquee_points'),
      wispTraceMult: (j['wisp_trace_mult'] as num).toDouble(),
      hiddenEssenceBonus: j['hidden_essence_bonus'] as int,
      buildKeepS: j['build_keep_s'] as int,
    );
  }

  /// O sol abaixo disto no começo da janela da célula é noite (Hum e Shade).
  final double nightSunDeg;

  /// Climas em que o Hum vale de dia; climas e biomas em que o Wisp vale.
  final Set<String> stormClimates, fogClimates, fogBiomes;

  /// Pontos do OSM (`*_traffic.bin`) que contam como poste (Hum) e como marquise (Shade).
  final Set<TrafficPointKind> poleKinds, marqueeKinds;

  /// Quanto os rastros do Radar duram a mais com um Wisp no Círculo.
  final double wispTraceMult;

  /// Essência a mais na destilação de um Eco que era Oculto, com um Bit no Círculo.
  final int hiddenEssenceBonus;

  /// Por quanto tempo o save guarda as builds antigas.
  final int buildKeepS;
}

/// O `player_id` como número, para os hashes da camada pessoal.
int playerKeyOf(String playerId) => fnv1a64Bytes(utf8.encode(playerId));

class PersonalLayer {
  PersonalLayer({required this.field, required this.playerKey, required this.builds, this.balance = const PersonalBalance(), this.points, this.hidden = _never});

  /// O mundo base: a seed, as épocas, o mapa, o clima e os caminhos são os dele.
  final SpawnField field;
  final int playerKey;
  final PersonalBalance balance;

  /// As builds do save, pelo tempo.
  final List<BuildEntry> Function() builds;

  /// Postes e marquises (pontos do OSM do tráfego, cenário). `null` (fallback, testes): Hum e Shade sem onde nascer.
  final TrafficPointSource? points;

  /// O interruptor do debug: esconde a camada pessoal para conferir a base.
  final bool Function() hidden;

  /// O que a camada acrescentou nesta sessão, para o debug: os Ecos (uids), as poças (por célula z17 e janela de chuva) e
  /// as unidades de material.
  final addedEcos = <int>{};
  final _addedPuddles = <(int, int, int), int>{};
  int addedMaterials = 0;

  int get addedPuddles => _addedPuddles.values.fold(0, (a, b) => a + b);

  final _levels = <int, int>{};

  int _windowStart(int cx, int cy, int window) => window * windowSeconds - windowOffset(field.seed, cx, cy);

  /// A build que vale na célula `(cx, cy)` em [t]: a do começo da janela dela.
  BuildEntry? buildFor(int cx, int cy, int t) => buildAt(builds(), _windowStart(cx, cy, windowIndex(field.seed, cx, cy, t)));

  /// Os Ecos da camada pessoal a até [radiusM] metros de ([lat], [lon]) em [tUtc]. Vazio com o interruptor do debug.
  List<WorldSpawn> around({required double lat, required double lon, required int tUtc, required double radiusM, required int playerLevel}) {
    if (hidden()) return const [];
    final (px, py) = latLonToTileFraction(lat, lon, biomeZoom);
    final mpc = metersPerCell(lat);
    final r = radiusM / mpc;
    final out = <WorldSpawn>[];
    for (var cy = ((py - r) / 2).floor(); cy <= ((py + r) / 2).floor(); cy++) {
      for (var cx = ((px - r) / 2).floor(); cx <= ((px + r) / 2).floor(); cx++) {
        for (final s in cell(cx, cy, tUtc, playerLevel)) {
          final moved = field.climate?.move(s, _windowStart(cx, cy, s.window), tUtc, mpc) ?? s;
          if (moved.distanceM(px, py, mpc) <= radiusM) out.add(moved);
        }
      }
    }
    addedEcos.addAll(out.map((s) => s.uid));
    return out;
  }

  /// Os Ecos da camada pessoal na célula z20 `(cx, cy)` em [t]. Três vagas (Hum, Shade, Wisp), cada uma com os mesmos oito
  /// sorteios sempre: a vaga dá o mesmo resultado com qualquer build, e a build só decide se ela nasce.
  List<WorldSpawn> cell(int cx, int cy, int t, int playerLevel) {
    final seed = field.seed;
    final window = windowIndex(seed, cx, cy, t);
    final ws = _windowStart(cx, cy, window);
    final b = buildAt(builds(), ws);
    if (b == null) return const [];
    final pct = [b.of(kStormNightEco) / 100, b.of(kNightEco) / 100, b.of(kFogEco) / 100];
    if (pct.every((p) => p <= 0)) return const [];
    final epoch = field.schedule.select(t).epoch;
    final v2 = epoch.ecoV2;
    final def = epoch.items.where((d) => d.kind == 'eco').firstOrNull;
    if (v2 == null || def == null) return const [];
    final biome = field.map.biomes.spawnKey(field.map.spawnBiomeAtCell(cx, cy));
    final climate = field.weatherAt?.call(cx, cy, ws) ?? 'clear';
    final (lat, lon) = tileFractionToLatLon(cx * 2 + 1.0, cy * 2 + 1.0, biomeZoom);
    final night = sunAltitudeDeg(lat, lon, ws) < balance.nightSunDeg;
    final pts = points?.pointsIn(cx * 2.0, cy * 2.0, cx * 2.0 + 2, cy * 2.0 + 2) ?? const <TrafficPoint>[];
    final poles = [for (final p in pts) if (balance.poleKinds.contains(p.kind)) p];
    final marquees = [for (final p in pts) if (balance.marqueeKinds.contains(p.kind)) p];
    final on = [
      (night || balance.stormClimates.contains(climate)) && poles.isNotEmpty,
      night && marquees.isNotEmpty,
      balance.fogClimates.contains(climate) || balance.fogBiomes.contains(biome),
    ];
    final weights = v2.behaviorWeights.values.fold(0, (a, b) => a + b);
    final hiddenP = (weights == 0 ? 0 : (v2.behaviorWeights['hidden'] ?? 0) / weights) + b.of(kHiddenChance) / 100;
    final variantP = v2.variantChance + b.of(kVariantChance) / 100;
    final cond = v2.conditions;
    final h = fnv1a64([seed, playerKey, epoch.id, cx, cy, window, _saltEco]);
    final rng = Pcg32(h, saltKenoma);
    final out = <WorldSpawn>[];
    for (var k = 0; k < 3; k++) {
      final roll = rng.nextFloat(), pick = rng.nextFloat(), px = rng.nextFloat(), py = rng.nextFloat();
      final lv = rng.nextFloat(), vr = rng.nextFloat(), sr = rng.nextFloat(), hr = rng.nextFloat();
      if (!on[k] || roll >= pct[k]) continue;
      String? species;
      double x, y;
      if (k == 2) {
        species = field.climate?.speciesOfTypeIn('spectral', pick, t);
        final w = epoch.walkable;
        final s = w == null ? null : field.snapper?.snap(cx, cy, px, py, maxOffM: w.ecoOffPathM, maxDistM: w.maxDistM);
        if (s != null && !s.keep) continue;
        (x, y) = ((cx + (s?.px ?? px)) * 2, (cy + (s?.py ?? py)) * 2);
      } else {
        final anchors = k == 0 ? poles : marquees;
        final a = anchors[(px * anchors.length).floor().clamp(0, anchors.length - 1)];
        (x, y) = (a.x, a.y);
        if (k == 0) {
          species = field.climate?.speciesOfTypeIn('electric', pick, t);
        } else {
          final ctx = field.contextOf(epoch, cx, cy, ws, climate);
          species = _fromTable(def.table[biome], pick, (id) => ctx == null ? 1 : cond?.mult(id, ctx) ?? 1);
        }
      }
      if (species == null || !(cond?.visibleTo(species, playerLevel) ?? true)) continue;
      final uid = fnv1a64([h, k, saltUid]);
      final span = def.hasLevelDelta ? def.levelDeltaMax! - def.levelDeltaMin! + 1 : 1;
      final delta = (def.levelDeltaMin ?? 0) + (lv * span).floor().clamp(0, span - 1);
      out.add(WorldSpawn(
        uid: uid,
        kind: 'eco',
        entryId: species,
        quantity: 1,
        x: x,
        y: y,
        cellX: cx,
        cellY: cy,
        window: window,
        level: _levels.putIfAbsent(uid, () => (playerLevel + delta).clamp(1, field.levelCapOf?.call(species!) ?? 20)),
        behavior: hr < hiddenP ? EcoBehavior.hidden : EcoBehavior.passive,
        variant: vr < variantP ? biome : null,
        shiny: sr < v2.shinyChance,
        personal: true,
      ));
    }
    return out;
  }

  /// As poças a mais do Rill na célula z17 `(cx17, cy17)` durante a chuva da janela [wetWindow]: a chave dos sorteios e
  /// quantas. As posições e os sorteios dependem só do jogador e da chuva; a build (do começo da janela de 20 min da
  /// célula) decide quantas, então a faixa maior só acrescenta poças. `null`: nenhuma.
  ({int key, int count})? puddlesAt(int cx17, int cy17, int wetWindow, int t) {
    if (hidden()) return null;
    final n = (buildFor(cx17, cy17, t)?.of(kRainPuddles) ?? 0).round();
    if (n <= 0) return null;
    _addedPuddles[(cx17, cy17, wetWindow)] = n;
    return (key: fnv1a64([field.seed, playerKey, _saltPuddle]), count: n);
  }

  /// Unidades de material a mais na coleta de [s] (Clod): o sorteio é do jogador e do uid, e a chance é a da build do
  /// começo da janela do material (a do instante, nos materiais do clima).
  int extraMaterial(WorldSpawn s, int t) {
    if (hidden() || !s.isMaterial) return 0;
    final from = s.window == 0 ? t : _windowStart(s.cellX, s.cellY, s.window);
    final pct = buildAt(builds(), from)?.of(kExtraMaterial) ?? 0;
    if (pct <= 0 || Pcg32(fnv1a64([playerKey, s.uid, _saltClod]), saltKenoma).nextFloat() >= pct / 100) return 0;
    addedMaterials++;
    return 1;
  }

  /// O resumo do debug: o que a camada acrescentou nesta sessão.
  String get stats => '${addedEcos.length} Ecos · $addedPuddles poças · $addedMaterials materiais';
}

/// A espécie da tabela ponderada de um bioma, com os pesos das condições da família. `null` se nada tem peso.
String? _fromTable(List<WeightedEntry>? table, double pick, double Function(String id) mult) {
  if (table == null || table.isEmpty) return null;
  final w = [for (final e in table) e.weight * mult(e.id)];
  final total = w.fold(0.0, (a, b) => a + b);
  if (total <= 0) return null;
  var target = pick * total;
  for (var i = 0; i < table.length; i++) {
    if (target < w[i]) return table[i].id;
    target -= w[i];
  }
  return table.last.id;
}

bool _never() => false;
