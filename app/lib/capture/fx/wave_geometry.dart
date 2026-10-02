/// Geometria da onda do sinal na tela: de onde saem o número de ciclos, o envelope e as cristas.
/// O painter desenha com estas mesmas funções, então um efeito colado na crista fica na crista.
library;

import 'dart:math' as math;

/// Ciclos visíveis da onda para a frequência [f].
double waveCycles(double f) => 1.5 + 5.0 * f;

/// Envelope da onda: 0 nas pontas do painel, 1 no meio. [u] em `[0, 1]`.
double waveEnvelope(double u) => math.pow(math.sin(math.pi * u), 0.6).toDouble();

/// Fase da rolagem da onda, a partir do relógio da tela.
double waveScroll(double clock) => clock * math.pi;

/// Fase da onda no ponto [u] para a frequência [f] e a rolagem [scroll].
double waveTheta(double f, double u, double scroll) => 2 * math.pi * waveCycles(f) * (u - 0.5) + scroll;

/// Forma serrilhada do sinal da criatura: de -1 a 1, com pico em `theta = pi/2`.
double triShape(double theta) => 2 / math.pi * math.asin(math.sin(theta));

/// Posições [u] dos picos da forma serrilhada, entre [from] e [to] (exclusive nas pontas).
List<double> crestUs(double f, double scroll, {double from = 0.1, double to = 0.9}) {
  final span = 2 * math.pi * waveCycles(f); // fase por unidade de u
  final out = <double>[];
  // theta = pi/2 + 2*pi*k  ->  u = 0.5 + (theta - scroll) / span
  final kMin = ((scroll + (from - 0.5) * span - math.pi / 2) / (2 * math.pi)).ceil();
  for (var k = kMin;; k++) {
    final u = 0.5 + (math.pi / 2 + 2 * math.pi * k - scroll) / span;
    if (u > to) break;
    if (u >= from) out.add(u);
  }
  return out;
}

/// O valor de [options] mais perto de [target]. [options] não pode ser vazio.
double nearestTo(List<double> options, double target) =>
    options.reduce((a, b) => (a - target).abs() <= (b - target).abs() ? a : b);

/// Número pseudoaleatório em `[0, 1)` que só depende de [a] e [b]. Dá posições estáveis aos efeitos.
double hash01(int a, int b) {
  var h = (a * 73856093) ^ (b * 19349663);
  h = (h ^ (h >>> 13)) * 1274126177;
  return ((h ^ (h >>> 16)) & 0xffff) / 0x10000;
}

/// Mistura linear de [r.$1] a [r.$2].
double lerpPair((double, double) r, double t) => r.$1 + (r.$2 - r.$1) * t;

/// Um trecho da onda, preso à fronteira da queima: o desenho anda com ela. A fase em [u] é
/// `2π × ciclos(frequência) × (u − anchorU) + phase`.
class WaveSegment {
  const WaveSegment({
    required this.fromU,
    required this.toU,
    required this.frequency,
    required this.anchorU,
    required this.phase,
    required this.real,
  });

  /// Trecho visível, em fração da largura.
  final double fromU;
  final double toU;
  final double frequency;
  final double anchorU;
  final double phase;

  /// Verdadeiro na onda real (a da direita). Falso nas iscas, que ficam cinza.
  final bool real;

  double thetaAt(double u) => 2 * math.pi * waveCycles(frequency) * (u - anchorU) + phase;
}
