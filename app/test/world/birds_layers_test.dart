import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/data/traffic_pack.dart';
import 'package:kenoma/ui/game/draw_order.dart';
import 'package:kenoma/ui/game/traffic_painter.dart' show birdInAir;
import 'package:kenoma/world/city_scene.dart' show isBusShelter;
import 'package:kenoma/world/sim/birds.dart';

/// 0.24.2: pássaro voando por cima dos telhados; pousado na altura de onde pousou (no chão ou no telhado); o abrigo do
/// ponto de ônibus deixa de ser um prédio que gira com o chão.
class _Square implements TrafficPointSource {
  @override
  List<TrafficPoint> pointsIn(double l, double t, double r, double b) => [(kind: TrafficPointKind.square, x: 100.0, y: 100.0)];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  const mpc = 0.6;

  test('a camada do ar vem depois dos prédios e das árvores: o pássaro voando passa por cima dos telhados', () {
    expect(MapLayer.air.index, greaterThan(MapLayer.buildings.index));
    expect(MapLayer.cars.index, lessThan(MapLayer.buildings.index), reason: 'o pombo no chão e o gato no muro ficam por baixo');
  });

  test('o pombo que pousa dentro de um prédio fica no telhado; o que pousa no chão, no chão', () {
    for (final roof in [12.0, null]) {
      final flocks = BirdFlocks(points: _Square(), seed: 3)..roofAt = (x, y) => roof;
      flocks.update(0.1, 0, 0, mpc, (x, y) => false); // o bando nasce fora da vista
      final f = flocks.flocks.values.single;
      expect(f.birds.every((b) => !birdInAir(b)), isTrue, reason: 'ciscando no chão: passada do chão');
      for (var i = 0; i < 40; i++) {
        flocks.update(0.1, f.x, f.y, mpc, (x, y) => true); // o avatar em cima: o bando voa
      }
      for (var i = 0; i < 60; i++) {
        flocks.update(0.1, -1000, -1000, mpc, (x, y) => true);
      }
      expect(flocks.takeoffs, greaterThan(0));
      for (final b in f.birds) {
        expect(b.flying, isFalse);
        expect(b.roofM, roof ?? 0, reason: roof == null ? 'no chão' : 'no telhado de 12 m');
        expect(birdInAir(b), roof != null, reason: 'no telhado, sai na passada do ar (na posição deslocada do telhado)');
      }
    }
  });

  test('voando, o pombo e a maritaca saem na passada do ar', () {
    final b = Bird(0, 0, 0)..height = 0.5;
    expect(birdInAir(b), isTrue);
    expect(birdInAir(Bird(0, 0, 0), always: true), isTrue);
  });

  test('o abrigo do ponto de ônibus (prédio pequeno ao lado do ponto) sai dos prédios', () {
    expect(isBusShelter(12, 3), isTrue);
    expect(isBusShelter(120, 3), isFalse, reason: 'prédio de verdade ao lado do ponto fica');
    expect(isBusShelter(12, 40), isFalse, reason: 'longe do ponto, é outra coisa');
  });
}
