/// Os três atributos que a Coleção mostra de toda criatura: Poder, Habilidade e Traços. Funções puras de apresentação:
/// os números vêm do `balance.json` (bloco `power`) e dos dados das espécies. Dart puro.
library;

import '../core/species_ids.dart';
import '../data/game_data.dart';
import '../data/tuning_data.dart';
import 'circle.dart' show abilityBandIndex, abilityEffect, abilityLabel;
import 'game_state.dart';

/// Poder: cresce com o nível e com a camada (Espírito acima do Eco). Sem estabilidade ainda.
int powerOf(CreatureInstance c, GameData data) => data.progress.conjurer.power(tierOfId(c.speciesId).name, c.level);

/// O texto de uma habilidade de mapa no [level], por extenso, com a faixa atual e a próxima: "A Aura pega... Faixa 2 de 3
/// (níveis 10 a 19). Próxima, no nível 20: Aura +8 m."
String abilityText(SpeciesAbility ability, int level, List<(int, int)> bands) {
  final band = abilityBandIndex(level, bands);
  final v = ability.bands[band.clamp(0, ability.bands.length - 1)];
  final (from, to) = bands[band];
  final range = level > to ? 'a partir do nível $from' : (from == to ? 'nível $from' : 'níveis $from a $to'); // o Espírito passa do último intervalo
  final next = band + 1 < bands.length && band + 1 < ability.bands.length
      ? 'Próxima, no nível ${bands[band + 1].$1}: ${abilityLabel(ability.kind, ability.bands[band + 1])}.'
      : 'É a última faixa.';
  return '${abilityEffect(ability.kind, v)} Faixa ${band + 1} de ${bands.length} ($range). $next';
}

/// Um traço: a chave (`urban`, `shiny`), o nome e o que ele faz.
class TraitLine {
  const TraitLine({required this.key, required this.name, required this.description, required this.tint});

  final String key;
  final String name;
  final String description;
  final int tint;
}

/// As chaves dos traços da criatura. O Eco tem o da variante de bioma ou do Brilhante (o Brilhante vale mais); o Espírito
/// tem os herdados na fusão (`traits`), ou, se veio de um spawn, os da própria variante. Limitado ao teto da camada.
List<String> traitKeysOf(CreatureInstance c, GameData data) {
  final own = [if (c.shiny) 'shiny', if (c.variant != null) c.variant!];
  final keys = c.traits.isNotEmpty ? c.traits : own;
  return keys.take(data.progress.traitCapFor(c.speciesId)).toList();
}

/// Os traços da criatura com nome e descrição (os textos estão em `creatures.json`, `variants`).
List<TraitLine> traitsOf(CreatureInstance c, GameData data) => [
      for (final k in traitKeysOf(c, data))
        if (data.variantInfo(biome: k == 'shiny' ? null : k, shiny: k == 'shiny') case final v?)
          TraitLine(key: k, name: v.name, description: v.trait, tint: v.tint),
    ];

/// "Traços 1/1": quantos a criatura tem e o teto da camada dela.
String traitsCounter(CreatureInstance c, GameData data) => 'Traços ${traitKeysOf(c, data).length}/${data.progress.traitCapFor(c.speciesId)}';

/// Tudo o que a Coleção mostra, de uma vez.
class CreatureAttributes {
  const CreatureAttributes({required this.power, required this.ability, required this.traitsCounter, required this.traits});

  final int power;

  /// `null` se a espécie não tem habilidade de mapa.
  final String? ability;
  final String traitsCounter;
  final List<TraitLine> traits;
}

CreatureAttributes attributesOf(CreatureInstance c, GameData data) {
  final sp = data.species(c.speciesId);
  return CreatureAttributes(
    power: powerOf(c, data),
    ability: sp?.ability == null ? null : abilityText(sp!.ability!, c.level, data.tuning.abilityBands),
    traitsCounter: traitsCounter(c, data),
    traits: traitsOf(c, data),
  );
}
