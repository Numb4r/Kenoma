/// Recomeçar do zero: apaga o progresso e mantém a identidade. Fica o `player_id`, a primeira versão instalada, o log de
/// versões encadeado (com uma linha "recomeço"), os certificados (hoje só o de fundador, que mora no registro), os
/// Ajustes do aparelho e o grupo. Sai todo o resto do save, o diário da Patrulha e os caches da lista [freshStartTargets].
///
/// A ordem protege a identidade: a semente nova é gravada ANTES de apagar as cópias antigas, então um corte de energia
/// no meio deixa sempre um save com o `player_id`. Depois pede um backup novo ao Android (`BackupManager.dataChanged`),
/// para o Auto Backup não ressuscitar o jogo antigo numa reinstalação.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../player/game_session.dart';
import '../world/device_sensors.dart';
import '../player/game_state.dart' show saveSchemaVersion;
import 'founder.dart';
import 'save_store.dart';

/// A palavra que o jogador digita para liberar o recomeço.
const String kFreshStartWord = 'RECOMEÇAR';

/// Na semente do recomeço, o grupo que o jogo novo herda (o `GameSession.open` lê; sem ela, sorteia um grupo).
const String kFreshStartGroupKey = 'fresh_start_group';

/// Ajustes que são progresso disfarçado e saem junto: o que o celular já mostrou, a pesquisa de ritual já vista e os
/// pontos de talento já vistos no Perfil. O resto de `settings` (som, clarões, interruptores) fica.
const List<String> kFreshStartDroppedSettingPrefixes = ['phone_seen_', 'ritual_viewed_', 'profile_seen_talent'];

/// A semente do jogo novo, a partir do save de agora: só a identidade, os Ajustes e o grupo. Puro.
Map<String, dynamic> freshStartSeed(Map<String, dynamic> save, {required int nowUtc}) {
  final founder = save['founder'] == null ? null : (Founder.fromJson(save['founder'] as Map<String, dynamic>)..noteRestart(nowUtc));
  final settings = (save['settings'] as Map<String, dynamic>?) ?? const {};
  return {
    'schema_version': saveSchemaVersion,
    if (founder != null) 'founder': founder.toJson(),
    'settings': {
      for (final e in settings.entries)
        if (!kFreshStartDroppedSettingPrefixes.any(e.key.startsWith)) e.key: e.value,
    },
    if (save['group_code'] is String) kFreshStartGroupKey: save['group_code'],
  };
}

/// O que o recomeço apaga além do save. Para somar um arquivo ou pasta, é uma linha aqui.
List<FileSystemEntity> freshStartTargets({required Directory documents, required Directory support, required Directory temp}) => [
      File('${documents.path}/patrulha.jsonl'), // o diário da Patrulha do Véu
      Directory('${support.path}/blocks'), // o cache de blocos do mapa de fallback
      // `${support.path}/regions` NÃO entra: são os pacotes de região baixados (12 MB de dados móveis), não progresso.
      if (temp.existsSync())
        for (final f in temp.listSync())
          if (f is File && f.uri.pathSegments.last.startsWith('kenoma-backup-')) f, // cópias do save deixadas pelo exportar
    ];

class FreshStart {
  FreshStart({required this.store, required this.targets, required this.requestBackup, this.stopPatrol});

  /// O do aparelho: as pastas do `path_provider` e o `BackupManager` pelo canal `kenoma/system`.
  static Future<FreshStart> onDevice(SaveStore store, {Future<void> Function()? stopPatrol}) async {
    final documents = await getApplicationDocumentsDirectory(), support = await getApplicationSupportDirectory(), temp = await getTemporaryDirectory();
    return FreshStart(
      store: store,
      targets: () => freshStartTargets(documents: documents, support: support, temp: temp),
      requestBackup: const DeviceSensors().requestBackup,
      stopPatrol: stopPatrol,
    );
  }

  final SaveStore store;

  /// Os arquivos e pastas a apagar (ver [freshStartTargets]).
  final List<FileSystemEntity> Function() targets;

  /// Pede ao Android um backup novo (`BackupManager.dataChanged`).
  final Future<void> Function() requestBackup;

  /// Encerra a Patrulha do Véu, se estiver ativa, antes de apagar o diário dela. Quem liga é a Patrulha.
  final Future<void> Function()? stopPatrol;

  /// Recomeça o jogo de [session], que não serve mais depois disto: quem chama reabre o mapa, que nasce na noite das
  /// Fendas como numa instalação nova.
  Future<void> run(GameSession session, int nowUtc) async {
    await stopPatrol?.call();
    await session.flush();
    session.dispose(); // nada do jogo antigo grava por cima
    await store.write(freshStartSeed(session.state.toJson(nowUtc), nowUtc: nowUtc));
    await store.wipe(keepCurrent: true); // as cópias do rodízio antigo e as sobras
    for (final e in targets()) {
      if (await e.exists()) await e.delete(recursive: true);
    }
    await requestBackup();
  }
}
