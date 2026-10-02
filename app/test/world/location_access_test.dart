import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/world/location_access.dart';

class FakeGateway implements LocationGateway {
  FakeGateway({this.service = true, this.state = LocationPermissionState.denied, this.afterRequest = LocationPermissionState.granted});

  bool service;
  LocationPermissionState state;
  LocationPermissionState afterRequest;
  int requests = 0, checks = 0, appSettings = 0, locationSettings = 0;

  @override
  Future<bool> serviceEnabled() async => service;

  @override
  Future<LocationPermissionState> check() async {
    checks++;
    return state;
  }

  @override
  Future<LocationPermissionState> request() async {
    requests++;
    state = afterRequest;
    return afterRequest;
  }

  @override
  Future<void> openAppSettings() async => appSettings++;

  @override
  Future<void> openLocationSettings() async => locationSettings++;
}

void main() {
  test('já concedida: não explica e não pede', () async {
    final g = FakeGateway(state: LocationPermissionState.granted);
    var explained = 0;
    final r = await LocationAccessFlow(g).ensure(explain: () async {
      explained++;
      return true;
    });
    expect(r, LocationAccess.granted);
    expect((explained, g.requests), (0, 0));
  });

  test('ainda não concedida: explica primeiro, e só se o jogador continua abre o diálogo do sistema', () async {
    final g = FakeGateway();
    final order = <String>[];
    final r = await LocationAccessFlow(g).ensure(explain: () async {
      order.add('explicação');
      expect(g.requests, 0, reason: 'o diálogo do sistema só vem depois da explicação');
      return true;
    });
    order.add('pedido:${g.requests}');
    expect(r, LocationAccess.granted);
    expect(order, ['explicação', 'pedido:1']);
  });

  test('o jogador fecha a explicação: não pede nada ao sistema e fica "negada", podendo tentar de novo', () async {
    final g = FakeGateway();
    final flow = LocationAccessFlow(g);
    expect(await flow.ensure(explain: () async => false), LocationAccess.denied);
    expect(g.requests, 0);
    expect(await flow.ensure(explain: () async => true), LocationAccess.granted, reason: 'tentar de novo funciona');
    expect(g.requests, 1);
  });

  test('o sistema nega: "negada"; nega para sempre: "negada para sempre"', () async {
    final denied = FakeGateway(afterRequest: LocationPermissionState.denied);
    expect(await LocationAccessFlow(denied).ensure(explain: () async => true), LocationAccess.denied);
    final forever = FakeGateway(afterRequest: LocationPermissionState.deniedForever);
    expect(await LocationAccessFlow(forever).ensure(explain: () async => true), LocationAccess.deniedForever);
  });

  test('já negada para sempre: não explica nem pede (o sistema nem abriria o diálogo)', () async {
    final g = FakeGateway(state: LocationPermissionState.deniedForever);
    var explained = 0;
    final r = await LocationAccessFlow(g).ensure(explain: () async {
      explained++;
      return true;
    });
    expect(r, LocationAccess.deniedForever);
    expect((explained, g.requests), (0, 0));
  });

  test('GPS do aparelho desligado: avisa antes de pedir qualquer permissão', () async {
    final g = FakeGateway(service: false);
    var explained = 0;
    final r = await LocationAccessFlow(g).ensure(explain: () async {
      explained++;
      return true;
    });
    expect(r, LocationAccess.serviceOff);
    expect((explained, g.requests, g.checks), (0, 0, 0));
  });

  test('cada resultado tem uma mensagem em português, e a concedida não tem', () {
    expect(locationAccessMessage(LocationAccess.granted), isEmpty);
    for (final a in [LocationAccess.serviceOff, LocationAccess.denied, LocationAccess.deniedForever]) {
      expect(locationAccessMessage(a), isNotEmpty);
    }
    expect(locationAccessMessage(LocationAccess.deniedForever), contains('ajustes'));
    expect(locationAccessMessage(LocationAccess.serviceOff), contains('GPS'));
  });

  test('a explicação é curta e diz que só usa com o app aberto', () {
    expect(kLocationRationale.length, lessThan(160));
    expect(kLocationRationale, contains('só com o app aberto'));
  });
}
