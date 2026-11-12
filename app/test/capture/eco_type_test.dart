import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/capture/seal.dart';
import 'package:kenoma/player/circle.dart';

import '../support/reference_player.dart';

/// A tabela de vantagens do GDD ("Vantagens e desvantagens"), linha por linha: (forte contra, fraco contra).
const Map<EcoType, (Set<EcoType>, Set<EcoType>)> gdd = {
  EcoType.fire: ({EcoType.plant, EcoType.metal}, {EcoType.water, EcoType.earth}),
  EcoType.water: ({EcoType.fire, EcoType.earth, EcoType.digital}, {EcoType.plant, EcoType.electric}),
  EcoType.plant: ({EcoType.water, EcoType.earth}, {EcoType.fire}),
  EcoType.earth: ({EcoType.fire, EcoType.electric, EcoType.metal}, {EcoType.water, EcoType.plant}),
  EcoType.electric: ({EcoType.water, EcoType.metal, EcoType.digital}, {EcoType.earth}),
  EcoType.metal: ({EcoType.fae, EcoType.light}, {EcoType.fire, EcoType.earth, EcoType.electric, EcoType.digital}),
  EcoType.light: ({EcoType.shadow, EcoType.spectral}, {EcoType.metal, EcoType.shadow}),
  EcoType.shadow: ({EcoType.light, EcoType.fae}, {EcoType.light, EcoType.spectral}),
  EcoType.spectral: ({EcoType.shadow, EcoType.spectral}, {EcoType.light, EcoType.spectral, EcoType.fae, EcoType.digital}),
  EcoType.digital: ({EcoType.spectral, EcoType.metal}, {EcoType.electric, EcoType.water}),
  EcoType.fae: ({EcoType.draconic, EcoType.spectral}, {EcoType.metal, EcoType.shadow}),
  EcoType.draconic: ({EcoType.draconic}, {EcoType.draconic, EcoType.fae}),
};

void main() {
  final balance = loadTuningBalance();
  final seals = loadTuningItems().seals;

  test('os 12 tipos existem e os três do MVP continuam os primeiros, na ordem dos sorteios antigos', () {
    expect(EcoType.values, hasLength(12));
    expect(EcoType.values.take(3), [EcoType.fire, EcoType.water, EcoType.plant]);
    expect(EcoType.mvp, [EcoType.fire, EcoType.water, EcoType.plant]);
    expect(gdd.keys.toSet(), EcoType.values.toSet());
  });

  test('a tabela do jogo é a do GDD, linha por linha', () {
    for (final t in EcoType.values) {
      expect(t.strongAgainst, gdd[t]!.$1, reason: '${t.name}: forte contra');
      expect(t.weakAgainst, gdd[t]!.$2, reason: '${t.name}: fraco contra');
    }
    // Quem é forte contra X aparece como fraqueza de X (menos o empate Luz e Sombra, forte nos dois sentidos).
    expect(EcoType.fire.beats(EcoType.plant), isTrue);
    expect(EcoType.plant.beats(EcoType.fire), isFalse);
    expect(EcoType.light.beats(EcoType.shadow) && EcoType.shadow.beats(EcoType.light), isTrue);
  });

  test('contenção no ritual: 1,5 forte, 0,66 resistido (o próprio tipo; e o Dracônico resiste a Fogo, Água, Planta e Elétrico), 1 no resto', () {
    for (final a in EcoType.values) {
      for (final b in EcoType.values) {
        final f = a.factorAgainst(b);
        if (a.beats(b)) {
          expect(f, 1.5, reason: '${a.name} x ${b.name}');
        } else if (a == b || (b == EcoType.draconic && const {EcoType.fire, EcoType.water, EcoType.plant, EcoType.electric}.contains(a))) {
          expect(f, 0.66, reason: '${a.name} x ${b.name}');
        } else {
          expect(f, 1, reason: '${a.name} x ${b.name}');
        }
      }
    }
    expect(EcoType.spectral.factorAgainst(EcoType.spectral), 1.5, reason: 'Espectral é forte contra si mesmo');
    expect(EcoType.draconic.factorAgainst(EcoType.draconic), 1.5);
    expect(EcoType.metal.factorAgainst(EcoType.metal), 0.66);
  });

  test('tolerância: o selo de cada um dos 12 tipos ganha o multiplicador contra todo tipo que o tipo dele vence, e só contra eles', () {
    final typed = {for (final s in seals) if (s.type != null) s.type!: s};
    expect(typed.keys.toSet(), EcoType.values.toSet());
    final simple = seals.firstWhere((s) => s.id == 'item.seal.simple');
    for (final t in EcoType.values) {
      for (final target in EcoType.values) {
        final tol = tuningTolerance(seal: typed[t]!, target: target, balance: balance);
        final plain = tuningTolerance(seal: simple, target: target, balance: balance);
        expect(tol, t.beats(target) ? closeTo(plain * typed[t]!.bonusMultiplier, 1e-12) : plain, reason: 'selo ${t.name} x ${target.name}');
      }
    }
  });

  test('tolerância: cada criatura do Círculo forte contra o alvo amplia o dial, com os 12 tipos', () {
    final simple = seals.firstWhere((s) => s.id == 'item.seal.simple');
    for (final target in EcoType.values) {
      final strong = [for (final t in EcoType.values) if (t.beats(target)) t];
      expect(strong, isNotEmpty, reason: 'todo tipo tem quem o vença: ${target.name}');
      expect(circleStrongCount(EcoType.values, target), strong.length);
      final one = tuningTolerance(seal: simple, target: target, balance: balance, circleStrong: 1);
      expect(one, closeTo(simple.tolerance * balance.circleStrongMultiplier, 1e-12));
    }
    expect(circleStrongCount([EcoType.electric, EcoType.earth, EcoType.plant], EcoType.metal), 2, reason: 'Elétrico e Terra vencem Metal; Planta não');
  });
}
