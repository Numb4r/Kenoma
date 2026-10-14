# M5b · Camada visual: capturas e números

Capturas do moto g54 (1080 × 2400), release 0.8.2+14, no zoom padrão (90 m de largura), com o simulador de GPS no lugar indicado. Nenhuma tem posição real do jogador.

| Arquivo | Lugar | O que mostra |
| --- | --- | --- |
| `unicamp.png` | Unicamp (-22,8174, -47,0697) | gramado (área verde) com caminhos de pedestre e ruas locais, a Aura de 25 m e o rastreador com um Eco fora da tela |
| `centro.png` | Centro de Campinas (-22,9056, -47,0608) | quadras de cidade, ruas com asfalto escuro e calçada de 1 pixel de arte em tom mais claro, e o rastreador com 3 Ecos |
| `taquaral.png` | Lagoa do Taquaral (-22,8660, -47,0535) | a borda da lagoa (água) com contorno de 1 pixel de arte, uma rua e áreas de parque |

## Pacote visual

| Campo | Valor |
| --- | --- |
| Arquivo | `app/assets/regions/campinas_e0_vis.bin` |
| Tamanho | 3.023.548 bytes (3,02 MB) |
| SHA-256 | `d0ba04db14106e0cffb24b8076adf147116f6e1833f0fdc027c8955ed1fa6f27` |
| Tiles z15 | 1.442 |
| Polilinhas (ruas) | 87.950, a partir de 68.422 vias |
| Polígonos (água e verde) | 16.682, a partir de 10.408 |
| Extrato | o mesmo da época 0 (`sudeste-latest.osm.pbf`, MD5 `d4778499e2017add7ee7879dd3b64b3c`) |
| Tempo | 4 min 14 s de `build_visual.py` |

O formato está em `docs/fase0-spec.md`, seção 1, "Pacote visual".

## Câmera com rotação e pixel de arte fixo de tela (0.9.0)

`rotacao.png`: Unicamp com o mapa girado cerca de 34°, no zoom padrão. As ruas ficam em diagonal com degraus de pixel de arte do mesmo tamanho de sempre, os sprites ficam de pé e a bússola aponta o norte.

**fps no moto g54** (90 Hz), release, Centro de Campinas, simulador andando de bicicleta, medido com `FrameTiming` numa build temporária com um roteiro automático. Nenhuma das fases precisou do pixel de arte maior (`coarse`):

| Fase (12 s cada) | fps | total p50 | total p90 | raster p50 |
| --- | --- | --- | --- | --- |
| parado, zoom padrão | 74 a 82 | 6 a 13 ms | 15 ms | 3 a 7 ms |
| girando a 0,9 rad/s | 89 a 90 | 5,5 a 7 ms | 7 a 9 ms | 3 ms |
| zoom oscilando de 60 a 150 m | 90 | 6 a 13 ms | 7 a 16 ms | 3 a 7 ms |
| girando e com zoom | 90 | 13 a 14 ms | 16 a 17 ms | 7 ms |

O tempo de rasterizar do lado do Dart (montar o desenho) ficou em 0,3 a 0,7 ms por quadro. Com giro e zoom juntos, 13% dos quadros passaram de 16,7 ms em algumas janelas de 3 s (37 de 273 na pior), sem queda no fps. O roteiro não é um gesto real de dois dedos: giro e zoom foram forçados por código, e o joystick ficou preso por `adb input swipe` para o aparelho manter o relógio alto.

## O que não foi medido

- **GPS real.** Tudo foi visto com o simulador.
- **O seguir direção com a bússola do celular de verdade.** O fluxo está coberto por testes com uma bússola de mentira, mas não girei o celular na mão.
- **Gesto real de dois dedos.** O `adb` não faz multitoque; o gesto foi testado por código e em testes de widget.
