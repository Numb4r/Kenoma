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

/// Cor do tipo do Eco (docs/referencias-de-arte.md): fogo em brasa, água em azul, planta em verde.
Color typeColor(EcoType t) => switch (t) {
      EcoType.fire => const Color(0xFFFF5A36),
      EcoType.water => const Color(0xFF4AA8FF),
      EcoType.plant => const Color(0xFF6BD36A),
      EcoType.earth => const Color(0xFFC79A5B),
      EcoType.electric => const Color(0xFFFFD84A),
      EcoType.metal => const Color(0xFF9FB3C8),
      EcoType.light => const Color(0xFFFFF3B0),
      EcoType.shadow => const Color(0xFF6B5A8E),
      EcoType.spectral => const Color(0xFFB8C4D6),
      EcoType.digital => const Color(0xFF3DFFB0),
      EcoType.fae => const Color(0xFFFF8FD8),
      EcoType.draconic => const Color(0xFFD14B4B),
    };
