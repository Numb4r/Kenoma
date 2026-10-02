import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kenoma/data/geolocator_source.dart';
import 'package:kenoma/world/location_access.dart';

Position pos({double lat = -22.8, double lon = -47.0, double acc = 7.5, DateTime? t}) => Position(
      latitude: lat,
      longitude: lon,
      timestamp: t ?? DateTime.utc(2026, 10, 2, 12),
      accuracy: acc,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  test('a leitura do geolocator vira a leitura do jogo, com a precisão e o instante UTC', () {
    final f = fixFromPosition(pos(lat: -22.8174, lon: -47.0697, acc: 12.5));
    expect((f.lat, f.lon, f.accuracyM), (-22.8174, -47.0697, 12.5));
    expect(f.timeMs, DateTime.utc(2026, 10, 2, 12).millisecondsSinceEpoch);
  });

  test('um carimbo de tempo inválido (aparelhos que mandam 0) vira o relógio de agora', () {
    final f = fixFromPosition(pos(t: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)), nowMs: () => 1790000000000);
    expect(f.timeMs, 1790000000000);
  });

  test('as permissões do geolocator viram as do jogo', () {
    expect(permissionFromGeolocator(LocationPermission.whileInUse), LocationPermissionState.granted);
    expect(permissionFromGeolocator(LocationPermission.always), LocationPermissionState.granted);
    expect(permissionFromGeolocator(LocationPermission.denied), LocationPermissionState.denied);
    expect(permissionFromGeolocator(LocationPermission.unableToDetermine), LocationPermissionState.denied);
    expect(permissionFromGeolocator(LocationPermission.deniedForever), LocationPermissionState.deniedForever);
  });

  test('o GPS real se chama GPS e a fonte é a interface que o jogo conhece', () {
    final s = GeolocatorPositionSource();
    expect(s.name, 'GPS');
    expect((s.distanceFilterM, s.interval), (2, const Duration(seconds: 1)));
  });
}
