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
