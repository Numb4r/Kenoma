import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/bestiary_view.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/research.dart';
import 'package:kenoma/save/migrations.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fixtures.dart';

/// `test/fixtures/save_v6_0191.json` foi gravado pelo código da própria 0.19.1 (commit b63dc4a, build 0.19.1+31; ver
/// `test/fixtures/README.md`): é o save que os amigos têm no celular quando a 0.20.0 chega.
void main() {
  final real = jsonDecode(File('test/fixtures/save_v6_0191.json').readAsStringSync()) as Map<String, dynamic>;
  final oldBestiary = real['bestiary'] as Map<String, dynamic>;
  final collection = (real['collection'] as List).cast<Map<String, dynamic>>();
  int owned(String key) => collection.where((c) {
        final id = c['species'] as String;
        return c['debug'] != true && [id, if (c['variant'] != null) '$id@${c['variant']}', if (c['shiny'] == true) '$id@shiny'].contains(key);
      }).length;

  test('o fixture é mesmo um save da 0.19.1: schema 6, bestiário só com visto e capturado', () {
    expect((real['schema_version'], real['app_version']), (6, '0.19.1+31'));
    expect(oldBestiary, isNotEmpty);
    expect(oldBestiary.values.every((e) => (e as Map).keys.toSet().difference({'seen', 'captured'}).isEmpty), isTrue);
    expect(collection, isNotEmpty);
    expect((real['inventory'] as Map)['item.dust.fire'], greaterThan(0));
  });

  test('v6 vira v7: cada espécie capturada ganha a contagem (as que estão na coleção, pelo menos uma), as Fagulhas da Bolsa entram, e o resto passa intacto', () {
    final out = migrateSave(real);
    expect(out['schema_version'], 7);
    final b = out['bestiary'] as Map<String, dynamic>;
    for (final e in oldBestiary.entries) {
      final was = e.value as Map<String, dynamic>, now = b[e.key] as Map<String, dynamic>;
      expect((now['seen'], now['captured']), (was['seen'], was['captured']), reason: '${e.key}: visto e capturado não mudam');
      if (was['captured'] == true) {
        expect(now['captures'], owned(e.key) < 1 ? 1 : owned(e.key), reason: e.key);
      } else {
        expect(now.containsKey('captures'), isFalse, reason: '${e.key} só foi vista');
      }
    }
    expect(b['soot.eco']!['captures'], greaterThanOrEqualTo(2), reason: 'a comum e a Urbana estão na coleção');
    final dust = {for (final e in (real['inventory'] as Map<String, dynamic>).entries) if (e.key.startsWith('item.dust.') && (e.value as int) > 0) e.key: e.value};
    expect(dust.keys, containsAll(['item.dust.fire', 'item.dust.water']));
    for (final e in dust.entries) {
      expect(b[e.key], {'seen': true, 'captured': true, 'captures': e.value}, reason: e.key);
    }
    expect(b.keys.toSet(), {...oldBestiary.keys, ...dust.keys}, reason: 'nada inventado');
    for (final k in real.keys.where((k) => k != 'schema_version' && k != 'bestiary')) {
      expect(out[k], real[k], reason: 'o campo $k passa sem mudar');
    }
    expect(migrateSave(out), out, reason: 'migrar duas vezes dá o mesmo');
  });

  test('abrir o save da 0.19.1 na 0.20.0: o jogo é o mesmo, a pesquisa começa do que dá para saber e grava no schema 7', () async {
    final data = loadGameData();
    final store = MemorySaveStore()..json = jsonDecode(jsonEncode(real)) as Map<String, dynamic>;
    final session = await GameSession.open(store: store, startInventory: {}, balance: loadProgressBalance(), nowUtc: () => 1794500000, nextInt: (n) => 0, appVersion: '0.20.0+32');
    await session.flush();
    final s = session.state;
    expect(s.groupCode, real['group_code']);
    expect((s.progress.level, s.progress.xp), ((real['player'] as Map)['level'], (real['player'] as Map)['xp']));
    expect(s.collection.length, collection.length);
    expect(s.inventory, real['inventory']);
    expect(s.circle, real['circle']);
    expect(s.conjurer.school?.id, (real['conjurer'] as Map)['school']);
    expect(s.founder!.chainValid, isTrue);
    expect(s.founder!.playerId, (real['founder'] as Map)['player_id'], reason: 'o player_id não muda');
    expect(s.founder!.versionsSeen.map((e) => e.version).last, '0.20.0+32');
    expect(store.json!['schema_version'], 7);
    // O Bestiário novo lê o save antigo: capturadas com nível 1 de pesquisa, vistas como vistas, Fagulhas coletadas.
    expect(formState('soot.eco', s.bestiary), FormStatus.captured);
    expect(formState('soot.spirit', s.bestiary), FormStatus.seen);
    expect(formState('item.dust.fire', s.bestiary), FormStatus.captured);
    expect(formState('hum.eco', s.bestiary), FormStatus.unknown);
    expect(researchLevel(data.lore['soot.eco']!.research, 'soot.eco', s.bestiary), 1, reason: 'capturar uma vez; a hora em que foi vista não ficou no save antigo');
    expect(familyKnown(data.families.firstWhere((f) => f.id == 'soot'), data, s.bestiary), isTrue);
    expect(familyKnown(data.families.firstWhere((f) => f.id == 'hum'), data, s.bestiary), isFalse);
    expect(bestiaryPercent(data, s.bestiary), greaterThan(0));
    // E segue jogando: a captura nova soma na contagem e guarda o bioma.
    final before = s.bestiary['soot.eco']!.captures;
    s.capture(uid: 9100, speciesId: 'soot.eco', level: 4, nowUtc: 1794500100, biome: 'urban');
    expect(s.bestiary['soot.eco']!.captures, before + 1);
    expect(s.bestiary['soot.eco']!.biomes, {'urban'});
  });
}
