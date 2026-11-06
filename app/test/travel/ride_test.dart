import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/travel/ride.dart';
import 'package:kenoma/travel/travel_path.dart';

void main() {
  const t0 = 1000;

  group('máquina de estados da corrida', () {
    test('com notificações: procura, chega, embarca e termina', () {
      final r = Ride(appName: 'Uber');
      expect(r.state, RideState.searching);
      r.onSignal(const RideSignal(state: RideState.driverComing, etaMin: 4), t0);
      expect(r.state, RideState.driverComing);
      expect(r.etaDueUtc, t0 + 240);
      r.onSignal(const RideSignal(state: RideState.arrived), t0 + 200);
      expect(r.state, RideState.arrived);
      r.onSignal(const RideSignal(state: RideState.inTrip), t0 + 260);
      expect(r.state, RideState.inTrip);
      r.onSignal(const RideSignal(state: RideState.finished), t0 + 900);
      expect(r.state, RideState.finished);
      expect(r.buttons, isEmpty);
    });

    test('sem notificação: o mesmo fluxo pelos botões', () {
      final r = Ride(appName: '99');
      expect(r.buttons, [RideButton.eta, RideButton.boarded]);
      r.onEtaButton(3, t0);
      expect(r.state, RideState.driverComing);
      expect(r.etaDueUtc, t0 + 180);
      r.onBoarded();
      expect(r.state, RideState.inTrip);
      expect(r.buttons, [RideButton.arrived]);
      r.onArrived();
      expect(r.state, RideState.finished);
    });

    test('texto desconhecido não muda nada e os botões continuam', () {
      final r = Ride(appName: 'Uber');
      r.onSignal(RideSignal.empty, t0);
      r.onSignal(RideSignal.empty, t0);
      expect(r.state, RideState.searching);
      expect(r.unrecognized, 2);
      expect(r.buttons, contains(RideButton.boarded));
      r.onBoarded();
      r.onSignal(RideSignal.empty, t0);
      expect(r.state, RideState.inTrip);
      expect(r.buttons, [RideButton.arrived]);
    });

    test('o ETA acaba e o carro conta como chegado, até uma notificação desmentir', () {
      final r = Ride(appName: 'Uber')..onEtaButton(1, t0);
      r.tick(t0 + 59);
      expect(r.state, RideState.driverComing);
      r.tick(t0 + 60);
      expect(r.state, RideState.arrived);
      r.onSignal(const RideSignal(state: RideState.driverComing, etaMin: 2), t0 + 61);
      expect(r.state, RideState.driverComing);
      expect(r.etaDueUtc, t0 + 181);
    });

    test('chegada dita por notificação não recua; outro motorista volta a procurar', () {
      final r = Ride(appName: 'Uber');
      r.onSignal(const RideSignal(state: RideState.arrived), t0);
      r.onSignal(const RideSignal(state: RideState.driverComing), t0 + 1);
      expect(r.state, RideState.arrived);
      r.onSignal(const RideSignal(state: RideState.searching), t0 + 2);
      expect(r.state, RideState.searching);
      expect(r.etaDueUtc, isNull);
    });

    test('em viagem nada recua, e o fim é o fim', () {
      final r = Ride(appName: 'Uber')..onBoarded();
      r.onSignal(const RideSignal(state: RideState.searching), t0);
      r.onSignal(const RideSignal(state: RideState.arrived), t0);
      expect(r.state, RideState.inTrip);
      r.onArrived();
      r.onSignal(const RideSignal(state: RideState.inTrip), t0);
      expect(r.state, RideState.finished);
    });

    test('Cheguei antes de embarcar não termina a corrida', () {
      final r = Ride(appName: 'Uber')..onArrived();
      expect(r.state, RideState.searching);
    });

    test('guarda o carro que a notificação disse', () {
      final r = Ride(appName: 'Uber');
      r.onSignal(const RideSignal(carType: 'suv', carColor: 0xFF112233), t0);
      r.onSignal(const RideSignal(state: RideState.driverComing), t0);
      expect((r.carType, r.carColor), ('suv', 0xFF112233));
    });
  });

  group('o carro acompanha o ETA', () {
    TravelPath km() => TravelPath.straight(0, 0, 100, 0, 10); // 1000 m

    test('chega junto com a estimativa', () {
      final a = RideApproach(km(), etaS: 100, startUtc: 0);
      expect(a.speedMps, closeTo(10, 1e-9));
      expect(a.sAt(50), closeTo(500, 1e-9));
      expect(a.arrivalUtc, closeTo(100, 1e-9));
      expect(a.sAt(500), closeTo(1000, 1e-9));
    });

    test('um tempo novo corrige a velocidade para bater com ele', () {
      final a = RideApproach(km(), etaS: 100, startUtc: 0);
      a.correct(25, 50); // faltam 500 m em 25 s
      expect(a.speedMps, closeTo(20, 1e-9));
      expect(a.arrivalUtc, closeTo(75, 1e-9));
      expect(a.sAt(60), closeTo(700, 1e-9));
      a.correct(100, 60); // o motorista atrasou
      expect(a.speedMps, closeTo(3, 1e-9));
      expect(a.arrivalUtc, closeTo(160, 1e-9));
    });

    test('a posição anda pelo caminho e a direção segue a linha', () {
      final a = RideApproach(km(), etaS: 100, startUtc: 0);
      final p = a.at(50);
      expect(p.x, closeTo(50, 1e-9));
      expect(p.heading, closeTo(0, 1e-9));
    });
  });
}
