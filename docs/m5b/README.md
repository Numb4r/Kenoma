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

## O que não foi medido

- **fps.** O `dumpsys gfxinfo` não enxerga os quadros do Flutter neste aparelho (devolve 0 quadros), então não há número de fps. O mapa foi andado com o simulador de bicicleta (6 m/s) por 12 s, sem erro no log e sem travada visível nas capturas, mas isso não é medição. Falta medir como no M4, com `FrameTiming`.
- **GPS real.** Tudo foi visto com o simulador.
