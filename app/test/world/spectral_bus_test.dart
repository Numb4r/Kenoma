import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/world/map_touch.dart';
import 'package:kenoma/world/spectral_bus.dart';

import '../support/fixtures.dart';

/// 0.24.5: o Ônibus Espectral passa de verdade no horário de cada ponto, igual para o grupo.
void main() {
  final b = TouchBalance.fromJson(loadJson('assets/data/balance.json')['map_touch'] as Map<String, dynamic>);
  const seed = 0x1234abcd, stop = 987654321, t0 = 1795800000;

  test('chega no minuto que o painel do ponto mostra, para, e some depois de sair', () {
    final a = spectralBusNext(seed: seed, stopKey: stop, t: t0, b: b, localHourOf: (_) => 12).utc;
    expect(spectralBusAt(seed: seed, stopKey: stop, t: a - b.busApproachS - 1, b: b), isNull);
    final arriving = spectralBusAt(seed: seed, stopKey: stop, t: a - b.busApproachS / 2, b: b)!;
    expect(arriving.phase, SpectralPhase.arriving);
    expect(arriving.alongM, lessThan(0));
    final at = spectralBusAt(seed: seed, stopKey: stop, t: a.toDouble(), b: b)!;
    expect((at.arriveUtc, at.phase, at.alongM), (a, SpectralPhase.stopped, 0.0));
    expect(spectralBusAt(seed: seed, stopKey: stop, t: a + b.busDwellS + b.busLeaveS / 2, b: b)!.phase, SpectralPhase.leaving);
    expect(spectralBusAt(seed: seed, stopKey: stop, t: a + b.busDwellS + b.busLeaveS + 1, b: b), isNull);
  });

  test('dois aparelhos com a mesma seed veem o mesmo ônibus no mesmo ponto e instante; outra seed, outro horário', () {
    String trace(int s) => [
          for (var t = t0.toDouble(); t < t0 + 3 * 3600; t += 7.5)
            if (spectralBusAt(seed: s, stopKey: stop, t: t, b: b) case final p?) '${p.arriveUtc}:${p.phase.name}:${p.alongM.toStringAsFixed(3)}:${p.rider.name}',
        ].join('|');
    final a = trace(seed);
    expect(a, isNotEmpty);
    expect(trace(seed), a, reason: 'o segundo aparelho');
    expect(trace(seed + 1), isNot(a));
  });

  test('o passageiro desce e some na calçada, ou aparece nela e embarca', () {
    expect(spectralRiderAt(SpectralRider.alights, 0, b), isNull, reason: 'a porta ainda não abriu');
    expect(spectralRiderAt(SpectralRider.alights, 2, b)!.alpha, 1);
    expect(spectralRiderAt(SpectralRider.alights, 7, b), isNull, reason: 'sumiu na calçada');
    expect(spectralRiderAt(SpectralRider.boards, -3, b)!.t, 1, reason: 'na calçada');
    expect(spectralRiderAt(SpectralRider.boards, 2.5, b)!.alpha, 0, reason: 'entrou');
  });
}
