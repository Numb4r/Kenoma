/// Astronomia offline (docs/GDD.md, "Tempo, astronomia e clima"): a altura do sol pela data e pela posição, a luz
/// do mapa que sai dela e a fase da lua. Dart puro, sem rede. Só desenho e HUD: nada aqui decide o que existe no
/// mundo (o mundo vem do hash), então o relógio e a posição do aparelho podem entrar sem quebrar o determinismo.
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
