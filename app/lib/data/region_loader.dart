/// Carrega o pacote de região do app e confere o SHA-256 dele contra a época vigente
/// (`epochs.json`). Nunca lança: um pacote que não bate volta como [RegionLoadError], com a
/// mensagem que a tela mostra (docs/fase0-spec.md, seção 1 e CLAUDE.md, regra 8).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../core/epochs.dart';
import 'region_pack.dart';

enum RegionLoadErrorKind {
  /// O `epochs.json` não pôde ser lido.
  epochs,

  /// A época vigente não lista pacote para a região.
  noPackForRegion,

  /// O arquivo do pacote não está nos assets.
  missingFile,

  /// O SHA-256 do arquivo não é o da época.
  shaMismatch,

  /// O SHA-256 bate, mas o conteúdo não é um pacote `VEU1` válido.
  badFormat,
}

sealed class RegionLoad {
  const RegionLoad();
}

class RegionLoaded extends RegionLoad {
  const RegionLoaded({required this.pack, required this.epoch, required this.stale, required this.sha256});

  final RegionPack pack;
  final Epoch epoch;

  /// O relógio está fora da janela das épocas: o mapa funciona, mas o mundo está desatualizado.
  final bool stale;
  final String sha256;
}

class RegionLoadError extends RegionLoad {
  const RegionLoadError(this.kind, this.message);

  final RegionLoadErrorKind kind;

  /// Em português, pronta para a tela.
  final String message;
}

/// SHA-256 em hexadecimal minúsculo.
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

String _short(String hash) => hash.length <= 12 ? hash : '${hash.substring(0, 12)}…';

/// Confere [bytes] contra o pacote que [epoch] lista para [region] e, se bate, lê o pacote.
RegionLoad verifyRegionPack({
  required Uint8List bytes,
  required Epoch epoch,
  required String region,
  bool stale = false,
}) {
  final ref = epoch.regionPacks[region];
  if (ref == null) {
    return RegionLoadError(RegionLoadErrorKind.noPackForRegion, 'A época ${epoch.id} não tem pacote para a região "$region".');
  }
  final actual = sha256Hex(bytes);
  if (actual != ref.sha256.toLowerCase()) {
    return RegionLoadError(
      RegionLoadErrorKind.shaMismatch,
      'O mapa ${ref.file} não é o da época ${epoch.id}.\n'
      'SHA-256 esperado: ${_short(ref.sha256)}\n'
      'SHA-256 lido: ${_short(actual)}\n'
      'Instale uma build com o pacote certo.',
    );
  }
  try {
    return RegionLoaded(pack: RegionPack.parse(bytes), epoch: epoch, stale: stale, sha256: actual);
  } on FormatException catch (e) {
    return RegionLoadError(RegionLoadErrorKind.badFormat, 'O mapa ${ref.file} está corrompido: ${e.message}.');
  } catch (e) {
    return RegionLoadError(RegionLoadErrorKind.badFormat, 'O mapa ${ref.file} está corrompido: $e.');
  }
}

/// Lê a época vigente em [nowUtc] (segundos UTC), o pacote de [region] e o confere.
Future<RegionLoad> loadRegion({required String region, required int nowUtc, AssetBundle? bundle}) async {
  final assets = bundle ?? rootBundle;
  final EpochSelection selection;
  try {
    final json = jsonDecode(await assets.loadString('assets/data/epochs.json')) as Map<String, dynamic>;
    selection = EpochSchedule.fromJson(json).select(nowUtc);
  } catch (e) {
    return RegionLoadError(RegionLoadErrorKind.epochs, 'Não consegui ler as épocas (epochs.json): $e');
  }
  final ref = selection.epoch.regionPacks[region];
  if (ref == null) {
    return RegionLoadError(
        RegionLoadErrorKind.noPackForRegion, 'A época ${selection.epoch.id} não tem pacote para a região "$region".');
  }
  final Uint8List bytes;
  try {
    final data = await assets.load('assets/regions/${ref.file}');
    bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } catch (e) {
    return RegionLoadError(RegionLoadErrorKind.missingFile, 'O mapa ${ref.file} não está no app: $e');
  }
  return verifyRegionPack(bytes: bytes, epoch: selection.epoch, region: region, stale: selection.stale);
}
