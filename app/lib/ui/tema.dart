/// Tokens do Design System do Kenoma (https://claude.ai/artifact/YNDxtTHyy6WUofSDC5A7Ub). Toda tela nova do celular, do
/// Perfil e do menu de debug usa estes nomes; as telas antigas (`colors.dart`) migram quando forem tocadas. Dart puro de
/// aparência: nenhuma regra de jogo mora aqui.
library;

import 'package:flutter/painting.dart';

/// Cores. `veuVioleta` é o jogador e o dial; `sinalCiano` é o mundo; `brasaLaranja` só para o que pede ação agora.
abstract final class KCores {
  static const Color fundo = Color(0xFF120E1A);
  static const Color superficie1 = Color(0xFF1E1830);
  static const Color superficie2 = Color(0xFF2A2240);
  static const Color contorno = Color(0xFF1A1424);
  static const Color veuVioleta = Color(0xFF9B7BFF);
  static const Color veuClaro = Color(0xFFC9B8FF);
  static const Color sinalCiano = Color(0xFF5FD3C6);
  static const Color brasaLaranja = Color(0xFFFF7A45);
  static const Color falha = Color(0xFFFF5A6E);
  static const Color texto = Color(0xFFECE6FF);
  static const Color textoMudo = Color(0xFF9A90B8);
  static const Color cidade = Color(0xFF3A3F55);
}

/// Espaços em múltiplos de 3 dp (o pixel de arte do mapa).
abstract final class KEspaco {
  static const double s1 = 6;
  static const double s2 = 12;
  static const double s3 = 18;
  static const double s4 = 24;
}

/// Cantos: retos, chanfro de um pixel de arte ou moldura do celular.
abstract final class KCanto {
  static const double r0 = 0;
  static const double r1 = 3;
  static const double r2 = 6;
}

/// Contorno de pixel de arte e a altura mínima de toque.
const double kContornoDp = 3;
const double kToqueMinDp = 48;

/// Fontes embarcadas: Silkscreen (títulos, rótulos e números, nunca parágrafo) e Pixelify Sans (frases).
abstract final class KFonte {
  static const String pixel = 'Silkscreen';
  static const String corpo = 'Pixelify Sans';
}

/// Estilos de texto do sistema.
abstract final class KTexto {
  static const TextStyle display = TextStyle(fontFamily: KFonte.pixel, fontSize: 36, height: 1, fontWeight: FontWeight.w700, color: KCores.texto);
  static const TextStyle titulo = TextStyle(fontFamily: KFonte.pixel, fontSize: 21, height: 24 / 21, fontWeight: FontWeight.w700, color: KCores.texto);
  static const TextStyle rotulo = TextStyle(fontFamily: KFonte.pixel, fontSize: 12, height: 15 / 12, letterSpacing: 1, color: KCores.texto);
  static const TextStyle numero = TextStyle(fontFamily: KFonte.pixel, fontSize: 24, height: 1, color: KCores.texto);
  static const TextStyle corpo = TextStyle(fontFamily: KFonte.corpo, fontSize: 16, height: 22 / 16, color: KCores.texto);
  static const TextStyle corpoPequeno = TextStyle(fontFamily: KFonte.corpo, fontSize: 14, height: 19 / 14, color: KCores.textoMudo);
}

/// Sombras: dura de 3 dp sob botões e cartões, e o único brilho permitido, o do Véu.
abstract final class KSombra {
  static const List<BoxShadow> pixel = [BoxShadow(color: KCores.contorno, offset: Offset(0, 3), blurRadius: 0)];
  static const List<BoxShadow> brilhoVeu = [BoxShadow(color: Color(0x739B7BFF), blurRadius: 12)];
}
