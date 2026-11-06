import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/player/progression.dart' show localDay;
import 'package:kenoma/story/mentor_script.dart';
import 'package:kenoma/travel/deep_links.dart';
import 'package:kenoma/travel/notification_parser.dart';
import 'package:kenoma/travel/ride.dart';
import 'package:kenoma/travel/travel_balance.dart';
import 'package:kenoma/travel/travel_path.dart';
import 'package:kenoma/travel/travel_session.dart';
import 'package:kenoma/travel/trip.dart';
import 'package:kenoma/world/region_map.dart';
import 'package:kenoma/world/spawn_field.dart';
import 'package:kenoma/world/traffic_graph.dart';
import 'package:kenoma/world/world_view.dart';

import '../support/fixtures.dart';

const double mpc = 10;
const double x0 = 1000000, y0 = 2000000;
const String spark = 'item.dust.fire';

WorldSpawn eco(int uid, {String species = 'soot.eco'}) => WorldSpawn(uid: uid, kind: 'eco', entryId: species, quantity: 1, x: x0, y: y0, cellX: 0, cellY: 0, window: 1, level: 2);

class Rig {
  Rig({this.now = 1800000000}) {
    state = GameState(groupCode: 'KENOMA-TESTE', balance: loadProgressBalance());
    travel = TravelSession(
      state: state,
      balance: TravelBalance(loadJson('assets/data/balance.json')),
      graph: TrafficGraph(loadTile: (_, _) => null, cellsPerTile: 64, extent: 4096),
      patterns: RidePatterns.fromJson(loadJson('assets/data/ride_patterns.json')),
      radioLines: const [MentorMessage(id: 'a', afterS: 0, text: 'A'), MentorMessage(id: 'b', afterS: 0, text: 'B')],
      sparkItem: (_, _, _) => spark,
      ecosInReach: () => ecos,
      nowUtc: () => now,
    );
  }

  int now;
  late GameState state;
  late TravelSession travel;
  List<WorldSpawn> ecos = const [];

  /// Fica na posição [m] metros a leste da origem.
  void at(double m, {double speed = 10}) => travel.onPosition(x: x0 + m / mpc, y: y0, mpc: mpc, speedMps: speed);

  /// Escolhe o destino a [km] e vai de [v], sem resposta sobre passageiro.
  void choose(Vehicle v, {double km = 3}) {
    at(0);
    travel.open();
    travel.tapCell(x0 + km * 1000 / mpc, y0);
    travel.chooseVehicle(v);
  }

  /// Anda até o destino e fica parado lá até a viagem acabar.
  Future<void> drive({double km = 3}) async {
    await pumpEventQueue();
    for (var m = 0.0; m < km * 1000; m += 100) {
      now += 10;
      at(m);
      travel.tick(speedMps: 10);
    }
    await arrive(km * 1000);
  }

  Future<void> arrive(double m) async {
    for (var i = 0; i < 20 && travel.stage == TravelStage.traveling; i++) {
      now += 1;
      at(m, speed: 0);
      travel.tick(speedMps: 0);
    }
  }
}

void main() {
  group('passageiro versus motorista', () {
    test('passageiro: Ecos marcados, Rádio e baú proporcional à distância', () async {
      final r = Rig()..choose(Vehicle.car);
      expect(r.travel.stage, TravelStage.askPassenger);
      r.travel.answerPassenger(true);
      expect(r.travel.radioOn, isTrue);
      expect(r.travel.quiet, isTrue);
      expect(r.travel.radioLine(r.now), isNotNull);
      r.ecos = [eco(1), eco(2)];
      await r.drive();
      final o = r.travel.outcome!;
      expect(r.travel.stage, TravelStage.done);
      expect(o.driver, isFalse);
      expect(o.chest, isTrue);
      expect(o.distanceM, closeTo(3000, 150));
      expect(o.sparks, 5, reason: '2 Fagulhas por km sobre os 2,9 km andados');
      expect(r.state.count(spark), 5);
      expect(o.marks.map((m) => m.uid).toSet(), {GameState.uidKey(1), GameState.uidKey(2)});
      expect(r.state.markOf(1), isNotNull);
    });

    test('motorista: só a distância gravada', () async {
      final r = Rig()..choose(Vehicle.car);
      r.travel.answerPassenger(false);
      expect(r.travel.quiet, isTrue, reason: 'o mundo fica calado');
      expect(r.travel.driver, isTrue);
      expect(r.travel.radioOn, isFalse);
      expect(r.travel.radioLine(r.now), isNull);
      r.ecos = [eco(1), eco(2)];
      await r.drive();
      final o = r.travel.outcome!;
      expect(o.driver, isTrue);
      expect(o.chest, isFalse);
      expect(o.sparks, 0);
      expect(o.marks, isEmpty);
      expect(r.state.marks, isEmpty);
      expect(r.state.count(spark), 0);
      expect(r.state.settings.containsKey(kChestGivenSetting), isFalse);
      expect(r.state.story.count('trip_m'), greaterThan(2800));
      expect(r.state.progress.xp, 0);
    });

    test('moto pergunta; ônibus não, e é passageiro', () {
      expect((Rig()..choose(Vehicle.moto)).travel.stage, TravelStage.askPassenger);
      final bus = Rig()..choose(Vehicle.bus);
      expect(bus.travel.stage, TravelStage.traveling);
      expect(bus.travel.radioOn, isTrue);
    });

    test('a pergunta vale por viagem: dirigir uma vez não prende a próxima', () {
      final r = Rig()..choose(Vehicle.car);
      r.travel.answerPassenger(false);
      r.travel.cancel();
      r.choose(Vehicle.car);
      expect(r.travel.stage, TravelStage.askPassenger);
      expect(r.travel.passenger, isTrue);
    });

    test('a marcação respeita o limite de marcas e pula quem não responde a ela', () async {
      final r = Rig()..choose(Vehicle.bus);
      r.ecos = [eco(9, species: 'soot.ritual'), for (var i = 1; i <= 6; i++) eco(i)];
      r.now += 1;
      r.travel.tick(speedMps: 10);
      expect(r.state.marks.length, r.state.balance.markMax);
      expect(r.state.markOf(9), isNull);
      expect(r.state.marks.first.expiresUtc - r.state.marks.first.markedUtc, r.travel.balance.markDurationS);
    });

    test('a viagem cancelada não dá baú', () async {
      final r = Rig()..choose(Vehicle.bus);
      for (var m = 0.0; m < 2000; m += 100) {
        r.now += 10;
        r.at(m);
      }
      r.travel.cancel();
      expect(r.travel.stage, TravelStage.idle);
      expect(r.state.count(spark), 0);
    });
  });

  group('a pé e de bicicleta', () {
    test('a pé é jogo normal: mundo vivo, sem Rádio, sem marca, sem baú', () async {
      final r = Rig()..choose(Vehicle.foot, km: 0.5);
      expect(r.travel.quiet, isFalse);
      r.ecos = [eco(1)];
      await r.drive(km: 0.5);
      expect(r.state.marks, isEmpty);
      expect(r.travel.outcome!.chest, isFalse);
      expect(r.state.count(spark), 0);
    });

    test('bicicleta acima de 25 km/h não conta para o baú', () async {
      final r = Rig()..choose(Vehicle.bike);
      for (var m = 0.0; m < 3000; m += 200) {
        r.now += 10; // 20 m/s
        r.at(m);
      }
      await r.arrive(3000);
      expect(r.travel.outcome!.sparks, 0);
      expect(r.travel.outcome!.distanceM, closeTo(3000, 250));
    });

    test('sem rota não há faixa de coleta; com rota, só na faixa e na velocidade aceita', () async {
      final r = Rig()..choose(Vehicle.bike);
      await pumpEventQueue();
      expect(r.travel.route, isNull);
      r.at(100);
      expect(r.travel.pickupBonusM, 0);
      r.travel.route = TravelPath.straight(x0, y0, x0 + 300, y0, mpc);
      r.at(100, speed: 6);
      expect(r.travel.pickupBonusM, r.travel.balance.vehicles[Vehicle.bike]!.bandM);
      r.at(100, speed: 8);
      expect(r.travel.pickupBonusM, 0, reason: 'acima de 25 km/h');
      r.travel.onPosition(x: x0 + 10, y: y0 + 500 / mpc, mpc: mpc, speedMps: 6);
      expect(r.travel.pickupBonusM, 0, reason: 'fora da faixa');
    });
  });

  group('teto diário do baú', () {
    test('o segundo baú do dia para no teto, e o dia seguinte recomeça', () async {
      final r = Rig();
      final cap = r.travel.balance.chestDailyCap;
      final day = localDay(r.now);
      r.state.setSetting(kChestDaySetting, day);
      r.state.setSetting(kChestGivenSetting, cap - 2);
      r.choose(Vehicle.bus);
      await r.drive();
      final o = r.travel.outcome!;
      expect(o.sparks, 2);
      expect(o.capped, isTrue);
      expect(chestCapLeft(r.state, day, cap), 0);
      r.travel.closeOutcome();

      r.choose(Vehicle.bus);
      await r.drive();
      expect(r.travel.outcome!.sparks, 0);
      expect(r.travel.outcome!.capped, isTrue);
      expect(r.state.count(spark), 2);
      r.travel.closeOutcome();

      r.now += 86400;
      r.choose(Vehicle.bus);
      await r.drive();
      expect(r.travel.outcome!.sparks, 5);
      expect(r.travel.outcome!.capped, isFalse);
      expect(chestCapLeft(r.state, localDay(r.now), cap), cap - 5);
    });

    test('cálculo puro', () {
      expect(chestSparks(rewardM: 2999, perKm: 2, capLeft: 100), 5);
      expect(chestSparks(rewardM: 2999, perKm: 2, capLeft: 3), 3);
      expect(chestSparks(rewardM: 400, perKm: 2, capLeft: 3), 0);
    });
  });

  group('chegada', () {
    test('passar perto sem parar não conta; parar longe também não', () {
      final w = ArrivalWatch(radiusM: 40, holdS: 8, speedMps: 1.5);
      expect(w.feed(distanceM: 30, speed: 10, tUtc: 0), isFalse);
      expect(w.feed(distanceM: 100, speed: 0, tUtc: 10), isFalse);
      expect(w.feed(distanceM: 30, speed: 0, tUtc: 20), isFalse);
      expect(w.feed(distanceM: 30, speed: 0, tUtc: 27), isFalse);
      expect(w.feed(distanceM: 30, speed: 0, tUtc: 28), isTrue);
      expect(w.feed(distanceM: 30, speed: 5, tUtc: 29), isFalse, reason: 'andou: recomeça');
    });

    test('a distância ignora o tremor do GPS parado', () {
      final t = TripRecorder(maxRewardMps: 100, minStepM: 5);
      for (var i = 0; i < 100; i++) {
        t.add(1000 + (i.isEven ? 0.1 : -0.1), 1000, 10, i);
      }
      expect(t.recordedM, 0);
    });
  });

  group('rádio', () {
    test('as falas se revezam', () {
      int at(int t) => radioIndex(seed: 7, startUtc: 100, tUtc: t, lineS: 12, count: 4);
      expect(at(100), at(111));
      expect(at(112), (at(100) + 1) % 4);
      expect(at(148), at(100));
    });
  });

  group('corrida', () {
    Rig ride() {
      final r = Rig()..choose(Vehicle.car);
      r.travel.startRide('Uber', kUberPackage);
      return r;
    }

    test('o botão do app já é passageiro, sem pergunta, e antes do embarque o jogo é normal', () {
      final r = ride();
      expect(r.travel.stage, TravelStage.traveling);
      expect(r.travel.passenger, isTrue);
      expect(r.travel.quiet, isFalse);
      r.ecos = [eco(1)];
      r.now += 1;
      r.travel.tick(speedMps: 0);
      expect(r.state.marks, isEmpty);
      expect(r.travel.viewWidthM, isNull);
    });

    test('sem notificação: tempo, Entrei e Cheguei, com o baú depois de o carro sair', () async {
      final r = ride();
      r.travel.onRideEta(4);
      await pumpEventQueue();
      final a = r.travel.approach!;
      expect(a.path.lengthM, closeTo(240 * r.travel.balance.urbanSpeedMps, 1e-6), reason: 'sem grafo: reta na distância ETA × velocidade');
      expect(a.arrivalUtc, closeTo(r.now + 240, 1e-6));
      r.travel.onRideEta(2);
      expect(a.arrivalUtc, closeTo(r.now + 120, 1e-6));
      r.travel.onRideBoarded();
      expect(r.travel.quiet, isTrue);
      expect(r.travel.hidesPlayerAt(r.now.toDouble()), isFalse, reason: 'o embarque ainda está acontecendo');
      expect(r.travel.boardingAt(r.now + 0.1), isNotNull);
      expect(r.travel.hidesPlayerAt(r.now + 2.0), isTrue);
      final car = r.travel.carPose(r.now + 2.0, 5, 6, 1)!;
      expect((car.x, car.y, car.heading), (5.0, 6.0, 1.0), reason: 'o carro é o avatar');
      for (var m = 0.0; m < 3000; m += 100) {
        r.now += 10;
        r.at(m);
        r.travel.tick(speedMps: 10);
      }
      r.travel.onRideArrived();
      expect(r.travel.ride!.state, RideState.finished);
      expect(r.travel.stage, TravelStage.traveling, reason: 'o carro ainda está saindo');
      expect(r.travel.hidesPlayerAt(r.now.toDouble()), isFalse, reason: 'o avatar desceu');
      r.now += r.travel.balance.leaveS.ceil();
      r.travel.tick(speedMps: 0);
      expect(r.travel.stage, TravelStage.done);
      expect(r.travel.outcome!.sparks, 5);
    });

    test('sintético, conferir com corrida real: notificações movem a corrida e corrigem o carro', () async {
      final r = ride();
      r.travel.onNotification(kUberPackage, 'Seu motorista está a caminho', 'Chega em 5 min, Hyundai Creta azul');
      await pumpEventQueue();
      expect(r.travel.ride!.state, RideState.driverComing);
      expect(r.travel.ride!.carType, 'suv');
      final a = r.travel.approach!;
      r.now += 60;
      r.travel.onNotification(kUberPackage, 'Seu motorista está a caminho', 'Chega em 2 min');
      expect(a.arrivalUtc, closeTo(r.now + 120, 1e-6));
      r.travel.onNotification(kUberPackage, 'Viagem iniciada', 'A caminho do destino');
      expect(r.travel.quiet, isTrue);
      r.travel.onNotification(kUberPackage, 'Você chegou', 'Avalie sua viagem');
      expect(r.travel.ride!.state, RideState.finished);
    });

    test('sintético, conferir com corrida real: texto desconhecido e outro app não mexem na corrida', () {
      final r = ride();
      r.travel.onNotification(kUberPackage, 'Promoção', 'Cupom de desconto');
      r.travel.onNotification(k99Package, 'Motorista chegou', '');
      expect(r.travel.ride!.state, RideState.searching);
      expect(r.travel.ride!.buttons, contains(RideButton.boarded));
    });

    test('parar perto do destino termina a corrida sem notificação', () async {
      final r = ride();
      r.travel.onRideBoarded();
      await r.drive();
      expect(r.travel.ride?.state ?? RideState.finished, RideState.finished);
    });

    test('outro motorista: o carro some', () async {
      final r = ride();
      r.travel.onRideEta(4);
      await pumpEventQueue();
      r.travel.onNotification(kUberPackage, 'Procurando outro motorista', 'Procurando um motorista');
      expect(r.travel.approach, isNull);
      expect(r.travel.ride!.state, RideState.searching);
      await pumpEventQueue();
      expect(r.travel.routing, isFalse, reason: 'a rota até o destino não depende do carro');
    });
  });

  group('mundo calado', () {
    const lat = -22.8215, lon = -47.0647; // Unicamp
    const t0 = 1800000000;

    WorldView view(GameState state) => WorldView(
          field: SpawnField(seed: seedGlobal('KENOMA-TESTE'), schedule: loadEpochs(), map: RegionMap(pack: loadCampinasPack(), biomes: loadBiomes())),
          state: state,
          auraM: 40,
          viewM: 120,
          itemName: (id) => id,
          street: loadStreetBalance(),
        );

    test('em viagem motorizada a Fagulha fica onde está, sem XP', () {
      final state = GameState.fresh(groupCode: 'KENOMA-TESTE', startInventory: {}, balance: loadProgressBalance());
      final v = view(state);
      final s = v.field.around(lat: lat, lon: lon, tUtc: t0, radiusM: 400, playerLevel: 1).firstWhere((s) => s.kind == 'spark');
      final (la, lo) = tileFractionToLatLon(s.x, s.y, biomeZoom);
      v.quiet = () => true;
      expect(v.refresh(lat: la, lon: lo, tUtc: t0), isEmpty);
      expect(state.isDone(s.uid), isFalse);
      expect(v.spawns.any((o) => o.uid == s.uid), isTrue);
      expect(state.progress.xp, 0);
      v.quiet = () => false;
      expect(v.refresh(lat: la, lon: lo, tUtc: t0), isNotEmpty, reason: 'fora da viagem, tudo volta');
    });

    test('a faixa da bicicleta alarga o raio de coleta, o mesmo que o círculo desenha', () {
      final state = GameState.fresh(groupCode: 'KENOMA-TESTE', startInventory: {}, balance: loadProgressBalance());
      final v = view(state);
      final base = v.auraRadiusM;
      v.travelPickupM = () => 25;
      expect(v.auraRadiusM, base + 25);
    });
  });

  group('dados', () {
    test('balance.json, mentor.json e textos-mentor.md têm o que a viagem lê', () {
      final data = loadGameData();
      expect(data.travel.vehicles.length, Vehicle.values.length);
      expect(data.travel.vehicles[Vehicle.bike]!.maxKmh, 25);
      expect(data.mentor.radio, isNotEmpty);
      final md = File('../docs/textos-mentor.md').readAsStringSync();
      for (final m in data.mentor.radio) {
        expect(md, contains(m.text));
      }
    });

    test('o save não muda de formato: o baú mora em settings', () {
      final state = GameState(groupCode: 'KENOMA-TESTE', balance: loadProgressBalance());
      recordChest(state, 100, 5, 30);
      expect(state.toJson(0)['settings'], containsPair(kChestGivenSetting, 5));
    });
  });
}
