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

/// O Familiar no mapa (0.25.0, pixel de arte de 2 dp): 24 × 24 desenhado à mão, com as letras de [familiarPalette]. O
/// mesmo fiapo, com brilho no alto da cabeça, reflexo nos olhos, boca e a cauda afinando para a direita.
const List<String> familiarMap24 = [
  '........................',
  '.........OOOOOO.........',
  '.......OOvvvvvvOO.......',
  '......OvvvvvvvvvvO......',
  '.....OvvWWvvvvvvvvO.....',
  '....OvvWWvvvvvvvvvvO....',
  '....OvvWvvvvvvvvvvvO....',
  '....OvvvvvvvvvvvvvpO....',
  '....OvvvWCvvvvWCvvpO....',
  '....OvvvCCvvvvCCvvpO....',
  '....OvvvCCvvvvCCvvpO....',
  '....OvvvvvvppvvvvppO....',
  '....OpvvvvvvvvvvvppO....',
  '.....OpvvvvvvvvvppO.....',
  '.....OppvvvvvvvpppO.....',
  '......OppvvvvvpppO......',
  '......OOpppvvppppO......',
  '........OOpppvpppO......',
  '..........OOpppppO......',
  '............OOpppO......',
  '.............OOppO......',
  '..............OOO.......',
  '........................',
  '........................',
];

/// Pixels do acessório da escola sobre [familiarMap24] (linha, coluna), no lugar de [familiarAccessory] da grade de 16.
const Map<School, List<(int, int)>> familiarAccessory24 = {
  School.technomancer: [(1, 16), (0, 16), (0, 17), (0, 18)], // antena
  School.shaman: [(1, 7), (1, 8), (0, 7), (0, 8), (0, 9)], // folha
  School.sealer: [(13, 9), (14, 10), (13, 11), (14, 12), (13, 13), (14, 14)], // pontos de costura em ziguezague
};

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

/// A grade do Familiar da [school] no mapa (ou a forma atual, sem escola): a de 24 × 24 desenhada à mão na grade de 2 dp
/// (0.25.0), ou a reduzida por código se [mapPlayerPx] não for 24.
List<String> familiarRows(School? school) {
  final hand = mapPlayerPx == 24;
  final rows = hand ? familiarMap24 : downscaleRows(familiarSprite, mapPlayerPx, keep: 'C');
  if (school == null) return rows;
  final grid = [for (final r in rows) r.split('')];
  for (final (y, x) in (hand ? familiarAccessory24 : familiarAccessory)[school]!) {
    grid[y][x] = 'A';
  }
  return [for (final r in grid) r.join()];
}

/// A imagem do Familiar para o mapa. Sem [school], a forma atual; com ela, a paleta e o acessório da escola.
Future<ui.Image> loadFamiliarImage({School? school}) => spriteToImage(familiarRows(school), palette: familiarPaletteFor(school));
