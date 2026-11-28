import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:kenoma/data/session_log_store.dart';
import 'package:kenoma/dev/debug_capture.dart';
import 'package:kenoma/dev/debug_commands.dart';
import 'package:kenoma/dev/debug_env.dart';
import 'package:kenoma/dev/debug_items.dart';
import 'package:kenoma/dev/debug_registry.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/save/save_store.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/world/style_advisor.dart' show kSimpleGraphicsSetting;

import '../support/fake_position_source.dart';

/// A linha de comando do debug (`celular.sh cmd`): uma vista do registro, como a tela (0.26.6).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemorySaveStore store;
  late DevTools tools;
  late DebugRegistry reg;
  Future<List<String>> cmd(String text) => runDebugCommands(text, reg, base: () => debugStateBase(tools));

  setUp(() {
    store = MemorySaveStore()..json = {'group_code': 'AAAAA-BBBBB', 'settings': {'street_names': true}};
    tools = DevTools(realSource: FakeGps());
    final dir = Directory.systemTemp.createTempSync('kenoma_cmd_');
    addTearDown(() => dir.deleteSync(recursive: true));
    reg = buildDefaultRegistry(DebugEnv(tools: tools, capture: CaptureDebug(store: SessionLogStore(File('${dir.path}/s.csv'))), saveStore: store));
  });

  test('list: uma linha por entrada, com o tipo, os valores, as marcas e os aliases', () async {
    final out = await cmd('list');
    expect(out, hasLength(reg.entries.length));
    for (final e in reg.entries) {
      expect(out.where((l) => l.startsWith('${e.id} · ${e.kind.label} · ')), hasLength(1), reason: e.id);
    }
    expect(out.firstWhere((l) => l.startsWith('pos.teleport ')), allOf(contains('coordenada'), contains('valinhos'), contains('alias tp, map.free')));
    expect(out.firstWhere((l) => l.startsWith('player.save_delete ')), allOf(contains('mexe no save'), contains('destrutivo: confirma=APAGAR')));
    expect(out.firstWhere((l) => l.startsWith('world.weather ')), contains('real desfaz'));
  });

  test('state: em JSON, a fonte, o relógio e o que está fora do real', () async {
    var s = jsonDecode((await cmd('state')).single) as Map<String, dynamic>;
    expect((s['fonte'], s['relogio_forcado']), ('gps', false));
    expect(s['fora_do_real'], isEmpty);
    await cmd('world.clock 2027-01-08T03:17; world.weather rain; visual.biome_grid on; pos.simulator on');
    s = jsonDecode((await cmd('state')).single) as Map<String, dynamic>;
    expect(s['fonte'], 'simulador');
    expect(s['relogio_forcado'], isTrue);
    final off = s['fora_do_real'] as Map<String, dynamic>;
    expect(off.keys, containsAll(['world.clock', 'world.weather', 'visual.biome_grid', 'pos.simulator']));
    expect(off['world.clock']['rotulo'], 'relógio 03:17 UTC');
    expect(off['world.weather'], {'rotulo': 'clima Chuva', 'valor': 'rain'});
  });

  test('os nomes de antes são aliases: sim, tp, clock, weather, event, width, labels, level', () async {
    expect(await cmd('sim on; tp -22.97,-46.995'), ['ok pos.simulator: ok', 'ok pos.teleport: Simulador em -22.97,-46.995']);
    expect((tools.useSimulator, tools.simulator.lat, tools.simulator.lon), (true, -22.97, -46.995));
    await cmd('tp sao paulo');
    expect((tools.simulator.lat, tools.simulator.lon), kPaulista, reason: 'um lugar pelo nome');
    await cmd('clock 2027-01-08T02:00');
    expect(tools.clock.nowUtc, closeTo(DateTime.utc(2027, 1, 8, 2).millisecondsSinceEpoch ~/ 1000, 2));
    await cmd('clock real; weather rain; width 80; labels on; level 7');
    expect((tools.clock.overridden, tools.force.weather, tools.forcedWidthM, tools.turnLabels, tools.levelOverride), (false, 'rain', 80.0, true, 7));
    expect(store.json!['level_override'], 7, reason: 'o nível forçado fica no save');
    await cmd('weather real; width auto; speed 3');
    expect((tools.force.weather, tools.forcedWidthM, tools.simulator.speedMps), (null, null, 3.0));
  });

  test('valores fora do registro são erro e nada muda; real desfaz; ? descreve', () async {
    expect(await cmd('world.weather granizo_azul'), [startsWith('erro world.weather: um de clear|cloudy|rain')]);
    expect(await cmd('pos.teleport 99,0'), [startsWith('erro pos.teleport: lat,lon ou um lugar')]);
    expect(await cmd('pos.simulator talvez'), ['erro pos.simulator: on ou off, não "talvez"']);
    expect(await cmd('player.level 99'), [startsWith('erro player.level: número de 0 a 20')]);
    expect(await cmd('testepoch on; devopts on'), ['erro testepoch: não existe (cmd list)', 'erro devopts: não existe (cmd list)']);
    expect((tools.force.weather, tools.useSimulator, tools.levelOverride), (null, false, 0));
    await cmd('visual.relief on');
    expect(await cmd('visual.relief real'), ['ok visual.relief: visual.relief real']);
    expect(tools.showRelief, isFalse);
    expect((await cmd('visual.relief ?')).single, allOf(startsWith('ok visual.relief: visual.relief · alternar'), contains('valor: off')));
  });

  test('o destrutivo só roda com confirma=<palavra>', () async {
    expect(await cmd('player.save_delete'), ['erro player.save_delete: player.save_delete é destrutivo: mande confirma=APAGAR']);
    expect(await cmd('player.save_delete confirma=sim'), [contains('confirma=APAGAR')]);
    expect(store.json, isNotNull);
    expect(await cmd('save.delete confirma=APAGAR'), ['ok player.save_delete: Save apagado.']);
    expect(store.json, isNull);
  });

  test('0.25.1: style grava os gráficos do mapa no save, sem mexer no resto', () async {
    expect(await cmd('style simple'), ['ok visual.style: Gráficos simplificados']);
    expect(store.json!['settings'], {'street_names': true, kSimpleGraphicsSetting: true});
    expect(store.json!['group_code'], 'AAAAA-BBBBB');
  });

  test('creature no formato antigo vira os parâmetros do criar criatura', () async {
    PackageInfo.setMockInitialValues(appName: 'kenoma', packageName: 'com.numb4r.kenoma', version: '0.2.0', buildNumber: '2', buildSignature: '');
    expect(await cmd('creature hum.eco shiny walk 3'), [startsWith('ok creature.create: 3 na fila')]);
    expect(tools.force.creatures.pending, 3);
    expect(await cmd('creature.create species=tipo type=plant layer=spirit count=2'), [startsWith('ok creature.create: 2 na fila')]);
    expect(tools.force.creatures.pending, 5);
    expect(await cmd('creature.create count=11'), [startsWith('erro creature.create: count: número de 1 a 10')]);
  });

  test('veículo e espécie vista são escolhas fechadas (sem texto livre); o vehicle antigo vira os dois parâmetros', () async {
    final out = (await cmd('list')).firstWhere((l) => l.startsWith('player.vehicle '));
    expect(out, contains('q=common|good|perfect'));
    expect((await cmd('vehicle cart@perfect')).single, 'erro player.vehicle: abra o mapa antes', reason: 'conferido contra o registro antes de rodar');
    expect((await cmd('player.vehicle id=foguete')).single, startsWith('erro player.vehicle: id: um de '));
    expect((await cmd('player.vehicle ?')).single, contains('id=bike|skate|cart'));
    expect((await cmd('creature.seen nao.existe')).single, startsWith('erro creature.seen: species: um de '));
  });

  test('event: liga e desliga cada um, e off (ou real) limpa', () async {
    expect(await cmd('event vigil'), ['ok world.events: ok']);
    expect(tools.force.events, ['vigil']);
    await cmd('event off');
    expect(tools.force.events, isEmpty);
  });
}
