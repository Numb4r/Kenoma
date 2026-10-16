/// Raios do mapa lidos de `balance.json` (chave `map`), em metros. Nenhum número vive no código.
library;

class MapBalance {
  MapBalance(Map<String, dynamic> balance) : this._(balance['map'] as Map<String, dynamic>);

  MapBalance._(Map<String, dynamic> m)
      : auraM = (m['aura_m'] as num).toDouble(),
        viewM = (m['view_m'] as num).toDouble(),
        trackerM = (m['tracker_m'] as num).toDouble(),
        trackerMax = m['tracker_max'] as int,
        defaultWidthM = (m['view_width_default_m'] as num).toDouble(),
        spriteHeightM = (m['sprite_height_m'] as num).toDouble(),
        playerHeightM = (m['player_height_m'] as num).toDouble(),
        familiarHeightM = (m['familiar_height_m'] as num).toDouble(),
        ecoHeightM = (m['eco_height_m'] as num).toDouble(),
        ghostPedestrianM = (m['ghost_pedestrian_m'] as num).toDouble(),
        ghostCarM = (m['ghost_car_m'] as num).toDouble(),
        sparkSizeM = (m['spark_size_m'] as num).toDouble(),
        artPixelDp = (m['art_pixel_dp'] as num).toDouble(),
        compassDeclinationDeg = (m['compass_declination_deg'] as num).toDouble(),
        sidewalkArtPx = (m['sidewalk_art_px'] as num).toDouble(),
        roadWidthM = {for (final e in (m['road_width_m'] as Map<String, dynamic>).entries) e.key: (e.value as num).toDouble()},
        cameraMinWidthM = (m['camera_min_width_m'] as num).toDouble(),
        cameraMaxWidthM = (m['camera_max_width_m'] as num).toDouble();

  /// Raio da Aura: só dentro dela o jogador interage.
  final double auraM;

  /// Até onde os spawns aparecem.
  final double viewM;

  /// Até onde o rastreador mostra.
  final double trackerM;

  /// Quantos Ecos fora da tela o rastreador mostra, no máximo.
  final int trackerMax;

  /// Largura da tela, em metros, no zoom padrão.
  final double defaultWidthM;

  /// Altura do Conjurador e dos Ecos, em metros do mundo: mais ou menos a largura de uma rua. A proporção
  /// com as ruas é a mesma em qualquer zoom.
  final double spriteHeightM;

  /// Alturas dos sprites em metros do mundo: Conjurador, Familiar e Ecos; e o tamanho dos fantasmas do tráfego
  /// (pedestre: altura; carro: comprimento).
  final double playerHeightM;
  final double familiarHeightM;
  final double ecoHeightM;
  final double ghostPedestrianM;
  final double ghostCarM;

  /// Tamanho das Fagulhas e dos pontos de material, em metros do mundo.
  final double sparkSizeM;

  /// Menor e maior largura de tela, em metros, que a pinça alcança (a câmera).
  final double cameraMinWidthM;
  final double cameraMaxWidthM;

  /// Tamanho de um pixel de arte no zoom padrão, em dp. O mapa é desenhado nesses pixels e ampliado.
  final double artPixelDp;

  /// Declinação magnética do lugar, em graus (leste positivo): a bússola do celular lê o norte magnético e o
  /// mapa tem o norte verdadeiro. Vale para a região da época (Campinas: cerca de -21°).
  final double compassDeclinationDeg;

  /// Calçada de cada lado da rua, em pixels de arte.
  final double sidewalkArtPx;

  /// Largura da rua por classe (`principal`, `secondary`, `local`, `pedestrian`), em metros.
  final Map<String, double> roadWidthM;
}
