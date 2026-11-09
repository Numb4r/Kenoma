/// Clima da época 6 em diante (docs/GDD.md, "Tempo, astronomia e clima"), orientado a dados. O bloco `climate` da época
/// guarda tudo o que muda o mundo: o sorteio por estação e hora local, os multiplicadores de spawn por tipo e as peças de
/// interação de cada clima. O código só conhece as peças (a época 7 soma as poças, o calendário e a astronomia); os climas
/// são combinações delas em dado. O que é só visual (camadas, ícone, nome, cobertura das ruas) mora em
/// `assets/data/clima.json`. Dart puro.
///
/// Tudo sai da seed: o clima por janela de 3 horas e região (tile z12, como o modelo antigo), e cada acontecimento (raio,
/// poça, pé do arco-íris, redemoinho) por célula z17 e janela, em fluxos com sal próprio que não tocam nos sorteios dos
/// spawns. As épocas 0 a 5 não têm o bloco e seguem com o modelo de quatro estados de `weather.dart`.
library;

import 'dart:math' as math;

import 'astro.dart';
import 'fnv.dart';
import 'pcg32.dart';

/// Sal do sorteio do clima da época 6 (separado do `WTHR` do modelo antigo).
final int saltClimate = salt('CLM6');

/// Sal dos acontecimentos de cada peça (quedas e zonas) por célula z17 e janela.
final int saltClimateFx = salt('CFX6');

/// Sal do uid das criaturas e itens que as peças fazem nascer.
final int saltClimateUid = salt('CUID6');

/// Sal da direção do vento por região e janela.
final int saltWind = salt('WIND6');

/// Época 7: os pontos baixos das poças (fixos por célula z17), os sorteios de cada poça por janela de chuva, a chance dos
/// eventos do calendário e da astronomia. Fluxos próprios: não tocam em nenhum sorteio da época 6.
final int saltPuddle = salt('PDL7');
final int saltPuddleFx = salt('PDLFX7');
final int saltCalendar = salt('CAL7');

/// Categorias do GDD. Só os nativos entram no sorteio; os outros só por evento ou debug.
enum ClimateCategory { native, otherRegion, mystic }

ClimateCategory _category(String s) => switch (s) {
      'native' => ClimateCategory.native,
      'other_region' => ClimateCategory.otherRegion,
      'mystic' => ClimateCategory.mystic,
      _ => throw FormatException('categoria de clima desconhecida: $s'),
    };

double _d(Object? v, [double fallback = 0]) => v == null ? fallback : (v as num).toDouble();
(int, int) _range(Object? v, (int, int) fallback) {
  final l = v as List<dynamic>?;
  return l == null ? fallback : ((l[0] as num).toInt(), (l[1] as num).toInt());
}

/// Uma criatura que uma peça faz nascer. [type] é o tipo pedido (`electric`, `water`...); sem espécie desse tipo no jogo,
/// nasce [fallbackSpecies] com a marca [tag], e sem fallback não nasce nada (o dado fica sem efeito até a espécie existir).
class PieceSpawn {
  const PieceSpawn({required this.type, this.fallbackSpecies, this.tag, required this.chance, required this.levelAdd, required this.ttlS, this.perZone = 1});

  factory PieceSpawn.fromJson(Map<String, dynamic> j) => PieceSpawn(
        type: j['type'] as String,
        fallbackSpecies: j['fallback_species'] as String?,
        tag: j['tag'] as String?,
        chance: _d(j['chance'], 1),
        levelAdd: _range(j['level_add'], (0, 0)),
        ttlS: (j['ttl_s'] as num?)?.toInt() ?? 600,
        perZone: (j['per_zone'] as num?)?.toInt() ?? 1,
      );

  final String type;
  final String? fallbackSpecies;
  final String? tag;
  final double chance;
  final (int, int) levelAdd;
  final int ttlS;

  /// Nas zonas: quantas nascem em cada uma.
  final int perZone;
}

/// Um item que uma peça faz cair ou nascer. [ids] é sorteado; o que não existe em `items.json` vira [fallback].
class PieceItem {
  const PieceItem({required this.ids, this.fallback, required this.kind, required this.qty, required this.chance, required this.ttlS, this.biomes, this.perZone = 1, this.revealM});

  factory PieceItem.fromJson(Map<String, dynamic> j) => PieceItem(
        ids: [for (final i in j['ids'] as List<dynamic>) i as String],
        fallback: j['fallback'] as String?,
        kind: j['kind'] as String? ?? 'material',
        qty: _range(j['qty'], (1, 1)),
        chance: _d(j['chance'], 1),
        ttlS: (j['ttl_s'] as num?)?.toInt() ?? 300,
        biomes: (j['biomes'] as List<dynamic>?)?.cast<String>(),
        perZone: (j['per_zone'] as num?)?.toInt() ?? 1,
        revealM: (j['reveal_m'] as num?)?.toDouble(),
      );

  final List<String> ids;
  final String? fallback;

  /// `spark` (a Aura pega sozinha) ou `material` (toque).
  final String kind;
  final (int, int) qty;
  final double chance;
  final int ttlS;

  /// Só nasce nestes biomas de spawn (`null`: em todos).
  final List<String>? biomes;
  final int perZone;

  /// Escondido (a duna): só aparece para quem está a até isto do ponto. `null`: sempre.
  final double? revealM;
}

/// As peças. [name] liga a peça ao visual em `clima.json` e ao debug ("raio", "granizo", "redemoinho", "meteoro").
sealed class ClimatePiece {
  const ClimatePiece(this.name);

  final String name;

  static ClimatePiece fromJson(Map<String, dynamic> j) {
    final name = j['name'] as String? ?? j['piece'] as String;
    return switch (j['piece'] as String) {
      'impact' || 'collectible' => DropPiece(
          name,
          impact: j['piece'] == 'impact',
          everyS: _range(j['every_s'], (20, 60)),
          spawn: j['spawn'] == null ? null : PieceSpawn.fromJson(j['spawn'] as Map<String, dynamic>),
          item: j['item'] == null ? null : PieceItem.fromJson(j['item'] as Map<String, dynamic>),
          item2: j['item2'] == null ? null : PieceItem.fromJson(j['item2'] as Map<String, dynamic>),
        ),
      'zone' || 'ghost' => ZonePiece(
          name,
          ghost: j['piece'] == 'ghost',
          perCell: (j['per_cell'] as num?)?.toInt() ?? 1,
          radiusM: _d(j['radius_m'], 25),
          durationS: (j['duration_s'] as num?)?.toInt() ?? 900,
          speedMps: _d(j['speed_mps']),
          spawn: j['spawn'] == null ? null : PieceSpawn.fromJson(j['spawn'] as Map<String, dynamic>),
          item: j['item'] == null ? null : PieceItem.fromJson(j['item'] as Map<String, dynamic>),
          snap: j['snap'] as bool? ?? false,
          slotAt: (j['slot_at'] as num?)?.toDouble(),
        ),
      'puddles' => PuddlePiece(
          name,
          perCell: (j['per_cell'] as num?)?.toInt() ?? 4,
          radiusM: _range(j['radius_m'], (4, 10)),
          growS: (j['grow_s'] as num?)?.toInt() ?? 1800,
          dryS: (j['dry_s'] as num?)?.toInt() ?? 3600,
          frozen: j['frozen'] as bool? ?? false,
          always: j['always'] as bool? ?? false,
          spawn: j['spawn'] == null ? null : PieceSpawn.fromJson(j['spawn'] as Map<String, dynamic>),
          item: j['item'] == null ? null : PieceItem.fromJson(j['item'] as Map<String, dynamic>),
        ),
      'modifier' => ModifierPiece(
          name,
          auraAddM: _d(j['aura_add_m']),
          viewMaxM: (j['view_max_m'] as num?)?.toDouble(),
          toleranceMult: _d(j['tolerance_mult'], 1),
          wanderMult: _d(j['wander_mult'], 1),
          immuneSchool: j['immune_school'] as String?,
          calm: j['calm'] as bool? ?? false,
          levelAdd: (j['level_add'] as num?)?.toInt() ?? 0,
          shinyMult: _d(j['shiny_mult'], 1),
          variantMult: _d(j['variant_mult'], 1),
          effects: (j['effects'] as List<dynamic>?)?.cast<String>() ?? const [],
        ),
      'movement' => MovementPiece(
          name,
          sparkDriftMps: _d(j['spark_drift_mps']),
          driftMaxM: _d(j['drift_max_m']),
          headingDeg: (j['heading_deg'] as num?)?.toDouble(),
          trafficMult: _d(j['traffic_mult'], 1),
          walkerMult: _d(j['walker_mult'], 1),
          sparkTtlS: (j['spark_ttl_s'] as num?)?.toInt(),
        ),
      'trails' => TrailsPiece(
          name,
          player: j['player'] as bool? ?? false,
          ecoTracksM: _d(j['eco_tracks_m']),
          traceTimeMult: _d(j['trace_time_mult'], 1),
        ),
      final other => throw FormatException('peça de clima desconhecida: $other'),
    };
  }
}

/// Ponto de impacto (raio, meteoro) e coletável que cai do céu (granizo, Fagulhas): acontecimentos a cada [everyS]
/// segundos (sorteados entre os dois valores) num ponto da célula z17. Só o desenho difere entre os dois.
class DropPiece extends ClimatePiece {
  const DropPiece(super.name, {required this.impact, required this.everyS, this.spawn, this.item, this.item2});

  final bool impact;
  final (int, int) everyS;
  final PieceSpawn? spawn;
  final PieceItem? item;

  /// Época 7: um segundo item no mesmo ponto, com o mesmo sorteio de escolha (o material raro da cratera do meteoro).
  final PieceItem? item2;
}

/// Zona temporária (poça, miragem, sombra de nuvem, redemoinho que anda) e sobreposição fantasma (Maré do Véu): [perCell]
/// zonas por célula z17 e janela, cada uma por [durationS] segundos, andando a [speedMps] numa direção sorteada.
class ZonePiece extends ClimatePiece {
  const ZonePiece(super.name, {required this.ghost, required this.perCell, required this.radiusM, required this.durationS, required this.speedMps, this.spawn, this.item, this.snap = false, this.slotAt});

  final bool ghost;
  final int perCell;
  final double radiusM;
  final int durationS;
  final double speedMps;
  final PieceSpawn? spawn;
  final PieceItem? item;

  /// Época 7: a zona parada nasce sobre a rua mais próxima (fuligem, duna, olhar), pelo mesmo `PathSnapper` dos spawns.
  final bool snap;

  /// Época 7: na zona que anda, todas as vagas aparecem nesta fração do percurso (0,95: o fim do rastro da Procissão).
  final double? slotAt;
}

/// Época 7: poças nos pontos baixos das ruas. Os pontos são fixos por célula z17 (a mesma poça em toda chuva); crescem em
/// [growS] segundos desde o começo da chuva e, quando ela acaba, secam em [dryS]. [always]: a poça existe inteira a janela
/// toda (a Geada forte congela os pontos baixos mesmo sem chuva). [frozen]: é gelo.
class PuddlePiece extends ClimatePiece {
  const PuddlePiece(super.name, {required this.perCell, required this.radiusM, required this.growS, required this.dryS, required this.frozen, required this.always, this.spawn, this.item});

  final int perCell;
  final (int, int) radiusM;
  final int growS;
  final int dryS;
  final bool frozen;
  final bool always;
  final PieceSpawn? spawn;
  final PieceItem? item;
}

/// Modificador do jogador: Aura, alcance de visão dos Ecos, sintonia, Ecos calmos, nível e Brilhante. [effects] lista os
/// efeitos pedidos pelo GDD que ainda não têm alvo no jogo (Exposição ao Véu, Espectrais...): só dado.
class ModifierPiece extends ClimatePiece {
  const ModifierPiece(
    super.name, {
    required this.auraAddM,
    this.viewMaxM,
    required this.toleranceMult,
    required this.wanderMult,
    this.immuneSchool,
    required this.calm,
    required this.levelAdd,
    required this.shinyMult,
    this.variantMult = 1,
    this.effects = const [],
  });

  final double auraAddM;
  final double? viewMaxM;
  final double toleranceMult;

  /// A deriva do sinal na sintonia vezes isto (ruído). [immuneSchool] não sente o ruído.
  final double wanderMult;
  final String? immuneSchool;

  /// Ecos não fogem nem atacam.
  final bool calm;

  /// Níveis a mais nos Ecos que aparecem (individual, como o nível).
  final int levelAdd;

  /// A chance de Brilhante vezes isto (muda o mundo: está na época).
  final double shinyMult;

  /// A chance de variante vezes isto (Lua Dupla, época 7).
  final double variantMult;
  final List<String> effects;
}

/// Movimento: Fagulhas derivam com o vento (até [driftMaxM] metros desde o começo da janela da célula), somem depois de
/// [sparkTtlS] segundos e o tráfego anda [trafficMult] vezes a velocidade.
class MovementPiece extends ClimatePiece {
  const MovementPiece(super.name, {required this.sparkDriftMps, required this.driftMaxM, this.headingDeg, required this.trafficMult, this.walkerMult = 1, this.sparkTtlS});

  final double sparkDriftMps;
  final double driftMaxM;

  /// Direção fixa (graus a partir do norte, sentido horário). `null`: a do vento sorteado da região.
  final double? headingDeg;
  final double trafficMult;

  /// Só os passantes e ciclistas fantasmas, vezes [trafficMult] (Geada forte: chão escorregadio).
  final double walkerMult;
  final int? sparkTtlS;
}

/// Rastros visíveis: pegadas do jogador, pegadas dos Ecos até [ecoTracksM] metros e rastros do Radar [traceTimeMult]
/// vezes mais longos.
class TrailsPiece extends ClimatePiece {
  const TrailsPiece(super.name, {required this.player, required this.ecoTracksM, required this.traceTimeMult});

  final bool player;
  final double ecoTracksM;
  final double traceTimeMult;
}

class ClimateDef {
  const ClimateDef({required this.id, required this.category, this.spawn = const {}, this.pieces = const []});

  factory ClimateDef.fromJson(String id, Map<String, dynamic> j) => ClimateDef(
        id: id,
        category: _category(j['category'] as String),
        spawn: {for (final e in ((j['spawn'] as Map<String, dynamic>?) ?? const {}).entries) e.key: _d(e.value)},
        pieces: [for (final p in (j['pieces'] as List<dynamic>?) ?? const []) ClimatePiece.fromJson(p as Map<String, dynamic>)],
      );

  final String id;
  final ClimateCategory category;

  /// `tipo -> multiplicador` do peso de spawn. Tipos sem espécie no jogo ficam sem efeito.
  final Map<String, double> spawn;
  final List<ClimatePiece> pieces;

  T? _first<T>() {
    for (final p in pieces) {
      if (p is T) return p as T;
    }
    return null;
  }

  ModifierPiece? get modifier => _first<ModifierPiece>();
  MovementPiece? get movement => _first<MovementPiece>();
  TrailsPiece? get trails => _first<TrailsPiece>();
  PuddlePiece? get puddles => _first<PuddlePiece>();
}

/// Uma regra do sorteio: meses e faixa de hora LOCAL (`[início, fim)`, pode virar a meia-noite) e os pesos dos nativos.
class SeasonRule {
  const SeasonRule({required this.months, this.hours, required this.weights});

  final Set<int> months;
  final (int, int)? hours;
  final Map<String, int> weights;

  bool matches(int month, int hour) {
    if (!months.contains(month)) return false;
    final h = hours;
    if (h == null) return true;
    return h.$1 <= h.$2 ? hour >= h.$1 && hour < h.$2 : hour >= h.$1 || hour < h.$2;
  }
}

/// Um clima forçado por evento (`events.json` assinado): vale nas janelas cujo meio cai em `[startsUtc, endsUtc)`.
class ClimateEvent {
  const ClimateEvent({required this.climate, required this.startsUtc, required this.endsUtc, this.id, this.reason});

  /// `null` se a entrada não é de clima ou está malformada: o app antigo e o novo ignoram o que não entendem.
  static ClimateEvent? tryParse(Map<String, dynamic> j) {
    try {
      if (j['kind'] != 'climate') return null;
      final s = DateTime.parse(j['starts_utc'] as String), e = DateTime.parse(j['ends_utc'] as String);
      if (!s.isUtc || !e.isUtc) return null;
      return ClimateEvent(
        climate: j['climate'] as String,
        startsUtc: s.millisecondsSinceEpoch ~/ 1000,
        endsUtc: e.millisecondsSinceEpoch ~/ 1000,
        id: j['event'] as String?,
        reason: j['reason'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  final String climate;
  final int startsUtc;
  final int endsUtc;

  /// O evento (`crimson_moon`, `listeners`...: o texto mora no `clima.json`) e a frase do motivo, se o feed mandar.
  final String? id;
  final String? reason;
}

/// De onde veio o clima de uma janela: o sorteio da estação, o feed assinado, o calendário da época, a astronomia ou o
/// debug. [event] é o id do evento (o nome e a frase do motivo estão no `clima.json`, `events`).
enum ClimateSource { season, feed, calendar, astro, debug }

class ClimateCause {
  const ClimateCause(this.climate, {this.source = ClimateSource.season, this.event, this.reason});

  final String climate;
  final ClimateSource source;
  final String? event;

  /// A frase do motivo que veio do feed (o calendário e a astronomia usam a do `clima.json`).
  final String? reason;
}

/// Época 7: um evento do calendário embarcado. Vale na janela cujo meio (hora local) cai no mês [month], entre os dias
/// [days] e nas horas [hours] (`[início, fim)`, pode virar a meia-noite), ou dentro de [utc]; com [chance] < 1, por um
/// sorteio da seed por janela, o mesmo para a cidade inteira.
class CalendarRule {
  const CalendarRule({required this.id, required this.climate, this.month, this.days, this.hours, this.utc, this.chance = 1});

  factory CalendarRule.fromJson(Map<String, dynamic> j) {
    final u = j['utc'] as List<dynamic>?;
    int iso(Object s) => DateTime.parse(s as String).millisecondsSinceEpoch ~/ 1000;
    return CalendarRule(
      id: j['id'] as String,
      climate: j['climate'] as String,
      month: (j['month'] as num?)?.toInt(),
      days: j['days'] == null ? null : _range(j['days'], (1, 31)),
      hours: j['hours'] == null ? null : _range(j['hours'], (0, 24)),
      utc: u == null ? null : (iso(u[0]), iso(u[1])),
      chance: _d(j['chance'], 1),
    );
  }

  final String id;
  final String climate;
  final int? month;
  final (int, int)? days;
  final (int, int)? hours;
  final (int, int)? utc;
  final double chance;

  bool matches(int midUtc, DateTime local) {
    final u = utc;
    if (u != null && (midUtc < u.$1 || midUtc >= u.$2)) return false;
    if (month != null && local.month != month) return false;
    final d = days;
    if (d != null && (local.day < d.$1 || local.day > d.$2)) return false;
    final h = hours;
    if (h != null && !(h.$1 <= h.$2 ? local.hour >= h.$1 && local.hour < h.$2 : local.hour >= h.$1 || local.hour < h.$2)) return false;
    return true;
  }
}

/// Época 7: um evento da astronomia. Hoje só a lua cheia muito perto da Terra (Lua Dupla): lua ao menos [fullMin] cheia e a
/// menos de [distanceMaxKm], nas horas locais [hours], com [chance] por janela.
class AstroRule {
  const AstroRule({required this.id, required this.climate, required this.fullMin, required this.distanceMaxKm, this.hours, this.chance = 1});

  factory AstroRule.fromJson(Map<String, dynamic> j) => AstroRule(
        id: j['id'] as String,
        climate: j['climate'] as String,
        fullMin: _d(j['full_min'], 0.985),
        distanceMaxKm: _d(j['distance_max_km'], 358000),
        hours: j['hours'] == null ? null : _range(j['hours'], (0, 24)),
        chance: _d(j['chance'], 1),
      );

  final String id;
  final String climate;
  final double fullMin;
  final double distanceMaxKm;
  final (int, int)? hours;
  final double chance;

  bool matches(int midUtc, DateTime local) {
    final h = hours;
    if (h != null && !(h.$1 <= h.$2 ? local.hour >= h.$1 && local.hour < h.$2 : local.hour >= h.$1 || local.hour < h.$2)) return false;
    return moonIllumination(midUtc) >= fullMin && moonDistanceKm(midUtc) <= distanceMaxKm;
  }
}

/// Um acontecimento de uma [DropPiece]: quando, onde (células z21 fracionárias) e os sorteios do que nasce ali.
class ClimateDrop {
  const ClimateDrop({required this.piece, required this.pieceIndex, required this.index, required this.tUtc, required this.x, required this.y, required this.spawnRoll, required this.itemRoll, required this.pick, required this.uid});

  final DropPiece piece;
  final int pieceIndex;
  final int index;
  final int tUtc;
  final double x, y;

  /// Sorteios em `[0, 1)`: nasce a criatura, nasce o item, e qual item / quantidade / nível.
  final double spawnRoll, itemRoll, pick;
  final int uid;
}

/// Uma zona de uma [ZonePiece]: centro no começo (células z21), direção, início e fim, e os pontos do que nasce dentro.
class ClimateZone {
  const ClimateZone({required this.piece, required this.pieceIndex, required this.index, required this.x0, required this.y0, required this.headingRad, required this.startUtc, required this.endUtc, required this.slots, required this.uidBase});

  final ZonePiece piece;
  final int pieceIndex;
  final int index;
  final double x0, y0;
  final double headingRad;
  final int startUtc, endUtc;

  /// Para cada vaga: deslocamento em fração do raio (dx, dy), o sorteio de nascer a criatura ([roll]), o de nascer o item
  /// ([roll2]) e o de escolha (espécie, item, quantidade, nível).
  final List<({double dx, double dy, double roll, double roll2, double pick})> slots;
  final int uidBase;

  bool activeAt(int t) => t >= startUtc && t < endUtc;

  /// O centro em [t] (células z21), andando [ZonePiece.speedMps] na direção da zona. [metersPerCell] é o da latitude.
  (double, double) centerAt(double t, double metersPerCell) {
    final s = piece.speedMps * (t - startUtc).clamp(0, endUtc - startUtc) / metersPerCell;
    return (x0 + math.sin(headingRad) * s, y0 - math.cos(headingRad) * s);
  }
}

class ClimateModel {
  ClimateModel({required this.windowS, required this.localOffsetH, required this.seasons, required this.after, required this.defs, this.calendar = const [], this.astro = const []}) {
    for (final r in seasons) {
      for (final id in r.weights.keys) {
        if (defs[id]?.category != ClimateCategory.native) throw FormatException('o sorteio só usa climas nativos: $id');
      }
    }
    for (final id in [...calendar.map((r) => r.climate), ...astro.map((r) => r.climate)]) {
      if (!defs.containsKey(id)) throw FormatException('evento com clima desconhecido: $id');
    }
  }

  factory ClimateModel.fromJson(Map<String, dynamic> j) => ClimateModel(
        windowS: (j['window_s'] as num).toInt(),
        localOffsetH: (j['local_offset_h'] as num).toInt(),
        seasons: [
          for (final r in j['seasons'] as List<dynamic>)
            SeasonRule(
              months: {for (final m in (r as Map<String, dynamic>)['months'] as List<dynamic>) (m as num).toInt()},
              hours: r['hours'] == null ? null : _range(r['hours'], (0, 24)),
              weights: {for (final e in (r['weights'] as Map<String, dynamic>).entries) e.key: (e.value as num).toInt()},
            ),
        ],
        after: {for (final e in ((j['after'] as Map<String, dynamic>?) ?? const {}).entries) e.key: (e.value as List<dynamic>).cast<String>().toSet()},
        defs: {for (final e in (j['climates'] as Map<String, dynamic>).entries) e.key: ClimateDef.fromJson(e.key, e.value as Map<String, dynamic>)},
        calendar: [for (final r in (j['calendar'] as List<dynamic>?) ?? const []) CalendarRule.fromJson(r as Map<String, dynamic>)],
        astro: [for (final r in (j['astro'] as List<dynamic>?) ?? const []) AstroRule.fromJson(r as Map<String, dynamic>)],
      );

  final int windowS;

  /// Horas somadas ao UTC para a hora e o mês locais (Brasília: -3, fixo em dado, sem o fuso do aparelho).
  final int localOffsetH;
  final List<SeasonRule> seasons;

  /// Climas que só podem sair logo depois de outros (o arco-íris depois da chuva).
  final Map<String, Set<String>> after;
  final Map<String, ClimateDef> defs;

  /// Época 7: os eventos do calendário embarcado e da astronomia, na ordem em que valem (o primeiro que bate ganha).
  final List<CalendarRule> calendar;
  final List<AstroRule> astro;

  int windowOf(int tUtc) => tUtc ~/ windowS;

  /// Mês e hora locais do meio da janela.
  (int, int) localMonthHour(int window) {
    final mid = window * windowS + windowS ~/ 2 + localOffsetH * 3600;
    final d = DateTime.fromMillisecondsSinceEpoch(mid * 1000, isUtc: true);
    return (d.month, d.hour);
  }

  /// O clima sorteado da janela [window] na região z12 `(rx, ry)`: só nativos, pela estação e hora local. Um clima com
  /// regra `after` (o arco-íris) só fica se a janela anterior foi um dos da lista; senão o mesmo sorteio cai entre os
  /// outros. A janela anterior só é olhada quando o sorteio dá um desses climas.
  String drawn(int seed, int window, int rx, int ry) => _draw(seed, window, rx, ry, 0);

  String _draw(int seed, int window, int rx, int ry, int depth) {
    final (month, hour) = localMonthHour(window);
    final rule = seasons.firstWhere((r) => r.matches(month, hour), orElse: () => const SeasonRule(months: {}, weights: {'clear': 1}));
    final u = Pcg32(fnv1a64([seed, window, rx, ry, saltClimate]), saltKenoma).nextFloat();
    String pick(List<MapEntry<String, int>> pool) {
      final total = pool.fold(0, (a, e) => a + e.value);
      if (total == 0) return 'clear';
      var target = u * total;
      for (final e in pool) {
        if (target < e.value) return e.key;
        target -= e.value;
      }
      return pool.last.key;
    }

    final full = [for (final e in rule.weights.entries) if (e.value > 0) e];
    final first = pick(full);
    final need = after[first];
    if (need == null) return first;
    // Teto de profundidade: só uma sequência de 8 sorteios seguidos desse clima chegaria nele.
    if (depth < 8 && need.contains(_draw(seed, window - 1, rx, ry, depth + 1))) return first;
    return pick([for (final e in full) if (!after.containsKey(e.key)) e]);
  }

  /// O clima da janela de [tUtc] na região: o de um evento ativo (o primeiro da lista), senão o sorteado.
  String at({required int seed, required int tUtc, required int rx, required int ry, List<ClimateEvent> events = const []}) =>
      resolve(seed: seed, tUtc: tUtc, rx: rx, ry: ry, events: events).climate;

  /// O clima da janela e de onde ele veio: o feed assinado, o calendário, a astronomia (as duas só da época 7 em diante) ou o
  /// sorteio da estação. O calendário e a astronomia sorteiam a chance com a seed e a janela, sem a região: a cidade inteira
  /// vê o mesmo evento.
  ClimateCause resolve({required int seed, required int tUtc, required int rx, required int ry, List<ClimateEvent> events = const []}) {
    final w = windowOf(tUtc);
    final mid = w * windowS + windowS ~/ 2;
    for (final e in events) {
      if (mid >= e.startsUtc && mid < e.endsUtc && defs.containsKey(e.climate)) return ClimateCause(e.climate, source: ClimateSource.feed, event: e.id, reason: e.reason);
    }
    if (calendar.isNotEmpty || astro.isNotEmpty) {
      final local = DateTime.fromMillisecondsSinceEpoch((mid + localOffsetH * 3600) * 1000, isUtc: true);
      bool roll(String id, double chance) => chance >= 1 || Pcg32(fnv1a64([seed, w, fnv1a64Bytes(id.codeUnits), saltCalendar]), saltKenoma).nextFloat() < chance;
      for (final r in calendar) {
        if (r.matches(mid, local) && roll(r.id, r.chance)) return ClimateCause(r.climate, source: ClimateSource.calendar, event: r.id);
      }
      for (final r in astro) {
        if (r.matches(mid, local) && roll(r.id, r.chance)) return ClimateCause(r.climate, source: ClimateSource.astro, event: r.id);
      }
    }
    return ClimateCause(drawn(seed, w, rx, ry));
  }

  ClimateDef? def(String id) => defs[id];

  /// A direção do vento (radianos a partir do norte, sentido horário) na região e janela.
  double windHeading(int seed, int epochId, int rx, int ry, int window) =>
      Pcg32(fnv1a64([seed, epochId, rx, ry, window, saltWind]), saltKenoma).nextFloat() * 2 * math.pi;

  /// Os acontecimentos da peça [pieceIndex] (uma [DropPiece]) na célula z17 `(cx, cy)` e na janela [window], em ordem de
  /// tempo. Cada um consome sempre os mesmos sorteios, nasça algo ou não.
  List<ClimateDrop> drops(int seed, int epochId, int cx, int cy, int window, int pieceIndex, DropPiece p) {
    final rng = Pcg32(fnv1a64([seed, epochId, cx, cy, window, pieceIndex, saltClimateFx]), saltKenoma);
    final out = <ClimateDrop>[];
    final end = (window + 1) * windowS;
    var t = window * windowS;
    final (lo, hi) = p.everyS;
    while (true) {
      t += lo + rng.nextInt(hi - lo + 1);
      if (t >= end) break;
      final px = rng.nextFloat(), py = rng.nextFloat();
      final i = out.length;
      out.add(ClimateDrop(
        piece: p,
        pieceIndex: pieceIndex,
        index: i,
        tUtc: t,
        x: (cx + px) * 16,
        y: (cy + py) * 16,
        spawnRoll: rng.nextFloat(),
        itemRoll: rng.nextFloat(),
        pick: rng.nextFloat(),
        uid: fnv1a64([seed, epochId, cx, cy, window, pieceIndex, i, saltClimateUid]),
      ));
    }
    return out;
  }

  /// As zonas da peça [pieceIndex] (uma [ZonePiece]) na célula z17 `(cx, cy)` e na janela [window].
  List<ClimateZone> zones(int seed, int epochId, int cx, int cy, int window, int pieceIndex, ZonePiece p) {
    final rng = Pcg32(fnv1a64([seed, epochId, cx, cy, window, pieceIndex, saltClimateFx]), saltKenoma);
    final slots = math.max(p.spawn?.perZone ?? 0, p.item?.perZone ?? 0);
    return [
      for (var k = 0; k < p.perCell; k++)
        () {
          final start = window * windowS + rng.nextInt(math.max(1, windowS - p.durationS));
          final px = rng.nextFloat(), py = rng.nextFloat(), heading = rng.nextFloat() * 2 * math.pi;
          return ClimateZone(
            piece: p,
            pieceIndex: pieceIndex,
            index: k,
            x0: (cx + px) * 16,
            y0: (cy + py) * 16,
            headingRad: heading,
            startUtc: start,
            endUtc: start + p.durationS,
            slots: [
              for (var j = 0; j < slots; j++)
                () {
                  final a = rng.nextFloat() * 2 * math.pi, r = math.sqrt(rng.nextFloat());
                  return (dx: math.cos(a) * r, dy: math.sin(a) * r, roll: rng.nextFloat(), roll2: rng.nextFloat(), pick: rng.nextFloat());
                }(),
            ],
            uidBase: fnv1a64([seed, epochId, cx, cy, window, pieceIndex, k, saltClimateUid]),
          );
        }(),
    ];
  }
}

/// Um ponto baixo de uma célula z17 (época 7): centro em células z21 e raio cheio em metros, antes de ir para a rua.
typedef PuddleSpot = ({int index, double x, double y, double radiusM});

/// Os pontos baixos da célula z17 `(cx, cy)`: fixos pela seed, pela época e pela célula (não pela janela), para a mesma poça
/// voltar em toda chuva.
List<PuddleSpot> puddleSpots(int seed, int epochId, int cx, int cy, PuddlePiece p) {
  final rng = Pcg32(fnv1a64([seed, epochId, cx, cy, saltPuddle]), saltKenoma);
  final (lo, hi) = p.radiusM;
  return [
    for (var k = 0; k < p.perCell; k++)
      (index: k, x: (cx + rng.nextFloat()) * 16, y: (cy + rng.nextFloat()) * 16, radiusM: lo + rng.nextFloat() * (hi - lo)),
  ];
}

/// Os sorteios da poça [k] na janela de chuva [wetWindow]: nasce o item, nasce o Eco, a escolha e o uid.
({double itemRoll, double spawnRoll, double pick, int uid}) puddleRolls(int seed, int epochId, int cx, int cy, int wetWindow, int k) {
  final rng = Pcg32(fnv1a64([seed, epochId, cx, cy, wetWindow, k, saltPuddleFx]), saltKenoma);
  return (itemRoll: rng.nextFloat(), spawnRoll: rng.nextFloat(), pick: rng.nextFloat(), uid: fnv1a64([seed, epochId, cx, cy, wetWindow, k, saltPuddle, saltClimateUid]));
}

/// A região do clima (tile z12) de uma célula z17.
(int, int) climateRegionOfCell17(int cx17, int cy17) => (cx17 >>> 5, cy17 >>> 5);
