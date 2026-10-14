/// De onde vem o rumo do celular para o "seguir direção" do mapa. Só a bússola do aparelho; o GPS não entra,
/// porque o rumo do GPS só existe em movimento.
library;

import 'package:flutter_compass/flutter_compass.dart';

abstract class HeadingSource {
  /// Rumo em graus a partir do norte magnético, no sentido horário, de 0 a 360. Cada leitura chega já
  /// filtrada pelo sensor; quem usa suaviza.
  Stream<double> get headings;
}

class CompassHeadingSource implements HeadingSource {
  const CompassHeadingSource();

  @override
  Stream<double> get headings {
    final events = FlutterCompass.events;
    if (events == null) return const Stream.empty(); // o aparelho não tem bússola
    return events.map((e) => e.heading).where((h) => h != null).cast<double>().map((h) => (h + 360) % 360);
  }
}
