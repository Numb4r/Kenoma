/// As entradas padrão do menu de debug, aba por aba. Para somar uma entrada nova, ver o cabeçalho de `debug_registry.dart`.
library;

import 'package:flutter/foundation.dart' show Listenable;

import '../patrol/patrol_controller.dart';
import 'debug_env.dart';
import 'debug_items_crafting.dart';
import 'debug_items_creature.dart';
import 'debug_items_home.dart';
import 'debug_items_position.dart';
import 'debug_items_profile.dart';
import 'debug_items_save.dart';
import 'debug_items_school.dart';
import 'debug_items_system.dart';
import 'debug_items_visual.dart';
import 'debug_items_world.dart';
import 'debug_registry.dart';

DebugRegistry buildDefaultRegistry(DebugEnv env) => DebugRegistry()
  ..addAll(worldEntries(env))
  ..addAll(positionEntries(env))
  ..addAll(creatureEntries(env))
  ..addAll(profileEntries(env))
  ..addAll(homeEntries(env))
  ..addAll(schoolEntries(env))
  ..addAll(craftingEntries(env))
  ..addAll(saveEntries(env))
  ..addAll(visualEntries(env))
  ..addAll(systemEntries(env));

/// O que avisa quando o estado das entradas muda (a tela se redesenha; o que não avisa, o [DebugRegistry.ran] cobre).
Listenable debugListenables(DebugEnv env) => Listenable.merge([env.tools, env.tools.force, env.tools.clock, env.capture, PatrolController.instance]);
