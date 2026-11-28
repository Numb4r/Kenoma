/// A linha de comando do debug (0.24.2; 0.26.6: uma vista do [DebugRegistry], como a tela). `scripts/celular.sh cmd
/// "pos.simulator on; pos.teleport valinhos"` vira `am start ... --es kenoma_cmd "..."`, que só chega a este app, e a
/// resposta sai no logcat (`kenoma_cmd ...`). O script nunca digita no aparelho (no 0.24.1 ele digitou num chat de outro
/// app).
///
/// - `list`: uma linha por entrada (id, tipo, valores, se mexe no save, se é destrutiva, aliases).
/// - `state`: em JSON, tudo que está fora do real, a fonte de posição e o relógio.
/// - `<id> <args>`: roda e responde `ok <id>: ...` ou `erro <id>: ...`. `<id> real` desfaz; `<id> ?` descreve e lê.
///
/// Os nomes de antes (`sim on`, `tp lat,lon`, `lastcell`, `clock`, `weather`, `creature hum.eco shiny 3`...) são aliases.
/// Comandos separados por `;`.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import '../ui/game/game_map_screen.dart' show liveGameState;
import 'debug_registry.dart';
import 'dev_tools.dart';

/// O canal por onde a atividade entrega o texto da intent.
const debugCommandChannel = MethodChannel('kenoma/debug_cmd');

/// O `state` além do que está fora do real: a fonte de posição, onde está o simulador, o relógio e se o mapa está aberto.
Map<String, Object?> debugStateBase(DevTools tools) => {
      'fonte': tools.useSimulator ? 'simulador' : 'gps',
      if (tools.useSimulator) 'simulador': [tools.simulator.lat, tools.simulator.lon],
      'relogio_utc': tools.clock.now.toIso8601String(),
      'relogio_forcado': tools.clock.overridden,
      'mapa_aberto': liveGameState() != null,
    };

/// Roda [text] no [registry]. Devolve uma linha por comando (`list` devolve uma por entrada).
Future<List<String>> runDebugCommands(String text, DebugRegistry registry, {Map<String, Object?> Function()? base}) async {
  final out = <String>[];
  for (final raw in text.split(';')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final space = line.indexOf(RegExp(r'\s'));
    final name = space < 0 ? line : line.substring(0, space);
    var args = space < 0 ? '' : line.substring(space + 1).trim();
    if (name == 'list') {
      out.addAll([for (final e in registry.entries) e.describe()]);
      continue;
    }
    if (name == 'state') {
      out.add(registry.state(always: base?.call() ?? const {}));
      continue;
    }
    args = _legacy(name, args);
    final e = registry.byName(name);
    if (e == null) {
      out.add('erro $name: não existe (cmd list)');
      continue;
    }
    try {
      out.add('ok ${e.id}: ${await registry.execute(e, args)}');
    } on DebugError catch (err) {
      out.add('erro ${e.id}: ${err.message}');
    } catch (err) {
      out.add('erro ${e.id}: $err');
    }
  }
  return out;
}

/// Os argumentos dos comandos de antes que mudaram de forma.
String _legacy(String name, String args) => switch (name) {
      'event' when args == 'off' => 'real',
      'clock' when args == 'real' => 'real',
      // `creature hum.eco [biome|crimson|shiny] [walk] [n]`, ou `creature fire ...` (só o tipo).
      'creature' when args.isNotEmpty && !args.contains('=') => () {
          final a = args.split(RegExp(r'\s+'));
          final n = a.length > 1 ? int.tryParse(a.last) : null;
          final first = a.first;
          return [
            first.contains('.') ? 'species=$first' : 'species=tipo type=$first',
            if (a.contains('shiny')) 'shiny=on',
            if (a.contains('walk')) 'walk=on',
            if (a.contains('biome')) 'variant=biome',
            if (a.contains('crimson')) 'variant=crimson',
            if (n != null) 'count=$n',
          ].join(' ');
        }(),
      _ => args,
    };

/// Liga o canal: pega o comando que abriu o app e os que chegarem depois (`onNewIntent`). Cada resposta sai numa linha
/// `kenoma_cmd ...` do logcat (o `celular.sh cmd` as lê de volta).
Future<void> listenDebugCommands(DebugRegistry registry, DevTools tools) async {
  Future<void> run(String text) async {
    for (final l in await runDebugCommands(text, registry, base: () => debugStateBase(tools))) {
      debugPrint('kenoma_cmd $l');
    }
  }

  debugCommandChannel.setMethodCallHandler((call) async {
    if (call.method == 'cmd' && call.arguments is String) await run(call.arguments as String);
  });
  try {
    final pending = await debugCommandChannel.invokeMethod<String>('pending');
    if (pending != null && pending.isNotEmpty) await run(pending);
  } on MissingPluginException {
    // testes e plataformas sem o canal
  } on PlatformException {
    // idem
  }
}
