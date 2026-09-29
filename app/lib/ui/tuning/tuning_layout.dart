import 'dart:math' as math;
import 'dart:ui';

/// Início e abertura do dial: 270 graus, do canto inferior esquerdo ao inferior direito, por cima.
const double dialStartRad = 3 * math.pi / 4;
const double dialSweepRad = 3 * math.pi / 2;

/// Ângulo do dial, em radianos, para a frequência [f] em `[0, 1]`.
double dialAngle(double f) => dialStartRad + dialSweepRad * f;

/// Onde cada peça da tela de sintonia fica. Serve para desenhar e para saber onde o toque vale.
class TuningLayout {
  TuningLayout(this.size) {
    final w = size.width;
    final h = size.height;
    spriteScale = math.max(2, (math.min(w * 0.5, h * 0.25) / 48).floor());
    creatureCenter = Offset(w / 2, h * 0.23);
    ringRadius = 48 * spriteScale / 2 + 14;
    final wavesTop = creatureCenter.dy + ringRadius + 18;
    wavePanel = Rect.fromLTWH(16, wavesTop, w - 32, h * 0.15);
    final free = h - wavePanel.bottom;
    dialRadius = math.min(w * 0.42, free / 2 - 12);
    dialCenter = Offset(w / 2, wavePanel.bottom + free / 2 + 4);
    timeBar = Rect.fromLTWH(hudLeft, 34, w - hudLeft - 16, 6);
  }

  final Size size;
  late final int spriteScale;
  late final Offset creatureCenter;
  late final double ringRadius;
  late final Rect wavePanel;
  late final Offset dialCenter;
  late final double dialRadius;
  late final Rect timeBar;

  /// Espaço à esquerda do HUD para o botão de voltar.
  static const double hudLeft = 48;

  /// O dial responde a arrastar em qualquer ponto abaixo do painel das ondas.
  bool isDialTouch(Offset p) => p.dy >= wavePanel.bottom;

  /// Ângulo do ponto [p] visto do centro do dial.
  double angleOf(Offset p) {
    final d = p - dialCenter;
    return math.atan2(d.dy, d.dx);
  }
}

/// Menor diferença entre dois ângulos, em `(-pi, pi]`.
double angleDelta(double from, double to) {
  var d = to - from;
  while (d > math.pi) {
    d -= 2 * math.pi;
  }
  while (d <= -math.pi) {
    d += 2 * math.pi;
  }
  return d;
}

/// Frequência depois de girar o dial por [deltaRad], limitada a `[0, 1]`.
double dialAfterTurn(double dial, double deltaRad) => (dial + deltaRad / dialSweepRad).clamp(0.0, 1.0);
