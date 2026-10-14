/// Cores do mapa de jogo em pixels de arte. Saem das paletas de `biomes.json` (a cidade segue a regra de
/// arte: fria e dessaturada) e do contorno ameixa, sem número de cor solto no desenho.
library;

import 'dart:ui';

import '../../core/biomes.dart';
import '../colors.dart';

class Material3 {
  const Material3(this.dark, this.base, this.light, this.edge);

  /// Os três tons da paleta e a cor da borda de 1 pixel de arte.
  final Color dark;
  final Color base;
  final Color light;
  final Color edge;
}

class ArtStyle {
  ArtStyle(BiomeSet biomes)
      : ground = _material(biomes.byId(4)), // Residencial: o chão neutro da cidade
        green = _material(biomes.byId(2)),
        water = _material(biomes.byId(3)),
        asphalt = Color(0xFF000000 | biomes.byId(0).palette[0]), // Vazio, o tom mais escuro
        sidewalk = Color(0xFF000000 | biomes.byId(1).palette[2]); // Urbano, o tom mais claro

  final Material3 ground;
  final Material3 green;
  final Material3 water;

  /// Rua e calçada: a calçada é um tom mais claro que o chão, o asfalto um mais escuro.
  final Color asphalt;
  final Color sidewalk;

  static Material3 _material(BiomeDef b) {
    Color c(int i) => Color(0xFF000000 | b.palette[i]);
    return Material3(c(0), c(1), c(2), Color.lerp(c(0), kOutline, 0.55)!);
  }
}
