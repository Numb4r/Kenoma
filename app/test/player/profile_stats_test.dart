import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/dev/debug_items_profile.dart';
import 'package:kenoma/player/bestiary.dart';
import 'package:kenoma/player/conjurer_balance.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/player/profile_stats.dart';
import 'package:kenoma/ui/menu/phone_apps.dart';

import '../support/fixtures.dart';

void main() {
  test('formatKm: uma casa, vírgula decimal', () {
    expect([formatKm(0), formatKm(999), formatKm(1250), formatKm(12340)], ['0,0 km', '1,0 km', '1,3 km', '12,3 km']);
    expect(formatKm2(0.456), '0,46 km²');
  });

  test('restDays e daysLabel', () {
    expect([restDays(0, 300), restDays(299, 300), restDays(900, 300), restDays(10, 0)], [0, 0, 3, 0]);
    expect([daysLabel(1), daysLabel(0), daysLabel(3)], ['1 dia', '0 dias', '3 dias']);
  });

  test('sanitizeName: letras, números, espaços e acentos; no máximo 20', () {
    expect(sanitizeName('  Zé  da Luz!! '), 'Zé  da Luz');
    expect(sanitizeName('<b>Ana</b>'), 'bAnab');
    expect(sanitizeName('abcdefghijklmnopqrstuvwxyz'), 'abcdefghijklmnopqrst');
    expect(sanitizeName('!!!'), '');
  });

  test('speciesRegistered ignora variantes e não capturados', () {
    final b = {
      'soot.eco': const BestiaryEntry(seen: true, captured: true),
      'soot.eco@shiny': const BestiaryEntry(seen: true, captured: true),
      'rill.eco': const BestiaryEntry(seen: true),
      'frond.eco': const BestiaryEntry(seen: true, captured: true),
    };
    expect(speciesRegistered(b), 2);
  });

  test('rótulos', () {
    expect(schoolLabel(null), 'Sem escola');
    expect(schoolLabel(School.shaman), School.shaman.label);
  });

  test('o dia jogado entra pelo ensureDaily, uma vez por dia', () {
    final data = loadGameData();
    final s = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress);
    s.ensureDaily(data.forum, 1, 20000);
    s.ensureDaily(data.forum, 1, 20000);
    s.ensureDaily(data.forum, 1, 20001);
    expect(s.conjurer.daysPlayed, [20000, 20001]);
  });

  test('a bolinha do Perfil acende com talento não visto e apaga ao ver', () {
    final data = loadGameData();
    final s = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress);
    expect(profileHasNews(s), isFalse);
    s.conjurer.talentEarned = 2;
    expect(profileHasNews(s), isTrue);
    s.setSetting('profile_seen_talent', 2);
    expect(profileHasNews(s), isFalse);
    s.conjurer.talentEarned = 3;
    expect(profileHasNews(s), isTrue);
  });

  test('grantProfile soma níveis, XP e talento sem mexer no resto', () {
    final out = grantProfile({'x': 1, 'player': {'level': 3, 'xp': 40}}, levels: 2, xp: 10, talent: 1);
    expect(out['x'], 1);
    expect(out['player'], {'level': 5, 'xp': 10});
    expect((out['conjurer'] as Map)['talent_earned'], 1);
    expect(grantProfile({}, xp: 5)['player'], {'level': 1, 'xp': 5});
  });
}
