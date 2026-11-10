/// A "Simulação de clima" do debug: passa por todos os climas da lista, um depois do outro, cada um por [ClimateSim.stepS]
/// segundos de parede. Cada passo começa do zero: o clima forma nos primeiros três quartos e, no último quarto, acaba
/// (vira Limpo) e o que ele deixou no chão seca ou derrete. Só neste aparelho: não muda o mundo nem dá recompensa. Dart puro.
library;

/// O passo da simulação agora: o índice e o id do clima, quantas voltas já deu, se está na parte em que o clima acabou e
/// quanto do passo passou (0 a 1).
typedef SimState = ({int index, String id, int round, bool fading, double progress});

class ClimateSim {
  ClimateSim({required this.ids, required double stepS, required double startS}) {
    _stepS = stepS;
    _startS = startS;
  }

  /// O clima para onde o passo vai quando acaba: o que ficou no chão seca.
  static const fadeTo = 'clear';

  /// A parte do passo em que o clima vale; o resto é ele secando.
  static const formShare = 0.75;

  final List<String> ids;
  late double _stepS;
  late double _startS;
  int _base = 0;
  bool _repeat = false;

  double get stepS => _stepS;
  bool get repeat => _repeat;

  SimState at(double wallS) {
    final elapsed = (wallS - _startS).clamp(0.0, double.infinity);
    final n = (elapsed / _stepS).floor();
    final within = elapsed - n * _stepS;
    final index = _repeat ? _base : (_base + n) % ids.length;
    return (index: index, id: ids[index], round: n, fading: within >= formShare * _stepS, progress: within / _stepS);
  }

  /// Pula para o clima [i], do zero.
  void jump(int i, double wallS) {
    _base = i.clamp(0, ids.length - 1);
    _startS = wallS;
  }

  /// Fica no clima de agora, repetindo do zero, ou volta à sequência a partir dele.
  void setRepeat(bool on, double wallS) {
    _base = at(wallS).index;
    _repeat = on;
    _startS = wallS;
  }

  /// Muda o tempo por clima e recomeça o clima de agora do zero.
  void setStep(double stepS, double wallS) {
    if (stepS <= 0) return;
    _base = at(wallS).index;
    _stepS = stepS;
    _startS = wallS;
  }
}
