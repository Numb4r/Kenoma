/// Filtro do GPS: recusa leituras ruins e suaviza o ruído, para o marcador não tremer parado.
/// Dart puro (docs/fase0-spec.md, seção 2).
///
/// - Leitura com precisão pior que [maxAccuracyM] (50 m) é recusada.
/// - **Parado:** a posição é a média das leituras (com peso que decai devagar). O desvio cai com a raiz
///   do número de leituras, então os ~5 m de ruído do GPS viram menos de 1 m e o marcador não treme.
/// - **Andando:** quando as últimas leituras se afastam da média de forma consistente, entra um filtro
///   de Kalman de posição e velocidade (velocidade constante com ruído de aceleração), que segue quem
///   anda sem atraso. Volta ao modo parado quando a velocidade estimada some por alguns segundos.
/// - Salto grande (teletransporte do simulador) recomeça o filtro na leitura.
library;

import 'dart:math' as math;

import 'geo_fix.dart';

/// Posição suavizada.
class FilteredPosition {
  const FilteredPosition({required this.lat, required this.lon, required this.accuracyM, required this.timeMs, required this.moving});

  final double lat;
  final double lon;

  /// Incerteza da estimativa (desvio padrão), em metros. Cai parado e sobe andando.
  final double accuracyM;
  final int timeMs;

  /// Se o jogador está se movendo (a estimativa andou no último intervalo).
  final bool moving;
}

class GpsFilter {
  GpsFilter({
    this.maxAccuracyM = 50,
    this.accelNoise = 0.35,
    this.motionFactor = 1.8,
    this.stillSpeedMps = 0.8,
    this.stillFixes = 6,
    this.resetDistanceM = 150,
    this.minSigmaM = 1.0,
    this.stillWeight = 0.03,
  });

  /// Pior precisão aceita. Acima disso a leitura é recusada.
  final double maxAccuracyM;

  /// Desvio da aceleração do jogador, em m/s², no modo andando: quanto o filtro espera que ele acelere.
  final double accelNoise;

  /// Parado, só vira movimento quando duas janelas de 4 leituras (as 4 últimas e as 4 antes delas) se
  /// afastam da média geral para o mesmo lado: a recente mais que `motionFactor × precisão` e a antiga
  /// mais que metade disso. Um tremor passageiro não passa nos dois testes (falso alarme ~0,02%).
  final double motionFactor;

  /// Andando, abaixo desta velocidade estimada, por [stillFixes] leituras seguidas, volta a parado.
  final double stillSpeedMps;
  final int stillFixes;

  /// Salto acima disso (e acima de 3x a precisão) é teletransporte: o filtro recomeça na leitura.
  final double resetDistanceM;

  /// Piso do desvio informado, em metros.
  final double minSigmaM;

  /// Peso de cada leitura na média parada, depois das primeiras: define o quanto a média acompanha uma
  /// deriva lenta (menor, mais firme).
  final double stillWeight;

  double _lat0 = 0, _lon0 = 0, _kLon = 1;
  bool _has = false;
  bool _moving = false;
  int _timeMs = 0;

  // Modo parado: média das leituras e as últimas 4, em metros.
  double _mx = 0, _my = 0, _acc = 5;
  int _n = 0;
  final List<(double, double)> _recent = [];

  // Modo andando: posição, velocidade e covariância 2x2 (pp, pv, vv).
  double _x = 0, _y = 0, _vx = 0, _vy = 0;
  double _pp = 0, _pv = 0, _vv = 0;
  int _slowRun = 0;

  /// Leituras recusadas por precisão ruim.
  int rejected = 0;

  static const double _mPerDegLat = 111132.92;
  static const double _mPerDegLon = 111319.49;

  /// A última posição suavizada, ou `null` antes da primeira leitura aceita.
  FilteredPosition? get position => _has ? _out() : null;

  void reset() {
    _has = false;
    _moving = false;
  }

  FilteredPosition _out() {
    final x = _moving ? _x : _mx, y = _moving ? _y : _my;
    final sigma = _moving ? math.sqrt(_pp) : math.max(minSigmaM, _acc / math.sqrt(math.max(1, math.min(_n, 1 / stillWeight))));
    return FilteredPosition(
      lat: _lat0 + y / _mPerDegLat,
      lon: _lon0 + x / (_mPerDegLon * _kLon),
      accuracyM: sigma,
      timeMs: _timeMs,
      moving: _moving,
    );
  }

  void _start(GeoFix fix) {
    _lat0 = fix.lat;
    _lon0 = fix.lon;
    _kLon = math.cos(fix.lat * math.pi / 180);
    _toStill(0, 0, fix.accuracyM, 1);
    _timeMs = fix.timeMs;
    _has = true;
  }

  void _toStill(double x, double y, double acc, int weightN) {
    _moving = false;
    _mx = x;
    _my = y;
    _acc = acc;
    _n = weightN;
    _recent
      ..clear()
      ..add((x, y));
    _slowRun = 0;
  }

  void _toMoving(double x, double y) {
    _moving = true;
    _x = x;
    _y = y;
    _vx = _vy = 0;
    _pp = _acc * _acc;
    _pv = 0;
    _vv = 4; // a velocidade é desconhecida: ~2 m/s de desvio
    _slowRun = 0;
  }

  /// Processa uma leitura. Devolve a posição suavizada, ou `null` se a leitura foi recusada (precisão
  /// pior que [maxAccuracyM], inválida ou fora de ordem no tempo).
  FilteredPosition? add(GeoFix fix) {
    if (!(fix.accuracyM <= maxAccuracyM) || fix.accuracyM < 0 || fix.lat.isNaN || fix.lon.isNaN) {
      rejected++;
      return null;
    }
    if (!_has) {
      _start(fix);
      return _out();
    }
    if (fix.timeMs <= _timeMs) return null; // fora de ordem ou repetida
    final dt = math.min((fix.timeMs - _timeMs) / 1000.0, 10.0);
    final zx = (fix.lon - _lon0) * _mPerDegLon * _kLon;
    final zy = (fix.lat - _lat0) * _mPerDegLat;
    final cx = _moving ? _x + _vx * dt : _mx, cy = _moving ? _y + _vy * dt : _my;
    final d = math.sqrt((zx - cx) * (zx - cx) + (zy - cy) * (zy - cy));
    if (d > resetDistanceM && d > 3 * fix.accuracyM) {
      _start(fix); // teletransporte
      return _out();
    }
    if (_moving) {
      _kalman(zx, zy, fix.accuracyM, dt);
    } else {
      _still(zx, zy, fix.accuracyM);
    }
    _timeMs = fix.timeMs;
    return _out();
  }

  void _still(double zx, double zy, double acc) {
    _recent.add((zx, zy));
    if (_recent.length > 8) _recent.removeAt(0);
    _acc = math.max(acc, minSigmaM);
    if (_recent.length == 8) {
      (double, double) mean(int from) {
        var sx = 0.0, sy = 0.0;
        for (var i = from; i < from + 4; i++) {
          sx += _recent[i].$1;
          sy += _recent[i].$2;
        }
        return (sx / 4, sy / 4);
      }

      final (ox, oy) = mean(0);
      final (rx, ry) = mean(4);
      final ax = ox - _mx, ay = oy - _my, bx = rx - _mx, by = ry - _my;
      final recent = math.sqrt(bx * bx + by * by), older = math.sqrt(ax * ax + ay * ay);
      final away = recent > motionFactor * _acc && older > 0.5 * motionFactor * _acc && ax * bx + ay * by > 0;
      if (away) {
        _toMoving(rx, ry); // as leituras se afastaram da média de forma consistente
        return;
      }
      if (recent > motionFactor * _acc) return; // suspeita de movimento: não deixa a leitura puxar a média
    }
    _n++;
    final w = math.max(1 / _n, stillWeight);
    _mx += w * (zx - _mx);
    _my += w * (zy - _my);
  }

  void _kalman(double zx, double zy, double acc, double dt) {
    final px = _x + _vx * dt, py = _y + _vy * dt;
    final q = accelNoise * accelNoise;
    final dt2 = dt * dt, dt3 = dt2 * dt, dt4 = dt2 * dt2;
    final pp = _pp + 2 * dt * _pv + dt2 * _vv + q * dt4 / 4;
    final pv = _pv + dt * _vv + q * dt3 / 2;
    final vv = _vv + q * dt2;
    final r = acc * acc;
    final s = pp + r;
    final kp = pp / s, kv = pv / s;
    final dx = zx - px, dy = zy - py;
    _x = px + kp * dx;
    _y = py + kp * dy;
    _vx += kv * dx;
    _vy += kv * dy;
    _pp = math.max(minSigmaM * minSigmaM, (1 - kp) * pp);
    _pv = (1 - kp) * pv;
    _vv = vv - kv * pv;
    _acc = acc;
    final speed = math.sqrt(_vx * _vx + _vy * _vy);
    _slowRun = speed < stillSpeedMps ? _slowRun + 1 : 0;
    if (_slowRun >= stillFixes) _toStill(_x, _y, acc, 15);
  }
}
