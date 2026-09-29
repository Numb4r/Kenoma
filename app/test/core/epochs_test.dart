import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/epochs.dart';

import '../support/fixtures.dart';

Map<String, dynamic> epochJson(int id, String starts, String until) => {
      'id': id,
      'starts_utc': starts,
      'valid_until_utc': until,
      'region_packs': <String, dynamic>{},
      'spawn': {'items': <dynamic>[]},
    };

int utc(String iso) => DateTime.parse(iso).millisecondsSinceEpoch ~/ 1000;

void main() {
  test('lê a época 0 de assets/data/epochs.json', () {
    final schedule = loadEpochs();
    final e0 = schedule.epochs.single;
    expect(e0.id, 0);
    expect(e0.startsUtc, utc('2026-09-22T00:00:00Z'));
    expect(e0.validUntilUtc, utc('2026-12-21T00:00:00Z'));
    expect(e0.regionPacks['campinas']!.file, 'campinas_e0.bin');
    expect(e0.regionPacks['campinas']!.sha256, hasLength(64));
    expect(e0.items.map((i) => i.index), [0, 1, 2, 3]);
    expect(e0.items.map((i) => i.kind), ['eco', 'spark', 'spark', 'material']);
    expect(e0.items[0].hasLevelDelta, isTrue);
    expect(e0.items[1].hasLevelDelta, isFalse);
  });

  test('toda tabela de spawn tem os quatro biomas e pesos positivos', () {
    for (final item in loadEpochs().epochs.single.items) {
      expect(item.chance.keys.toSet(), {'urban', 'green', 'water', 'residential'});
      expect(item.table.keys.toSet(), {'urban', 'green', 'water', 'residential'});
      for (final entries in item.table.values) {
        expect(entries, isNotEmpty);
        expect(entries.every((e) => e.weight > 0), isTrue);
      }
    }
  });

  test('época vigente: a de maior starts_utc que já passou', () {
    final schedule = EpochSchedule.fromJson({
      'format': 1,
      'epochs': [
        epochJson(0, '2026-09-22T00:00:00Z', '2026-12-21T00:00:00Z'),
        epochJson(2, '2027-03-22T00:00:00Z', '2027-06-21T00:00:00Z'),
        epochJson(1, '2026-12-21T00:00:00Z', '2027-03-22T00:00:00Z'),
      ],
    });
    expect(schedule.current(utc('2026-10-01T00:00:00Z'))!.id, 0);
    expect(schedule.current(utc('2026-12-21T00:00:00Z'))!.id, 1, reason: 'começa exatamente em starts_utc');
    expect(schedule.current(utc('2026-12-20T23:59:59Z'))!.id, 0);
    expect(schedule.current(utc('2028-01-01T00:00:00Z'))!.id, 2);
  });

  group('bordas da época 0 (spec, seção 3)', () {
    final schedule = loadEpochs();

    test('1790035199 não tem época vigente; o app usa a primeira e marca desatualizado', () {
      expect(schedule.current(1790035199), isNull);
      final s = schedule.select(1790035199);
      expect(s.epoch.id, 0);
      expect(s.stale, isTrue);
    });

    test('1790035200 é a época 0, em dia', () {
      expect(schedule.current(1790035200)!.id, 0);
      final s = schedule.select(1790035200);
      expect(s.epoch.id, 0);
      expect(s.stale, isFalse);
    });

    test('1797811200 já marca a época 0 como desatualizada, e segue gerando por ela', () {
      expect(schedule.current(1797811200)!.id, 0);
      final s = schedule.select(1797811200);
      expect(s.epoch.id, 0);
      expect(s.stale, isTrue);
    });

    test('um segundo antes do fim ainda está em dia', () {
      expect(schedule.select(1797811199).stale, isFalse);
    });

    test('bem depois do fim continua na época 0, desatualizada', () {
      final s = schedule.select(utc('2027-01-15T00:00:00Z'));
      expect((s.epoch.id, s.stale), (0, true));
    });

    test('as bordas batem com as datas de epochs.json', () {
      expect(utc('2026-09-22T00:00:00Z'), 1790035200);
      expect(utc('2026-12-21T00:00:00Z'), 1797811200);
      expect(schedule.epochs.single.startsUtc, 1790035200);
      expect(schedule.epochs.single.validUntilUtc, 1797811200);
    });
  });

  test('o instante dos vetores de hash é anterior à época 0', () {
    expect(vectorTime, 1790000000);
    expect(loadEpochs().current(vectorTime), isNull);
  });

  test('com várias épocas, antes da primeira usa a mais antiga', () {
    final schedule = EpochSchedule.fromJson({
      'format': 1,
      'epochs': [
        epochJson(1, '2026-12-21T00:00:00Z', '2027-03-22T00:00:00Z'),
        epochJson(0, '2026-09-22T00:00:00Z', '2026-12-21T00:00:00Z'),
      ],
    });
    expect(schedule.select(utc('2026-01-01T00:00:00Z')).epoch.id, 0);
    expect(schedule.select(utc('2026-01-01T00:00:00Z')).stale, isTrue);
    expect(schedule.select(utc('2026-12-21T00:00:00Z')).stale, isFalse, reason: 'a época 1 cobre');
  });

  test('datas de época são lidas em UTC', () {
    // 2026-09-22T00:00:00Z = 1790035200 s desde a época Unix.
    expect(loadEpochs().epochs.single.startsUtc, 1790035200);
  });
}
