/// Os itens padrão do menu de debug, por seção. Para somar um item novo, ver o cabeçalho de `debug_registry.dart`.
library;

import 'debug_capture.dart';
import 'debug_env.dart';
import 'debug_items_position.dart';
import 'debug_items_ritual.dart';
import 'debug_items_save.dart';
import 'debug_items_world.dart';
import 'debug_registry.dart';

DebugRegistry buildDefaultRegistry(DebugEnv env) => DebugRegistry()
  ..addAll(positionItems(env))
  ..addAll(timeItems(env))
  ..addAll(spawnItems(env))
  ..addAll(mapItems(env))
  // Tráfego: a Rua viva ainda não tem controles de debug. Itens novos entram aqui com DebugSection.traffic.
  ..addAll(playerItems(env))
  ..addAll(captureItems(env.capture))
  ..addAll(signatureItems(env))
  ..addAll(performanceItems())
  ..addAll(saveItems(env))
  ..addAll(ritualDebugItems(env));
