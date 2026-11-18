import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kenoma/data/climate_catalog.dart';
import 'package:kenoma/core/biomes.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/data/game_data.dart';
import 'package:kenoma/data/region_pack.dart';
import 'package:kenoma/player/progress_balance.dart';
import 'package:kenoma/world/street_life_balance.dart';

// `flutter test` roda com o diretório de trabalho em app/.
Map<String, dynamic> loadJson(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// O `epochs.json` que vai no APK (0.25.2: modo de desenvolvimento, uma época só, ativa desde o começo).
Map<String, dynamic> shippedEpochsJson() => loadJson('assets/data/epochs.json');

EpochSchedule loadShippedEpochs() => EpochSchedule.fromJson(shippedEpochsJson());

/// As épocas como eram até a 0.25.1, para os testes que usam os modelos antigos como fixture: o histórico 0 a 11
/// (`test/fixtures/epochs_history.json`, fora do APK) e a época de desenvolvimento no lugar que a 12 tinha (início em 2099,
/// sem o modo de desenvolvimento). O conteúdo da 12 é sempre o do APK.
Map<String, dynamic> epochsJson() {
  final history = loadJson('test/fixtures/epochs_history.json');
  final shipped = shippedEpochsJson();
  return {
    'format': shipped['format'],
    'epochs': [
      ...history['epochs'] as List<dynamic>,
      for (final e in shipped['epochs'] as List<dynamic>) {...(e as Map<String, dynamic>), 'starts_utc': '2099-01-01T00:00:00Z', 'valid_until_utc': '2099-04-01T00:00:00Z'},
    ],
  };
}

EpochSchedule loadEpochs() => EpochSchedule.fromJson(epochsJson());

StreetLifeBalance loadStreetBalance() => StreetLifeBalance(loadJson('assets/data/balance.json'));

ProgressBalance loadProgressBalance() => ProgressBalance(loadJson('assets/data/balance.json'));

BiomeSet loadBiomes() => BiomeSet.fromJson(loadJson('assets/data/biomes.json'));

RegionPack loadCampinasPack() =>
    RegionPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0.bin').readAsBytesSync()));

/// Vetores da seção 3 da spec.
const String vectorSeedCode = 'KENOMA-TESTE';
const int vectorSeed = 0x6ebe19ac6345175f;
const double vectorLat = -22.9056;
const double vectorLon = -47.0608;
const int vectorCellX = 387213;
const int vectorCellY = 592857;
const int vectorTime = 1790000000;
const int vectorWindow = 1491667;

/// Os dados do jogo lidos de `assets/data/`, sem passar pelo bundle do Flutter.
GameData loadGameData() => GameData.fromJson(
      balance: loadJson('assets/data/balance.json'),
      balanceVersion: 'test',
      creatures: loadJson('assets/data/creatures.json'),
      items: loadJson('assets/data/items.json'),
      epochs: shippedEpochsJson(),
      recipes: loadJson('assets/data/recipes.json'),
      mentor: loadJson('assets/data/mentor.json'),
      forum: loadJson('assets/data/forum.json'),
      rituals: loadJson('assets/data/rituals.json'),
      climates: loadJson('assets/data/clima.json'),
      events: loadJson('assets/data/eventos.json'),
      mapTexts: loadJson('assets/data/mapa.json'),
      npc: loadJson('assets/data/npc.json'),
    );

/// O visual dos climas e dos eventos (`clima.json` e `eventos.json`, época 12).
ClimateCatalog loadClimateCatalog() => ClimateCatalog.fromJson(loadJson('assets/data/clima.json'), loadJson('assets/data/eventos.json'));

/// As épocas até [lastId]: para testes que descrevem uma época que já ficou para trás (a seguinte começa no release).
EpochSchedule loadEpochsUpTo(int lastId) {
  final json = epochsJson();
  return EpochSchedule.fromJson({
    ...json,
    'epochs': [for (final e in json['epochs'] as List<dynamic>) if ((e as Map<String, dynamic>)['id'] as int <= lastId) e],
  });
}
