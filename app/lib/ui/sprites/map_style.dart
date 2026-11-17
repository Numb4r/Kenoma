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
// concreto, quintal, cimentado, cimento claro, calçada, piso ladrilhado).
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
// Cimento claro (148): o chão neutro do Iluminado e o piso de área comercial. Liso, entre o cimentado e a calçada.
const int _cementDark = 0xFF808492, _cement = 0xFF9094A2, _cementLight = 0xFFA0A4B0;

// Paredes e telhados (0.22.0). O telhado é a face que recebe o sol de cima, então em todo estilo a escada de valor é
// telhado > parede no sol > parede na sombra. Luma da base entre parênteses.
// Paredes (0.23.1, escurecidas para lerem como lateral de prédio; o cinza do Centro puxa para o ameixa do contorno e
// não para o azul do asfalto): reboco (78 / 56), reboco azulado (78 / 57), cinza do Centro em três degraus
// (85 / 63 / 46; o terceiro é a sombra dos prédios de manta), Iluminado (106 / 78), cal do Sagrado (108 / 79), tijolo
// do Vazio (90 / 64). Todas abaixo do telhado mais escuro (manta, 99), menos a do Iluminado e a do Sagrado, que só
// andam com laje (154) e ardósia (149).
const int _wallRes = 0xFF5A4C3C, _wallResShade = 0xFF403630;
const int _wallUrban = 0xFF57525E, _wallUrbanShade = 0xFF403C48, _wallUrbanDeep = 0xFF2F2B38;
const int _wallLit = 0xFF6A6876, _wallLitShade = 0xFF4E4C5A;
const int _wallSacred = 0xFF706C64, _wallSacredShade = 0xFF524E48;
const int _wallBare = 0xFF74523F, _wallBareShade = 0xFF523A30;
// Cerâmica: vermelho-terra (113) e a telha mais nova, mais clara (134). Bem menos saturadas que a brasa.
const int _roofTileDark = 0xFF8A4431, _roofTile = 0xFFB05A40, _roofTileLight = 0xFFCC7655;
const int _roofTileBDark = 0xFF9A5A40, _roofTileB = 0xFFBC7452, _roofTileBLight = 0xFFD49068;
// Laje de concreto: cinza claro e quente (154), lisa. Fica um degrau abaixo da calçada (167); quem a separa do chão é a
// borda, a platibanda, a parede escura e a sombra.
const int _roofSlabDark = 0xFF827F7C, _roofSlab = 0xFF9C9A96, _roofSlabLight = 0xFFB0AEA8;
// Fibrocimento: cinza-esverdeado (141), ondulado.
const int _roofFibroDark = 0xFF6F7A70, _roofFibro = 0xFF879287, _roofFibroLight = 0xFF9BA69A;
// Manta escura (99): o telhado mais escuro da cidade, ainda bem acima do asfalto (57).
const int _roofTarDark = 0xFF4A4E5E, _roofTar = 0xFF5E6272, _roofTarLight = 0xFF72768A;
// Metal de galpão: zinco novo (164) e zinco velho (128).
const int _roofMetalDark = 0xFF7E8A94, _roofMetal = 0xFF9AA7B0, _roofMetalLight = 0xFFB4C0C8;
const int _roofMetalBDark = 0xFF5E6872, _roofMetalB = 0xFF77828C, _roofMetalBLight = 0xFF909BA4;
// Ardósia do Sagrado (149); a caixa d'água usa os mesmos azuis.
const int _roofSlateDark = 0xFF647A98, _roofSlate = 0xFF8298B6, _roofSlateLight = 0xFF9CB0CA;
// Platibanda: a mureta de 1 px por dentro da borda da laje (190) e da manta (140).
const int _parapet = 0xFFC0BEB6, _parapetTar = 0xFF8A8C98;
// Calçada portuguesa do Centro: pedra clara (182) e basalto (94), nunca preto. Um terço escuro: a média (153) fica no
// degrau da calçada.
const int _mosaicLight = 0xFFB8B6B0, _mosaicDark = 0xFF5E5C68;

/// A paleta do mapa. Nomes estáveis: os carimbos ([mapStampLegend]) apontam para estas chaves.
const Map<String, int> mapPalette = {
  'outline': _outline,
  // Sombra projetada (prédio, árvore): o contorno ameixa a 42%. O renderizador lê o alfa daqui.
  'shadow': 0x6B1A1424,
  'asphalt_dark': _asphaltDark,
  'asphalt': _asphalt,
  'asphalt_light': _asphaltLight,
  // Chuva: o asfalto molhado escurece e azula (43 e 34, ainda acima do contorno); `wet_shine` é o brilho do céu nele,
  // em pixels soltos; `lamp_reflect` é o reflexo do poste à noite, uma faixa vertical curta.
  'asphalt_wet': 0xFF262B3C,
  'asphalt_wet_dark': 0xFF1E2231,
  'wet_shine': 0xFF7C88A6,
  'lamp_reflect': 0xFFE8C27A,
  'lane': 0xFFC9C4A8,
  'lane_worn': 0xFF8F8C7C,
  // Faixa de pedestre: listras de 1 px, um pouco mais brancas que a faixa central.
  'crosswalk': 0xFFDAD7C6,
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
  // Mais dois verdes de copa, todos abaixo da grama (118): o amarelado (103; sibipiruna, e o ipê fora da floração) e o
  // fundo (70; mangueira, figueira).
  'canopy_warm_dark': 0xFF38602A,
  'canopy_warm': 0xFF4E7E36,
  'canopy_warm_light': 0xFF6E9E48,
  'canopy_deep_dark': 0xFF17482F,
  'canopy_deep': 0xFF205C3C,
  'canopy_deep_light': 0xFF34784E,
  // Ipê em flor. O ipê-roxo é rosa-magenta (matiz 320), de propósito longe do violeta do Véu; o amarelo é ouro, longe
  // do laranja brasa.
  'ipe_purple_dark': 0xFF8E3E78,
  'ipe_purple': 0xFFB85A9A,
  'ipe_purple_light': 0xFFDA8ABC,
  'ipe_yellow_dark': 0xFFB88A1E,
  'ipe_yellow': 0xFFE6BC2E,
  'ipe_yellow_light': 0xFFF6DC6A,
  'concrete_dark': _concreteDark,
  'concrete': _concrete,
  'concrete_light': _concreteLight,
  'res_dark': _resDark,
  'res': _res,
  'res_light': _resLight,
  'sidewalk_dark': _sidewalkDark,
  'sidewalk': _sidewalk,
  'sidewalk_light': _sidewalkLight,
  // Junta da calçada de concreto (157): só 10 de luma abaixo da calçada, para não virar grade.
  'sidewalk_joint': 0xFF999DAA,
  'cement_dark': _cementDark,
  'cement': _cement,
  'cement_light': _cementLight,
  'mosaic_light': _mosaicLight,
  'mosaic_dark': _mosaicDark,
  'lit_dark': _litDark,
  'lit': _lit,
  'lit_light': _litLight,
  'pebble': 0xFFB0B0B8,
  'pebble_dark': 0xFF6E6E78,
  // Muro de quintal.
  'fence': 0xFFBEB8AA,
  'fence_dark': 0xFF8C867A,
  // Portão de ferro no muro das casas: 3 a 4 px do lado da rua, `gate_dark` no pixel oposto ao sol.
  'gate': 0xFF5E6E7E,
  'gate_dark': 0xFF44505E,
  'wall_res': _wallRes,
  'wall_res_shade': _wallResShade,
  'wall_res_b': 0xFF465252,
  'wall_res_b_shade': 0xFF323C3E,
  'wall_urban': _wallUrban,
  'wall_urban_shade': _wallUrbanShade,
  'wall_urban_deep': _wallUrbanDeep,
  'wall_lit': _wallLit,
  'wall_lit_shade': _wallLitShade,
  'wall_sacred': _wallSacred,
  'wall_sacred_shade': _wallSacredShade,
  'wall_bare': _wallBare,
  'wall_bare_shade': _wallBareShade,
  'roof_tile_dark': _roofTileDark,
  'roof_tile': _roofTile,
  'roof_tile_light': _roofTileLight,
  'roof_tile_b_dark': _roofTileBDark,
  'roof_tile_b': _roofTileB,
  'roof_tile_b_light': _roofTileBLight,
  'roof_slab_dark': _roofSlabDark,
  'roof_slab': _roofSlab,
  'roof_slab_light': _roofSlabLight,
  'roof_fibro_dark': _roofFibroDark,
  'roof_fibro': _roofFibro,
  'roof_fibro_light': _roofFibroLight,
  'roof_tar_dark': _roofTarDark,
  'roof_tar': _roofTar,
  'roof_tar_light': _roofTarLight,
  'roof_metal_dark': _roofMetalDark,
  'roof_metal': _roofMetal,
  'roof_metal_light': _roofMetalLight,
  'roof_metal_b_dark': _roofMetalBDark,
  'roof_metal_b': _roofMetalB,
  'roof_metal_b_light': _roofMetalBLight,
  'parapet': _parapet,
  'parapet_tar': _parapetTar,
  'roof_slate_dark': _roofSlateDark,
  'roof_slate': _roofSlate,
  'roof_slate_light': _roofSlateLight,
  // Janela apagada (36): desceu junto com as paredes (0.23.1) para continuar mais escura que a parede de sombra.
  'window_off': 0xFF1F2334,
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
  // Neve e geada acumuladas no telhado, em pontilhado de 70% por cima da telha: branco azulado, nunca puro, e a
  // sombra dela no lado oposto ao sol e junto da borda.
  'snow': 0xFFE4E8F0,
  'snow_shade': 0xFFB4BCD0,
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

/// Chão por bioma (`biomes.json`; `empty` e `void` são o Vazio), por uso do solo (`paved`, `parking`, `vacant`,
/// `lot_res`, `commercial`) e por superfície (`sidewalk`, `road`, `yard`, `lot`).
///
/// 0.23.1: o chão de bioma do que é cidade ou Vazio (`urban`, `lit`, `residential`, `sacred`, `empty`, `void`) é
/// neutro: só o tom e um pontilhado leve, sem módulo e sem carimbo. É o que se pinta onde não há informação de uso do
/// solo. Ladrilho só em `paved`.
const Map<String, GroundRecipe> groundRecipes = {
  'empty': _emptyGround,
  'void': _emptyGround,
  'urban': GroundRecipe(base: _concrete, dark: _concreteDark, light: _concreteLight, ditherPct: 5, stamps: [], stampsPer100Px: 0),
  'green': GroundRecipe(base: _grass, dark: _grassDark, light: _grassLight, ditherPct: 18, stamps: ['tuft', 'tuft', 'tuft', 'tuft_b', 'tuft_b', 'flower_a', 'flower_b', 'flower_c', 'bush'], stampsPer100Px: 60),
  'water': GroundRecipe(base: _water, dark: _waterDark, light: _waterLight, ditherPct: 10, stamps: ['ripple'], stampsPer100Px: 20),
  'residential': GroundRecipe(base: _res, dark: _resDark, light: _resLight, ditherPct: 6, stamps: [], stampsPer100Px: 0),
  // O Iluminado sem informação: cimento claro liso (148), não mais o piso branco ladrilhado (194).
  'lit': GroundRecipe(base: _cement, dark: _cementDark, light: _cementLight, ditherPct: 4, stamps: [], stampsPer100Px: 0),
  'sacred': GroundRecipe(base: _sacred, dark: _sacredDark, light: _sacredLight, ditherPct: 6, stamps: [], stampsPer100Px: 0),
  // Área de pedestre e praça calçada do OSM: o único chão ladrilhado (módulo `floor_lit`), o mais claro da cidade.
  'paved': GroundRecipe(base: _lit, dark: _litDark, light: _litLight, ditherPct: 4, stamps: [], stampsPer100Px: 0),
  // Estacionamento: asfalto com as vagas pintadas (módulo `parking_bay`) e uma ou outra mancha de óleo.
  'parking': GroundRecipe(base: _asphalt, dark: _asphaltDark, light: _asphaltLight, ditherPct: 8, stamps: ['oil'], stampsPer100Px: 2),
  // Terreno baldio: a terra e o mato de `lot`.
  'vacant': _lotGround,
  // Lote residencial: terra batida clara de quintal, com tufo de grama; sem flor nem arbusto (isso é `yard`).
  'lot_res': GroundRecipe(base: _dirtLight, dark: _dirt, light: _res, ditherPct: 12, stamps: ['tuft_b', 'tuft_b', 'tuft', 'pebble'], stampsPer100Px: 18),
  // Área comercial: concreto claro liso, sem módulo e sem carimbo.
  'commercial': GroundRecipe(base: _cement, dark: _cementDark, light: _cementLight, ditherPct: 3, stamps: [], stampsPer100Px: 0),
  // Calçada comum: concreto liso com junta discreta (módulo `sidewalk_tile`).
  'sidewalk': GroundRecipe(base: _sidewalk, dark: _sidewalkDark, light: _sidewalkLight, ditherPct: 3, stamps: ['crack'], stampsPer100Px: 2),
  // A calçada portuguesa, só no Centro: o pontilhado são pedras soltas ou trocadas, nos tons da calçada.
  'sidewalk_mosaic': GroundRecipe(base: _mosaicLight, dark: _sidewalkDark, light: _sidewalkLight, ditherPct: 3, stamps: ['crack'], stampsPer100Px: 2),
  'road': GroundRecipe(base: _asphalt, dark: _asphaltDark, light: _asphaltLight, ditherPct: 10, stamps: ['crack', 'oil', 'patch'], stampsPer100Px: 6),
  'yard': GroundRecipe(base: _yard, dark: _yardDark, light: _yardLight, ditherPct: 14, stamps: ['tuft', 'tuft_b', 'flower_c', 'bush'], stampsPer100Px: 35),
  'lot': _lotGround,
};

const GroundRecipe _emptyGround = GroundRecipe(base: _dirt, dark: _dirtDark, light: _dirtLight, ditherPct: 10, stamps: [], stampsPer100Px: 0);
const GroundRecipe _lotGround = GroundRecipe(base: _dirt, dark: _dirtDark, light: _dirtLight, ditherPct: 16, stamps: ['weed', 'weed', 'tuft', 'pebble'], stampsPer100Px: 45);

/// Os chãos que levam um módulo repetido por baixo dos carimbos (paginação de piso). Nenhum chão de bioma está aqui.
const Map<String, String> groundPatterns = {'sidewalk': 'sidewalk_tile', 'sidewalk_mosaic': 'sidewalk_mosaic', 'paved': 'floor_lit', 'parking': 'parking_bay'};

/// A altura de um andar em pixels de arte: uma fileira de janelas (módulo de 4 x 4) por andar visível da fachada.
const int floorPx = 4;

/// Os carimbos de detalhe fino, que saem no zoom aberto: flores, tufos, pedrinhas, rachaduras e props de telhado.
const Set<String> fineStamps = {'tuft', 'tuft_b', 'flower_a', 'flower_b', 'flower_c', 'pebble', 'crack', 'roof_tank', 'roof_ac', 'roof_antenna'};

// A sombra da árvore não é carimbo (0.23.0): o renderizador desenha a silhueta do próprio carimbo da copa, achatada a
// 70% da altura, na cor `shadow`. Assim a sombra tem sempre a forma da copa, seja a de código ou a do Aseprite.

/// O carimbo do ipê de [kind] (`purple` ou `yellow`) no mês local [month] (1 a 12). Em Campinas o ipê-roxo floresce em
/// junho e julho e o ipê-amarelo em agosto e setembro, um depois do outro; fora da floração é `ipe_green`. Ipê só em
/// praça e parque.
String ipeStamp(String kind, int month) => switch (kind) {
      'purple' when month == 6 || month == 7 => 'ipe_purple',
      'yellow' when month == 8 || month == 9 => 'ipe_yellow',
      _ => 'ipe_green',
    };

// A copa do ipê: a mesma silhueta em flor e fora dela, para a árvore não mudar de forma com a estação.
const List<String> _ipe = [
  '....OOOOO....',
  '..OOlllggOO..',
  '.OllllgggggO.',
  'OllglggglggdO',
  'OlllggggggddO',
  'OlggglggdggdO',
  'OgglggggggddO',
  'OggggdglgdddO',
  'OggdggggddddO',
  '.OggggdddddO.',
  '..OOdddddOO..',
  '....OOOOO....',
];

/// Carimbos de pixel: um caractere por pixel de arte, `.` transparente, o resto pela legenda de [mapStampLegend].
/// Os de nome `roof_*` (menos os props `roof_tank`, `roof_ac` e `roof_antenna`), `sidewalk_*`, `floor_lit`,
/// `parking_bay` e `window*` são módulos que se repetem; os outros são avulsos. Módulo de chão tem lados que dividem 64.
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
  // Copa de árvore vista de cima (a sombra é a silhueta dela, desenhada e deslocada pelo sol no renderizador).
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
  // Árvores variadas (0.22.0): a pequena amarelada (9 px), a média de copa irregular (12 px) e a grande de verde
  // fundo (16 px). A `tree` de cima continua valendo como quarta forma.
  'tree_a': [
    '..OOOOO..',
    '.OllgggO.',
    'OlllggggO',
    'OllglgggO',
    'OlgggggdO',
    'OggggdgdO',
    'OgggdgddO',
    '.OgddddO.',
    '..OOOOO..',
  ],
  'tree_b': [
    '...OOOO.....',
    '..OllggOOOO.',
    '.OlllggggggO',
    'OlllglgggggO',
    'OllgggggggdO',
    'OlggglggggdO',
    '.OgggggggddO',
    'OggggdggdddO',
    'OgggdgggdddO',
    '.OgdddddddO.',
    '..OOOOOOOO..',
  ],
  'tree_c': [
    '.....OOOOOO.....',
    '...OOllllggOO...',
    '..OlllllgggggO..',
    '.OllllglggggggO.',
    'OlllgggglgggggdO',
    'OllggggggggggddO',
    'OllgglgggggdgddO',
    'OlgggggggggggddO',
    'OgggggglggggdddO',
    'OggggggggdggdddO',
    'OgggdggggggddddO',
    '.OgggggdgdddddO.',
    '..OgdddddddddO..',
    '...OOddddddOO...',
    '.....OOOOOO.....',
  ],
  // Ipê: roxo e amarelo em flor, verde fora da floração ([ipeStamp] escolhe pelo mês).
  'ipe_purple': _ipe,
  'ipe_yellow': _ipe,
  'ipe_green': _ipe,
  // Abrigo de ônibus visto de cima: a cobertura clara com a espinha escura. Na calçada das ruas principais.
  'bus_stop': [
    'OOOOOOOOO',
    'OlllllllO',
    'OkkkkkkkO',
    'OmmmmmmmO',
    'OOOOOOOOO',
  ],
  // Banca de jornal: a caixa de metal e o toldo listrado na linha de baixo. Na calçada do Centro e nas praças.
  'newsstand': [
    'OOOOOOO',
    'OgghggO',
    'OgggggO',
    'OkkkkkO',
    'OakakaO',
    'OOOOOOO',
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
  // A cerâmica mais clara: telha menor, com o ressalto a cada 3 px.
  'roof_tile_b': [
    'ltd',
    'ltd',
    'ddd',
  ],
  // Fibrocimento: a onda a cada 3 px, em tom próximo (quase não lista), e a emenda das chapas a cada 6 px.
  'roof_fibro': [
    'ffdffd',
    'ffdffd',
    'ffdffd',
    'ffdffd',
    'ffdffd',
    'lldlld',
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
  // Ar-condicionado (a caixa clara com a hélice escura) e antena de TV: props avulsos, como a caixa d'água. Quais
  // telhados levam qual está em `WallStyle.roofProps`.
  'roof_ac': [
    'llll',
    'lkkl',
    'dddd',
  ],
  'roof_antenna': [
    'k.k',
    '.k.',
    'kkk',
    '.k.',
    'kkk',
  ],
  // Manta escura: lisa, com a emenda das faixas a cada 8 px (só na horizontal, nunca em grade). O ar-condicionado
  // agora é prop avulso (`roof_ac`), não faz mais parte do módulo.
  'roof_tar': [
    'tttttttt',
    'tttttttt',
    'ttttlttt',
    'tttttttt',
    'tttttttt',
    'tdtttttt',
    'tttttttt',
    'dddddddd',
  ],
  // Telha metálica de galpão: zinco novo, nervura a cada 4 px; zinco velho, trapezoidal, a cada 6 px.
  'roof_metal': [
    'mmlk',
    'mmlk',
  ],
  'roof_metal_b': [
    'mmmmlk',
    'mmmmlk',
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
  // Calçada de concreto: placas de 8 px com a junta de 1 px num tom vizinho (`sidewalk_joint`); o resto é o tom da
  // receita. Numa calçada de 2 a 3 px a junta aparece como um risco de vez em quando, não como grade.
  'sidewalk_tile': [
    '.......j',
    '.......j',
    '.......j',
    '.......j',
    '.......j',
    '.......j',
    '.......j',
    'jjjjjjjj',
  ],
  // Estacionamento: duas fileiras de vagas de 4 x 5 px, costas com costas, e o corredor de 5 px. Tinta gasta.
  'parking_bay': [
    'l...',
    'l...',
    'l...',
    'l...',
    'l...',
    'llll',
    'l...',
    'l...',
    'l...',
    'l...',
    'l...',
    '....',
    '....',
    '....',
    '....',
    '....',
  ],
  // Calçada portuguesa do Centro: a onda de basalto de 2 px sobre a pedra clara, num módulo de 8 x 6.
  'sidewalk_mosaic': [
    'lddlllll',
    'ddddllll',
    'dllddlld',
    'lllldddd',
    'lllllddl',
    'llllllll',
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
  'tree_a': {'O': 'outline', 'l': 'canopy_warm_light', 'g': 'canopy_warm', 'd': 'canopy_warm_dark'},
  'tree_b': {'O': 'outline', 'l': 'canopy_light', 'g': 'canopy', 'd': 'canopy_dark'},
  'tree_c': {'O': 'outline', 'l': 'canopy_deep_light', 'g': 'canopy_deep', 'd': 'canopy_deep_dark'},
  'ipe_purple': {'O': 'outline', 'l': 'ipe_purple_light', 'g': 'ipe_purple', 'd': 'ipe_purple_dark'},
  'ipe_yellow': {'O': 'outline', 'l': 'ipe_yellow_light', 'g': 'ipe_yellow', 'd': 'ipe_yellow_dark'},
  'ipe_green': {'O': 'outline', 'l': 'canopy_warm_light', 'g': 'canopy_warm', 'd': 'canopy_warm_dark'},
  'bus_stop': {'O': 'outline', 'l': 'roof_metal_light', 'k': 'roof_metal_dark', 'm': 'roof_metal'},
  'newsstand': {'O': 'outline', 'g': 'gate', 'h': 'pole_head', 'k': 'gate_dark', 'a': 'lane'},
  'bush': {'O': 'outline', 'l': 'canopy_light', 'g': 'canopy', 'd': 'canopy_dark'},
  'lamp': {'h': 'pole_head', 'g': 'lamp_glow', 'p': 'pole'},
  'sign_bar': {'O': 'outline', 'k': 'sign_dark', 'a': 'neon_a'},
  'sign_blade': {'O': 'outline', 'k': 'sign_dark', 'c': 'neon_c'},
  'neon_ring': {'b': 'neon_b'},
  'neon_arrow': {'a': 'neon_a'},
  'roof_tile': {'l': 'roof_tile_light', 't': 'roof_tile', 'd': 'roof_tile_dark'},
  'roof_slab': {'s': 'roof_slab', 'l': 'roof_slab_light', 'd': 'roof_slab_dark'},
  'roof_tank': {'O': 'outline', 'l': 'roof_slate_light', 'b': 'roof_slate', 'd': 'roof_slate_dark'},
  'roof_tile_b': {'l': 'roof_tile_b_light', 't': 'roof_tile_b', 'd': 'roof_tile_b_dark'},
  'roof_fibro': {'f': 'roof_fibro', 'l': 'roof_fibro_light', 'd': 'roof_fibro_dark'},
  'roof_ac': {'l': 'pole_head', 'k': 'pole', 'd': 'roof_metal_dark'},
  'roof_antenna': {'k': 'pole'},
  'roof_tar': {'t': 'roof_tar', 'd': 'roof_tar_dark', 'l': 'roof_tar_light'},
  'roof_metal': {'m': 'roof_metal', 'l': 'roof_metal_light', 'k': 'roof_metal_dark'},
  'roof_metal_b': {'m': 'roof_metal_b', 'l': 'roof_metal_b_light', 'k': 'roof_metal_b_dark'},
  'sidewalk_mosaic': {'l': 'mosaic_light', 'd': 'mosaic_dark'},
  'roof_slate': {'s': 'roof_slate', 'l': 'roof_slate_light', 'd': 'roof_slate_dark'},
  'sidewalk_tile': {'j': 'sidewalk_joint'},
  'parking_bay': {'l': 'lane_worn'},
  'floor_lit': {'l': 'lit_light', 'f': 'lit', 'd': 'lit_dark'},
  'window_off': {'o': 'window_off'},
  'window_on': {'n': 'window_on'},
  'window_shop_off': {'o': 'window_off'},
  'window_shop_on': {'n': 'window_on_cool'},
  'cloud': {'c': 'cloud', 's': 'cloud_shade'},
};

/// Parede e telhado de um prédio.
class WallStyle {
  const WallStyle({required this.wall, required this.wallShade, required this.roof, required this.roofEdge, required this.roofPattern, required this.window, this.parapet = 0, this.roofProps = const []});

  /// Parede no lado da luz e no lado da sombra, telhado (o tom base do módulo) e a borda de 1 px do telhado.
  final int wall, wallShade, roof, roofEdge;

  /// O módulo de [mapStamps] que cobre o telhado.
  final String roofPattern;

  /// O prefixo do módulo de janela: o renderizador usa `<window>_on` ou `<window>_off`. Vazio: parede cega.
  final String window;

  /// A cor da platibanda, a mureta de 1 px por dentro da borda do telhado. 0: sem platibanda (laje e manta têm; telha,
  /// fibrocimento, metal e ardósia não).
  final int parapet;

  /// Os carimbos avulsos que podem cair neste telhado (nome repetido pesa mais). Vazio: telhado sem prop.
  final List<String> roofProps;
}

const List<String> _slabProps = ['roof_tank', 'roof_tank', 'roof_ac', 'roof_antenna'];
const List<String> _tarProps = ['roof_ac', 'roof_ac', 'roof_antenna'];
const List<String> _fibroProps = ['roof_antenna'];

// Casa: cerâmica (a regra), a cerâmica clara, fibrocimento e a casa de laje.
const WallStyle _houseStyle = WallStyle(wall: _wallRes, wallShade: _wallResShade, roof: _roofTile, roofEdge: _roofTileDark, roofPattern: 'roof_tile', window: 'window');
const WallStyle _houseTileB = WallStyle(wall: _wallRes, wallShade: _wallResShade, roof: _roofTileB, roofEdge: _roofTileBDark, roofPattern: 'roof_tile_b', window: 'window');
const WallStyle _houseFibro = WallStyle(wall: _wallRes, wallShade: _wallResShade, roof: _roofFibro, roofEdge: _roofFibroDark, roofPattern: 'roof_fibro', window: 'window', roofProps: _fibroProps);
const WallStyle _houseSlab = WallStyle(wall: _wallRes, wallShade: _wallResShade, roof: _roofSlab, roofEdge: _roofSlabDark, roofPattern: 'roof_slab', window: 'window', parapet: _parapet, roofProps: _slabProps);
// Bloco do Centro: laje (a regra), fibrocimento e manta. O prédio de manta desce um degrau na escada do cinza, para a
// parede continuar abaixo do telhado.
const WallStyle _blockStyle = WallStyle(wall: _wallUrban, wallShade: _wallUrbanShade, roof: _roofSlab, roofEdge: _roofSlabDark, roofPattern: 'roof_slab', window: 'window', parapet: _parapet, roofProps: _slabProps);
const WallStyle _blockFibro = WallStyle(wall: _wallUrban, wallShade: _wallUrbanShade, roof: _roofFibro, roofEdge: _roofFibroDark, roofPattern: 'roof_fibro', window: 'window', roofProps: _fibroProps);
const WallStyle _blockTar = WallStyle(wall: _wallUrbanShade, wallShade: _wallUrbanDeep, roof: _roofTar, roofEdge: _roofTarDark, roofPattern: 'roof_tar', window: 'window', parapet: _parapetTar, roofProps: _tarProps);
// Comércio fora do Iluminado: os mesmos três, com vitrine.
const WallStyle _shopStyle = WallStyle(wall: _wallUrban, wallShade: _wallUrbanShade, roof: _roofSlab, roofEdge: _roofSlabDark, roofPattern: 'roof_slab', window: 'window_shop', parapet: _parapet, roofProps: _slabProps);
const WallStyle _shopFibro = WallStyle(wall: _wallUrban, wallShade: _wallUrbanShade, roof: _roofFibro, roofEdge: _roofFibroDark, roofPattern: 'roof_fibro', window: 'window_shop', roofProps: _fibroProps);
const WallStyle _shopTar = WallStyle(wall: _wallUrbanShade, wallShade: _wallUrbanDeep, roof: _roofTar, roofEdge: _roofTarDark, roofPattern: 'roof_tar', window: 'window_shop', parapet: _parapetTar, roofProps: _tarProps);
// Comércio do Iluminado: manta escura (a regra) e a loja de laje, de parede mais clara.
const WallStyle _shopLitStyle = _shopTar;
const WallStyle _shopLitSlab = WallStyle(wall: _wallLit, wallShade: _wallLitShade, roof: _roofSlab, roofEdge: _roofSlabDark, roofPattern: 'roof_slab', window: 'window_shop', parapet: _parapet, roofProps: _slabProps);
// Galpão, parede cega: o zinco novo (a regra do estilo simplificado), o zinco velho, fibrocimento e laje.
const WallStyle _shedStyle = WallStyle(wall: _wallUrban, wallShade: _wallUrbanShade, roof: _roofMetal, roofEdge: _roofMetalDark, roofPattern: 'roof_metal', window: '');
const WallStyle _shedMetalB = WallStyle(wall: _wallUrban, wallShade: _wallUrbanShade, roof: _roofMetalB, roofEdge: _roofMetalBDark, roofPattern: 'roof_metal_b', window: '');
const WallStyle _shedFibro = WallStyle(wall: _wallUrban, wallShade: _wallUrbanShade, roof: _roofFibro, roofEdge: _roofFibroDark, roofPattern: 'roof_fibro', window: '');
const WallStyle _shedSlab = WallStyle(wall: _wallUrban, wallShade: _wallUrbanShade, roof: _roofSlab, roofEdge: _roofSlabDark, roofPattern: 'roof_slab', window: '', parapet: _parapet, roofProps: _slabProps);
const WallStyle _sacredStyle = WallStyle(wall: _wallSacred, wallShade: _wallSacredShade, roof: _roofSlate, roofEdge: _roofSlateDark, roofPattern: 'roof_slate', window: 'window');
// Vazio, tijolo sem reboco: fibrocimento (a regra), laje crua e zinco velho.
const WallStyle _bareStyle = WallStyle(wall: _wallBare, wallShade: _wallBareShade, roof: _roofFibro, roofEdge: _roofFibroDark, roofPattern: 'roof_fibro', window: 'window', roofProps: _fibroProps);
const WallStyle _bareSlab = WallStyle(wall: _wallBare, wallShade: _wallBareShade, roof: _roofSlab, roofEdge: _roofSlabDark, roofPattern: 'roof_slab', window: 'window', parapet: _parapet, roofProps: _slabProps);
const WallStyle _bareMetalB = WallStyle(wall: _wallBare, wallShade: _wallBareShade, roof: _roofMetalB, roofEdge: _roofMetalBDark, roofPattern: 'roof_metal_b', window: 'window');

/// As variantes de telhado de cada estilo; a primeira é a de [wallStyleFor]. Estilo repetido pesa mais no sorteio.
/// O metal só aparece em galpão (2 em 6) e no Vazio (1 em 4): não domina mais o quarteirão.
const Map<String, List<WallStyle>> _roofVariants = {
  'sacred': [_sacredStyle],
  'house': [_houseStyle, _houseStyle, _houseStyle, _houseTileB, _houseTileB, _houseFibro, _houseSlab],
  'shop_lit': [_shopLitStyle, _shopLitStyle, _shopLitSlab],
  'shop': [_shopStyle, _shopStyle, _shopFibro, _shopTar],
  'block': [_blockStyle, _blockStyle, _blockStyle, _blockFibro, _blockTar],
  'shed': [_shedStyle, _shedFibro, _shedFibro, _shedSlab, _shedMetalB, _shedSlab],
  'bare': [_bareStyle, _bareStyle, _bareSlab, _bareMetalB],
};

const Set<String> _sacredTypes = {'church', 'chapel', 'cathedral', 'temple', 'mosque', 'synagogue', 'shrine', 'religious'};
const Set<String> _houseTypes = {'house', 'residential', 'detached', 'semidetached_house', 'terrace', 'bungalow', 'hut', 'cabin'};
const Set<String> _blockTypes = {'apartments', 'dormitory', 'hotel', 'office', 'school', 'university', 'hospital', 'public', 'civic'};
const Set<String> _shopTypes = {'commercial', 'retail', 'supermarket', 'kiosk'};
const Set<String> _shedTypes = {'industrial', 'warehouse', 'hangar', 'shed', 'garage', 'garages', 'roof'};

/// O estilo de um prédio pelo `building=*` do OSM e pelo bioma onde ele está. O tipo manda; `yes` e o que não se
/// conhece seguem o bioma, que é o que dá cara ao bairro.
WallStyle wallStyleFor(String buildingType, String biome) => roofVariantsFor(buildingType, biome).first;

/// As variantes de parede e telhado de um prédio, com a mesma regra de [wallStyleFor] (que devolve a primeira). O
/// renderizador escolhe `variantes[hash do prédio % length]`; a lista nunca é vazia.
List<WallStyle> roofVariantsFor(String buildingType, String biome) => _roofVariants[_styleKind(buildingType, biome)]!;

String _styleKind(String buildingType, String biome) {
  if (_sacredTypes.contains(buildingType)) return 'sacred';
  if (_houseTypes.contains(buildingType)) return 'house';
  if (_shopTypes.contains(buildingType)) return biome == 'lit' ? 'shop_lit' : 'shop';
  if (_blockTypes.contains(buildingType)) return 'block';
  if (_shedTypes.contains(buildingType)) return 'shed';
  return switch (biome) {
    'sacred' => 'sacred',
    'residential' || 'green' || 'water' => 'house',
    'lit' => 'shop_lit',
    'urban' => 'block',
    _ => 'bare', // Vazio: tijolo sem reboco e fibrocimento
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

/// A luz partida em quente e fria, nas mesmas altitudes de [_altKeys]. De noite e no crepúsculo as duas são o tom de
/// [sceneLight]; com o sol no horizonte e na hora dourada o contraste é máximo; ao meio-dia as duas somem.
const List<int> _warmTone = [0xFF141033, 0xFF2A1F55, 0xFFF2907A, 0xFFFFC27A, 0xFFFFE2B0, 0xFFFFFFFF];
const List<double> _warmAlpha = [0.58, 0.46, 0.30, 0.24, 0.08, 0.0];
const List<int> _coolTone = [0xFF141033, 0xFF2A1F55, 0xFF3A3F8A, 0xFF4A5AA0, 0xFF6A7AB0, 0xFFFFFFFF];
const List<double> _coolAlpha = [0.58, 0.46, 0.44, 0.30, 0.10, 0.0];

/// A luz da hora em duas: [warm] por cima de chão, telhado e parede no sol, e [cool] dentro das sombras projetadas e
/// nas paredes de sombra. Como em [sceneLight], pinta-se ANTES das luzes acesas. Nunca pinte as duas no mesmo pixel.
({int warm, double warmAlpha, int cool, double coolAlpha}) sceneLightSplit(double sunAltDeg) {
  final (i, k) = _segment(sunAltDeg);
  return (
    warm: mixArgb(_warmTone[i], _warmTone[i + 1], k),
    warmAlpha: _warmAlpha[i] + (_warmAlpha[i + 1] - _warmAlpha[i]) * k,
    cool: mixArgb(_coolTone[i], _coolTone[i + 1], k),
    coolAlpha: _coolAlpha[i] + (_coolAlpha[i + 1] - _coolAlpha[i]) * k,
  );
}

/// A cor da névoa de distância que dissolve o topo do mapa no céu: a última cor de [skyGradient] debaixo da mesma luz
/// da cena. De dia é quase a cor do horizonte; de noite escurece junto com o mapa, em vez de virar uma faixa clara.
int horizonFog(double sunAltDeg) {
  final light = sceneLight(sunAltDeg);
  return mixArgb(skyGradient(sunAltDeg).last, light.argb, light.alpha);
}

/// Postes, janelas e neon acesos: do sol 1 grau abaixo do horizonte até ele voltar a essa altura.
bool lightsOn(double sunAltDeg) => sunAltDeg < -1;

/// As 4 cores da faixa do horizonte, de cima para baixo, para a altitude do sol em graus.
List<int> skyGradient(double sunAltDeg) {
  final (i, k) = _segment(sunAltDeg);
  return [for (var c = 0; c < 4; c++) mixArgb(_sky[i][c], _sky[i + 1][c], k)];
}
