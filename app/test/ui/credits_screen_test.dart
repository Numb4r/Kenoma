import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/settings/credits_screen.dart';

/// 0.23.0: os créditos dos dados do mapa, com as licenças que o OSM e o Overture pedem.
void main() {
  test('a lista tem o OSM, o Overture com as duas licenças e as fontes dos contornos de IA', () {
    final by = {for (final c in kMapCredits) c.name: c};
    expect(by['OpenStreetMap']!.license, contains('ODbL'));
    expect(by['OpenStreetMap']!.note, contains('© OpenStreetMap contributors'));
    final ov = by['Overture Maps Foundation']!;
    expect(ov.license, allOf(contains('ODbL'), contains('CDLA Permissive 2.0')));
    expect(ov.note, contains('2026-10-21.0'));
    expect(by['Microsoft Global ML Building Footprints']!.license, contains('ODbL'));
    expect(by['Google Open Buildings']!.license, 'CC BY 4.0');
    expect(by['Foursquare']!.license, 'Apache 2.0');
  });

  testWidgets('a tela mostra cada fonte com a licença', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreditsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('OPENSTREETMAP'), findsOneWidget);
    expect(find.text('OVERTURE MAPS FOUNDATION'), findsOneWidget);
    expect(find.text('prédios ODbL 1.0, places CDLA Permissive 2.0'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('GOOGLE OPEN BUILDINGS'), 200);
    expect(find.text('CC BY 4.0'), findsWidgets);
  });
}
