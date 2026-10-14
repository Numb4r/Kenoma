/// O Conjurador no mapa: a posição que se desenha, interpolada entre as leituras filtradas do GPS para o
/// marcador nunca pular. Dart puro.
///
/// O marcador anda pelo caminho das leituras aceitas com [delayS] de atraso (cerca de 1 s): entre duas
/// leituras ele vai em linha reta, na velocidade estimada por elas, e chega na última quando a leitura
/// seguinte já deveria ter chegado. Um seguidor com [followTauS] de constante de tempo tira as quinas do
/// caminho, e quando o GPS para o marcador desacelera até a última posição sem passar dela.
///
/// Leituras que exigiriam mais de [maxSpeedMps] desde a última aceita são erro do GPS e são descartadas.
/// Se várias seguidas, perto umas das outras, mostram que o jogador realmente está em outro lugar (outra
/// fonte, teleporte do simulador, o GPS achou o sinal de novo), o marcador reaparece lá.
library;

import 'dart:math' as math;

class PlayerAvatar {
  PlayerAvatar({
    this.delayS = 1.0,
    this.followTauS = 0.15,
    this.maxSpeedMps = 12,
    this.relocateAfter = 2,
    this.relocateRadiusM = 30,
    this.movingMps = 0.35,
    this.stillMps = 0.15,
  });

  /// Atraso do marcador em relação ao caminho do GPS: o tempo que ele leva para chegar na última leitura.
  final double delayS;

  /// Constante de tempo do seguidor que arredonda as quinas do caminho.
  final double followTauS;

  /// Velocidade máxima plausível, em m/s. Uma leitura que exigiria mais que isto é descartada.
  final double maxSpeedMps;

  /// Quantas leituras seguidas, todas impossíveis e perto umas das outras, valem como uma mudança real de lugar.
  final int relocateAfter;
  final double relocateRadiusM;

  /// Velocidade para contar como andando, e abaixo da qual volta a parado (a histerese evita tremer).
  final double movingMps;
  final double stillMps;

  double _x = 0, _y = 0;
  double _t = 0;
  bool _has = false;
  bool _moving = false;
  double _vx = 0, _vy = 0; // células por segundo, suavizada
  double _metersPerCell = 17.6;

  /// O caminho: leituras aceitas, com o instante em que chegaram.
  final List<_Point> _path = [];

  // Candidata a nova posição depois de leituras impossíveis.
  double _cx = 0, _cy = 0;
  int _candidates = 0;

  /// Quantas leituras foram descartadas por exigirem mais que [maxSpeedMps].
  int discarded = 0;

  bool get hasPosition => _has;

  /// Onde desenhar, em células z21 fracionárias.
  double get x => _x;
  double get y => _y;

  /// Velocidade de agora, em células por segundo (suavizada).
  double get velocityX => _vx;
  double get velocityY => _vy;

  /// Velocidade de agora, em m/s.
  double get speedMps => math.sqrt(_vx * _vx + _vy * _vy) * _metersPerCell;

  /// Se o marcador está andando: sobe acima de [movingMps] e só volta a parado abaixo de [stillMps].
  bool get moving => _moving;

  /// Para onde o caminho chegou: a última leitura aceita.
  (double, double)? get latest => _path.isEmpty ? null : (_path.last.x, _path.last.y);

  /// Uma leitura filtrada nova em ([x], [y]), em células z21 fracionárias. [metersPerCell] é o tamanho de
  /// uma célula na latitude de agora. A primeira posição aparece direto.
  ///
  /// [timeMs] é o instante da leitura, no relógio do GPS. Com ele a velocidade exigida sai do tempo real entre
  /// as leituras, mesmo que várias cheguem juntas (o app voltou do segundo plano, ou o simulador andou
  /// de uma vez). Sem ele vale o tempo em que cada uma chegou.
  void setTarget(double x, double y, {required double metersPerCell, int? timeMs}) {
    _metersPerCell = metersPerCell;
    if (!_has) {
      _snap(x, y, timeMs);
      return;
    }
    final last = _path.last;
    final meters = math.sqrt(math.pow(x - last.x, 2) + math.pow(y - last.y, 2)) * metersPerCell;
    // Duas leituras no mesmo instante contam como 0,25 s: o GPS não entrega mais rápido que isso.
    final realElapsed = timeMs != null && last.ms != null ? (timeMs - last.ms!) / 1000 : _t - last.t;
    final elapsed = math.max(realElapsed, 0.25);
    if (meters / elapsed <= maxSpeedMps) {
      _candidates = 0;
      // O tempo do caminho sempre cresce: duas leituras no mesmo quadro ficam 0,25 s uma da outra.
      _path.add(_Point(x, y, math.max(_t, last.t + 0.25), timeMs));
      return;
    }
    discarded++;
    final nearCandidate = _candidates > 0 && math.sqrt(math.pow(x - _cx, 2) + math.pow(y - _cy, 2)) * metersPerCell <= relocateRadiusM;
    if (nearCandidate) {
      _candidates++;
    } else {
      _candidates = 1;
    }
    _cx = x;
    _cy = y;
    if (_candidates >= relocateAfter) _snap(x, y, timeMs);
  }

  void _snap(double x, double y, int? timeMs) {
    _x = x;
    _y = y;
    _has = true;
    _vx = _vy = 0;
    _moving = false;
    _candidates = 0;
    _path
      ..clear()
      ..add(_Point(x, y, _t, timeMs));
  }

  /// Esquece a posição: o marcador some até a próxima [setTarget].
  void clear() {
    _has = false;
    _moving = false;
    _vx = _vy = 0;
    _path.clear();
    _candidates = 0;
  }

  void update(double dt) {
    if (dt <= 0) return;
    _t += dt;
    if (!_has) return;
    // O ponto do caminho que corresponde a [delayS] atrás.
    final td = _t - delayS;
    while (_path.length > 2 && _path[1].t <= td) {
      _path.removeAt(0);
    }
    var px = _path.last.x, py = _path.last.y;
    if (_path.length == 1 || td <= _path.first.t) {
      px = _path.first.x;
      py = _path.first.y;
    } else if (td < _path.last.t) {
      final a = _path[0], b = _path[1];
      final u = ((td - a.t) / (b.t - a.t)).clamp(0.0, 1.0);
      px = a.x + (b.x - a.x) * u;
      py = a.y + (b.y - a.y) * u;
    }
    final k = 1 - math.exp(-dt / followTauS);
    final nx = _x + (px - _x) * k, ny = _y + (py - _y) * k;
    // Velocidade para a animação, suavizada para não piscar entre andando e parado.
    final s = 1 - math.exp(-dt / 0.2);
    _vx += ((nx - _x) / dt - _vx) * s;
    _vy += ((ny - _y) / dt - _vy) * s;
    _x = nx;
    _y = ny;
    final speed = speedMps;
    if (_moving ? speed < stillMps : speed > movingMps) _moving = !_moving;
  }
}

class _Point {
  const _Point(this.x, this.y, this.t, [this.ms]);

  final double x;
  final double y;

  /// Instante em que o marcador devia estar aqui, no relógio do jogo, e o da leitura no relógio do GPS.
  final double t;
  final int? ms;
}
