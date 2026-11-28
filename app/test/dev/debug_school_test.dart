import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/dev/debug_capture.dart';
import 'package:kenoma/dev/debug_commands.dart';
import 'package:kenoma/dev/debug_env.dart';
import 'package:kenoma/dev/debug_items.dart';
import 'package:kenoma/dev/debug_registry.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fake_position_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DebugRegistry regFor(MemorySaveStore store) => buildDefaultRegistry(DebugEnv(tools: DevTools(realSource: FakeGps()), capture: CaptureDebug(), saveStore: store));

  test('as entradas da escola ficam na aba Jogador; limpar e zerar as notas são destrutivas', () {
    final reg = regFor(MemorySaveStore());
    for (final id in ['player.school', 'player.school_clear', 'player.school_invite', 'player.school_scores', 'player.school_tests']) {
      expect(reg.byName(id)?.tab, DebugTab.player, reason: id);
    }
    expect([for (final id in ['player.school_clear', 'player.school_scores', 'player.school_invite']) reg.byName(id)!.destructive], [true, true, false]);
  });

  test('escolher e limpar a escola e zerar o convite mexem só no bloco conjurer do save', () async {
    final store = MemorySaveStore()
      ..json = {
        'schema_version': 5,
        'player': {'level': 5},
        'conjurer': {'tests_offered': true, 'test_scores': {'sealer': 80}},
      };
    final reg = regFor(store);
    expect(await runDebugCommands('player.school ?', reg), [contains('Escola: nenhuma')]);
    expect(await runDebugCommands('player.school sealer', reg), [contains('Escola: Selador')]);
    expect((store.json!['conjurer'] as Map)['school'], 'sealer');
    expect(store.json!['player'], {'level': 5}, reason: 'o resto do save fica como estava');
    await runDebugCommands('player.school_invite', reg);
    expect((store.json!['conjurer'] as Map)['tests_offered'], false);
    expect(await runDebugCommands('player.school_clear', reg), [contains('confirma=sim')]);
    await runDebugCommands('player.school_clear confirma=sim', reg);
    expect((store.json!['conjurer'] as Map).containsKey('school'), isFalse);
    expect((store.json!['conjurer'] as Map)['test_scores'], {'sealer': 80});
  });

  test('sem save ainda, a escola avisa e não cria um', () async {
    final store = MemorySaveStore();
    expect(await runDebugCommands('player.school sealer', regFor(store)), ['erro player.school: Ainda não há jogo salvo: abra o mapa uma vez.']);
    expect(store.json, isNull);
  });
}
