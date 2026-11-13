import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/behavior.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/core/windows.dart';
import 'package:kenoma/data/traffic_pack.dart';
import 'package:kenoma/player/circle.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/player/personal_build.dart';
import 'package:kenoma/world/climate_world.dart';
import 'package:kenoma/world/personal_layer.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/world_view.dart';

import '../support/fixtures.dart';

int utc(int y, int m, int d, [int h = 0, int min = 0]) => DateTime.utc(y, m, d, h, min).millisecondsSinceEpoch ~/ 1000;

/// A camada pessoal de spawn (0.20.1): o mundo base igual para todos, e por cima o que o Círculo acrescenta só para o
/// jogador, estável por jogador, build, célula e janela.
void main() {
  final seed = seedGlobal('KENOMA-TESTE');
  final data = loadGameData();
  final schedule = loadEpochs();
  final map = RegionMap(pack: loadCampinasPack(), biomes: loadBiomes());
  const lat = -22.9056, lon = -47.0608; // Centro
  final (x21, y21) = latLonToTileFraction(lat, lon, 21);
  final (cx0, cy0) = (x21.floor() >>> 1, y21.floor() >>> 1);
  // Época 11. 03:00 UTC é meia-noite em Campinas; 15:00 UTC, meio-dia.
  final night = utc(2026, 12, 1, 3), day = utc(2026, 12, 1, 15);
  // Um poste (semáforo) e uma marquise (loja) no meio de cada célula z20 de um quadrado de 30 × 30 em volta do Centro.
  final cells = [for (var dy = -15; dy < 15; dy++) for (var dx = -15; dx < 15; dx++) (cx0 + dx, cy0 + dy)];
  final points = TrafficPack.of([
    for (final (cx, cy) in cells) ...[
      (kind: TrafficPointKind.signal, x: cx * 2 + 0.5, y: cy * 2 + 0.5),
      (kind: TrafficPointKind.shop, x: cx * 2 + 1.5, y: cy * 2 + 1.5),
    ],
  ]);

  ClimateWorld climate({String? forced}) => ClimateWorld(
        seed: seed,
        schedule: schedule,
        speciesOfType: data.ecoOfType,
        speciesOfTypeAt: data.ecoOfType,
        itemExists: data.itemNames.containsKey,
        itemSince: (id) => data.itemSinceEpoch[id],
        typeOf: (id) => data.species(id)?.type.name,
        forced: () => forced,
      );

  SpawnField fieldOf({String weather = 'clear', ClimateWorld? cw}) => SpawnField(
        seed: seed,
        schedule: schedule,
        map: map,
        typeOf: (id) => data.species(id)?.type.name,
        weatherAt: (cx, cy, t) => weather,
        climate: cw ?? climate(),
        levelCapOf: data.progress.levelCapFor,
      );

  PersonalLayer layerOf(Map<String, double> values, {String weather = 'clear', String player = 'jogador-a', TrafficPointSource? pts, bool Function()? hidden}) =>
      PersonalLayer(
        field: fieldOf(weather: weather),
        playerKey: playerKeyOf(player),
        builds: () => [BuildEntry(fromUtc: 0, values: values)],
        balance: data.personal,
        points: pts ?? points,
        hidden: hidden ?? () => false,
      );

  List<WorldSpawn> all(PersonalLayer l, int t, {int level = 10}) => [for (final (cx, cy) in cells) ...l.cell(cx, cy, t, level)];
  Set<int> uids(Iterable<WorldSpawn> s) => {for (final x in s) x.uid};
  List<int> bands(String id) => data.species(id)!.ability!.bands;

  test('os números ficam no balance.json, fora das épocas', () {
    final p = data.personal;
    expect(p.nightSunDeg, -6);
    expect(p.poleKinds, {TrafficPointKind.signal, TrafficPointKind.busStop});
    expect(p.marqueeKinds, {TrafficPointKind.shop, TrafficPointKind.bar});
    expect(p.fogClimates, contains('fog'));
    expect(p.fogBiomes, {'sacred'});
    expect(epochsJson().toString(), isNot(contains('personal_layer')));
  });

  group('a camada base não muda', () {
    test('os spawns do mundo são os mesmos com o Círculo vazio e com todas as habilidades no máximo, e a camada só acrescenta', () {
      for (final (t, weather) in [(night, 'clear'), (day, 'storm'), (night, 'fog'), (night, 'rain')]) {
        WorldView view(Map<String, double> values) {
          final cw = climate(forced: weather);
          final field = fieldOf(weather: weather, cw: cw);
          final s = GameState.fresh(groupCode: 'KENOMA-TESTE', startInventory: const {}, balance: data.progress);
          final layer = PersonalLayer(field: field, playerKey: playerKeyOf('jogador-a'), builds: () => s.builds, balance: data.personal, points: points);
          cw.personalPuddles = layer.puddlesAt;
          return WorldView(field: field, personal: layer, state: s, auraM: 0, viewM: 120, itemName: (i) => i, street: loadStreetBalance(), abilities: () => MapAbilities(values: values));
        }

        final empty = view(const {})..refresh(lat: lat, lon: lon, tUtc: t);
        final full = view(const {
          kRainPuddles: 4, kStormNightEco: 100, kNightEco: 100, kFogEco: 100, kHiddenChance: 20, kVariantChance: 20, kExtraMaterial: 20,
        })..refresh(lat: lat, lon: lon, tUtc: t);
        String key(WorldSpawn s) => '${s.uid}|${s.entryId}|${s.x}|${s.y}|${s.variant}|${s.shiny}|${s.behavior}|${s.level}';
        final base = {for (final s in empty.allEcos) key(s)};
        expect(empty.allEcos.where((s) => s.personal), isEmpty, reason: 'Círculo vazio: nada pessoal');
        expect({for (final s in full.allEcos) if (!s.personal) key(s)}, base, reason: '$weather: a base é idêntica');
        expect(full.allEcos.where((s) => s.personal), isNotEmpty, reason: '$weather: a camada pessoal acrescentou');
        expect(uids(full.allEcos.where((s) => s.personal)).intersection(uids(empty.allEcos)), isEmpty, reason: 'uids próprios');
      }
    });

    test('as poças do mundo são as mesmas com e sem o Rill; as do Rill são a mais', () {
      final t = night + 3000;
      final plain = climate(forced: 'rain');
      final withRill = climate(forced: 'rain');
      final layer = layerOf(const {kRainPuddles: 3});
      withRill.personalPuddles = layer.puddlesAt;
      final a = plain.puddlesNear(x21, y21, 60, t), b = withRill.puddlesNear(x21, y21, 60, t);
      String key(Puddle p) => '${p.x}|${p.y}|${p.radiusM}|${p.rolls.uid}';
      expect(a.every((p) => !p.personal), isTrue);
      expect([for (final p in b) if (!p.personal) key(p)], [for (final p in a) key(p)]);
      expect(b.where((p) => p.personal), isNotEmpty);
    });
  });

  group('estável por jogador, build, célula e janela', () {
    const shade = {kNightEco: 100.0};

    test('o mesmo jogador com a mesma build recebe o mesmo, mesmo reabrindo o app; outro jogador, outro', () {
      final a = all(layerOf(shade), night), again = all(layerOf(shade), night); // outra instância: o app reaberto
      String key(WorldSpawn s) => '${s.uid}|${s.entryId}|${s.x}|${s.y}|${s.variant}|${s.shiny}|${s.behavior}|${s.level}';
      expect(a, isNotEmpty);
      expect([for (final s in again) key(s)], [for (final s in a) key(s)]);
      final other = all(layerOf(shade, player: 'jogador-b'), night);
      expect(uids(other).intersection(uids(a)), isEmpty, reason: 'cada jogador tem os dele');
      expect([for (final s in other) s.entryId], isNot([for (final s in a) s.entryId]));
    });

    test('a janela seguinte sorteia de novo', () {
      final (cx, cy) = cells.first;
      final l = layerOf(shade);
      final now = l.cell(cx, cy, night, 10), next = l.cell(cx, cy, night + windowSeconds, 10);
      expect(now.single.window + 1, next.single.window);
      expect(now.single.uid, isNot(next.single.uid));
    });

    test('trocar o Círculo vale só a partir da janela seguinte da célula', () {
      final builds = <BuildEntry>[];
      final l = PersonalLayer(field: fieldOf(), playerKey: playerKeyOf('jogador-a'), builds: () => builds, balance: data.personal, points: points);
      final (cx, cy) = cells.first;
      final start = windowIndex(seed, cx, cy, night) * windowSeconds - windowOffset(seed, cx, cy);
      noteBuild(builds, const {}, start - 5000);
      expect(builds.single.fromUtc, 0, reason: 'a primeira build vale desde sempre');
      final mid = start + windowSeconds ~/ 2;
      expect(noteBuild(builds, shade, mid), isTrue);
      expect(l.cell(cx, cy, mid, 10), isEmpty, reason: 'trocou no meio da janela: ela continua com a build de antes');
      expect(l.cell(cx, cy, start + windowSeconds - 1, 10), isEmpty);
      expect(l.cell(cx, cy, start + windowSeconds, 10), hasLength(1), reason: 'a janela seguinte já usa a build nova');
      // Voltar à build vazia e de novo à do Shade não sorteia de novo: a mesma vaga dá o mesmo Eco.
      final first = l.cell(cx, cy, start + windowSeconds, 10).single;
      noteBuild(builds, const {}, start + windowSeconds + 10);
      noteBuild(builds, shade, start + windowSeconds + 20);
      expect(l.cell(cx, cy, start + 2 * windowSeconds, 10).single.entryId, isNotNull);
      expect(PersonalLayer(field: fieldOf(), playerKey: playerKeyOf('jogador-a'), builds: () => [BuildEntry(fromUtc: 0, values: shade)], balance: data.personal, points: points)
          .cell(cx, cy, start + windowSeconds, 10)
          .single
          .uid, first.uid);
    });

    test('a build vai para o save, e as velhas saem', () {
      final s = GameState.fresh(groupCode: 'KENOMA-TESTE', startInventory: const {}, balance: data.progress);
      noteBuild(s.builds, const {kNightEco: 10}, 1000);
      noteBuild(s.builds, const {kNightEco: 15}, 2000);
      expect(noteBuild(s.builds, const {kNightEco: 15}, 3000), isFalse, reason: 'a mesma build não entra de novo');
      final back = GameState.fromJson(s.toJson(3000), data.progress).builds;
      expect([for (final b in back) (b.fromUtc, b.of(kNightEco))], [(0, 10.0), (2000, 15.0)]);
      noteBuild(s.builds, const {kNightEco: 20}, 2000 + 2 * 86400);
      noteBuild(s.builds, const {kNightEco: 25}, 2000 + 3 * 86400);
      expect(s.builds.length, lessThanOrEqualTo(3));
      expect(buildAt(s.builds, 2000 + 2 * 86400 + 5)!.of(kNightEco), 20);
    });
  });

  group('cada habilidade nas três faixas', () {
    /// Os Ecos de cada faixa: cada faixa só acrescenta ao que a anterior dava, e a contagem cresce.
    void growing(String what, List<Set<int>> byBand) {
      for (var i = 1; i < byBand.length; i++) {
        expect(byBand[i].containsAll(byBand[i - 1]), isTrue, reason: '$what: a faixa ${i + 1} contém a $i');
        expect(byBand[i].length, greaterThan(byBand[i - 1].length), reason: '$what: a faixa ${i + 1} dá mais');
      }
    }

    test('Hum: Elétricos nos postes à noite e na tempestade, nada de dia com tempo limpo nem sem poste', () {
      final b = bands('hum.eco');
      final sets = [for (final v in b) uids(all(layerOf({kStormNightEco: v.toDouble()}), night))];
      growing('Hum', sets);
      expect(sets.last.length / cells.length, closeTo(b.last / 100, 0.05));
      final eco = all(layerOf({kStormNightEco: 100}), night);
      expect(eco.every((s) => data.species(s.entryId)!.type.name == 'electric'), isTrue);
      expect(eco.every((s) => (s.x - 0.5) % 2 == 0 && (s.y - 0.5) % 2 == 0), isTrue, reason: 'no poste');
      expect(all(layerOf({kStormNightEco: 100}, weather: 'storm'), day), isNotEmpty, reason: 'tempestade de dia');
      expect(all(layerOf({kStormNightEco: 100}), day), isEmpty, reason: 'dia limpo');
      expect(all(layerOf({kStormNightEco: 100}, pts: TrafficPack.of(const [])), night), isEmpty, reason: 'sem poste');
    });

    test('Shade: um Eco sob as marquises à noite, nada de dia nem sem marquise', () {
      final b = bands('shade.eco');
      final sets = [for (final v in b) uids(all(layerOf({kNightEco: v.toDouble()}), night))];
      growing('Shade', sets);
      expect(sets.last.length / cells.length, closeTo(b.last / 100, 0.05));
      final eco = all(layerOf({kNightEco: 100}), night);
      expect(eco.every((s) => (s.x - 1.5) % 2 == 0 && (s.y - 1.5) % 2 == 0), isTrue, reason: 'na marquise');
      expect({for (final s in eco) s.entryId}.length, greaterThan(2), reason: 'da tabela do bioma, não de um tipo só');
      expect(all(layerOf({kNightEco: 100}), day), isEmpty);
      expect(all(layerOf({kNightEco: 100}, pts: TrafficPack.of(const [])), night), isEmpty);
    });

    test('Wisp: Espectrais na neblina, nada com tempo limpo fora do Sagrado; os rastros do Radar duram mais', () {
      final b = bands('wisp.eco');
      final sets = [for (final v in b) uids(all(layerOf({kFogEco: v.toDouble()}, weather: 'fog'), day))];
      growing('Wisp', sets);
      final eco = all(layerOf({kFogEco: 100}, weather: 'fog'), day);
      expect(eco.every((s) => data.species(s.entryId)!.type.name == 'spectral'), isTrue);
      expect(all(layerOf({kFogEco: 100}), day), isEmpty, reason: 'sem neblina e sem Sagrado no pacote da época 0');
      expect(data.personal.wispTraceMult, greaterThan(1));
    });

    test('Sprig: mais variantes nos Ecos da camada pessoal, só acrescentando', () {
      final b = bands('sprig.eco');
      final base = all(layerOf({kNightEco: 100}), night);
      final sets = [
        for (final v in [0, ...b]) {for (final s in all(layerOf({kNightEco: 100, kVariantChance: v.toDouble()}), night)) if (s.variant != null) s.uid},
      ];
      growing('Sprig', sets);
      expect(sets.last.length / base.length, closeTo(data.schedule.epochs.last.ecoV2!.variantChance + b.last / 100, 0.06));
    });

    test('Bit: mais Ocultos nos Ecos da camada pessoal, e Essência a mais ao destilar um que era Oculto', () {
      final b = bands('bit.eco');
      final sets = [
        for (final v in [0, ...b]) {for (final s in all(layerOf({kNightEco: 100, kHiddenChance: v.toDouble()}), night)) if (s.behavior == EcoBehavior.hidden) s.uid},
      ];
      growing('Bit', sets);
      expect(data.personal.hiddenEssenceBonus, greaterThan(0));
    });

    test('Rill: na chuva, as poças a mais por célula z17 são as da faixa, e cada faixa contém a anterior', () {
      final t = night + 3000;
      final sets = <Set<String>>[];
      for (final v in bands('rill.eco')) {
        final cw = climate(forced: 'rain')..personalPuddles = layerOf({kRainPuddles: v.toDouble()}).puddlesAt;
        final mine = cw.puddlesNear(x21, y21, 1, t).where((p) => p.personal).toList();
        expect(mine.length, v, reason: 'faixa com $v');
        sets.add({for (final p in mine) '${p.x}|${p.y}'});
      }
      for (var i = 1; i < sets.length; i++) {
        expect(sets[i].containsAll(sets[i - 1]), isTrue);
      }
      final dry = climate()..personalPuddles = layerOf({kRainPuddles: 3}).puddlesAt;
      expect(dry.puddlesNear(x21, y21, 1, day).where((p) => p.personal), isEmpty, reason: 'sem chuva, nada');
    });

    test('Clod: material a mais na coleta, na chance da faixa, e cada faixa contém a anterior', () {
      final mats = [
        for (var i = 0; i < 3000; i++)
          WorldSpawn(uid: 7000 + i * 7919, kind: 'material', entryId: 'item.scrap', quantity: 1, x: 0, y: 0, cellX: cx0, cellY: cy0, window: 0),
      ];
      final b = bands('clod.eco');
      final sets = [
        for (final v in b) {for (final m in mats) if (layerOf({kExtraMaterial: v.toDouble()}).extraMaterial(m, night) > 0) m.uid},
      ];
      growing('Clod', sets);
      for (var i = 0; i < b.length; i++) {
        expect(sets[i].length / mats.length, closeTo(b[i] / 100, 0.02));
      }
      final spark = WorldSpawn(uid: 1, kind: 'spark', entryId: 'item.dust.fire', quantity: 1, x: 0, y: 0, cellX: 0, cellY: 0, window: 0);
      expect(layerOf({kExtraMaterial: 100}).extraMaterial(spark, night), 0, reason: 'só material');
    });

    test('toda habilidade de mapa das famílias tem efeito: nenhuma chave sem uso', () {
      const used = {'aura_bonus_m', 'spark_pickup_bonus_m', 'seal_save_pct', 'day_tolerance_pct', 'distill_bonus', kRainPuddles, kStormNightEco, kExtraMaterial, kNightEco, kFogEco, kHiddenChance, kVariantChance};
      for (final sp in data.tuning.species.where((s) => s.ability != null)) {
        expect(used, contains(sp.ability!.kind), reason: sp.id);
        expect(sp.ability!.bands, hasLength(3), reason: sp.id);
      }
    });
  });

  test('o interruptor do debug esconde a camada pessoal e o contador soma o que ela acrescentou', () {
    var hide = false;
    final l = layerOf(const {kNightEco: 100, kRainPuddles: 2}, hidden: () => hide);
    final shown = l.around(lat: lat, lon: lon, tUtc: night, radiusM: 120, playerLevel: 10);
    expect(shown, isNotEmpty);
    expect(l.addedEcos.length, shown.length);
    expect(l.stats, startsWith('${shown.length} Ecos'));
    hide = true;
    expect(l.around(lat: lat, lon: lon, tUtc: night, radiusM: 120, playerLevel: 10), isEmpty);
    expect(l.puddlesAt(1, 1, 1, night), isNull);
    hide = false;
    expect(l.puddlesAt(1, 1, 1, night)!.count, 2);
    expect(l.addedPuddles, 2);
  });
}
