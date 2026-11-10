import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/climate.dart';
import 'package:kenoma/core/fnv.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/climate_catalog.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/world/climate_form.dart';
import 'package:kenoma/world/climate_sim.dart';
import 'package:kenoma/world/climate_world.dart';
import 'package:kenoma/world/debug_force.dart';
import 'package:kenoma/world/procession.dart';
import 'package:kenoma/world/traffic_graph.dart';
import 'package:kenoma/world/visual_map.dart';
import 'package:kenoma/world/walk_paths.dart';

import '../support/fake_position_source.dart';
import '../support/fixtures.dart';

int utc(int y, int m, int d, [int h = 0]) => DateTime.utc(y, m, d, h).millisecondsSinceEpoch ~/ 1000;

void main() {
  final seed = seedGlobal('KENOMA-TESTE');
  final data = loadGameData();
  final catalog = ClimateCatalog.fromJson(loadJson('assets/data/clima.json'));
  final (cx20, cy20) = latLonToTile(-22.8174, -47.0697, 20); // Unicamp
  final x21 = cx20 * 2.0 + 1, y21 = cy20 * 2.0 + 1;
  final mpc = metersPerCell(-22.8174);
  final visual = VisualMap(VisualPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync())), cacheTiles: 64);

  ClimateWorld device({String? Function()? forced, ForcedPhase Function()? phase}) => ClimateWorld(
        seed: seed,
        schedule: loadEpochs(),
        speciesOfType: data.ecoOfType,
        itemExists: data.itemNames.containsKey,
        snapper: WalkPaths(visual),
        forced: forced,
        forcedPhase: phase,
      );

  group('as marcas se formam com o tempo', () {
    test('sobe em grow_s, fica, e depois do fim desce a partir do que formou', () {
      expect(formAmount(sinceStartS: 0, growS: 1800, fadeS: 3600), 0);
      expect(formAmount(sinceStartS: 900, growS: 1800, fadeS: 3600), 0.5);
      expect(formAmount(sinceStartS: 9000, growS: 1800, fadeS: 3600), 1);
      // Choveu 15 min (meia poça) e parou há 15 min: resta um quarto.
      expect(formAmount(sinceStartS: 1800, sinceEndS: 900, growS: 1800, fadeS: 3600), closeTo(0.25, 1e-9));
      expect(formAmount(sinceStartS: 9000, sinceEndS: 3600, growS: 1800, fadeS: 3600), 0, reason: 'secou em 1 h');
    });

    test('a neve: pó, grama, chão e telhados, e só depois as ruas, das pouco usadas às avenidas; derrete ao contrário', () {
      final early = snowStages(0.15), mid = snowStages(0.5), late = snowStages(0.95);
      expect(early.dust, greaterThan(0));
      expect((early.ground, early.street(0)), (0, 0));
      expect(mid.green, greaterThan(mid.ground));
      expect(mid.street(0), greaterThan(mid.street(3)));
      expect(late.street(3), greaterThan(0));
      // Derretendo: o que precisou de mais neve (a avenida) some antes do chão.
      final melt = snowStages(formAmount(sinceStartS: 3600 + 2000, sinceEndS: 2000, growS: 3600, fadeS: 3600));
      expect(melt.street(3), 0);
      expect(melt.ground, greaterThan(0));
    });

    test('dois aparelhos com a mesma seed veem a mesma fase de cada marca, no mesmo instante', () {
      // Uma chuva da época 7 em Campinas: o começo, o clima de antes e quanto cada camada formou batem nos dois.
      final a = device(), b = device();
      final t0 = utc(2027, 1, 10, 18);
      var checked = 0;
      for (var t = t0; t < t0 + 30 * 86400 && checked < 6; t += 3 * 3600 + 1234) {
        final ma = a.modsAt(x21, y21, t), mb = b.modsAt(x21 + 0.4, y21 - 0.3, t);
        expect((ma.id, ma.runStartUtc, ma.prevId, ma.prevStartUtc, ma.prevEndUtc), (mb.id, mb.runStartUtc, mb.prevId, mb.prevStartUtc, mb.prevEndUtc));
        expect(ma.runStartUtc, lessThanOrEqualTo(t));
        expect(ma.prevEndUtc, ma.runStartUtc, reason: 'o de antes acaba quando este começa');
        expect(ma.prevId, isNot(ma.id));
        for (final g in catalog.of(ma.id).ground) {
          double amount(PlayerClimate c) => formAmount(sinceStartS: (t - c.runStartUtc).toDouble(), growS: g.val('grow_s', 900), fadeS: g.val('fade_s', 1800));
          expect(amount(ma), amount(mb));
        }
        checked++;
      }
      expect(checked, greaterThan(0));
    });

    test('clima forçado começa do zero quando é forçado e evolui na velocidade do debug', () {
      var wall = 1000.0;
      final force = DebugForce(wallS: () => wall)..set(weather: 'rain');
      final w = device(forced: () => force.weather, phase: force.phase);
      final t = utc(2027, 1, 10, 18);
      expect(w.modsAt(x21, y21, t).runStartUtc, t, reason: 'do zero');
      expect(w.puddlesNear(x21, y21, 60, t), isEmpty, reason: 'ainda nem pontos molhados');
      wall += 30;
      final p0 = w.puddlesNear(x21, y21, 60, t);
      expect(p0, isNotEmpty);
      expect(p0.first.size, closeTo(30 / 1800, 1e-6));
      force.setSpeed(60); // 30 s a 1x, depois 30 s a 60x: 30 + 1800 s de clima
      wall += 30;
      expect(force.phase().ageS, closeTo(1830, 1e-6));
      expect(w.puddlesNear(x21, y21, 60, t).first.size, 1);
      // Trocar para Limpo: as poças secam a partir dali, no mesmo relógio.
      force.set(weather: 'clear');
      wall += 30; // 1800 s de clima depois do fim
      final dry = w.puddlesNear(x21, y21, 60, t);
      expect(dry, isNotEmpty);
      expect(dry.first.wet, isFalse);
      expect(dry.first.size, closeTo(0.5, 1e-6));
      expect(w.modsAt(x21, y21, t).prevId, 'rain');
    });
  });

  group('Simulação de clima', () {
    test('passa por todos os climas em sequência, do zero; pula e repete; no fim de cada passo o clima seca', () {
      var wall = 0.0;
      final force = DebugForce(wallS: () => wall);
      final ids = catalog.climates.keys.toList();
      force.startSim(ids);
      expect((force.weather, force.speed), (ids[0], 60));
      expect(force.phase().ageS, 0);
      wall = 60;
      expect(force.phase().ageS, 3600, reason: '1 min a 60x');
      wall = 100; // 3/4 de 2 min: acabou e está secando
      expect(force.weather, ClimateSim.fadeTo);
      expect(force.phase().prevId, ids[0]);
      wall = 121;
      expect(force.weather, ids[1]);
      expect(force.phase().prevId, isNull, reason: 'o passo novo começa do zero');
      force.simJump(10);
      expect(force.weather, ids[10]);
      force.simRepeat(true);
      wall += 125;
      expect(force.weather, ids[10]);
      expect(force.phase().ageS, closeTo(5 * 60, 1e-6), reason: 'repetindo, do zero a cada 2 min');
      force.stopSim();
      expect(force.weather, isNull);
    });

    test('não muda o mundo nem dá recompensa', () {
      final tools = DevTools(realSource: FakeGps());
      expect(tools.sandboxed, isFalse);
      tools.force.startSim(['rain', 'snow']);
      expect(tools.sandboxed, isTrue, reason: 'nada do que se pega entra na Bolsa, no XP ou no bestiário');
      tools.force.stopSim();
      expect(tools.sandboxed, isFalse);
      // O mundo dos outros: sem o forçado, o clima e as peças são os mesmos de um aparelho sem debug.
      final t = utc(2027, 1, 10, 18);
      final plain = device();
      final other = device(forced: () => null, phase: tools.force.phase);
      expect(other.modsAt(x21, y21, t).runStartUtc, plain.modsAt(x21, y21, t).runStartUtc);
    });
  });

  group('Procissão', () {
    final e7 = loadEpochs().epochs.firstWhere((e) => e.id == 7).climate!;
    final piece = e7.def('fog_procession')!.pieces.whereType<ZonePiece>().single;
    final graph = TrafficGraph(loadTile: visual.tile, cellsPerTile: visual.cellsPerTile, extent: visual.pack.extent, cacheTiles: 256, stitch: true);

    test('a fila anda pelas ruas: todo ponto da fila e toda vela sobre uma linha do pacote visual', () {
      final zones = [
        for (final (dx, dy) in [(0, 0), (1, 0), (0, 1), (-1, -1)])
          ...e7.zones(seed, 7, (x21 / 16).floor() + dx, (y21 / 16).floor() + dy, 9000, e7.def('fog_procession')!.pieces.indexOf(piece), piece),
      ];
      var plans = 0;
      for (final z in zones) {
        final plan = planProcession(graph, z, mpc: mpc);
        if (plan == null) continue;
        plans++;
        expect(plan.figures, inInclusiveRange(12, 20));
        double off(double x, double y) {
          var best = double.infinity;
          for (var tx = (x / 64).floor() - 1; tx <= (x / 64).floor() + 1; tx++) {
            for (var ty = (y / 64).floor() - 1; ty <= (y / 64).floor() + 1; ty++) {
              for (final l in graph.linesOfTile(tx, ty)) {
                for (var s = 0; s + 1 < l.vertexCount; s++) {
                  final ax = l.xy[2 * s], ay = l.xy[2 * s + 1], ex = l.xy[2 * s + 2] - ax, ey = l.xy[2 * s + 3] - ay;
                  final len = ex * ex + ey * ey;
                  final u = len <= 0 ? 0.0 : (((x - ax) * ex + (y - ay) * ey) / len).clamp(0.0, 1.0);
                  final dx = ax + ex * u - x, dy = ay + ey * u - y;
                  best = best < dx * dx + dy * dy ? best : dx * dx + dy * dy;
                }
              }
            }
          }
          return best;
        }

        for (final t in [z.startUtc + 30.0, z.startUtc + 600.0, plan.arriveUtc - 5, plan.arriveUtc + 40]) {
          final figs = plan.figuresAt(t);
          expect(figs, isNotEmpty, reason: 'zona ${z.uidBase} em $t');
          for (final f in figs) {
            expect(off(f.x, f.y), lessThan(0.01 * 0.01), reason: 'figura fora da rua');
          }
          // A fila: uma atrás da outra, ~1,6 m.
          for (var i = 1; i < figs.length; i++) {
            final d = ((figs[i].x - figs[i - 1].x) * (figs[i].x - figs[i - 1].x) + (figs[i].y - figs[i - 1].y) * (figs[i].y - figs[i - 1].y));
            expect(d, lessThanOrEqualTo((1.7 / mpc) * (1.7 / mpc)));
          }
        }
        // Velas: acesas por onde a frente passou, por 30 min, e a trilha até o Eco.
        final candles = plan.candlesAt(plan.arriveUtc + 60);
        expect(candles, isNotEmpty);
        for (final c in candles.where((c) => c.litUtc < plan.arriveUtc)) {
          expect(off(c.x, c.y), lessThan(0.01 * 0.01));
        }
        expect(plan.candlesAt(plan.arriveUtc + 1800 + 60).where((c) => c.litUtc < plan.arriveUtc - 1), isNot(contains(candles.first)), reason: 'apagam em 30 min');
        // A frente chega ao fim da rota no instante em que o Eco do fim aparece, a 0,8 m/s.
        expect(plan.headAt(plan.arriveUtc), closeTo(plan.route.lengthM, 1e-6));
        expect(plan.headAt(plan.arriveUtc) - plan.headAt(plan.arriveUtc - 100), closeTo(80, 1e-6));
      }
      expect(plans, greaterThan(0));
    });

    test('a mesma Procissão em dois aparelhos: mesma rota, mesmas figuras', () {
      final z = e7.zones(seed, 7, (x21 / 16).floor(), (y21 / 16).floor(), 9001, e7.def('fog_procession')!.pieces.indexOf(piece), piece).single;
      final g2 = TrafficGraph(loadTile: visual.tile, cellsPerTile: visual.cellsPerTile, extent: visual.pack.extent, stitch: true);
      final a = planProcession(graph, z, mpc: mpc), b = planProcession(g2, z, mpc: mpc);
      expect(a?.route.xy, b?.route.xy);
      expect(a?.figures, b?.figures);
    });

    test('a zona que anda é achada de longe (de onde veio andando) e depois do fim (as velas), só para o desenho', () {
      final w = device(forced: () => 'fog_procession');
      final t = utc(2027, 11, 2, 15);
      final near = w.zonesNear(x21, y21, 6, t);
      final far = w.zonesNear(x21, y21, 6, t, movingExtra21: 1100 / mpc, lookBackS: 1860);
      expect(far.length, greaterThan(near.length));
      expect(far.map((z) => z.uidBase).toSet().length, far.length, reason: 'sem repetir');
      expect(near.every((z) => far.any((f) => f.uidBase == z.uidBase)), isTrue);
    });

    test('épocas até a 7: o Eco do fim fica onde estava (street_route só da época 8 em diante)', () {
      expect(piece.streetRoute, isFalse);
      final json = Map<String, dynamic>.of(epochsJson()['epochs'].firstWhere((e) => e['id'] == 7)['climate']['climates']['fog_procession']['pieces'][0] as Map<String, dynamic>);
      expect(ClimatePiece.fromJson({...json, 'street_route': true}), isA<ZonePiece>().having((p) => p.streetRoute, 'streetRoute', true));
      // Impressão digital do mundo de antes da 0.17.1 (conferida rodando o código da 0.17.0): o que nasce no Finados de 2027
      // (a Procissão), numa semana de janeiro (chuvas, poças, raios) e o começo de cada clima.
      final w = device();
      final parts = <int>[];
      for (var t = utc(2027, 11, 2, 9); t < utc(2027, 11, 2, 15); t += 180) {
        for (final s in w.extras(x21: x21, y21: y21, radiusM: 2000, t: t, metersPerCell21: mpc, levelOf: (id, add, uid) => add)) {
          parts.addAll([s.uid, (s.x * 1e4).round(), (s.y * 1e4).round()]);
        }
      }
      for (var t = utc(2027, 1, 10, 9); t < utc(2027, 1, 12, 15); t += 600) {
        for (final s in w.extras(x21: x21, y21: y21, radiusM: 800, t: t, metersPerCell21: mpc, levelOf: (id, add, uid) => add)) {
          parts.addAll([s.uid, (s.x * 1e4).round(), (s.y * 1e4).round()]);
        }
        final m = w.modsAt(x21, y21, t);
        parts.addAll([m.runStartUtc, m.windWindowStart]);
      }
      expect(parts, isNotEmpty);
      expect(fnv1a64(parts), _finadosExtras);
    });
  });
}

const _finadosExtras = -4220781441257367033;
