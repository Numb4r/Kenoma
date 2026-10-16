import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/save/migrations.dart';
import 'package:kenoma/save/save_store.dart';
import 'package:kenoma/story/chat_state.dart';
import 'package:kenoma/story/daily_quests.dart';
import 'package:kenoma/story/forum_data.dart';
import 'package:kenoma/story/mentor_script.dart';

import '../support/fixtures.dart';

void main() {
  final script = MentorScript.fromJson(loadJson('assets/data/mentor.json'));
  final forum = ForumData.fromJson(loadJson('assets/data/forum.json'));
  final b = loadProgressBalance();
  const seed = 0x6ebe19ac6345175f;
  const day = 20750; // um dia qualquer

  group('roteiro do mentor (JSON)', () {
    test('o contato é o número desconhecido, as mensagens têm id único, texto e espera', () {
      expect(script.contactName, 'Número desconhecido');
      expect(script.tutorial.length, greaterThanOrEqualTo(10));
      expect({for (final m in script.tutorial) m.id}.length, script.tutorial.length);
      for (final m in script.tutorial) {
        expect(m.text.trim(), isNotEmpty, reason: m.id);
        expect(m.afterS, greaterThan(0), reason: m.id);
        expect(m.text.length, lessThan(320), reason: '${m.id}: mensagem de chat, curta');
      }
    });

    test('o tutorial cobre Aura, sintonia, Bancada e Círculo', () {
      final all = script.tutorial.map((m) => m.text).join(' ');
      for (final word in ['Aura', 'dial', 'Bancada', 'Círculo']) {
        expect(all, contains(word));
      }
    });

    test('as condições só pedem eventos que o jogo conta', () {
      const known = {'capture', 'craft', 'distill', 'spark', 'material', 'walk_m'};
      for (final m in script.tutorial) {
        if (m.requires != null) expect(known, contains(m.requires!.event), reason: m.id);
      }
    });

    test('os textos do docs/textos-mentor.md batem com o JSON (rode scripts/mentor_md.py)', () {
      final md = File('../docs/textos-mentor.md').readAsStringSync();
      for (final m in script.tutorial) {
        expect(md, contains(m.text), reason: m.id);
      }
      for (final t in forum.templates) {
        for (final tx in t.texts) {
          expect(md, contains(tx), reason: t.id);
        }
      }
    });
  });

  group('chat com o mentor', () {
    int none(String e) => 0;

    test('as mensagens saem em ordem, uma por vez, depois da espera de cada uma', () {
      final chat = ChatState();
      final first = script.tutorial.first;
      expect(chat.tick(first.afterS - 1, 100, script, none), isNull);
      expect(chat.delivered, isEmpty);
      expect(chat.tick(1, 101, script, none)?.id, first.id);
      expect(chat.unread, 1);
      expect(chat.waitS, 0);
      final second = script.tutorial[1];
      expect(chat.tick(second.afterS, 130, script, none)?.id, second.id);
      expect(chat.delivered.map((e) => e.id), [first.id, second.id]);
      expect(chat.delivered.last.utc, 130);
    });

    test('uma chamada entrega no máximo uma mensagem, mesmo com muito tempo acumulado', () {
      final chat = ChatState();
      chat.tick(10000, 1, script, none);
      expect(chat.delivered, hasLength(1));
    });

    test('a mensagem que pede um evento espera por ele', () {
      final chat = ChatState();
      final idx = script.tutorial.indexWhere((m) => m.requires != null);
      for (var i = 0; i < idx; i++) {
        chat.tick(10000, 1, script, none);
      }
      expect(chat.delivered, hasLength(idx));
      final gated = script.tutorial[idx];
      expect(chat.tick(10000, 2, script, none), isNull, reason: 'o evento ${gated.requires!.event} ainda não aconteceu');
      expect(chat.tick(10000, 3, script, (e) => e == gated.requires!.event ? gated.requires!.min - 1 : 0), isNull);
      expect(chat.tick(10000, 4, script, (e) => e == gated.requires!.event ? gated.requires!.min : 0)?.id, gated.id);
    });

    test('o tutorial acaba e não entrega mais nada; ler zera o contador de não lidas', () {
      final chat = ChatState();
      for (var i = 0; i < script.tutorial.length + 5; i++) {
        chat.tick(10000, i, script, (_) => 99);
      }
      expect(chat.delivered, hasLength(script.tutorial.length));
      expect(chat.tutorialDone(script), isTrue);
      expect(chat.tick(10000, 999, script, (_) => 99), isNull);
      expect(chat.unread, script.tutorial.length);
      chat.markAllRead();
      expect(chat.unread, 0);
    });

    test('vai e volta no JSON', () {
      final chat = ChatState()..tick(10000, 77, script, none);
      chat.waitS = 12.5;
      chat.markAllRead();
      final again = ChatState.fromJson(jsonDecode(jsonEncode(chat.toJson())) as Map<String, dynamic>);
      expect((again.delivered.single.id, again.delivered.single.utc, again.readCount, again.waitS), (chat.delivered.single.id, 77, 1, 12.5));
    });
  });

  group('diárias do fórum', () {
    Quest q(int slot, {int level = 1, int d = day, int s = seed, int epoch = 1, int reroll = 0, Set<String> taken = const {}}) =>
        generateQuest(seed: s, epochId: epoch, day: d, slot: slot, level: level, forum: forum, reroll: reroll, taken: taken);

    test('a mesma seed, época, data e slot dão o mesmo pedido (amigos recebem os mesmos)', () {
      for (var slot = 0; slot < 3; slot++) {
        expect(q(slot).toJson(), q(slot).toJson());
      }
    });

    test('outro dia, outra seed ou outra época dão outros pedidos', () {
      String sig(int d, int s, int e) => [for (var slot = 0; slot < 3; slot++) q(slot, d: d, s: s, epoch: e).text].join('|');
      final base = sig(day, seed, 1);
      var different = 0;
      for (var d = day + 1; d < day + 8; d++) {
        if (sig(d, seed, 1) != base) different++;
      }
      expect(different, greaterThanOrEqualTo(6));
      expect(sig(day, seed + 1, 1), isNot(base));
      expect(sig(day, seed, 2), isNot(base));
    });

    test('três pedidos por dia, de eventos diferentes entre si, e o do slot 2 é de casa', () {
      for (var d = day; d < day + 60; d++) {
        final daily = DailyState()..ensure(today: d, seed: seed, epochId: 1, level: 5, forum: forum);
        expect(daily.quests, hasLength(3));
        expect({for (final x in daily.quests) '${x.kind}:${x.key}'}.length, 3, reason: 'dia $d: pedidos repetidos');
        expect(['craft', 'distill'], contains(daily.atSlot(2)!.kind), reason: 'dia $d: um pedido dá para fazer em casa');
        expect(['walk_m', 'spark', 'material', 'capture'], contains(daily.atSlot(0)!.kind), reason: 'dia $d: o slot 0 é de explorar ou coletar');
      }
    });

    test('o texto sai preenchido: meta, tipo e item no lugar, sem chaves sobrando', () {
      for (var d = day; d < day + 80; d++) {
        for (var slot = 0; slot < 3; slot++) {
          final x = q(slot, d: d);
          expect(x.text, isNot(contains('{')), reason: x.text);
          expect(x.text, isNot(contains('}')));
          expect(x.target, greaterThan(0));
          expect(x.rewardXp, greaterThanOrEqualTo(150));
          expect(forum.users, contains(x.user));
        }
      }
    });

    test('a meta cresce com o nível e respeita o passo', () {
      final lo = [for (var d = day; d < day + 40; d++) q(0, d: d, level: 1).target].reduce((a, b) => a + b);
      final hi = [for (var d = day; d < day + 40; d++) q(0, d: d, level: 15).target].reduce((a, b) => a + b);
      expect(hi, greaterThan(lo));
      for (var d = day; d < day + 40; d++) {
        final x = q(0, d: d, level: 12);
        final t = forum.template(x.templateId)!;
        expect(x.target % t.step, 0);
        expect(x.target, greaterThanOrEqualTo(t.targetMin));
      }
    });

    test('o dia virou: gera novos pedidos e zera o reroll; no mesmo dia não muda nada', () {
      final d = DailyState();
      expect(d.ensure(today: day, seed: seed, epochId: 1, level: 1, forum: forum), isTrue);
      final first = [for (final x in d.quests) x.text];
      expect(d.ensure(today: day, seed: seed, epochId: 1, level: 1, forum: forum), isFalse);
      expect([for (final x in d.quests) x.text], first);
      d.rerolls = 1;
      expect(d.ensure(today: day + 1, seed: seed, epochId: 1, level: 1, forum: forum), isTrue);
      expect(d.rerolls, 0);
      expect(d.day, day + 1);
    });

    test('um reroll por dia: troca o pedido sem repetir os outros, e o segundo é recusado', () {
      final d = DailyState()..ensure(today: day, seed: seed, epochId: 1, level: 1, forum: forum);
      final before = d.atSlot(1)!.text;
      expect(d.reroll(1, seed: seed, epochId: 1, level: 1, forum: forum), isTrue);
      expect(d.rerolls, 1);
      expect(d.quests, hasLength(3));
      expect({for (final x in d.quests) '${x.kind}:${x.key}'}.length, 3);
      expect(d.atSlot(1)!.progress, 0);
      expect(d.reroll(0, seed: seed, epochId: 1, level: 1, forum: forum), isFalse, reason: 'só um por dia');
      // O reroll é o mesmo para quem tem a mesma seed.
      final friend = DailyState()..ensure(today: day, seed: seed, epochId: 1, level: 1, forum: forum);
      friend.reroll(1, seed: seed, epochId: 1, level: 1, forum: forum);
      expect(friend.atSlot(1)!.text, d.atSlot(1)!.text);
      expect(before, isNotNull);
    });

    test('pedido já entregue não troca', () {
      final d = DailyState()..ensure(today: day, seed: seed, epochId: 1, level: 1, forum: forum);
      d.atSlot(2)!.claimed = true;
      expect(d.reroll(2, seed: seed, epochId: 1, level: 1, forum: forum), isFalse);
    });

    test('o progresso conta o evento certo e a variação certa, e avisa ao completar', () {
      final d = DailyState(quests: [
        Quest(slot: 0, templateId: 'sparks', kind: 'spark', key: 'fire', target: 5, user: 'x', text: 't', rewardXp: 150, rewardItems: const {}),
        Quest(slot: 1, templateId: 'hunt', kind: 'capture', key: 'any', target: 2, user: 'x', text: 't', rewardXp: 150, rewardItems: const {}),
        Quest(slot: 2, templateId: 'walk', kind: 'walk_m', key: '', target: 500, user: 'x', text: 't', rewardXp: 150, rewardItems: const {}),
      ]);
      expect(d.record('spark', 'water', 3), isEmpty);
      expect(d.atSlot(0)!.progress, 0, reason: 'outro tipo não conta');
      expect(d.record('spark', 'fire', 3), isEmpty);
      expect(d.record('spark', 'fire', 9).map((x) => x.slot), [0]);
      expect(d.atSlot(0)!.progress, 5, reason: 'não passa da meta');
      expect(d.record('spark', 'fire', 1), isEmpty, reason: 'pronto não avisa de novo');
      expect(d.record('capture', 'plant', 1), isEmpty);
      expect(d.record('capture', 'water', 1).map((x) => x.slot), [1], reason: 'any conta qualquer tipo');
      expect(d.record('walk_m', '', 600).map((x) => x.slot), [2]);
      expect(d.record('craft', 'recipe.seal.simple', 1), isEmpty);
    });

    test('vai e volta no JSON com o progresso', () {
      final d = DailyState()..ensure(today: day, seed: seed, epochId: 1, level: 3, forum: forum);
      d.atSlot(0)!.progress = 2;
      d.atSlot(1)!.claimed = true;
      final again = DailyState.fromJson(jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>);
      expect(again.toJson(), d.toJson());
    });
  });

  group('no estado do jogo', () {
    GameState state() => GameState(groupCode: 'KENOMA-TESTE', balance: b);

    test('evento de jogo conta no total e nos pedidos, e entregar dá XP e materiais', () {
      final s = state()..ensureDaily(forum, 1, day);
      final notices = <String>[];
      s.onNotice = notices.add;
      final slot2 = s.story.daily.atSlot(2)!;
      expect(s.claimDaily(2, 1790035200), isFalse, reason: 'ainda não está pronto');
      s.recordEvent(slot2.kind, slot2.key == 'any' ? '' : slot2.key, slot2.target);
      expect(s.story.count(slot2.kind), slot2.target);
      expect(notices.single, contains('pronto'));
      final xpBefore = s.progress.xp + s.progress.level;
      expect(s.claimDaily(2, 1790035200), isTrue);
      expect(slot2.claimed, isTrue);
      for (final e in slot2.rewardItems.entries) {
        expect(s.count(e.key), greaterThanOrEqualTo(e.value));
      }
      expect(s.progress.xp + s.progress.level, greaterThan(xpBefore));
      expect(s.claimDaily(2, 1790035200), isFalse, reason: 'só uma vez');
    });

    test('o chat avisa quando chega mensagem', () {
      final s = state();
      final notices = <String>[];
      s.onNotice = notices.add;
      expect(s.tickChat(1, 1, script), isNull);
      expect(s.tickChat(script.tutorial.first.afterS, 2, script)?.id, script.tutorial.first.id);
      expect(notices.single, contains('Número desconhecido'));
    });

    test('a história inteira vai e volta pelo save', () async {
      final store = MemorySaveStore();
      final session = await GameSession.open(store: store, startInventory: {}, balance: b, nowUtc: () => 1790035200, nextInt: (n) => 0);
      final s = session.state..ensureDaily(forum, 1, day);
      s.tickChat(1000, 1790035200, script);
      s.recordEvent('capture', 'fire', 2);
      await session.flush();
      final again = await GameSession.open(store: store, startInventory: {}, balance: b, nowUtc: () => 1790035300, nextInt: (n) => 0);
      expect(again.state.story.toJson(), s.story.toJson());
      expect(again.state.story.count('capture'), 2);
      expect(again.state.story.chat.delivered, hasLength(1));
      expect(again.state.story.daily.quests, hasLength(3));
    });
  });

  group('migração do save v2 para v3', () {
    // Um save como a 0.12.1 grava (schema 2), com tudo o que ele tinha.
    final v2 = <String, dynamic>{
      'schema_version': 2,
      'group_code': 'AAAAA-BBBBB',
      'player': {'level': 4, 'xp': 80, 'banked_xp': 0, 'rest_balance': 200, 'rest_day': 20749},
      'level_override': 7,
      'saved_utc': 1790040000,
      'created_utc': 1790000000,
      'last_seen_utc': 1790040000,
      'app_version': '0.12.1+19',
      'epoch': 1,
      'founder': {
        'player_id': '00112233445566778899aabbccddeeff',
        'first_install_version': '0.12.0+18',
        'first_seen_utc': 1790000000,
        'versions_seen': <dynamic>[],
      },
      'settings': {'street_names': true, 'veil_traffic': false, 'follow_heading': true},
      'inventory': {'item.chalk': 3, 'item.seal.simple': 4},
      'collection': [
        {'uid': '9', 'species': 'soot.eco', 'level': 5, 'xp': 12, 'captured_utc': 1790001000},
      ],
      'collected': {'123': 1790039000},
      'circle': ['9'],
      'bestiary': {
        'soot.eco': {'seen': true, 'captured': true},
        'rill.eco': {'seen': true, 'captured': false},
      },
      'marks': <dynamic>[],
      'campo_do_futuro': {'x': 1},
    };

    test('v2 vira v3 com a história vazia e todo o resto intacto, inclusive campos desconhecidos', () {
      final out = migrateSave(v2);
      expect(out['schema_version'], 4);
      expect(out['story'], {
        'events': <String, dynamic>{},
        'chat': {'delivered': <dynamic>[], 'read': 0, 'wait_s': 0},
        'daily': {'day': null, 'rerolls': 0, 'quests': <dynamic>[]},
      });
      for (final k in v2.keys.where((k) => k != 'schema_version')) {
        expect(out[k], v2[k], reason: 'o campo $k passa sem mudar');
      }
    });

    test('um save v3 que já tem história não é sobrescrito', () {
      final withStory = {...migrateSave(v2), 'story': {'events': {'capture': 5}, 'chat': {'delivered': <dynamic>[], 'read': 0, 'wait_s': 3}, 'daily': {'day': 1, 'rerolls': 0, 'quests': <dynamic>[]}}};
      expect(migrateSave(withStory)['story'], withStory['story']);
    });

    test('abrir o save v2 mantém o jogo, começa o tutorial do zero e regrava no schema atual', () async {
      final store = MemorySaveStore()..json = jsonDecode(jsonEncode(v2)) as Map<String, dynamic>;
      final session = await GameSession.open(store: store, startInventory: {}, balance: b, nowUtc: () => 1790041000, nextInt: (n) => 0, appVersion: '0.13.0+20');
      await session.flush();
      final s = session.state;
      expect((s.groupCode, s.progress.level, s.progress.xp, s.levelOverride, s.count('item.chalk')), ('AAAAA-BBBBB', 4, 80, 7, 3));
      expect(s.circle, ['9']);
      expect(s.collection.single.level, 5);
      expect(s.setting('street_names'), isTrue);
      expect(s.settingOr('veil_traffic', true), isFalse);
      expect(s.founder!.playerId, '00112233445566778899aabbccddeeff');
      expect(s.story.chat.delivered, isEmpty);
      expect(store.json!['schema_version'], 4);
      expect(store.json!['campo_do_futuro'], {'x': 1});
      expect(store.json!['story'], isNotNull);
    });
  });
}
