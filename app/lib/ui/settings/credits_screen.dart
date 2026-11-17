/// Os créditos dos dados do mapa (0.23.0): o OpenStreetMap e o Overture Maps, com as fontes que a página de atribuição do
/// Overture pede para os temas que os pacotes usam (prédios e places). A lista são as fontes presentes nos recortes de Campinas e
/// de São Paulo da release 2026-10-21.0 (sem Esri nem as outras fontes de prédios, que não aparecem nelas).
library;

import 'package:flutter/material.dart';

import '../colors.dart';
import '../menu/screen_frame.dart';

typedef Credit = ({String name, String license, String note});

const kMapCredits = <Credit>[
  (
    name: 'OpenStreetMap',
    license: 'ODbL 1.0',
    note: '© OpenStreetMap contributors. Ruas, água, verde, biomas, prédios e pontos de interesse. Disponível sob a Open Database License.',
  ),
  (
    name: 'Overture Maps Foundation',
    license: 'prédios ODbL 1.0, places CDLA Permissive 2.0',
    note: '© OpenStreetMap contributors, Overture Maps Foundation (overturemaps.org), release 2026-10-21.0. Prédios e pontos de interesse que o OSM ainda não tem.',
  ),
  (
    name: 'Microsoft Global ML Building Footprints',
    license: 'ODbL 1.0',
    note: 'Contornos de prédios detectados por imagem de satélite, pelo Overture. Licenciado pela Microsoft sob a Open Database License.',
  ),
  (
    name: 'Google Open Buildings',
    license: 'CC BY 4.0',
    note: 'Contornos de prédios detectados por imagem de satélite, pelo Overture. Disponível sob CC BY 4.0.',
  ),
  (
    name: 'Places do Overture: Meta, Microsoft, Uberall, PinMeTo, OpenTravel Alliance e DAC',
    license: 'CDLA Permissive 2.0',
    note: 'Pontos de interesse (comércio, bares, igrejas, escolas, praças) das fontes do tema places do Overture.',
  ),
  (
    name: 'AllThePlaces',
    license: 'CC0 1.0',
    note: 'Pontos de interesse de lojas e redes, pelo Overture.',
  ),
  (
    name: 'Foursquare',
    license: 'Apache 2.0',
    note: 'Copyright 2024 Foursquare Labs, Inc. All rights reserved. Dados transformados para o esquema do Overture.',
  ),
  (
    name: 'SRTM (NASA)',
    license: 'domínio público',
    note: 'O relevo (SRTMGL1, 1 segundo de arco).',
  ),
];

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(title: 'Créditos', subtitle: 'Dados do mapa', children: [
      for (final c in kMapCredits)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name.toUpperCase(), style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
            Text(c.license, style: const TextStyle(fontSize: 8, color: kSignal, height: 1.8)),
            Text(c.note, style: const TextStyle(fontSize: 8, color: kDim, height: 1.8)),
          ]),
        ),
      const Text('Os prédios derivados do OpenStreetMap e do Overture continuam sob a ODbL.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
    ]);
  }
}
