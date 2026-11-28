/// Bestiário: por espécie, se já foi vista no mapa, se já foi capturada e o que a pesquisa precisa saber (quantas
/// capturas, em que hora e clima foi vista, em que biomas foi sintonizada). Dart puro; vai para o save.
library;

class BestiaryEntry {
  const BestiaryEntry({this.seen = false, this.captured = false, this.captures = 0, this.when = const {}, this.biomes = const {}, this.archived = 0});

  factory BestiaryEntry.fromJson(Map<String, dynamic> j) => BestiaryEntry(
        seen: (j['seen'] as bool?) ?? false,
        captured: (j['captured'] as bool?) ?? false,
        captures: (j['captures'] as int?) ?? 0,
        when: {...((j['when'] as List<dynamic>?) ?? const []).cast<String>()},
        biomes: {...((j['biomes'] as List<dynamic>?) ?? const []).cast<String>()},
        archived: (j['archived'] as int?) ?? 0,
      );

  final bool seen;
  final bool captured;

  /// Quantas vezes foi capturada (a fusão conta como uma).
  final int captures;

  /// Quando foi vista: `day`, `night`, `twilight` e o clima (`climate:fog`).
  final Set<String> when;

  /// Os biomas em que foi capturada.
  final Set<String> biomes;

  /// 0.28.0: as tarefas de pesquisa que o Arquivo da Casa fez (somam no nível de pesquisa, depois das feitas na rua).
  final int archived;

  /// Capturar implica ter visto.
  BestiaryEntry copyWith({bool? seen, bool? captured, int? captures, Set<String>? when, Set<String>? biomes, int? archived}) => BestiaryEntry(
        seen: (seen ?? this.seen) || (captured ?? this.captured),
        captured: captured ?? this.captured,
        captures: captures ?? this.captures,
        when: when ?? this.when,
        biomes: biomes ?? this.biomes,
        archived: archived ?? this.archived,
      );

  Map<String, dynamic> toJson() => {
        'seen': seen,
        'captured': captured,
        if (captures > 0) 'captures': captures,
        if (when.isNotEmpty) 'when': when.toList()..sort(),
        if (biomes.isNotEmpty) 'biomes': biomes.toList()..sort(),
        if (archived > 0) 'archived': archived,
      };
}

/// As chaves do bestiário de um Eco: a da espécie e, se é variante ou Brilhante, a de cada uma (`espécie@bioma`,
/// `espécie@shiny`). Ver e capturar uma variante marca a espécie também.
List<String> bestiaryKeys(String speciesId, {String? variant, bool shiny = false}) => [
      speciesId,
      if (variant != null) '$speciesId@$variant',
      if (shiny) '$speciesId@shiny',
    ];

/// As marcas de "quando" de um avistamento: a hora pelo sol ([sunAltDeg], com o crepúsculo a menos de [twilightDeg] do
/// horizonte) e o clima. Da época 12 o clima é a pilha (`storm+vigil`): uma marca para o clima e uma para cada evento.
Set<String> seenTags({required double sunAltDeg, String? climate, double twilightDeg = 6}) => {
      sunAltDeg.abs() < twilightDeg ? 'twilight' : (sunAltDeg > 0 ? 'day' : 'night'),
      if (climate != null)
        for (final part in climate.split('+')) 'climate:$part',
    };
