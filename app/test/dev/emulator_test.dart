import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/dev/emulator.dart';

import '../support/fake_position_source.dart';

/// GDD rev 353, Salvaguardas: o emulador conta como GPS simulado.
void main() {
  test('a regra: simulador ou emulador sem o interruptor não dá recompensa; com ele, dá; a Simulação de clima nunca dá', () {
    for (final (simulator, emulator, rewards, climateSim, sandbox) in [
      (false, false, false, false, false), // celular, GPS de verdade
      (false, true, false, false, true), // emulador
      (false, true, true, false, false), // emulador com o interruptor ligado
      (true, false, false, false, true), // simulador
      (true, true, true, false, false),
      (false, false, true, true, true), // Simulação de clima
    ]) {
      expect(sandboxFor(simulator: simulator, emulator: emulator, rewards: rewards, climateSim: climateSim), sandbox, reason: '$simulator $emulator $rewards $climateSim');
    }
  });

  test('no DevTools: o emulador detectado deixa a localização sem recompensa, até ligar o interruptor', () async {
    final tools = DevTools(realSource: FakeGps());
    expect(tools.sandboxed, isFalse, reason: 'aparelho de verdade, GPS de verdade');
    await tools.detect();
    expect(tools.emulator, isFalse, reason: 'nos testes não há plataforma Android: conta como aparelho de verdade');
    tools.setEmulator(true);
    expect((tools.useSimulator, tools.sandboxed), (false, true), reason: 'emulador sem o simulador: ainda sem recompensa');
    tools.setSimRewards(true);
    expect(tools.sandboxed, isFalse);
  });
}
