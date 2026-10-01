/// Partícula de efeito: posição relativa ao ponto de ancoragem do efeito, em unidades dele.
class FxParticle {
  const FxParticle(this.x, this.y, this.size, this.alpha);

  final double x;
  final double y;

  /// Tamanho de 0 a 1.
  final double size;
  final double alpha;
}
