import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/dev/clock_input.dart';

void main() {
  test('lê data e hora em UTC, com espaço, T, segundos e Z opcionais', () {
    final want = DateTime.utc(2026, 12, 21, 3, 4, 5).millisecondsSinceEpoch ~/ 1000;
    for (final text in ['2026-12-21 03:04:05', '2026-12-21T03:04:05', '2026-12-21T03:04:05Z', ' 2026-12-21 03:04:05 ']) {
      expect(parseUtcInput(text), want, reason: text);
    }
    expect(parseUtcInput('2026-12-21 03:04'), DateTime.utc(2026, 12, 21, 3, 4).millisecondsSinceEpoch ~/ 1000);
    expect(parseUtcInput('2026-12-21'), DateTime.utc(2026, 12, 21).millisecondsSinceEpoch ~/ 1000, reason: 'só a data é meia-noite UTC');
  });

  test('o fim da época 0 (valid_until) e o começo (starts) se digitam como estão no epochs.json', () {
    expect(parseUtcInput('2026-12-21 00:00'), DateTime.utc(2026, 12, 21).millisecondsSinceEpoch ~/ 1000);
    expect(parseUtcInput('2026-09-22T00:00:00Z'), DateTime.utc(2026, 9, 22).millisecondsSinceEpoch ~/ 1000);
  });

  test('recusa o que não é data e hora válidas', () {
    for (final text in ['', 'amanhã', '2026-13-01', '2026-02-30', '2026-12-32', '2026-12-21 24:00', '2026-12-21 10:60', '21/12/2026', '2026-12-21 10', '2026-12-21 10:00:60']) {
      expect(parseUtcInput(text), isNull, reason: text);
    }
  });

  test('formatUtc é o inverso: ida e volta, sempre em UTC, mesmo com um DateTime local', () {
    final t = DateTime.utc(2027, 1, 15, 8, 1, 30);
    expect(formatUtc(t), '2027-01-15 08:01:30');
    expect(parseUtcInput(formatUtc(t)), t.millisecondsSinceEpoch ~/ 1000);
    expect(formatUtc(DateTime.utc(5, 1, 2)), '0005-01-02 00:00:00');
  });
}
