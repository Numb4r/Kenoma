import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/dev/debug_commands.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/save/save_store.dart';
import 'package:kenoma/world/style_advisor.dart' show kSimpleGraphicsSetting;

import '../support/fake_position_source.dart';

/// Os comandos de debug por intent (`celular.sh cmd`), sem tocar nos menus do celular.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('0.25.1: style grava os gráficos do mapa no save, sem mexer no resto', () async {
    final store = MemorySaveStore()..json = {'group_code': 'AAAAA-BBBBB', 'settings': {'street_names': true}};
    final tools = DevTools(realSource: FakeGps());
    expect(await runDebugCommands('style simple', tools: tools, openSave: () async => store), ['style simple']);
    expect(store.json!['settings'], {'street_names': true, kSimpleGraphicsSetting: true});
    expect(store.json!['group_code'], 'AAAAA-BBBBB');
  });

  test('0.25.2: testepoch e devopts saíram com a época em teste (comando desconhecido, nada gravado)', () async {
    final store = MemorySaveStore()..json = {'settings': {'street_names': true}};
    final tools = DevTools(realSource: FakeGps());
    expect(await runDebugCommands('testepoch on; devopts on', tools: tools, openSave: () async => store), ['? testepoch', '? devopts']);
    expect(store.json!['settings'], {'street_names': true});
  });
}
