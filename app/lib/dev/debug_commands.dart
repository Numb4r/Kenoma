/// Comandos de debug vindos do adb por intent (0.24.2), para dirigir o celular sem teclado: o script nunca digita no
/// aparelho (no 0.24.1 ele digitou num chat de outro app). `scripts/celular.sh cmd "sim on; clock 2027-01-08T02:00;
/// weather rain; tp -22.9041,-47.06; width 80; map"` vira `am start ... --es kenoma_cmd "..."`, que só chega a este app.
/// Comandos separados por `;`. Desconhecido é ignorado e dito no retorno. 0.24.3: `devopts on|off` (a seção Desenvolvedor
/// dos Ajustes) e `testepoch on|off` (a época não publicada mais nova só neste aparelho; vale ao abrir o mapa).
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import '../core/epochs.dart';
import '../world/debug_creatures.dart' show DebugCreatureSpec, DebugVariant;
import '../crafting/crafting_state.dart' show LoadoutSlot;
import '../net/signed_feed.dart' show loadEpochsJson;
import '../save/ksv_save_store.dart';
import '../save/save_store.dart';
import '../ui/game/game_map_screen.dart' show liveGameState;
import 'debug_items_save.dart' show writeSetting;
import 'dev_tools.dart';

/// O canal por onde a atividade entrega o texto da intent.
const debugCommandChannel = MethodChannel('kenoma/debug_cmd');

/// Aplica [text] em [tools]. [openMap] abre o mapa do jogo (o comando `map`). Devolve uma linha por comando.
Future<List<String>> runDebugCommands(String text, {required DevTools tools, Future<void> Function()? openMap, Future<SaveStore> Function()? openSave}) async {
  final out = <String>[];
  final save = openSave ?? KsvSaveStore.inDocuments;
  final later = liveGameState() == null ? '' : ' (vale ao reabrir o mapa)';
  for (final raw in text.split(';')) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.first.isEmpty) continue;
    final arg = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    switch (parts.first) {
      case 'sim':
        await tools.setUseSimulator(arg != 'off');
        out.add('sim ${tools.useSimulator ? 'on' : 'off'}');
      case 'clock':
        if (arg == 'real') {
          tools.clock.clear();
        } else {
          final t = DateTime.tryParse(arg.endsWith('Z') ? arg : '${arg}Z');
          if (t == null) {
            out.add('clock? $arg');
            continue;
          }
          tools.clock.setUtc(t.millisecondsSinceEpoch ~/ 1000);
        }
        out.add('clock $arg');
      case 'weather':
        arg == 'real' ? tools.force.set(clearWeather: true) : tools.force.set(weather: arg);
        out.add('weather $arg');
      case 'tp':
        final ll = arg.split(',').map((x) => double.tryParse(x.trim())).toList();
        if (ll.length != 2 || ll.contains(null)) {
          out.add('tp? $arg');
          continue;
        }
        tools.simulator.teleport(ll[0]!, ll[1]!);
        out.add('tp $arg');
      case 'width':
        tools.setWidthM(arg == 'auto' ? null : double.tryParse(arg));
        out.add('width $arg');
      case 'labels':
        tools.setTurnLabels(arg != 'off');
        out.add('labels $arg');
      case 'npcs':
        tools.setForceNpcs(arg != 'off');
        out.add('npcs ${tools.forceNpcs ? 'on' : 'off'}');
      case 'speed':
        final v = double.tryParse(arg);
        if (v == null) {
          out.add('speed? $arg');
          continue;
        }
        tools.simulator.speedMps = v;
        out.add('speed $v');
      case 'npctune':
        // Leva o GPS simulado para 45 m ao sul do Eco (longe da proteção de 30 m, ainda na tela) e o relógio para pouco antes.
        final tu = tools.nextNpcTune?.call();
        if (tu == null) {
          out.add('npctune? nenhuma sintonia perto');
          continue;
        }
        tools.simulator.teleport(tu.lat - 45 / 111320, tu.lon);
        tools.clock.setUtc(tu.at - (int.tryParse(arg) ?? 4));
        out.add('npctune ${tu.at}');
      case 'vehicle':
        // Debug: equipa direto no save aberto, sem passar pela bolsa (`vehicle cart@perfect`).
        final live = liveGameState();
        final id = 'item.vehicle.$arg';
        if (live == null || arg.isEmpty) {
          out.add('vehicle? $arg');
          continue;
        }
        live.crafting.equipped[arg.startsWith('cart') ? LoadoutSlot.vehicleCar : LoadoutSlot.vehicleBike] = id;
        live.changed();
        out.add('vehicle $id');
      case 'spectral':
        final sp = tools.nextSpectral?.call();
        if (sp == null) {
          out.add('spectral? nenhum ponto perto');
          continue;
        }
        tools.simulator.teleport(sp.lat - 25 / 111320, sp.lon);
        tools.clock.setUtc(sp.at - (int.tryParse(arg) ?? 12));
        out.add('spectral ${sp.at}');
      case 'buses':
        tools.setManyBuses(arg != 'off');
        out.add('buses ${tools.manyBuses ? 'on' : 'off'}');
      case 'npc':
        out.add('npc ${tools.openNearestNpc?.call() ?? '? nenhum à vista'}');
      case 'event':
        // 0.25.0: os eventos do clima por cima (até dois, como no debug): `event vigil`, `event off`.
        arg == 'off' ? tools.force.clearEvents() : tools.force.toggleEvent(arg);
        out.add('event ${tools.force.events.join('+')}');
      case 'creature':
        // 0.25.0: `creature hum.eco [biome|crimson|shiny] [n]`, como o "Criar criatura" do debug (fora do mundo).
        final a = arg.split(' ');
        final shiny = a.contains('shiny'), n = a.length > 1 ? int.tryParse(a.last) ?? 1 : 1;
        tools.force.creatures.request(DebugCreatureSpec(speciesId: a.first, shiny: shiny, variant: DebugVariant.parse(a.length > 1 ? a[1] : null), count: n), [a.first]);
        out.add('creature ${a.first}');
      case 'seen':
        // 0.25.0: marca a espécie como vista no save aberto (o retrato no Bestiário), só para conferir.
        final live = liveGameState();
        if (live == null || arg.isEmpty) {
          out.add('seen? $arg');
          continue;
        }
        live.markSeen(arg);
        live.changed();
        out.add('seen $arg');
      case 'exit':
        // 0.25.0: a saída animada do Eco mais perto (`exit tuned` ou `exit flee`), só no desenho.
        out.add('exit ${tools.exitNearestEco?.call(arg != 'flee') ?? '? sem Eco à vista'}');
      case 'devopts':
        await writeSetting(save, kDevOptionsSetting, arg != 'off');
        out.add('devopts ${arg == 'off' ? 'off' : 'on'}');
      case 'testepoch':
        if (arg == 'off') {
          await writeSetting(save, kTestEpochSetting, null);
          out.add('testepoch off$later');
          continue;
        }
        final e = EpochSchedule.fromJson(await loadEpochsJson()).newestUnpublished;
        if (e == null) {
          out.add('testepoch? nenhuma época não publicada');
          continue;
        }
        await writeSetting(save, kDevOptionsSetting, true);
        await writeSetting(save, kTestEpochSetting, e.id);
        out.add('testepoch ${e.id}$later');
      case 'map':
        await openMap?.call();
        out.add('map');
      default:
        out.add('? ${parts.first}');
    }
  }
  return out;
}

/// Liga o canal: pega o comando que abriu o app e os que chegarem depois (`onNewIntent`).
Future<void> listenDebugCommands({required DevTools tools, required Future<void> Function() openMap}) async {
  debugCommandChannel.setMethodCallHandler((call) async {
    if (call.method == 'cmd' && call.arguments is String) debugPrint('kenoma_cmd ${await runDebugCommands(call.arguments as String, tools: tools, openMap: openMap)}');
  });
  try {
    final pending = await debugCommandChannel.invokeMethod<String>('pending');
    if (pending != null && pending.isNotEmpty) debugPrint('kenoma_cmd ${await runDebugCommands(pending, tools: tools, openMap: openMap)}');
  } on MissingPluginException {
    // testes e plataformas sem o canal
  } on PlatformException {
    // idem
  }
}
