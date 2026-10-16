import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/behavior.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/world/debug_force.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/world/radar.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/world_view.dart';

import '../support/fixtures.dart';

const t0 = 1790040000;
final seed = seedGlobal('KENOMA-TESTE');
final street = loadStreetBalance();
final map = RegionMap(pack: loadCampinasPack(), biomes: loadBiomes());
final double lat0 = kCentroCampinas.$1, lon0 = kCentroCampinas.$2;

/// Uma época de teste que força o comportamento (e as chances de variante e Brilhante) de todos os Ecos.
EpochSchedule schedule(Map<String, int> weights, {double variant = 0, double shiny = 0}) {
  final j = jsonDecode(jsonEncode(epochsJson())) as Map<String, dynamic>;
  final e = (j['epochs'] as List).cast<Map<String, dynamic>>().firstWhere((e) => e['id'] == 2);
  e['starts_utc'] = '2026-01-01T00:00:00Z';
  e['valid_until_utc'] = '2027-12-31T00:00:00Z';
  final v2 = e['eco_v2'] as Map<String, dynamic>;
  v2['behavior_weights'] = {'passive': 0, 'skittish': 0, 'aggressive': 0, 'hidden': 0, ...weights};
  v2['variant_chance'] = variant;
  v2['shiny_chance'] = shiny;
  return EpochSchedule([Epoch.fromJson(e)]);
}

GameState newState() => GameState(groupCode: 'KENOMA-TESTE', balance: loadProgressBalance());

WorldView viewOf(GameState s, EpochSchedule sch, {DebugForce? force, List<String>? msgs}) => WorldView(
      field: SpawnField(seed: seed, schedule: sch, map: map, typeOf: (id) => id.split('.').first == 'soot' ? 'fire' : (id.startsWith('frond') ? 'plant' : 'water')),
      state: s,
      auraM: 25,
      viewM: 120,
      trackerM: 120,
      itemName: (i) => i,
      street: street,
      force: force,
      typeOf: (id) => id.startsWith('soot') ? 'fire' : (id.startsWith('frond') ? 'plant' : 'water'),
      onMessage: msgs?.add,
    );

/// Um Eco perto do centro e o ponto (lat, lon) dele.
(WorldSpawn, double, double) anEco(EpochSchedule sch) {
  final s = viewOf(newState(), sch);
  final eco = s.field.around(lat: lat0, lon: lon0, tUtc: t0, radiusM: 500, playerLevel: 1).firstWhere((x) => x.isEco);
  final (la, lo) = tileFractionToLatLon(eco.x, eco.y, biomeZoom);
  return (eco, la, lo);
}

/// O ponto a [meters] metros ao sul do ponto dado.
(double, double) south(double lat, double lon, double meters) => (lat - meters / 111320, lon);

void main() {
  group('Arisco', () {
    final sch = schedule({'skittish': 100});

    /// Chega do sul até o Eco a [speed] m/s, uma leitura por segundo, e diz se ele fugiu.
    bool fledWhenApproaching(double speed) {
      final (eco, la, lo) = anEco(sch);
      final state = newState();
      final msgs = <String>[];
      final v = viewOf(state, sch, msgs: msgs);
      var d = 70.0, t = t0;
      while (d > 5) {
        final (pla, plo) = south(la, lo, d);
        v.refresh(lat: pla, lon: plo, tUtc: t);
        d -= speed;
        t++;
      }
      final fled = state.isDone(eco.uid);
      if (fled) expect(msgs.any((m) => m.contains('arisco')), isTrue);
      return fled;
    }

    test('foge se o jogador entra na Aura acima de 2,5 m/s, e fica se vem devagar', () {
      expect(fledWhenApproaching(1.4), isFalse, reason: 'andando');
      expect(fledWhenApproaching(2.4), isFalse, reason: 'quase correndo');
      expect(fledWhenApproaching(3.0), isTrue, reason: 'correndo');
      expect(fledWhenApproaching(6.0), isTrue, reason: 'de bicicleta');
    });

    test('a velocidade é a média dos últimos 5 s: um arranque curto não conta', () {
      final (eco, la, lo) = anEco(sch);
      final state = newState();
      final v = viewOf(state, sch);
      var t = t0;
      // 10 s devagar (1 m/s), depois 1 s a 5 m/s ao entrar na Aura: a média dos últimos 5 s fica baixa.
      var d = 40.0;
      for (var i = 0; i < 10; i++) {
        final (pla, plo) = south(la, lo, d);
        v.refresh(lat: pla, lon: plo, tUtc: t++);
        d -= 1;
      }
      final (pla, plo) = south(la, lo, 24);
      v.refresh(lat: pla, lon: plo, tUtc: t); // 6 m no último segundo: a média dos 5 s é 2 m/s
      expect(v.playerSpeedMps, closeTo(2.0, 0.2));
      expect(v.playerSpeedMps, lessThan(2.5));
      expect(state.isDone(eco.uid), isFalse);
    });

    test('quem já estava dentro da Aura não foge de novo: só a entrada conta', () {
      final (eco, la, lo) = anEco(sch);
      final state = newState();
      final v = viewOf(state, sch);
      final (pla, plo) = south(la, lo, 10);
      v.refresh(lat: pla, lon: plo, tUtc: t0);
      v.refresh(lat: pla, lon: plo, tUtc: t0 + 1);
      expect(state.isDone(eco.uid), isFalse);
      expect(v.spawns.any((s) => s.uid == eco.uid), isTrue);
    });

    test('a fuga entra no registro e o Eco não volta', () {
      final (eco, la, lo) = anEco(sch);
      final state = newState();
      final v = viewOf(state, sch);
      var d = 70.0, t = t0;
      while (d > 5) {
        final (pla, plo) = south(la, lo, d);
        v.refresh(lat: pla, lon: plo, tUtc: t++);
        d -= 5;
      }
      expect(state.isDone(eco.uid), isTrue);
      final (pla, plo) = south(la, lo, 8);
      v.refresh(lat: pla, lon: plo, tUtc: t + 100);
      expect(v.spawns.any((s) => s.uid == eco.uid), isFalse);
    });
  });

  group('Agressivo', () {
    final sch = schedule({'aggressive': 100});

    test('ao entrar na Aura avisa uma vez só, mesmo saindo e entrando de novo', () {
      final (eco, la, lo) = anEco(sch);
      final v = viewOf(newState(), sch);
      final fired = <int>[];
      v.onAggressive = (s) {
        fired.add(s.uid);
        return true;
      };
      var t = t0;
      void at(double d) {
        final (pla, plo) = south(la, lo, d);
        v.refresh(lat: pla, lon: plo, tUtc: t++);
      }

      at(60);
      expect(fired, isEmpty);
      at(20);
      expect(fired, contains(eco.uid));
      at(60);
      at(20);
      expect(fired.where((u) => u == eco.uid).length, 1);
    });

    test('tela ocupada: a chance não se gasta e tenta de novo no quadro seguinte', () {
      final (eco, la, lo) = anEco(sch);
      final v = viewOf(newState(), sch);
      var busy = true;
      final opened = <int>[];
      v.onAggressive = (s) {
        if (busy) return false;
        opened.add(s.uid);
        return true;
      };
      final (pla, plo) = south(la, lo, 10);
      v.refresh(lat: pla, lon: plo, tUtc: t0);
      expect(opened, isEmpty);
      busy = false;
      v.refresh(lat: pla, lon: plo, tUtc: t0 + 1);
      expect(opened, contains(eco.uid));
    });

    test('Passivo e Oculto não disparam a folha sozinhos', () {
      for (final b in ['passive', 'hidden']) {
        final sch2 = schedule({b: 100});
        final (eco, la, lo) = anEco(sch2);
        final v = viewOf(newState(), sch2);
        var fired = 0;
        v.onAggressive = (_) {
          fired++;
          return true;
        };
        final (pla, plo) = south(la, lo, 10);
        v.refresh(lat: pla, lon: plo, tUtc: t0);
        expect(fired, 0, reason: b);
        expect(eco, isNotNull);
      }
    });
  });

  group('Oculto e Radar', () {
    final sch = schedule({'hidden': 100});

    test('não aparece no mapa nem no rastreador antes da varredura, mesmo dentro da Aura', () {
      final (eco, la, lo) = anEco(sch);
      final v = viewOf(newState(), sch);
      final (pla, plo) = south(la, lo, 10);
      v.refresh(lat: pla, lon: plo, tUtc: t0);
      expect(v.spawns.any((s) => s.uid == eco.uid), isFalse);
      expect(v.allEcos.any((s) => s.uid == eco.uid), isTrue, reason: 'existe, o Radar o conhece');
      expect(v.tracked(offScreen: (_) => true, trackerM: 120, max: 9).any((t) => t.spawn.uid == eco.uid), isFalse);
      expect(v.touch(eco, t0), TouchResult.encounter, reason: 'a regra do toque não muda; ele só não está na lista');
    });

    test('a varredura revela os Ocultos a até 60 m e só eles; fora disso continuam escondidos', () {
      final (eco, la, lo) = anEco(sch);
      final state = newState();
      final v = viewOf(state, sch);
      var (pla, plo) = south(la, lo, 40);
      v.refresh(lat: pla, lon: plo, tUtc: t0);
      final out = v.radar(t0);
      expect(out.revealed.map((s) => s.uid), contains(eco.uid));
      expect(v.spawns.any((s) => s.uid == eco.uid), isTrue);
      expect(state.story.count('hidden_revealed'), greaterThan(0));
      expect(state.radarLastUtc, t0);

      final far = viewOf(newState(), sch);
      (pla, plo) = south(la, lo, 150);
      far.refresh(lat: pla, lon: plo, tUtc: t0);
      expect(far.radar(t0).revealed.any((s) => s.uid == eco.uid), isFalse, reason: 'a 150 m está fora dos 60 m');
      expect(far.spawns.any((s) => s.uid == eco.uid), isFalse);
    });

    test('o revelado continua à vista por 15 minutos e some de novo depois', () {
      // Um Eco cuja janela de spawn ainda tem mais de 16 min: senão ele sumiria por outro motivo.
      late WorldSpawn eco;
      late double la, lo;
      var tStart = t0;
      for (var k = 0; k < 40; k++) {
        tStart = t0 + k * 60;
        final v = viewOf(newState(), sch);
        final e = v.field.around(lat: lat0, lon: lon0, tUtc: tStart, radiusM: 300, playerLevel: 1).firstWhere((x) => x.isEco && x.behavior == EcoBehavior.hidden);
        if (v.field.secondsLeft(e.cellX, e.cellY, tStart) >= 1000) {
          eco = e;
          (la, lo) = tileFractionToLatLon(e.x, e.y, biomeZoom);
          break;
        }
      }
      final state = newState();
      final v = viewOf(state, sch);
      final (pla, plo) = south(la, lo, 30);
      v.refresh(lat: pla, lon: plo, tUtc: tStart);
      v.radar(tStart);
      v.refresh(lat: pla, lon: plo, tUtc: tStart + 600);
      expect(v.spawns.any((s) => s.uid == eco.uid), isTrue, reason: '10 min depois ainda está');
      v.refresh(lat: pla, lon: plo, tUtc: tStart + 901);
      expect(v.spawns.any((s) => s.uid == eco.uid), isFalse, reason: 'passou dos 15 min');
    });

    test('a recarga é de 2 minutos', () {
      expect(radarWaitS(lastUtc: 1000, nowUtc: 1000, balance: street), 120);
      expect(radarWaitS(lastUtc: 1000, nowUtc: 1100, balance: street), 20);
      expect(radarWaitS(lastUtc: 1000, nowUtc: 1120, balance: street), 0);
      expect(radarWaitS(lastUtc: 0, nowUtc: 5000, balance: street), 0);
    });
  });

  group('rastros', () {
    final sch = schedule({'passive': 100}, variant: 1.0);

    test('os raros (aqui, todos variantes) deixam rastro a até 250 m, e os comuns não', () {
      final plain = schedule({'passive': 100});
      final v = viewOf(newState(), sch);
      v.refresh(lat: lat0, lon: lon0, tUtc: t0);
      final out = v.radar(t0);
      final inRange = v.allEcos.where((e) => v.distanceM(e) <= 250 && v.distanceM(e) >= street.traceHideWithinM);
      expect(out.traces.map((t) => t.uid).toSet(), inRange.map((e) => e.uid).toSet());
      expect(out.traces, isNotEmpty);

      final common = viewOf(newState()..levelOverride = 15, plain); // nível 15: nenhum Eco está acima dele
      common.refresh(lat: lat0, lon: lon0, tUtc: t0);
      final commonTraces = common.radar(t0).traces;
      for (final t in commonTraces) {
        expect(common.allEcos.firstWhere((e) => e.uid == t.uid).level, greaterThan(15), reason: 'sem variante, Brilhante nem Oculto, só o nível acima do jogador faz rastro');
      }
    });

    test('Eco de nível acima do jogador também é raro', () {
      final plain = schedule({'passive': 100});
      final v = viewOf(newState(), plain);
      v.refresh(lat: lat0, lon: lon0, tUtc: t0);
      final high = v.allEcos.where((e) => (e.level ?? 0) > 1).toList();
      final out = v.radar(t0);
      expect(out.traces.map((t) => t.uid).toSet(), high.where((e) => v.distanceM(e) <= 250 && v.distanceM(e) >= 40).map((e) => e.uid).toSet());
    });

    test('o erro da direção é de no máximo 30°, fixo na janela de 20 minutos e muda na seguinte', () {
      for (var uid = 1; uid < 200; uid++) {
        final e = traceError(seed: seed, uid: uid, tUtc: t0, maxDeg: 30);
        expect(e.abs(), lessThanOrEqualTo(30 * math.pi / 180 + 1e-12));
        expect(traceError(seed: seed, uid: uid, tUtc: t0 + 5, maxDeg: 30), e, reason: 'mesma janela');
      }
      final errs = {for (var w = 0; w < 30; w++) traceError(seed: seed, uid: 7, tUtc: t0 + w * 1200, maxDeg: 30)};
      expect(errs.length, greaterThan(20), reason: 'muda a cada janela');
      final both = [for (var uid = 1; uid < 400; uid++) traceError(seed: seed, uid: uid, tUtc: t0, maxDeg: 30)];
      expect(both.any((e) => e > 0.2), isTrue);
      expect(both.any((e) => e < -0.2), isTrue);
    });

    test('a direção aponta para o Eco mais o erro; nível 1 sem tipo, nível 2 (nível 5 do Conjurador) com o tipo', () {
      final state1 = newState();
      final v1 = viewOf(state1, sch);
      v1.refresh(lat: lat0, lon: lon0, tUtc: t0);
      expect(v1.radar(t0).traces.every((t) => t.typeId == null), isTrue);
      expect(scannerLevel(4, street), 1);
      expect(scannerLevel(5, street), 2);

      final state2 = newState()..levelOverride = 5;
      final v2 = viewOf(state2, sch);
      v2.refresh(lat: lat0, lon: lon0, tUtc: t0);
      final out2 = v2.radar(t0);
      expect(out2.traces, isNotEmpty);
      expect(out2.traces.every((t) => const {'fire', 'plant', 'water'}.contains(t.typeId)), isTrue);

      final t = out2.traces.first;
      final eco = v2.allEcos.firstWhere((e) => e.uid == t.uid);
      final (px, py) = latLonToTileFraction(lat0, lon0, biomeZoom);
      final straight = math.atan2(eco.y - py, eco.x - px);
      expect(traceBearing(t, playerX: px, playerY: py, ecoX: eco.x, ecoY: eco.y), closeTo(straight + t.errorRad, 1e-12));
      expect(t.errorRad.abs(), lessThanOrEqualTo(30 * math.pi / 180 + 1e-12));
    });

    test('o rastro fica 5 minutos no mapa e depois some', () {
      final v = viewOf(newState(), sch);
      v.refresh(lat: lat0, lon: lon0, tUtc: t0);
      v.radar(t0);
      expect(v.traces, isNotEmpty);
      v.refresh(lat: lat0, lon: lon0, tUtc: t0 + 200);
      expect(v.traces, isNotEmpty);
      v.refresh(lat: lat0, lon: lon0, tUtc: t0 + 301);
      expect(v.traces, isEmpty);
    });
  });

  group('debug: forçar o próximo spawn', () {
    final sch = schedule({'passive': 100});

    test('o pedido vai para o primeiro Eco novo, uma vez só, e o forçado continua forçado', () {
      final force = DebugForce()..set(behavior: EcoBehavior.aggressive, shiny: true);
      final v = viewOf(newState(), sch, force: force);
      v.refresh(lat: lat0, lon: lon0, tUtc: t0);
      final forced = v.allEcos.where((e) => e.behavior == EcoBehavior.aggressive && e.shiny).toList();
      expect(forced, hasLength(1));
      expect(force.pendingEco, isFalse, reason: 'o pedido foi gasto');
      v.refresh(lat: lat0, lon: lon0, tUtc: t0 + 1);
      expect(v.allEcos.where((e) => e.shiny).length, 1, reason: 'o segundo quadro não força outro');
      expect(v.allEcos.firstWhere((e) => e.uid == forced.single.uid).shiny, isTrue, reason: 'o forçado continua');
    });

    test('sem pedido nada muda, e limpar tudo zera os pedidos e o clima', () {
      final force = DebugForce();
      final v = viewOf(newState(), sch, force: force);
      v.refresh(lat: lat0, lon: lon0, tUtc: t0);
      expect(v.allEcos.every((e) => e.behavior == EcoBehavior.passive && !e.shiny), isTrue);
      force.set(behavior: EcoBehavior.hidden, variant: true);
      force.clearAll();
      expect((force.pendingEco, force.weather), (false, null));
    });
  });

  group('Familiar', () {
    test('soma o bônus de coleta ao raio, junto com o do Círculo', () {
      final v = viewOf(newState(), schedule({'passive': 100}));
      expect(street.familiarPickupBonusM, 5);
      expect(v.pickupRadiusM, 25 + 5);
    });
  });
}
