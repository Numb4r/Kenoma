/// Raios do mapa lidos de `balance.json` (chave `map`), em metros. Nenhum número vive no código.
library;

class MapBalance {
  MapBalance(Map<String, dynamic> balance) : this._(balance['map'] as Map<String, dynamic>);

  MapBalance._(Map<String, dynamic> m)
      : auraM = (m['aura_m'] as num).toDouble(),
        viewM = (m['view_m'] as num).toDouble(),
        trackerM = (m['tracker_m'] as num).toDouble(),
        auraWidthFraction = (m['aura_width_fraction'] as num).toDouble(),
        zoomMinWidthM = (m['zoom_min_width_m'] as num).toDouble(),
        zoomMaxWidthM = (m['zoom_max_width_m'] as num).toDouble();

  /// Raio da Aura: só dentro dela o jogador interage.
  final double auraM;

  /// Até onde os spawns aparecem.
  final double viewM;

  /// Até onde o rastreador mostra.
  final double trackerM;

  /// No zoom padrão, o diâmetro da Aura ocupa esta fração da largura da tela.
  final double auraWidthFraction;

  /// Menor e maior largura de tela, em metros, que a pinça alcança.
  final double zoomMinWidthM;
  final double zoomMaxWidthM;

  /// Largura de tela, em metros, do zoom padrão: o diâmetro da Aura vale [auraWidthFraction] dela.
  double get defaultWidthM => 2 * auraM / auraWidthFraction;
}
