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

## Fase 1 · fatia 2a · Escala, Aura e densidade (0.13.1)

Vem antes da Rua viva (0.14.0). Especificação na seção 13 da spec e em `docs/densidade-epoca2.md`.

- Aura de 10 m só para coleta, alcance de toque de 30 m para Ecos, um raio só para lógica e desenho, lógica na posição suavizada. Sprites menores.
- Época 2 com a densidade nova e itens sobre os caminhos; a Rua viva passa para a época 3.
- Retorno visual de toque em menos de 100 ms (efeitos de coleta, pulo, costura e fuga).
- A 0.13.1 sai com a Rua viva escondida (`STREET_LIFE=false`): névoa, Radar, clima no HUD, chuva e Familiar só aparecem na 0.14.0.
- Ajustes depois do teste na rua: câmera de 40 a 80 m (50 m no padrão) e pixel de arte de 3 dp; anel do alcance de toque e contorno violeta; densidade por rota com rodovias fora do caminho; Arisco pelo GPS cru; Tráfego do Véu refeito (calçadas, entradas fora da tela, modelos e paletas).

## Fase 1 · fatia 3 · Progressão, celular e perfil (0.15.0)

Spec na seção 14 de `docs/fase0-spec.md`. **A época 4 muda o mundo** (Espíritos e Espíritos de ritual raros, itens 9 e 10); o resto é cliente.

- **Níveis até 20**, curva 60 × n^1,25 (21.290 XP do 1 ao 20), um ponto de talento por nível (só acumulam), Aura +1 m nos níveis 10 e 20. **Save schema 5**, migração v4 → v5 testada num save gravado pelo código da 0.14.0.
- **Escola no nível 3:** três testes (sinal, calma, sigilo), escolha definitiva até o nível 30, bônus de captura por escola e Familiar com a cor e o acessório da escola.
- **Fusão no nível 6** (5 Ecos + Essência viram o Espírito), **Espíritos no mapa no nível 8**, atributos Poder, Habilidade e Traços na Coleção.
- **Ritual básico no nível 8**, três espécies só de ritual, espaços revelados pela pesquisa.
- **Perfil** (retrato do HUD ou app), **celular redesenhado** (tema do Design System, apps bloqueados por nível, bolinhas de novidade), **menu de debug reorganizado** (busca, favoritos, seções).
- **Conectividade leve:** épocas e eventos assinados (Ed25519), backup automático do Android, contador de passos e modo bolso, tudo opcional.
- **Ficou de fora:** árvores de talento, troca de escola, estabilidade, fase de pressão do ritual, publicação no GitHub Pages (os arquivos assinados estão em `docs/pages/`; nada foi publicado).

## Fase 1 · fatia 3a · Mapa fora de Campinas e atalho para Uber e 99 (0.15.1)

**A época 5 muda o mundo** (início 2026-11-09T16:20:00Z): acrescenta os pacotes de São Paulo com SHA fixado. Campinas usa os mesmos pacotes, mas o número da época entra no hash, então os spawns mudam para quem atualiza.

- **Três camadas por bloco de 1 km** (`world/layered_world.dart`): pacote de região, fallback Overpass, piso sem dados. O jogador nunca vê tela vazia. Teste de que Campinas fica idêntica com o mundo em camadas.
- **Pacote de São Paulo** (município inteiro, 11,99 MB, fora do APK): lista assinada em `docs/pages/regions.json`, baixa ao entrar na bbox ou pelo botão "Baixar região" nos Ajustes, aviso de tamanho acima de 10 MB, confere assinatura e SHA. **Não publicado:** comando em `docs/assinatura.md`.
- **Fallback Overpass** (`world/fallback/`, `world/fallback_service.dart`): consulta só o bloco e os vizinhos na direção do movimento, `date` fixado no início da época, uma consulta por bloco, espera entre consultas, servidores alternativos, nada acima de 30 km/h, cache por bloco. Selo "Véu instável" no HUD. **Oráculo:** diferença zero na grade lógica em 10 blocos commitados (8 de Campinas, 2 de São Paulo). Fora do repositório, zero em todos os 1.295 blocos inteiros de Campinas e 2.730 de São Paulo, e zero numa consulta real à Overpass. Limite conhecido: polígono cuja borda fique a mais de 0,25° ao norte do bloco é invisível para ele.
- **Piso sem dados:** tom da cidade, grade fraca, spawns pelo sorteio geral, fala do Familiar na primeira vez, refeito sem reiniciar quando a internet volta.
- **Modo Viagem mínimo** (`lib/travel/`), que não existia: destino por toque ou busca (Nominatim), veículo, rota A* sobre o grafo de ruas, a pé e de bicicleta fora de rodovia, Rádio do Véu em texto, baú na chegada com teto diário. Passageiro é perguntado por viagem. **Motorista: viagem só gravada, sem baú.** O GDD diz "com tudo entregue na chegada" e o pedido diz "nunca recompensa dirigir"; ficou a segunda leitura.
- **Atalhos:** "Chamar Uber" pelo deep link oficial com destino, "Chamar 99" pelo pacote com o destino copiado, só para apps instalados. Viagem por esses botões já é passageiro, sem recompensa extra.
- **Corrida no mapa:** carro do Véu chegando pela rota com o tempo estimado, embarque, GPS em viagem, desembarque e baú. Leitura opcional de notificações só do Uber e do 99, com interruptor próprio; padrões em `assets/data/ride_patterns.json`. **Os padrões ainda são sintéticos**, sem amostra de corrida real; sem reconhecer, cai para os botões.
- Sem mudança no schema do save (fica em 5). Rádio do Véu sem áudio novo.
- **Conferido no moto g54 (2026-11-09, GPS simulado):** instalação por cima da 0.15.0; Paulista sem internet e sem pacote = piso; São Paulo baixado pelo botão dos Ajustes (aviso de 11,4 MB, "Pronta") a partir de um feed local assinado, sem publicar; Paulista com o pacote, com e sem internet; Bandeirantes e Jundiaí sem internet = piso e, com internet, o bloco da Overpass chegou em ~100 s e ~2 min sem reiniciar, com o selo "Véu instável"; fala do Familiar no piso. **Não visto no aparelho:** Uber, 99 e corrida (sem corrida real), Modo Viagem andando.
- **Corrigido no teste:** `overpass.private.coffee` respondia à consulta com data usando uma base de 2026-05-31, e o mundo de quem caísse nele sairia diferente do dos amigos. Agora a resposta com `timestamp_osm_base` anterior à data da época é recusada e o próximo servidor é tentado.


## Fase 1 · fatia 4 · Clima, passos, Patrulha do Véu e recomeço (0.16.0)

- **Névoa de guerra removida** (foi para as ideias descartadas). Saíram do app o véu do mapa (`ui/game/fog_painter.dart`), a lógica (`world/fog.dart`), o contador de área nos Ajustes e no Perfil, os itens "Revelar névoa" e "Névoa de debug" do menu e o bloco `fog` do `balance.json`. O código continua na história do git (até 162ae36).
- **Células visitadas.** O jogo continua registrando, sem nada visual, as células z17 (~280 m) por onde o jogador passa de verdade: `GameState.markVisited(x, y)` e `GameState.visitedCells`, gravadas em `celulas_visitadas` (pares z17). O simulador e quem dirige não contam. As expedições da fase 2 vão usar.
- **Save schema 6**, migração v5 → v6 testada num save gravado pelo código da 0.15.0 (`test/fixtures/save_v5_0150.json`): os blocos z17 não vazios de `fog.cells` viram `celulas_visitadas`, o conjunto `fog.debug` (simulador) não entra e o `fog` sai.
- **Recomeçar do zero** (Ajustes, no fim): apaga o progresso, o rodízio do save, o diário da Patrulha e os caches da lista em `save/fresh_start.dart`; mantém `player_id`, primeira versão, log de versões (com a linha `recomeço`), certificados, grupo e Ajustes do aparelho. Pede um backup novo ao Android (`BackupManager.dataChanged`). **Falta:** testar a reinstalação com Auto Backup no aparelho.
- **Criar criatura** no menu de debug (Spawns): nasce na Aura, fora do mundo determinístico, por 20 minutos; marcada como debug no save e na Coleção, não conta para bestiário nem estatísticas.
- **Clima completo** (época 6 em diante, `core/climate.dart`, `world/climate_world.dart`): os 36 climas do GDD (14 nativos, 9 de outras regiões, 13 místicos) feitos de 7 peças (ponto de impacto, zona temporária, coletável do céu, modificador do jogador, movimento, rastros, sobreposição fantasma). **O que muda o mundo mora no bloco `climate` da época** (sorteio por mês e faixa de hora local, multiplicadores, parâmetros das peças); `assets/data/clima.json` é só visual e textos; `balance.json` tem o que vale por aparelho (limite de partículas, clarão, bolso). Sorteio normal só com nativos e estações de Campinas; outras regiões e místicos só por `events.json` assinado (entrada `kind: climate`) ou debug. Open-Meteo continua só visual e mapeia só para nativos. Épocas 0 a 5 travadas por impressão digital.
- **Faixa sem chuva corrigida.** A causa não era a câmera: as gotas derivam 0,28 px para a esquerda por px de queda e renasciam só até `largura + 60`, então o canto inferior direito ficava seco. O desenho novo (`ui/game/climate_painter.dart`) nasce partículas nas bordas por onde elas entram; teste em 4 proporções, 6 ângulos e numa volta de 360° com zoom de 40 e 80 m.
- **Raios:** um por célula z17 e janela, a cada 20 a 60 s, mesmo ponto para todos. Quem está a menos de 15 m não vê nem ouve aquele raio (o ponto continua sendo do mundo). Traço, clarão de 120 ms, trovão com atraso pela distância (`ToneGenerator`, provisório), poeira, faíscas e marca de 60 s. **Provisório:** o "Eco Elétrico" do raio é um Sootling com a marca `charged` ("Eco carregado", ciano), porque ainda não há espécie Elétrica; o dado já pede o tipo `electric` e troca sozinho quando ela existir.
- **Reduzir clarões** nos Ajustes: troca todo clarão do jogo (raio, brilho da coleta, costura da sintonia, glitch da Estática) por um escurecimento leve.
- **Climas com efeito completo (16):** limpo, garoa, chuva, tempestade, vento, frio, neve, nevasca, dilúvio, onda de calor, aurora, chuva ácida, chuva de meteoros, Neve do Véu, Chuva de Fagulhas, Garoa Prismática. **Com parte do efeito sem alvo ou visual provisório (20):** sol forte, nublado, granizo, arco-íris, neblina, vendaval, poeira seca, fumaça, tempestade de areia, tornado, Chuva Carmim, Tempestade de Ecos, Estática, Silêncio, Cinzas do Véu, Procissão na névoa, Vento das Fendas, Céu Invertido, Maré do Véu, Sol Negro. Multiplicadores de tipos sem espécie (Elétrico, Espectral, Terra, Sombra, Luz, Feérico, Dracônico, Digital, Metal) ficam como dado sem efeito.
- **Modo passos:** teto de 12 mil passos convertidos por dia local, reinício do celular pela hora do boot (nunca negativo nem em dobro), trechos da Patrulha descontados, marcos de 5 e 10 mil com fala do Familiar, passos do dia no Perfil.
- **Patrulha do Véu** (`lib/patrol/`, `flutter_foreground_task`): serviço em primeiro plano do tipo localização, sem localização em segundo plano; GPS equilibrado a cada ~10 s ou 15 m; coleta na Aura e marca Ecos a até 30 m com o mesmo código do app; vibração e aviso para raro com o nome da rua; Arisco não é marcado acima de 2,5 m/s; carro ou moto pergunta pela notificação e motorista só tem a viagem gravada; desliga em 2 h (até 4 h), com bateria abaixo de 20% ou 10 min sem GPS; resumo no Chat. **O serviço nunca grava o save:** escreve `patrulha.jsonl`, que o app incorpora pelo uid, também com a Patrulha ainda ativa. A Patrulha simulada do debug não grava células visitadas.
- **Modo bolso** com a Patrulha: proximidade coberta escurece a tela e pausa o desenho; quem coleta é o serviço.
- **Adventure Sync (Health Connect): pendente**, não feito nesta versão.
- **Conferido no moto g54 (2026-11-09, GPS simulado):** instalação por cima da 0.15.1 com save schema 6 (mesmo `player_id`, log de versões íntegro); tempestade com clarão e Eco carregado do raio; arco-íris, neblina, Neve, Neve do Véu (flocos discretos demais, ajustar) e Chuva de Fagulhas; chuva cobrindo a tela inteira com o mapa girado em 90°, 180°, 270° e 360° a 50 m (40 e 80 m só no teste automatizado: o adb não faz pinça); Brilhante nível 20 pelo formulário; Oculto com variante revelado pelo Radar; Patrulha simulada com a notificação atualizando com o app aberto e com a tela bloqueada, vibração na marcação, incorporação com a Patrulha ativa e resumo no Chat; fps com tempestade e tráfego no Centro: build p50 3,9 ms, raster p50 6,4 ms, p90 abaixo de 7,6 ms (90 Hz). **Falta medir andando:** bateria, Patrulha real, vibrações no bolso, passos (`docs/teste-de-rua.md`).

## Fase 1 · fatia 5 · Clima no mapa, tudo no celular, rotas pelas ruas e HUD novo (0.17.0)

Segue o GDD rev 328. **A época 7 muda o mundo** (início 2026-11-10T04:40:00Z): clima em duas camadas com marcas e interações no mapa, 8 climas novos e climas presos a eventos. Save sem mudança de schema (continua 6).

- **Clima em duas camadas** (`docs/clima-auditoria.md`, com a lista do que é "proposta"): a tela só tem o que cai do céu ou cobre a vista; sombras de nuvem, Sol Negro, Procissão, Maré do Véu, poças, crateras, dunas, neve acumulada e marcas de raio são desenhadas no mapa, com a câmera, em posições do mundo. Neve do Véu com flocos maiores e mais densos.
- **Marcas e interações:** poças pela seed ao longo das ruas (sem relevo SRTM no projeto), que crescem, refletem o céu, secam em até 1 h e dão água pura e Ecos de Água, e na Geada forte viram gelo; crateras de meteoro por algumas horas; ruas baixas alagadas no Dilúvio, com barcos e canoas fantasmas; neve com trilhas nas avenidas e pegadas; dunas que mudam a rota dos fantasmas; destroços do tornado; brasas da Trovoada seca.
- **Eventos → clima:** Finados, Festa Junina e São João, chuvas de meteoros do calendário, superlua (Lua Dupla) e o feed assinado (`events.json` com `event` e `reason`). NOAA, Fendas, panteões e Os Que Escutam ainda não têm fonte. O app Céu mostra o motivo.
- **Tudo no celular:** apps Rotas (Modo Viagem), Patrulha (com histórico) e Céu; Radar como app de sonar. Ajustes só com preferências.
- **Radar refeito:** pulso com recarga de 2 min, arcos para rastros a até 250 m (mais estreitos de perto, cor do tipo no nível 2), Ocultos a até 60 m como distorção que vira Eco quando o jogador chega a 20 m, onda ciano no chão, rastreador único na borda direita e atalho no HUD com anel de recarga.
- **HUD em zonas fixas:** barra do topo (hora, lua, clima, selo de modo), bússola abaixo só fora do norte, retrato, celular, rastreador e atalho do Radar, faixa de atalhos temporários. Teste de não sobreposição nos três tamanhos. Os chips do simulador e o menu de debug ficam na folha do selo.
- **Rota pelas ruas:** a reta vinha do grafo que só ligava ruas com vértice em comum; o pacote corta ruas nos tiles e as simplifica separadamente. O grafo de rotas agora costura cruzamentos (o tráfego fantasma continua no grafo antigo). Perfis a pé, bicicleta e motorizado; nada por `access=private`/`no` (arquivo só de rotas, `campinas_e0_noaccess.bin` no APK, o de São Paulo no `regions.json` em `route_files`). Recalcula a 30 m da rota; destino fora dos dados com trecho tracejado e aviso.
- **Corrida já em andamento:** ao abrir e ao voltar ao app, lê as notificações ativas do Uber e do 99 (com a permissão e o interruptor) e retoma no estado certo. Padrões ainda sintéticos.
- **Ajustes da 0.16.0:** "GPS simulado dá recompensa" no debug, desligado por padrão (itens entram, mas sem XP, estatísticas, bestiário nem baú, e as capturas ficam marcadas como debug); pré-carga dos blocos da Overpass à frente só com Wi-Fi não medido; motorista sem nada nem na chegada, com teste.
- **Decisões para revisar:** bicicleta respeita a mão; com o GPS simulado os itens ainda entram na Bolsa; as propostas da auditoria do clima.
- **Revisão do usuário e ajustes depois do primeiro pacote:** GPS simulado sem recompensa também não põe nada na Bolsa; eclipse só vira evento se for visível no centro da região do clima (elementos da NASA, solar parcial conta, lunar só total entre U1 e U4), com as fontes em `docs/clima-auditoria.md`; poças da Chuva Carmim dão Essência carmesim; a Runa dá Giz e um bônus que revela um espaço "???" no próximo ritual (campo opcional `conjurer.rune_bonus`, schema continua 6); Cinzas do Véu, Procissão, Maré do Véu e Sol Negro marcados como provisórios até existir a espécie ou o sistema; bicicleta respeitando a mão mantida (CTB art. 58).
- **Conferido no moto g54 (2026-11-10, GPS simulado):** instalação por cima da 0.16.0 com o save intacto (schema 6, log de versões íntegro); HUD em zonas com o rastreador cheio, com o mapa girado (bússola abaixo da barra) e com a Patrulha ativa (faixa acima do celular), sem sobreposição; apps Rotas, Patrulha e Céu na grade; Radar em sonar com 4 arcos coloridos e pegadas no chão; Maré do Véu presa ao chão ao girar o mapa; poça com água pura e Eco de Água; cratera de meteoro com a Chuva de meteoros ativa; rua alagada no Dilúvio; rota de carro Unicamp → Catedral pelas ruas (11,7 km, ~29 min) com os botões do Uber e do 99; app Céu com motivo do evento; vídeo do Silêncio. **Achado e corrigido no aparelho:** os apps do celular não abriam depois que o HUD se reorganizava (contexto do botão fora da árvore). **Não visto no aparelho:** barcos no Dilúvio, sombras do Sol Negro no chão, figuras da Procissão distinguíveis, cratera depois que o clima muda, distorção de Oculto no Radar, corrida em andamento (sem corrida real).
- **Silêncio:** no aparelho os fantasmas somem em vez de ficarem parados; pendente da aprovação do usuário.


## Fase 1 · fatia 5a · Polimento do clima, passantes e Radar (0.17.1)

Segue o GDD rev 333. **A época 8 muda o mundo** (início 2026-11-10T15:40:00Z, validade até 2027-02-08T15:40:00Z): copia a 7 e acrescenta o calendário do Véu, o arco-íris fixo no mapa e a Procissão com o Eco do fim na rua. Save sem mudança de schema (continua 6). A 0.17.0 recusa a época 8 do feed: ela só deve ir para o feed assinado com todo mundo na 0.17.1.

- **Marcas formam e somem com o tempo** (`world/climate_form.dart`): poças, neve, dunas, água do Dilúvio, gelo, fuligem, geada, cinzas e sombras do Sol Negro crescem desde o começo do clima no lugar e secam ou derretem depois do fim, pelos instantes do mundo (iguais para amigos juntos). Tempos só de desenho no `clima.json`. Debug: velocidade do clima 1×, 10× e 60× e a simulação que passa por todos os climas sem dar recompensa. Tabela em `docs/clima-auditoria.md`.
- **Poças, neve e dunas refeitas:** poças irregulares que se juntam; neve do pó à grama, ao chão e só depois às ruas, com trilhas nas avenidas; dunas que crescem do meio da rua.
- **Calendário do Véu** na época 8 (`core/veil_calendar.dart`): cada clima de outra região e cada místico ao menos uma vez por ano, com datas móveis offline (Páscoa, equinócios, solstícios, sextas-feiras 13); o feed muda uma data com `calendar_skip`. O app Céu mostra o próximo evento.
- **Arco-íris no mapa:** depois da chuva, 25% de chance, de 20 a 40 min, pé numa rua a até 400 m do centro da região; a base gira com o mapa e a altura sobe na tela. Pé com Fragmento de luz. **Prisma de orvalho** (Bancada) aponta o pé mais perto. Itens novos com `since_epoch: 8`.
- **Vento nas criaturas** (só desenho): Ecos e Fagulhas inclinam, os leves derivam e voltam.
- **Raio aqui** no debug; o Eco carregado do raio aparece sem aviso.
- **Procissão de verdade:** de 12 a 20 figuras encapuzadas a 0,8 m/s pela rota das ruas, com vela na mão, velas no chão por 30 min, visíveis até 120 m.
- **Passantes vestidos pelo clima** (guarda-chuva, casaco e gorro), iguais nos dois aparelhos.
- **Silêncio:** o tráfego congela onde está no instante em que o Silêncio começa e volta a andar de onde parou; o relógio volta à hora real no fim da janela seguinte.
- **Céu no HUD:** Lua Dupla e Sol Negro numa faixa própria abaixo da barra (`HudLayout.sky`), no teste de não sobreposição.
- **Radar:** sem os quadrados de tipo; o app fica "???" até o mentor entregá-lo no nível 5 (fala `radar_gift`, também para quem já passou do 5); sem rastreador fixo; o pulso deixa marcas na borda da tela por 2 min (`radar.edge_marks_s`).
- **Achado e corrigido no aparelho:** "Ir até o pé do arco-íris" nunca funcionava, porque o menu de debug fecha o mapa; agora o pedido espera o mapa abrir, e os arcos soltos no toque sobrevivem à ida ao menu. "Efeito do clima no toque" ganhou a Procissão.
- **Conferido no moto g54 (2026-11-10, GPS simulado na Unicamp, APK com a chave de release, instalado por cima da 0.17.0):** formação a 60× de poças (com Eco de Água), neve e dunas, com antes e depois; passantes de guarda-chuva e de casaco; arco-íris girando com o mapa (base em pé ao girar); teleporte até o pé; raio do debug em vídeo (traço, clarão, Eco carregado com faíscas, sem aviso); Procissão com figuras, velas na mão e velas no chão; Radar sem quadrados, com 2 arcos verdes, marca na borda e pegada no chão; fala do mentor no Chat; Lua Dupla e Sol Negro abaixo da barra sem sobreposição. **Não visto no aparelho:** Dilúvio com barcos, vento nas criaturas, simulação completa, calendário (só teste), Prisma de orvalho.
- **Pendentes de revisão:** cinco climas sem data no calendário (Sol Negro, Chuva Carmim, Vento das Fendas, Tempestade de Ecos, Lua Dupla); o scanner nível 1 deixou de existir na prática (o nível 2 também chega no 5); o m10 e o Círculo ainda falam em "rastreador"; o atraso do tráfego depois do Silêncio dura até o fim da janela seguinte.

## Fase 1 · fatia 5b · Ordem de desenho, formas e respostas da 0.17.1 (0.17.2)

Segue o GDD rev 334 (a seção Instrumentos e canções é só especificação: nada dela foi implementado). **Nada muda o mundo:** sem época nova, save sem mudança de schema (continua 6), `epochs.json` intocado. Só desenho, textos e `balance.json`.

- **Ordem de desenho fixa** (`ui/game/draw_order.dart`, `MapLayer`): mapa base, marcas do clima no chão, sombras, criaturas, Fagulhas, materiais, passantes, carros, Conjurador e Familiar, efeitos no ar presos ao mapa (arco-íris, olho do furacão, redemoinho, prédios da Maré, vultos, Procissão em pé), camada de tela do clima, HUD. Antes, a camada do chão do clima era pintada depois do Tráfego do Véu: neve, poças e água cobriam passantes e carros e mudavam a cor deles. O tom do clima fica na camada de tela, por cima do mapa e de quem está nele, por igual. Os carros agora ficam por cima dos passantes. Teste: `test/ui/draw_order_test.dart`.
- **Formas variadas** (`blobRows` em `ui/game/climate_puddle.dart`): toda marca no chão sai de um contorno procedural com ruído, do hash da marca: seis famílias (redonda, comprida, dois lóbulos, feijão, três pontas, respingada), cada uma com rotação, alongamento, irregularidade e tamanho (0,75 a 1,3) próprios. Vale para poças, gelo, crateras, marcas queimadas, brasas, manchas de cinza e fuligem, sombras do Sol Negro, brilhos, olhares, runas e a cera das velas. As dunas afinam nas pontas e ondulam (`duneOutline`). Teste: `test/ui/climate_shapes_test.dart`.
- **Cobertura das ruas sem cortes** (`ui/game/climate_cover.dart`): neve, gelo, fuligem e água do Dilúvio seguem a linha da rua com pontas e esquinas redondas; a borda se desfaz em três degraus de largura e em pontilhado de pixel (`edgeDither`), também no recorte das ruas na neve do chão. Os montes de neve deixaram de ser um por célula.
- **Radar:** chega no nível 5 com o scanner nível 1; o nível 2 (cor do tipo) passou para o nível 8 (`radar.level2_player_level`).
- **Textos:** "rastreador" virou Radar no m10, no Círculo e nas habilidades.
- **Noite das Fendas:** entra no calendário do Véu sem data (`clima.json` `calendar_pending`, só texto): o app Céu lista "Noite das Fendas: Vento das Fendas e Tempestade de Ecos. Data a definir." Quando a data sair (o aniversário do início do beta), a regra entra no `calendar` de uma época nova. Até lá, os dois climas só pelo debug. Sol Negro e Chuva Carmim continuam só nos eclipses visíveis, e a Lua Dupla, pela astronomia.
- **Depois do Silêncio:** o relógio do tráfego volta à hora real quando o Silêncio acaba. Durante 60 s (`climate.traffic_resync_s`), quem estava parado volta a andar de onde parou, 1,25 vez mais rápido (`climate.traffic_resync_speed`), e se desfaz pela costura do Véu enquanto o tráfego da hora entra. Ninguém salta de lugar nem fica atrasado até a janela seguinte. Função só do tempo do mundo: igual nos dois aparelhos. O mesmo vale quando o debug tira o Silêncio.
- **Conferido no moto g54 (2026-11-11, GPS real, APK 0.17.2+28 com a chave de release, instalado por cima da 0.17.1, save mantido):** antes e depois na chuva e na neve a 60×. Na 0.17.1 a neve cobria passantes e carros e as vielas acabavam em corte quadrado; na 0.17.2 o passante aparece com as cores dele por cima da neve, o carro por cima da rua molhada, as vielas acabam redondas com a borda pontilhada, e a cratera da Chuva de meteoros tem contorno irregular. Tela de bloqueio conferida antes de cada captura. **Não visto no aparelho:** poças (não havia nenhuma perto na chuva forçada), várias crateras lado a lado, dunas, gelo, fuligem, Dilúvio, a ressincronização depois do Silêncio e a linha da Noite das Fendas no app Céu; esses estão cobertos por teste e, no caso das coberturas, por render fora da tela.
- **Feed:** `docs/pages` não tinha nada a commitar: o feed assinado com as épocas 0 a 7 já está no commit `0281e0d`. A época 8 continua fora do feed até todo mundo estar na 0.17.1 ou mais nova.

## Fase 1 · fatia 6 · Tráfego e neve simulados (0.18.0)

Segue o GDD rev 335: o tráfego comum deixa de ser igual entre amigos. **Nada muda o mundo:** sem época nova, `epochs.json` intocado, save sem mudança de schema (continua 6). O tráfego comum nunca esteve em `epochs.json` (lá só há o `traffic_mult` de cada clima, que continua valendo como lentidão); o que saiu foi a geração pela seed (`TrafficField`, `traffic_route.dart`). A neve continua determinística pela seed e pelo tempo; só as trilhas do tráfego são locais.

### Tráfego simulado (`app/lib/world/sim/`)

- **Área:** raio de 400 m em volta do jogador (`traffic_sim.radius_m`; a tela no zoom mais aberto tem 80 m de largura). O grafo é refeito quando o jogador anda 150 m; quem está nas ruas que continuam fica onde está, e os trechos novos (a borda) já entram povoados.
- **Grafo de faixas (`lane_graph.dart`):** do grafo de ruas da rota (`TrafficGraph` com corte nas esquinas e os viadutos do arquivo de rota). Cada trecho entre duas esquinas vira uma via com mão de direção (a mão única do pacote), faixas pela classe (2 por sentido na principal, 1 nas outras) e as duas calçadas. Esquinas ligadas por um trecho de menos de 12 m viram uma só. Onde duas ruas se juntam em ângulo raso, o recuo vai até onde elas se separam.
- **Controle das esquinas:** do OSM, pelo arquivo novo `campinas_e0_traffic.bin` (`pipeline/build_traffic.py`, fora das épocas): 909 semáforos, 1.137 pare, 77 dê a preferência, 4.933 faixas de pedestre e 935 entradas (estacionamentos e garagens) em Campinas. Sem placa, cede a vez quem vem da rua menor; entre ruas iguais, todos param e entra quem chegou primeiro. Fora da área do arquivo (São Paulo, blocos do fallback), cruzamento de avenidas ganha semáforo.
- **Semáforo de pedestre:** nó com semáforo do OSM e só duas ruas de carro (a faixa no meio da quadra): a rua fica verde 33 s e para 10 s para a faixa.
- **Semáforos:** dois grupos por esquina (o eixo da rua mais larga e o atravessado), verde de 22 s (20% a mais no eixo de avenida), amarelo de 3 s e vermelho geral de 2 s, com a fase pela seed e pela posição da esquina.
- **Carros:** seguem o da frente pelo IDM (aceleração 1,5 m/s², freada 2 m/s², intervalo 1,2 s, folga 2 m), param na linha no vermelho (no amarelo, só passa quem não consegue mais parar), reservam a vez na esquina antes de entrar e só entram com lugar do outro lado. Dois movimentos só cabem juntos na esquina se forem a mesma faixa do mesmo acesso, lado a lado para a mesma rua, ou a mão contrária indo reto. A curva da esquina é uma Bézier da ponta de uma faixa ao começo da outra; a direção desenhada é suavizada. Perto da tela, quem tem outro carro logo à frente fora da sua fila freia por ele (ruas que se juntam).
- **Passantes:** andam nas calçadas (1,5 m além do meio-fio) e nos caminhos de pedestre. Na ponta da calçada escolhem seguir, virar a esquina ou atravessar. Só atravessam onde há faixa do OSM perto da esquina; sem nenhuma faixa mapeada ali, nas esquinas (nunca no meio do quarteirão). No semáforo esperam os carros daquela rua ficarem no vermelho; sem semáforo, esperam ninguém vir chegando. Enquanto atravessam, os carros esperam antes da faixa. Quem vem de frente desvia cada um para a sua direita; quem alcança um mais lento passa pela esquerda.
- **Nascer e sumir:** só na borda da área ou nas entradas do OSM, e sempre a mais de 25 m da tela. Ao abrir o app a área já está povoada e a simulação roda 30 s antes do primeiro quadro (as filas dos semáforos já existem). Um carro preso há mais de 2 min longe da tela some.
- **Densidade:** a curva pela hora local de antes, vezes a classe da rua (`cars_per_100m`, `walkers_per_100m`), até 400 carros e 350 passantes. O clima reduz e freia (ver `docs/clima-auditoria.md`).
- **Silêncio:** a simulação pausa e depois continua de onde parou. O crossfade da 0.17.2 saiu.
- **Longe da tela:** além de 60 m da tela, os carros atualizam a cada 4 quadros e os passantes a cada 8, com o passo maior.
- **Debug (seção Tráfego):** contador de agentes e custo do passo, área simulada e entradas desenhadas, a luz de cada acesso dos semáforos, densidade forçada (vazio, pouco, rush, lotado).
- **Fora desta versão:** Ônibus Espectral, Van do Mercador, Carroça de Essência e carro fugitivo ainda não existem no código; quando entrarem, saem da seed, fora da simulação. A Procissão já é assim e não foi tocada. Os carros da simulação não desviam dela.

### Neve e coberturas por campo

Ver "Cobertura por campo (0.18.0)" em `docs/clima-auditoria.md`: máscara única das ruas por bloco, campo de profundidade em forma fechada, trilhas do tráfego local, bancos no meio-fio, derretimento inverso, bordas em pontilhado ordenado. A mesma técnica para gelo, fuligem e água do Dilúvio; as poças ganharam o mesmo tipo de borda, mas continuam desenhadas uma a uma.

### Testes

`test/world/sim/traffic_sim_test.dart` (cidade em grade): ninguém nasce nem some dentro da vista (600 s), carros não se atravessam nem andam de ré, ninguém reserva a esquina no vermelho, passante só atravessa na faixa e no semáforo só com os carros no vermelho, carro espera o passante, pausa do Silêncio, densidade pela hora e pelo clima, rua fechada, refazer a área sem salto, desempenho. `traffic_sim_campinas_test.dart`: as ruas de verdade do Centro, do Taquaral, de Barão Geraldo e do entroncamento da Norte-Sul, sem sobreposição perto da tela. `test/world/cover_field_test.dart`: máscara única sem sobreposição, um só nível de opacidade no cruzamento, profundidade igual para o mesmo tempo e na ordem das superfícies, trilhas, bancos nas bordas e do lado do vento, degelo, bordas em pixel, neve funda, desempenho. Suíte: 1653 passam, 4 pulados; `flutter analyze` limpo.

### Medido no PC (não é o celular)

- Passo da simulação com 60 carros e 80 passantes na grade: 7 a 11 µs. Nas ruas de Campinas com a densidade de rush: 30 a 140 µs com 150 a 280 carros e 100 a 280 passantes.
- Montar o grafo de faixas: 20 a 50 ms depois de os tiles estarem lidos; 120 a 340 ms na primeira vez no Centro (inclui ler e cortar os tiles).
- Montar um bloco da cobertura: 2 a 3 ms, fora da thread do desenho.

### Limites conhecidos

- Em entroncamentos muito picados, fora da tela, dois carros ainda podem se encostar (lá não há a rede de segurança e o passo é maior).
- Não há troca de faixa no meio do quarteirão: a faixa é escolhida ao entrar na rua.
- O arquivo de rota (ruas fechadas a motor) não é lido pela simulação: carros podem entrar em rua particular.
- O desgaste da neve não diminui com o tempo nem zera quando começa outra nevasca na mesma sessão.
- A primeira montagem do grafo custa alguns quadros no celular (37 a 71 ms medidos).
- O pixel do campo (uns 0,55 m) é maior que o pixel de arte (3 dp, uns 0,42 m no zoom padrão): o pontilhado aparece graúdo de perto. Dá para afinar com `coverRes` (48 daria 0,37 m, com 2,25 vezes o custo por bloco).
- A tecla voltar no menu de debug aberto pela folha do simulador fecha o app (já era assim antes desta versão).

### Conferido no moto g54 (2026-11-11, APK 0.18.0+29 com a chave de release, instalado por cima da 0.17.2, save mantido)

- **Tráfego no GPS real:** carros nas faixas e passantes na calçada desde o primeiro quadro; 44 carros e 34 passantes na área, passo médio de 141 µs. Não há semáforo a 400 m de onde o aparelho estava.
- **Semáforo (simulador de GPS no Centro de Campinas, densidade de rush forçada):** vídeo de 30 s num cruzamento com semáforo: um carro espera no vermelho e sai no verde, enquanto a outra rua forma fila de três carros em duas faixas no vermelho dela. Com a sobreposição do debug ligada (a luz de cada acesso). 310 carros e 164 passantes na área: passo médio de 383 µs, pico de 1,2 ms. Com 136 carros e 49 passantes: 320 µs. **O teto de 2 ms vale com folga**; a combinação exata de 60 carros e 80 passantes não foi medida (fica entre 141 e 320 µs).
- **Grafo de faixas:** 37 ms no bairro do aparelho, 62 a 71 ms no Centro (288 esquinas, 38 a 40 semáforos).
- **Neve (Nevasca forçada, clima a 10x, no mesmo cruzamento):** três fases capturadas. Começo: chão e grama em pontilhado, ruas limpas. Cobertura: a neve avança das calçadas para dentro das ruas de forma irregular, a avenida por último. Cheia: neve suja nas ruas com as trilhas escuras do tráfego e os bancos no meio-fio. Depois, com a Tempestade forçada, o degelo: ruas limpas com os bancos claros nas bordas, e por fim o chão raleando em pontilhado. Nenhum tubo, nenhum círculo no cruzamento, nenhuma ponta redonda. 16 blocos na tela, cada um refeito em 12,6 ms fora da thread do desenho.
- **Durante a conferência entraram duas mudanças** (o APK instalado já as tem): semáforo de pedestre no meio da quadra (o nó com semáforo do OSM e só duas ruas de carro: a rua para por `ped_green_s` = 10 s enquanto a faixa abre), e os tetos subiram para 400 carros e 350 passantes.
- **Não visto no aparelho:** gelo, fuligem e Dilúvio pelo campo novo (só no render fora da tela), a pausa do Silêncio, um passante esperando o verde no vídeo, a neve funda fechando rua, e a mesma área da captura da 0.17.2 (a de antes é no bairro do aparelho, a de depois é no Centro). O material coletado pelo simulador durante a conferência entrou como debug, fora da Bolsa.
- Tela de bloqueio e app em primeiro plano conferidos antes de cada captura e durante a gravação. Numa das voltas a tecla voltar fechou o Kenoma e o app que estava aberto antes ficou na frente: a captura foi recusada.

## Fase 1 · fatia 7 · Relevo, água, neblina, vento e vida urbana (0.19.0)

Segue o GDD rev 336 ("Simulações do mundo"; o texto entrou no commit `f726cd7`, junto com a conferência da 0.18.0, por engano: não há um commit "docs: GDD rev 336" separado). A regra: o que muda o jogo é função da seed e do tempo, igual para amigos; o que é cenário pode ser simulação local. **Esta versão muda o mundo: época 9**, início 2026-11-11T17:30:00Z, válida até 2027-02-09. Save sem mudança de schema (continua 6). As épocas 0 a 8 não foram tocadas (conferido byte a byte ao acrescentar a 9). **A época 9 não está no feed assinado:** quem tem a 0.18.0 ou mais antiga continua na 8 até receber a 0.19.0.

### O que muda o mundo (época 9)

- **Relevo (`relief_packs`):** `campinas_e9_relief.bin`, do SRTM de 30 m (espelho público skadi), numa grade z20 de 1169 x 1206 amostras suavizadas (sigma de 1,2 amostra), de 527,8 a 998,6 m, 1.373.573 bytes, SHA-256 `1bb9c5ac…7d86` fixado na época. A altura de uma célula z21 é a interpolação bilinear das quatro amostras; a água usa a versão só com inteiros (`h16At`, 1/16 dm). `pipeline/build_relief.py` recusa regerar por cima. São Paulo e os blocos do fallback Overpass não têm relevo: lá o terreno é plano e valem as regras de antes (poças e ruas alagadas sorteadas, neblina igual em todo lugar).
- **Água da chuva (`water`, `world/water_field.dart`):** por tile z15, com 32 células de folga: a chuva põe 1024 em cada célula z21 e, em 32 passos fixos, metade da água de cada célula vai para a vizinha mais baixa das oito. O leito das ruas fica abaixo do terreno (1 a 3 dm pela classe: são os canais), o bueiro tira 5, 10 ou 16 de cada 256 por passo (local, secundária, principal), e rios e lagos do pacote visual levam embora o que chega. Alturas e água em inteiros.
  - **Poças:** em cada célula z17, os pontos onde mais água se juntou (a baixada, ou o ponto com mais água que os oito em volta), no máximo `per_cell` do clima, levados para a rua como antes. A mais funda é a maior e a última a secar (`dry_depth_bonus`: até 50% a mais de tempo). No Centro saem uns 20 por tile z15 (1,3 por célula z17); **antes eram 2 a 5 por célula z17**: há menos poças, e elas ficam nos pontos baixos de verdade. Os sorteios da poça (item, Eco) continuam os mesmos.
  - **Dilúvio:** alaga a rua que tem pelo menos um terço do traçado em células por onde passou muita água (fundo de vale) ou a até três células de um rio ou lago e no máximo 1,2 m acima dele. No Centro, 4,5% das células. Os caminhos de pedestre não alagam. Sai o sorteio de `share` (continua valendo onde não há relevo).
- **Neblina (`fog`):** em `fog` e `fog_procession`, a visão dos Ecos (`view_max_m`, 60 m) passa a depender do lugar: a altura do ponto contra a média de oito pontos a 16 células (15 m abaixo é fundo de vale, 15 m acima é alto de morro), mais a beira d'água. No vale 0,6 vez (36 m), no morro 1,6 vez (96 m). O sol acima de 8° começa a desfazê-la e em 30° a visão chega a 2,5 vezes.
- **Movimento (`motion`, `core/motion_model.dart`):** função fechada da seed, do uid e do tempo, sem estado.
  - Eco Passivo: anda devagar num raio de 3,5 m (duas ondas de períodos diferentes, em torno de 80 s). Arisco, Agressivo e Oculto ficam onde nascem.
  - Eco de Água: ronda a poça mais próxima (o ponto onde a água se junta, a até 40 m) num círculo de 4 m; o que nasceu de uma poça ronda a dele.
  - Correntes do Véu: nove em dez células z18 têm um redemoinho fixo pela seed; a Fagulha desliza a 0,04 m/s até o mais próximo (a até 60 m) e gira em volta dele a 1,5 m. A deriva do vento do clima soma por cima, como antes.
  - Alcance de toque e Aura são medidos contra a posição do momento (a lista do mundo já sai com ela, relida a 4 Hz com o instante exato).

### Cenário (local, fora das épocas)

- **Véu da neblina:** preso ao mapa, em quatro tons pela densidade do lugar, por baixo da camada leve de tela que já existia. **Redemoinhos:** ponto de brilho que pulsa, com quatro pixels girando.
- **Vento local (`world/sim/wind_field.dart`):** a direção e a força do clima canalizadas pelas ruas (1,35 vez ao longo da rua, quase nada na rua de través, metade atrás das quadras), com rajadas. Leva 40 folhas e papéis pelo chão nos climas de vento (`wind_mps`), que nascem fora da tela, do lado de onde o vento vem.
- **Chuva:** quando ela começa, quem está na rua corre (2,4 vezes) para o abrigo mais próximo, que é a esquina a até 20 m de um ponto de ônibus, comércio ou bar do OSM, e fica parado lá até parar de chover. Quem nasce durante a chuva já vem de guarda-chuva e anda normal.
- **Pombos:** um bando de 4 a 8 em cada praça ou parque do OSM a até 220 m; ciscam, e quando o avatar chega a 5 m levantam voo e pousam uns 13 m adiante. Só nascem e somem fora da vista.
- **Pontos do OSM:** `campinas_e0_traffic.bin` foi regerado com ponto de ônibus (1.258), comércio (2.536), bar e restaurante (1.026), escola (582) e praça (1.575): 14.967 pontos, 56.231 bytes.
- **Debug:** relevo como mapa de calor (seção Mapa e câmera).

### Do pedido, o que NÃO entrou nesta versão

- **Água:** a neve derretida não entra no campo de água; a poça rasa não congela de madrugada em Frio e Geada (continuam as poças de gelo próprias desses climas); as poças não entraram na máscara única dos blocos.
- **Vento:** fumaça, fuligem do smog nascendo nas avenidas e areia ainda não seguem o campo; as dunas não andam; as criaturas continuam se inclinando pelo vento do clima, não pelo local; a deriva das Fagulhas pelo vento continua em linha reta na direção do clima (não é canalizada pelas ruas).
- **Vida urbana:** esperar e entrar no ônibus (o Ônibus Espectral ainda não existe), sentar em praças, passear com cachorro, lotar comércio de dia e bar à noite, horário de escola e de fim de expediente, ciclistas na ciclovia, a multidão em dia de jogo, gatos, morcegos e maritacas.
- **Ecos:** de Sombra e voadores ainda não existem.
- **Relevo:** recorte de SRTM para os blocos do fallback e para São Paulo.

### Testes

`relief_pack_test` (interpolação e vetores fixos de Campinas, SHA do arquivo), `water_field_test` (a água para no fundo da bacia, igual em dois aparelhos e na emenda de tiles, ruas como canais, lago como sumidouro, margem alagada, Dilúvio por rua), `fog_model_test` (vale e morro, sol da manhã), `motion_model_test` (Eco Passivo, órbita, redemoinhos, Fagulha sem salto), `epoch9_world_test` (ponta a ponta com os arquivos de verdade: poças iguais em dois aparelhos e abaixo da vizinhança, Eco e Fagulha em movimento, neblina no vale e no morro), `wind_field_test` (vento desviado pelas ruas, rajadas, folhas), `birds_test` (pombos levantando voo), e em `traffic_sim_test` os passantes se abrigando na chuva. Suíte: 1684 testes, 4 pulados; `flutter analyze` limpo. O teste "um Eco oculto forçado…" de `game_map_screen_test` depende do relógio e falha de vez em quando (já falhava na 0.17.2).

### Medido no PC

- Campo de água: 6 a 8 ms por tile z15 (uma vez por tile, guardado). Montar o relevo: uma leitura de 1,4 MB ao abrir.
