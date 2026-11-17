/// Comandos de debug vindos do adb por intent (0.24.2), para dirigir o celular sem teclado: o script nunca digita no
/// aparelho (no 0.24.1 ele digitou num chat de outro app). `scripts/celular.sh cmd "sim on; clock 2027-01-08T02:00;
/// weather rain; tp -22.9041,-47.06; width 80; map"` vira `am start ... --es kenoma_cmd "..."`, que só chega a este app.
/// Comandos separados por `;`. Desconhecido é ignorado e dito no retorno.
library;

import 'package:flutter/services.dart';

import 'dev_tools.dart';

/// O canal por onde a atividade entrega o texto da intent.
const debugCommandChannel = MethodChannel('kenoma/debug_cmd');

/// Aplica [text] em [tools]. [openMap] abre o mapa do jogo (o comando `map`). Devolve uma linha por comando.
Future<List<String>> runDebugCommands(String text, {required DevTools tools, Future<void> Function()? openMap}) async {
  final out = <String>[];
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
    if (call.method == 'cmd' && call.arguments is String) await runDebugCommands(call.arguments as String, tools: tools, openMap: openMap);
  });
  try {
    final pending = await debugCommandChannel.invokeMethod<String>('pending');
    if (pending != null && pending.isNotEmpty) await runDebugCommands(pending, tools: tools, openMap: openMap);
  } on MissingPluginException {
    // testes e plataformas sem o canal
  } on PlatformException {
    // idem
  }
}
