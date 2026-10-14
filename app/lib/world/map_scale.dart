/// A escala do mapa de jogo em metros: a câmera é definida pela largura da tela em metros, e daí sai
/// quantos pixels cada célula z21 ocupa. Dart puro.
library;

import '../core/tiles.dart';

/// Pixels por célula z21 para que a largura da tela, [viewWidthPx], mostre [widthM] metros na latitude [lat].
double pixelsPerCellFor({required double widthM, required double viewWidthPx, required double lat}) =>
    viewWidthPx * metersPerCell(lat) / widthM;

/// Largura da tela em metros para [pixelsPerCell] pixels por célula. É a inversa de [pixelsPerCellFor].
double widthMFor({required double pixelsPerCell, required double viewWidthPx, required double lat}) =>
    viewWidthPx * metersPerCell(lat) / pixelsPerCell;
