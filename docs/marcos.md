# Marcos da Fase 0

Um marco por vez. Cada marco termina com algo que roda e pode ser verificado sozinho. Não avance sem cumprir o critério de pronto.

O protótipo da sintonia vem cedo, no M3, porque é o primeiro teste de diversão do projeto. Se o dial não for divertido sozinho, nada do resto importa, e o plano B de batalha do GDD entra em discussão antes de construir o mapa.

## M0 · Estrutura

Criar o repositório com a estrutura do CLAUDE.md e o projeto Flutter vazio rodando. Copiar os arquivos de `docs/dados-iniciais/` para os lugares indicados no CLAUDE.md. Criar `pipeline/requirements.txt`, `scripts/sync_shared.sh` e o teste que confere que as duas cópias de `biomes.json` são iguais.

**Pronto quando** `flutter run` abre uma tela vazia e `flutter test` passa, incluindo o teste de `biomes.json`.

## M1 · Pipeline de região

Script `pipeline/build_region.py` que:

- lê a região em `pipeline/regions.json` e as regras de `shared/biomes.json`;
- baixa ou lê o extrato da Geofabrik e recorta pela bbox;
- aplica os buffers em projeção métrica e rasteriza na grade zoom 21, respeitando as prioridades;
- gera `campinas_e0.bin` no formato da spec;
- gera `campinas_preview.png`, com uma cor por bioma;
- imprime o SHA-256 do `.bin`, que vai para a época 0 em `epochs.json`.

**Pronto quando:**
- o preview, comparado a um mapa real, mostra parques, lagos e ruas nos lugares certos;
- bairros residenciais aparecem como Residencial ou Vazio, e não como Urbano;
- o `.bin` tem poucos MB.

É o marco de maior risco técnico. Se o resultado ficar ruim, ajustar buffers e prioridades aqui antes de seguir.

## M2 · Núcleo determinístico

Em `app/lib/core/`, em Dart puro:

- FNV-1a 64 com serialização de campos;
- PCG32;
- conversão de lat/lon para tile em qualquer zoom;
- janela com deslocamento por célula;
- leitura de `epochs.json` e escolha da época vigente;
- geração de uid.

- geração dos 4 itens de uma célula com os sorteios na ordem da spec.

**Pronto quando:**
- todos os vetores de teste da seção 3 da spec passam;
- um teste confirma que células vizinhas trocam de janela em momentos diferentes;
- um teste confirma que o bioma de uma célula z20 com empate sai pela maior prioridade.

## M3 · Protótipo da sintonia

Tela de sintonia isolada, sem mapa. Um menu de debug escolhe a espécie, o nível, o selo e o nível do Conjurador.

- A lógica fica em `capture/`, com testes unitários, e a renderização fica separada.
- Inclui dial, duas ondas, tolerância, progresso e tempo.
- Inclui os padrões de resistência de Fogo, Planta e Água.
- Inclui a vibração que marca os momentos da resistência de cada tipo (aviso de pico do Fogo, virada da maré da Água, broto da Planta), com o pacote `vibration`.
- Inclui o resultado de sucesso ou falha.

**Pronto quando:**
- uma sintonia sem resistência leva de 5 a 8 segundos;
- com resistência forte leva de 10 a 15 segundos, dentro do teto de 20;
- a vibração marca os momentos da resistência, sem precisar identificar o tipo sozinha;
- os testes cobrem tolerância, progresso e cada padrão.

Jogar o protótipo por alguns dias antes de seguir. Se não divertir, parar e rever o design.

**Status: concluído.** A calibração da sintonia continua em paralelo, pelo menu de debug e, a partir do M7, pelos dados de jogo real.

## M4 · Mapa estático

App carrega `campinas.bin` e renderiza a grade em Flame em torno de uma coordenada fixa, com câmera arrastável.

**Pronto quando:**
- a área renderizada bate com o preview do M1;
- a navegação roda fluida no celular.

**Status: implementado e medido no celular.** Arrastar roda sem quadro acima de 16,7 ms, e o zoom em estresse passa de 16,7 ms em ~3% dos quadros (`docs/m4/README.md`). O pacote `campinas_e0.bin` é carregado e o SHA-256 conferido contra a época vigente (erro claro na tela se não bate). `world/` consulta bioma por célula z21, por célula z20 e por lat/lon e calcula as células visíveis. O mapa é desenhado em Flame com texturas provisórias por bioma (paleta em `shared/biomes.json`) e cache por chunk. O menu de debug abre o mapa em qualquer coordenada (padrão Unicamp) e mostra, sob o dedo, a coordenada, as células z20 e z21 e os biomas. Todas as células do `.bin` batem com o preview do M1 (`test/data/region_preview_test.dart`). As capturas do aparelho estão em `docs/m4/`.

## M5 · GPS e simulador

Posição real via `geolocator`, marcador do jogador e círculo da Aura.

Simulador de GPS de debug com:
- joystick;
- teleporte;
- override do relógio UTC.

**Pronto quando:**
- andar com o celular move o marcador;
- o simulador permite testar tudo sentado.

**Status: implementado, falta testar andando na rua.** A posição vem de uma `PositionSource` trocável (`geolocator` ou o simulador do menu de debug), filtrada por `GpsFilter` (recusa precisão pior que 50 m e não deixa o marcador tremer parado). O mapa do jogo (`GameMapScreen`) segue o Conjurador com suavização, desenha o marcador e a Aura (raio de `balance.json`), espia ao arrastar e volta sozinho depois de 3 s, com zoom de 8 a 24 px por célula. A câmera livre do M4 ficou só no menu de debug. O simulador (joystick com andando, correndo e bicicleta, teleporte com atalhos, ruído de GPS opcional) e o override do relógio UTC estão no menu de debug. O GPS real não foi testado andando: só dá para confirmar o fluxo de permissão e a fonte.

## M5b · Camada visual

**Posição na fila: entre o M5 e o M6.**

Camada só de desenho para o mapa de jogo. **A grade de biomas continua sendo a única camada lógica:** spawns, coleta, Aura e o hash do mundo leem só a grade, e nada que for desenhado aqui entra em regra de jogo.

- **Pacote visual** `campinas_e0_vis.bin` (`pipeline/build_visual.py`): ruas por classe (principal, secundária, local, pedestre), água e áreas verdes como polígonos simplificados a 2 m, por tile z15, com coordenadas quantizadas, deltas e varint, em gzip. O SHA-256 fica na época 0, em `visual_packs`, em campo separado do pacote lógico. Formato na spec.
- **Mapa em pixels de arte.** O mundo é desenhado em chunks de baixa resolução, com o pixel de arte de tamanho fixo em metros, e ampliado por vizinho mais próximo. No zoom padrão (90 m) a ampliação é inteira em pixels físicos. O ruído do chão também é em pixels de arte.
- **Camadas:** chão neutro; verde e água com borda de 1 pixel de arte; calçada de 1 pixel de arte em tom mais claro; ruas com a largura da classe em metros; Aura; Fagulhas e materiais; Ecos e Conjurador. Cores de `biomes.json`.
- **A grade de biomas** e a grade z20 viraram sobreposição opcional no menu de debug.
- **Conjurador** com sprite placeholder de 48 × 48, feito por matriz de caracteres como os Ecos: figura de capuz escuro, celular com brilho ciano, contorno #1a1424.
- **Lógica em `world/`** (`visual_map.dart`): geometrias por tile com cache, e só os chunks visíveis são desenhados.

- **Escala dos sprites e movimento (0.10.0):** Conjurador e Ecos em metros do mundo (12 m), Fagulhas e materiais com 3 m, zoom de 70 a 120 m; o marcador anda pelo caminho do GPS com cerca de 1 s de atraso, descarta saltos acima de 12 m/s, anima o passo e olha para o lado em que anda.
- **Câmera (0.9.0):** o pixel de arte passou a ter tamanho fixo de tela (3 dp), rasterizado a cada quadro, e o mapa gira livremente com dois dedos em torno do Conjurador, com bússola (toque: norte; duplo toque: seguir direção). Sprites com tamanho fixo de tela; só a Aura fica em metros.

**Status: feito.** Capturas na Unicamp, no centro e no Taquaral em `docs/m5b/`, com o tamanho do arquivo e as contagens. O pacote de ruas continua sendo fonte da época: como o `.bin` lógico, só se regenera numa época nova. **Falta medir o fps** (ver `docs/m5b/README.md`).

## M6 · Spawns e coleta

- Spawns determinísticos por célula, janela e época.
- Ecos visíveis até 120 m.
- Fagulhas coletadas ao entrar na Aura, virando Pó de Essência.
- Pontos de material tocáveis.
- Inventário básico.
- Registro de coletas por uid, limpo depois de 48 horas.

**Pronto quando:**
- dois aparelhos, ou dois emuladores, com a mesma seed mostram os mesmos spawns no mesmo lugar e hora;
- o que foi coletado não reaparece;
- o entorno se renova aos poucos, e não tudo de uma vez.

**Status: implementado (fatia M6 + M7), falta jogar na rua.** `SpawnField` (`world/`) gera Ecos, Fagulhas e pontos de material por célula z20, janela e época, até 120 m, com o nível do Eco guardado pelo uid. `WorldView` coleta as Fagulhas ao entrar na Aura, coleta material por toque dentro da Aura e abre o encontro ao tocar num Eco dentro dela. O registro de coletados (uid, 48 h) vive no `GameState`, salvo num JSON local (`save.json`, escrita atômica); o formato completo do save continua sendo o M10. Ficou de fora: Pó de Essência virando XP, a habilidade de coleta do Frondling (M8) e o rastreador.

## M7 · Encontro completo

- Tocar num Eco dentro da Aura abre a folha de preparo (escolha de selo e tônico) e depois a sintonia do M3 com aquele Eco.
- Sucesso adiciona a criatura à coleção, dá Ectoplasma e atualiza o bestiário.
- Falha perde o selo já consumido e pode fazer a criatura fugir; a fuga entra no registro.
- Marcação por toque longo, com duração e limite.

**Pronto quando** o ciclo andar, encontrar, sintonizar, capturar e voltar ao mapa funciona sem intervenção de debug, inclusive sintonizando um Eco marcado depois de sair da célula.

**Status: feito (0.11.0), falta jogar na rua.** Tocar num Eco na Aura abre a folha de selo (com os selos e o tônico que o jogador tem) e depois a sintonia do M3 (sem gravar `sessions.csv`). Sucesso põe a criatura na coleção, dá Ectoplasma, XP e atualiza o bestiário; falha gasta o selo e a criatura foge com a chance da spec, e a fuga entra no registro. **Marcação:** toque longo (500 ms parado) num Eco dentro da Aura prende o sinal por 300 s, no máximo 3; fica numa ficha com contagem regressiva e abre o encontro de qualquer distância. Arrastar cancela o toque longo. Na quarta marcação o app avisa; toque longo num Eco já marcado solta. A marcação vai no `save.json`.

## M8 · Círculo e bestiário

- Três espaços ativos.
- Habilidades de mapa por faixa de nível: Aura maior, alcance de coleta e alcance do rastreador.
- Bônus de tolerância por tipo forte.
- XP das criaturas no Círculo.
- Bestiário com vista e capturada.

**Pronto quando:**
- trocar o Círculo muda de forma visível a Aura, a coleta ou o rastreador;
- levar um tipo forte deixa a sintonia perceptivelmente mais fácil.

**Status: feito (0.11.0), falta jogar na rua.** O botão do celular, no centro de baixo do mapa, abre o menu com Coleção, Círculo, Bestiário e Bancada. O Círculo tem 3 espaços escolhidos da coleção; as habilidades somam por tipo e valem a maior (Sootling: Aura +5/+8/+12 m; Frondling: coleta +10/+15/+20 m, que vale para Fagulhas e materiais; Rillet: rastreador 150/170/200 m, que também alarga a área de spawns gerada). Cada criatura do Círculo forte contra o tipo do alvo dá ×1,1 de tolerância, até 3. Criaturas no Círculo ganham 10 XP por sintonia concluída (30 × n por nível, até o 20). O bestiário mostra vista e capturada, com silhueta para o que não foi visto. Lógica em `player/circle.dart`.

## M9 · Bancada e destilação

Bancada com as quatro receitas: selo simples, selo reforçado, selos de tipo e tônico. Destilação de Ecos em Essência.

**Pronto quando:**
- dá para sustentar capturas só com selos fabricados a partir do que se coleta andando;
- destilar um Eco repetido para fazer um selo melhor parece uma boa troca.

**Status: feito (0.11.0), falta jogar na rua.** A Bancada tem as abas Fabricar (as seis receitas: selo simples, reforçado, três selos de tipo e tônico; o reforçado gasta 2 Essências de qualquer tipo, da pilha maior primeiro) e Destilar (Eco vira 3, 4 ou 5 Essências do tipo conforme o nível, com confirmação; Ecos no Círculo não saem). Lógica em `crafting/crafting.dart`. O botão de fabricar na Coleção saiu.

## M10 · Progressão, save e seed

- XP do Conjurador pela curva da spec, com nível máximo 15 e bônus de descanso.
- Save no formato da spec (`KSV1`, SHA-256 e JSON em gzip), versionado, com escrita atômica, rodízio de 3 e migrações.
- Exportar e importar backup.
- Tela de Ajustes com o código do grupo, QR para mostrar e escanear, e a época atual com o aviso de mundo desatualizado.

**Status: feito (0.12.0), falta jogar na rua.**
- **XP e nível (0.11.0):** curva da spec (60 × n^1,25 em dezenas, teto 15, XP além do teto guardado) com o bônus de descanso (350 por dia local rendem o dobro, acumula até 1050); XP de sintonia concluída (20 + 2 × nível do Eco, máx. 60), de primeira captura (100), de Fagulha (2) e de material (5). O nível real manda no nível dos Ecos e na resistência, e o seletor do debug (0 = real) é um override. Retrato com o nível e a barra de XP no canto de baixo à esquerda.
- **Save no formato final (0.12.0):** `save.ksv` com o magic `KSV1`, o SHA-256 do payload e o JSON em gzip (`save/ksv1.dart`). A escrita é atômica: grava um temporário, confere que lê de volta e só então gira as cópias com `rename` (`save.ksv`, `.1` e `.2`; uma cópia corrompida nunca empurra uma boa para fora). Se a mais recente não passa no checksum, carrega a anterior e avisa no mapa. O `save.json` antigo é lido uma vez, migrado e guardado como `save.json.migrated`: nada se apaga. Schema 2 com o cabeçalho da spec (`app_version`, `epoch`, `created_utc`, `saved_utc`, `last_seen_utc`); campos desconhecidos são preservados. Se o relógio do aparelho voltar para antes de `last_seen_utc`, o jogo usa `last_seen_utc` (o override do debug passa por cima e não empurra o `last_seen`).
- **Registro de fundador (só a coleta):** `player_id` de 128 bits do gerador seguro do sistema, gerado no primeiro uso; `first_install_version` e `first_seen_utc`; log `versions_seen`, uma linha por versão aberta, encadeado por SHA-256 (cada linha guarda o hash da anterior; mudar ou apagar uma linha quebra a cadeia). Sem assinatura ainda. Segue a seção "Assinaturas, fundadores e controles" do GDD só no que é coleta; ficam para a fase das assinaturas: o QR de Ajustes com `player_id` e log, o certificado de fundador, a chave Ed25519, a verificação de épocas e a lista de revogação.
- **Backup:** Ajustes > Exportar backup (folha de compartilhamento, o mesmo arquivo KSV1) e Importar backup (seletor de arquivos); importar confere o arquivo, mostra nível, criaturas, data, grupo e versão, e só substitui o jogo depois da confirmação.
- **Grupo:** código com QR (`kenoma:group:CODIGO`) e leitura por câmera; digitar também serve; trocar de grupo pede confirmação, limpa o registro de coletas e as marcações e mantém coleção, Círculo, bolsa e nível.
- **Ajustes:** grupo e QR, época atual com o aviso de mundo desatualizado, versão e `player_id` com botão de copiar, interruptores do mapa (**nomes de rua: só o interruptor, sem efeito**; **seguir direção**), backup.
- **Menu de debug na release:** continua a primeira tela de toda build, sem flag, com a seção nova de identidade (`player_id`, log de versões com a conferência da cadeia, época e cabeçalho do save).
- **Nomes de rua: pulado.** O `build_visual.py` não lê a tag `name` hoje; incluí-los pede mudar o formato do pacote visual, regenerá-lo com o extrato de 4,5 GB (novo SHA em `epochs.json`) e desenhar texto ao longo das ruas. É mais que um trabalho pequeno. Para fazer: ler `name` das vias principais no `build_visual.py`, gravar os nomes no `_vis.bin`, e desenhar o rótulo rente à via em `ArtRenderer`, ligado a `settings.street_names`.

**Pronto quando:**
- fechar e reabrir o app preserva tudo;
- um backup exportado e importado noutro aparelho restaura o jogo;
- dois amigos que escaneiam o mesmo QR veem o mesmo mundo.

## M11 · Build de teste

APK de release, ajuste inicial de `balance.json` jogando na rua e lista dos problemas encontrados.

**Pronto quando** começa o teste de duas semanas. Anotar diariamente:
- o que foi divertido e o que foi chato;
- quantos Ecos apareceram por caminhada;
- se a sintonia continua gostosa depois de dezenas de capturas.

O resultado decide se o jogo avança para a Fase 1 ou se o Núcleo precisa mudar.

**Status: build pronta (0.12.0+18), teste não começou.** O APK é assinado com a chave de release própria, guardada fora do repositório em `~/.kenoma-signing/` (onde fica, como conferir e como fazer o backup dela: `docs/assinatura.md`). O texto para os amigos está em `docs/beta.md`. Como a 0.11 foi assinada com a chave de debug, o celular de teste precisou desinstalar o app para receber a 0.12 (o save de teste de lá foi perdido); a partir daqui toda atualização instala por cima. **Falta:** guardar as duas cópias do keystore (ver `docs/assinatura.md`), mandar o APK e o QR aos amigos, e jogar na rua para o ajuste de `balance.json`. A permissão `INTERNET` do manifesto fica de propósito, para as próximas fases (registrado em `docs/assinatura.md`).

## Fase 1 · primeira fatia

Segue o `docs/GDD.md` (Mapa vivo, O mentor, Quests, Tempo). Versão 0.13.0. Salvo dito o contrário, tudo é só visual ou de conteúdo e **não muda o mundo**: não precisa de época nova.

- **Nomes de rua.** O `build_visual.py` agora lê `name` e `oneway`: pacote visual **versão 2** (cada linha leva o sentido e, nas principais e secundárias, o nome; 3,13 MB, mesmo extrato da época 0, MD5 `d4778499…`). O leitor do app aceita a versão 1 e a 2. SHA-256 novo nas épocas 0 e 1 de `epochs.json` (`e8491fa2…`). O interruptor dos Ajustes liga rótulos discretos no trecho mais reto de cada rua principal, que giram com o mapa e nunca ficam de cabeça para baixo.
- **Dia e noite.** `core/astro.dart`: a luz do mapa segue a altura real do sol (posição solar offline, erro abaixo de 0,02°), com amanhecer e anoitecer suaves; o tom quente aparece com o sol baixo. A fase da lua (fase média) está no HUD, espelhada no hemisfério sul. Testado contra o nascer e o pôr do sol de Campinas em 21/12 (05:23 e 18:47) e contra as luas de setembro e outubro de 2026.
- **Tráfego do Véu.** `world/veil_traffic.dart`: carros e pedestres fantasmas, gerados por seed, rua e janela de 20 min, com a mão única do OSM e a mão de direção (pela direita), com densidade pela hora real do lugar. Interruptor nos Ajustes (ligado). Teto de 160 por quadro. **O fps não foi medido no aparelho.** Ficam para depois: semáforos, ônibus, vans e os veículos especiais da tabela do GDD.
- **Chat com o mentor** e **diárias do fórum:** ver a seção 11 da spec. Os textos para revisão estão em `docs/textos-mentor.md`.
- **Avisos no celular:** opcionais e desligados por padrão (seção 11 da spec).
- **Save schema 3** com migração v2 → v3 testada. Toda versão daqui em diante sai assinada com a mesma chave (`docs/assinatura.md`).

## Fase 1 · fatia 2 · Rua viva (0.14.0)

Segue o `docs/GDD.md`; os detalhes e as divergências estão na seção 12 da spec. **A época 2 muda o mundo** (comportamento, variantes, Brilhante, clima nos spawns): ela começa no release. Tudo o resto é visual ou de conteúdo.

- **Época 2 e fluxo v2.** Sorteios novos num fluxo separado; impressões digitais da 0.13.0 travadas em teste. Os pesos e as chances vivem em `epochs.json`, não no `balance.json` como o pedido dizia: regra 8.
- **Comportamentos.** Arisco foge por velocidade média na entrada da Aura; Agressivo abre a folha; Oculto só pelo Radar. Ícone sobre o Eco e na folha de preparo.
- **Variantes e Brilhante.** Paleta por tom sobre a silhueta, halo e som no Brilhante, Essência de Traço e Prismática ao destilar, bestiário por variante.
- **Radar e rastros** (níveis 1 e 2). **Névoa de guerra** em blocos z17 de 64 bits. **Clima** determinístico e opcional pela rede (só visual), com HUD e chuva. **Familiar** companheiro com +5 m de coleta e três falas.
- **Escala dos sprites.** Pixel de arte de 2 dp; Conjurador e Familiar 8 m, Ecos 9 m, fantasmas 6 m e 7 m; sprites redesenhados em 20 × 20 e 18 × 18, sem filtro.
- **Save schema 4**, migração v3 → v4 testada com um save real da 0.13.0.
- **Release.** Época 2 começa em 2026-10-16T04:40:00Z. APK assinado com a mesma chave (SHA-256 a5ee03b0…). Instalação por cima da 0.13.0 e conferência no aparelho **pendentes**: o celular não estava conectado por adb. Até lá, o que passou só em teste: Arisco, Oculto, variantes, névoa, clima, escala dos sprites e o save v3 → v4.
