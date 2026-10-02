/// O GPS real, pelo `geolocator`. Só emite com o app aberto: a tela chama [stop] quando o app vai para
/// segundo plano e [start] quando volta. Sem serviço em primeiro plano e sem permissão de segundo plano
/// (Fase 0, docs/fase0-spec.md, seção 2).
library;

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../world/geo_fix.dart';
import '../world/location_access.dart';
import '../world/position_source.dart';

/// A leitura do geolocator no formato do jogo. Um carimbo de tempo inválido (alguns aparelhos mandam 0)
/// vira o relógio de agora.
GeoFix fixFromPosition(Position p, {int Function()? nowMs}) {
  final ms = p.timestamp.millisecondsSinceEpoch;
  return GeoFix(
    lat: p.latitude,
    lon: p.longitude,
    accuracyM: p.accuracy,
    timeMs: ms > 946684800000 ? ms : (nowMs ?? () => DateTime.now().millisecondsSinceEpoch)(),
  );
}

LocationPermissionState permissionFromGeolocator(LocationPermission p) => switch (p) {
      LocationPermission.always || LocationPermission.whileInUse => LocationPermissionState.granted,
      LocationPermission.deniedForever => LocationPermissionState.deniedForever,
      LocationPermission.denied || LocationPermission.unableToDetermine => LocationPermissionState.denied,
    };

class GeolocatorGateway implements LocationGateway {
  const GeolocatorGateway();

  @override
  Future<bool> serviceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermissionState> check() async => permissionFromGeolocator(await Geolocator.checkPermission());

  @override
  Future<LocationPermissionState> request() async => permissionFromGeolocator(await Geolocator.requestPermission());

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}

class GeolocatorPositionSource implements PositionSource {
  GeolocatorPositionSource({this.distanceFilterM = 2, this.interval = const Duration(seconds: 1)});

  /// Só entrega uma leitura nova depois de andar isto, em metros: "a cada poucos metros".
  final int distanceFilterM;

  /// Intervalo desejado entre leituras.
  final Duration interval;

  StreamSubscription<Position>? _sub;
  final StreamController<GeoFix> _out = StreamController<GeoFix>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();

  @override
  String get name => 'GPS';

  @override
  Stream<GeoFix> get fixes => _out.stream;

  /// Erros do fluxo (permissão tirada no meio, GPS desligado).
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> start() async {
    if (_sub != null) return;
    _sub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilterM,
        intervalDuration: interval,
      ),
    ).listen((p) => _out.add(fixFromPosition(p)), onError: _errors.add);
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
