/// O Familiar (placeholder): um fiapo violeta com olhos ciano, 18 × 18 pixels redesenhado em 16 × 16 para o mapa (6 m com o pixel de
/// arte de 3 dp). Arte nunca bloqueia código: a forma de verdade vem com a escola do Conjurador.
library;

import 'dart:ui' as ui;

import '../../player/conjurer_balance.dart' show School;
import 'sprite_downscale.dart';
import 'sprite_image.dart';

const Map<String, int> familiarPalette = {
  'O': 0xFF1A1424, // contorno
  'v': 0xFF9B7BFF, // o violeta do Véu
  'p': 0xFF6A52C4, // violeta na sombra
  'C': 0xFF5FD3C6, // olhos: o sinal
  'W': 0xFFE8E4F4, // brilho
};

const List<String> familiarSprite = [
  '..................',
  '.......OOOO.......',
  '.....OOvvvvOO.....',
  '....OvvWWvvvvO....',
  '...OvvvWvvvvvvO...',
  '...OvvvvvvvvvvO...',
  '...OvvCCvvCCvvO...',
  '...OvvCCvvCCvvO...',
  '...OvvvvvvvvvvO...',
  '...OpvvvvvvvvpO...',
  '....OpvvvvvvpO....',
  '....OppvvvvppO....',
  '.....OpppvpppO....',
  '.....OOpppppOO....',
  '.......OOpppO.....',
  '........OOpO......',
  '.........OO.......',
  '..................',
];

/// A paleta do Familiar na escola: o corpo (`v` e a sombra `p`) vai para a cor da escola, e `A` é o acessório. Sem escola,
/// a forma de antes (violeta com olhos ciano).
Map<String, int> familiarPaletteFor(School? school) => switch (school) {
      null => familiarPalette,
      School.sealer => {...familiarPalette, 'A': 0xFFE8E4F4}, // violeta do Véu: fio de costura claro
      School.technomancer => {...familiarPalette, 'v': 0xFF5FD3C6, 'p': 0xFF3A9A91, 'C': 0xFFE8E4F4, 'A': 0xFFE8E4F4}, // ciano do sinal: antena
      School.shaman => {...familiarPalette, 'v': 0xFFFF7A45, 'p': 0xFFC2552B, 'A': 0xFF6BD36A}, // laranja da Essência: folha
    };

/// Pixels do acessório da escola na grade reduzida do mapa (linha, coluna), desenhados por código sobre o sprite base.
const Map<School, List<(int, int)>> familiarAccessory = {
  School.technomancer: [(1, 11), (0, 11), (0, 12)], // antena
  School.shaman: [(1, 4), (0, 5), (0, 6)], // folha
  School.sealer: [(9, 6), (10, 7), (9, 8), (10, 9)], // pontos de costura em X
};

/// A grade 16 × 16 do Familiar da [school] (ou a forma atual, sem escola).
List<String> familiarRows(School? school) {
  final rows = downscaleRows(familiarSprite, mapPlayerPx, keep: 'C');
  if (school == null) return rows;
  final grid = [for (final r in rows) r.split('')];
  for (final (y, x) in familiarAccessory[school]!) {
    grid[y][x] = 'A';
  }
  return [for (final r in grid) r.join()];
}

/// A imagem do Familiar para o mapa. Sem [school], a forma atual; com ela, a paleta e o acessório da escola.
Future<ui.Image> loadFamiliarImage({School? school}) => spriteToImage(familiarRows(school), palette: familiarPaletteFor(school));
