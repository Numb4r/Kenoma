import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/dev/street_debug_section.dart';
import 'package:kenoma/world/fog.dart';
import 'package:kenoma/world/places.dart';


void main() {
  final v3 = <String, dynamic>{'schema_version': 3, 'group_code': 'AAAAA-BBBBB', 'inventory': {'item.chalk': 2}};

  group('operações no save', () {
    test('revelar névoa marca o conjunto de debug, não o real, e migra o save antigo sem perder nada', () {
      final out = revealDebugFog(v3, kUnicamp.$1, kUnicamp.$2, 600);
      expect(out['schema_version'], 4);
      expect(out['inventory'], {'item.chalk': 2});
      final fog = FogState.fromJson(out['fog'] as Map<String, dynamic>);
      expect(fog.debugCount, greaterThan(500), reason: '600 m de raio são centenas de células de 35 m');
      expect(fog.revealedCount, 0, reason: 'o contador de área só conta o caminho real');
    });

    test('limpar tira só o debug: o caminho real fica', () {
      final real = FogState()..reveal(774426.4, 1185714.7, 40, 17.6);
      final base = {...v3, 'fog': real.toJson()};
      final withDebug = revealDebugFog(base, kUnicamp.$1, kUnicamp.$2, 300);
      final cleared = clearDebugFog(withDebug);
      final fog = FogState.fromJson(cleared['fog'] as Map<String, dynamic>);
      expect(fog.debugCount, 0);
      expect(fog.revealedCount, real.revealedCount);
    });

    test('zerar o Radar tira a recarga e os Ocultos revelados', () {
      final out = resetRadar({...v3, 'radar': {'last_utc': 999, 'revealed': {'5': 123456}}});
      expect(out['radar'], {'last_utc': 0, 'revealed': <String, dynamic>{}});
    });
  });
}
