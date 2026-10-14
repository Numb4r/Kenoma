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
        playerHeightFraction = (m['player_height_fraction'] as num).toDouble(),
        zoomMinWidthM = (m['zoom_min_width_m'] as num).toDouble(),
        zoomMaxWidthM = (m['zoom_max_width_m'] as num).toDouble();

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

  /// O Conjurador e os Ecos ocupam esta fração da altura da tela.
  final double playerHeightFraction;

  /// Menor e maior largura de tela, em metros, que a pinça alcança.
  final double zoomMinWidthM;
  final double zoomMaxWidthM;
}
