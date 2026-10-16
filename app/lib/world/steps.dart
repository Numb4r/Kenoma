/// Contador de passos opcional: o sensor do Android acumula passos desde o boot; a cada `per_spark` passos o
/// Conjurador ganha UMA Fagulha comum do bioma onde esteve por último. Lógica pura; o sensor fica em `device_sensors.dart`.
/// Os números vivem em `balance.json` (bloco `steps`).
library;

import '../core/epochs.dart';
import '../player/game_state.dart';

class StepsBalance {
  const StepsBalance({required this.perSpark, required this.maxJump});

  factory StepsBalance.fromJson(Map<String, dynamic> balance) {
    final s = balance['steps'] as Map<String, dynamic>;
    return StepsBalance(perSpark: s['per_spark'] as int, maxJump: s['max_jump'] as int);
  }

  /// Passos para cada Fagulha.
  final int perSpark;

  /// Uma leitura que salta mais que isto de uma vez é ignorada (sensor ou dado estranho).
  final int maxJump;
}

/// O que se guarda entre leituras: a última leitura do sensor e o resto que ainda não virou Fagulha.
class StepState {
  const StepState({this.last, this.remainder = 0});

  final int? last;
  final int remainder;
}

class StepResult {
  const StepResult(this.state, this.sparks);

  final StepState state;
  final int sparks;
}

/// Aplica a leitura [reading] do sensor (passos desde o boot) ao [state].
///
/// - Primeira leitura: só fixa a base, não ganha nada.
/// - Leitura menor que a anterior: o celular reiniciou e o sensor voltou a zero; contam os passos desde o boot.
/// - Salto maior que [StepsBalance.maxJump] (nos dois casos): ignorado, só atualiza a base.
StepResult applySteps(StepState state, int reading, StepsBalance b) {
  final last = state.last;
  if (reading < 0) return StepResult(state, 0);
  if (last == null) return StepResult(StepState(last: reading, remainder: state.remainder), 0);
  final delta = reading >= last ? reading - last : reading;
  if (delta > b.maxJump) return StepResult(StepState(last: reading, remainder: state.remainder), 0);
  final total = state.remainder + delta;
  return StepResult(StepState(last: reading, remainder: total % b.perSpark), total ~/ b.perSpark);
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

const _kLast = 'steps_last';
const _kRemainder = 'steps_rem';

/// Une sensor, estado salvo (nos `settings` do save), inventário e evento.
class StepTracker {
  StepTracker({required this.state, required this.balance, required this.read});

  final GameState state;
  final StepsBalance balance;

  /// Passos desde o boot, ou `null` (sem sensor, sem permissão ou sem resposta).
  final Future<int?> Function() read;

  /// Lê o sensor e converte. Devolve quantas Fagulhas entraram. [epoch] é a vigente; o bioma vem de `last_biome`.
  Future<int> sync(Epoch epoch) async {
    try {
      final reading = await read();
      if (reading == null) return 0;
      final last = state.settings[_kLast];
      final rem = state.settings[_kRemainder];
      final r = applySteps(StepState(last: last is int ? last : null, remainder: rem is int ? rem : 0), reading, balance);
      state.setSetting(_kLast, r.state.last!);
      state.setSetting(_kRemainder, r.state.remainder);
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

  /// Esquece a base ao desligar o contador: ao ligar de novo os passos de enquanto esteve desligado não contam.
  void reset() {
    state.settings.remove(_kLast);
    state.settings.remove(_kRemainder);
  }
}
