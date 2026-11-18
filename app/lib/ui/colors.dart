import 'dart:ui' show Color;

import '../capture/eco_type.dart';

/// Cores fixas do jogo (CLAUDE.md). Contorno em ameixa escuro, nunca preto puro.
const Color kOutline = Color(0xFF1A1424);
const Color kVeil = Color(0xFF9B7BFF); // violeta: o Véu
const Color kSignal = Color(0xFF5FD3C6); // ciano: o sinal
const Color kEssence = Color(0xFFFF7A45); // laranja: Essência
const Color kPanel = Color(0xFF241A33);
const Color kPanelLine = Color(0xFF3D3357);
const Color kText = Color(0xFFE8E4F4);
const Color kDim = Color(0xFF8A8FA3);

/// As ciclovias no mapa: o ciano do sinal, apagado (linha fina e discreta).
const Color kCycleway = Color(0xFF5FD3C6);

/// 0.26.0: a cor principal de cada tipo (docs/art/estilo-ui.md, "Cores e ícones dos tipos"): nunca o ciano do sinal nem o
/// violeta do Véu. Tipo é sempre cor + ícone (`assets/art/ui/types/`); a cor sozinha não separa os tipos em cinza.
Color typeColor(EcoType t) => switch (t) {
      EcoType.fire => const Color(0xFFF0502E),
      EcoType.water => const Color(0xFF4A9CFF),
      EcoType.plant => const Color(0xFF4DBD62),
      EcoType.earth => const Color(0xFFC0915A),
      EcoType.electric => const Color(0xFFFFD23A),
      EcoType.metal => const Color(0xFF93A1B3),
      EcoType.light => const Color(0xFFFFF0B8),
      EcoType.shadow => const Color(0xFFA677AB),
      EcoType.spectral => const Color(0xFFD3E2F4),
      EcoType.digital => const Color(0xFFA8F040),
      EcoType.fae => const Color(0xFFFFA8E0),
      EcoType.draconic => const Color(0xFFDE4F84),
    };

/// O tom claro do tipo: texto e número sobre o painel.
Color typeColorLight(EcoType t) => switch (t) {
      EcoType.fire => const Color(0xFFFF9C7A),
      EcoType.water => const Color(0xFFA4D0FF),
      EcoType.plant => const Color(0xFFA2E8A0),
      EcoType.earth => const Color(0xFFE6C594),
      EcoType.electric => const Color(0xFFFFEE9A),
      EcoType.metal => const Color(0xFFCCD6E2),
      EcoType.light => const Color(0xFFFFFBE6),
      EcoType.shadow => const Color(0xFFD2ABD6),
      EcoType.spectral => const Color(0xFFF2F7FF),
      EcoType.digital => const Color(0xFFDCFA9E),
      EcoType.fae => const Color(0xFFFFD6F1),
      EcoType.draconic => const Color(0xFFF797B6),
    };

/// O tom escuro do tipo: só sombra de ícone e fundo de etiqueta (não serve para texto sobre o painel).
Color typeColorDark(EcoType t) => switch (t) {
      EcoType.fire => const Color(0xFFA82E1C),
      EcoType.water => const Color(0xFF2A62B8),
      EcoType.plant => const Color(0xFF2B7A40),
      EcoType.earth => const Color(0xFF7E5A32),
      EcoType.electric => const Color(0xFFB8901C),
      EcoType.metal => const Color(0xFF566274),
      EcoType.light => const Color(0xFFCDB468),
      EcoType.shadow => const Color(0xFF68426E),
      EcoType.spectral => const Color(0xFF8A9DBA),
      EcoType.digital => const Color(0xFF62A01E),
      EcoType.fae => const Color(0xFFC0669E),
      EcoType.draconic => const Color(0xFF8E2852),
    };
