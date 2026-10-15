import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/progression.dart';
import 'package:kenoma/story/notification_plan.dart';

import '../support/fixtures.dart';

void main() {
  final b = loadProgressBalance();
  const brt = Duration(hours: -3); // Brasília, para o teste não depender do fuso da máquina
  int utc(String iso) => DateTime.parse(iso).millisecondsSinceEpoch ~/ 1000;

  PlayerProgress progress({int rest = 350, int? restDay}) => PlayerProgress(balance: b, restBalance: rest, restDay: restDay);

  List<PlannedNotification> plan(int now, PlayerProgress p, {bool enabled = true}) =>
      planNotifications(enabled: enabled, nowUtc: now, progress: p, balance: b, offset: brt);

  test('desligadas (o padrão): nenhum aviso', () {
    expect(plan(utc('2026-10-16T15:00:00Z'), progress(), enabled: false), isEmpty);
  });

  test('diárias renovadas: 9 h do próximo dia local, quando os pedidos mudam', () {
    final now = utc('2026-10-16T15:00:00Z'); // 12:00 de 16/10 em Brasília
    final n = plan(now, progress(rest: 1050)).singleWhere((x) => x.id == notifyDailyId);
    expect(n.atUtc, utc('2026-10-17T12:00:00Z'), reason: '09:00 de 17/10 em Brasília = 12:00 UTC');
    expect(n.atUtc, greaterThan(now));
  });

  test('perto da meia-noite local o aviso é o do dia que vem, não o de agora', () {
    final now = utc('2026-10-17T02:30:00Z'); // 23:30 de 16/10 em Brasília
    final n = plan(now, progress(rest: 1050)).singleWhere((x) => x.id == notifyDailyId);
    expect(n.atUtc, utc('2026-10-17T12:00:00Z'), reason: 'amanhã às 9 h locais, em 9 h e 30 min');
  });

  test('descanso cheio: avisa no dia em que o saldo (350 por dia, até 1050) enche', () {
    final now = utc('2026-10-16T15:00:00Z');
    final today = localDay(now, offset: brt);
    final n = plan(now, progress(rest: 350, restDay: today)).singleWhere((x) => x.id == notifyRestId);
    expect(n.atUtc, utc('2026-10-18T12:00:00Z'), reason: '350 → 700 → 1050: cheio daqui a 2 dias, 9 h locais');
    final one = plan(now, progress(rest: 700, restDay: today)).singleWhere((x) => x.id == notifyRestId);
    expect(one.atUtc, utc('2026-10-17T12:00:00Z'));
  });

  test('os dias que passaram sem abrir o app já entram na conta', () {
    final now = utc('2026-10-16T15:00:00Z');
    final today = localDay(now, offset: brt);
    // O saldo foi gravado há 1 dia com 350: hoje já vale 700, então enche amanhã.
    final n = plan(now, progress(rest: 350, restDay: today - 1)).singleWhere((x) => x.id == notifyRestId);
    expect(n.atUtc, utc('2026-10-17T12:00:00Z'));
    expect(restToday(progress(rest: 350, restDay: today - 1), today), 700);
    expect(restToday(progress(rest: 350, restDay: today - 30), today), 1050, reason: 'o teto vale');
  });

  test('descanso já cheio ou sem registro de dia: sem aviso de descanso (o de diárias continua)', () {
    final now = utc('2026-10-16T15:00:00Z');
    final today = localDay(now, offset: brt);
    expect(plan(now, progress(rest: 1050, restDay: today)).map((x) => x.id), [notifyDailyId]);
    expect(plan(now, progress(rest: 350, restDay: today - 10)).map((x) => x.id), [notifyDailyId]);
    expect(plan(now, progress(rest: 350)).map((x) => x.id), contains(notifyRestId), reason: 'sem dia registrado vale o saldo guardado');
  });

  test('nenhum aviso no passado', () {
    final now = utc('2026-10-16T23:59:00Z');
    for (final n in plan(now, progress(rest: 0, restDay: localDay(now, offset: brt)))) {
      expect(n.atUtc, greaterThan(now));
    }
  });

  test('sem o offset de teste usa o fuso do aparelho e dá um instante no futuro', () {
    final now = utc('2026-10-16T15:00:00Z');
    final n = planNotifications(enabled: true, nowUtc: now, progress: progress(rest: 350, restDay: localDay(now)), balance: b);
    expect(n, isNotEmpty);
    for (final x in n) {
      expect(x.atUtc, greaterThan(now));
      expect(x.atUtc - now, lessThan(4 * 86400));
    }
  });
}
