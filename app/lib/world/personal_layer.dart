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
const kStormNightEco = 'storm_night_ecos_per_hour'; // Hum: Elétricos por hora perto de postes, à noite e na tempestade
const kExtraMaterial = 'extra_material_pct'; // Clod: material a mais na coleta
const kNightEco = 'night_eco_pct'; // Shade: um Eco em becos e sob marquises à noite, por célula e janela
const kFogEco = 'fog_ecos_per_hour'; // Wisp: Espectrais por hora na neblina e no Sagrado
const kHiddenChance = 'hidden_chance_pct'; // Bit: Oculto a mais nos Ecos da camada pessoal
const kVariantChance = 'variant_chance_pct'; // Sprig: variante a mais nos Ecos da camada pessoal

final int _saltEco = salt('pers_eco');
final int _saltHour = salt('pers_hr');

/// Vagas por bloco e hora do Hum e do Wisp: os sorteios de cada vaga saem sempre, e a faixa só decide quantas nascem.
const int _hourSlots = 4;
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
    this.shadeKinds = const {TrafficPointKind.shop, TrafficPointKind.bar, TrafficPointKind.alley},
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
      shadeKinds: kinds('shade_points'),
      wispTraceMult: (j['wisp_trace_mult'] as num).toDouble(),
      hiddenEssenceBonus: j['hidden_essence_bonus'] as int,
      buildKeepS: j['build_keep_s'] as int,
    );
  }

  /// O sol abaixo disto no começo da janela da célula é noite (Hum e Shade).
  final double nightSunDeg;

  /// Climas em que o Hum vale de dia; climas e biomas em que o Wisp vale.
  final Set<String> stormClimates, fogClimates, fogBiomes;

  /// Pontos do OSM (`*_traffic.bin`) que contam como poste (Hum) e como beco ou marquise (Shade).
  final Set<TrafficPointKind> poleKinds, shadeKinds;

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
    void keep(WorldSpawn s, int since) {
      final moved = field.climate?.move(s, since, tUtc, mpc) ?? s;
      if (moved.distanceM(px, py, mpc) <= radiusM) out.add(moved);
    }

    for (var cy = ((py - r) / 2).floor(); cy <= ((py + r) / 2).floor(); cy++) {
      for (var cx = ((px - r) / 2).floor(); cx <= ((px + r) / 2).floor(); cx++) {
        for (final s in cell(cx, cy, tUtc, playerLevel)) {
          keep(s, _windowStart(cx, cy, s.window));
        }
      }
    }
    for (var by = ((py - r) / 16).floor(); by <= ((py + r) / 16).floor(); by++) {
      for (var bx = ((px - r) / 16).floor(); bx <= ((px + r) / 16).floor(); bx++) {
        for (final s in block(bx, by, tUtc, playerLevel)) {
          keep(s, tUtc - tUtc % 3600);
        }
      }
    }
    addedEcos.addAll(out.map((s) => s.uid));
    return out;
  }

  /// O Eco da Shade na célula z20 `(cx, cy)` em [t]: à noite, numa célula com beco ou marquise, com a chance da faixa. Os
  /// oito sorteios saem sempre; a build (a do começo da janela da célula) só decide se ele nasce.
  List<WorldSpawn> cell(int cx, int cy, int t, int playerLevel) {
    final seed = field.seed;
    final window = windowIndex(seed, cx, cy, t);
    final ws = _windowStart(cx, cy, window);
    final b = buildAt(builds(), ws);
    final pct = (b?.of(kNightEco) ?? 0) / 100;
    if (b == null || pct <= 0) return const [];
    final ctx = _context(t);
    if (ctx == null) return const [];
    final h = fnv1a64([seed, playerKey, ctx.epoch.id, cx, cy, window, _saltEco]);
    final rng = Pcg32(h, saltKenoma);
    final r = _Rolls(rng);
    final anchors = [for (final p in _points(cx * 2.0, cy * 2.0, 2)) if (balance.shadeKinds.contains(p.kind)) p];
    if (r.roll >= pct || anchors.isEmpty || !_night(cx, cy, ws)) return const [];
    final biome = _biome(cx, cy);
    final climate = field.weatherAt?.call(cx, cy, ws) ?? 'clear';
    final cond = ctx.epoch.ecoV2!.conditions;
    final sc = field.contextOf(ctx.epoch, cx, cy, ws, climate);
    final species = _fromTable(ctx.def.table[biome], r.pick, (id) => sc == null ? 1 : cond?.mult(id, sc) ?? 1);
    final a = anchors[(r.px * anchors.length).floor().clamp(0, anchors.length - 1)];
    final eco = _eco(fnv1a64([h, 1, saltUid]), species, a.x, a.y, window, r, b, ctx, biome, playerLevel);
    return eco == null ? const [] : [eco];
  }

  /// Os Ecos por hora do Hum e do Wisp no bloco z17 `(bx, by)` (uns 300 m) na hora UTC de [t]: até [_hourSlots] vagas de
  /// cada um, que valem a hora inteira. Quantas nascem é a faixa da build do começo da janela de 20 min do bloco (a troca do
  /// Círculo entra em até 20 min, e a faixa maior só acrescenta vagas). O Hum nasce num poste à noite ou na tempestade; o
  /// Wisp, numa célula do bloco com neblina ou no Sagrado.
  List<WorldSpawn> block(int bx, int by, int t, int playerLevel) {
    final b = buildFor(bx, by, t);
    final hum = (b?.of(kStormNightEco) ?? 0).round(), wisp = (b?.of(kFogEco) ?? 0).round();
    if (b == null || hum + wisp <= 0) return const [];
    final ctx = _context(t);
    if (ctx == null) return const [];
    final hour = t ~/ 3600, start = hour * 3600;
    final h = fnv1a64([field.seed, playerKey, ctx.epoch.id, bx, by, hour, _saltHour]);
    final rng = Pcg32(h, saltKenoma);
    final out = <WorldSpawn>[];
    final poles = hum <= 0 ? const <TrafficPoint>[] : [for (final p in _points(bx * 16.0, by * 16.0, 16)) if (balance.poleKinds.contains(p.kind)) p];
    final fogCells = wisp <= 0
        ? const <(int, int)>[]
        : [
            for (var cy = by * 8; cy < by * 8 + 8; cy++)
              for (var cx = bx * 8; cx < bx * 8 + 8; cx++)
                if (balance.fogBiomes.contains(_biome(cx, cy)) || balance.fogClimates.contains(field.weatherAt?.call(cx, cy, start) ?? 'clear')) (cx, cy),
          ];
    for (var kind = 0; kind < 2; kind++) {
      for (var k = 0; k < _hourSlots; k++) {
        final r = _Rolls(rng);
        if (k >= (kind == 0 ? hum : wisp)) continue;
        double x, y;
        if (kind == 0) {
          if (poles.isEmpty) continue;
          final p = poles[(r.px * poles.length).floor().clamp(0, poles.length - 1)];
          final (cx, cy) = (p.x.floor() >>> 1, p.y.floor() >>> 1);
          if (!_night(cx, cy, start) && !balance.stormClimates.contains(field.weatherAt?.call(cx, cy, start) ?? 'clear')) continue;
          (x, y) = (p.x, p.y);
        } else {
          if (fogCells.isEmpty) continue;
          final (cx, cy) = fogCells[(r.px * fogCells.length).floor().clamp(0, fogCells.length - 1)];
          final w = ctx.epoch.walkable;
          final sn = w == null ? null : field.snapper?.snap(cx, cy, r.roll, r.py, maxOffM: w.ecoOffPathM, maxDistM: w.maxDistM);
          if (sn != null && !sn.keep) continue;
          (x, y) = ((cx + (sn?.px ?? r.roll)) * 2, (cy + (sn?.py ?? r.py)) * 2);
        }
        final (cx, cy) = (x.floor() >>> 1, y.floor() >>> 1);
        final species = field.climate?.speciesOfTypeIn(kind == 0 ? 'electric' : 'spectral', r.pick, t);
        final eco = _eco(fnv1a64([h, kind, k, saltUid]), species, x, y, windowIndex(field.seed, cx, cy, t), r, b, ctx, _biome(cx, cy), playerLevel);
        if (eco != null) out.add(eco);
      }
    }
    return out;
  }

  ({Epoch epoch, SpawnItemDef def})? _context(int t) {
    final epoch = field.schedule.select(t).epoch;
    final def = epoch.items.where((d) => d.kind == 'eco').firstOrNull;
    return epoch.ecoV2 == null || def == null ? null : (epoch: epoch, def: def);
  }

  String _biome(int cx, int cy) => field.map.biomes.spawnKey(field.map.spawnBiomeAtCell(cx, cy));

  List<TrafficPoint> _points(double x, double y, double size) => points?.pointsIn(x, y, x + size, y + size) ?? const <TrafficPoint>[];

  bool _night(int cx, int cy, int t) {
    final (lat, lon) = tileFractionToLatLon(cx * 2 + 1.0, cy * 2 + 1.0, biomeZoom);
    return sunAltitudeDeg(lat, lon, t) < balance.nightSunDeg;
  }

  /// O Eco pessoal com os sorteios [r]: nível pelo delta da época, variante (com o Sprig), Brilhante e Oculto (com o Bit).
  WorldSpawn? _eco(int uid, String? species, double x, double y, int window, _Rolls r, BuildEntry b, ({Epoch epoch, SpawnItemDef def}) ctx, String biome, int playerLevel) {
    final v2 = ctx.epoch.ecoV2!, def = ctx.def;
    if (species == null || !(v2.conditions?.visibleTo(species, playerLevel) ?? true)) return null;
    final weights = v2.behaviorWeights.values.fold(0, (a, c) => a + c);
    final hiddenP = (weights == 0 ? 0 : (v2.behaviorWeights['hidden'] ?? 0) / weights) + b.of(kHiddenChance) / 100;
    final span = def.hasLevelDelta ? def.levelDeltaMax! - def.levelDeltaMin! + 1 : 1;
    final delta = (def.levelDeltaMin ?? 0) + (r.lv * span).floor().clamp(0, span - 1);
    return WorldSpawn(
      uid: uid,
      kind: 'eco',
      entryId: species,
      quantity: 1,
      x: x,
      y: y,
      cellX: x.floor() >>> 1,
      cellY: y.floor() >>> 1,
      window: window,
      level: _levels.putIfAbsent(uid, () => (playerLevel + delta).clamp(1, field.levelCapOf?.call(species) ?? 20)),
      behavior: r.hr < hiddenP ? EcoBehavior.hidden : EcoBehavior.passive,
      variant: r.vr < v2.variantChance + b.of(kVariantChance) / 100 ? biome : null,
      shiny: r.sr < v2.shinyChance,
      personal: true,
    );
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

/// Os oito sorteios de uma vaga, sempre na mesma ordem, nasça ela ou não.
class _Rolls {
  _Rolls(Pcg32 rng)
      : roll = rng.nextFloat(),
        pick = rng.nextFloat(),
        px = rng.nextFloat(),
        py = rng.nextFloat(),
        lv = rng.nextFloat(),
        vr = rng.nextFloat(),
        sr = rng.nextFloat(),
        hr = rng.nextFloat();

  final double roll, pick, px, py, lv, vr, sr, hr;
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
