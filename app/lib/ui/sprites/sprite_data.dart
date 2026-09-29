/// Sprites dos Ecos como matrizes de caracteres, 48 x 48. Um caractere por pixel.
///
/// Para redesenhar, edite os caracteres. `.` é transparente e o resto vem de [spritePalette].
/// Regras de arte: contorno `O` (#1a1424, nunca preto puro), costuras violeta `v`, brilho externo `u`
/// e no máximo 24 cores no total.
library;

/// Cor de cada caractere em ARGB. O caractere `.` fica de fora: é transparente.
const Map<String, int> spritePalette = {
  'O': 0xFF1A1424, // contorno
  'a': 0xFF3D4254, // fuligem escura
  'b': 0xFF5A6072, // fuligem
  'c': 0xFF8A8FA3, // fuligem clara
  'q': 0xFFC9502A, // brasa escura
  'o': 0xFFFF7A45, // brasa
  'p': 0xFFFFB37A, // brasa clara
  'd': 0xFF2F6B45, // folha escura
  'e': 0xFF4C9A5A, // folha
  'f': 0xFF86D37C, // folha clara
  'r': 0xFF5A4636, // raiz
  's': 0xFF8A6A4A, // raiz clara
  'h': 0xFF2D5AA0, // água escura
  'i': 0xFF4A86D6, // água
  'j': 0xFF9FD0F5, // água clara
  'k': 0xFF1F2A5C, // céu refletido, noite
  'y': 0xFFF2C48D, // céu refletido, entardecer claro
  'z': 0xFFD98A6C, // céu refletido, entardecer
  'v': 0xFF9B7BFF, // costura violeta (o Véu)
  'u': 0xFF6A4FD0, // brilho externo
  'x': 0xFFF0EEF8, // olho
  'n': 0xFF3A3450, // silhueta neutra
  'm': 0xFF56507A, // silhueta neutra clara
  'w': 0xFF2B2540, // silhueta neutra escura
};

/// Sootling (soot.eco).
const List<String> sootlingSprite = [
  '................................................',
  '................................................',
  '................................................',
  '................................................',
  '................................................',
  '................................................',
  '................................................',
  '................................................',
  '................................................',
  '.......................u.u......................',
  '......................uOOOu.....................',
  '.....................uOcccOu....................',
  '................u.u.uOccaccOu.u.u...............',
  '...............uOOOuOccccbbbOuOOOu..............',
  '..............uOcccOccccbbbbbOcccOu.............',
  '.............uOccacccccbabbbbbcaccOu............',
  '............uOccccbbbcbbbbbbbbbcaaaOu...........',
  '.............OcccbbbbbbbbbbbbbaavaaO............',
  '............uOccbbbbbObbbbbObbbavaaOu...........',
  '.............uOcbbbbbbbbbbbbbbbbvaOu............',
  '..............uObbbbbbbcbbbbbcbbbOu.............',
  '.............uOccbbbbbbbbbbbbbbbbvOu............',
  '............uOvcccbbbbbbbbbbbbbbvbbOu...........',
  '...........uOccvcbxxxxxbbbbxxxxxvbbaOu..........',
  '..........uOccccvbxxxxxbbbbxxxxxvbbabOu.........',
  '.........uOccccbvxxxxxxxbbxxxxxxxbbbbbOu........',
  '......u.uOOcccbbbxxxOOxxbbxxOOxxxbbbbbOOu.u.....',
  '.....u.OOcOccbbbvxxxOOxxbbxxOOxxxvbbbbObOO.u....',
  '......OccccccbbbvbxxxxxbbbbxxxxxbbvbbbbbccO.....',
  '.....uOccccbcbbbvbxxxxxbbbbxxxxxbbbvbbbbcaOu....',
  '....uOcccbbbbbbvbbbbbbbqqqbbbbbbbbbbbbbaaaaOu...',
  '.....OcccbbbbbbbvbbbbqqqoqqqbbbbbbbbbbbaaaaO....',
  '....uOccaabbbbbbvbbbqqoooooqqbbbbaaabaaaaaaOu...',
  '.....uOcaaabbbbbbvbbqoopppooqbbbaaaaaaaaaaOu....',
  '......OcaaaabbbbbbvbqoopppooqbbaaaaaaaaaaaO.....',
  '.....u.OOaOOObbbbbbbqoopppooqbaaaaaaOOOaOO.u....',
  '......u.uOu.uOaabbbbqqoooooqqaaaaaaOu.uOu.u.....',
  '.........u...uObbbaaaqqqoqqqbbaaaaOu...u........',
  '..............uObbbaaaaqqqbbbbbaaOu.............',
  '...............uOOObaaabbvbbbbOOOu..............',
  '..............uOccbaaOOObOOObbbaaOu.............',
  '.............uOccccccaOuOuObbbaaccOu............',
  '............uOccccaaaaaOuOacccaaaaaOu...........',
  '.............uOccaaaaaOu.uOccaaaaaOu............',
  '..............uOaaaaaOu...uOaaaaaOu.............',
  '...............uOOOOOu.....uOOOOOu..............',
  '................u.u.u.......u.u.u...............',
  '................................................',
];

/// Frondling (frond.eco).
const List<String> frondlingSprite = [
  '.......................u.u......................',
  '......................u.O.u.....................',
  '.....................u.OeO.u....................',
  '....................uOOeeeOOu...................',
  '...................uOffedeeeOu..................',
  '..................uOeddededddOu.................',
  '.................uOeeeedddeeddOu................',
  '................uOfffffedeeeddvOu...............',
  '...............uOffdfffedeeeddvdOu..............',
  '..............u.OveedeeedeeedvddO.u.............',
  '.............u.OeeveeddededddvdddO.u............',
  '..............OfffvffffdddeevdddddO.............',
  '.............uOffffvfffedeeevdddddOu............',
  '..........u.uOeeeeeveeeedeeedvdddddOu.u.........',
  '.........u.O.OeeeeeeveeedeeedvdddddO.O.u........',
  '........u.OeOOffffffvddededdddvddddOOeO.u.......',
  '.......u.OedeOfffffvfffdddeeddvddddOedeO.u......',
  '......u.OeedeeeeeeveeeeedeeedddvdddeedeeO.u.....',
  '.......OedededeeeevdeeeedeeedddvddddededeO......',
  '......uOeedddefffffvdffedeeeddvddddedddeeOu.....',
  '.....uOeevedeefffffvfddededdddvddddeedeeeeOu....',
  '......OedevdeedeeeeeveedddeedvdddddeedeedeO.....',
  '.....uOeedvdedeeeeeeveeedeeedvddddddededeeOu....',
  '....uOeeeevddeeffffdfvfedeeeddddddeedddeeeeOu...',
  '.....uOeeeeveeefffffdffedeeeddddddeeedeeeeOu....',
  '......OedeeveedeeeeeeddededddddddedeedeedeO.....',
  '.....uOeedvdedeeOeeeeeedddeeddddOeedededeeOu....',
  '......uOeevddeeOOffffffedeeeddddOOeedddeeOu.....',
  '.......OeevdeeeO.OfffffedeeedddO.OeeedeeeO......',
  '......u.OeedeeO.u.OeeeeedeeeddO.u.OeedeeO.u.....',
  '.......u.OedeO.u.u.OeeeedeeedO.u.u.OedeO.u......',
  '........u.OdO.u...u.OffedeeeO.u...u.OdO.u.......',
  '.........u.O.u...uOOeeeedeeeeOOu...u.O.u........',
  '..........u.u...uOeeeeeedeeeeeeOu...u.u.........',
  '...............uOeeeeeeeeeeeeeeeOu..............',
  '..............uOeeexxxeeeeexxxeeeOu.............',
  '.............u.OeexxxxxeeexxxxxeeO.u............',
  '..............OeeexxOOxeeexOOxxeeeO.............',
  '.............u.OeexxOOxeeexOOxxeeO.u............',
  '............u.OOeeexxxeeeeexxxeeeOO.u...........',
  '...........uOOrrreeeeeeeeeeeeeeerrrOOu..........',
  '..........uOrrsrrreeeeeeeeeeeeersrrrrOu.........',
  '...........OrrrrrrrOeeeeeeeeeOrrrrrrrO..........',
  '..........uOrrrrrrrOOrrrerrrOOrrrrrrrOu.........',
  '...........uOOrrrOOu.OrrrrrO.uOOrrrOOu..........',
  '............u.OOO.u.u.OOrOO.u.u.OOO.u...........',
  '.............u.u.u...u.uOu.u...u.u.u............',
  '................................................',
];

/// Rillet (rill.eco).
const List<String> rilletSprite = [
  '................................................',
  '................................................',
  '................................................',
  '.......................u.u......................',
  '......................u.O.u.....................',
  '.......................OjO......................',
  '......................uOjOu.....................',
  '.......................OjO......................',
  '......................uOjOu.....................',
  '.....................u.OjO.u....................',
  '......................OjjjO.....................',
  '.....................uOjjjOu....................',
  '....................uOjjjhhOu...................',
  '...................u.OjjjihO.u..................',
  '....................OjjjiihhO...................',
  '...................uOjjjiiihOu..................',
  '..................uOjjjiiiiihOu.................',
  '.................u.OjjjiiiiihO.u................',
  '................u.OjjjiiiiiiihO.u...............',
  '.................OvjjjiiiiiiiihO................',
  '................uOjjjiiiiiiiiiiOu...............',
  '...............uOxxxiiiiiiiiixxxOu..............',
  '..............uOxxxxxiiiiiiixxxxxOu.............',
  '.............uOxxxxxxxiiiiixxxxxxxOu............',
  '............u.OxxxxxxxiiiiixxxxxxxO.u...........',
  '...........u.OjxxxOOxxiiiiixxOOxxxiO.u..........',
  '..........u.OjjxxxOOxxiiiiixxOOxxxiiO.u.........',
  '.........u.OjjjxxxxxxxiiiiixxxxxxxihhO.u........',
  '........u.OjjjjixxxxxiiiiiiixxxxxiihhhO.u.......',
  '.........OjjjjiiixxxiiiiiiiiixxxiiihhhhO........',
  '........u.OjjiiiiiiiiiiiiiiiiikkkiihhhO.u.......',
  '.........uOjiiiiiiiiiiiiiiiikkkxkkzhhhOu........',
  '..........OjjiiiiiiiiiiiiikkxkkkkzzzhhO.........',
  '.........uOjjiiiiiiiiiiiiikkkkkkzzzyhhOu........',
  '..........OjjiiiiiiiiiiiikkkkkkzzzyyhhO.........',
  '.........u.OjiiiiiiiiiiiikkkkkzzzyyhhO.u........',
  '..........uOjiiiiiiiiiiiikkkkzzzyyyhhOu.........',
  '...........uOjiiiiiiiiiiiikkzzzyyyhhOu..........',
  '............uOiiiiiiiiiiiivzzzyyyhhOu...........',
  '.............uOhiiiiiiiiivihzyyyhhOu............',
  '..............uOhhhhhhhhvhhhhhhhhOu.............',
  '...............uOhhhhhhhhhhhhhhhOu..............',
  '................uOOhhhhhhhhhhhOOu...............',
  '.................u.OOOOOOOOOOO.u................',
  '..................u.u.u.u.u.u.u.................',
  '................................................',
  '................................................',
  '................................................',
];

/// Silhueta neutra do modo de tipo oculto: não mostra nada do tipo.
const List<String> neutralSprite = [
  '................................................',
  '................................................',
  '................................................',
  '................................................',
  '................................................',
  '................................................',
  '................................................',
  '................................................',
  '................................................',
  '.......................u.u......................',
  '....................u.u.O.u.u...................',
  '.................u.uOOOOmOOOOu.u................',
  '................u.OOmmmmmmmmmOO.u...............',
  '...............u.OmmmmmmmmnmmmmO.u..............',
  '..............u.OmmmmmnnnnnnnnnmO.u.............',
  '...............OmmmmnnnnnnnnnnnwwO..............',
  '..............uOmmmnnnnnnnnnnnnnwOu.............',
  '.............uOmmmnnnnnnnnnnnnnnnvOu............',
  '............u.OmmmnnnnxxxxxnnnnnnvO.u...........',
  '...........u.OmmmnnnnxxnnnxxnnnnnvwO.u..........',
  '..........u.OmmmmnnnxxnnnnnxxnnnvnnwO.u.........',
  '...........OmmvmnnnnnnnnnnnxxnnnvnnwwO..........',
  '..........uOmmmvnnnnnnnnnnxxnnnnvnnwwOu.........',
  '.........uOmmmnnvnnnnnnnnxxnnnnnnvnwwwOu........',
  '..........OmmmnnvnnnnnnnxxnnnnnnnnvnwwO.........',
  '.........uOmmnnnnvnnnnnnxxnnnnnnnnvwwwOu........',
  '........u.OmmnnnvnnnnnnnnnnnnnnnnnnvwwO.u.......',
  '.........OmmmnnnvnnnnnnnxxnnnnnnnnnwwwwO........',
  '........u.OmmnnnvnnnnnnnxxnnnnnnnnnwwwO.u.......',
  '.........uOmnnnvnnnnnnnnnnnnnnnnnnwwwwOu........',
  '..........OmmnnnvnnnnnnnnnnnnnnnnnwwwwO.........',
  '.........uOmmnnnvnnnnnnnnnnnnnnnnwwwwwOu........',
  '..........uOmnnnnvnnnnnnnnnnnnnnwwwwwOu.........',
  '...........OmnnnnnvnnnnnnnnnnnnwwwwwwO..........',
  '..........u.OmnnnnnnnnnnnnnnnwwwwwwwO.u.........',
  '...........u.OwwnnnnnnnnnnnvwnnnnnwO.u..........',
  '............u.OnwwwwwnwwwwvnnnnnnnO.u...........',
  '.........u.uOOOOOwwwwwwwwwvnnnnnOOOOOu.u........',
  '........u.OOmmmmmOOwwwwwwvwnnnOOnnnnmOO.u.......',
  '.........OmmmmmmmmmOOOOOwOOOOOnnnnmmmmmO........',
  '........uOmmmmwwwwwOu.u.O.u.uOwwmmwwwwwOu.......',
  '.........OmmwwwwwwwO...u.u...OmmwwwwwwwO........',
  '........u.OOwwwwwOO.u.......u.OOwwwwwOO.u.......',
  '.........u.uOOOOOu.u.........u.uOOOOOu.u........',
  '............u.u.u...............u.u.u...........',
  '................................................',
  '................................................',
  '................................................',
];

/// Matriz de cada espécie, pelo id de `creatures.json`.
const Map<String, List<String>> ecoSprites = {
  'soot.eco': sootlingSprite,
  'frond.eco': frondlingSprite,
  'rill.eco': rilletSprite,
};
