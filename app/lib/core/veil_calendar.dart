/// O calendário embarcado na época (docs/GDD.md, "Tempo, astronomia e clima"): as datas fixas da época 7 (Finados, Festa
/// Junina, chuvas de meteoros) e, da época 8 em diante, o calendário do Véu, que traz cada clima de outra região e cada
/// místico ao menos uma vez por ano. Datas móveis offline: Páscoa (Carnaval e Cinzas), equinócios e solstícios
/// (`astro.dart`) e sextas-feiras 13. Tudo pela hora LOCAL do meio da janela (o fuso fixo do modelo do clima) e pela seed:
/// a cidade inteira vê o mesmo. Dart puro.
///
/// Uma regra com [CalendarRule.climates] é um período: a seed escolhe, por ano, um dia do período para cada clima da lista
/// (seguidos, com `consecutive`). Assim todo clima da lista aparece no ano, e o dia muda de ano para ano. Os dias já
/// tomados por uma regra anterior da lista (Carnaval, 14 de julho, as chuvas de meteoros) não entram na escolha.
library;

import 'astro.dart';
import 'fnv.dart';
import 'pcg32.dart';

/// Sal do sorteio da chance por janela (o mesmo da época 7) e o da escolha dos dias dos períodos (época 8).
final int saltCalendar = salt('CAL7');
final int saltVeilDays = salt('VDAY8');

/// Âncoras das datas móveis.
enum CalendarAnchor { easter, marchEquinox, juneSolstice, septemberEquinox, decemberSolstice }

CalendarAnchor _anchor(String s) => switch (s) {
      'easter' => CalendarAnchor.easter,
      'march_equinox' => CalendarAnchor.marchEquinox,
      'june_solstice' => CalendarAnchor.juneSolstice,
      'september_equinox' => CalendarAnchor.septemberEquinox,
      'december_solstice' => CalendarAnchor.decemberSolstice,
      _ => throw FormatException('âncora de calendário desconhecida: $s'),
    };

(int, int)? _pair(Object? v) {
  final l = v as List<dynamic>?;
  return l == null ? null : ((l[0] as num).toInt(), (l[1] as num).toInt());
}

/// O número do dia (dias desde 1970-01-01) de uma data local guardada como UTC.
int dayNumber(DateTime localDate) => localDate.millisecondsSinceEpoch ~/ 86400000;

DateTime _dateOf(int day) => DateTime.fromMillisecondsSinceEpoch(day * 86400000, isUtc: true);

bool _inHours((int, int)? h, int hour) => h == null || (h.$1 <= h.$2 ? hour >= h.$1 && hour < h.$2 : hour >= h.$1 || hour < h.$2);

/// Um evento do calendário. A data vale se bate tudo o que a regra traz: o mês ([month] ou [months]), os dias do mês
/// [days], o dia da semana [weekday] (1 segunda a 7 domingo) e a âncora móvel [anchor] com [offsetDays] (dias depois
/// dela, `[de, até]`). Na data, só as horas locais [hours] (`[início, fim)`, pode virar a meia-noite), e com [chance] < 1
/// por um sorteio da seed por janela. [climate] é o clima de todo dia que bate; [climates] faz da regra um período.
class CalendarRule {
  const CalendarRule({
    required this.id,
    this.climate,
    this.climates = const [],
    this.month,
    this.months,
    this.days,
    this.weekday,
    this.anchor,
    this.offsetDays = (0, 0),
    this.hours,
    this.chance = 1,
    this.consecutive = false,
  });

  factory CalendarRule.fromJson(Map<String, dynamic> j) {
    final r = CalendarRule(
      id: j['id'] as String,
      climate: j['climate'] as String?,
      climates: [for (final c in (j['climates'] as List<dynamic>?) ?? const []) c as String],
      month: (j['month'] as num?)?.toInt(),
      months: (j['months'] as List<dynamic>?)?.map((m) => (m as num).toInt()).toSet(),
      days: _pair(j['days']),
      weekday: (j['weekday'] as num?)?.toInt(),
      anchor: j['anchor'] == null ? null : _anchor(j['anchor'] as String),
      offsetDays: _pair(j['offset_days']) ?? (0, 0),
      hours: _pair(j['hours']),
      chance: (j['chance'] as num?)?.toDouble() ?? 1,
      consecutive: j['consecutive'] as bool? ?? false,
    );
    if ((r.climate == null) == r.climates.isEmpty) throw FormatException('regra de calendário ${r.id}: um clima ou uma lista de climas');
    if (r.month == null && r.months == null && r.days == null && r.weekday == null && r.anchor == null) {
      throw FormatException('regra de calendário ${r.id} sem data');
    }
    return r;
  }

  final String id;
  final String? climate;
  final List<String> climates;
  final int? month;
  final Set<int>? months;
  final (int, int)? days;
  final int? weekday;
  final CalendarAnchor? anchor;
  final (int, int) offsetDays;
  final (int, int)? hours;
  final double chance;
  final bool consecutive;

  /// É um período (a seed escolhe um dia por clima da lista).
  bool get picked => climates.isNotEmpty;

  /// Todos os climas que a regra pode forçar.
  List<String> get allClimates => [?climate, ...climates];

  /// A data local [local] bate (sem olhar as horas). [anchorDay] dá o dia da âncora no ano.
  bool matchesDate(DateTime local, {int Function(CalendarAnchor a, int year)? anchorDay}) {
    if (month != null && local.month != month) return false;
    if (months != null && !months!.contains(local.month)) return false;
    final d = days;
    if (d != null && (local.day < d.$1 || local.day > d.$2)) return false;
    if (weekday != null && local.weekday != weekday) return false;
    final a = anchor;
    if (a != null) {
      if (anchorDay == null) return false;
      final k = dayNumber(local) - anchorDay(a, local.year);
      if (k < offsetDays.$1 || k > offsetDays.$2) return false;
    }
    return true;
  }

  bool matchesHour(int hour) => _inHours(hours, hour);

  /// A data e a hora locais batem (a regra de data fixa da época 7).
  bool matches(DateTime local, {int Function(CalendarAnchor a, int year)? anchorDay}) => matchesDate(local, anchorDay: anchorDay) && matchesHour(local.hour);
}

/// O que o calendário força numa janela: a regra e o clima.
typedef CalendarHit = ({CalendarRule rule, String climate});

/// As regras de uma época, com os dias escolhidos de cada período guardados por seed e ano.
class VeilCalendar {
  VeilCalendar(this.rules, {required this.localOffsetH});

  final List<CalendarRule> rules;
  final int localOffsetH;

  final _anchors = <(CalendarAnchor, int), int>{};
  final _picks = <(int, int), List<Map<int, String>>>{};

  /// O dia local da âncora [a] no ano [year].
  int anchorDay(CalendarAnchor a, int year) => _anchors.putIfAbsent((a, year), () {
        if (a == CalendarAnchor.easter) return dayNumber(easterSunday(year));
        final p = SeasonPoint.values[a.index - 1];
        return (seasonInstantUtc(year, p) + localOffsetH * 3600) ~/ 86400;
      });

  /// Para cada regra (na ordem), os dias escolhidos no ano e o clima de cada um. Vazio nas regras de data fixa.
  List<Map<int, String>> picksOf(int seed, int year) => _picks.putIfAbsent((seed, year), () {
        if (_picks.length > 16) _picks.clear();
        final first = dayNumber(DateTime.utc(year)), end = dayNumber(DateTime.utc(year + 1));
        final taken = <int>{};
        final out = <Map<int, String>>[];
        for (final r in rules) {
          final days = [for (var d = first; d < end; d++) if (!taken.contains(d) && r.matchesDate(_dateOf(d), anchorDay: anchorDay)) d];
          if (!r.picked) {
            taken.addAll(days);
            out.add(const {});
            continue;
          }
          final rng = Pcg32(fnv1a64([seed, year, fnv1a64Bytes(r.id.codeUnits), saltVeilDays]), saltKenoma);
          final k = r.climates.length;
          final List<int> chosen;
          if (r.consecutive) {
            final starts = [for (var j = 0; j + k <= days.length; j++) if (days[j + k - 1] - days[j] == k - 1) j];
            final s = starts.isEmpty ? 0 : starts[rng.nextInt(starts.length)];
            chosen = days.sublist(s, (s + k).clamp(0, days.length));
          } else {
            for (var j = 0; j < k && j < days.length; j++) {
              final o = j + rng.nextInt(days.length - j);
              final tmp = days[j];
              days[j] = days[o];
              days[o] = tmp;
            }
            chosen = days.take(k).toList();
          }
          final cs = [...r.climates];
          for (var j = cs.length - 1; j > 0; j--) {
            final o = rng.nextInt(j + 1);
            final tmp = cs[j];
            cs[j] = cs[o];
            cs[o] = tmp;
          }
          out.add({for (var j = 0; j < chosen.length; j++) chosen[j]: cs[j]});
          taken.addAll(chosen);
        }
        return out;
      });

  /// O evento da janela [window] (meio em [midUtc]), ou `null`. [skipped] tira regras pelo id (o feed assinado).
  CalendarHit? at(int seed, int window, int midUtc, {bool Function(String id)? skipped}) {
    if (rules.isEmpty) return null;
    final local = DateTime.fromMillisecondsSinceEpoch((midUtc + localOffsetH * 3600) * 1000, isUtc: true);
    List<Map<int, String>>? picks;
    for (final (i, r) in rules.indexed) {
      if (skipped != null && skipped(r.id)) continue;
      final String climate;
      if (r.picked) {
        picks ??= picksOf(seed, local.year);
        final c = picks[i][dayNumber(local)];
        if (c == null || !r.matchesHour(local.hour)) continue;
        climate = c;
      } else {
        if (!r.matches(local, anchorDay: anchorDay)) continue;
        climate = r.climate!;
      }
      if (r.chance < 1 && Pcg32(fnv1a64([seed, window, fnv1a64Bytes(r.id.codeUnits), saltCalendar]), saltKenoma).nextFloat() >= r.chance) continue;
      return (rule: r, climate: climate);
    }
    return null;
  }
}
