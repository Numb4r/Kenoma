/// Bestiário básico: por espécie, se já foi vista no mapa e se já foi capturada (docs/fase0-spec.md, seção 9).
library;

class BestiaryEntry {
  const BestiaryEntry({this.seen = false, this.captured = false});

  factory BestiaryEntry.fromJson(Map<String, dynamic> j) =>
      BestiaryEntry(seen: (j['seen'] as bool?) ?? false, captured: (j['captured'] as bool?) ?? false);

  final bool seen;
  final bool captured;

  /// Capturar implica ter visto.
  BestiaryEntry copyWith({bool? seen, bool? captured}) => BestiaryEntry(
        seen: (seen ?? this.seen) || (captured ?? this.captured),
        captured: captured ?? this.captured,
      );

  Map<String, dynamic> toJson() => {'seen': seen, 'captured': captured};
}

/// As chaves do bestiário de um Eco: a da espécie e, se é variante ou Brilhante, a de cada uma (`espécie@bioma`,
/// `espécie@shiny`). Ver e capturar uma variante marca a espécie também.
List<String> bestiaryKeys(String speciesId, {String? variant, bool shiny = false}) => [
      speciesId,
      if (variant != null) '$speciesId@$variant',
      if (shiny) '$speciesId@shiny',
    ];
