import '../capture/eco_type.dart';

/// Nome do tipo na interface.
String typeLabel(EcoType t) => switch (t) {
      EcoType.fire => 'Fogo',
      EcoType.water => 'Água',
      EcoType.plant => 'Planta',
      EcoType.earth => 'Terra',
      EcoType.electric => 'Elétrico',
      EcoType.metal => 'Metal',
      EcoType.light => 'Luz',
      EcoType.shadow => 'Sombra',
      EcoType.spectral => 'Espectral',
      EcoType.digital => 'Digital',
      EcoType.fae => 'Feérico',
      EcoType.draconic => 'Dracônico',
    };

/// O padrão de resistência do tipo no dial, em uma frase (docs/GDD.md, tabela de resistência): a aba Sintonia do Bestiário.
String typePatternText(EcoType t) => switch (t) {
      EcoType.fire => 'O sinal dá picos e deixa uma isca cinza para trás: siga a onda ciano depois da queima.',
      EcoType.water => 'O sinal vai e volta como maré: acompanhe a onda sem correr atrás dela.',
      EcoType.plant => 'Raízes crescem no dial e cortam a sintonia: mantenha o botão fora delas.',
      EcoType.earth => 'Faixas pesadas no dial: dentro delas o progresso sobe devagar.',
      EcoType.electric => 'O sinal salta entre duas ou três frequências em ritmo fixo: o arco avisa o salto.',
      EcoType.metal => 'De tempos em tempos sobe a blindagem: alinhado, só solta faísca, sem progresso.',
      EcoType.light => 'Clarões apagam a onda e deixam a imagem de onde ela estava.',
      EcoType.shadow => 'A onda afunda na tinta: siga o pulso fraco que aparece na borda do dial.',
      EcoType.spectral => 'Uma cópia cinza imita a onda com atraso: a verdadeira é a ciano.',
      EcoType.digital => 'Cópias falsas pulam de lugar: a verdadeira é a que não tem glitch.',
      EcoType.fae => 'O dial inverte o sentido de tempos em tempos e o padrão muda no meio.',
      EcoType.draconic => 'Começa calmo e, a cada etapa, soma o padrão de outro tipo.',
    };
