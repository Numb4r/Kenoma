# Densidade da época 2

A 0.13.0 deixou o jogo esparso na rua. A época 2 (0.13.1) refaz a densidade com a Aura de 10 m e põe Fagulhas e materiais sobre o que dá para andar. Medido por `app/tools/sim_caminhada.dart` (20 largadas por rota, a 1,3 m/s, 10 minutos, Aura de 10 m, alcance de toque de 30 m, visão de 120 m).

## O que mudou no mundo

- **Itens por célula e janela** (`epochs.json`, época 2): 1 Eco (chance 1,65 vezes a da época 1), 5 Fagulhas (35%) e 2 pontos de material (20%).
- **Chance proporcional ao caminho.** A chance de Fagulhas e materiais é multiplicada por `min(1, comprimento andável da célula / 25 m)` (`walkable.ref_length_m`, `walkable.max_factor`): quarteirão com pouca rua dá menos item, e o item por metro de caminho fica parecido por toda parte. Os Ecos não usam o fator (o alcance de 30 m já cobre as ruas vizinhas).
- **Posição.** Fagulhas e materiais são projetados no caminho andável mais próximo dentro da célula z20 (ruas, calçadas, ciclovias e trilhas do pacote visual). Os Ecos preferem o caminho, mas podem ficar até 15 m fora dele. Célula sem via nenhuma no mapa fica com a posição crua do sorteio.
- **Rodovias não são caminho.** Motorway, trunk e seus links, lidos do mesmo extrato da época 0 (`pipeline/build_nowalk.py` → `campinas_e2_nowalk.bin`, 1966 vias, SHA-256 fixado na época 2), saem do caminho andável. O item que cairia numa delas vai para a calçada ou o caminho mais próximo; sem caminho a até 35 m (ou numa célula só com rodovia), não nasce.
- **Geometria fixada.** A época 2 fixa o SHA-256 do pacote visual (`campinas_e0_vis.bin`) e o do pacote das rodovias, porque a posição dos itens depende dos dois. Trocar qualquer um exige época nova.
- **Os sorteios não mudam de ordem:** só a chance, a posição final e a existência dependem do caminho. Um teste compara a mesma célula com e sem projeção.

## Resultado, por rota (20 largadas, 10 minutos)

| | Fagulhas | Materiais | Ecos a ≤30 m | Ecos a ≤120 m |
|---|---|---|---|---|
| Meta, por rota | 20 a 30 | 5 a 8 | 6 a 10 | "bem mais" |
| Época 1, Aura 10 m: residencial | 8,2 | 2,7 | 5,9 | 24,7 |
| Época 1: avenida | 6,5 | 2,1 | 4,3 | 24,0 |
| Época 1: parque | 6,8 | 2,5 | 4,5 | 23,1 |
| **Época 2: residencial** | **21,6** | **5,3** | **10,4** | 41,1 |
| **Época 2: avenida** | **26,4** | **6,2** | **7,6** | 36,8 |
| **Época 2: parque** | **26,7** | **6,3** | **5,6** | 32,0 |

Parado em casa por 1 hora: 1,37 Ecos a ≤30 m na época 1 e 1,72 na época 2 (meta: cerca de 2).

Fora da meta: o parque tem 5,6 Ecos a ≤30 m (meta 6) e a rota residencial, 10,4 (meta até 10). A diferença vem de a rota residencial atravessar 27 células e a do parque, 21; subir ou descer a chance de Eco troca um pelo outro.

**Sobre a rota residencial.** A primeira versão da simulação partia de um ponto de Barão Geraldo que dava voltas num beco e cobria só 11 células, o que fazia a residencial parecer pobre (11 Fagulhas). A simulação agora procura, entre 10 bairros, o primeiro ponto cuja rota anda de fato ~800 m adiante (pelo menos 20 células) e prefere trechos ainda não andados. Saiu -22.823, -47.078.

## Como reproduzir

```
cd app
dart run tools/sim_caminhada.dart --epochs 1,2 --starts 20 [--debug]
python3 tools/calibrate_density.py --eco 1.65 --ref 25 --maxf 1 --sparks 5 0.35 --materials 2 0.2   # reescreve as épocas 2 e 3
cd ../pipeline && .venv/bin/python build_nowalk.py --region campinas   # só para refazer as rodovias (muda o SHA da época)
```

As rotas saem do grafo de ruas do pacote visual, a partir de três pontos de Campinas (um bairro residencial, a Av. Barão de Itapura e o Parque Portugal), a 1,3 m/s. A época 3 (Rua viva, 0.14.0) copia a densidade da época 2.
