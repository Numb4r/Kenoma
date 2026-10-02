/// A Aura no chão: o raio em metros vira pixels na escala da câmera.
library;

import '../core/tiles.dart';

/// Raio da Aura em pixels, para [auraM] metros na latitude [lat] com [pixelsPerCell] pixels por célula z21.
double auraRadiusPx({required double auraM, required double lat, required double pixelsPerCell}) =>
    auraM / metersPerCell(lat) * pixelsPerCell;
