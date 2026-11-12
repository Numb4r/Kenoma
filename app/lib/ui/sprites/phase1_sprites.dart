/// Os sprites provisórios das famílias da fase 1 e das Fagulhas: a silhueta de `phase1_masks.dart` ampliada para 48 x 48,
/// com o contorno `#1a1424`, luz em cima, sombra embaixo e a cor do tipo. Só desenho; a arte final vai para o backlog.
library;

import '../../capture/eco_type.dart';
import '../../core/species_ids.dart';
import '../colors.dart';
import 'phase1_masks.dart';

/// O tipo de cada família, só para a cor do sprite (o tipo do jogo vem de `creatures.json`).
const Map<String, EcoType> spriteFamilyType = {
  'soot': EcoType.fire,
  'frond': EcoType.plant,
  'rill': EcoType.water,
  'hum': EcoType.electric,
  'clod': EcoType.earth,
  'rust': EcoType.metal,
  'glare': EcoType.light,
  'shade': EcoType.shadow,
  'wisp': EcoType.spectral,
  'bit': EcoType.digital,
  'sprig': EcoType.fae,
  'wyrm': EcoType.draconic,
};

const int _scale = 3;

/// A chave da Fagulha de uma família (`hum.mote`).
String moteKey(String family) => '$family.mote';

bool hasPhase1Sprite(String key) => phase1Masks.containsKey(key);

/// A matriz 48 x 48 de [key] (`hum.eco`, `hum.spirit`, `hum.mote`): `O` contorno, `B` corpo, `L` luz, `D` sombra, `v`
/// costura, `E` olho.
List<String> phase1Rows(String key) {
  final mask = phase1Masks[key] ?? (throw StateError('Sem silhueta para $key'));
  final n = mask.length * _scale;
  String cell(int x, int y) => x < 0 || y < 0 || x >= n || y >= n ? '.' : mask[y ~/ _scale][x ~/ _scale];
  bool body(int x, int y) => cell(x, y) != '.';
  return [
    for (var y = 0; y < n; y++)
      [
        for (var x = 0; x < n; x++)
          switch (cell(x, y)) {
            '.' => body(x - 1, y) || body(x + 1, y) || body(x, y - 1) || body(x, y + 1) ? 'O' : '.',
            'e' => 'E',
            'v' => 'v',
            _ => !body(x, y - 1) ? 'L' : (!body(x, y + 1) ? 'D' : 'B'),
          },
      ].join(),
  ];
}

int _mix(int argb, int toward, double k) {
  int ch(int shift) => (((argb >> shift) & 0xff) + ((((toward >> shift) & 0xff) - ((argb >> shift) & 0xff)) * k)).round();
  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

/// A paleta do sprite provisório de um tipo.
Map<String, int> phase1Palette(EcoType type) {
  final base = typeColor(type).toARGB32();
  return {'O': 0xFF1A1424, 'B': base, 'L': _mix(base, 0xFFFFFFFF, 0.4), 'D': _mix(base, 0xFF1A1424, 0.4), 'v': 0xFF9B7BFF, 'u': 0xFF6A4FD0, 'E': 0xFFF0EEF8};
}

/// O tipo da família de [key], para a cor.
EcoType spriteTypeOf(String key) => spriteFamilyType[familyOfId(key)] ?? EcoType.fire;
