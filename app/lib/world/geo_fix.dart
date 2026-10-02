/// Uma leitura de posição, venha ela do GPS ou do simulador. É o que o resto do app enxerga: a fonte
/// pode trocar sem mudar mais nada.
library;

class GeoFix {
  const GeoFix({required this.lat, required this.lon, required this.accuracyM, required this.timeMs, this.speedMps});

  final double lat;
  final double lon;

  /// Raio de 68% de confiança, em metros, como o `Position.accuracy` do geolocator.
  final double accuracyM;

  /// Instante da leitura, em milissegundos UTC desde a época Unix.
  final int timeMs;

  /// Velocidade que a própria fonte informa, em m/s (o GPS mede por efeito Doppler, bem melhor que a
  /// diferença entre posições). `null` se a fonte não informa. O filtro só a usa como sinal de que o
  /// jogador começou a andar: um 0 não prova que ele parou.
  final double? speedMps;

  @override
  String toString() => 'GeoFix($lat, $lon ±${accuracyM.toStringAsFixed(1)} m @ $timeMs)';
}
