import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/astro.dart';
import 'package:kenoma/core/climate.dart';
import 'package:kenoma/core/seed.dart';

import '../support/fixtures.dart';

int utc(int y, int m, int d, [int h = 0, int min = 0]) => DateTime.utc(y, m, d, h, min).millisecondsSinceEpoch ~/ 1000;

void main() {
  final seed = seedGlobal('KENOMA-TESTE');
  final e8 = loadEpochs().epochs.firstWhere((e) => e.id == 8).climate!;
  const rx = 1514, ry = 2315; // Campinas

  /// O clima e o evento da janela que contém a hora LOCAL (Brasília, -3) [h] do dia.
  ClimateCause at(int y, int m, int d, int h, {List<ClimateEvent> events = const []}) => e8.resolve(seed: seed, tUtc: utc(y, m, d, h + 3), rx: rx, ry: ry, events: events);

  group('datas móveis', () {
    test('Páscoa (Meeus/Jones/Butcher) contra as datas conhecidas', () {
      const known = {2024: (3, 31), 2025: (4, 20), 2026: (4, 5), 2027: (3, 28), 2028: (4, 16), 2029: (4, 1), 2030: (4, 21), 2038: (4, 25), 2285: (3, 22)};
      for (final e in known.entries) {
        expect(easterSunday(e.key), DateTime.utc(e.key, e.value.$1, e.value.$2), reason: '${e.key}');
      }
    });

    test('equinócios e solstícios (Meeus, cap. 27) a menos de 3 min dos publicados (USNO)', () {
      final known = {
        (2024, SeasonPoint.marchEquinox): utc(2024, 3, 20, 3, 6),
        (2024, SeasonPoint.juneSolstice): utc(2024, 6, 20, 20, 51),
        (2024, SeasonPoint.septemberEquinox): utc(2024, 9, 22, 12, 44),
        (2024, SeasonPoint.decemberSolstice): utc(2024, 12, 21, 9, 20),
        (2025, SeasonPoint.marchEquinox): utc(2025, 3, 20, 9, 1),
        (2025, SeasonPoint.juneSolstice): utc(2025, 6, 21, 2, 42),
        (2025, SeasonPoint.septemberEquinox): utc(2025, 9, 22, 18, 19),
        (2025, SeasonPoint.decemberSolstice): utc(2025, 12, 21, 15, 3),
        (2026, SeasonPoint.marchEquinox): utc(2026, 3, 20, 14, 46),
        (2026, SeasonPoint.juneSolstice): utc(2026, 6, 21, 8, 24),
        (2026, SeasonPoint.septemberEquinox): utc(2026, 9, 23, 0, 5),
        (2026, SeasonPoint.decemberSolstice): utc(2026, 12, 21, 20, 50),
      };
      for (final e in known.entries) {
        expect((seasonInstantUtc(e.key.$1, e.key.$2) - e.value).abs(), lessThan(180), reason: '${e.key}');
      }
    });

    test('o Carnaval é segunda e terça 48 e 47 dias antes da Páscoa, e Cinzas é a quarta seguinte', () {
      // 2031: Páscoa em 13 de abril, Carnaval em 24 e 25 de fevereiro, Cinzas em 26.
      expect(easterSunday(2031), DateTime.utc(2031, 4, 13));
      expect(at(2031, 2, 24, 10).climate, 'prismatic_drizzle');
      expect(at(2031, 2, 25, 22).event, 'carnaval');
      expect(at(2031, 2, 26, 10).climate, 'veil_ash');
      expect(at(2031, 2, 23, 10).event, isNot('carnaval'));
      expect(at(2031, 2, 27, 10).event, isNot('cinzas'));
    });

    test('a Noite das Runas cai na data LOCAL do equinócio, só à noite', () {
      // Equinócio de setembro de 2030 às 23h27 UTC do dia 22: em Brasília ainda é dia 22.
      final eq = seasonInstantUtc(2030, SeasonPoint.septemberEquinox);
      expect(DateTime.fromMillisecondsSinceEpoch((eq - 3 * 3600) * 1000, isUtc: true).day, 22);
      expect(at(2030, 9, 22, 19).climate, 'rune_rain');
      expect(at(2030, 9, 22, 22).event, 'runas_setembro');
      expect(at(2030, 9, 22, 10).event, isNot('runas_setembro'), reason: 'de dia, não');
      expect(at(2030, 9, 23, 19).event, isNot('runas_setembro'));
      // Solstício de inverno do sul (junho): Neve do Véu à noite.
      final sol = DateTime.fromMillisecondsSinceEpoch((seasonInstantUtc(2030, SeasonPoint.juneSolstice) - 3 * 3600) * 1000, isUtc: true);
      expect(at(2030, 6, sol.day, 20).climate, 'veil_snow');
    });

    test('sexta-feira 13 traz a Vigília; 14 de julho, a Maré do Véu; 31 de outubro à noite, o Silêncio', () {
      expect(DateTime.utc(2030, 9, 13).weekday, DateTime.friday);
      expect(at(2030, 9, 13, 10).climate, 'vigil');
      expect(at(2030, 9, 14, 10).event, isNot('sexta_dos_olhos'));
      expect(at(2031, 7, 14, 15).climate, 'veil_tide');
      expect(at(2030, 10, 31, 20).climate, 'silence');
      expect(at(2030, 10, 31, 10).event, isNot('noite_calada'));
      expect(at(2031, 1, 1, 0).climate, 'spark_rain');
      expect(at(2031, 4, 1, 12).climate, 'inverted_sky');
    });
  });

  test('todo clima de outra região e todo místico aparece ao menos uma vez por ano, para várias seeds', () {
    // Ficam de fora os presos a um evento que não tem data: eclipse (Sol Negro, Chuva Carmim), Fenda (Vento das Fendas,
    // Tempestade de Ecos) e a lua cheia no perigeu (Lua Dupla). Estão no GDD só por evento, não no calendário do Véu.
    const eventOnly = {'black_sun', 'crimson_rain', 'rift_wind', 'echo_storm', 'double_moon'};
    final want = {for (final d in e8.defs.values) if (d.category != ClimateCategory.native && !eventOnly.contains(d.id)) d.id};
    expect(want, hasLength(22));
    for (final s in [seed, seedGlobal('OUTRA-SEED'), seedGlobal('TERCEIRA')]) {
      for (final year in [2030, 2031, 2033]) {
        final seen = <String>{};
        for (var w = utc(year, 1, 1, 3) ~/ e8.windowS; w < utc(year + 1, 1, 1, 3) ~/ e8.windowS; w++) {
          final c = e8.resolve(seed: s, tUtc: w * e8.windowS, rx: rx, ry: ry);
          if (c.source == ClimateSource.calendar) seen.add(c.climate);
        }
        expect(want.difference(seen), isEmpty, reason: 'ano $year');
      }
    }
  });

  test('os períodos escolhem dias diferentes a cada ano, iguais em dois aparelhos', () {
    Set<String> days(int year, int s) => {
          for (var d = DateTime.utc(year, 7); d.month == 7; d = d.add(const Duration(days: 1)))
            if (e8.resolve(seed: s, tUtc: utc(year, 7, d.day, 15), rx: rx, ry: ry).event == 'inverno_do_veu') '${d.day}',
        };
    expect(days(2030, seed), hasLength(4));
    expect(days(2030, seed), isNot(days(2031, seed)));
    final other = loadEpochs().epochs.firstWhere((e) => e.id == 8).climate!; // outro aparelho, lido do zero
    expect({for (var d = 1; d <= 31; d++) other.resolve(seed: seed, tUtc: utc(2030, 7, d, 15), rx: rx, ry: ry).climate}, {for (var d = 1; d <= 31; d++) e8.resolve(seed: seed, tUtc: utc(2030, 7, d, 15), rx: rx, ry: ry).climate});
    // A Semana da Fuligem são sete dias seguidos de maio.
    final fuligem = [for (var d = 1; d <= 31; d++) if (e8.resolve(seed: seed, tUtc: utc(2030, 5, d, 15), rx: rx, ry: ry).event == 'semana_fuligem') d];
    expect(fuligem, hasLength(7));
    expect(fuligem.last - fuligem.first, 6);
  });

  test('o feed desliga um evento do calendário (calendar_skip) e manda outro clima no lugar', () {
    final skip = ClimateEvent.tryParse({'kind': 'calendar_skip', 'event': 'mare_da_cidade', 'starts_utc': '2031-07-14T00:00:00Z', 'ends_utc': '2031-07-16T00:00:00Z'})!;
    expect(skip.skipsCalendar, isTrue);
    expect(at(2031, 7, 14, 15, events: [skip]).event, isNot('mare_da_cidade'));
    final moved = ClimateEvent.tryParse({'kind': 'climate', 'climate': 'veil_tide', 'event': 'mare_da_cidade', 'starts_utc': '2031-07-15T03:00:00Z', 'ends_utc': '2031-07-16T03:00:00Z'})!;
    expect(at(2031, 7, 15, 15, events: [skip, moved]).climate, 'veil_tide');
  });

  test('o app Céu acha o próximo evento do calendário, sem repetir o que já está valendo', () {
    final n = e8.nextCalendar(seed, utc(2030, 10, 1, 12))!;
    expect(n.rule.id, isNot('finados'));
    final first = DateTime.fromMillisecondsSinceEpoch(n.startUtc * 1000, isUtc: true);
    expect(first.isAfter(DateTime.utc(2030, 10, 1, 12)), isTrue);
    expect(e8.resolve(seed: seed, tUtc: n.startUtc, rx: rx, ry: ry).event, n.rule.id);
    // Durante a Maré da Cidade, o próximo não é ela mesma.
    expect(e8.nextCalendar(seed, utc(2031, 7, 14, 18))!.rule.id, isNot('mare_da_cidade'));
  });
}
