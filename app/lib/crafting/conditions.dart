/// As condições de agora e aqui (docs/GDD.md, "Condições, não lugares"): noite, clima, fase da lua, água perto, bioma e
/// estação do ano, lidas do mesmo estado do mundo que o mapa usa. Servem às receitas, aos coletores e à qualidade do
/// material bruto. Dart puro.
library;

import '../core/astro.dart';
import 'crafting_data.dart';
import 'quality.dart';

/// O grupo de fase da lua em [utc].
MoonGroup moonGroupAt(int utc) => switch (moonPhase(utc)) {
      MoonPhase.newMoon => MoonGroup.newMoon,
      MoonPhase.waxingCrescent || MoonPhase.firstQuarter || MoonPhase.waxingGibbous => MoonGroup.waxing,
      MoonPhase.fullMoon => MoonGroup.full,
      _ => MoonGroup.waning,
    };

/// O primeiro instante a partir de [utc] (em passos de 3 h, até 40 dias) em que a lua está no grupo [g].
int nextMoonGroup(MoonGroup g, int utc) {
  for (var t = utc; t < utc + 40 * 86400; t += 3 * 3600) {
    if (moonGroupAt(t) == g) return t;
  }
  return utc;
}

/// As estações astronômicas do hemisfério sul: o verão começa no solstício de dezembro.
YearSeason seasonAt(int utc) {
  final year = DateTime.fromMillisecondsSinceEpoch(utc * 1000, isUtc: true).year;
  if (utc < seasonInstantUtc(year, SeasonPoint.marchEquinox)) return YearSeason.summer;
  if (utc < seasonInstantUtc(year, SeasonPoint.juneSolstice)) return YearSeason.autumn;
  if (utc < seasonInstantUtc(year, SeasonPoint.septemberEquinox)) return YearSeason.winter;
  if (utc < seasonInstantUtc(year, SeasonPoint.decemberSolstice)) return YearSeason.spring;
  return YearSeason.summer;
}

/// Quando começa a próxima [s] a partir de [utc] (agora, se já é ela).
int nextSeason(YearSeason s, int utc) {
  if (seasonAt(utc) == s) return utc;
  final year = DateTime.fromMillisecondsSinceEpoch(utc * 1000, isUtc: true).year;
  final point = switch (s) {
    YearSeason.summer => SeasonPoint.decemberSolstice,
    YearSeason.autumn => SeasonPoint.marchEquinox,
    YearSeason.winter => SeasonPoint.juneSolstice,
    YearSeason.spring => SeasonPoint.septemberEquinox,
  };
  final t = seasonInstantUtc(year, point);
  return t > utc ? t : seasonInstantUtc(year + 1, point);
}

/// Os climas de sol forte.
const kSunnyClimates = {'clear', 'strong_sun', 'heat_wave'};

/// O momento e o lugar do jogador (ou de um coletor plantado).
class Here {
  const Here({required this.utc, required this.lat, required this.lon, required this.sunAltDeg, required this.climate, this.events = const [], this.waterM, this.biome});

  final int utc;
  final double lat;
  final double lon;
  final double sunAltDeg;

  /// O id do clima da célula (com a pilha de clima, `rain+cold`, partida em [climates]).
  final String climate;

  /// Eventos do calendário ativos.
  final List<String> events;

  /// Distância até a água mais perto, `null` se nenhuma na busca.
  final double? waterM;

  /// A chave de bioma da célula (`green`, `water`, `sacred`, `urban`...).
  final String? biome;

  List<String> get climates => climate.split('+');
  MoonGroup get moon => moonGroupAt(utc);
  YearSeason get season => seasonAt(utc);
  bool night(CraftingBalance b) => sunAltDeg < b.nightSunDeg;
  bool strongSun(CraftingBalance b) => sunAltDeg >= b.strongSunDeg && climates.any(kSunnyClimates.contains);
}

/// Uma condição que falta: o que pede e quando (ou onde) vai valer.
typedef Unmet = ({String what, String when});

String _inTime(int s) {
  if (s < 3600) return 'em ${(s / 60).ceil()} min';
  if (s < 2 * 86400) return 'em ${(s / 3600).round()} h';
  return 'em ${(s / 86400).round()} dias';
}

/// O que falta de [n] em [h]. Vazio: pode fazer agora.
List<Unmet> unmetNeeds(Needs n, Here h, CraftingBalance b, {String Function(String climate)? climateName}) {
  final out = <Unmet>[];
  if (n.night && !h.night(b)) {
    var t = h.utc;
    while (t < h.utc + 86400 && sunAltitudeDeg(h.lat, h.lon, t) >= b.nightSunDeg) {
      t += 600;
    }
    out.add((what: 'à noite', when: _inTime(t - h.utc)));
  }
  if (n.daySun && !h.strongSun(b)) out.add((what: 'sol forte de dia', when: h.night(b) ? 'amanhã, sem nuvem' : 'quando abrir o sol'));
  if (n.waterM != null && (h.waterM == null || h.waterM! > n.waterM!)) {
    out.add((what: 'perto de água', when: h.waterM == null ? 'sem água por perto' : 'água a ${h.waterM!.round()} m'));
  }
  if (n.biomes.isNotEmpty && !n.biomes.contains(h.biome)) out.add((what: n.biomes.contains('green') ? 'em área verde' : 'em ${n.biomes.join(' ou ')}', when: 'noutro lugar'));
  if (n.moon.isNotEmpty && !n.moon.contains(h.moon)) {
    final next = n.moon.map((g) => nextMoonGroup(g, h.utc)).reduce((a, b) => a < b ? a : b);
    out.add((what: n.moon.map((g) => g.label).join(' ou '), when: _inTime(next - h.utc)));
  }
  if (n.season != null && h.season != n.season) out.add((what: 'no ${n.season!.label}', when: _inTime(nextSeason(n.season!, h.utc) - h.utc)));
  if (n.climates.isNotEmpty && !n.climates.any(h.climates.contains)) {
    out.add((what: n.climates.map(climateName ?? (c) => c).join(' ou '), when: 'quando o tempo virar'));
  }
  return out;
}

/// A qualidade de um bruto pego em [h]: [base], um nível a mais no lugar certo e outro na fase da lua certa
/// (`crafting.quality.raw` do `balance.json`).
Quality rawQuality(String itemId, Here h, CraftingBalance b, {Quality base = Quality.common}) {
  final r = b.rawQuality[itemId];
  if (r == null) return base;
  var up = 0;
  if (r.biomes.contains(h.biome)) up++;
  if (r.moon.contains(h.moon)) up++;
  return base.up(up);
}
