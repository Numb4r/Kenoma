/// O Familiar (placeholder): um fiapo violeta com olhos ciano, 18 × 18 pixels redesenhado em 16 × 16 para o mapa (6 m com o pixel de
/// arte de 3 dp). Arte nunca bloqueia código: a forma de verdade vem com a escola do Conjurador.
library;

import 'dart:ui' as ui;

import '../../player/conjurer_balance.dart';
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

/// A imagem do Familiar para o mapa.
/// [school] ainda é ignorado: a forma por escola vem com a arte.
Future<ui.Image> loadFamiliarImage({School? school}) => spriteToImage(downscaleRows(familiarSprite, mapPlayerPx, keep: 'C'), palette: familiarPalette);
