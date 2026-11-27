# Estilo das criaturas

O formato e a régua de acabamento das criaturas (GDD, "Direção visual das criaturas" e "Direção de arte", Formas por camada e Câmera). O Humoth (`tools/art/creatures/humoth/`, gerado por `build.lua`) é a régua do Eco: os números abaixo saem dele, e toda etapa de toda família é medida contra eles.

## Etapas e tamanhos

Toda família tem quatro etapas de criatura (Eco, Espírito, Entidade Maior, Arquétipo) e a Fagulha, que não é etapa: é o fragmento solto que carrega o traço-assinatura. Pixel de arte de 2 dp, um tamanho de pixel só por sprite, 4 px por metro do mundo.

| Etapa | Quadro no mapa | Altura no mundo | Retrato | Onde aparece |
|---|---|---|---|---|
| Fagulha | 12 × 12 | 3 m | 96 × 96 | mapa comum |
| Eco | 28 × 28 (fixo) | 7 m | 96 × 96 | mapa comum |
| Espírito | 36 × 36 | 9 m | 96 × 96 | mapa comum |
| Entidade Maior | 48 × 48 | 12 m | 96 × 96 | mapa comum, rara: ocupa a rua de calçada a calçada |
| Arquétipo | 64 × 64 | 16 m | 128 × 128 | só evento e Incursão |

- O Arquétipo não nasce no mapa comum. Com a câmera de 40 a 80 m de largura, 16 m são de 20% a 40% da tela (128 dp num aparelho de 360 dp): ele é a cena, não um ponto dela. No mapa comum ele só existe pelos pedaços (as Fagulhas e as etapas de baixo); o sprite de 64 entra em evento e Incursão.
- A criatura olha para a **direita**; o código espelha. O centro do corpo fica no centro do quadro no quadro 0 do `idle`.
- Deixe 2 px livres em cima e 1 px embaixo no quadro 0 do `idle`; nada do corpo encosta na borda. Só o emissivo solto do Arquétipo pode sair do quadro.
- Sem sombra no desenho.

## A régua em números

Medidas sobre o quadro parado (quadro 0 do `idle` e do retrato), nas camadas `corpo` e emissiva (`leds` + `glow`):

- **opacos**: pixels opacos do corpo.
- **cores**: cores distintas na camada corpo (o contorno e os emissivos apagados contam).
- **detalhe interno**: fração dos pixels de dentro (opacos, fora o contorno) que têm um vizinho de lado, também de dentro, de outra cor.
- **contorno**: fração dos opacos na cor `#1a1424`.
- **emissivo**: pixels da camada emissiva divididos pelos opacos do corpo.
- **degraus**: valores distintos por material (asa, pelo, metal).

O Humoth mede, no mapa: 404 opacos, 10 cores (3 de asa, 2 de pelo, 1 de antena, contorno e 3 apagadas; o retrato soma 2 de asa de trás, 1 de pelo e 1 de antena), 3 degraus na asa, detalhe 0,88, contorno 0,23, emissivo 0,10 (24 pixels em `leds` com 2 cores, 16 em `glow` com 1). No retrato: 14 cores, detalhe 0,44, contorno 0,19, emissivo 0,08. O "mascote" a evitar (o Sootling antigo) mede detalhe 0,54 no mapa.

Pisos no mapa (`tools/art/creatures/conceitos/_conceito.lua` traz a mesma tabela em `PISO` e avisa ao gravar; `python3 tools/art/creatures/regua.py` confere a arte final com os mesmos números e sai com erro abaixo do piso):

| Etapa | Cores (mín.) | Degraus no material principal (mín.) | Detalhe interno (mín.) | Contorno (máx.) | Emissivo (faixa) | Cores emissivas (mín.) |
|---|---|---|---|---|---|---|
| Fagulha | 6 | 2 | 0,85 | 0,45 | 0,15 a 0,50 | 2 |
| Eco | 10 | 3 | 0,80 | 0,28 | 0,06 a 0,14 | 3 |
| Espírito | 12 | 3 | 0,75 | 0,28 | 0,09 a 0,18 | 3 |
| Entidade Maior | 14 | 3 | 0,70 | 0,26 | 0,12 a 0,24 | 3 |
| Arquétipo | 14 | 3 | 0,65 | 0,24 | 0,16 a 0,40 | 4 |

Pisos no retrato: contorno no máximo 0,22 em toda etapa; o teto de emissivo é o do mapa.

| Etapa | Cores (mín.) | Detalhe interno (mín.) | Emissivo (mín.) |
|---|---|---|---|
| Fagulha | 10 | 0,40 | 0,10 |
| Eco | 14 | 0,40 | 0,05 |
| Espírito | 16 | 0,45 | 0,07 |
| Entidade Maior | 16 | 0,50 | 0,09 |
| Arquétipo | 16 | 0,50 | 0,14 |

**Ampliação** (só o `regua.py` confere, em toda etapa): fração das trocas de cor do corpo que caem na fronteira da grade de blocos 2×2 (a melhor das duas fases, na pior direção). Desenho nativo mede perto de 0,50; um sprite menor ampliado 2×, ou textura em bloco de 2, mede até 1,0. Teto: 0,62. Reprovou: desenhe a textura no pixel do quadro (no retrato, `p = 1`), não mexa no teto.

Além dos números, em toda etapa: `lint_sprite` na camada corpo sem peça solta nem pixel sozinho; nenhuma cor do corpo com saturação de desenho animado (as cores vêm do material: pó de asa, cobre, aço, porcelana, fuligem); o traço-assinatura da família visível no tamanho do mapa, inclusive na Fagulha.

Contorno: 1 px em `#1a1424` por fora da forma, nunca preto. Faísca solta não tem contorno. Do Espírito para cima o contorno é seletivo: peça fina (fio, pelo solto, filamento) pode ficar sem ele, desde que se leia no asfalto de noite e no concreto de dia.

## Escada de tom

O Eco é simpático, elegante e só um pouco errado; cada etapa é mais sinistra; o Arquétipo é a forma original, horror cósmico.

| | Fagulha | Eco | Espírito | Entidade Maior | Arquétipo |
|---|---|---|---|---|---|
| O que é | um pedaço solto com o traço-assinatura | o bicho, com um detalhe estranho | o bicho tomado pelo pedaço da cidade | o lugar inteiro faz parte dela | o bicho e o objeto são máscaras de outra coisa |
| Anatomia | não tem: é um fragmento | natural | partes em número errado (olhos, antenas, asas) | rosto fora do lugar, membros a mais | rosto ausente; no lugar do corpo, um vão |
| Simetria | livre | bilateral | bilateral quebrada (um lado não repete o outro) | tripla ou radial, em cata-vento | tripla ou radial sobre uma forma que não fecha |
| Bicho : objeto | só o traço | 9 : 1 | 6 : 4 | 4 : 6 | o objeto é a armação; do bicho sobram pedaços |
| Regra quebrada | nenhuma | nenhuma | nenhuma | uma regra física, visível parada | geometria impossível mais uma regra física |
| Emissivo | 15% a 50% | 6% a 14% | 9% a 18% | 12% a 24% | 16% a 40% |
| Paleta | a do Eco | cor do material, 3 degraus | a do Eco mais o material do objeto | mais escura, o objeto domina | dessaturada (cinza, osso, aço); a cor é quase só luz |
| Costura do Véu | várias, finas (1 px), só no `glow` | menos e mais largas | menos e mais largas | uma ou duas, largas | nenhuma: o vão |
| Violeta do Véu | não | só na costura | só na costura | só na costura | o vão, no emissivo |

Em toda etapa: proporção natural do bicho, sem olho grande de mascote; contraste pelo valor e pela luz do tipo; o que brilha vai na camada emissiva. A regra física da Entidade Maior e do Arquétipo fica escrita no `docs/art/conceitos/<familia>.md`.

## Decisões da rodada 1 de conceitos

- **Costura do Véu** (GDD, "Costura do Véu"): violeta `#9b7bff`, sempre na camada `glow`, com o par apagado no `corpo` num tom quase igual ao do material, para sumir de dia e acender à noite. O Eco tem mais costuras, finas; a cada etapa ficam menos numerosas e mais largas. O Arquétipo não tem costura: tem o vão. O Humoth ganha uma costura fina só no `glow`, sem mudar o resto.
- **Arquétipo:** só em evento e Incursão. O vão violeta é o elemento comum; o bicho e o objeto da cidade são máscaras que não dão conta do que está atrás: a silhueta ainda lembra o bicho, mas errada (escala, simetria demais ou de menos, partes que se repetem para dentro do vão), e o vão é onde a máscara não fecha. Disco radial só no Hum, no Wisp e no Wyrm; os outros nove têm silhueta própria. Nada de mandala nem de objeto (armário, mesa, painel, ave).
- **Espírito:** um elemento claramente errado que o Eco não tem (o objeto tomando o corpo por dentro, uma parte no lugar errado, um olho a mais), não só o bicho maior com mais objeto.
- **Entidade Maior:** a anatomia cede de verdade (o poste do Hum, o saruê enrolado na brasa do Soot, a marquise com morcegos do Shade são a medida).
- **Retratos:** o desenho do mapa refeito no tamanho do retrato, com detalhe e textura no pixel do retrato (nunca em bloco de 2: a régua mede a ampliação); o do Arquétipo é a forma inteira em 128.
- **Retrato do Arquétipo (128, nativo):** a mesma silhueta e o mesmo vão do 64 aprovado, com a forma inteira dentro da moldura, nos doze: o `draw` do mapa refeito em escala 1,85 a 2, centrado, com pelo menos 5 px de margem em todo quadro (só o emissivo solto passa). Nada de busto nem de rasgo na borda (`margin = false` no `_retrato.lua`). O alcance da luz e a profundidade do vão acompanham a escala, para o fundo do vão aparecer. O acabamento é o de `tools/art/creatures/_retrato.lua`, chamado no `draw` de cada espécie:
  - corpo: todos os degraus do material, com volume (luz de cima à esquerda), textura do material real no pixel (pelo em fios, ferro e concreto com poros, pedra e osso com trincas, pano em sarja, escama em fileiras) e a borda recortada pela luz do tipo, na camada `glow`, por fora e em volta do vão. No Soot a brasa escurece o que está perto (a regra dele) e a luz da borda vem da boca;
  - vão: do violeta `#9b7bff` da borda ao quase preto `#0d0914` em seis degraus (`! @ $ %` no `glow`, `= *` no corpo, que não entram no `map` das variantes), com o que há lá dentro: a repetição do bicho que a espécie já desenha, uma faixa de poeira que desliza e estrelas na luz do tipo, cada uma piscando no seu passo;
  - cores do corpo só as do `map` das variantes, mais as apagadas.
- **Ângulo:** bicho que voa pode ser visto de cima; bicho que anda fica de perfil. **Exceção aceita pelo dono:** a Entidade Maior e o Arquétipo do Rill ficam de frente (rodada 3, `docs/art/conceitos/rill.md`); o Rillet e o Brookkin seguem a regra.
- **Cores emissivas:** a luz do tipo é sempre a de `tools/art/ui/types/palette.lua`. O ciano `#5fd3c6` fica só para o sinal e o Hum. **A única exceção é o Glare multicolor (decisão do dono):** a base é a luz do tipo Luz (`#FFF0B8`, `#FFFBE6`, `#CDB468`) e o espectro do prisma vai por cima dela, em cores claras, longe do violeta do Véu, do ciano do sinal e do laranja da Essência. A rodada 3 dos conceitos tinha tirado o multicolor; a arte final o devolve. O vão quase preto do Hum (`#0d0914`) continua, e não é luz. O Rust troca o azul-aço por outra luz do tipo Metal.
- **Exceções de tamanho e forma:** aceitas, desde que os Ecos continuem legíveis a 28 px, de noite e de dia.

## As três camadas

Cada animação sai em três tiras horizontais com os mesmos quadros, uma por camada:

| Arquivo | Camada | O que vai nela | O que o código faz |
|---|---|---|---|
| `<especie>_<anim>.png` | corpo | tudo o que não brilha, mais as partes emissivas **apagadas** num tom escuro (o olho desligado continua lendo como olho) | recebe o tom da noite e do clima e a troca de cor da variante |
| `<especie>_<anim>_leds.png` | leds | só o que **pisca**: ocelos, olhos, LEDs acesos | desenha depois do tom e faz piscar, fora de fase com o movimento |
| `<especie>_<anim>_glow.png` | glow | o que brilha **sem piscar**: veios, costuras, faíscas soltas | desenha depois do tom, sem piscar |

Regras: um pixel aceso em `leds` ou `glow` tem sempre o par apagado embaixo dele em `corpo` (menos a faísca solta, que só existe em `glow`). As cores apagadas e as emissivas não entram no mapa de variantes: ficam iguais em todas. Quando a animação pede brilho que cresce (alerta, fuga), ele é desenhado quadro a quadro em `glow`.

Os conceitos (um quadro parado por etapa) saem com as duas camadas emissivas juntas, em `<familia>_<etapa>_<mapa|retrato>_emissivo.png`; a separação em `leds` e `glow` é feita na animação.

## Animações

Seis no mapa, mais o retrato. Os quadros abaixo são os do Humoth e são o **mínimo** de toda etapa; outra espécie pode mudar o fps no `<especie>.json`, não a lista. A Fagulha tem um laço só, de 4 quadros a 5 fps.

| Animação | Quadros (mín.) | fps | O que mostra |
|---|---|---|---|
| `idle` | 4 | 8 | parado: o movimento próprio da espécie em laço (bater de asa, respirar), o corpo sobe e desce 1 px |
| `drift` | 4 | 8 | deriva: o mesmo laço, inclinado na direção do movimento |
| `alert` | 3 | 6 | pose aberta e parada, o brilho crescendo em `glow`; `leds` fixos |
| `flee` | 6 | 12 | 1 quadro de antecipação (encolhe e desce 1 px), depois sobe e sai de lado deixando rastro em `glow` |
| `spawn` | 6 | 10 | 3 quadros só de faíscas se juntando, 1 de silhueta escura com os emissivos acesos, 2 abrindo até a pose do `idle` |
| `tuned` | 6 | 10 | 1 quadro inteiro e aceso, 3 se desfazendo de fora para dentro, 2 só de faíscas, a última juntando no centro |
| retrato | 4 | 6 | pairando: corpo e asas sobem em passos diferentes, os LEDs varrem, os veios pulsam |

Quanto mais alta a etapa, mais lento o laço: Entidade Maior e Arquétipo usam `idle` e `drift` de 6 quadros ou mais, a 6 fps ou menos.

**Arquétipo: o vão é o corpo, o bicho e o objeto são a máscara.** A espécie declara o vão no `run` (`vao = { lit, fill, mid, edge, extra }`) e o `K.run` do `_hum.lua` faz, em toda espécie:

- `idle` e `drift`: o que está dentro do vão se mexe no passo próprio da espécie (queixadas que afundam, coroa que tremula, olhos que descem); o vão sobe e desce um quadro antes da máscara (ela atrasa) e respira duas vezes por laço, avançando 1 px sobre a máscara;
- `flee`: depois da antecipação a máscara se abre e o vão engole o resto (1, 2, 4, 6 e 9 px);
- `spawn`, 7 quadros: 3 de faíscas, 1 só do vão na forma da silhueta (`body_visible` 0), e a máscara se fecha sobre ele em 2 quadros até a pose do `idle`;
- retrato: o vão vai um quadro à frente do corpo, a borda dele respira e o céu de dentro anda no seu passo;
- **vão de dia:** sem o `glow` o vão continua violeta, mais fraco, pela camada `corpo`. O par apagado dos emissivos do vão desce em degraus (`#45378A` na borda, `#32286A` no meio, `#241B4C` e `#1B1230` para o fundo), o que vive lá dentro fica em `#5B4AA6`, `#45378A` ou `#32286A` conforme o brilho (ainda se lê) e o fundo liso ganha dois degraus junto da borda. Vale no mapa de 64 e no retrato de 128, em todo quadro; essas cores não entram no `map` das variantes. Conferência: `python3 tools/art/creatures/vao_dia.py` grava `docs/art/final/vao_dia.png` (os doze, 64 e 128, de noite e de dia).

O `<especie>.json` lista `frame`, `anims` (quadros e fps) e `body_dy` (quanto o corpo sobe em cada quadro, em pixels, negativo para cima). O do Humoth traz ainda `body_visible` (0 nos quadros que são só faísca, onde o acessório da variante não deve aparecer) e `portrait`.

## Variantes

A variante tem de se ler em **escala de cinza**: muda o **valor** do corpo e ganha um **acessório**; trocar só o matiz não vale.

- `<especie>_variants.json`: por chave (`urban`, `green`, `water`, `residential`, `lit`, `sacred`, `crimson`), o `map` de cor para cor do corpo e o `accessory`.
- O acessório é um PNG do tamanho do quadro do mapa, desenhado sobre o quadro 0 do `idle`. Fica no tronco (a parte que só se move por `body_dy`), nunca numa parte que bate ou balança, e tem forma e lugar próprios: dois acessórios não ocupam o mesmo ponto do corpo.
- Escada de valor do Humoth, do mais escuro ao mais claro: `crimson`, `water`, `urban`, base, `green`, `residential`, `sacred`, `lit`. Acessório claro em corpo escuro e escuro em corpo claro.
- O mesmo `map` vale para o retrato: o retrato só usa as cores do corpo que estão no mapa.
- O Brilhante não tem arquivo: é o único com brilho animado, feito em código.

## O que é desenhado e o que é código

| Desenhado | Código |
|---|---|
| os quadros das três camadas, olhando para a direita | espelhar para a esquerda |
| o corpo subindo e descendo dentro do quadro (`body_dy`) | deslocar o sprite no mapa (a fuga para cima e para o lado) |
| os emissivos acesos e apagados | o tom da noite e do clima no corpo, e os emissivos por cima sem tom |
| o brilho que cresce no alerta e o rastro da fuga | o piscar da camada `leds` |
| as faíscas do `tuned` até juntarem no centro | levar as faíscas até o Conjurador |
| o acessório e o mapa de cor da variante | aplicar o mapa, pôr o acessório em todo quadro com `body_dy`, o brilho do Brilhante |
| nada | a sombra no chão |

## Conferência

- Conceitos: cada família desenha em `tools/art/creatures/conceitos/<familia>/build.lua` com o ajudante `_conceito.lua` (o uso está no topo do arquivo), que grava corpo e emissivo e imprime as medidas da régua. `python3 tools/art/creatures/conceitos/folhas.py` monta `docs/art/conceitos/<familia>.png` (mapa em 2× e 4×, de noite e de dia, e o retrato), `ecos.png`, `arquetipos.png` e `escada.png`. O `docs/art/conceitos/<familia>.md` diz o bicho, o pedaço da cidade, o traço e uma frase por etapa.
- Espécie pronta: a folha `<especie>_folha.png` (4×, vizinho mais próximo, fundo de asfalto com o tom da noite) traz uma fileira por animação, na ordem da tabela, com o corpo no tom da noite e `leds` e `glow` por cima; depois três fileiras de variantes (base, `urban`, `green`, `water`, `residential`, `lit`, `sacred`, `crimson`): em cor, em cinza e com o tom da noite.
- Arte final: `python3 tools/art/creatures/regua.py` mede o quadro 0 do `idle` e do retrato de toda espécie (e as Fagulhas refeitas), confere a ampliação e falha abaixo do piso; as pastas das famílias ainda sem arte final ficam em `PENDENTES` e saem da lista quando a família for integrada.
- Família pronta: `python3 tools/art/creatures/familia.py <familia> fagulha:<tipo> eco:humoth eco:<pasta> espirito:<pasta> entidade:<pasta> arquetipo:<pasta>` monta `docs/art/final/<familia>.png` (o quadro 0 do `idle` a 4×, de noite e de dia, e os retratos), com o Humoth ao lado.
- Antes de entregar: `view_sprite` em cada sprite, `lint_sprite` na camada `corpo` sem peça solta nem pixel sozinho, e nenhum quadro encostando na borda.

## No app (0.25.1)

- `scripts/sync_creature_art.py` copia as pastas completas (json, variantes, retrato e folha) para `app/assets/art/creatures/`, sem as fontes nem a folha, e reescreve o `index.json` (espécie → pasta e gatilho de nascer). 0.26.2: depois ele roda `scripts/pack_creature_atlas.py`, que junta as pastas de cada família numa folha (`app/assets/art/creatures/atlas/<família>.png` e `.json`); só as folhas vão para o APK (o build do Android também roda o script), e as pastas ficam de fonte.
- Gatilho de nascer, por família, só no desenho (o Eco continua no ponto da seed): Hum `lightning_lamp` (o raio na tempestade; à noite, faíscas do poste mais perto até `lamp_m`), Rill `puddle` (a poça ondula, com chuva), Clod `ground` (o chão se revira), Wisp `fog` (a neblina se junta). Os climas de cada gatilho estão no `index.json`.
- Gatilhos decididos pelo dono depois da arte final (0.26.0): Soot `manhole` (sai do bueiro), Frond `crack` (sai da rachadura da calçada), Wyrm `crater_crack` (da cratera de meteoro, na chuva de meteoros; do asfalto rachado com brasa, fora dela). Depois, pela coluna "Onde e quando" do GDD: Glare `glint_rainbow` (sai da faixa do arco-íris à vista; senão, de dia, do clarão de sol na vitrine; de noite, sem gatilho), Bit `static_sign` (a placa, banca ou ponto de ônibus mais perto até `lamp_m` pisca em estática e solta o pombo; sem nenhum perto, a estática acende em cima dela), Rust `grate` (uma grade enferrujada range atrás dela e solta limalha que se junta no besouro) e Sprig `whirl` (folhas secas giram num redemoinho que fecha nela; no crepúsculo real, com pólen aceso). Só o Shade segue sem gatilho.
- O retrato no Bestiário troca as cores pelo mesmo `map` da variante (sem o acessório, que é do quadro do mapa).
- `test/ui/creature_art_test.dart` cobre toda espécie do índice: grade (28 no Eco, 36 no Espírito), as seis animações nas três camadas, retrato de 96, variantes distintas em cinza (no mínimo 12 pixels por par) e o retrato da variante com a silhueta igual. Os quadros de 48 e 64, o retrato de 128 e os pisos da régua ainda não estão no teste.
