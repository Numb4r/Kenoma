/// O estilo do mapa 2D (laboratório visual da 0.21.0): paleta, receitas de chão, carimbos de pixel, estilo de parede e
/// telhado, curva de luz e céu do horizonte. Só dados e funções puras, cores em `int` ARGB; quem desenha é o
/// renderizador. O guia completo está em `docs/art/estilo-mapa.md`.
///
/// Regras que valem para tudo aqui: pixel de arte de 3 dp, carimbo nunca gira nem escala (só a posição acompanha o
/// mapa), contorno `#1a1424` e nunca preto puro, e as três cores da magia (violeta, ciano, laranja brasa) não entram
/// na paleta da cidade.
library;

const int _outline = 0xFF1A1424;

// Chão: cada material num degrau de valor (do mais escuro ao mais claro: asfalto, água, sagrado, baldio, grama,
// concreto, quintal, cimentado, calçada, piso do Iluminado).
const int _asphaltDark = 0xFF2B2F3D, _asphalt = 0xFF343949, _asphaltLight = 0xFF40465A;
const int _waterDark = 0xFF234A70, _water = 0xFF2A5580, _waterLight = 0xFF3B6C9A;
const int _sacredDark = 0xFF4A4560, _sacred = 0xFF5A5474, _sacredLight = 0xFF6C668A;
const int _dirtDark = 0xFF5F5443, _dirt = 0xFF736652, _dirtLight = 0xFF877A64;
const int _grassDark = 0xFF2F7446, _grass = 0xFF429658, _grassLight = 0xFF5FB26A;
const int _concreteDark = 0xFF6A707F, _concrete = 0xFF7C8291, _concreteLight = 0xFF8E94A2;
const int _yardDark = 0xFF5A8A4E, _yard = 0xFF6FA05E, _yardLight = 0xFF8AB874;
const int _resDark = 0xFF847C6F, _res = 0xFF968E80, _resLight = 0xFFA8A092;
const int _sidewalkDark = 0xFF8E92A0, _sidewalk = 0xFFA3A7B3, _sidewalkLight = 0xFFB6BAC4;
const int _litDark = 0xFFADABB9, _lit = 0xFFC2C0CC, _litLight = 0xFFD4D2DC;

// Paredes e telhados.
const int _wallRes = 0xFFD9C8A8, _wallResShade = 0xFFB09F82;
const int _wallUrban = 0xFF9A9FB0, _wallUrbanShade = 0xFF767B8E;
const int _wallLit = 0xFFE2DFE8, _wallLitShade = 0xFFB9B6C6;
const int _wallSacred = 0xFFE6E0D0, _wallSacredShade = 0xFFB8B2A0;
const int _wallBare = 0xFF9A7462, _wallBareShade = 0xFF765848;
const int _roofTileDark = 0xFF84402F, _roofTile = 0xFFA8553D, _roofTileLight = 0xFFC4704F;
// Laje: cinza quente de valor médio (luma 108), bem abaixo da calçada (167) e do concreto (130). É a massa dominante
// do Centro, então fica quieta: quem brilha na cena é a calçada, a parede no sol e a magia.
const int _roofSlabDark = 0xFF56525A, _roofSlab = 0xFF6E6A70, _roofSlabLight = 0xFF86828A;
const int _roofTarDark = 0xFF3D4254, _roofTar = 0xFF4A4F62;
const int _roofMetalDark = 0xFF7E8A94, _roofMetal = 0xFF9AA7B0, _roofMetalLight = 0xFFB4C0C8;
const int _roofSlateDark = 0xFF566C8A, _roofSlate = 0xFF6F86A6, _roofSlateLight = 0xFF8AA0BC;

/// A paleta do mapa. Nomes estáveis: os carimbos ([mapStampLegend]) apontam para estas chaves.
const Map<String, int> mapPalette = {
  'outline': _outline,
  // Sombra projetada (prédio, árvore): o contorno ameixa a 42%. O renderizador lê o alfa daqui.
  'shadow': 0x6B1A1424,
  'asphalt_dark': _asphaltDark,
  'asphalt': _asphalt,
  'asphalt_light': _asphaltLight,
  'lane': 0xFFC9C4A8,
  'lane_worn': 0xFF8F8C7C,
  'oil': 0xFF22242F,
  'water_dark': _waterDark,
  'water': _water,
  'water_light': _waterLight,
  'foam': 0xFFB8DCEA,
  'sacred_dark': _sacredDark,
  'sacred': _sacred,
  'sacred_light': _sacredLight,
  'dirt_dark': _dirtDark,
  'dirt': _dirt,
  'dirt_light': _dirtLight,
  'weed_dark': 0xFF4A5A32,
  'weed': 0xFF64783E,
  'weed_light': 0xFF8A9A52,
  'grass_dark': _grassDark,
  'grass': _grass,
  'grass_light': _grassLight,
  'yard_dark': _yardDark,
  'yard': _yard,
  'yard_light': _yardLight,
  'flower_white': 0xFFF0EEE0,
  'flower_yellow': 0xFFF2D15A,
  'flower_pink': 0xFFE58FB0,
  'flower_core': 0xFFC9963A,
  'canopy_dark': 0xFF1F5A3A,
  'canopy': 0xFF2C7048,
  'canopy_light': 0xFF45905A,
  'concrete_dark': _concreteDark,
  'concrete': _concrete,
  'concrete_light': _concreteLight,
  'res_dark': _resDark,
  'res': _res,
  'res_light': _resLight,
  'sidewalk_dark': _sidewalkDark,
  'sidewalk': _sidewalk,
  'sidewalk_light': _sidewalkLight,
  'lit_dark': _litDark,
  'lit': _lit,
  'lit_light': _litLight,
  'pebble': 0xFFB0B0B8,
  'pebble_dark': 0xFF6E6E78,
  // Muro de quintal.
  'fence': 0xFFBEB8AA,
  'fence_dark': 0xFF8C867A,
  'wall_res': _wallRes,
  'wall_res_shade': _wallResShade,
  'wall_res_b': 0xFFC2CCC8,
  'wall_res_b_shade': 0xFF96A29E,
  'wall_urban': _wallUrban,
  'wall_urban_shade': _wallUrbanShade,
  'wall_lit': _wallLit,
  'wall_lit_shade': _wallLitShade,
  'wall_sacred': _wallSacred,
  'wall_sacred_shade': _wallSacredShade,
  'wall_bare': _wallBare,
  'wall_bare_shade': _wallBareShade,
  'roof_tile_dark': _roofTileDark,
  'roof_tile': _roofTile,
  'roof_tile_light': _roofTileLight,
  'roof_slab_dark': _roofSlabDark,
  'roof_slab': _roofSlab,
  'roof_slab_light': _roofSlabLight,
  'roof_tar_dark': _roofTarDark,
  'roof_tar': _roofTar,
  'roof_metal_dark': _roofMetalDark,
  'roof_metal': _roofMetal,
  'roof_metal_light': _roofMetalLight,
  'roof_slate_dark': _roofSlateDark,
  'roof_slate': _roofSlate,
  'roof_slate_light': _roofSlateLight,
  'window_off': 0xFF2B3044,
  'window_on': 0xFFFFD98A,
  'window_on_cool': 0xFFDFE8FF,
  // Neon do Iluminado: rosa, lima e azul. De propósito nenhum é violeta do Véu, ciano do sinal ou laranja brasa.
  'neon_a': 0xFFFF4F9A,
  'neon_b': 0xFFE8FF5A,
  'neon_c': 0xFF4F8CFF,
  // De dia o neon está apagado: o renderizador troca `neon_*` por esta cor enquanto `lightsOn` for falso.
  'neon_off': 0xFF6C6880,
  'sign_dark': 0xFF2B2540,
  'pole': 0xFF3D4254,
  'pole_head': 0xFFC9CDD8,
  'lamp_glow': 0xFFFFD98A,
  'lamp_glow_lit': 0xFFFFF3D0,
  'cloud': 0xFFECEAF2,
  'cloud_shade': 0xFFC2C0D2,
};

/// A receita de um chão: três tons, quanto pontilhado e quais carimbos.
class GroundRecipe {
  const GroundRecipe({required this.base, required this.dark, required this.light, required this.ditherPct, required this.stamps, required this.stampsPer100Px});

  /// Os três tons em ARGB.
  final int base, dark, light;

  /// De cada 100 pixels de arte, quantos saem do tom base: metade vira [dark], metade [light] (sorteio por hash da
  /// posição no mundo, nunca da tela).
  final int ditherPct;

  /// Carimbos de [mapStamps] sorteados neste chão; um nome repetido pesa mais no sorteio.
  final List<String> stamps;

  /// Quantos carimbos num bloco de 100 x 100 pixels de arte.
  final int stampsPer100Px;
}

/// Chão por bioma (`biomes.json`; `empty` e `void` são o Vazio) e por superfície (`sidewalk`, `road`, `yard`, `lot`).
const Map<String, GroundRecipe> groundRecipes = {
  'empty': _emptyGround,
  'void': _emptyGround,
  'urban': GroundRecipe(base: _concrete, dark: _concreteDark, light: _concreteLight, ditherPct: 6, stamps: ['crack', 'pebble', 'oil'], stampsPer100Px: 8),
  'green': GroundRecipe(base: _grass, dark: _grassDark, light: _grassLight, ditherPct: 18, stamps: ['tuft', 'tuft', 'tuft', 'tuft_b', 'tuft_b', 'flower_a', 'flower_b', 'flower_c', 'bush'], stampsPer100Px: 60),
  'water': GroundRecipe(base: _water, dark: _waterDark, light: _waterLight, ditherPct: 10, stamps: ['ripple'], stampsPer100Px: 20),
  'residential': GroundRecipe(base: _res, dark: _resDark, light: _resLight, ditherPct: 8, stamps: ['pebble', 'tuft_b', 'crack'], stampsPer100Px: 10),
  'lit': GroundRecipe(base: _lit, dark: _litDark, light: _litLight, ditherPct: 4, stamps: ['pebble'], stampsPer100Px: 3),
  'sacred': GroundRecipe(base: _sacred, dark: _sacredDark, light: _sacredLight, ditherPct: 8, stamps: ['pebble', 'tuft_b', 'flower_a'], stampsPer100Px: 10),
  'sidewalk': GroundRecipe(base: _sidewalk, dark: _sidewalkDark, light: _sidewalkLight, ditherPct: 5, stamps: ['crack', 'tuft_b'], stampsPer100Px: 4),
  'road': GroundRecipe(base: _asphalt, dark: _asphaltDark, light: _asphaltLight, ditherPct: 10, stamps: ['crack', 'oil', 'patch'], stampsPer100Px: 6),
  'yard': GroundRecipe(base: _yard, dark: _yardDark, light: _yardLight, ditherPct: 14, stamps: ['tuft', 'tuft_b', 'flower_c', 'bush'], stampsPer100Px: 35),
  'lot': GroundRecipe(base: _dirt, dark: _dirtDark, light: _dirtLight, ditherPct: 16, stamps: ['weed', 'weed', 'tuft', 'pebble'], stampsPer100Px: 45),
};

const GroundRecipe _emptyGround = GroundRecipe(base: _dirt, dark: _dirtDark, light: _dirtLight, ditherPct: 14, stamps: ['weed', 'tuft', 'pebble', 'pebble'], stampsPer100Px: 25);

/// Os chãos que levam um módulo repetido por baixo dos carimbos (paginação de piso).
const Map<String, String> groundPatterns = {'sidewalk': 'sidewalk_tile', 'lit': 'floor_lit'};

/// Carimbos de pixel: um caractere por pixel de arte, `.` transparente, o resto pela legenda de [mapStampLegend].
/// Os de nome `roof_*`, `sidewalk_tile`, `floor_lit` e `window*` são módulos que se repetem; os outros são avulsos.
const Map<String, List<String>> mapStamps = {
  // Tufo de grama (três folhas) e o tufo pequeno.
  'tuft': [
    'l...l',
    '.l.l.',
    '.dld.',
  ],
  'tuft_b': [
    'l.l',
    '.d.',
  ],
  // Flores do Verde: branca, rosa e amarela.
  'flower_a': [
    '.w.',
    'wyw',
    '.d.',
  ],
  'flower_b': [
    'p.p',
    '.y.',
    'p.p',
  ],
  'flower_c': [
    '.y.',
    'yoy',
    '.d.',
  ],
  // Mato de terreno baldio.
  'weed': [
    '..l..',
    'l.w.l',
    '.wlw.',
    '.wdw.',
    '..d..',
  ],
  'pebble': [
    '.pp.',
    'pppk',
    '.kk.',
  ],
  // Rachadura de asfalto e de calçada.
  'crack': [
    'c......',
    '.cc....',
    '...c..c',
    '....cc.',
    '....c..',
  ],
  'oil': [
    '.oooo.',
    'oooooo',
    'ooosoo',
    '.ooo..',
  ],
  // Remendo de asfalto.
  'patch': [
    'ddddddd',
    'dlllllk',
    'dlllllk',
    'dkkkkkk',
  ],
  // Reflexo na água.
  'ripple': [
    '.lll..',
    'l...ll',
  ],
  // Copa de árvore vista de cima e a sombra dela (o renderizador desloca a sombra pelo sol).
  'tree': [
    '....OOOOOO....',
    '..OOllllggOO..',
    '.OllllllgggdO.',
    '.OlllglggggdO.',
    'OlllgggggggddO',
    'OllgggggggdgdO',
    'OlggglggggdddO',
    'OggggggggdgddO',
    'OgggggdggddddO',
    'OggdgggggddddO',
    '.OgggggdddddO.',
    '..OOddddddOO..',
    '....OOOOOO....',
  ],
  'tree_shadow': [
    '...ssssssss...',
    '.ssssssssssss.',
    'ssssssssssssss',
    'ssssssssssssss',
    'ssssssssssssss',
    '.ssssssssssss.',
    '...ssssssss...',
  ],
  'bush': [
    '..OOO..',
    '.OllgO.',
    'OllgggO',
    'OlgggdO',
    'OggdddO',
    '.OOOOO.',
  ],
  // Poste visto de cima: a cabeça com a lâmpada e o braço. A poça de luz é desenhada à parte.
  'lamp': [
    '.h.',
    'hgh',
    '.h.',
    '.p.',
    '.p.',
  ],
  // Letreiros do Iluminado, sem texto: barra, lâmina vertical, anel e seta.
  'sign_bar': [
    'OOOOOOOOOO',
    'OkaaaaaakO',
    'OkkkkkkkkO',
    'OOOOOOOOOO',
  ],
  'sign_blade': [
    'OOOO',
    'OccO',
    'OkkO',
    'OccO',
    'OkkO',
    'OccO',
    'OkkO',
    'OccO',
    'OOOO',
  ],
  'neon_ring': [
    '.bbbb.',
    'b....b',
    'b.bb.b',
    'b.bb.b',
    'b....b',
    '.bbbb.',
  ],
  'neon_arrow': [
    'a.....a',
    'aa...aa',
    '.aa.aa.',
    '..aaa..',
    '...a...',
  ],
  // Telha de cerâmica: fileiras de capa (clara) e canal (escuro), com o ressalto a cada 4 px.
  'roof_tile': [
    'ltdt',
    'ltdt',
    'ltdt',
    'tddd',
  ],
  // Laje de concreto: lisa, SEM junta (grade é só de calçada), com manchas esparsas num módulo de 12 px.
  'roof_slab': [
    'ssssssssssss',
    'sssssssslsss',
    'ssdsssssssss',
    'ssssssssssss',
    'ssssssssssss',
    'sssssssssdds',
    'ssssssssssds',
    'ssssssssssss',
    'ssslssssssss',
    'ssssssssssss',
    'sssssssdssss',
    'ssssssssssss',
  ],
  // Caixa d'água azul: avulsa, uma por laje grande (posição por hash do prédio), por cima do telhado.
  'roof_tank': [
    '.OOO.',
    'OlllO',
    'OlbbO',
    'ObbdO',
    '.OOO.',
  ],
  // Manta escura do comércio do Iluminado, com a caixa do ar-condicionado.
  'roof_tar': [
    'tttttttt',
    'tddddttt',
    'tdaadttt',
    'tdaadttt',
    'tddddttt',
    'tttttttt',
    'ttttttdt',
    'tttttttt',
  ],
  // Telha metálica de galpão.
  'roof_metal': [
    'mmlk',
    'mmlk',
  ],
  // Ardósia do Sagrado, em escama.
  'roof_slate': [
    'sssd',
    'lssd',
    'dddd',
    'sdss',
    'sdls',
    'dddd',
  ],
  // Paginação da calçada e do piso claro do Iluminado.
  'sidewalk_tile': [
    'sssd',
    'sssd',
    'sssd',
    'dddd',
  ],
  'floor_lit': [
    'lllllffd',
    'lllllffd',
    'lllllffd',
    'lllllffd',
    'lllllffd',
    'fffffffd',
    'fffffffd',
    'dddddddd',
  ],
  // Janela de parede: módulo de 4 x 4 que se repete ao longo da parede; `.` deixa a parede aparecer.
  'window_off': [
    '....',
    '.oo.',
    '.oo.',
    '....',
  ],
  'window_on': [
    '....',
    '.nn.',
    '.nn.',
    '....',
  ],
  // Vitrine do comércio: mais larga.
  'window_shop_off': [
    '......',
    '.oooo.',
    '.oooo.',
    '......',
  ],
  'window_shop_on': [
    '......',
    '.nnnn.',
    '.nnnn.',
    '......',
  ],
  // Nuvem da faixa do horizonte.
  'cloud': [
    '....cccc........',
    '..cccccccc.ccc..',
    '.cccccccccccccc.',
    'cccccccccccccccc',
    '.sssssssssssss..',
  ],
};

/// Para cada carimbo, a chave de [mapPalette] de cada caractere.
const Map<String, Map<String, String>> mapStampLegend = {
  'tuft': {'l': 'grass_light', 'd': 'grass_dark'},
  'tuft_b': {'l': 'grass_light', 'd': 'grass_dark'},
  'flower_a': {'w': 'flower_white', 'y': 'flower_yellow', 'd': 'grass_dark'},
  'flower_b': {'p': 'flower_pink', 'y': 'flower_yellow'},
  'flower_c': {'y': 'flower_yellow', 'o': 'flower_core', 'd': 'grass_dark'},
  'weed': {'l': 'weed_light', 'w': 'weed', 'd': 'weed_dark'},
  'pebble': {'p': 'pebble', 'k': 'pebble_dark'},
  'crack': {'c': 'outline'},
  'oil': {'o': 'oil', 's': 'asphalt_light'},
  'patch': {'d': 'asphalt_dark', 'l': 'asphalt_light', 'k': 'oil'},
  'ripple': {'l': 'water_light'},
  'tree': {'O': 'outline', 'l': 'canopy_light', 'g': 'canopy', 'd': 'canopy_dark'},
  'tree_shadow': {'s': 'shadow'},
  'bush': {'O': 'outline', 'l': 'canopy_light', 'g': 'canopy', 'd': 'canopy_dark'},
  'lamp': {'h': 'pole_head', 'g': 'lamp_glow', 'p': 'pole'},
  'sign_bar': {'O': 'outline', 'k': 'sign_dark', 'a': 'neon_a'},
  'sign_blade': {'O': 'outline', 'k': 'sign_dark', 'c': 'neon_c'},
  'neon_ring': {'b': 'neon_b'},
  'neon_arrow': {'a': 'neon_a'},
  'roof_tile': {'l': 'roof_tile_light', 't': 'roof_tile', 'd': 'roof_tile_dark'},
  'roof_slab': {'s': 'roof_slab', 'l': 'roof_slab_light', 'd': 'roof_slab_dark'},
  'roof_tank': {'O': 'outline', 'l': 'roof_slate_light', 'b': 'roof_slate', 'd': 'roof_slate_dark'},
  'roof_tar': {'t': 'roof_tar', 'd': 'roof_tar_dark', 'a': 'roof_metal'},
  'roof_metal': {'m': 'roof_metal', 'l': 'roof_metal_light', 'k': 'roof_metal_dark'},
  'roof_slate': {'s': 'roof_slate', 'l': 'roof_slate_light', 'd': 'roof_slate_dark'},
  'sidewalk_tile': {'s': 'sidewalk', 'd': 'sidewalk_dark'},
  'floor_lit': {'l': 'lit_light', 'f': 'lit', 'd': 'lit_dark'},
  'window_off': {'o': 'window_off'},
  'window_on': {'n': 'window_on'},
  'window_shop_off': {'o': 'window_off'},
  'window_shop_on': {'n': 'window_on_cool'},
  'cloud': {'c': 'cloud', 's': 'cloud_shade'},
};

/// Parede e telhado de um prédio.
class WallStyle {
  const WallStyle({required this.wall, required this.wallShade, required this.roof, required this.roofEdge, required this.roofPattern, required this.window});

  /// Parede no lado da luz e no lado da sombra, telhado (o tom base do módulo) e a borda de 1 px do telhado.
  final int wall, wallShade, roof, roofEdge;

  /// O módulo de [mapStamps] que cobre o telhado.
  final String roofPattern;

  /// O prefixo do módulo de janela: o renderizador usa `<window>_on` ou `<window>_off`. Vazio: parede cega.
  final String window;
}

const WallStyle _houseStyle = WallStyle(wall: _wallRes, wallShade: _wallResShade, roof: _roofTile, roofEdge: _roofTileDark, roofPattern: 'roof_tile', window: 'window');
const WallStyle _blockStyle = WallStyle(wall: _wallUrban, wallShade: _wallUrbanShade, roof: _roofSlab, roofEdge: _roofSlabDark, roofPattern: 'roof_slab', window: 'window');
const WallStyle _shopStyle = WallStyle(wall: _wallUrban, wallShade: _wallUrbanShade, roof: _roofSlab, roofEdge: _roofSlabDark, roofPattern: 'roof_slab', window: 'window_shop');
const WallStyle _shopLitStyle = WallStyle(wall: _wallLit, wallShade: _wallLitShade, roof: _roofTar, roofEdge: _roofTarDark, roofPattern: 'roof_tar', window: 'window_shop');
const WallStyle _shedStyle = WallStyle(wall: _wallUrbanShade, wallShade: _concreteDark, roof: _roofMetal, roofEdge: _roofMetalDark, roofPattern: 'roof_metal', window: '');
const WallStyle _sacredStyle = WallStyle(wall: _wallSacred, wallShade: _wallSacredShade, roof: _roofSlate, roofEdge: _roofSlateDark, roofPattern: 'roof_slate', window: 'window');
// Telha de fibrocimento (o módulo metálico): a laje nova teria a luma da terra do Vazio.
const WallStyle _bareStyle = WallStyle(wall: _wallBare, wallShade: _wallBareShade, roof: _roofMetal, roofEdge: _roofMetalDark, roofPattern: 'roof_metal', window: 'window');

const Set<String> _sacredTypes = {'church', 'chapel', 'cathedral', 'temple', 'mosque', 'synagogue', 'shrine', 'religious'};
const Set<String> _houseTypes = {'house', 'residential', 'detached', 'semidetached_house', 'terrace', 'bungalow', 'hut', 'cabin'};
const Set<String> _blockTypes = {'apartments', 'dormitory', 'hotel', 'office', 'school', 'university', 'hospital', 'public', 'civic'};
const Set<String> _shopTypes = {'commercial', 'retail', 'supermarket', 'kiosk'};
const Set<String> _shedTypes = {'industrial', 'warehouse', 'hangar', 'shed', 'garage', 'garages', 'roof'};

/// O estilo de um prédio pelo `building=*` do OSM e pelo bioma onde ele está. O tipo manda; `yes` e o que não se
/// conhece seguem o bioma, que é o que dá cara ao bairro.
WallStyle wallStyleFor(String buildingType, String biome) {
  if (_sacredTypes.contains(buildingType)) return _sacredStyle;
  if (_houseTypes.contains(buildingType)) return _houseStyle;
  if (_shopTypes.contains(buildingType)) return biome == 'lit' ? _shopLitStyle : _shopStyle;
  if (_blockTypes.contains(buildingType)) return _blockStyle;
  if (_shedTypes.contains(buildingType)) return _shedStyle;
  return switch (biome) {
    'sacred' => _sacredStyle,
    'residential' || 'green' || 'water' => _houseStyle,
    'lit' => _shopLitStyle,
    'urban' => _blockStyle,
    _ => _bareStyle, // Vazio: tijolo sem reboco e fibrocimento
  };
}

/// Mistura duas cores ARGB ([k] de 0 a 1), canal a canal. Serve para o céu por clima (ver o guia).
int mixArgb(int a, int b, double k) {
  int ch(int s) => (((a >> s) & 0xff) + (((b >> s) & 0xff) - ((a >> s) & 0xff)) * k).round();
  return (ch(24) << 24) | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

/// As altitudes do sol, em graus, em que a luz e o céu têm cor marcada; entre duas, mistura linear.
const List<double> _altKeys = [-18, -6, 0, 8, 35, 90];

/// O tom por cima da cena em cada altitude de [_altKeys]: noite, crepúsculo, sol no horizonte, hora dourada, meia
/// manhã, zênite. O quente dura até os 35 graus para a manhã (7h30, sol a ~29 graus) não ser igual ao meio-dia.
const List<int> _lightTone = [0xFF141033, 0xFF2A1F55, 0xFFD8707A, 0xFFFFC98A, 0xFFFFE2B0, 0xFFFFFFFF];
const List<double> _lightAlpha = [0.58, 0.46, 0.24, 0.16, 0.09, 0.0];

/// O céu em cada altitude de [_altKeys], de cima para baixo da faixa do horizonte.
const List<List<int>> _sky = [
  [0xFF120E2A, 0xFF1A1740, 0xFF26235A, 0xFF343A6E],
  [0xFF1A1740, 0xFF33306E, 0xFF6A4F8A, 0xFFC9708A],
  [0xFF2F3F7A, 0xFF7A6AA8, 0xFFE58FA0, 0xFFFFC98A],
  [0xFF4A78B8, 0xFF8FB0D8, 0xFFF2D6B8, 0xFFFFE6B8],
  [0xFF4F8FD0, 0xFF7FB4E0, 0xFFB8D8EE, 0xFFE6E6DC],
  [0xFF2F78C8, 0xFF5A9EDC, 0xFF9CCAEE, 0xFFD0E6F5],
];

/// O trecho de [_altKeys] onde cai [alt] e a fração dentro dele.
(int, double) _segment(double alt) {
  final a = alt.isNaN ? _altKeys.last : alt.clamp(_altKeys.first, _altKeys.last).toDouble();
  var i = 0;
  while (i < _altKeys.length - 2 && a > _altKeys[i + 1]) {
    i++;
  }
  return (i, (a - _altKeys[i]) / (_altKeys[i + 1] - _altKeys[i]));
}

/// O tom de luz por cima da cena para a altitude do sol em graus (de -18 a 90; fora disso, o extremo). Pinta-se um
/// retângulo de cor [argb] com opacidade [alpha] sobre chão, prédios e sprites, e ANTES das luzes (poças de poste,
/// janelas acesas, neon), que ficam por cima sem tom.
({int argb, double alpha}) sceneLight(double sunAltDeg) {
  final (i, k) = _segment(sunAltDeg);
  return (argb: mixArgb(_lightTone[i], _lightTone[i + 1], k), alpha: _lightAlpha[i] + (_lightAlpha[i + 1] - _lightAlpha[i]) * k);
}

/// Postes, janelas e neon acesos: do sol 1 grau abaixo do horizonte até ele voltar a essa altura.
bool lightsOn(double sunAltDeg) => sunAltDeg < -1;

/// As 4 cores da faixa do horizonte, de cima para baixo, para a altitude do sol em graus.
List<int> skyGradient(double sunAltDeg) {
  final (i, k) = _segment(sunAltDeg);
  return [for (var c = 0; c < 4; c++) mixArgb(_sky[i][c], _sky[i + 1][c], k)];
}
