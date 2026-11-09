import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/dev/street_debug_section.dart';


void main() {
  final v3 = <String, dynamic>{'schema_version': 3, 'group_code': 'AAAAA-BBBBB', 'inventory': {'item.chalk': 2}};

  group('operações no save', () {
    test('zerar o Radar tira a recarga e os Ocultos revelados', () {
      final out = resetRadar({...v3, 'radar': {'last_utc': 999, 'revealed': {'5': 123456}}});
      expect(out['radar'], {'last_utc': 0, 'revealed': <String, dynamic>{}});
      expect(out['inventory'], {'item.chalk': 2}, reason: 'migra o save antigo sem perder nada');
    });
  });
}
