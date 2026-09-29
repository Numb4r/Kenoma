/// Definições de bioma (lidas de biomes.json) e o bioma da célula de spawn (docs/fase0-spec.md, seção 3).
library;

class BiomeDef {
  const BiomeDef({required this.id, required this.key, required this.priority, this.spawnAs});

  factory BiomeDef.fromJson(Map<String, dynamic> json) => BiomeDef(
        id: json['id'] as int,
        key: json['key'] as String,
        priority: json['priority'] as int,
        spawnAs: json['spawn_as'] as String?,
      );

  final int id;
  final String key;
  final int priority;

  /// Bioma cujas tabelas de spawn este usa. Vazio usa as de Residencial.
  final String? spawnAs;
}

class BiomeSet {
  BiomeSet(List<BiomeDef> biomes) : _byId = {for (final b in biomes) b.id: b};

  factory BiomeSet.fromJson(Map<String, dynamic> json) => BiomeSet([
        for (final b in json['biomes'] as List<dynamic>) BiomeDef.fromJson(b as Map<String, dynamic>),
      ]);

  final Map<int, BiomeDef> _byId;

  BiomeDef byId(int id) => _byId[id] ?? (throw StateError('Bioma desconhecido: $id'));

  /// Chave das tabelas de spawn para este bioma.
  String spawnKey(int id) {
    final biome = byId(id);
    return biome.spawnAs ?? biome.key;
  }

  /// Bioma de uma célula z20: a moda das quatro células z21 que ela contém, na ordem
  /// (noroeste, nordeste, sudoeste, sudeste). Em caso de empate vence a maior prioridade.
  /// Não consome o gerador.
  int spawnCellBiome(List<int> quad) {
    assert(quad.length == 4, 'uma célula z20 tem 2 x 2 células z21');
    final counts = <int, int>{};
    for (final id in quad) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    // Id desconhecido é erro de dados, com ou sem empate.
    final priority = {for (final id in counts.keys) id: byId(id).priority};
    var best = quad.first;
    for (final entry in counts.entries) {
      final wins = entry.value > counts[best]! ||
          (entry.value == counts[best] && priority[entry.key]! > priority[best]!);
      if (wins) best = entry.key;
    }
    return best;
  }
}
