/// Raios do mapa lidos de `balance.json` (chave `map`), em metros. Nenhum número vive no código.
library;

class MapBalance {
  MapBalance(Map<String, dynamic> balance) : this._(balance['map'] as Map<String, dynamic>);

  MapBalance._(Map<String, dynamic> m)
      : auraM = (m['aura_m'] as num).toDouble(),
        viewM = (m['view_m'] as num).toDouble(),
        trackerM = (m['tracker_m'] as num).toDouble();

  /// Raio da Aura: só dentro dela o jogador interage.
  final double auraM;

  /// Até onde os spawns aparecem.
  final double viewM;

  /// Até onde o rastreador mostra.
  final double trackerM;
}
