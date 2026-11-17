import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/crafting/bag.dart';
import 'package:kenoma/crafting/collector_tick.dart';
import 'package:kenoma/crafting/collectors.dart';
import 'package:kenoma/crafting/conditions.dart';
import 'package:kenoma/crafting/crafting_data.dart';
import 'package:kenoma/crafting/crafting_state.dart';
import 'package:kenoma/crafting/grimoire.dart';
import 'package:kenoma/crafting/loadout.dart';
import 'package:kenoma/crafting/quality.dart';
import 'package:kenoma/data/game_data.dart';
import 'package:kenoma/player/game_state.dart';

import '../support/fixtures.dart';

/// O crafting da fase 1 com um livro pequeno escrito aqui: as regras não dependem do conteúdo de `items.json`.
void main() {
  final progress = loadProgressBalance();
  GameState state([Map<String, int> inv = const {}]) => GameState(groupCode: 'KENOMA-TESTE', balance: progress, inventory: inv);

  ItemDef item(String id, String kind, {Map<String, dynamic> extra = const {}}) => ItemDef.fromJson({'id': id, 'name': id, 'kind': kind, ...extra});
  final book = CraftingBook(
    items: {
      for (final i in [
        item('item.chalk', 'material'),
        item('item.herbs', 'material'),
        item('item.ectoplasm', 'material'),
        item('item.dust.shadow', 'essence_dust', extra: {'type': 'shadow'}),
        item('item.dust.fire', 'essence_dust', extra: {'type': 'fire'}),
        item('item.vessel.glass', 'vessel'),
        item('item.vessel.thermal', 'vessel', extra: {'keeps_cold': true}),
        item('item.rain_water', 'condition'),
        item('item.snow', 'condition', extra: {'perish_h': 72, 'melts_to': 'item.snow_water'}),
        item('item.snow_water', 'condition'),
        item('item.moonlight.full', 'condition', extra: {'perish_h': 48}),
        item('item.ref.chalk', 'refined'),
        item('item.ref.ink', 'refined'),
        item('item.bag.big', 'bag', extra: {'effects': {'bag_slots': 20}}),
        item('item.amulet.rain', 'amulet', extra: {'season': 'summer', 'in_season_mult': 1.5, 'effects': {'planted_slots': 2}}),
      ])
        i.id: i,
    },
    balance: CraftingBalance.fromJson({
      'crafting': {
        'bag': {'base_slots': 6, 'stack': 99, 'discard_per_dust': 5},
        'collectors': {
          'belt_slots': 3,
          'planted_slots': 3,
          'planted_gap_m': 100,
          'rules': [
            {'id': 'glass.drizzle', 'vessels': ['item.vessel.glass'], 'climates': ['drizzle'], 'out': 'item.rain_water', 'quality': 'common', 'carry_s': 300, 'planted_s': 1200},
            {'id': 'glass.rain', 'vessels': ['item.vessel.glass'], 'climates': ['rain'], 'out': 'item.rain_water', 'quality': 'good', 'carry_s': 300, 'planted_s': 1200},
            {'id': 'glass.storm', 'vessels': ['item.vessel.glass'], 'climates': ['storm'], 'out': 'item.rain_water', 'quality': 'perfect', 'carry_s': 300, 'planted_s': 1200},
            {'id': 'snow', 'vessels': ['item.vessel.glass', 'item.vessel.thermal'], 'climates': ['snow'], 'out': 'item.snow', 'quality': 'good', 'carry_s': 300, 'planted_s': 1200},
            {'id': 'dark.moon', 'vessels': ['item.vessel.dark'], 'night': true, 'out': 'item.moonlight.{moon}', 'carry_s': 600, 'planted_s': 21600},
          ],
        },
        'quality': {
          'raw': {
            'item.herbs': {'biomes': ['green'], 'moon': ['full']},
          },
        },
      },
    }['crafting'] as Map<String, dynamic>),
  );
  // 2026-11-17 15:00 UTC: dia em Campinas, lua no começo do mês sinódico.
  const t0 = 1795446000;
  Here here({int t = t0, String climate = 'clear', double lat = -22.9, double lon = -47.06, String? biome, double sun = 50}) =>
      Here(utc: t, lat: lat, lon: lon, sunAltDeg: sun, climate: climate, biome: biome);

  group('qualidade', () {
    test('o resultado herda o pior ingrediente', () {
      final s = state({'item.chalk@perfect': 2, 'item.ectoplasm@good': 1});
      final r = Recipe(id: 'r', outId: 'item.ref.ink', outQty: 1, inputs: const {'item.chalk': 1, 'item.ectoplasm': 1});
      final plan = planCraft(s, r, book)!;
      expect(plan.quality, Quality.good);
      expect(plan.limiting, ['item.ectoplasm']);
      expect(craftAt(s, r, book, here()), Quality.good);
      expect(s.countQ('item.ref.ink', Quality.good), 1);
      expect((s.countQ('item.chalk', Quality.perfect), s.count('item.ectoplasm')), (1, 0));
    });

    test('sem escolha gasta a pior pilha primeiro; a escolha pega a pilha pedida', () {
      final s = state({'item.chalk': 1, 'item.chalk@perfect': 1});
      final r = Recipe(id: 'r', outId: 'item.ref.chalk', outQty: 1, inputs: const {'item.chalk': 1});
      expect(planCraft(s, r, book)!.quality, Quality.common);
      expect(planCraft(s, r, book, pick: {'item.chalk': Quality.perfect})!.quality, Quality.perfect);
      expect(s.count('item.chalk'), 2, reason: 'o id puro soma as qualidades');
    });

    test('a qualidade do bruto vem do lugar real e da fase da lua certa, um nível cada', () {
      // a primeira lua cheia depois de t0
      final full = nextMoonGroup(MoonGroup.full, t0);
      final dark = nextMoonGroup(MoonGroup.newMoon, t0); // fora da lua cheia
      expect(rawQuality('item.herbs', here(t: dark), book.balance), Quality.common);
      expect(rawQuality('item.herbs', here(t: dark, biome: 'green'), book.balance), Quality.good);
      expect(rawQuality('item.herbs', here(t: full), book.balance), Quality.good);
      expect(rawQuality('item.herbs', here(t: full, biome: 'green'), book.balance), Quality.perfect);
      expect(rawQuality('item.chalk', here(biome: 'green'), book.balance), Quality.common, reason: 'sem tabela, comum');
    });

    test('a água da garrafa sai pela condição: garoa comum, chuva boa, tempestade perfeita', () {
      for (final (c, q) in [('drizzle', Quality.common), ('rain', Quality.good), ('storm', Quality.perfect)]) {
        final s = state({'item.vessel.glass': 1});
        expect(toBelt(s, 'item.vessel.glass', book, t0), isTrue);
        tickBelt(s, here(climate: c), 400, book);
        expect(s.crafting.at(VesselPlace.belt).single.quality, q, reason: c);
      }
    });
  });

  group('coletores', () {
    test('levado no cinto enche na chuva depois de alguns minutos; a condição que acaba zera a conta', () {
      final s = state({'item.vessel.glass': 1});
      expect(toBelt(s, 'item.vessel.glass', book, t0), isTrue);
      expect(s.count('item.vessel.glass'), 0);
      final v = s.crafting.at(VesselPlace.belt).single;
      expect(tickBelt(s, here(climate: 'rain'), 200, book), isEmpty);
      tickBelt(s, here(climate: 'clear'), 10, book);
      expect(v.progressS, 0, reason: 'a chuva parou: recomeça');
      tickBelt(s, here(climate: 'rain'), 200, book);
      expect(tickBelt(s, here(climate: 'rain', t: t0 + 200), 120, book), [v]);
      expect((v.content, v.quality, v.filledUtc), ('item.rain_water', Quality.good, t0 + 200));
    });

    test('plantado enche com a condição do lugar com o jogador longe, e só se colhe de perto', () {
      final s = state({'item.vessel.glass': 1});
      final v = plant(s, 'item.vessel.glass', here(), 1.2, 2.2, book)!;
      // A chuva cai no ponto do coletor das 15:30 às 16:00; o jogador está a quilômetros.
      Here at(int t) => here(t: t, climate: t >= t0 + 1800 && t < t0 + 3600 ? 'rain' : 'clear');
      expect(updatePlanted(v, t0 + 1800, at, book), PlantedState.waiting);
      expect(updatePlanted(v, t0 + 2400, at, book), PlantedState.filling);
      expect(updatePlanted(v, t0 + 7200, at, book), PlantedState.full);
      expect((v.content, v.quality, v.filledUtc), ('item.rain_water', Quality.good, t0 + 1800 + 1200));
      // Mesma conta feita de uma vez só: o resultado não depende de quando se olha.
      final s2 = state({'item.vessel.glass': 1});
      final v2 = plant(s2, 'item.vessel.glass', here(), 0, 2.2, book)!;
      expect(updatePlanted(v2, t0 + 7200, at, book), PlantedState.full);
      expect(v2.filledUtc, v.filledUtc);
      expect(harvest(s, v, 400, 30, book, t0 + 7200), isFalse, reason: 'longe: não colhe');
      expect(v.place, VesselPlace.planted);
      expect(harvest(s, v, 12, 30, book, t0 + 7200), isTrue);
      expect(v.place, VesselPlace.belt);
      expect(carriedWith(s, 'item.rain_water'), [v]);
    });

    test('dois plantados ficam a 100 m ou mais um do outro', () {
      final s = state({'item.vessel.glass': 3});
      expect(plant(s, 'item.vessel.glass', here(), 1, 2.2, book), isNotNull);
      final near = here(lat: -22.9 + 60 / 111320); // 60 m ao norte
      expect(plantBlocker(s, 'item.vessel.glass', near, 1, 2.2, book), contains('60 m'));
      final far = here(lat: -22.9 + 120 / 111320);
      expect(plantBlocker(s, 'item.vessel.glass', far, 1, 2.2, book), isNull);
    });

    test('plantar de carro é recusado: só a pé', () {
      final s = state({'item.vessel.glass': 1});
      expect(plantBlocker(s, 'item.vessel.glass', here(), 11, 2.2, book), contains('a pé'));
      expect(plant(s, 'item.vessel.glass', here(), 11, 2.2, book), isNull);
      expect(s.count('item.vessel.glass'), 1, reason: 'nada gasto');
    });

    test('o limite de plantados sobe com o equipamento (o amuleto na estação dele vale mais)', () {
      final s = state({'item.vessel.glass': 9, 'item.amulet.rain': 1});
      expect(plantedCapacity(s, book, t0), 3);
      expect(equip(s, book, LoadoutSlot.amulet, 'item.amulet.rain'), isTrue);
      expect(plantedCapacity(s, book, t0), 5, reason: 'novembro é primavera: +2');
      final summer = nextSeason(YearSeason.summer, t0) + 86400;
      expect(plantedCapacity(s, book, summer), 6, reason: 'no verão, +2 × 1,5');
      expect(plantedCapacity(s, book, nextSeason(YearSeason.winter, t0) + 86400), 5);
    });

    test('o perecível estraga plantado no mesmo ritmo da bolsa, e a garrafa fica', () {
      final s = state({'item.vessel.glass': 1});
      final v = plant(s, 'item.vessel.glass', here(), 0, 2.2, book)!;
      v
        ..content = 'item.moonlight.full'
        ..filledUtc = t0;
      Here clear(int t) => here(t: t);
      expect(updatePlanted(v, t0 + 47 * 3600, clear, book), PlantedState.full);
      expect(updatePlanted(v, t0 + 49 * 3600, clear, book), PlantedState.waiting);
      expect((v.content, s.crafting.vessels.contains(v)), (null, true));
      // Na bolsa, a mesma luz estraga na mesma hora.
      final b = Vessel(uid: 99, kind: 'item.vessel.glass', place: VesselPlace.bag, content: 'item.moonlight.full', filledUtc: t0);
      expect(settle(b, t0 + 47 * 3600, book), isFalse);
      expect(settle(b, t0 + 48 * 3600, book), isTrue);
      expect(b.empty, isTrue);
    });

    test('guardado na bolsa estraga no mesmo ritmo, pela mesma conta do mapa e da Patrulha', () {
      final s = state();
      s.crafting.vessels
        ..add(Vessel(uid: 1, kind: 'item.vessel.glass', place: VesselPlace.bag, content: 'item.moonlight.full', filledUtc: t0))
        ..add(Vessel(uid: 2, kind: 'item.vessel.glass', place: VesselPlace.bag, content: 'item.snow', filledUtc: t0));
      tickCollectors(s, book, hereAt: (lat, lon, t) => here(t: t), lat: -22.9, lon: -47.06, now: t0 + 80 * 3600, dtS: 10);
      expect(s.crafting.vessels.map((v) => v.content), ['item.snow_water'], reason: 'a luz estragou, a neve derreteu');
      expect(s.count('item.vessel.glass'), 1, reason: 'a garrafa da luz voltou a ser pilha vazia');
    });

    test('a neve derrete em água de neve em alguns dias, menos no frasco térmico', () {
      final glass = Vessel(uid: 1, kind: 'item.vessel.glass', place: VesselPlace.bag, content: 'item.snow', quality: Quality.good, filledUtc: t0);
      final thermal = Vessel(uid: 2, kind: 'item.vessel.thermal', place: VesselPlace.bag, content: 'item.snow', quality: Quality.good, filledUtc: t0);
      settle(glass, t0 + 71 * 3600, book);
      expect(glass.content, 'item.snow');
      settle(glass, t0 + 73 * 3600, book);
      settle(thermal, t0 + 400 * 3600, book);
      expect((glass.content, glass.quality, thermal.content), ('item.snow_water', Quality.good, 'item.snow'));
    });
  });

  group('descoberta', () {
    final refine = Recipe(
      id: 'recipe.refine.chalk',
      outId: 'item.ref.chalk',
      outQty: 1,
      inputs: const {'item.chalk': 1},
      discovery: Discovery.experiment,
      needs: const Needs(night: true),
      hint: 'algo da noite',
    );
    final ink = Recipe(id: 'recipe.refine.ink', outId: 'item.ref.ink', outQty: 1, inputs: const {'item.chalk': 1, 'item.ectoplasm': 1}, discovery: Discovery.experiment, hint: 'falta algo que assombra');

    test('experimentar nunca gasta material: erra, recebe pista, acerta e aprende', () {
      final s = state({'item.chalk': 2, 'item.ectoplasm': 1, 'item.herbs': 1});
      final before = {...s.inventory};
      expect(experiment(s, ['item.herbs'], [refine, ink], book, here()).text, contains('Nada'));
      expect(experiment(s, ['item.chalk'], [refine, ink], book, here()).text, contains('noite'), reason: 'de dia o giz não consagra');
      expect(isKnown(s, refine), isFalse);
      final night = here(sun: -20);
      expect(experiment(s, ['item.chalk'], [refine, ink], book, night).learned, refine);
      expect(isKnown(s, refine), isTrue);
      expect(s.inventory, before, reason: 'nada se gastou em nenhuma tentativa');
    });

    test('a silhueta aparece quando o jogador tem um dos ingredientes', () {
      final s = state({'item.ectoplasm': 1});
      expect(silhouettes(s, [refine, ink]), [ink]);
      expect(silhouettes(state(), [refine, ink]), isEmpty);
    });
  });

  group('bolsa', () {
    test('descartar rende 1 Pó a cada 5', () {
      final s = state({'item.chalk': 12, 'item.dust.shadow': 1, 'item.dust.fire': 3});
      expect(discard(s, book, 'item.chalk', 11), (dust: 'item.dust.shadow', qty: 2), reason: 'sem tipo: o Pó de que tem menos');
      expect((s.count('item.chalk'), s.count('item.dust.shadow')), (1, 3));
      expect(discard(s, book, 'item.chalk', 4), isNull, reason: 'não tem tanto');
    });

    test('a bolsa cheia recusa item; uma bolsa maior abre espaço', () {
      final s = state({'item.chalk': 99, 'item.herbs': 1, 'item.ectoplasm': 1, 'item.dust.fire': 1, 'item.dust.shadow': 1, 'item.bag.big': 1});
      expect(slotsUsed(s, book), 6);
      expect(fits(s, book, t0, 'item.herbs', 1), isTrue, reason: 'mesma pilha, sem espaço novo');
      expect(fits(s, book, t0, 'item.chalk', 1), isFalse, reason: 'a pilha de 99 abriria outro espaço');
      expect(fits(s, book, t0, 'item.ref.ink', 1), isFalse);
      final r = Recipe(id: 'r', outId: 'item.ref.ink', outQty: 1, inputs: const {'item.herbs': 1, 'item.ectoplasm': 1});
      final keep = state({'item.chalk': 99, 'item.herbs': 2, 'item.ectoplasm': 2, 'item.dust.fire': 1, 'item.dust.shadow': 1, 'item.ref.chalk': 1});
      expect(craftBlocker(keep, r, book, here()), 'Bolsa cheia');
      expect(craftAt(keep, r, book, here()), isNull);
      expect(keep.count('item.herbs'), 2, reason: 'nada gasto');
      expect(equip(s, book, LoadoutSlot.bag, 'item.bag.big'), isTrue);
      expect(bagCapacity(s, book, t0), 26);
      expect(fits(s, book, t0, 'item.ref.ink', 1), isTrue);
    });
  });

  test('o loadout mostra e esconde a bolsa, as garrafas e o brilho do amuleto no sprite', () {
    final s = state({'item.bag.big': 1, 'item.amulet.rain': 1, 'item.vessel.glass': 2});
    expect(avatarGear(s), (bag: false, bottles: 0, amuletGlow: false));
    equip(s, book, LoadoutSlot.bag, 'item.bag.big');
    equip(s, book, LoadoutSlot.amulet, 'item.amulet.rain');
    toBelt(s, 'item.vessel.glass', book, t0);
    toBelt(s, 'item.vessel.glass', book, t0);
    expect(avatarGear(s), (bag: true, bottles: 2, amuletGlow: true));
    s.crafting.hidden.addAll({LoadoutSlot.bag, LoadoutSlot.belt});
    expect(avatarGear(s), (bag: false, bottles: 0, amuletGlow: true));
    // A aparência troca a cara, o efeito continua o do equipado.
    s.crafting.looks[LoadoutSlot.amulet] = 'item.bag.big';
    expect(lookOf(s, LoadoutSlot.amulet), 'item.bag.big');
    expect(plantedCapacity(s, book, t0), 5);
    unequip(s, LoadoutSlot.bag);
    expect((s.count('item.bag.big'), bagCapacity(s, book, t0)), (1, 6));
  });

  test('o bloco crafting vai e volta pelo save', () {
    final s = state({'item.vessel.glass': 2});
    toBelt(s, 'item.vessel.glass', book, t0);
    plant(s, 'item.vessel.glass', here(), 0, 2.2, book);
    s.crafting
      ..known.add('recipe.refine.chalk')
      ..pages.add('page.moon')
      ..pins.add('item.chalk')
      ..hidden.add(LoadoutSlot.belt);
    final back = CraftingState.fromJson(s.crafting.toJson());
    expect(back.toJson(), s.crafting.toJson());
    expect(back.at(VesselPlace.planted).single.lat, -22.9);
  });
}
