import 'dart:async';

import 'package:kenoma/world/geo_fix.dart';
import 'package:kenoma/world/location_access.dart';
import 'package:kenoma/world/position_source.dart';

/// "GPS real" de mentira: emite o que o teste mandar, só enquanto iniciado.
class FakeGps implements PositionSource {
  @override
  String get name => 'GPS';
  final _c = StreamController<GeoFix>.broadcast();
  bool started = false;
  int starts = 0, stops = 0;

  @override
  Stream<GeoFix> get fixes => _c.stream;

  void emit(double lat, double lon, {double acc = 8, int t = 1}) {
    if (started) _c.add(GeoFix(lat: lat, lon: lon, accuracyM: acc, timeMs: t));
  }

  @override
  Future<void> start() async {
    if (started) return;
    started = true;
    starts++;
  }

  @override
  Future<void> stop() async {
    started = false;
    stops++;
  }
}

/// Permissão de mentira, com o que o teste quiser.
class FakeGateway implements LocationGateway {
  FakeGateway({this.service = true, this.state = LocationPermissionState.denied, this.afterRequest = LocationPermissionState.granted});

  bool service;
  LocationPermissionState state;
  LocationPermissionState afterRequest;
  int requests = 0, appSettings = 0, locationSettings = 0;

  @override
  Future<bool> serviceEnabled() async => service;

  @override
  Future<LocationPermissionState> check() async => state;

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
