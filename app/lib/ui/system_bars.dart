/// 0.23.1: tela cheia. O jogo roda em modo imersivo "sticky" (sem a barra de status e a de navegação do Android: elas voltam
/// com um deslize da borda e somem de novo sozinhas), no mapa, na sintonia e no celular do jogo. Ajustes, "Barras do
/// Android", desliga para quem prefere as barras. O HUD continua dentro do recorte da câmera (`MediaQuery.padding`).
library;

import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Chave em `GameState.settings`: `true` mostra as barras do Android (o padrão, `false`, é a tela cheia).
const kSystemBarsSetting = 'system_bars';

/// Se as barras do Android estão à vista (o último [applySystemBars]).
bool systemBarsShown = false;

Future<void> applySystemBars({required bool show}) async {
  systemBarsShown = show;
  try {
    await SystemChrome.setEnabledSystemUIMode(show ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky);
  } catch (_) {
    // Sem plataforma (testes): nada a fazer.
  }
}

/// O furo da câmera no topo da tela, em tela cheia (0.23.2 no mapa, 0.24.1 nas telas do celular): o Android declara a faixa
/// inteira da barra de status como recorte, e o conteúdo só precisa desviar do furo. `null` com as barras à vista ou sem furo.
Rect? topCutout(BuildContext context) => systemBarsShown
    ? null
    : MediaQuery.displayFeaturesOf(context).where((f) => f.type == ui.DisplayFeatureType.cutout && f.bounds.top <= 1).map((f) => f.bounds).firstOrNull;
