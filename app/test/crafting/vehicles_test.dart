import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/crafting/crafting_state.dart';
import 'package:kenoma/crafting/loadout.dart';
import 'package:kenoma/travel/travel_balance.dart';

import '../support/fixtures.dart';
import '../travel/travel_session_test.dart' show Rig, eco;

/// 0.24.5 (docs/GDD.md, "Veículos do Véu"): o veículo é só aparência. Escolhe o desenho pela faixa do modo trânsito e não
/// muda velocidade, recompensa nem as regras de passageiro.
void main() {
  final tb = TravelBalance(loadJson('assets/data/balance.json'));
  final walk = tb.vehicles[Vehicle.foot]!.maxMps, bike = tb.vehicles[Vehicle.bike]!.maxMps;

  test('a faixa: pela velocidade sem viagem; com viagem, pelo veículo escolhido nela', () {
    RideBand at(double v, [Vehicle? t]) => rideBandOf(speedMps: v, walkMaxMps: walk, bikeMaxMps: bike, travel: t);
    expect(at(1.4), RideBand.foot);
    expect(at(walk), RideBand.foot);
    expect(at(walk + 0.1), RideBand.bike);
    expect(at(bike), RideBand.bike);
    expect(at(bike + 0.1), RideBand.car);
    expect(at(30, Vehicle.bike), RideBand.bike, reason: 'de bicicleta na viagem, mesmo rápido');
    expect(at(1, Vehicle.bus), RideBand.car, reason: 'no ônibus parado no ponto');
    expect(at(1, Vehicle.moto), RideBand.car);
    expect(at(20, Vehicle.foot), RideBand.foot);
  });

  test('o veículo certo por faixa, e nenhum a pé ou escondido', () {
    final s = Rig().state;
    s.crafting.equipped[LoadoutSlot.vehicleBike] = 'item.vehicle.skate@good';
    s.crafting.equipped[LoadoutSlot.vehicleCar] = 'item.vehicle.cart';
    expect(vehicleLook(s, RideBand.foot), isNull);
    expect(vehicleLook(s, RideBand.bike), 'item.vehicle.skate@good');
    expect(vehicleLook(s, RideBand.car), 'item.vehicle.cart');
    s.crafting.looks[LoadoutSlot.vehicleBike] = 'item.vehicle.bike';
    expect(vehicleLook(s, RideBand.bike), 'item.vehicle.bike', reason: 'a aparência escolhida');
    s.crafting.hidden.add(LoadoutSlot.vehicleCar);
    expect(vehicleLook(s, RideBand.car), isNull, reason: 'mostrar no personagem desligado');
  });

  test('os veículos dos dados não têm efeito nenhum e só cabem no espaço da faixa deles', () {
    final book = loadGameData().craft;
    final vehicles = [for (final id in ['item.vehicle.bike', 'item.vehicle.skate', 'item.vehicle.cart']) book.item(id)!];
    expect(vehicles.every((v) => v.effects.isEmpty), isTrue);
    expect({for (final v in vehicles) v.id: v.kind}, {'item.vehicle.bike': 'vehicle_bike', 'item.vehicle.skate': 'vehicle_bike', 'item.vehicle.cart': 'vehicle_car'});
  });

  // A mesma viagem duas vezes, com e sem veículo equipado: tudo o que sai dela é igual.
  for (final (v, passenger) in [(Vehicle.bike, true), (Vehicle.car, true), (Vehicle.car, false), (Vehicle.bus, true)]) {
    test('${v.label}${v.asksPassenger ? (passenger ? ', passageiro' : ', motorista') : ''}: velocidade, recompensa e regras iguais com e sem veículo', () async {
      Future<(Map<String, dynamic>, Object, double?)> run(bool withVehicle) async {
        final r = Rig();
        if (withVehicle) {
          r.state.crafting.equipped[LoadoutSlot.vehicleBike] = 'item.vehicle.bike@perfect';
          r.state.crafting.equipped[LoadoutSlot.vehicleCar] = 'item.vehicle.cart@perfect';
        }
        r.choose(v);
        if (v.asksPassenger) r.travel.answerPassenger(passenger);
        final quiet = r.travel.quiet, maxMps = r.travel.avatarMaxMps;
        r.ecos = [eco(1), eco(2)];
        await r.drive();
        final o = r.travel.outcome!;
        final json = r.state.toJson(r.now)..remove('crafting');
        return (json, (o.driver, o.chest, o.sparks, o.distanceM, [for (final m in o.marks) m.uid].join(','), quiet), maxMps);
      }

      final a = await run(false), b = await run(true);
      expect(b.$1, a.$1, reason: 'o save inteiro (menos o próprio loadout)');
      expect(b.$2, a.$2, reason: 'motorista, baú, Fagulhas, distância, marcas e o mundo calado');
      expect(b.$3, a.$3, reason: 'a velocidade máxima do avatar');
    });
  }
}
