import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/dev/debug_commands.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fake_position_source.dart';
import '../support/fixtures.dart';

/// 0.24.3: a época em teste se liga por comando (`celular.sh cmd`), sem tocar nos menus do celular.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('testepoch on grava a não publicada mais nova e libera a seção; off apaga e mantém o resto do save', () async {
    final store = MemorySaveStore()..json = {'group_code': 'AAAAA-BBBBB', 'settings': {'street_names': true}};
    final tools = DevTools(realSource: FakeGps());
    final newest = loadEpochs().newestUnpublished!.id;
    expect(await runDebugCommands('testepoch on', tools: tools, openSave: () async => store), ['testepoch $newest']);
    expect(testEpochOf(store.json), newest);
    expect(store.json!['settings'][kDevOptionsSetting], isTrue);
    expect(store.json!['group_code'], 'AAAAA-BBBBB');
    expect(await runDebugCommands('testepoch off; devopts off', tools: tools, openSave: () async => store), ['testepoch off', 'devopts off']);
    expect(testEpochOf(store.json), isNull);
    expect(store.json!['settings'], {'street_names': true, kDevOptionsSetting: false});
  });
}
