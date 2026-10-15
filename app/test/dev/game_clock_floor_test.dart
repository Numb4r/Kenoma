import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/dev/game_clock.dart';

void main() {
  test('se o relógio do aparelho volta para antes do last_seen_utc, o jogo usa o last_seen_utc', () {
    var real = 2000 * 1000;
    final c = GameClock(realNowMs: () => real)..raiseFloor(2000);
    real = 1000 * 1000; // o jogador atrasou o relógio
    expect(c.nowUtc, 2000);
    real = 2500 * 1000;
    expect(c.nowUtc, 2500, reason: 'passado o piso, volta a andar');
  });

  test('o piso só sobe', () {
    var real = 0;
    final c = GameClock(realNowMs: () => real)..raiseFloor(500)..raiseFloor(100);
    expect(c.nowUtc, 500);
  });

  test('o override do debug passa por cima do piso, e o relógio real não o vê', () {
    final c = GameClock(realNowMs: () => 1000 * 1000)..raiseFloor(5000);
    c.setUtc(100);
    expect(c.nowUtc, 100);
    expect(c.realNowUtc, 1000);
    c.clear();
    expect(c.nowUtc, 5000);
  });
}
