import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/patrol/patrol_journal.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/player/mark.dart';
import 'package:kenoma/world/steps.dart';

import '../support/fixtures.dart';

const t0 = 1790040000;

GameState fresh() => GameState(groupCode: 'KENOMA-TESTE', balance: loadProgressBalance());

Map<String, Object?> spark(int uid, {int t = t0, int q = 1}) => {'k': 'spark', 'uid': '$uid', 't': t, 'item': 'item.dust.fire', 'q': q};

Map<String, Object?> mark(int uid, {int t = t0, int duration = 7200}) => {
      'k': 'mark',
      'uid': '$uid',
      't': t,
      'mark': Mark(uid: '$uid', speciesId: 'soot.eco', level: 2, x: 1, y: 2, cellX: 0, cellY: 0, window: 1, markedUtc: t, expiresUtc: t + duration).toJson(),
    };

void main() {
  late Directory dir;
  late File file;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('patrulha');
    file = File('${dir.path}/$kJournalFile');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  JournalWriter writer() => JournalWriter(file, newId: () => 'abc');

  group('parseJournal', () {
    test('linha cortada no fim fica de fora; linha estragada no meio é pulada', () {
      final text = '${jsonEncode({'k': 'head', 'id': 'x'})}\n{"k":"spark","uid":"1"}\nlixo{\n{"k":"spark","uid":"2"}\n{"k":"spa';
      final r = parseJournal(Uint8List.fromList(utf8.encode(text)), 0);
      expect(r.head, 'x');
      expect(r.lines.map((l) => l['uid']), ['1', '2']);
      expect(r.end, text.lastIndexOf('\n') + 1);
    });
  });

  group('JournalWriter', () {
    test('arquivo novo ganha cabeçalho; um fim cortado é fechado antes da linha nova', () {
      writer().write(spark(1));
      file.writeAsStringSync('{"k":"spa', mode: FileMode.append); // morreu no meio da escrita
      writer().write(spark(2));
      final r = parseJournal(file.readAsBytesSync(), 0);
      expect(r.head, 'abc');
      expect(r.lines.map((l) => l['uid']), ['1', '2']);
    });
  });

  group('incorporação', () {
    test('ignora uids já coletados e soma o resto, com XP e evento', () async {
      final s = fresh()..markDone(1, t0);
      writer()
        ..write({'k': 'start', 't': t0})
        ..write(spark(1))
        ..write(spark(2, q: 2));
      final r = await incorporateJournal(s, file, running: true, nowUtc: t0 + 60);
      expect((r.sparks, s.count('item.dust.fire'), s.story.count('spark')), (2, 2, 2));
      expect(s.isDone(2), isTrue);
      expect(s.progress.xp, greaterThan(0));
    });

    test('duas incorporações seguidas não duplicam nada', () async {
      final s = fresh();
      writer()
        ..write({'k': 'start', 't': t0})
        ..write(spark(5))
        ..write(mark(6));
      await incorporateJournal(s, file, running: true, nowUtc: t0 + 60);
      final again = await incorporateJournal(s, file, running: true, nowUtc: t0 + 61);
      expect((again.lines, again.sparks, again.marks), (0, 0, 0));
      expect((s.count('item.dust.fire'), s.marks.length), (1, 1));
    });

    test('com a Patrulha ativa: o arquivo fica, o que o serviço escreve depois entra na próxima, e nada repete', () async {
      final s = fresh();
      final w = writer()
        ..write({'k': 'start', 't': t0})
        ..write(spark(10));
      file.writeAsStringSync('{"k":"spark","uid":"11"', mode: FileMode.append); // o serviço no meio de uma linha
      final first = await incorporateJournal(s, file, running: true, nowUtc: t0 + 30);
      expect(first.sparks, 1);
      expect(file.existsSync(), isTrue, reason: 'o serviço ainda escreve');
      file.writeAsStringSync(',"t":$t0,"item":"item.dust.fire","q":1}\n', mode: FileMode.append); // terminou a linha
      w.write(spark(12));
      final second = await incorporateJournal(s, file, running: true, nowUtc: t0 + 60);
      expect(second.sparks, 2, reason: 'a 11, que estava cortada, e a 12');
      expect(s.count('item.dust.fire'), 3);
      w.write({'k': 'end', 't': t0 + 600, 'why': 'user'});
      final last = await incorporateJournal(s, file, running: false, nowUtc: t0 + 700);
      expect((last.sparks, last.ended, file.existsSync()), (0, true, false));
      expect(s.story.chat.delivered.single.id, 'patrol_summary');
      expect(s.story.chat.delivered.single.vars, {'min': '10', 'sparks': '3', 'materials': '0', 'marks': '0'});
      expect(s.settings.containsKey(kJournalKey), isFalse);
    });

    test('arquivo novo (outro cabeçalho) recomeça do zero, mesmo com deslocamento antigo maior', () async {
      final s = fresh()..setSetting(kJournalKey, {'id': 'velho', 'off': 99999});
      writer().write(spark(20));
      expect((await incorporateJournal(s, file, running: true, nowUtc: t0)).sparks, 1);
    });

    test('marca expira contando da hora do diário, não da incorporação', () async {
      final s = fresh();
      writer()
        ..write(mark(30, t: t0, duration: 600))
        ..write(mark(31, t: t0 + 500, duration: 600));
      final r = await incorporateJournal(s, file, running: false, nowUtc: t0 + 700);
      expect(r.marks, 1);
      expect(s.markOf(31)!.expiresUtc, t0 + 1100);
      expect(s.markOf(30), isNull);
    });

    test('marca de Eco já capturado não entra', () async {
      final s = fresh()..markDone(40, t0);
      writer().write(mark(40));
      expect((await incorporateJournal(s, file, running: false, nowUtc: t0 + 1)).marks, 0);
    });

    test('fuga, caminhada, viagem e células', () async {
      final s = fresh();
      final cells = <(int, int)>[];
      writer()
        ..write({'k': 'fled', 'uid': '50', 't': t0})
        ..write({'k': 'walk', 't': t0, 'm': 50})
        ..write({'k': 'trip', 't': t0, 'm': 1200, 'driver': true})
        ..write({'k': 'cell', 't': t0, 'x': 7, 'y': 8});
      await incorporateJournal(s, file, running: false, nowUtc: t0, onCell: (x, y, _) => cells.add((x, y)));
      expect((s.isDone(50), s.story.count('walk_m'), s.story.count('trip_m')), (true, 50, 1200));
      expect(cells, [(7, 8)]);
    });

    test('passos: o começo e o fim da Patrulha viram um trecho descontado', () async {
      final s = fresh();
      writer()
        ..write({'k': 'start', 't': t0, 'steps': 1000, 'boot': 5})
        ..write({'k': 'end', 't': t0 + 60, 'why': 'user', 'steps': 4000, 'boot': 5});
      await incorporateJournal(s, file, running: false, nowUtc: t0 + 60);
      expect(patrolSpansOf(s).map((p) => (p.from, p.to)), [(1000, 4000)]);
    });

    test('o serviço morreu sem escrever o fim: o app fecha a Patrulha com o resumo e a leitura dele', () async {
      final s = fresh();
      writer()
        ..write({'k': 'start', 't': t0, 'steps': 1000, 'boot': 5})
        ..write(spark(60, t: t0 + 300));
      final r = await incorporateJournal(s, file, running: false, nowUtc: t0 + 9000, steps: const StepReading(2500, 5));
      expect(r.ended, isTrue);
      expect(s.story.chat.delivered.single.vars['min'], '5');
      expect(patrolSpansOf(s).single.to, 2500);
      expect(s.settings.containsKey(kPatrolRunKey), isFalse);
    });

    test('o resumo no Chat sai com os números no texto e sobrevive ao save', () async {
      final s = fresh();
      writer()
        ..write({'k': 'start', 't': t0})
        ..write(spark(70, q: 12))
        ..write({'k': 'end', 't': t0 + 34 * 60, 'why': 'time'});
      await incorporateJournal(s, file, running: false, nowUtc: t0 + 34 * 60);
      final entry = GameState.fromJson(jsonDecode(jsonEncode(s.toJson(t0))) as Map<String, dynamic>, loadProgressBalance()).story.chat.delivered.single;
      final text = entry.fill(loadGameData().mentor.byId(entry.id)!.text);
      expect(text, startsWith('34 minutos de Patrulha. 12 Fagulhas e 0 materiais'));
      expect(text, isNot(contains('{')));
    });

    test('sem diário e sem Patrulha em curso, nada muda', () async {
      final s = fresh();
      final r = await incorporateJournal(s, file, running: false, nowUtc: t0);
      expect((r.lines, s.story.chat.delivered.length), (0, 0));
    });
  });
}
