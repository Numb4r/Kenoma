/// Contador de passos opcional: o sensor do Android acumula passos desde o boot; a cada `per_spark` passos o
/// Conjurador ganha UMA Fagulha comum do bioma onde esteve por último, até `daily_cap` passos convertidos por dia local.
/// Lógica pura; o sensor fica em `device_sensors.dart`. Os números vivem em `balance.json` (bloco `steps`).
///
/// Reinicialização: junto com a leitura vem a hora do boot (relógio de agora menos `SystemClock.elapsedRealtime`). Boot
/// diferente do guardado é reinício, e contam os passos desde ele; mesmo boot com leitura menor não conta nada. Saves sem
/// a hora do boot (até a 0.15) caem na regra antiga uma vez: leitura menor que a anterior é reinício.
///
/// Patrulha: os trechos do contador andados com ela ligada (`steps_patrol`, lidos pelo serviço ao começar e ao terminar)
/// saem da conta; quem recompensa esses passos é a própria Patrulha.
library;

import 'dart:math' as math;

import '../core/epochs.dart';
import '../player/game_state.dart';
import '../player/progression.dart' show localDay;

class StepsBalance {
  const StepsBalance({required this.perSpark, required this.maxJump, this.dailyCap = 12000, this.milestones = const [5000, 10000], this.bootToleranceS = 120});

  factory StepsBalance.fromJson(Map<String, dynamic> balance) {
    final s = balance['steps'] as Map<String, dynamic>;
    return StepsBalance(
      perSpark: s['per_spark'] as int,
      maxJump: s['max_jump'] as int,
      dailyCap: (s['daily_cap'] as int?) ?? 12000,
      milestones: [for (final m in (s['milestones'] as List<dynamic>?) ?? const [5000, 10000]) m as int],
      bootToleranceS: (s['boot_tolerance_s'] as int?) ?? 120,
    );
  }

  /// Passos para cada Fagulha.
  final int perSpark;

  /// Uma leitura que salta mais que isto de uma vez é ignorada (sensor ou dado estranho).
  final int maxJump;

  /// Passos convertidos em Fagulhas por dia local; o que passa disso não vira nada.
  final int dailyCap;

  /// Passos do dia em que o Familiar comenta (`steps_5k`, `steps_10k` em `mentor.json`).
  final List<int> milestones;

  /// Diferença na hora do boot que ainda conta como o mesmo boot (o relógio do aparelho se acerta sozinho).
  final int bootToleranceS;
}

/// Uma leitura do sensor: passos desde o boot e a hora do boot em segundos UTC (`null` se a plataforma não deu).
class StepReading {
  const StepReading(this.steps, [this.bootUtc]);

  final int steps;
  final int? bootUtc;
}

/// Um trecho do contador andado com a Patrulha: do valor [from] ao [to] (`null` enquanto ela está ligada), no boot [bootUtc].
class PatrolSpan {
  const PatrolSpan({required this.bootUtc, required this.from, this.to});

  factory PatrolSpan.fromJson(List<dynamic> j) => PatrolSpan(bootUtc: j[0] as int, from: j[1] as int, to: j[2] as int?);

  final int bootUtc;
  final int from;
  final int? to;

  List<Object?> toJson() => [bootUtc, from, to];
}

/// O que se guarda entre leituras. [day] é o dia local de [today] (passos vistos hoje) e [converted] (os que viraram
/// Fagulha hoje, até o teto); [milestone] é quantos marcos do dia o Familiar já comentou.
class StepState {
  const StepState({this.last, this.remainder = 0, this.bootUtc, this.day, this.today = 0, this.converted = 0, this.milestone = 0});

  final int? last;
  final int remainder;
  final int? bootUtc;
  final int? day;
  final int today;
  final int converted;
  final int milestone;

  StepState copyWith({int? last, int? remainder, int? bootUtc, int? day, int? today, int? converted, int? milestone}) => StepState(
        last: last ?? this.last,
        remainder: remainder ?? this.remainder,
        bootUtc: bootUtc ?? this.bootUtc,
        day: day ?? this.day,
        today: today ?? this.today,
        converted: converted ?? this.converted,
        milestone: milestone ?? this.milestone,
      );
}

class StepResult {
  const StepResult(this.state, this.sparks, {this.milestones = const []});

  final StepState state;
  final int sparks;

  /// Os marcos do dia que esta leitura passou (5000, 10000).
  final List<int> milestones;
}

bool _sameBoot(int? a, int? b, int tol) => a != null && b != null && (a - b).abs() <= tol;

/// Quantos passos do trecho [a, b] do contador caem em trechos da Patrulha do boot [bootUtc].
int patrolOverlap(int a, int b, int? bootUtc, List<PatrolSpan> spans, int tol) {
  var n = 0;
  for (final s in spans) {
    if (!_sameBoot(s.bootUtc, bootUtc, tol)) continue;
    n += math.max(0, math.min(b, s.to ?? b) - math.max(a, s.from));
  }
  return math.min(n, b - a);
}

/// Aplica a leitura [r] do sensor ao [state] no dia local [day].
///
/// - Primeira leitura: só fixa a base, não ganha nada.
/// - Boot diferente do guardado: o celular reiniciou e o sensor voltou a zero; contam os passos desde o boot.
/// - Mesmo boot e leitura menor: não conta (nunca passos negativos); só refaz a base.
/// - Salto maior que [StepsBalance.maxJump]: ignorado, só atualiza a base.
/// - Os passos dentro de [patrol] não contam; os do dia passam do teto sem virar Fagulha.
StepResult applySteps(StepState state, StepReading r, StepsBalance b, {required int day, List<PatrolSpan> patrol = const []}) {
  final last = state.last;
  if (r.steps < 0) return StepResult(state, 0);
  final fresh = state.day == day ? state : state.copyWith(day: day, today: 0, converted: 0, milestone: 0);
  StepState rebase() => StepState(last: r.steps, remainder: fresh.remainder, bootUtc: r.bootUtc ?? fresh.bootUtc, day: day, today: fresh.today, converted: fresh.converted, milestone: fresh.milestone);
  if (last == null) return StepResult(rebase(), 0);
  final rebooted = state.bootUtc != null && r.bootUtc != null ? !_sameBoot(state.bootUtc, r.bootUtc, b.bootToleranceS) : r.steps < last;
  if (!rebooted && r.steps < last) return StepResult(rebase(), 0);
  final from = rebooted ? 0 : last;
  final delta = r.steps - from;
  if (delta > b.maxJump) return StepResult(rebase(), 0);
  final counted = delta - patrolOverlap(from, r.steps, r.bootUtc, patrol, b.bootToleranceS);
  final convert = math.max(0, math.min(counted, b.dailyCap - fresh.converted));
  final total = fresh.remainder + convert;
  final today = fresh.today + delta; // o Perfil mostra o que foi andado, com ou sem Patrulha
  final passed = [for (final m in b.milestones.skip(fresh.milestone)) if (today >= m) m];
  return StepResult(
    StepState(
      last: r.steps,
      remainder: total % b.perSpark,
      bootUtc: r.bootUtc ?? fresh.bootUtc,
      day: day,
      today: today,
      converted: fresh.converted + convert,
      milestone: fresh.milestone + passed.length,
    ),
    total ~/ b.perSpark,
    milestones: passed,
  );
}

/// A Fagulha comum de [biomeKey]: a de maior peso na tabela de Fagulhas da época. Sem bioma conhecido (ou fora
/// da tabela) usa `urban`. `null` se a época não tem Fagulhas.
String? sparkForBiome(Epoch epoch, String? biomeKey) {
  final spark = epoch.items.where((i) => i.kind == 'spark');
  if (spark.isEmpty) return null;
  final table = spark.first.table;
  final entries = table[biomeKey] ?? table['urban'];
  if (entries == null || entries.isEmpty) return null;
  var best = entries.first;
  for (final e in entries) {
    if (e.weight > best.weight) best = e;
  }
  return best.id;
}

// Chaves em `GameState.settings`. `steps_last` e `steps_rem` vêm da 0.15 e continuam valendo.
const _kLast = 'steps_last';
const _kRemainder = 'steps_rem';
const _kBoot = 'steps_boot';
const _kDay = 'steps_day';
const _kToday = 'steps_today';
const _kConverted = 'steps_conv';
const _kMilestone = 'steps_ms';

/// Os trechos da Patrulha ainda por descontar (`[boot, de, até|null]`). Quem escreve é a incorporação do diário.
const kStepsPatrolKey = 'steps_patrol';

List<PatrolSpan> patrolSpansOf(GameState s) => [
      for (final j in (s.settings[kStepsPatrolKey] as List<dynamic>?) ?? const []) PatrolSpan.fromJson(j as List<dynamic>),
    ];

void setPatrolSpans(GameState s, List<PatrolSpan> spans) =>
    spans.isEmpty ? s.settings.remove(kStepsPatrolKey) : s.setSetting(kStepsPatrolKey, [for (final p in spans) p.toJson()]);

/// Os passos do dia [day] (o Perfil mostra), ou 0 se o contador não leu nada hoje.
int stepsToday(GameState s, int day) => s.settings[_kDay] == day ? ((s.settings[_kToday] as int?) ?? 0) : 0;

int? _int(Object? v) => v is int ? v : null;

/// Une sensor, estado salvo (nos `settings` do save), inventário, chat e evento.
class StepTracker {
  StepTracker({required this.state, required this.balance, required this.read, int Function()? nowUtc}) : nowUtc = nowUtc ?? _realNow;

  final GameState state;
  final StepsBalance balance;

  /// Passos desde o boot e a hora do boot, ou `null` (sem sensor, sem permissão ou sem resposta).
  final Future<StepReading?> Function() read;

  /// O relógio do jogo, para o dia local e a hora das falas.
  final int Function() nowUtc;

  StepState get saved => StepState(
        last: _int(state.settings[_kLast]),
        remainder: _int(state.settings[_kRemainder]) ?? 0,
        bootUtc: _int(state.settings[_kBoot]),
        day: _int(state.settings[_kDay]),
        today: _int(state.settings[_kToday]) ?? 0,
        converted: _int(state.settings[_kConverted]) ?? 0,
        milestone: _int(state.settings[_kMilestone]) ?? 0,
      );

  /// Lê o sensor e converte. Devolve quantas Fagulhas entraram. [epoch] é a vigente; o bioma vem de `last_biome`.
  Future<int> sync(Epoch epoch) async {
    try {
      final reading = await read();
      if (reading == null) return 0;
      final now = nowUtc();
      final spans = patrolSpansOf(state);
      final r = applySteps(saved, reading, balance, day: localDay(now), patrol: spans);
      _store(r.state);
      // Trechos já fechados abaixo da leitura ou de outro boot não descontam mais nada.
      setPatrolSpans(state, [
        for (final p in spans)
          if (_sameBoot(p.bootUtc, reading.bootUtc, balance.bootToleranceS) && (p.to == null || p.to! > reading.steps)) p,
      ]);
      for (final m in r.milestones) {
        state.deliverMessage('steps_${m ~/ 1000}k', now);
      }
      if (r.sparks == 0) return 0;
      final biome = state.settings['last_biome'];
      final item = sparkForBiome(epoch, biome is String ? biome : null);
      if (item == null) return 0;
      state.add(item, r.sparks);
      state.recordEvent('steps', item.replaceFirst('item.dust.', ''), r.sparks);
      return r.sparks;
    } catch (_) {
      return 0;
    }
  }

  void _store(StepState s) {
    state.setSetting(_kLast, s.last!);
    state.setSetting(_kRemainder, s.remainder);
    if (s.bootUtc != null) state.setSetting(_kBoot, s.bootUtc!);
    if (s.day != null) state.setSetting(_kDay, s.day!);
    state.setSetting(_kToday, s.today);
    state.setSetting(_kConverted, s.converted);
    state.setSetting(_kMilestone, s.milestone);
  }

  /// Esquece a base ao desligar o contador: ao ligar de novo os passos de enquanto esteve desligado não contam. O que já
  /// foi convertido hoje fica (o teto é do dia).
  void reset() {
    state.settings.remove(_kLast);
    state.settings.remove(_kRemainder);
    state.settings.remove(_kBoot);
  }
}

int _realNow() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
