import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/game/spawn_trigger.dart';

/// 0.25.1: de onde cada família nasce no desenho (GDD: o Humoth nasce onde o raio cai; Rill na poça, Clod no chão
/// revirado, Wisp na neblina). Sem gatilho que valha, nasce onde o Eco aparece.
void main() {
  const climates = {
    'lightning': {'storm'},
    'puddle': {'rain', 'storm'},
    'fog': {'fog'},
  };
  SpawnTrigger? of(String? spec, String climate, {bool night = true, (double, double)? lamp}) =>
      resolveSpawnTrigger(spec, climateId: climate, night: night, climates: climates, lamp: lamp);

  test('Humoth: o raio na tempestade (de dia também), senão o poste à noite, senão nada', () {
    expect(of('lightning_lamp', 'storm', night: false, lamp: (1, 1))?.kind, SpawnTriggerKind.lightning);
    expect(of('lightning_lamp', 'clear', lamp: (3, 4)), const SpawnTrigger(SpawnTriggerKind.lamp, (3, 4)));
    expect(of('lightning_lamp', 'clear', night: false, lamp: (3, 4)), isNull, reason: 'de dia o poste não acende');
    expect(of('lightning_lamp', 'clear'), isNull, reason: 'sem poste perto');
  });

  test('Rill na poça só com chuva, Clod sempre do chão, Wisp só na neblina, e quem não tem gatilho nasce onde aparece', () {
    expect(of('puddle', 'rain')?.kind, SpawnTriggerKind.puddle);
    expect(of('puddle', 'clear'), isNull);
    expect(of('ground', 'clear')?.kind, SpawnTriggerKind.ground);
    expect(of('fog', 'fog')?.kind, SpawnTriggerKind.fog);
    expect(of('fog', 'rain'), isNull);
    expect(of(null, 'storm'), isNull);
  });

  test('o poste mais perto dentro do alcance', () {
    final pts = [(10.0, 0.0), (3.0, 4.0), (0.0, 30.0)];
    expect(nearestPoint(pts, 0, 0, 6), (3.0, 4.0));
    expect(nearestPoint(pts, 0, 0, 4.9), isNull);
    expect(nearestPoint(const [], 0, 0, 100), isNull);
  });
}
