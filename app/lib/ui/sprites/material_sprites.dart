/// Os materiais no mapa (0.23.1): um sprite pequeno por item que nasce no chão, no lugar da caixinha colorida. Só
/// dados, no mesmo formato de `mapStamps` / `mapStampLegend` de `map_style.dart`: um caractere por pixel de arte, `.`
/// transparente, o resto pela legenda, que aponta para [materialPalette].
///
/// Regras: sprite de pé (não gira nem escala com o mapa), 1 caractere = 1 pixel de arte (3 dp), a base da última linha
/// no ponto do spawn, contorno `#1a1424`. Nenhuma cor aqui é o violeta do Véu, o ciano do sinal ou o laranja da
/// Essência, e todo material tem contorno fechado e não pisca: é isso que o separa da Fagulha (cruz sem contorno, que
/// pulsa) e do Eco (sprite grande com anel).
library;

/// As cores dos materiais (ARGB). Três tons por material: `_light`, base, `_dark`.
const Map<String, int> materialPalette = {
  'outline': 0xFF1A1424,
  'chalk_light': 0xFFF4F0E2,
  'chalk': 0xFFD8D2C0,
  'chalk_dark': 0xFFA8A090,
  // Ectoplasma: verde pálido, longe do ciano do sinal.
  'ecto_light': 0xFFE2F6C8,
  'ecto': 0xFFA8DC8C,
  'ecto_dark': 0xFF6AA868,
  // Carmesim: o vermelho da Lua Carmim, longe do laranja brasa.
  'crimson_light': 0xFFFF8A8A,
  'crimson': 0xFFD8324A,
  'crimson_dark': 0xFF8E1C36,
  'herb_light': 0xFF8AD06A,
  'herb': 0xFF4E9E48,
  'herb_dark': 0xFF2E6E3A,
  'twine': 0xFFC9963A,
  'ice_light': 0xFFF0FAFF,
  'ice': 0xFFB4DCF2,
  'ice_dark': 0xFF7AA8D4,
  'meteor_light': 0xFF8A7E8E,
  'meteor': 0xFF5A5064,
  'meteor_dark': 0xFF3A3244,
  'gold': 0xFFF2D15A,
  'prism_white': 0xFFFDFBFF,
  'prism_pink': 0xFFFF9AC8,
  'prism_yellow': 0xFFF6E27A,
  'prism_blue': 0xFF8AB4FF,
  'glass': 0xFFE6F4FF,
  'water': 0xFF5AA0E6,
  'water_dark': 0xFF3A6EB8,
  'cork': 0xFFB08A5A,
  'stone_light': 0xFFA8A4B4,
  'stone': 0xFF7C788C,
  'stone_dark': 0xFF56526A,
  'metal_light': 0xFFB4C0C8,
  'metal': 0xFF7E8A94,
  'metal_dark': 0xFF56606C,
  'rust': 0xFFA8553D,
  'wood_end': 0xFFE6C48E,
  'wood_light': 0xFFC89A62,
  'wood': 0xFF9A6A3E,
  'wood_dark': 0xFF6A4628,
};

/// O sprite de cada material, pela id do item.
const Map<String, List<String>> materialSprites = {
  // Giz: o bastão branco deitado na diagonal. 7 x 8.
  'item.chalk': [
    '....OO.',
    '...OllO',
    '..OllcO',
    '.OllcO.',
    'OllcO..',
    'OlcdO..',
    'OcdO...',
    '.OO....',
  ],
  // Ectoplasma: a gota gorda verde pálida, escorrendo em três pingos. 7 x 7.
  'item.ectoplasm': [
    '..OOO..',
    '.OlllO.',
    'OllgggO',
    'OlggggO',
    'OggdgdO',
    'OgOdOdO',
    '.O.O.O.',
  ],
  // Essência carmesim: a gota vermelha de ponta para cima. 7 x 8.
  'item.essence.crimson': [
    '...O...',
    '..OlO..',
    '..OrO..',
    '.OlrrO.',
    'OlrrrdO',
    'OrrrddO',
    '.OrddO.',
    '..OOO..',
  ],
  // Ervas: o maço de três folhas amarrado com barbante. 7 x 8.
  'item.herbs': [
    '.O.O.O.',
    'OlOlOlO',
    'OgOgOgO',
    'OlgggdO',
    '.OgggO.',
    '..OtO..',
    '..OdO..',
    '...O...',
  ],
  // Cristal de gelo: duas agulhas de base reta, a da esquerda mais alta. 7 x 8.
  'item.ice_crystal': [
    '..O....',
    '.OlO.O.',
    '.OlOOlO',
    'OliOliO',
    'OliiliO',
    'OliiidO',
    'OiiiddO',
    '.OOOOO.',
  ],
  // Meteorito: a pedra escura e arredondada com um ponto ainda quente. 8 x 7.
  'item.meteorite': [
    '..OOOO..',
    '.OllmmO.',
    'OlmmdmmO',
    'OmmymmdO',
    'OmdmmddO',
    '.OmdddO.',
    '..OOOO..',
  ],
  // Fragmento de luz: o caco triangular com as faixas rosa, amarela e azul. 7 x 7.
  'item.prism_shard': [
    '...O...',
    '..OwO..',
    '..OwpO.',
    '.OwpyO.',
    '.OwpybO',
    'OwppybO',
    'OOOOOOO',
  ],
  // Água pura: o frasco de rolha, meio cheio. 5 x 8.
  'item.pure_water': [
    '.OOO.',
    '.OkO.',
    '.OgO.',
    'OgggO',
    'OgwwO',
    'OwwwO',
    'OwwdO',
    '.OOO.',
  ],
  // Runa: a pedra de pé com o traço dourado gravado. 7 x 8.
  'item.rune': [
    '..OOO..',
    '.OlllO.',
    'OlsysdO',
    'OlyyydO',
    'OssysdO',
    'OssysdO',
    'OsddddO',
    'OOOOOOO',
  ],
  // Sucata: a engrenagem de dentes e furo, com ferrugem embaixo. 8 x 7.
  'item.scrap': [
    '.OO..OO.',
    'OllOOlmO',
    'OlmmmmdO',
    '.OmOOmO.',
    'OlmOOmdO',
    'OmrmmrdO',
    '.OOOOOO.',
  ],
  // Madeira: a tora deitada, com o topo claro do corte à esquerda. 8 x 6.
  'item.wood': [
    '.OOOOOOO',
    'OeeOllwO',
    'OeceOwwO',
    'OeeeOwdO',
    '.OeOwddO',
    '..OOOOO.',
  ],
};

/// Para cada sprite, a chave de [materialPalette] de cada caractere.
const Map<String, Map<String, String>> materialSpriteLegend = {
  'item.chalk': {'O': 'outline', 'l': 'chalk_light', 'c': 'chalk', 'd': 'chalk_dark'},
  'item.ectoplasm': {'O': 'outline', 'l': 'ecto_light', 'g': 'ecto', 'd': 'ecto_dark'},
  'item.essence.crimson': {'O': 'outline', 'l': 'crimson_light', 'r': 'crimson', 'd': 'crimson_dark'},
  'item.herbs': {'O': 'outline', 'l': 'herb_light', 'g': 'herb', 'd': 'herb_dark', 't': 'twine'},
  'item.ice_crystal': {'O': 'outline', 'l': 'ice_light', 'i': 'ice', 'd': 'ice_dark'},
  'item.meteorite': {'O': 'outline', 'l': 'meteor_light', 'm': 'meteor', 'd': 'meteor_dark', 'y': 'gold'},
  'item.prism_shard': {'O': 'outline', 'w': 'prism_white', 'p': 'prism_pink', 'y': 'prism_yellow', 'b': 'prism_blue'},
  'item.pure_water': {'O': 'outline', 'k': 'cork', 'g': 'glass', 'w': 'water', 'd': 'water_dark'},
  'item.rune': {'O': 'outline', 'l': 'stone_light', 's': 'stone', 'd': 'stone_dark', 'y': 'gold'},
  'item.scrap': {'O': 'outline', 'l': 'metal_light', 'm': 'metal', 'd': 'metal_dark', 'r': 'rust'},
  'item.wood': {'O': 'outline', 'e': 'wood_end', 'c': 'wood_dark', 'l': 'wood_light', 'w': 'wood', 'd': 'wood_dark'},
};
