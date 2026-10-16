import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/attributes.dart';
import 'package:kenoma/player/game_state.dart';

import '../support/fixtures.dart';

void main() {
  final data = loadGameData();
  CreatureInstance c(String id, int level, {String? variant, bool shiny = false, List<String> traits = const []}) =>
      CreatureInstance(uid: 'x', speciesId: id, level: level, capturedUtc: 0, variant: variant, shiny: shiny, traits: traits);

  test('Poder cresce com o nível e com a camada', () {
    final eco1 = powerOf(c('soot.eco', 1), data), eco20 = powerOf(c('soot.eco', 20), data);
    final sp1 = powerOf(c('soot.spirit', 1), data), sp30 = powerOf(c('soot.spirit', 30), data);
    expect((eco1, eco20, sp1, sp30), (12, 50, 43, 130));
    expect(sp1, greaterThan(eco1), reason: 'no mesmo nível o Espírito pesa mais');
  });

  test('o texto da Habilidade traz o efeito da faixa por extenso', () {
    String text(String id, int level) => attributesOf(c(id, level), data).ability!;
    expect(text('soot.eco', 4), 'Aura +3 m (faixa 1 de 3: níveis 1 a 9)');
    expect(text('soot.eco', 10), 'Aura +5 m (faixa 2 de 3: níveis 10 a 19)');
    expect(text('soot.eco', 20), 'Aura +8 m (faixa 3 de 3: nível 20)');
    expect(text('soot.spirit', 10), 'Aura +8 m (faixa 2 de 3: níveis 10 a 19)', reason: 'um degrau acima do Eco');
    expect(text('soot.spirit', 27), 'Aura +11 m (faixa 3 de 3: a partir do nível 20)');
    expect(text('frond.eco', 1), startsWith('Coleta de Fagulhas e materiais +'));
    expect(text('rill.eco', 1), startsWith('Rastreador alcança '));
  });

  test('Traços: Eco 1/1 pela variante ou pelo Brilhante, comum 0/1', () {
    expect(attributesOf(c('soot.eco', 5), data).traitsCounter, 'Traços 0/1');
    final v = attributesOf(c('soot.eco', 5, variant: 'urban'), data);
    expect(v.traitsCounter, 'Traços 1/1');
    expect(v.traits.single.name, 'Urbana');
    expect(v.traits.single.description, contains('Cinzenta'));
    final both = attributesOf(c('soot.eco', 5, variant: 'urban', shiny: true), data);
    expect((both.traitsCounter, both.traits.single.key), ('Traços 1/1', 'shiny'), reason: 'o Brilhante vale mais');
  });

  test('Traços: Espírito 2/2 pelos herdados, e nunca passa do teto', () {
    final sp = attributesOf(c('soot.spirit', 12, traits: ['shiny', 'green']), data);
    expect(sp.traitsCounter, 'Traços 2/2');
    expect([for (final t in sp.traits) t.name], ['Brilhante', 'Verde']);
    expect(attributesOf(c('soot.spirit', 12, traits: ['shiny']), data).traitsCounter, 'Traços 1/2');
    expect(attributesOf(c('soot.spirit', 12, traits: ['shiny', 'green', 'urban']), data).traitsCounter, 'Traços 2/2');
    expect(attributesOf(c('soot.eco', 5, traits: ['shiny', 'green']), data).traitsCounter, 'Traços 1/1');
  });
}
