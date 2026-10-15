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
