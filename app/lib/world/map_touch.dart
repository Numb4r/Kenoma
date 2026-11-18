/// O mapa responde ao toque (0.24.2): ponto de ônibus, pombos e maritacas, banca de jornal, árvores, poças, postes, gatos
/// e placas de rua. Regras de todos: só a até `touch_m` (30 m) e a pé. Nada muda o mundo dos amigos: o que é igual para o
/// grupo (a passagem do Ônibus Espectral, a manchete da banca) sai da seed; o resto é cenário local ou recompensa pequena
/// da camada pessoal, com limite por dia no save (`touches`). Dart puro.
library;

import '../core/fnv.dart';

/// As interações. A ordem é estável (o save guarda pelo nome).
enum TouchKind { busStop, flock, newsstand, tree, puddle, lamp, cat, sign }

/// Os limites e números do `balance.json` (`map_touch`).
class TouchBalance {
  const TouchBalance({
    this.touchM = 30,
    this.featherChance = 0.35,
    this.featherPerDay = 3,
    this.treePerDay = 6,
    this.treeChance = 0.6,
    this.catPerDay = 3,
    this.catGiftChance = 0.25,
    this.catGifts = const ['item.scrap'],
    this.catFollowM = 100,
    this.puddlePerDay = 10,
    this.puddleTurnS = 6,
    this.puddleEcoM = 40,
    this.lampPerDay = 10,
    this.humExtraS = 8,
    this.humM = 40,
    this.busEveryMin = (15, 35),
    this.busFirstH = 5,
    this.busLastH = 23,
    this.busApproachS = 8,
    this.busDwellS = 12,
    this.busLeaveS = 8,
    this.busRunM = 70,
  });

  factory TouchBalance.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const TouchBalance();
    Map<String, dynamic> m(String k) => (j[k] as Map<String, dynamic>?) ?? const {};
    double d(Map<String, dynamic> o, String k, double v) => ((o[k] as num?) ?? v).toDouble();
    int i(Map<String, dynamic> o, String k, int v) => (o[k] as int?) ?? v;
    final bus = m('bus');
    final every = (bus['every_min'] as List<dynamic>?) ?? const [15, 35];
    return TouchBalance(
      touchM: d(j, 'touch_m', 30),
      featherChance: d(m('feather'), 'chance', 0.35),
      featherPerDay: i(m('feather'), 'per_day', 3),
      treePerDay: i(m('tree'), 'per_day', 6),
      treeChance: d(m('tree'), 'chance', 0.6),
      catPerDay: i(m('cat'), 'per_day', 3),
      catGiftChance: d(m('cat'), 'gift_chance', 0.25),
      catGifts: [...((m('cat')['gifts'] as List<dynamic>?) ?? const ['item.scrap']).cast<String>()],
      catFollowM: d(m('cat'), 'follow_m', 100),
      puddlePerDay: i(m('puddle'), 'per_day', 10),
      puddleTurnS: d(m('puddle'), 'turn_s', 6),
      puddleEcoM: d(m('puddle'), 'eco_m', 40),
      lampPerDay: i(m('lamp'), 'per_day', 10),
      humExtraS: d(m('lamp'), 'hum_extra_s', 8),
      humM: d(m('lamp'), 'hum_m', 40),
      busEveryMin: (every[0] as int, every[1] as int),
      busFirstH: i(bus, 'first_h', 5),
      busLastH: i(bus, 'last_h', 23),
      busApproachS: d(bus, 'approach_s', 8),
      busDwellS: d(bus, 'dwell_s', 12),
      busLeaveS: d(bus, 'leave_s', 8),
      busRunM: d(bus, 'run_m', 70),
    );
  }

  final double touchM;
  final double featherChance;
  final int featherPerDay;
  final int treePerDay;
  final double treeChance;
  final int catPerDay;
  final double catGiftChance;
  final List<String> catGifts;
  final double catFollowM;
  final int puddlePerDay;
  final double puddleTurnS;
  final double puddleEcoM;
  final int lampPerDay;
  final double humExtraS;
  final double humM;
  final (int, int) busEveryMin;
  final int busFirstH;

  /// 0.24.5, o Ônibus Espectral passando (só cena): segundos chegando, parado e saindo, e os metros que ele anda até o ponto
  /// e depois dele.
  final double busApproachS, busDwellS, busLeaveS, busRunM;
  final int busLastH;

  /// O limite do dia de [k], ou `null` (sem limite: o que só mostra informação).
  int? perDay(TouchKind k) => switch (k) {
        TouchKind.flock => featherPerDay,
        TouchKind.tree => treePerDay,
        TouchKind.cat => catPerDay,
        TouchKind.puddle => puddlePerDay,
        TouchKind.lamp => lampPerDay,
        _ => null,
      };
}

/// O que o save guarda (bloco `touches`): o dia local e, nele, quantas vezes cada interação rendeu e que objetos já deram
/// o que tinham (uma árvore por dia).
class TouchState {
  TouchState({this.day = 0, Map<String, int>? counts, Set<String>? used})
      : counts = counts ?? {},
        used = used ?? {};

  factory TouchState.fromJson(Map<String, dynamic>? j) => j == null
      ? TouchState()
      : TouchState(
          day: (j['day'] as int?) ?? 0,
          counts: {for (final e in ((j['counts'] as Map<String, dynamic>?) ?? const {}).entries) e.key: e.value as int},
          used: {...((j['used'] as List<dynamic>?) ?? const []).cast<String>()},
        );

  int day;
  final Map<String, int> counts;
  final Set<String> used;

  void _roll(int today) {
    if (today == day) return;
    day = today;
    counts.clear();
    used.clear();
  }

  int count(TouchKind k, int today) {
    _roll(today);
    return counts[k.name] ?? 0;
  }

  /// Se [k] ainda rende hoje (e, com [objectKey], se aquele objeto ainda não deu).
  bool canReward(TouchKind k, int today, TouchBalance b, {String? objectKey}) {
    _roll(today);
    final limit = b.perDay(k);
    if (limit != null && (counts[k.name] ?? 0) >= limit) return false;
    return objectKey == null || !used.contains('${k.name}:$objectKey');
  }

  /// Conta uma recompensa de [k] hoje.
  void reward(TouchKind k, int today, {String? objectKey}) {
    _roll(today);
    counts[k.name] = (counts[k.name] ?? 0) + 1;
    if (objectKey != null) used.add('${k.name}:$objectKey');
  }

  Map<String, dynamic> toJson() => {'day': day, 'counts': counts, 'used': [...used]..sort()};
}

/// Se dá para tocar: a até [TouchBalance.touchM] e a pé (até [walkMaxMps]). Nunca de carro.
bool canTouch(double distM, double speedMps, double walkMaxMps, TouchBalance b) => distM <= b.touchM && speedMps <= walkMaxMps;

double _unit(List<int> parts) => (fnv1a64(parts) >>> 11) / (1 << 53);

/// Um sorteio de 0 a 1 da camada pessoal: igual para o mesmo jogador, dia, objeto e vez.
double personalRoll(int playerKey, int day, String objectKey, int n) => _unit([playerKey, day, fnv1a64Bytes(objectKey.codeUnits), n]);

/// A próxima passagem do Ônibus Espectral no ponto [stopKey] a partir de [t] (segundos UTC), e se ela é de noite (fora do
/// horário das linhas: pode ser uma linha que não existe). Sai da seed e do ponto, então é igual para todo o grupo; o ônibus
/// que circular depois tem de seguir este mesmo horário. [localHourOf] dá a hora local de um instante.
({int utc, bool night}) spectralBusNext({required int seed, required int stopKey, required int t, required TouchBalance b, required int Function(int utc) localHourOf}) {
  final (lo, hi) = b.busEveryMin;
  final every = (lo + (fnv1a64([seed, stopKey, 0x6275]) >>> 32) % (hi - lo + 1)) * 60;
  final offset = (fnv1a64([seed, stopKey, 0x6f66]) >>> 32) % every;
  var next = t - ((t - offset) % every);
  if (next < t) next += every;
  final h = localHourOf(next);
  final night = h < b.busFirstH || h >= b.busLastH;
  return (utc: next, night: night);
}

/// Uma manchete do Véu: o título e o corpo, com as lacunas preenchidas.
typedef Headline = ({String title, String body});

/// A manchete da banca [standKey] no dia [day] (dia local), igual para amigos: o grupo e o modelo saem de
/// `hash(seed, época, dia, banca)`. CLIMA vale sempre; EVENTO só com [event] (o nome e os dias até ele); FAMÍLIA só com
/// [family] (a família que anda aparecendo ali). [templates]: os modelos de `mapa.json` (`news`).
Headline? veilHeadline({
  required int seed,
  required int epochId,
  required int day,
  required int standKey,
  required String climate,
  required Map<String, dynamic> templates,
  ({String name, int days})? event,
  String? family,
}) {
  final h = fnv1a64([seed, epochId, day, standKey, 0x6e657773]);
  List<Map<String, dynamic>> list(String k) => [...((templates[k] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>()];
  final groups = <List<Map<String, dynamic>>>[
    list('climate'),
    if (event != null) [for (final m in list('event')) if ((m['today'] == true) == (event.days == 0)) m],
    if (family != null) list('family'),
  ]..removeWhere((g) => g.isEmpty);
  if (groups.isEmpty) return null;
  final g = groups[(h >>> 32) % groups.length];
  final m = g[(fnv1a64([h, 0x746d706c]) >>> 32) % g.length];
  final days = event?.days ?? 0;
  // Concordância (0.24.2): "Faltam 3 dias", mas "Falta 1 dia".
  String fill(String s) => (days == 1 ? s.replaceAll('Faltam {dias} dias', 'Falta 1 dia').replaceAll('{dias} dias', '1 dia') : s)
      .replaceAll('{clima}', climate)
      .replaceAll('{evento}', event?.name ?? '')
      .replaceAll('{dias}', '${event?.days ?? 0}')
      .replaceAll('{familia}', family ?? '');
  return (title: fill(m['title'] as String), body: fill(m['body'] as String));
}

/// A chave estável de um objeto do mapa pela posição (células z21, arredondadas a 1/64).
int placeKey(double x, double y) => fnv1a64([(x * 64).round(), (y * 64).round()]);
