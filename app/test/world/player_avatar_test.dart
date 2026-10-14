import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/world/player_avatar.dart';

/// Metros por célula z21 em Campinas.
const mpc = 17.6;
const dt = 1 / 60;

/// Roda [seconds] de quadros a 60 Hz e devolve o maior passo de um quadro (em metros).
double run(PlayerAvatar a, double seconds, {void Function(double t)? each}) {
  var biggest = 0.0;
  var t = 0.0;
  while (t < seconds - 1e-9) {
    final x0 = a.x, y0 = a.y;
    a.update(dt);
    t += dt;
    biggest = math.max(biggest, math.sqrt(math.pow(a.x - x0, 2) + math.pow(a.y - y0, 2)) * mpc);
    each?.call(t);
  }
  return biggest;
}

/// Uma caminhada para o leste a [mps], com uma leitura por segundo. Devolve a posição verdadeira em células.
double walkEast(PlayerAvatar a, double mps, double seconds, {double startX = 1000}) {
  var x = startX;
  run(a, 1); // a primeira leitura chegou um segundo antes da seguinte, como no GPS de verdade
  for (var s = 0; s < seconds; s++) {
    x += mps / mpc;
    a.setTarget(x, 500, metersPerCell: mpc);
    run(a, 1);
  }
  return x;
}

void main() {
  group('interpolador do Conjurador', () {
    test('a primeira posição aparece direto, sem deslizar de lugar nenhum', () {
      final a = PlayerAvatar();
      expect(a.hasPosition, isFalse);
      a.setTarget(100, 200, metersPerCell: mpc);
      expect((a.x, a.y, a.hasPosition, a.moving), (100.0, 200.0, true, false));
    });

    test('nunca pula: andando a 1,4 m/s, nenhum quadro passa de 1,4 m/s vezes o quadro, com folga', () {
      final a = PlayerAvatar()..setTarget(1000, 500, metersPerCell: mpc);
      run(a, 1);
      var biggest = 0.0;
      var x = 1000.0;
      for (var s = 0; s < 30; s++) {
        x += 1.4 / mpc;
        a.setTarget(x, 500, metersPerCell: mpc);
        biggest = math.max(biggest, run(a, 1));
      }
      expect(biggest, lessThan(1.4 * dt * 1.6), reason: 'o marcador anda na velocidade do jogador, sem arrancos');
      expect(biggest, greaterThan(0));
    });

    test('depois de uma leitura nova o marcador chega nela em cerca de 1 s, sem passar dela', () {
      final a = PlayerAvatar()..setTarget(1000, 500, metersPerCell: mpc);
      run(a, 2);
      a.setTarget(1000 + 10 / mpc, 500, metersPerCell: mpc); // 10 m para o leste
      final goal = 1000 + 10 / mpc;
      var arrivedAt = -1.0;
      var maxX = 0.0;
      run(a, 3, each: (t) {
        maxX = math.max(maxX, a.x);
        if (arrivedAt < 0 && (goal - a.x) * mpc < 0.5) arrivedAt = t;
      });
      expect(arrivedAt, inInclusiveRange(0.9, 1.6));
      expect(maxX, lessThanOrEqualTo(goal + 1e-9), reason: 'nunca passa da última leitura');
      expect((goal - a.x) * mpc, lessThan(0.01));
    });

    test('parado, o marcador não se mexe e não conta como andando', () {
      final a = PlayerAvatar()..setTarget(1000, 500, metersPerCell: mpc);
      for (var s = 0; s < 10; s++) {
        a.setTarget(1000 + 0.05 / mpc * (s.isEven ? 1 : -1), 500, metersPerCell: mpc); // tremor de 5 cm
        run(a, 1);
      }
      expect(a.moving, isFalse);
      expect(a.speedMps, lessThan(0.35));
    });

    test('andando conta como andando (com histerese) e depois de parar volta a parado', () {
      final a = PlayerAvatar()..setTarget(1000, 500, metersPerCell: mpc);
      walkEast(a, 1.4, 6);
      expect(a.moving, isTrue);
      expect(a.speedMps, closeTo(1.4, 0.25));
      expect(a.velocityX, greaterThan(0), reason: 'indo para o leste');
      run(a, 4); // o GPS para de trazer leituras novas
      expect(a.moving, isFalse);
      expect(a.speedMps, lessThan(0.15));
    });

    test('quando o GPS para o marcador desacelera até a última leitura e para: não passa, não continua andando', () {
      final a = PlayerAvatar()..setTarget(1000, 500, metersPerCell: mpc);
      final last = walkEast(a, 2.0, 8);
      var maxX = 0.0;
      final xs = <double>[];
      run(a, 5, each: (_) {
        maxX = math.max(maxX, a.x);
        xs.add(a.x);
      });
      expect(maxX, lessThanOrEqualTo(last + 1e-9), reason: 'sem extrapolar além da última leitura');
      expect((last - a.x) * mpc, lessThan(0.05), reason: 'chegou na última leitura');
      // E parou: nos últimos 2 s nada mexe.
      final tail = xs.sublist(xs.length - 120);
      expect((tail.reduce(math.max) - tail.reduce(math.min)) * mpc, lessThan(0.01));
    });

    test('a desaceleração é suave: a velocidade cai sem degrau quando o GPS para', () {
      final a = PlayerAvatar()..setTarget(1000, 500, metersPerCell: mpc);
      walkEast(a, 3.0, 8);
      var prev = a.x;
      var prevStep = double.infinity;
      var worstDrop = 0.0;
      run(a, 3, each: (_) {
        final step = (a.x - prev) * mpc;
        prev = a.x;
        if (prevStep.isFinite) worstDrop = math.max(worstDrop, prevStep - step);
        prevStep = step;
      });
      expect(worstDrop, lessThan(3.0 * dt * 0.2), reason: 'de um quadro para o outro a velocidade perde pouco');
    });

    test('descarta leituras que exigiriam mais de 12 m/s desde a última: um pico de 300 m não move o marcador', () {
      final a = PlayerAvatar()..setTarget(1000, 500, metersPerCell: mpc);
      walkEast(a, 1.4, 4);
      final before = (a.x, a.y);
      final latest = a.latest;
      a.setTarget(1000 + 300 / mpc, 500, metersPerCell: mpc); // 300 m em ~0 s: erro do GPS
      expect(a.discarded, 1);
      expect(a.latest, latest, reason: 'a leitura não entrou no caminho');
      run(a, 3);
      expect(a.x, greaterThan(before.$1 - 1e-9));
      expect((a.x - before.$1) * mpc, lessThan(6), reason: 'continua onde o caminho bom o leva, longe dos 300 m');
    });

    test('12 m/s é o limite: 11 m/s passa, 13 m/s não', () {
      final ok = PlayerAvatar()..setTarget(1000, 500, metersPerCell: mpc);
      run(ok, 5);
      ok.setTarget(1000 + 11 * 5 / mpc, 500, metersPerCell: mpc);
      expect(ok.discarded, 0);
      final bad = PlayerAvatar()..setTarget(1000, 500, metersPerCell: mpc);
      run(bad, 5);
      bad.setTarget(1000 + 13 * 5 / mpc, 500, metersPerCell: mpc);
      expect(bad.discarded, 1);
    });

    test('depois de um tempo sem leituras, uma posição mais longe é plausível (o app voltou do segundo plano)', () {
      final a = PlayerAvatar()..setTarget(1000, 500, metersPerCell: mpc);
      run(a, 60);
      a.setTarget(1000 + 400 / mpc, 500, metersPerCell: mpc); // 400 m em 60 s = 6,7 m/s
      expect(a.discarded, 0);
      run(a, 3);
      expect((1000 + 400 / mpc - a.x) * mpc, lessThan(1));
    });

    test('um único erro não atrapalha: a leitura boa seguinte é aceita', () {
      final a = PlayerAvatar()..setTarget(1000, 500, metersPerCell: mpc);
      run(a, 1);
      a.setTarget(5000, 9000, metersPerCell: mpc); // erro
      run(a, 1);
      a.setTarget(1000 + 1.4 / mpc, 500, metersPerCell: mpc); // boa, perto da anterior
      expect(a.discarded, 1);
      run(a, 3);
      expect(a.x, closeTo(1000 + 1.4 / mpc, 1e-3));
    });

    test('leituras impossíveis, seguidas e juntas, mostram que o jogador mudou de lugar: o marcador reaparece lá', () {
      final a = PlayerAvatar()..setTarget(1000, 500, metersPerCell: mpc);
      run(a, 1);
      a.setTarget(9000, 4000, metersPerCell: mpc); // outro bairro: a primeira, sozinha, é descartada
      expect(a.x, closeTo(1000, 1e-9));
      run(a, 1);
      a.setTarget(9000.1, 4000, metersPerCell: mpc); // a segunda confirma
      expect(a.x, closeTo(9000.1, 1e-9), reason: 'ao confirmar, aparece direto, sem cruzar o mapa');
      expect(a.y, 4000.0);
      expect(a.moving, isFalse);
    });

    test('o tempo do GPS manda: 30 leituras que chegam juntas, 1 s uma da outra, são uma caminhada válida', () {
      final a = PlayerAvatar()..setTarget(1000, 500, metersPerCell: mpc, timeMs: 0);
      for (var s = 1; s <= 30; s++) {
        a.setTarget(1000 + s * 6.0 / mpc, 500, metersPerCell: mpc, timeMs: s * 1000); // 6 m/s, de bicicleta
      }
      expect(a.discarded, 0);
      run(a, 20);
      expect((1000 + 30 * 6.0 / mpc - a.x) * mpc, lessThan(1));
    });

    test('leituras impossíveis em lugares diferentes não se confirmam: cada uma é um erro', () {
      final a = PlayerAvatar()..setTarget(1000, 500, metersPerCell: mpc);
      run(a, 1);
      a.setTarget(9000, 4000, metersPerCell: mpc);
      a.setTarget(2000, 8000, metersPerCell: mpc);
      a.setTarget(7000, 100, metersPerCell: mpc);
      expect(a.discarded, 3);
      run(a, 1);
      expect(a.x, closeTo(1000, 1e-6));
    });

    test('sem posição não anda; passo de tempo nulo não faz nada; clear esquece tudo', () {
      final a = PlayerAvatar();
      a.update(1);
      expect(a.hasPosition, isFalse);
      a.setTarget(5, 5, metersPerCell: mpc);
      a.update(0);
      expect((a.x, a.y), (5.0, 5.0));
      a.clear();
      expect(a.hasPosition, isFalse);
      a.setTarget(7, 7, metersPerCell: mpc);
      expect((a.x, a.y), (7.0, 7.0));
    });
  });
}
