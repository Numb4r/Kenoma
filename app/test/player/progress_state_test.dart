import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/player/mark.dart';
import 'package:kenoma/save/migrations.dart';
import 'package:kenoma/save/save_store.dart';
import 'package:kenoma/world/spawn_field.dart';

import '../support/fixtures.dart';

WorldSpawn spawn(int uid, {int? level = 7}) =>
    WorldSpawn(uid: uid, kind: 'eco', entryId: 'soot.eco', quantity: 1, x: 10.5, y: 20.25, cellX: 5, cellY: 10, window: 99, level: level);

void main() {
  final b = loadProgressBalance();
  GameState state() => GameState(groupCode: 'KENOMA-TESTE', balance: b);

  group('nível real e override do debug', () {
    test('o nível que o jogo usa é o real; o override do debug manda quando existe', () {
      final s = state();
      expect(s.playerLevel, 1);
      s.gainXp(60, 1790035200);
      expect(s.playerLevel, 2, reason: '60 + bônus de descanso = 120: nível 2');
      s.levelOverride = 9;
      expect(s.playerLevel, 9);
      expect(s.progress.level, 2, reason: 'o real não muda');
      s.levelOverride = null;
      expect(s.playerLevel, 2);
    });
  });

  group('bestiário', () {
    test('vista e capturada por espécie; capturar implica ter visto', () {
      final s = state();
      expect(s.hasCaptured('soot.eco'), isFalse);
      s.markSeen('rill.eco');
      expect((s.bestiary['rill.eco']!.seen, s.bestiary['rill.eco']!.captured), (true, false));
      s.capture(uid: 1, speciesId: 'soot.eco', level: 2, nowUtc: 5);
      expect((s.bestiary['soot.eco']!.seen, s.bestiary['soot.eco']!.captured), (true, true));
      expect(s.hasCaptured('soot.eco'), isTrue);
      s.markSeen('soot.eco');
      expect(s.bestiary['soot.eco']!.captured, isTrue, reason: 'ver de novo não apaga a captura');
    });

    test('destilar o Eco não tira a espécie do bestiário', () {
      final s = state();
      final c = s.capture(uid: 1, speciesId: 'soot.eco', level: 2, nowUtc: 5);
      s.removeCreature(c.uid);
      expect(s.hasCaptured('soot.eco'), isTrue);
    });
  });

  group('marcação', () {
    const t = 1000;
    Mark mark(int uid, {int at = t}) => Mark.of(spawn(uid), nowUtc: at, durationS: b.markDurationS);

    test('prende o sinal por 300 s com o nível já calculado', () {
      expect(b.markDurationS, 300);
      final m = mark(5);
      expect((m.level, m.expiresUtc), (7, t + 300));
      expect(m.activeAt(t + 299), isTrue);
      expect(m.activeAt(t + 300), isFalse);
      expect(m.secondsLeft(t + 100), 200);
    });

    test('no máximo 3 ao mesmo tempo; vencida libera o espaço', () {
      final s = state();
      expect([for (var i = 1; i <= 4; i++) s.addMark(mark(i), t)], [true, true, true, false]);
      expect(s.activeMarks(t), hasLength(3));
      expect(s.addMark(mark(4, at: t + 300), t + 300), isTrue, reason: 'as três primeiras venceram');
      expect(s.activeMarks(t + 300).map((m) => m.uid), ['4']);
    });

    test('o Eco marcado volta como spawn igual, mesmo sem a janela, e soltar tira a marcação', () {
      final s = state();
      s.addMark(mark(5), t);
      final back = s.markOf(5)!.toSpawn();
      expect((back.uid, back.entryId, back.level, back.x, back.y, back.window), (5, 'soot.eco', 7, 10.5, 20.25, 99));
      expect(s.markOf(6), isNull);
      expect(s.removeMark('5'), isTrue);
      expect(s.removeMark('5'), isFalse);
    });

    test('capturar ou fugir acaba com a marcação', () {
      final s = state();
      s.addMark(mark(5), t);
      s.addMark(mark(6), t);
      s.capture(uid: 5, speciesId: 'soot.eco', level: 7, nowUtc: t + 10);
      s.markDone(6, t + 10);
      expect(s.activeMarks(t + 10), isEmpty);
    });
  });

  group('save e migração', () {
    final v1 = <String, dynamic>{
      'schema_version': 1,
      'group_code': 'AAAAA-BBBBB',
      'player_level': 6,
      'saved_utc': 77,
      'inventory': {'item.chalk': 3},
      'collection': [
        {'uid': '42', 'species': 'rill.eco', 'level': 3, 'xp': 0, 'captured_utc': 50},
      ],
      'collected': {'42': 50},
      'future_field': {'x': 1},
    };

    test('v1 vira v2: o nível do debug vira override, o nível real começa em 1 e o bestiário vem da coleção', () {
      final out = migrateSave(v1);
      expect(out['schema_version'], 4);
      expect(out.containsKey('player_level'), isFalse);
      expect(out['level_override'], 6);
      expect(out['player'], {'level': 1, 'xp': 0, 'banked_xp': 0});
      expect(out['circle'], isEmpty);
      expect(out['marks'], isEmpty);
      expect(out['bestiary'], {'rill.eco': {'seen': true, 'captured': true}});
      expect(out['inventory'], v1['inventory'], reason: 'o resto passa intacto');
      expect(out['future_field'], {'x': 1}, reason: 'campos desconhecidos são preservados');
    });

    test('v1 com nível 1 não vira override', () {
      expect(migrateSave({...v1, 'player_level': 1}).containsKey('level_override'), isFalse);
    });

    test('v2 passa sem mudar, e uma versão futura também', () {
      final v2 = migrateSave(v1);
      expect(migrateSave(v2), v2);
      final future = {...v2, 'schema_version': 9, 'novo': true};
      expect(migrateSave(future), future);
    });

    test('abrir um save v1 dá o mesmo jogo, regrava em v2 e não perde nada', () async {
      final store = MemorySaveStore()..json = v1;
      final session = await GameSession.open(store: store, startInventory: {}, balance: b, nowUtc: () => 100, nextInt: (n) => 0);
      await session.flush();
      final s = session.state;
      expect((s.groupCode, s.count('item.chalk'), s.collection.single.speciesId, s.isDone(42)), ('AAAAA-BBBBB', 3, 'rill.eco', true));
      expect((s.playerLevel, s.progress.level, s.levelOverride), (6, 1, 6));
      expect(store.json!['schema_version'], 4);
      expect(store.json!['future_field'], {'x': 1});
    });

    test('tudo vai e volta: nível, XP, descanso, Círculo, bestiário, marcações e criaturas', () async {
      final store = MemorySaveStore();
      final session = await GameSession.open(store: store, startInventory: {}, balance: b, nowUtc: () => 1790035200, nextInt: (n) => 3);
      final s = session.state;
      s.gainXp(500, 1790035200);
      s.capture(uid: 9, speciesId: 'soot.eco', level: 4, nowUtc: 1790035200);
      s.toggleCircle('9');
      s.replaceCreature(s.creature('9')!.advanced(level: 5, xp: 12));
      s.markSeen('rill.eco');
      s.addMark(Mark.of(spawn(77), nowUtc: 1790035200, durationS: 300), 1790035200);
      s.levelOverride = 8;
      await session.flush();

      final again = await GameSession.open(store: store, startInventory: {}, balance: b, nowUtc: () => 1790035300, nextInt: (n) => 0);
      final r = again.state;
      expect(r.toJson(0), s.toJson(0));
      expect((r.progress.level, r.progress.xp, r.progress.restBalance), (s.progress.level, s.progress.xp, s.progress.restBalance));
      expect(r.circle, ['9']);
      expect((r.creature('9')!.level, r.creature('9')!.xp), (5, 12));
      expect(r.bestiary['rill.eco']!.seen, isTrue);
      expect(r.markOf(77)!.level, 7);
      expect(r.playerLevel, 8);
    });
  });
}
