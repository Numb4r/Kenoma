# Fase 0 · Núcleo

Objetivo único: provar que andar pela cidade vendo ela virar mundo espiritual, coletando e sintonizando criaturas, é divertido. Critério de saída: jogar duas semanas andando de verdade e ainda querer abrir o app.

Tudo que não está neste documento está fora do escopo. Plataforma alvo: Android. Web está fora do escopo, porque inteiros de 64 bits não funcionam lá.

## 0. Onde vivem os números

Os números ficam em três arquivos:

- **`epochs.json`** guarda tudo que muda o mundo: chances de spawn, espécies por bioma, quantidades, faixa de nível, materiais por bioma e o pacote de região em uso. Só muda criando uma época nova.
- **`balance.json`** guarda o que não muda o mundo: sintonia, XP, destilação, tempos, raios. Pode mudar a qualquer momento.
- **`biomes.json`** define os biomas. Também muda o mundo, então qualquer alteração exige época nova.

Os arquivos iniciais estão em `docs/dados-iniciais/` e devem ser copiados para os lugares indicados no CLAUDE.md. Os valores marcados como **fixo** entram no hash e nunca mudam.

## 1. Mapa

### Região

`pipeline/regions.json` define cada região com bbox (lon/lat mínimos e máximos), URL do extrato da Geofabrik e zoom. A Fase 0 tem só Campinas.

### Biomas

Definidos em `shared/biomes.json`, com as regras de tags OSM e os buffers em metros. Quando duas geometrias se sobrepõem, vale a de maior prioridade.

| Id | Bioma | Tags OSM principais | Prioridade |
| --- | --- | --- | --- |
| 0 | Vazio | sem dado | 0 |
| 1 | Urbano | `highway` principal (motorway a tertiary, buffer de 14 m), `landuse=commercial/retail/industrial/education/institutional/railway/construction/garages`, `amenity=university/college/school/hospital/marketplace/parking/bus_station`, `building` comercial, de escritório, industrial e institucional, `aeroway=aerodrome` | 2 |
| 2 | Verde | `leisure=park/garden/nature_reserve`, `landuse=grass/forest/meadow/recreation_ground/farmland/orchard/plant_nursery`, `natural=wood/scrub/grassland` | 3 |
| 3 | Água | `natural=water`, `waterway=river/stream/canal` (com buffer), `landuse=reservoir/basin` | 4 |
| 4 | Residencial | `landuse=residential` | 1 |

Ruas residenciais e prédios genéricos (`building=yes`, `house`, `residential`, `apartments`) **não** viram Urbano. Sem isso, os bairros residenciais sumiriam da grade.

Vazio é desenhado e tratado como Residencial para spawns, o que garante um piso mínimo. Muitos bairros no OSM brasileiro não têm `landuse` e caem aqui.

### Rasterização

- **Polígonos** entram na grade pelo centro de cada célula z21.
- **Linhas** ganham buffer em metros numa projeção métrica antes de rasterizar.
- **Sobreposição:** a célula recebe o bioma de maior prioridade.

### Formato do pacote `.bin`

**Cabeçalho**, little-endian, sem compressão, 23 bytes:

| Campo | Tipo | Valor |
| --- | --- | --- |
| magic | 4 bytes | `VEU1` |
| version | uint16 | 1, versão do formato do arquivo |
| zoom | uint8 | 21 |
| x0, y0 | uint32 | tile do canto superior esquerdo |
| width, height | uint32 | dimensões da grade |

**Dados:** depois do cabeçalho vem um stream gzip até o fim do arquivo, com `width × height` bytes. Cada byte é um id de bioma, em ordem row-major, começando em `(x0, y0)`, com y crescendo para o sul como no slippy map.

**Fora do pacote**, qualquer célula vale Vazio.

O SHA-256 do arquivo inteiro fica registrado na época que usa o pacote. Regerar o pacote com um OSM mais novo muda o mundo, então o pacote novo só entra numa época nova.

### Renderização

- Flame, um tile de 16 px por célula z21, escala inteira por vizinho mais próximo.
- Visão de cima, sem prédios em pé e sem rotação.
- Tiles placeholder na paleta fria e dessaturada do GDD, com leve ruído determinístico por célula.
- Câmera centrada no jogador. Só as células num raio visível são desenhadas.

## 2. Jogador no mapa

- Posição via `geolocator`, a cada poucos metros, só com o app aberto.
- Aura de 40 m, desenhada como círculo violeta tracejado. Interação só dentro da Aura.
- Spawns visíveis até 120 m. O rastreador também mostra até 120 m.
- Ferramenta de dev obrigatória, ativada por flag de build de debug:
  - simulador de GPS com joystick na tela;
  - teleporte para coordenada;
  - override do relógio UTC.

## 3. Núcleo determinístico (fixo)

### Tipos

Todo valor de hash é um inteiro sem sinal de 64 bits.

- **Em Dart:** usar `int` com aritmética que dá a volta em 2^64 e sempre `>>>` (deslocamento lógico), nunca `>>`.
- **Módulo:** sempre sobre os 32 bits de cima, `(h >>> 32) % n`, para nunca operar sobre número negativo.

### FNV-1a 64

Offset `0xcbf29ce484222325`, primo `0x100000001b3`. O hash recebe uma lista de campos, cada um serializado como 8 bytes little-endian em complemento de dois, na ordem dada.

Um **salt** é uma string ASCII de até 8 caracteres, completada com zeros à direita e lida como u64 little-endian:

| Salt | Valor |
| --- | --- |
| `SPWN` | 0x4E575053 |
| `OFFS` | 0x5346464F |
| `UID_` | 0x5F444955 |
| `KENOMA` | 0x414D4F4E454B |

### Seed do grupo

- É um código de 10 caracteres em base32 de Crockford, exibido como `XXXXX-XXXXX` e gerado aleatoriamente na primeira abertura.
- **Normalização:** tirar espaços e hífens e passar para maiúsculas.
- `seed_global` = FNV-1a 64 sobre os bytes UTF-8 do código normalizado.
- O QR code contém só o código.

### PCG32

- Variante XSH RR de referência.
- Semeado como `pcg32_srandom_r(initstate = h, initseq = 0x414D4F4E454B)`, com o passo de aquecimento da referência.
- **Float:** `next() / 2^32`.
- **Inteiro em `[0, n)`:** `(next() * n) >>> 32`.

### Janelas

- `deslocamento(célula) = (FNV(seed_global, cell_x, cell_y, OFFS) >>> 32) % 1200`
- `janela(célula, t) = (t_utc + deslocamento(célula)) ~/ 1200`, com `t_utc` em segundos.

### Épocas

`epochs.json` lista as épocas. Cada uma tem:
- `id`;
- `starts_utc`;
- `valid_until_utc`;
- o pacote de região;
- as tabelas de spawn.

A época vigente é a de maior `starts_utc` que já passou. Se o relógio passar do `valid_until_utc` da última época conhecida, o app mostra o aviso de mundo desatualizado e continua gerando por ela.

### Bioma da célula de spawn

Uma célula z20 contém 2 × 2 células z21. O bioma dela é a moda das quatro. Em caso de empate, vence a maior prioridade. Este passo não consome o gerador.

### Geração de uma célula

Cada célula tem quatro itens fixos, cada um com o próprio gerador:

| Índice | Item |
| --- | --- |
| 0 | Eco |
| 1 | Fagulha A |
| 2 | Fagulha B |
| 3 | Ponto de material |

`h_i = FNV(seed_global, época, cell_x, cell_y, janela, i, SPWN)` semeia o PCG32 do item `i`. Todo item consome sempre os mesmos sorteios, nesta ordem, existindo ou não:

1. `existe = float() < chance`, com a chance da tabela da época para o bioma e o índice;
2. `escolha = inteiro(soma dos pesos)`, que escolhe a espécie, o tipo da Fagulha ou o material pela lista ponderada da época, na ordem do arquivo;
3. `delta = inteiro(5) − 2`, que é o delta de nível do Eco;
4. `quantidade = mínimo + inteiro(máximo − mínimo + 1)`;
5. `px = float()` e `py = float()`, a posição dentro da célula.

`uid_i = FNV(seed_global, época, cell_x, cell_y, janela, i, UID_)`.

### Vetores de teste

Os vetores são obrigatórios nos testes do M2:

| Entrada | Resultado |
| --- | --- |
| FNV-1a 64 de `""` | `0xcbf29ce484222325` |
| FNV-1a 64 de `"a"` | `0xaf63dc4c8601ec8c` |
| PCG32 com `srandom(42, 54)` | primeiras saídas `0xa15c02b7`, `0x7b47f409`, `0xba1d3330` (vetor da referência) |
| código `KENOMA-TESTE` | `seed_global = 0x6ebe19ac6345175f` |
| lat −22.9056, lon −47.0608 | tile z20 `(387213, 592857)`, z21 `(774426, 1185714)` |
| essa célula z20 com essa seed | deslocamento 534 |
| `t = 1790000000` | janela 1491667 |
| época 0, índice 0 | `h_0 = 0x90a9f55334e3a1bc` |
| PCG32 com esse `h_0` | primeiras saídas 937126716, 1949151193, 2853980563 |
| época 0, índice 0 | `uid_0 = 0xb15342d5daf75c2d` |

O instante t = 1790000000 (2026-09-21 14:13:20 UTC) é anterior à época 0 e vale só para os vetores de hash e janela. Para testar a seleção de época, use as bordas: 1790035199 não tem época vigente, 1790035200 (2026-09-22 00:00 UTC) é a época 0, e 1797811200 (2026-12-21 00:00 UTC) já marca a época 0 como desatualizada.

Se não há época vigente (relógio antes da primeira), o app usa a primeira época e marca o mundo como desatualizado.

### Registro de coletas

O aparelho guarda cada uid coletado, capturado ou que fugiu. Um uid registrado não aparece de novo. O registro guarda só as últimas 48 horas. Como o uid inclui a janela, um spawn nunca volta depois que a janela passa.

### O que é compartilhado e o que é individual

**Compartilhado entre amigos:**
- se o spawn existe;
- a espécie;
- a posição;
- a quantidade;
- o delta de nível.

**Individual:**
- **Nível do Eco:** é `limitar(nível do Conjurador + delta, 1, 20)`, calculado na primeira vez que o Eco entra no raio de visão. Fica guardado em memória pelo uid e na marcação, se houver.
- **Captura:** é individual, então capturar não remove nada para os outros.

## 4. Criaturas

Três famílias, com duas camadas cada na Fase 0, Fagulha e Eco. Os nomes são provisórios.

| Família | Deus | Bioma | Tipo | Fagulha | Eco |
| --- | --- | --- | --- | --- | --- |
| Soot | Ialprg | Urbano | Fogo | Ember Mote | Sootling, bicho de fuligem com brasa no peito |
| Frond | Peab | Verde | Planta | Seed Mote | Frondling, fronde fractal que anda sobre raízes |
| Rill | Zumvi | Água | Água | Drip Mote | Rillet, gota que reflete outro céu |

Todo bioma sorteia as três famílias, com peso 6 para a nativa e 1 para as outras. Residencial e Vazio usam pesos iguais. Nenhuma espécie é exclusiva de um bioma, para que o jogo funcione em qualquer cidade e para quem não tem acesso a parque ou lago. Vantagens em triângulo: Fogo vence Planta, Planta vence Água e Água vence Fogo.

**`creatures.json`** tem os dados da espécie:
- id;
- nome;
- família;
- tipo;
- habilidade de mapa com as três faixas.

**O save** tem os dados da instância:
- uid;
- espécie;
- nível;
- XP;
- traços, vazios na Fase 0.

O Poder é derivado (base 10 + nível) e não é salvo.

O nível máximo do Eco é 20. Na Fase 0 os Ecos aparecem até o nível 17 (teto 15 do Conjurador + 2), então a faixa 3 das habilidades não é alcançável no teste.

| Eco | Habilidade de mapa | Faixas por nível (1 a 9, 10 a 19, 20) |
| --- | --- | --- |
| Sootling | Aura maior | +5, +8, +12 m |
| Frondling | coleta Fagulhas de mais longe | +10, +15, +20 m |
| Rillet | rastreador vê além da visão | 150, 170, 200 m |

Habilidades iguais no Círculo não se somam: vale a maior.

**Fagulhas** não são criaturas. São coletadas automaticamente ao entrar na Aura e viram Pó de Essência do tipo.

## 5. Sintonia

A captura é um minigame de rádio. Não existe batalha.

### Início

1. Tocar num Eco dentro da Aura, ou num Eco marcado, abre uma folha de preparo. Nela o jogador escolhe o selo entre os que tem, marca opcionalmente um tônico e confirma com **Sintonizar**.
2. Cancelar antes de confirmar não custa nada.
3. Ao confirmar, o selo e o tônico são consumidos e a sintonia começa.

Na Fase 0 todos os Ecos são passivos.

### Marcação

- Tocar e segurar num Eco dentro da Aura prende o sinal dele por 5 minutos, com o nível já calculado.
- A sintonia de um Eco marcado pode ser feita de qualquer lugar, mesmo depois que a janela acabar.
- Máximo de 3 marcações.

### O dial

- O eixo de frequência vai de 0 a 1.
- O sinal da criatura tem frequência `f_t(t)`, e a resistência do tipo mexe **nele**.
- O jogador controla `f_p` girando o dial.
- Está alinhado quando `|f_p − f_t| ≤ tolerância`.
- Alinhado, o progresso sobe 0,2 por segundo. Desalinhado, cai 0,1 por segundo.
- Progresso 1 sela a criatura.
- Tempo máximo de 20 s, ou 25 s com tônico.

Alvos de duração:
- sem resistência: 5 a 8 s;
- com resistência forte: 10 a 15 s.

A sintonia não depende de como o jogador se move.

### Tolerância

A tolerância é o valor do selo multiplicado pelos bônus:

- **Selo:** simples 0,08, reforçado 0,11. O selo de tipo vale como simples, e ×1,4 contra o tipo que ele vence.
- **Círculo:** ×1,1 por criatura do Círculo forte contra o tipo do alvo, até 3.

### Resistência

| Tipo | Padrão | Como ler |
| --- | --- | --- |
| Fogo | picos bruscos que empurram o sinal | a onda tremula e o celular vibra curto antes de cada pico |
| Água | deriva lenta e contínua, como maré | acompanhar suave; vibração longa e ondulada |
| Planta | a tolerância encolhe aos poucos durante a sintonia | precisão importa; pulsos cada vez mais curtos |

A intensidade vai de 0 a 1:

- Níveis 1 a 3 do Conjurador: 0.
- Níveis 4 a 9: 0,3.
- Nível 10 em diante: sobe 0,07 por nível.
- Soma-se 0,02 por nível que o Eco tiver acima do Conjurador.
- O resultado é limitado entre 0 e 1.

Mesmo sem resistência, cada tipo tem uma vibração de identidade no início da sintonia. Usar o pacote `vibration`, porque o `HapticFeedback` não faz padrão.

### Resultado

**Sucesso:**
- a criatura vai para a coleção;
- o bestiário marca a espécie como capturada;
- a sintonia rende 1 ou 2 de Ectoplasma;
- cada criatura do Círculo ganha 10 XP.

**Falha:**
- o selo já foi consumido;
- a criatura foge com 50% de chance, e a fuga entra no registro;
- se não fugir, dá para tentar de novo.

### Tela

- No alto, a criatura, com as costuras violeta pulsando.
- No meio, duas ondas: a da criatura em **ciano** (o sinal) e a do jogador em **violeta** (o Véu).
- Embaixo, o dial circular com marcas de frequência e glifos em forma de traço de osciloscópio.
- Um anel de progresso em volta da criatura.
- Indicadores do selo e do tempo.
- Nenhum botão de ataque.

Referência visual em `docs/referencias-de-arte.md`, tela Sintonia.

## 6. Círculo

- 3 espaços ativos. O resto fica na coleção, sem limite na Fase 0.
- Cada criatura ativa aplica a própria habilidade de mapa.
- Criaturas no Círculo ganham 10 XP por sintonia concluída.
- Para ir do nível n ao n+1 a criatura precisa de 30 × n de XP.

## 7. Materiais, crafting e destilação

### Materiais

| Material | Origem |
| --- | --- |
| Sucata, Giz | ponto de material em célula Urbana ou Residencial |
| Ervas | ponto de material em célula Verde ou Residencial |
| Água pura | ponto de material em célula de Água |
| Ectoplasma | toda sintonia concluída |
| Pó de Essência de Fogo, Planta, Água | Fagulhas |
| Essência de Fogo, Planta, Água | destilação de Ecos |

Pontos de material são tocados dentro da Aura. Sucata não entra em nenhuma receita da Fase 0; ela é coletada para já existir no save quando os gadgets chegarem.

### Receitas

Todas são improviso: feitas em qualquer lugar e conhecidas desde o início.

| Receita | Ingredientes | Efeito |
| --- | --- | --- |
| Selo simples | Giz + Ectoplasma | tolerância 0,08 |
| Selo reforçado | Selo simples + 2 Essência de qualquer tipo, misturadas ou não | tolerância 0,11 |
| Selo de Fogo, de Planta, de Água | Selo simples + 3 Pó de Essência do tipo | ×1,4 contra o tipo que ele vence |
| Tônico de foco | Ervas + Água pura | +5 s na sintonia em que for usado |

### Destilação

- Improviso, feito em qualquer lugar.
- Um Eco da coleção vira Essência do tipo: 3 do nível 1 ao 7, 4 do 8 ao 14 e 5 do 15 ao 20.
- A criatura sai da coleção.
- Ecos no Círculo não podem ser destilados.

### Início

O jogador começa com 5 Selos simples e 3 Giz.

## 8. Conjurador

- Sem talentos, escolas, magias, Familiar nem história.
- Para ir do nível n ao n+1 são necessários `60 × n^1,25` de XP, arredondado para dezenas. O teto na Fase 0 é o nível 15. XP além do teto fica guardado para quando o teto subir.

**Fontes de XP:**
- sintonia: 20 + 2 × nível do Eco, com teto de 60;
- primeira captura de cada espécie: 100;
- Fagulha: 2;
- ponto de material: 5.

**Descanso.** Até 350 de XP bruto por dia rendem o dobro. O que não for usado num dia acumula, até 1050. O dia é o dia local do aparelho, porque isso não afeta o mundo.

## 9. Telas

- **Mapa.** Tem três elementos:
  - o botão do celular no centro, embaixo;
  - o retrato com o nível à esquerda;
  - o rastreador à direita.
- **Folha de preparo** e **Sintonia.**
- **Celular aberto**, com os apps Bolsa, Círculo, Bestiário, Bancada e Ajustes.
- **Bolsa:** materiais e itens.
- **Círculo:** os 3 ativos e a coleção.
- **Bestiário básico:** vista e capturada por espécie.
- **Bancada:** as abas Fabricar e Destilar.
- **Ajustes:**
  - código do grupo: ver, digitar, mostrar em QR, escanear QR;
  - exportar e importar backup;
  - época atual e aviso de mundo desatualizado.

Trocar o código do grupo limpa o registro de coletas e as marcações, e mantém a coleção.

Referências visuais em `docs/referencias-de-arte.md`.

## 10. Save

### Arquivo

O arquivo tem três partes:

1. o magic `KSV1`, com 4 bytes;
2. o SHA-256 do payload, com 32 bytes;
3. o payload, que é o JSON em gzip.

### Cabeçalho do JSON

`schema_version`, `app_version`, `epoch`, `group_code`, `created_utc`, `saved_utc`, `last_seen_utc`.

### Conteúdo do JSON

- Conjurador: nível, XP, XP guardado além do teto e saldo de descanso.
- Coleção de criaturas.
- Círculo.
- Inventário por id de item.
- Bestiário.
- Marcações ativas.
- Registro de coletas por uid, com o horário.

### Regras

1. IDs estáveis em texto, nunca índices.
2. Cada `schema_version` tem uma migração pura e testada para a seguinte. Campos desconhecidos são preservados.
3. A escrita é atômica: grava num temporário e renomeia. O app mantém os 3 últimos saves em rodízio. Se o checksum não bater, carrega o anterior.
4. O app salva a cada evento relevante.
5. Se o relógio voltar para antes de `last_seen_utc`, o app usa `last_seen_utc`.
6. O backup é exportado pela folha de compartilhamento do sistema, que permite mandar para o Google Drive, e importado por seletor de arquivo.

## Fora do escopo

- **Personagem e história:**
  - Familiar;
  - tutorial com mentor e fórum;
  - escolas, talentos, magias, build;
  - história.
- **Captura avançada:**
  - ritual, vínculo, fusão, estabilidade;
  - Espíritos e camadas acima;
  - comportamentos de criatura;
  - variantes;
  - Constelações;
  - minigames extras.
- **Casa e crafting avançado:**
  - casa, Bolsa limitada, Armazém;
  - lures, expedições, invasões;
  - descoberta de receitas, coletores, qualidade de material;
  - estações, grandes obras.
- **Mundo:**
  - Fendas, Soberanos, incursões, Aethyrs;
  - Exposição ao Véu;
  - névoa de guerra, Ley Lines, rastros e scanner;
  - clima, astronomia, horários especiais, eventos;
  - prédios com altura, rotação de câmera.
- **Conteúdo e serviços:**
  - marcas, rumores, quests;
  - chat, Mercador;
  - notificações, contador de passos, trilha adaptativa;
  - social, anti-cheat, tempo do GNSS.
- **Outros:**
  - tipos além de Fogo, Planta e Água;
  - batalha;
  - iOS e web.
