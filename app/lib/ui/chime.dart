/// O som curto do aparecimento de um Eco Brilhante. No Android sai do gerador de tons do sistema (ver `MainActivity`).
/// Sem o canal (testes, outras plataformas) não faz nada.
library;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('kenoma/sound');

/// O volume geral dos efeitos e da música, de 0 a 1. **Zero até a sonoplastia começar** (0.20.0): os sons de teste
/// saíram, o sistema de áudio fica aqui pronto, sem arquivo de som no APK. Com zero, nada chega ao canal.
const double kSoundVolume = 0;

/// O ajuste "Sons" do save (o interruptor saiu dos Ajustes na 0.20.0 e volta com a sonoplastia).
const String kSoundSetting = 'sound';
final ValueNotifier<bool> soundOn = ValueNotifier<bool>(true);

Future<void> playChime() async {
  if (!soundOn.value || kSoundVolume <= 0) return;
  try {
    await _channel.invokeMethod<void>('chime');
  } catch (_) {
    // sem som: o aviso na tela basta
  }
}

/// Quanto o trovão de um raio a [distanceM] metros demora a chegar: a velocidade do som, 343 m/s.
Duration thunderDelay(double distanceM) => Duration(milliseconds: (distanceM / 343 * 1000).round());

/// O trovão de um raio a [distanceM] metros, mais fraco de longe (quem chama espera [thunderDelay] antes). Sai do gerador
/// de tons do sistema, sem arquivo de áudio (`MainActivity`, método `thunder`).
Future<void> playThunder(double distanceM) async {
  if (!soundOn.value || kSoundVolume <= 0) return;
  try {
    await _channel.invokeMethod<void>('thunder', {'volume': ((100 - distanceM / 12).clamp(20, 100) * kSoundVolume).round()});
  } catch (_) {
    // sem som: o clarão basta
  }
}
