/// Eclipses vistos de um lugar, offline, com os elementos da NASA (época 7, bloco `climate.eclipses` do `epochs.json`).
///
/// Solar: circunstâncias locais a partir dos elementos besselianos do Five Millennium Canon (Espenak e Meeus,
/// NASA/TP-2006-214141), como no JavaScript Solar Eclipse Explorer da NASA (https://eclipse.gsfc.nasa.gov/JSEX/program.js,
/// elementos em https://eclipse.gsfc.nasa.gov/JSEX/SE2001.js; método do Explanatory Supplement, Meeus cap. 11). O lugar
/// fica na altitude 0. Há eclipse se a magnitude local passa de 0 com o Sol acima do horizonte (altura > -0,3°, o critério
/// da NASA) em algum instante entre o 1º e o 4º contato.
///
/// Lunar: os instantes U1 e U4 e a posição da Lua (polinômios de ascensão reta e declinação) dos Lunar Eclipse Elements
/// (https://eclipse.gsfc.nasa.gov/JLEX/LE2001.js, o Lunar Eclipse Explorer em https://eclipse.gsfc.nasa.gov/JLEX/program.js).
/// Há eclipse se a Lua está acima do horizonte (altura topocêntrica ≥ semidiâmetro − 0,5667°, o critério da NASA) em algum
/// instante entre U1 e U4: a fase parcial umbral conta, a penumbral não.
///
/// Os ΔT são os previstos pelo Canon (75 s em 2026, contra ~69 s medidos): erro de ~2 km na faixa, muito menor que a
/// região z12 do clima (~10 km). Dart puro.
library;

import 'dart:math' as math;

const double _deg = math.pi / 180;

/// O trecho visível de um eclipse num lugar: início, máximo e fim (segundos UTC) e a magnitude no máximo visível (solar:
/// fração do diâmetro do Sol coberta, ou a razão Lua/Sol no anular e no total; lunar: a magnitude umbral do eclipse).
typedef EclipseView = ({int startUtc, int maxUtc, int endUtc, double magnitude});

sealed class Eclipse {
  Eclipse(this.date, this.e);

  /// Data do eclipse (`2027-02-06`), só para leitura.
  final String date;

  /// Os números da NASA, na ordem do arquivo de origem.
  final List<double> e;

  /// 0 h TDT do dia do máximo, em segundos UTC sem o ΔT.
  int get _day0 => (((e[0] - e[1] / 24).floorToDouble() + 0.5 - 2440587.5) * 86400).round();
  double get _deltaT;

  /// O instante UTC de [t] horas depois de t0 (TDT).
  int utcOf(double t) => (_day0 + (e[1] + t) * 3600 - _deltaT).round();

  /// O intervalo UTC em que o eclipse pode ser visto em algum lugar da Terra: filtro rápido antes da conta local.
  (int, int) get span;

  /// O trecho visível de ([latDeg], [lonDeg]) (leste positivo), ou `null` se de lá não se vê.
  EclipseView? viewFrom(double latDeg, double lonDeg);
}

/// Busca o trecho de [c1, c4] em que [up] vale, sabendo que o eclipse vai de [c1] a [c4] com máximo em [mid]. Bissecção
/// (sem refração variável): o nascer ou o pôr cai entre um contato abaixo do horizonte e um instante acima dele.
(double, double, double)? _visibleSpan(double c1, double mid, double c4, bool Function(double t) up) {
  final anchor = [mid, c1, c4].where(up).firstOrNull;
  if (anchor == null) return null; // ponytail: perde o Sol que nasce e se põe entre contatos abaixo (só perto dos polos)
  double edge(double out, double inn) {
    for (var k = 0; k < 40; k++) {
      final m = (out + inn) / 2;
      if (up(m)) {
        inn = m;
      } else {
        out = m;
      }
    }
    return inn;
  }

  final s = up(c1) ? c1 : edge(c1, anchor);
  final f = up(c4) ? c4 : edge(c4, anchor);
  return (s, mid.clamp(s, f), f);
}

/// Eclipse solar: os 28 números de cada eclipse do `SE2001.js` (JD do máximo, t0, tmin, tmax, ΔT, ΔT; x, y em 4 termos;
/// d, μ, l1, l2 em 3; tan f1, tan f2).
class SolarEclipse extends Eclipse {
  SolarEclipse(super.date, super.e) {
    if (e.length != 28) throw FormatException('eclipse solar $date: 28 elementos, veio ${e.length}');
  }

  @override
  double get _deltaT => e[4];

  @override
  (int, int) get span => (utcOf(e[2]), utcOf(e[3]));

  @override
  EclipseView? viewFrom(double latDeg, double lonDeg) {
    final phi = latDeg * _deg, lonW = -lonDeg * _deg;
    final u = math.atan(0.99664719 * math.tan(phi));
    final rs = 0.99664719 * math.sin(u), rc = math.cos(u);
    final sinPhi = math.sin(phi), cosPhi = math.cos(phi);

    _B at(double t) {
      double p3(int i) => ((e[i + 3] * t + e[i + 2]) * t + e[i + 1]) * t + e[i];
      double d3(int i) => (3 * e[i + 3] * t + 2 * e[i + 2]) * t + e[i + 1];
      double p2(int i) => (e[i + 2] * t + e[i + 1]) * t + e[i];
      double d2(int i) => 2 * e[i + 2] * t + e[i + 1];
      final d = p2(14) * _deg, dd = d2(14) * _deg, dmu = d2(17) * _deg;
      final h = p2(17) * _deg - lonW - e[5] / 13713.44;
      final sinD = math.sin(d), cosD = math.cos(d), sinH = math.sin(h), cosH = math.cos(h);
      final xi = rc * sinH, eta = rs * cosD - rc * cosH * sinD, zeta = rs * sinD + rc * cosH * cosD;
      final uu = p3(6) - xi, vv = p3(10) - eta;
      final a = d3(6) - dmu * rc * cosH, b = d3(10) - (dmu * xi * sinD - zeta * dd);
      return _B(uu, vv, a, b, p2(20) - zeta * e[26], p2(23) - zeta * e[27], math.asin(sinD * sinPhi + cosD * cosPhi * cosH));
    }

    // Máximo: o instante em que o eixo da sombra passa mais perto do lugar (Newton sobre u·a + v·b = 0).
    var mid = 0.0;
    for (var k = 0; k < 50; k++) {
      final s = at(mid), step = (s.u * s.a + s.v * s.b) / s.n2;
      mid -= step;
      if (step.abs() < 1e-6) break;
    }
    final m0 = at(mid);
    if (m0.magnitude <= 0) return null;

    // 1º e 4º contatos: penumbra tocando o lugar.
    double contact(double sign) {
      double tau(_B s) {
        final n = math.sqrt(s.n2), q = (s.a * s.v - s.u * s.b) / n / s.l1;
        return math.sqrt(math.max(0, 1 - q * q)) * s.l1 / n;
      }

      var t = mid + sign * tau(m0);
      for (var k = 0; k < 50; k++) {
        final s = at(t), step = (s.u * s.a + s.v * s.b) / s.n2 - sign * tau(s);
        t -= step;
        if (step.abs() < 1e-6) break;
      }
      return t;
    }

    final span = _visibleSpan(contact(-1), mid, contact(1), (t) => at(t).alt > -0.00524);
    if (span == null) return null;
    final (s, mx, f) = span;
    return (startUtc: utcOf(s), maxUtc: utcOf(mx), endUtc: utcOf(f), magnitude: at(mx).magnitude);
  }
}

/// O estado da sombra no plano fundamental para um lugar num instante (nomes do Explanatory Supplement).
class _B {
  _B(this.u, this.v, this.a, this.b, this.l1, this.l2, this.alt);
  final double u, v, a, b, l1, l2, alt;
  double get n2 => a * a + b * b;

  /// A magnitude local: a razão Lua/Sol dentro da faixa central, senão a fração do diâmetro do Sol coberta.
  double get magnitude {
    final m = math.sqrt(u * u + v * v);
    return m < l2.abs() ? (l1 - l2) / (l1 + l2) : (l1 - m) / (l1 + l2);
  }
}

/// Eclipse lunar: os 22 números de cada eclipse do `LE2001.js` (JD do máximo, t0, ΔT, magnitude penumbral e umbral, tipo,
/// tempo sideral em t0, paralaxe e semidiâmetro da Lua; P1, U1, U2, máximo, U3, U4, P4 em horas desde t0; ascensão reta e
/// declinação da Lua em 3 termos).
class LunarEclipse extends Eclipse {
  LunarEclipse(super.date, super.e) {
    if (e.length != 22) throw FormatException('eclipse lunar $date: 22 elementos, veio ${e.length}');
  }

  @override
  double get _deltaT => e[2];

  /// Magnitude umbral.
  double get umbralMagnitude => e[4];

  @override
  (int, int) get span => (utcOf(e[10]), utcOf(e[14]));

  @override
  EclipseView? viewFrom(double latDeg, double lonDeg) {
    final phi = latDeg * _deg, lonW = -lonDeg * _deg;
    bool up(double t) {
      final ra = (e[18] * t + e[17]) * t + e[16];
      final dec = ((e[21] * t + e[20]) * t + e[19]) * _deg;
      final h = (15 * (e[6] + (t - e[2] / 3600) * 1.00273791) - ra) * _deg - lonW;
      var alt = math.asin(math.sin(phi) * math.sin(dec) + math.cos(phi) * math.cos(dec) * math.cos(h));
      alt -= math.asin(math.sin(e[7] * _deg) * math.cos(alt)); // paralaxe: altura topocêntrica
      return alt / _deg >= e[8] - 0.5667;
    }

    final span = _visibleSpan(e[10], e[12], e[14], up);
    if (span == null) return null;
    final (s, mx, f) = span;
    return (startUtc: utcOf(s), maxUtc: utcOf(mx), endUtc: utcOf(f), magnitude: umbralMagnitude);
  }
}
