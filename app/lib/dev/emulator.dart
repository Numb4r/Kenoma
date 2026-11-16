/// O emulador conta como GPS simulado (GDD, Salvaguardas): a localização dele não dá recompensa, a menos que o interruptor
/// de recompensas do debug esteja ligado. Detectado pelo `isPhysicalDevice` do Android.
library;

import 'package:device_info_plus/device_info_plus.dart';

/// O aparelho é um emulador. Sem conseguir ler (testes, outra plataforma): aparelho de verdade.
Future<bool> detectEmulator() async {
  try {
    return !(await DeviceInfoPlugin().androidInfo).isPhysicalDevice;
  } catch (_) {
    return false;
  }
}

/// O que se pega não conta (XP, Bolsa, estatística, bestiário): com o simulador ligado ou no emulador, salvo o interruptor
/// de recompensas; e sempre na Simulação de clima.
bool sandboxFor({required bool simulator, required bool emulator, required bool rewards, bool climateSim = false}) =>
    ((simulator || emulator) && !rewards) || climateSim;
