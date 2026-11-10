import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/eclipse.dart';

import '../support/fixtures.dart';

/// Horas UT do dia [y]-[m]-[d] em segundos UTC.
int ut(int y, int m, int d, double h) => DateTime.utc(y, m, d).millisecondsSinceEpoch ~/ 1000 + (h * 3600).round();

/// Os valores esperados saem do JavaScript Solar/Lunar Eclipse Explorer da NASA (https://eclipse.gsfc.nasa.gov/JSEX/program.js
/// e https://eclipse.gsfc.nasa.gov/JLEX/program.js) rodado com os mesmos elementos, para o lugar na altitude 0. Tolerância:
/// 1 min nos instantes e 0,005 na magnitude (o porte dá diferença de segundos; o erro real vem do ΔT previsto, ~6 s).
void main() {
  const tol = 60;
  final e7 = loadEpochs().epochs.firstWhere((e) => e.id == 7);
  Eclipse find(String date) => e7.climate!.eclipses.expand((r) => r.events).firstWhere((e) => e.date == date);

  test('eclipse total de 2024-04-08: visível em Dallas (máximo 18h42 UT, magnitude ~1), não em Campinas', () {
    // https://eclipse.gsfc.nasa.gov/JSEX/SE2001.js, entrada "2024  4  8" (fora da época 7: só vetor de teste).
    final e = SolarEclipse('2024-04-08', const [
      2460409.262840, 18.0, -4.0, 4.0, 74.0, 74.0,
      -0.3182440, 0.5117116, 3.260e-05, -8.420e-06,
      0.2197640, 0.2709589, -5.950e-05, -4.660e-06,
      7.5862002, 0.0148440, -2.000e-06,
      89.5912170, 15.0040817, 0.000e-00,
      0.5358140, 0.0000618, -1.280e-05,
      -0.0102720, 0.0000615, -1.270e-05,
      0.0046683, 0.0046450,
    ]);
    final dallas = e.viewFrom(32.7767, -96.7970)!;
    expect(dallas.maxUtc, closeTo(ut(2024, 4, 8, 18.7089), tol));
    expect(dallas.startUtc, closeTo(ut(2024, 4, 8, 17.3867), tol));
    expect(dallas.endUtc, closeTo(ut(2024, 4, 8, 20.0429), tol));
    expect(dallas.magnitude, closeTo(1.0558, 0.005), reason: 'total: a razão Lua/Sol');
    expect(e.viewFrom(-22.9056, -47.0608), isNull);
  });

  test('eclipse anular de 2027-02-06: parcial em Campinas (magnitude 0,825), nada em Bogotá', () {
    final e = find('2027-02-06');
    final c = e.viewFrom(-22.9056, -47.0608)!;
    expect(c.maxUtc, closeTo(ut(2027, 2, 6, 16.3712), tol));
    expect(c.startUtc, closeTo(ut(2027, 2, 6, 14.5302), tol));
    expect(c.endUtc, closeTo(ut(2027, 2, 6, 18.0009), tol));
    expect(c.magnitude, closeTo(0.8252, 0.005));
    expect(e.viewFrom(4.7100, -74.0700), isNull, reason: 'Bogotá fica ao norte do limite da penumbra');
    expect(e.viewFrom(2.8200, -60.6700)!.magnitude, closeTo(0.0315, 0.005), reason: 'Boa Vista: o limite passa no norte de Roraima');
    expect(e.viewFrom(5.2700, -60.2000), isNull, reason: 'Monte Caburaí, já fora');
  });

  test('o Sol abaixo do horizonte corta o trecho: Luanda vê até o pôr do sol; Nairobi, com o Sol já posto, não vê', () {
    final e = find('2027-02-06');
    final luanda = e.viewFrom(-8.8400, 13.2300)!;
    expect(luanda.startUtc, closeTo(ut(2027, 2, 6, 16.5984), tol));
    expect((luanda.maxUtc, luanda.endUtc), (luanda.endUtc, luanda.endUtc), reason: 'o máximo visível é o pôr do sol');
    expect(luanda.endUtc, closeTo(ut(2027, 2, 6, 17.5380), tol));
    expect(luanda.magnitude, closeTo(0.5356, 0.005));
    expect(e.viewFrom(-1.2900, 36.8200), isNull, reason: 'magnitude 0,64 com o Sol abaixo do horizonte');
  });

  test('eclipse lunar total de 2029-06-26: visível em Campinas; o de 2028-12-31, não (Lua abaixo do horizonte)', () {
    final jun = find('2029-06-26').viewFrom(-22.9056, -47.0608)!;
    expect(jun.startUtc, closeTo(ut(2029, 6, 26, 1.5385), tol));
    expect(jun.maxUtc, closeTo(ut(2029, 6, 26, 3.3681), tol));
    expect(jun.endUtc, closeTo(ut(2029, 6, 26, 5.1973), tol));
    expect(jun.magnitude, closeTo(1.844, 1e-9));
    expect(find('2028-12-31').viewFrom(-22.9056, -47.0608), isNull);
  });

  test('eclipse lunar de 2029-12-20: a Lua nasce já na fase parcial e conta; o trecho começa no nascer', () {
    final v = find('2029-12-20').viewFrom(-22.9056, -47.0608)!;
    // NASA: U1 às 20,92 h com a Lua a -11°, máximo às 22,70 h a +10°.
    expect(v.startUtc, greaterThan(ut(2029, 12, 20, 20.9215) + tol));
    expect(v.startUtc, lessThan(ut(2029, 12, 20, 22.6984)));
    expect(v.maxUtc, closeTo(ut(2029, 12, 20, 22.6984), tol));
    expect(v.endUtc, closeTo(ut(2029, 12, 20, 24.4762), tol));
  });

  test('a época 7 traz 22 eclipses solares e os 8 lunares totais de 2026 a 2035, em ordem', () {
    final rules = {for (final r in e7.climate!.eclipses) r.id: r};
    expect(rules['solar_eclipse']!.events, hasLength(22));
    expect(rules['solar_eclipse']!.events.every((e) => e is SolarEclipse), isTrue);
    final lunar = rules['crimson_moon']!.events.cast<LunarEclipse>();
    expect([for (final e in lunar) e.date], ['2026-03-03', '2028-12-31', '2029-06-26', '2029-12-20', '2032-04-25', '2032-10-18', '2033-04-14', '2033-10-08']);
    expect(lunar.every((e) => e.e[5] == 1 && e.umbralMagnitude >= 1), isTrue, reason: 'só totais');
    for (final r in rules.values) {
      for (final (a, b) in r.events.indexed.skip(1).map((p) => (r.events[p.$1 - 1], p.$2))) {
        expect(a.span.$1, lessThan(b.span.$1));
      }
    }
  });
}
