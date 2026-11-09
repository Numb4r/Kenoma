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

/// O trovão de um raio a [distanceM] metros: chega com o atraso do som (343 m/s) e mais fraco de longe. Sai do gerador de
/// tons do sistema, sem arquivo de áudio (`MainActivity`, método `thunder`).
Future<void> playThunder(double distanceM) async {
  await Future<void>.delayed(Duration(milliseconds: (distanceM / 343 * 1000).round()));
  try {
    await _channel.invokeMethod<void>('thunder', {'volume': (100 - distanceM / 12).clamp(20, 100).round()});
  } catch (_) {
    // sem som: o clarão basta
  }
}
