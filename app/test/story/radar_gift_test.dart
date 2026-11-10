import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/save/migrations.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();
  const t = 1790040000;
  bool gotRadar(GameState s) => s.story.chat.delivered.any((e) => e.id == 'radar_gift');

  test('o mentor entrega o Radar no nível 5, com uma fala no Chat, uma vez só', () {
    final s = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress);
    expect(data.mentor.byId('radar_gift')?.from, 'mentor');
    s.tickChat(1, t, data.mentor);
    expect(gotRadar(s), isFalse, reason: 'nível 1: ainda não');
    while (s.playerLevel < 5) {
      s.gainXp(500, t);
    }
    s.tickChat(1, t + 10, data.mentor);
    expect(gotRadar(s), isTrue);
    s.tickChat(1, t + 20, data.mentor);
    expect(s.story.chat.delivered.where((e) => e.id == 'radar_gift').length, 1);
  });

  test('save real acima do nível 5 (0.15.0, nível 10) recebe o Radar na próxima abertura, sem schema novo', () {
    final real = jsonDecode(File('test/fixtures/save_v5_0150.json').readAsStringSync()) as Map<String, dynamic>;
    // Também sem os eventos de nível no save (os mais antigos não tinham): a abertura os recompõe.
    final story = {...real['story'] as Map<String, dynamic>};
    story['events'] = {for (final e in (story['events'] as Map<String, dynamic>).entries) if (!e.key.startsWith('level_')) e.key: e.value};
    for (final save in [real, {...real, 'story': story}]) {
      final s = GameState.fromJson(migrateSave(save), data.progress);
      expect(s.playerLevel, greaterThan(5));
      expect(gotRadar(s), isFalse);
      s.tickChat(1, t, data.mentor);
      expect(gotRadar(s), isTrue);
      expect(data.phone.apps.firstWhere((a) => a.id == 'radar').unlockedAt(s.playerLevel), isTrue);
    }
  });
}
