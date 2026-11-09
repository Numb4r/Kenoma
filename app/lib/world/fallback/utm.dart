/// UTM no GRS80 (série de Krüger de ordem 6), direto e inverso, para o buffer do fallback sob demanda. O pipeline usa
/// EPSG:31983 (UTM 23S); fora de Campinas vale a zona da longitude do bloco. Dart puro.
library;

import 'dart:math' as math;

const double _a = 6378137.0;
const double _f = 1 / 298.257222101;
const double _k0 = 0.9996;
const double _falseEasting = 500000.0;
const double _falseNorthingSouth = 10000000.0;

double sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
double cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;

double asinh(double x) {
  final s = x.abs();
  final r = math.log(s + math.sqrt(s * s + 1));
  return x < 0 ? -r : r;
}

double atanh(double x) => 0.5 * math.log((1 + x) / (1 - x));

double _hypot(double x, double y) => math.sqrt(x * x + y * y);

class Utm {
  Utm.zone(int zone, {required this.south}) : _lon0 = (zone * 6 - 183) * math.pi / 180;

  /// A zona UTM de uma longitude em graus.
  static int zoneOf(double lon) => ((lon + 180) / 6).floor().clamp(0, 59) + 1;

  final bool south;
  final double _lon0;

  static final double _n = _f / (2 - _f);
  static final double _e2 = _f * (2 - _f);
  static final double _e = math.sqrt(_e2);
  static final double _rect = () {
    final n2 = _n * _n;
    return _a / (1 + _n) * (1 + n2 * (1 / 4 + n2 * (1 / 64 + n2 / 256)));
  }();
  static final List<double> _alpha = () {
    final n = _n, n2 = n * n, n3 = n2 * n, n4 = n3 * n, n5 = n4 * n, n6 = n5 * n;
    return [
      n / 2 - 2 * n2 / 3 + 5 * n3 / 16 + 41 * n4 / 180 - 127 * n5 / 288 + 7891 * n6 / 37800,
      13 * n2 / 48 - 3 * n3 / 5 + 557 * n4 / 1440 + 281 * n5 / 630 - 1983433 * n6 / 1935360,
      61 * n3 / 240 - 103 * n4 / 140 + 15061 * n5 / 26880 + 167603 * n6 / 181440,
      49561 * n4 / 161280 - 179 * n5 / 168 + 6601661 * n6 / 7257600,
      34729 * n5 / 80640 - 3418889 * n6 / 1995840,
      212378941 * n6 / 319334400,
    ];
  }();
  static final List<double> _beta = () {
    final n = _n, n2 = n * n, n3 = n2 * n, n4 = n3 * n, n5 = n4 * n, n6 = n5 * n;
    return [
      n / 2 - 2 * n2 / 3 + 37 * n3 / 96 - n4 / 360 - 81 * n5 / 512 + 96199 * n6 / 604800,
      n2 / 48 + n3 / 15 - 437 * n4 / 1440 + 46 * n5 / 105 - 1118711 * n6 / 3870720,
      17 * n3 / 480 - 37 * n4 / 840 - 209 * n5 / 4480 + 5569 * n6 / 90720,
      4397 * n4 / 161280 - 11 * n5 / 504 - 830251 * n6 / 7257600,
      4583 * n5 / 161280 - 108847 * n6 / 3991680,
      20648693 * n6 / 638668800,
    ];
  }();

  static double _conformalTan(double tau) {
    final s = sinh(_e * atanh(_e * tau / math.sqrt(1 + tau * tau)));
    return tau * math.sqrt(1 + s * s) - s * math.sqrt(1 + tau * tau);
  }

  /// (leste, norte) em metros de (lon, lat) em graus.
  (double, double) forward(double lon, double lat) {
    final lam = lon * math.pi / 180 - _lon0;
    final tau = _conformalTan(math.tan(lat * math.pi / 180));
    final c = math.cos(lam);
    final xi0 = math.atan2(tau, c), eta0 = asinh(math.sin(lam) / _hypot(tau, c));
    var xi = xi0, eta = eta0;
    for (var j = 1; j <= 6; j++) {
      final a = _alpha[j - 1];
      xi += a * math.sin(2 * j * xi0) * cosh(2 * j * eta0);
      eta += a * math.cos(2 * j * xi0) * sinh(2 * j * eta0);
    }
    return (_falseEasting + _k0 * _rect * eta, (south ? _falseNorthingSouth : 0) + _k0 * _rect * xi);
  }

  /// (lon, lat) em graus de (leste, norte) em metros.
  (double, double) inverse(double easting, double northing) {
    final xi = (northing - (south ? _falseNorthingSouth : 0)) / (_k0 * _rect);
    final eta = (easting - _falseEasting) / (_k0 * _rect);
    var xi0 = xi, eta0 = eta;
    for (var j = 1; j <= 6; j++) {
      final b = _beta[j - 1];
      xi0 -= b * math.sin(2 * j * xi) * cosh(2 * j * eta);
      eta0 -= b * math.cos(2 * j * xi) * sinh(2 * j * eta);
    }
    final sh = sinh(eta0), c = math.cos(xi0);
    final tauP = math.sin(xi0) / _hypot(sh, c);
    final e2m = 1 - _e2;
    var tau = tauP / e2m;
    for (var i = 0; i < 6; i++) {
      final t = _conformalTan(tau);
      final dt = (tauP - t) / math.sqrt(1 + t * t) * (1 + e2m * tau * tau) / (e2m * math.sqrt(1 + tau * tau));
      tau += dt;
      if (dt.abs() < 1e-15) break;
    }
    return ((_lon0 + math.atan2(sh, c)) * 180 / math.pi, math.atan(tau) * 180 / math.pi);
  }
}
