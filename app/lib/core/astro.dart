/// Astronomia offline (docs/GDD.md, "Tempo, astronomia e clima"): a altura do sol pela data e pela posição, a luz
/// do mapa que sai dela e a fase da lua. Dart puro, sem rede. O sol é só desenho e HUD. A lua cheia no perigeu força a
/// Lua Dupla da época 7 em diante (`climate.dart`, `AstroRule`): só a partir do instante UTC, igual em todo aparelho.
library;

import 'dart:math' as math;

const double _deg = math.pi / 180;

/// Dia juliano de [utcSeconds] (segundos UTC desde a época Unix).
double julianDay(int utcSeconds) => utcSeconds / 86400 + 2440587.5;

/// Altura do sol sobre o horizonte, em graus, em ([latDeg], [lonDeg]) no instante [utcSeconds]. Posição solar de
/// baixa precisão (erro abaixo de 0,02°), geométrica: sem refração. Leste positivo em [lonDeg].
double sunAltitudeDeg(double latDeg, double lonDeg, int utcSeconds) {
  final n = julianDay(utcSeconds) - 2451545.0;
  final meanLon = (280.460 + 0.9856474 * n) % 360;
  final anomaly = ((357.528 + 0.9856003 * n) % 360) * _deg;
  final eclLon = (meanLon + 1.915 * math.sin(anomaly) + 0.020 * math.sin(2 * anomaly)) * _deg;
  final obliquity = (23.439 - 0.0000004 * n) * _deg;
  final ra = math.atan2(math.cos(obliquity) * math.sin(eclLon), math.cos(eclLon));
  final dec = math.asin(math.sin(obliquity) * math.sin(eclLon));
  final gmst = (280.46061837 + 360.98564736629 * n) % 360;
  final hourAngle = ((gmst + lonDeg) * _deg) - ra;
  final lat = latDeg * _deg;
  final sinAlt = math.sin(lat) * math.sin(dec) + math.cos(lat) * math.cos(dec) * math.cos(hourAngle);
  return math.asin(sinAlt.clamp(-1.0, 1.0)) / _deg;
}

/// A luz do mapa numa dada altura do sol.
class DayLight {
  const DayLight({required this.night, required this.warm});

  /// 0 de dia, 1 de noite fechada. Cai suave pelo crepúsculo: 0 a partir de +4° de altura e 1 a partir de -12°
  /// (o fim do crepúsculo náutico).
  final double night;

  /// 0 a 1: o tom quente do nascer e do pôr do sol, que aparece com o sol baixo (de -4° a +10°) e some de dia e de noite.
  final double warm;

  bool get isDay => night < 0.5;
}

double _smoothstep(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// A luz para a altura do sol [altitudeDeg]: noite suave, com amanhecer e anoitecer sem corte.
DayLight lightForAltitude(double altitudeDeg) {
  final night = 1 - _smoothstep(-12, 4, altitudeDeg);
  // Sino em torno de +3°: sobe de -4° e desce até +10°.
  final warm = _smoothstep(-4, 3, altitudeDeg) * (1 - _smoothstep(3, 10, altitudeDeg));
  return DayLight(night: night, warm: warm);
}

DayLight dayLightAt(double latDeg, double lonDeg, int utcSeconds) => lightForAltitude(sunAltitudeDeg(latDeg, lonDeg, utcSeconds));

/// Mês sinódico médio, em dias.
const double synodicMonthDays = 29.530588853;

/// Uma lua nova de referência (2000-01-06 18:14 UTC), em dia juliano.
const double _refNewMoonJd = 2451550.26;

/// Idade da lua, em dias desde a última lua nova (0 a 29,53). Fase média: erra até cerca de meio dia, o que basta
/// para o HUD e para as regras de lua cheia.
double moonAgeDays(int utcSeconds) {
  final age = (julianDay(utcSeconds) - _refNewMoonJd) % synodicMonthDays;
  return age < 0 ? age + synodicMonthDays : age;
}

/// A fração do ciclo, de 0 (nova) a 1: 0,25 quarto crescente, 0,5 cheia, 0,75 quarto minguante.
double moonCycle(int utcSeconds) => moonAgeDays(utcSeconds) / synodicMonthDays;

/// A fração iluminada do disco, de 0 a 1.
double moonIllumination(int utcSeconds) => (1 - math.cos(2 * math.pi * moonCycle(utcSeconds))) / 2;

/// A distância da Terra à Lua, em km: os quatro maiores termos da série de Meeus (cap. 47), erro de algumas centenas de km,
/// o bastante para separar a lua cheia no perigeu (~357 mil km) das outras. Da época 7 em diante decide a Lua Dupla (um
/// limite de dado, longe de empates).
double moonDistanceKm(int utcSeconds) {
  final d = julianDay(utcSeconds) - 2451545.0;
  final mp = (134.963 + 13.064993 * d) * _deg; // anomalia média da Lua
  final dd = (297.850 + 12.190749 * d) * _deg; // elongação média
  return 385001 - 20905 * math.cos(mp) - 3699 * math.cos(2 * dd - mp) - 2956 * math.cos(2 * dd) - 570 * math.cos(2 * mp);
}

enum MoonPhase { newMoon, waxingCrescent, firstQuarter, waxingGibbous, fullMoon, waningGibbous, lastQuarter, waningCrescent }

/// A das oito fases, cada uma com um oitavo do ciclo centrado no ponto dela (a lua nova vale ±1/16 do ciclo).
MoonPhase moonPhase(int utcSeconds) => MoonPhase.values[((moonCycle(utcSeconds) * 8) + 0.5).floor() % 8];

const Map<MoonPhase, String> moonPhaseNames = {
  MoonPhase.newMoon: 'Lua nova',
  MoonPhase.waxingCrescent: 'Crescente',
  MoonPhase.firstQuarter: 'Quarto crescente',
  MoonPhase.waxingGibbous: 'Crescente gibosa',
  MoonPhase.fullMoon: 'Lua cheia',
  MoonPhase.waningGibbous: 'Minguante gibosa',
  MoonPhase.lastQuarter: 'Quarto minguante',
  MoonPhase.waningCrescent: 'Minguante',
};

/// O domingo de Páscoa do ano [year] (calendário gregoriano, algoritmo de Meeus/Jones/Butcher), como data UTC à
/// meia-noite. A terça de Carnaval é 47 dias antes e a Quarta-feira de Cinzas, 46.
DateTime easterSunday(int year) {
  final a = year % 19, b = year ~/ 100, c = year % 100, d = b ~/ 4, e = b % 4;
  final f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3, h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final n = h + l - 7 * m + 114;
  return DateTime.utc(year, n ~/ 31, n % 31 + 1);
}

/// Os quatro pontos do ano, na ordem de [seasonInstantUtc]. No hemisfério sul, o de junho é o solstício de inverno.
enum SeasonPoint { marchEquinox, juneSolstice, septemberEquinox, decemberSolstice }

const _seasonMean = <List<double>>[
  [2451623.80984, 365242.37404, 0.05169, -0.00411, -0.00057],
  [2451716.56767, 365241.62603, 0.00325, 0.00888, -0.00030],
  [2451810.21715, 365242.01767, -0.11575, 0.00337, 0.00078],
  [2451900.05952, 365242.74049, -0.06223, -0.00823, 0.00032],
];

// Meeus, "Astronomical Algorithms", tabela 27.C: A, B (graus), C (graus por século juliano).
const _seasonTerms = <List<double>>[
  [485, 324.96, 1934.136], [203, 337.23, 32964.467], [199, 342.08, 20.186], [182, 27.85, 445267.112],
  [156, 73.14, 45036.886], [136, 171.52, 22518.443], [77, 222.54, 65928.934], [74, 296.72, 3034.906],
  [70, 243.58, 9037.513], [58, 119.81, 33718.147], [52, 297.17, 150.678], [50, 21.02, 2281.226],
  [45, 247.54, 29929.562], [44, 325.15, 31555.956], [29, 60.93, 4443.417], [18, 155.12, 67555.328],
  [17, 288.79, 4562.452], [16, 198.04, 62894.029], [14, 199.76, 31436.921], [12, 95.39, 14577.848],
  [12, 287.11, 31931.756], [12, 320.81, 34777.259], [9, 227.73, 1222.114], [8, 15.45, 16859.074],
];

/// O instante (segundos UTC) do equinócio ou solstício [p] do ano [year] (2000 a 3000), pelo cap. 27 de Meeus: erro de
/// cerca de um minuto, o bastante para a data local. ΔT fixo em 69 s (o de 2025): o erro dele não muda a data.
int seasonInstantUtc(int year, SeasonPoint p) {
  final y = (year - 2000) / 1000, c = _seasonMean[p.index];
  final jde0 = c[0] + c[1] * y + c[2] * y * y + c[3] * y * y * y + c[4] * y * y * y * y;
  final t = (jde0 - 2451545.0) / 36525;
  final w = (35999.373 * t - 2.47) * _deg;
  final dl = 1 + 0.0334 * math.cos(w) + 0.0007 * math.cos(2 * w);
  var s = 0.0;
  for (final term in _seasonTerms) {
    s += term[0] * math.cos((term[1] + term[2] * t) * _deg);
  }
  return ((jde0 + 0.00001 * s / dl - 2440587.5) * 86400).round() - 69;
}
