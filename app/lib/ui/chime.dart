/// O som curto do aparecimento de um Eco Brilhante. No Android sai do gerador de tons do sistema (ver `MainActivity`).
/// Sem o canal (testes, outras plataformas) não faz nada.
library;

import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('kenoma/sound');

Future<void> playChime() async {
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
  try {
    await _channel.invokeMethod<void>('thunder', {'volume': (100 - distanceM / 12).clamp(20, 100).round()});
  } catch (_) {
    // sem som: o clarão basta
  }
}
