/// Os spawns ao redor do jogador: Ecos, Fagulhas e pontos de material, derivados de
/// `hash(seed, época, célula, janela)` (docs/fase0-spec.md, seção 3). Dart puro.
///
/// Dois aparelhos com a mesma seed, a mesma época e o mesmo relógio veem os mesmos spawns. O que é
/// individual (o nível do Eco, o que já foi coletado) fica fora daqui ou entra por parâmetro.
library;

import 'dart:math' as math;

import '../core/astro.dart';
import '../core/behavior.dart';
import '../core/epochs.dart';
import '../core/spawn.dart';
import '../core/spawn_conditions.dart';
import '../core/tiles.dart';
import '../core/walkable.dart';
import '../core/weather.dart';
import '../core/windows.dart';
import '../data/relief_pack.dart';
import 'climate_world.dart';
import 'region_map.dart';

/// Um item de spawn no mundo, já com posição e nível.
class WorldSpawn {
  const WorldSpawn({
    required this.uid,
    required this.kind,
    required this.entryId,
    required this.quantity,
    required this.x,
    required this.y,
    required this.cellX,
    required this.cellY,
    required this.window,
    this.level,
    this.behavior = EcoBehavior.passive,
    this.variant,
    this.shiny = false,
    this.tag,
    this.personal = false,
  });

  final int uid;

  /// `eco`, `spark` ou `material`.
  final String kind;

  /// Espécie, item de Pó de Essência ou material.
  final String entryId;
  final int quantity;

  /// Posição em células z21 fracionárias.
  final double x;
  final double y;

  /// Célula z20 e janela de onde veio.
  final int cellX;
  final int cellY;
  final int window;

  /// Nível do Eco para o Conjurador de quando ele apareceu. `null` nos outros.
  final int? level;

  /// Só nos Ecos de épocas com o fluxo v2: o comportamento, a chave do bioma da variante e se é Brilhante.
  final EcoBehavior behavior;
  final String? variant;
  final bool shiny;

  /// Marca de quem nasceu de uma peça do clima (`charged`: o Eco do raio). Só no mapa: não vai para o save.
  final String? tag;

  /// Veio da camada pessoal de spawn (`personal_layer.dart`): só este jogador vê. No mapa é igual aos outros.
  final bool personal;

  /// Cópia em outra posição (a Fagulha que deriva com o vento).
  WorldSpawn movedTo(double x, double y) => WorldSpawn(
        uid: uid, kind: kind, entryId: entryId, quantity: quantity, x: x, y: y, cellX: cellX, cellY: cellY, window: window,
        level: level, behavior: behavior, variant: variant, shiny: shiny, tag: tag, personal: personal,
      );

  /// Cópia com a espécie e o nível trocados (o debug força um Espírito no lugar do Eco).
  WorldSpawn withSpecies(String entryId, int level) => WorldSpawn(
        uid: uid,
        kind: kind,
        entryId: entryId,
        quantity: quantity,
        x: x,
        y: y,
        cellX: cellX,
        cellY: cellY,
        window: window,
        level: level,
        behavior: behavior,
        variant: variant,
        shiny: shiny,
        tag: tag,
        personal: personal,
      );

  /// Cópia com o comportamento, a variante e o Brilhante trocados (o debug força o próximo spawn).
  WorldSpawn withTraits({required EcoBehavior behavior, String? variant, required bool shiny, String? entryId}) => WorldSpawn(
        uid: uid,
        kind: kind,
        entryId: entryId ?? this.entryId,
        quantity: quantity,
        x: x,
        y: y,
        cellX: cellX,
        cellY: cellY,
        window: window,
        level: level,
        behavior: behavior,
        variant: variant,
        shiny: shiny,
        tag: tag,
        personal: personal,
      );

  /// Se é um Eco raro: variante, Brilhante ou Oculto (ou, com [playerLevel], de nível acima do jogador). Só os raros
  /// deixam rastros.
  bool isRare(int playerLevel) => isEco && (variant != null || shiny || behavior == EcoBehavior.hidden || (level ?? 0) > playerLevel);

  bool get isEco => kind == 'eco';
  bool get isSpark => kind == 'spark';
  bool get isMaterial => kind == 'material';

  /// Distância em metros até um ponto, em células z21 fracionárias.
  double distanceM(double px, double py, double metersPerCell21) =>
      math.sqrt((x - px) * (x - px) + (y - py) * (y - py)) * metersPerCell21;
}

class SpawnField {
  SpawnField({required this.seed, required this.schedule, required this.map, this.maxCached = 4000, this.weatherAt, this.typeOf, this.snapper, this.levelCapOf, this.climate, this.relief});

  final int seed;
  final EpochSchedule schedule;
  final RegionMap map;
  final int maxCached;

  /// O id do clima de uma célula z20 no instante, para os pesos de spawn das épocas com o fluxo v2. `null`: sempre limpo.
  final String Function(int cellX, int cellY, int tUtc)? weatherAt;

  /// As peças do clima completo (época 6 em diante): o que nasce do raio, das poças..., a deriva das Fagulhas e o nível a
  /// mais. `null`: só o sorteio normal.
  final ClimateWorld? climate;

  /// O tipo (`fire`, `plant`, `water`) de uma espécie, para o clima mexer nos pesos.
  final String? Function(String entryId)? typeOf;

  /// Leva as posições para o que dá para andar (épocas com `walkable`). `null`: posições cruas do sorteio.
  final PathSnapper? snapper;

  /// O teto de nível de uma espécie (o Eco vai a 20, o Espírito a 30). `null`: 20 para todas.
  final int Function(String entryId)? levelCapOf;

  /// O relevo, para as famílias que preferem morro ou vale (época 11 em diante). `null` ou fora da grade: plano.
  final ReliefSource? relief;

  /// O lugar e o instante da célula z20 para as condições das famílias: o sol e a lua do começo da janela, o relevo do
  /// centro dela e o clima. `null` nas épocas sem `eco_v2.conditions`.
  SpawnContext? contextOf(Epoch epoch, int cx, int cy, int windowStart, String weather) {
    final cond = epoch.ecoV2?.conditions;
    if (cond == null) return null;
    final (lat, lon) = tileFractionToLatLon(cx * 2 + 1.0, cy * 2 + 1.0, biomeZoom);
    var rise = 0.0;
    final r = relief, x = cx * 2, y = cy * 2, k = cond.ringCells, kd = (k * 0.7071).round();
    final h = r?.h16At(x, y);
    if (r != null && h != null) {
      int? ring = 0;
      for (final (dx, dy) in [(k, 0), (-k, 0), (0, k), (0, -k), (kd, kd), (-kd, kd), (kd, -kd), (-kd, -kd)]) {
        final v = r.h16At(x + dx, y + dy);
        ring = v == null || ring == null ? null : ring + v;
      }
      if (ring != null) rise = cond.rise(h, ring);
    }
    return SpawnContext(sunAltDeg: sunAltitudeDeg(lat, lon, windowStart), moonIllum: moonIllumination(windowStart), rise: rise, climate: weather);
  }

  final _cells = <(int, String, int, int, int), List<SpawnItem>>{};
  int _revision = 0;
  final _levels = <int, int>{};

  /// Nível do Eco: `limitar(nível do Conjurador + delta, 1, teto da camada)`, calculado na primeira vez que ele
  /// entra no raio de visão e guardado pelo uid.
  int _levelOf(SpawnItem item, int playerLevel, [int add = 0]) =>
      _levels.putIfAbsent(item.uid, () => (playerLevel + (item.levelDelta ?? 0) + add).clamp(1, levelCapOf?.call(item.entryId) ?? 20));

  /// Os itens da célula z20 `(cx, cy)` no instante [tUtc]. Todos, existam ou não.
  List<SpawnItem> cellItems(int cx, int cy, int tUtc) {
    if (map.pack.revision != _revision) {
      _revision = map.pack.revision; // chegou bloco ou região: a célula é refeita sem reiniciar o app
      _cells.clear();
    }
    final epoch = schedule.select(tUtc).epoch;
    final window = windowIndex(seed, cx, cy, tUtc);
    // O clima só entra nas épocas que o trazem; nas outras a célula não depende dele. É o do COMEÇO da janela de 20 min da
    // célula, não o do instante: assim a espécie de um Eco não muda enquanto o jogador anda até ele, ainda que a janela de 3 h
    // do clima vire no meio.
    final windowStart = window * windowSeconds - windowOffset(seed, cx, cy);
    final weather = epoch.ecoV2 == null || weatherAt == null ? 'clear' : weatherAt!(cx, cy, windowStart);
    final key = (epoch.id, weather, cx, cy, window);
    final cached = _cells[key];
    if (cached != null) return cached;
    if (_cells.length >= maxCached) _cells.clear();
    final biome = map.biomes.spawnKey(map.spawnBiomeAtCell(cx, cy));
    // Até a época 5: o clima de quatro estados. Da 6 em diante: os multiplicadores e o Brilhante do clima completo.
    final model = epoch.climate;
    final def = model?.def(weather);
    return _cells[key] = generateCell(
      seed: seed,
      epoch: epoch,
      cellX: cx,
      cellY: cy,
      window: window,
      biomeKey: biome,
      weather: model == null ? Weather.parse(weather) : Weather.clear,
      climateMult: def == null || def.spawn.isEmpty ? null : def.spawn,
      shinyMult: def?.modifier?.shinyMult ?? 1,
      variantMult: def?.modifier?.variantMult ?? 1,
      typeOf: typeOf,
      snapper: snapper,
      context: contextOf(epoch, cx, cy, windowStart, weather),
    );
  }

  /// Segundos até a janela da célula acabar.
  int secondsLeft(int cx, int cy, int tUtc) => windowSeconds - (tUtc + windowOffset(seed, cx, cy)) % windowSeconds;

  /// Os spawns existentes a até [radiusM] metros de ([lat], [lon]) em [tUtc].
  List<WorldSpawn> around({
    required double lat,
    required double lon,
    required int tUtc,
    required double radiusM,
    required int playerLevel,
  }) {
    final (px, py) = latLonToTileFraction(lat, lon, biomeZoom);
    final mpc = metersPerCell(lat);
    final r = radiusM / mpc; // em células z21
    final out = <WorldSpawn>[];
    final cond = schedule.select(tUtc).epoch.ecoV2?.conditions;
    for (var cy = ((py - r) / 2).floor(); cy <= ((py + r) / 2).floor(); cy++) {
      for (var cx = ((px - r) / 2).floor(); cx <= ((px + r) / 2).floor(); cx++) {
        final window = windowIndex(seed, cx, cy, tUtc);
        final levelAdd = climate?.levelAddAt(cx, cy, tUtc) ?? 0;
        final windowStart = window * windowSeconds - windowOffset(seed, cx, cy);
        for (final item in cellItems(cx, cy, tUtc)) {
          if (!item.exists) continue;
          // Família com nível mínimo (o Wyrm): abaixo dele o Conjurador não a encontra.
          if (item.kind == 'eco' && !(cond?.visibleTo(item.entryId, playerLevel) ?? true)) continue;
          var spawn = WorldSpawn(
            uid: item.uid,
            kind: item.kind,
            entryId: item.entryId,
            quantity: item.quantity,
            x: (cx + item.px) * 2,
            y: (cy + item.py) * 2,
            cellX: cx,
            cellY: cy,
            window: window,
            level: item.kind == 'eco' ? _levelOf(item, playerLevel, levelAdd) : null,
            behavior: item.behavior,
            variant: item.variantBiome,
            shiny: item.shiny,
          );
          // O movimento próprio (época 9 em diante) antes do vento do clima: a deriva soma por cima da corrente.
          if (climate != null) spawn = climate!.move(spawn, windowStart, tUtc, mpc);
          if (climate != null && spawn.isSpark) {
            final moved = climate!.adjustSpark(spawn, windowStart, tUtc, mpc);
            if (moved == null) continue; // evaporou (Onda de calor) ou subiu ao céu (Céu Invertido)
            spawn = moved;
          }
          if (spawn.distanceM(px, py, mpc) <= radiusM) out.add(spawn);
        }
      }
    }
    final c = climate;
    if (c != null) {
      // Os Ecos do clima (o da poça, o do raio) também se movem; as Fagulhas do clima já têm o movimento delas.
      out.addAll([
        for (final s in c.extras(
          x21: px,
          y21: py,
          radiusM: radiusM,
          t: tUtc,
          metersPerCell21: mpc,
          levelOf: (id, add, uid) => _levels.putIfAbsent(uid, () => (playerLevel + add + c.levelAddAt(px.floor() >>> 1, py.floor() >>> 1, tUtc)).clamp(1, levelCapOf?.call(id) ?? 20)),
        ))
          if (!s.isEco || (cond?.visibleTo(s.entryId, playerLevel) ?? true)) s.isEco ? c.move(s, tUtc, tUtc, mpc) : s,
      ]);
    }
    return out;
  }
}
