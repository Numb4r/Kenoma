import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/species_ids.dart';

/// A camada pelo sufixo do id e o que aparece no mapa comum.
void main() {
  test('a camada sai do sufixo do id', () {
    expect(tierOfId('soot.eco'), SpeciesTier.eco);
    expect(tierOfId('soot.spirit'), SpeciesTier.spirit);
    expect(tierOfId('soot.ritual'), SpeciesTier.spirit);
    expect(tierOfId('hum.major'), SpeciesTier.major);
    expect(tierOfId('hum.archetype'), SpeciesTier.archetype);
  });

  test('só Eco e Espírito aparecem no mapa comum', () {
    expect(['soot.eco', 'soot.spirit', 'soot.ritual'].every(appearsOnMap), isTrue);
    expect(appearsOnMap('hum.major'), isFalse);
    expect(appearsOnMap('hum.archetype'), isFalse);
  });
}
