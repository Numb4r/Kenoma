import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/climate.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/world/climate_world.dart';

import '../support/fixtures.dart';

int utc(int y, int m, int d, [int h = 0, int min = 0]) => DateTime.utc(y, m, d, h, min).millisecondsSinceEpoch ~/ 1000;

void main() {
  final seed = seedGlobal('KENOMA-TESTE');
  final data = loadGameData();
  final (cx20, cy20) = latLonToTile(-22.8174, -47.0697, 20); // Unicamp
  final x = cx20 * 2.0 + 1, y = cy20 * 2.0 + 1;

  // Silêncio do feed das 13:00 às 19:30 UTC: valem as janelas de 3 h das 12 e das 15 (o meio delas cai no evento). Depois,
  // céu limpo, para o Dilúvio de um sorteio não mexer no relógio.
  final s0 = utc(2026, 12, 1, 13), s1 = utc(2026, 12, 1, 19, 30);
  final events = [
    ClimateEvent(climate: 'silence', startsUtc: s0, endsUtc: s1),
    ClimateEvent(climate: 'clear', startsUtc: utc(2026, 12, 1, 18), endsUtc: utc(2026, 12, 2)),
    ClimateEvent(climate: 'clear', startsUtc: utc(2026, 12, 1, 9), endsUtc: utc(2026, 12, 1, 12)),
  ];
  ClimateWorld device() => ClimateWorld(seed: seed, schedule: loadEpochs(), speciesOfType: data.ecoOfType, itemExists: data.itemNames.containsKey)..events = events;

  test('o Silêncio congela o tráfego no horário do evento e, quando acaba, ele volta de onde parou', () {
    final a = device();
    final noon = utc(2026, 12, 1, 12).toDouble();
    expect(a.modsAt(x, y, utc(2026, 12, 1, 14)).trafficMult, 0, reason: 'a janela das 12 é Silêncio');
    // Antes do horário do evento, mesmo na janela de Silêncio, o tráfego anda.
    expect(a.trafficClock(x, y, noon + 1800), noon + 1800);
    // Parado no instante em que o Silêncio começa, a tarde inteira.
    for (final h in [13.0, 14.5, 16.0, 17.99]) {
      expect(a.trafficClock(x, y, noon + (h - 12) * 3600), s0.toDouble(), reason: '$h h');
    }
    // Acabou no fim da janela das 15 (18:00): anda a partir de onde parou, atrasado as 5 h da parada.
    final end = utc(2026, 12, 1, 18).toDouble();
    expect(a.trafficClock(x, y, end), s0.toDouble());
    expect(a.trafficClock(x, y, end + 0.5), closeTo(s0 + 0.5, 1e-6));
    expect(a.trafficClock(x, y, end + 3000), closeTo(s0 + 3000, 1e-6));
    // Na janela seguinte a ela (21:00), volta à hora real.
    final late = utc(2026, 12, 1, 21, 30).toDouble();
    expect(a.trafficClock(x, y, late), late);
  });

  test('dois aparelhos veem o mesmo relógio do tráfego', () {
    final a = device(), b = device();
    for (var t = utc(2026, 12, 1, 11).toDouble(); t < utc(2026, 12, 1, 23); t += 977.3) {
      expect(a.trafficClock(x, y, t), b.trafficClock(x, y, t), reason: '$t');
      expect(a.trafficClock(x, y, t, walker: true), b.trafficClock(x, y, t, walker: true));
    }
  });

  test('Silêncio forçado pelo debug congela no instante em que foi forçado', () {
    final w = ClimateWorld(seed: seed, schedule: loadEpochs(), speciesOfType: data.ecoOfType, itemExists: data.itemNames.containsKey, forced: () => 'silence');
    final at = utc(2026, 12, 3, 10, 7).toDouble();
    expect(w.trafficClock(x, y, at + 600, sinceUtc: at), at);
  });
}
