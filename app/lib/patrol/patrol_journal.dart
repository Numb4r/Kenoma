/// O diário da Patrulha (`<documentos>/patrulha.jsonl`): o serviço nunca escreve o save principal; ele acrescenta uma linha
/// JSON por coleta, marcação, fuga, célula, trecho andado ou viagem, com o uid do spawn, e o app incorpora ao abrir.
///
/// Escrita: append com flush por linha. A primeira linha do arquivo é `{"k":"head","id":...}`: o app guarda o id e o
/// deslocamento em bytes do que já incorporou (`settings.patrol_journal`), então incorporar com a Patrulha ainda ativa não
/// apaga nem relê nada, e um arquivo novo (id outro) recomeça do zero. Uma linha cortada no fim (morte no meio da escrita)
/// fica de fora até completar; uma linha estragada no meio é pulada.
///
/// Incorporar é idempotente: uid já coletado não entra de novo. Sem a Patrulha rodando, depois de incorporar o arquivo
/// sai (só havia o que já entrou e, no máximo, uma linha cortada). Marcas expiram contando da hora do diário.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../player/game_state.dart';
import '../player/mark.dart';
import '../world/steps.dart';

const kJournalFile = 'patrulha.jsonl';

/// Em `settings`: `{"id": head, "off": bytes}`.
const kJournalKey = 'patrol_journal';

/// Em `settings`: a Patrulha cujo fim o app ainda não viu (`{"t0", "last", "sparks", "materials", "marks"}`).
const kPatrolRunKey = 'patrol_run';

/// Quem escreve o diário: o serviço da Patrulha (e o debug).
class JournalWriter {
  JournalWriter(this.file, {String Function()? newId}) : _newId = newId ?? _randomId;

  final File file;
  final String Function() _newId;
  bool _checked = false;

  /// Acrescenta [line] e faz flush. Arquivo novo ganha o cabeçalho; um fim sem `\n` (escrita cortada) é fechado antes, para a
  /// linha nova não colar no lixo.
  void write(Map<String, Object?> line) {
    final out = StringBuffer();
    final len = file.existsSync() ? file.lengthSync() : 0;
    if (len == 0) {
      out.writeln(jsonEncode({'k': 'head', 'id': _newId()}));
    } else if (!_checked) {
      final raf = file.openSync();
      try {
        raf.setPositionSync(len - 1);
        if (raf.readByteSync() != 0x0a) out.writeln();
      } finally {
        raf.closeSync();
      }
    }
    _checked = true;
    out.writeln(jsonEncode(line));
    file.writeAsStringSync(out.toString(), mode: FileMode.append, flush: true);
  }

  static String _randomId() {
    final r = math.Random.secure(); // não é lógica de mundo
    return [for (var i = 0; i < 8; i++) r.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
  }
}

/// As linhas completas de [bytes] a partir de [from], o id do cabeçalho e até onde foi lido (o fim da última linha completa).
({String? head, List<Map<String, dynamic>> lines, int end}) parseJournal(Uint8List bytes, int from) {
  String? head;
  final lines = <Map<String, dynamic>>[];
  var start = 0, end = from;
  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] != 0x0a) continue;
    Map<String, dynamic>? j;
    try {
      j = jsonDecode(utf8.decode(bytes.sublist(start, i))) as Map<String, dynamic>;
    } catch (_) {
      j = null; // estragada: pula
    }
    if (start == 0 && j?['k'] == 'head') head = j!['id'] as String?;
    if (start >= from && j != null && j['k'] != 'head') lines.add(j);
    start = i + 1;
    if (start > end) end = start;
  }
  return (head: head, lines: lines, end: end);
}

/// O que uma incorporação trouxe, para o aviso na tela.
class JournalResult {
  int sparks = 0, materials = 0, marks = 0, lines = 0;
  bool ended = false;
}

/// Aplica as [lines] ao [state]. [nowUtc] decide se uma marca já expirou. [onCell] recebe as células z17 visitadas.
JournalResult applyJournal(GameState state, List<Map<String, dynamic>> lines, {required int nowUtc, void Function(int x17, int y17, int tUtc)? onCell}) {
  final res = JournalResult()..lines = lines.length;
  for (final l in lines) {
    final k = l['k'], t = (l['t'] as int?) ?? nowUtc;
    final uid = int.tryParse('${l['uid']}');
    // A Patrulha em curso: contadores do resumo e a hora da última linha (o fim, se o serviço morrer sem escrevê-lo).
    final run = state.settings[kPatrolRunKey] is Map ? Map<String, dynamic>.from(state.settings[kPatrolRunKey] as Map) : null;
    if (run != null && k != 'end') state.setSetting(kPatrolRunKey, run..['last'] = t);
    void bump(String key, int n) {
      if (run == null) return;
      run[key] = ((run[key] as int?) ?? 0) + n;
      state.setSetting(kPatrolRunKey, {...run});
    }

    switch (k) {
      case 'start':
        state.setSetting(kPatrolRunKey, {'t0': t, 'last': t, 'sparks': 0, 'materials': 0, 'marks': 0});
        final steps = l['steps'], boot = l['boot'];
        if (steps is int && boot is int) setPatrolSpans(state, [...patrolSpansOf(state), PatrolSpan(bootUtc: boot, from: steps)]);
      case 'spark' || 'material':
        if (uid == null || state.isDone(uid)) continue;
        final item = l['item'] as String, q = (l['q'] as int?) ?? 1;
        state.add(item, q);
        state.markDone(uid, t);
        state.gainXp(k == 'spark' ? state.balance.spark : state.balance.material, t);
        state.recordEvent(k as String, k == 'spark' ? item.replaceFirst('item.dust.', '') : item, q);
        if (k == 'spark') {
          res.sparks += q;
          bump('sparks', q);
        } else {
          res.materials += q;
          bump('materials', q);
        }
      case 'mark':
        if (uid == null || state.isDone(uid) || state.markOf(uid) != null) continue;
        final m = Mark.fromJson(l['mark'] as Map<String, dynamic>);
        if (!m.activeAt(nowUtc) || !state.addMark(m, nowUtc)) continue; // vencida (conta da hora do diário) ou sem vaga
        res.marks++;
        bump('marks', 1);
      case 'fled':
        if (uid != null && !state.isDone(uid)) state.markDone(uid, t);
      case 'cell':
        onCell?.call(l['x'] as int, l['y'] as int, t);
      case 'walk':
        state.recordEvent('walk_m', '', (l['m'] as int?) ?? 0);
      case 'trip':
        state.recordEvent('trip_m', 'car', (l['m'] as int?) ?? 0);
      case 'end':
        _closeSpans(state, l['steps'] as int?);
        _summary(state, t);
        res.ended = true;
    }
  }
  return res;
}

/// Fecha o trecho de passos aberto em [steps] (a leitura do fim; o serviço não sobrevive a um reinício, então o boot é o do
/// começo). Sem leitura, fica aberto até o app fechar com a dele.
void _closeSpans(GameState state, int? steps) {
  if (steps == null) return;
  setPatrolSpans(state, [for (final p in patrolSpansOf(state)) p.to == null ? PatrolSpan(bootUtc: p.bootUtc, from: p.from, to: math.max(p.from, steps)) : p]);
}

/// O resumo no Chat, com os números da Patrulha que acabou.
void _summary(GameState state, int endUtc) {
  final run = state.settings[kPatrolRunKey];
  if (run is! Map) return;
  state.settings.remove(kPatrolRunKey);
  final t0 = (run['t0'] as int?) ?? endUtc;
  state.deliverMessage('patrol_summary', endUtc, vars: {
    'min': math.max(0, (endUtc - t0) ~/ 60),
    'sparks': (run['sparks'] as int?) ?? 0,
    'materials': (run['materials'] as int?) ?? 0,
    'marks': (run['marks'] as int?) ?? 0,
  });
}

/// Lê [file] do ponto guardado e aplica. [running]: o serviço ainda escreve, então o arquivo fica e só o deslocamento anda;
/// parado, o arquivo sai e uma Patrulha sem linha de fim (o serviço morreu) é fechada aqui, com [steps] para os passos.
Future<JournalResult> incorporateJournal(
  GameState state,
  File file, {
  required bool running,
  required int nowUtc,
  StepReading? steps,
  void Function(int x17, int y17, int tUtc)? onCell,
}) async {
  var res = JournalResult();
  if (await file.exists()) {
    // ponytail: relê o arquivo inteiro (o cabeçalho confere o deslocamento); 2 h de Patrulha dão poucas centenas de KB. Ler só
    // do deslocamento se pesar.
    final bytes = await file.readAsBytes();
    final saved = state.settings[kJournalKey];
    final head = parseJournal(bytes, bytes.length).head;
    final from = saved is Map && saved['id'] == head && (saved['off'] as int? ?? 0) <= bytes.length ? (saved['off'] as int? ?? 0) : 0;
    final read = parseJournal(bytes, from);
    res = applyJournal(state, read.lines, nowUtc: nowUtc, onCell: onCell);
    if (running) {
      state.setSetting(kJournalKey, {'id': head, 'off': read.end});
    } else {
      await file.delete();
      state.settings.remove(kJournalKey);
    }
  }
  if (!running && state.settings[kPatrolRunKey] is Map) {
    // O serviço acabou sem escrever o fim: os passos fecham com a leitura de agora (desconta a mais, nunca em dobro).
    _closeSpans(state, steps?.steps);
    _summary(state, ((state.settings[kPatrolRunKey] as Map)['last'] as int?) ?? nowUtc);
    res.ended = true;
  }
  return res;
}
