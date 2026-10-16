# Densidade da época 2

A 0.13.0 deixou o jogo esparso na rua. A época 2 (0.13.1) refaz a densidade com a Aura de 10 m e põe Fagulhas e materiais sobre o que dá para andar. Medido por `app/tools/sim_caminhada.dart` (20 largadas por rota, a 1,3 m/s, 10 minutos, Aura de 10 m, alcance de toque de 30 m, visão de 120 m).

## O que mudou no mundo

- **Itens por célula e janela** (`epochs.json`, época 2): 1 Eco, 5 Fagulhas (35% cada) e 2 pontos de material (25% cada). A chance de Eco é 2,2 vezes a da época 1 (urbano, verde e água 33%; residencial 26,4%).
- **Posição.** Fagulhas e materiais são projetados no caminho andável mais próximo dentro da célula z20 (ruas de todas as classes, calçadas, ciclovias e trilhas do pacote visual). Os Ecos preferem o caminho, mas podem ficar até 15 m fora dele. Célula sem nada andável fica com a posição crua do sorteio.
- **Geometria fixada.** A época 2 fixa o SHA-256 do pacote visual (`campinas_e0_vis.bin`), porque agora a posição dos itens depende dele. Trocar o pacote exige época nova.
- **Os sorteios não mudam de ordem:** só a posição final é levada ao caminho. Um teste compara a mesma célula com e sem projeção.

## Resultado (média das 3 rotas de ~800 m)

| | Fagulhas | Materiais | Ecos a ≤30 m | Ecos a ≤120 m | Parado 1 h em casa (≤30 m) |
|---|---|---|---|---|---|
| Meta | 20 a 30 | 5 a 8 | 6 a 10 | "bem mais" | cerca de 2 |
| Antes (época 1, Aura 10 m) | 5,3 | 1,8 | 3,5 | 21,4 | 1,37 |
| **Depois (época 2)** | **23,7** | **7,0** | **7,9** | **43,9** | **2,35** |

Por rota (depois): residencial 11,3 Fagulhas, 3,1 materiais, 5,3 Ecos a ≤30 m; avenida 28,4, 8,1, 9,8; parque 31,3, 9,8, 8,5.

A rota residencial fica abaixo da média e do piso de 20 Fagulhas: as ruas locais têm menos trechos andáveis por célula. A meta vale para a média das três; se a rua de bairro precisar de mais, o ajuste é subir a chance dos itens sem tocar na avenida e no parque, o que exige uma época nova.

## Como reproduzir

```
cd app
dart run tools/sim_caminhada.dart --epochs 1,2 --starts 20
python3 tools/calibrate_density.py --eco 2.2 --sparks 5 0.35 --materials 2 0.25   # reescreve as épocas 2 e 3
```

As rotas saem do grafo de ruas do pacote visual, a partir de três pontos de Campinas (Barão Geraldo, Av. Barão de Itapura e Parque Portugal), seguindo sempre o trecho que menos vira. A época 3 (Rua viva, 0.14.0) copia a densidade da época 2.
