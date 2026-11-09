import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/behavior.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/crafting/fusion.dart';
import 'package:kenoma/dev/debug_items_creature.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/world/debug_creatures.dart';
import 'package:kenoma/world/debug_force.dart';

import '../support/fixtures.dart';
import 'street_life_test.dart' show lat0, lon0, newState, schedule, t0, viewOf;

void main() {
  final data = loadGameData();
  final (px, py) = latLonToTileFraction(lat0, lon0, biomeZoom);
  final mpc = metersPerCell(lat0);
  double dist(s) => math.sqrt((s.x - px) * (s.x - px) + (s.y - py) * (s.y - py)) * mpc;

  group('o formulário vira criaturas', () {
    test('nascem dentro da Aura, cada uma num ponto, com uid da faixa de debug, e somem em 20 minutos', () {
      final c = DebugCreatures()..request(const DebugCreatureSpec(speciesId: 'rill.eco', level: 33, shiny: true, behavior: EcoBehavior.skittish, variant: DebugVariant.crimson, count: 10), ['rill.eco']);
      expect(c.pending, 10);
      final live = c.around(px: px, py: py, metersPerCell21: mpc, radiusM: 12, tUtc: t0);
      expect(live.length, 10);
      expect(c.pending, 0);
      expect(live.map((s) => s.uid).toSet().length, 10);
      expect(live.map((s) => (s.x, s.y)).toSet().length, 10, reason: 'cada uma num ponto diferente');
      for (final s in live) {
        expect(isDebugUid(s.uid), isTrue);
        expect(dist(s), lessThanOrEqualTo(12));
        expect((s.entryId, s.level, s.shiny, s.behavior, s.variant, s.isEco), ('rill.eco', 33, true, EcoBehavior.skittish, 'crimson', true));
      }
      expect(c.around(px: px, py: py, metersPerCell21: mpc, radiusM: 12, tUtc: t0 + kDebugCreatureS - 1).length, 10);
      expect(c.around(px: px, py: py, metersPerCell21: mpc, radiusM: 12, tUtc: t0 + kDebugCreatureS), isEmpty);
    });

    test('só o tipo sorteia entre as espécies dele; a camada Espírito troca o sufixo; variante de bioma vem do ponto', () {
      final species = data.tuning.species;
      expect(debugCandidates(const DebugCreatureSpec(type: 'plant'), species), ['frond.eco']);
      expect(debugCandidates(const DebugCreatureSpec(speciesId: 'soot.eco', type: 'water'), species), ['soot.eco']);
      final c = DebugCreatures()..request(const DebugCreatureSpec(type: 'fire', spirit: true, variant: DebugVariant.biome), debugCandidates(const DebugCreatureSpec(type: 'fire'), species));
      final s = c.around(px: px, py: py, metersPerCell21: mpc, radiusM: 10, tUtc: t0, biomeAt: (x, y) => 'green').single;
      expect((s.entryId, s.variant), ('soot.spirit', 'green'));
    });

    test('o formulário volta igual do JSON das preferências', () {
      const spec = DebugCreatureSpec(type: 'water', spirit: true, level: 40, shiny: true, variant: DebugVariant.biome, behavior: EcoBehavior.hidden, count: 7);
      expect(DebugCreatureSpec.fromJson(spec.toJson()).toJson(), spec.toJson());
    });

    test('os uids do mundo não caem na faixa de debug', () {
      final v = viewOf(newState(), schedule({'passive': 1}));
      final world = v.field.around(lat: lat0, lon: lon0, tUtc: t0, radiusM: 500, playerLevel: 1);
      expect(world, isNotEmpty);
      expect(world.where((s) => isDebugUid(s.uid)), isEmpty);
    });
  });

  group('não conta para o progresso', () {
    test('aparece no mapa sem entrar no bestiário; capturada vai para a coleção marcada, sem XP, bestiário nem estatística', () {
      final s = newState();
      final force = DebugForce();
      final v = viewOf(s, schedule({'passive': 1}), force: force);
      force.creatures.request(const DebugCreatureSpec(speciesId: 'soot.eco', spirit: true, level: 4, shiny: true), ['soot.eco']); // Espírito: no nível 1 o mundo não mostra nenhum
      v.refresh(lat: lat0, lon: lon0, tUtc: t0);
      final eco = v.spawns.firstWhere((x) => isDebugUid(x.uid));
      expect(eco.entryId, 'soot.spirit');
      expect(s.bestiary.keys.where((k) => k.startsWith('soot.spirit')), isEmpty, reason: 'markSeen não roda para a de debug');
      final (xp, events) = (s.progress.xp, {...s.story.events});
      s.capture(uid: eco.uid, speciesId: eco.entryId, level: eco.level!, nowUtc: t0, shiny: eco.shiny, debug: true);
      expect(s.collection.single.debug, isTrue);
      expect(CreatureInstance.fromJson(s.collection.single.toJson()).debug, isTrue, reason: 'marcada no save');
      expect(s.bestiary.keys.where((k) => k.startsWith('soot.spirit')), isEmpty);
      expect(s.progress.xp, xp);
      expect(s.story.events, events);
      v.refresh(lat: lat0, lon: lon0, tUtc: t0 + 1);
      expect(v.spawns.where((x) => x.uid == eco.uid), isEmpty, reason: 'capturada sai do mapa');
    });

    test('uma fusão com Eco de debug faz um Espírito de debug, sem contar fusão nem bestiário', () {
      final s = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress, inventory: {'item.essence.fire': 5})..levelOverride = 6;
      for (var i = 0; i < 5; i++) {
        s.collection.add(CreatureInstance(uid: 'e$i', speciesId: 'soot.eco', level: 5, capturedUtc: t0, debug: i == 0));
      }
      final spirit = fuse(s, data, 'soot', ['e0', 'e1', 'e2', 'e3', 'e4'], nowUtc: t0)!;
      expect(spirit.debug, isTrue);
      expect((s.conjurer.fusions, s.story.count('fusion'), s.hasCaptured('soot.spirit')), (0, 0, false));
    });
  });
}
