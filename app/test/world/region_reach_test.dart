import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/world/region_reach.dart';

/// 0.26.4: São Paulo e as regiões baixadas entram a menos de 40 km e saem a mais de 60 km; no Modo Viagem tudo fica.
void main() {
  const sp = GeoBox(south: -23.80, west: -46.83, north: -23.36, east: -46.36);

  test('a distância é até a borda: 0 dentro, ~70 km da Unicamp até a borda de São Paulo', () {
    expect(distanceToBoxM(-23.55, -46.63, sp), 0);
    final d = distanceToBoxM(-22.8174, -47.0697, sp);
    expect(d, inInclusiveRange(55000, 75000));
    expect(distanceToBoxM(-23.36 + 0.09, -46.6, sp), closeTo(10000, 300), reason: '0,09 grau ao norte da borda');
  });

  test('entra a menos de 40 km, sai a mais de 60 km, e entre os dois fica como está', () {
    RegionMove at(double km, bool loaded, {bool travel = false}) => regionMove(distM: km * 1000, loaded: loaded, loadM: 40000, unloadM: 60000, travel: travel);
    expect(at(39, false), RegionMove.load);
    expect(at(41, false), RegionMove.keep);
    expect(at(50, true), RegionMove.keep, reason: 'a folga: não sai antes dos 60');
    expect(at(61, true), RegionMove.unload);
    expect(at(500, false, travel: true), RegionMove.load, reason: 'Modo Viagem: o destino pode estar em qualquer região');
    expect(at(500, true, travel: true), RegionMove.keep);
  });

  test('o bbox do catálogo vem como oeste, sul, leste, norte', () {
    final b = GeoBox.fromBbox([-46.83, -23.80, -46.36, -23.36]);
    expect((b.south, b.west, b.north, b.east), (-23.80, -46.83, -23.36, -46.36));
  });
}
