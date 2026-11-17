/// 0.23.1: tela cheia. O jogo roda em modo imersivo "sticky" (sem a barra de status e a de navegação do Android: elas voltam
/// com um deslize da borda e somem de novo sozinhas), no mapa, na sintonia e no celular do jogo. Ajustes, "Barras do
/// Android", desliga para quem prefere as barras. O HUD continua dentro do recorte da câmera (`MediaQuery.padding`).
library;

import 'package:flutter/services.dart';

/// Chave em `GameState.settings`: `true` mostra as barras do Android (o padrão, `false`, é a tela cheia).
const kSystemBarsSetting = 'system_bars';

Future<void> applySystemBars({required bool show}) async {
  try {
    await SystemChrome.setEnabledSystemUIMode(show ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky);
  } catch (_) {
    // Sem plataforma (testes): nada a fazer.
  }
}
