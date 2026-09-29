import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kenoma/core/biomes.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/data/region_pack.dart';

// `flutter test` roda com o diretório de trabalho em app/.
Map<String, dynamic> loadJson(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> epochsJson() => loadJson('assets/data/epochs.json');

EpochSchedule loadEpochs() => EpochSchedule.fromJson(epochsJson());

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
