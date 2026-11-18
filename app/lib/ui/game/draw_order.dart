/// A ordem fixa de desenho do mapa do jogo, de baixo para cima (docs/clima-auditoria.md, "Ordem de desenho"). O que o
/// clima deixa no chão fica por baixo de tudo que anda; o que é do mapa mas está no ar fica por cima; o tom do clima é da
/// tela inteira, então pinta o mapa e quem está nele por igual. Dart puro: o teste confere a ordem.
library;

enum MapLayer {
  /// Ruas, verde, água, a luz do dia, a rota e os nomes das ruas.
  base,

  /// Marcas do clima no chão: cobertura das ruas, poças, crateras, brasas, velas, manchas, pegadas.
  climateGround,

  /// Sombras do clima: os pares de sombra da Lua Dupla.
  shadows,
  walkers,
  cars,

  /// 0.22.0, estilo Completo: prédios (paredes e telhados), árvores, postes e props de pé e a faixa do céu. O tráfego e os
  /// passantes passam por baixo; o que é do jogo vem depois e nunca fica escondido.
  buildings,

  /// O alcance: a Aura, o anel de toque e os rastros, por cima dos prédios.
  reach,
  creatures,
  sparks,
  materials,

  /// O Familiar, o Conjurador (ou o carro do Modo Viagem) e o retorno visual das ações.
  player,

  /// Efeitos no ar presos ao mapa: arco-íris, olho do furacão, redemoinho, vultos, a Procissão em pé.
  air,

  /// A camada de tela do clima: gotas, flocos, raios e o tom de cor, por cima do mapa inteiro.
  climateScreen,

  /// 0.25.0: a camada emissiva das criaturas (ocelos de LED, veios acesos, faíscas, o brilho do Brilhante), desenhada
  /// depois do tom da noite e do clima para continuar acesa no escuro e na chuva. O corpo da criatura recebe o tom; o que
  /// brilha, não.
  emissive,

  /// O que é HUD dentro do canvas (as marcas do Radar na borda). O resto do HUD é widget, por cima.
  hud,
}

/// Chama os pintores na ordem de [MapLayer], qualquer que seja a ordem em que foram dados. [drawn], se passado, recebe as
/// camadas pintadas, na ordem (teste e debug).
void paintLayers(Map<MapLayer, void Function()> painters, {List<MapLayer>? drawn}) {
  for (final layer in MapLayer.values) {
    final paint = painters[layer];
    if (paint == null) continue;
    drawn?.add(layer);
    paint();
  }
}
