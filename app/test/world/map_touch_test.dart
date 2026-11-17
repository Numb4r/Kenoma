import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/world/map_touch.dart';

import '../support/fixtures.dart';

/// As regras do mapa que responde ao toque (0.24.2): alcance e a pé, limite por dia e por objeto, o ônibus e a manchete
/// iguais para amigos.
void main() {
  final b = TouchBalance.fromJson(loadJson('assets/data/balance.json')['map_touch'] as Map<String, dynamic>);
  final templates = loadJson('assets/data/mapa.json')['news'] as Map<String, dynamic>;

  test('tocar só a até 30 m e a pé', () {
    expect(b.touchM, 30);
    expect(canTouch(29, 1.2, 2.2, b), isTrue);
    expect(canTouch(31, 1.2, 2.2, b), isFalse, reason: 'longe');
    expect(canTouch(10, 9, 2.2, b), isFalse, reason: 'de carro');
  });

  test('cada interação respeita o limite do dia; a árvore dá uma vez por dia; o dia seguinte zera', () {
    final s = TouchState();
    for (final k in [TouchKind.flock, TouchKind.tree, TouchKind.cat, TouchKind.puddle, TouchKind.lamp]) {
      final limit = b.perDay(k)!;
      for (var i = 0; i < limit; i++) {
        expect(s.canReward(k, 100, b, objectKey: '$i'), isTrue, reason: '$k $i');
        s.reward(k, 100, objectKey: '$i');
      }
      expect(s.canReward(k, 100, b, objectKey: 'outro'), isFalse, reason: '$k no limite');
    }
    final t = TouchState();
    t.reward(TouchKind.tree, 100, objectKey: 'ipê');
    expect(t.canReward(TouchKind.tree, 100, b, objectKey: 'ipê'), isFalse, reason: 'a mesma árvore, no mesmo dia');
    expect(t.canReward(TouchKind.tree, 101, b, objectKey: 'ipê'), isTrue, reason: 'no dia seguinte, de novo');
    expect(b.perDay(TouchKind.busStop), isNull, reason: 'só informação: sem limite');
    expect(TouchState.fromJson(s.toJson()).toJson(), s.toJson());
  });

  test('o Ônibus Espectral passa no mesmo horário para todo o grupo, no intervalo do balance', () {
    int hour(int t) => ((t ~/ 3600) - 3) % 24;
    final a = spectralBusNext(seed: 42, stopKey: placeKey(100.5, 200.25), t: 1795446000, b: b, localHourOf: hour);
    final c = spectralBusNext(seed: 42, stopKey: placeKey(100.5, 200.25), t: 1795446000, b: b, localHourOf: hour);
    expect(a, c);
    expect(a.utc, greaterThanOrEqualTo(1795446000));
    expect(a.utc - 1795446000, lessThanOrEqualTo(b.busEveryMin.$2 * 60));
    final next = spectralBusNext(seed: 42, stopKey: placeKey(100.5, 200.25), t: a.utc + 1, b: b, localHourOf: hour);
    expect(next.utc - a.utc, inInclusiveRange(b.busEveryMin.$1 * 60, b.busEveryMin.$2 * 60));
  });

  test('a manchete da banca é igual para dois aparelhos no mesmo dia e muda de um dia para outro', () {
    Headline? on(int day) => veilHeadline(seed: 7, epochId: 12, day: day, standKey: placeKey(55, 66), climate: 'Chuva', templates: templates, family: 'Soot', event: (name: 'Noite Branca', days: 3));
    expect(on(20400), on(20400), reason: 'mesma seed, dia e banca: a mesma manchete');
    expect({for (var d = 20400; d < 20410; d++) on(d)!.title}.length, greaterThan(1), reason: 'muda com o dia');
    final h = on(20400)!;
    expect(h.title.contains('{'), isFalse, reason: 'lacunas preenchidas');
    final onlyClimate = veilHeadline(seed: 7, epochId: 12, day: 20400, standKey: 1, climate: 'Garoa', templates: templates);
    expect([for (final m in templates['climate'] as List) (m as Map)['title']].any((t) => (t as String).replaceAll('{clima}', 'Garoa') == onlyClimate!.title), isTrue);
  });

  test('a manchete concorda o número de dias', () {
    final one = {
      for (var d = 20400; d < 20460; d++)
        veilHeadline(seed: 7, epochId: 12, day: d, standKey: 3, climate: 'Chuva', templates: templates, event: (name: 'Noite Branca', days: 1))!.title,
    };
    expect(one.any((t) => t.contains('1 dias') || t.contains('Faltam 1')), isFalse);
  });

  test('o sorteio pessoal é estável para o mesmo jogador, dia e objeto', () {
    expect(personalRoll(9, 100, 'flock:1', 0), personalRoll(9, 100, 'flock:1', 0));
    expect(personalRoll(9, 100, 'flock:1', 0), isNot(personalRoll(10, 100, 'flock:1', 0)));
  });
}
