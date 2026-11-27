import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/save/backup.dart';
import 'package:kenoma/save/ksv1.dart';
import 'package:kenoma/save/migrations.dart';
import 'package:kenoma/save/save_store.dart';

import '../support/fixtures.dart';

/// 0.26.4: a última posição do mapa (`map_last_cell`, a célula z21) entra no save deste aparelho, e nunca no backup nem na
/// exportação. Um save v14 (o da 0.26.3) abre sem ela.
void main() {
  // O save real da 0.24.1 levado até o v14 (o v15 só acrescenta a chave opcional).
  final v14 = {...migrateSave(jsonDecode(File('test/fixtures/save_v11_0241.json').readAsStringSync()) as Map<String, dynamic>), 'schema_version': 14}
    ..remove(kLastMapCellKey);

  Future<GameSession> open(Map<String, dynamic> json) => GameSession.open(
        store: MemorySaveStore()..json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
        startInventory: {},
        balance: loadProgressBalance(),
        nowUtc: () => 1795800000,
        nextInt: (n) => 0,
        appVersion: '0.26.4+57',
      );

  test('v14 vira v15 sem a posição, e o resto passa igual', () async {
    final out = migrateSave(v14);
    expect(out['schema_version'], saveSchemaVersion);
    expect(out.containsKey(kLastMapCellKey), isFalse);
    for (final k in v14.keys.where((k) => k != 'schema_version')) {
      expect(out[k], v14[k], reason: 'o campo $k passa sem mudar');
    }
    expect((await open(v14)).state.lastMapCell, isNull, reason: 'a primeira abertura usa o centro de sempre');
  });

  test('a célula vai e volta pelo save, e o backup e a exportação não a levam', () async {
    final s = (await open(v14)).state..lastMapCell = (781234, 563210);
    final json = s.toJson(1795800000);
    expect(json[kLastMapCellKey], [781234, 563210]);
    expect((await open(json)).state.lastMapCell, (781234, 563210));
    final backup = decodeKsv(exportBackup(json));
    expect(backup.containsKey(kLastMapCellKey), isFalse, reason: 'nunca sai do celular');
    expect(backup['group_code'], json['group_code']);
  });
}
