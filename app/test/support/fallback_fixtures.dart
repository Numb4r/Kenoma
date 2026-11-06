import 'dart:convert';
import 'dart:typed_data';

import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/fallback/block.dart';
import 'package:kenoma/world/fallback_service.dart';

/// O bioma dos blocos falsos: Verde.
const int kFakeBiome = 2;

/// Um bloco falso: todo Verde, com uma rua local cruzando o tile.
FallbackBlock fakeBlock(int tx, int ty, int epochId) => FallbackBlock(
      tx: tx,
      ty: ty,
      epochId: epochId,
      cells: Uint8List(blockCells * blockCells)..fillRange(0, blockCells * blockCells, kFakeBiome),
      visual: VisualTile(lines: [VisualLine(RoadClass.local, Int32List.fromList([0, 2048, 4096, 2048]))], areas: const []),
      noWalk: const [],
    );

String _query({required int tx, required int ty, required String dateIso}) => '[date:"$dateIso"];tile $tx $ty';

FallbackBlock _build({required String overpassJson, required int tx, required int ty, required int epochId}) => fakeBlock(tx, ty, epochId);

Uint8List _encode(FallbackBlock b) => Uint8List.fromList(utf8.encode('${b.tx} ${b.ty} ${b.epochId}'));

FallbackBlock _decode(Uint8List bytes) {
  final p = utf8.decode(bytes).split(' ').map(int.parse).toList();
  return fakeBlock(p[0], p[1], p[2]);
}

/// O codec falso dos testes: funções soltas, porque atravessam o Isolate.
const fakeCodec = FallbackCodec(query: _query, build: _build, encode: _encode, decode: _decode);

/// Resposta boa da Overpass.
HttpReply okReply() => HttpReply(200, Uint8List.fromList(utf8.encode('{"elements":[]}')));
