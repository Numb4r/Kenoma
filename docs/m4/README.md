# Capturas do M4 · mapa estático

Capturas reais do moto g54 (`adb screencap`, 1080 x 2400), com a release 0.5.0+6.

- `mapa_unicamp_16px.png` e `mapa_centro_16px.png`: a escala da spec (16 px lógicos por célula z21, ~26 x 57
  células). A mira ciano é o centro da câmera. O dedo está um pouco acima e à esquerda do centro: o
  contorno violeta é a célula z20 e o branco, a z21 sob o dedo, e o painel mostra a coordenada, as duas
  células e os biomas.
- `mapa_unicamp_zoom_minimo_vs_preview.png` e `mapa_centro_zoom_minimo_vs_preview.png`: à esquerda o
  preview do M1 (um pixel por célula, ampliado 2,625x), à direita o app no zoom mínimo (1 px lógico por
  célula, ~411 x 914 células), cobrindo as mesmas células. A geometria bate; as cores diferem porque o app
  usa a paleta fria e dessaturada de `shared/biomes.json` em vez das cores vivas do preview.

Lugares: `unicamp` (-22,8174, -47,0697) e `centro` (-22,9056, -47,0608).

## Como foram feitas

Release no celular, menu de debug → Abrir mapa. Toque no mapa para a sonda e os botões − e + do painel para
o zoom. A comparação com o preview é uma montagem em Python (recorte do `test/fixtures/campinas_e0_preview.png`
pelas mesmas células, ampliado por vizinho mais próximo, ao lado da captura).

## Fluidez (moto g54, build de perfil, tempos de quadro do `FrameTiming`)

Quadros que passaram de 16,7 ms, com toque contínuo (swipes do `adb`, que mantêm o clock do aparelho alto):

| Cenário | Quadros | Acima de 16,7 ms |
| --- | --- | --- |
| Arrastar o mapa (16 px por célula) | 1.560 | 0 (0,0%) |
| Arrastar com zoom automático varrendo de 1 a 32 px por célula | 2.547 | 81 (3,2%), nos zoom-outs extremos |
| Abertura da tela (monta os primeiros chunks) | 254 | 10 (3,9%) |

O zoom automático é um teste de estresse, mais duro que uma pinça real (varre toda a faixa a cada ~10 s).
Sem toque o aparelho baixa o clock e o raster sobe para ~12 ms, o mesmo que se viu na tela de sintonia.
