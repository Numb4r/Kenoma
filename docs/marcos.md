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

### Conferido no moto g54 (2026-11-11, APK 0.19.0+30 com a chave de release, instalado por cima da 0.18.0, save mantido)

Com o simulador de GPS (Taquaral e Centro de Campinas), climas forçados pelo debug.

- **Relevo no debug:** o mapa de calor no Taquaral, de 715 m no alto da tela a 708 m embaixo, com a altura de cada célula.
- **Dilúvio (Taquaral):** a rua ao lado do lago alaga (com um carro virado barco), com a borda irregular do campo; as ruas mais altas em volta ficam secas.
- **Chuva e abrigo (Centro, densidade "lotado"):** vídeo de 30 s: ao abrir o mapa na chuva, os passantes correm pela calçada e param na esquina do comércio; os carros seguem. Passantes parados no abrigo também numa captura.
- **Pombos (praça no Centro):** o bando aparece no gramado e levanta voo quando o avatar chega; no vídeo eles são pequenos (uns 12 por 6 pixels de tela), mesmo depois de aumentados.
- **Eco de Água** visto perto de uma esquina na chuva.
- **Orçamento:** passo da simulação do tráfego com 302 carros e uns 320 passantes: 421 µs em média (último 262 µs). O teto somado de 4 ms vale com folga para o que foi medido. **Não medidos no aparelho:** o campo de água (uma vez por tile; 6 a 8 ms no PC), o véu da neblina por quadro, pombos e folhas.
- **Corrigido durante a conferência:** a densidade forçada do debug não valia para a primeira leva de agentes ao abrir o mapa.
- **Não visto no aparelho:** a neblina num vale de manhã (o relógio do aparelho estava no meio da tarde, com o sol alto, e não mexi no relógio do debug), poças formando nas baixadas (na chuva forçada não havia nenhuma na tela nos dois lugares), o movimento de um Eco Passivo e de uma Fagulha até o redemoinho acompanhados de perto, as folhas ao vento num clima de vento, e a comparação com um lugar que alaga de verdade (a rua alagada no Taquaral fica ao lado do lago; a Av. Norte-Sul não foi visitada). Estão cobertos por teste.
- Tela de bloqueio e app em primeiro plano conferidos antes de cada captura e durante as gravações.

## Fase 1 · fatia 7b · Completando a 0.19.0 (0.19.1)

**Muda o mundo: época 10**, início 2026-11-11T19:00:00Z, válida até 2027-02-09. É a época 9 mais os números e as regras abaixo; as épocas 0 a 9 não foram tocadas (conferido ao acrescentar). Save sem mudança de schema (6). **Fora do feed assinado**, como a 9.

### Mundo (época 10)

- **Poças (medido antes e depois):** no Centro, de 1,40 para **2,41 poças por célula z17** em média (teto de 5 do clima). Só baixar `pool_min` não bastava: na época 9 só valia o ponto com mais água que os oito em volta, e isso limita a contagem. Na 10, qualquer célula com água parada acima de `pool_min` (2048) pode ser poça, desde que fique a 3 células de outra maior (`spot_spacing`).
- **Rua molhada:** enquanto chove (climas com poça que gera Eco: chuva, tempestade, chuva carmim), cada célula z17 sorteia 2 trechos de rua por janela do clima (`wet_per_cell`) e em cada um nasce o Eco da poça com 30% de chance (`wet_chance`), mesmo sem poça ali.
- **Neve derretida:** depois de neve, nevasca ou neve do Véu, aparecem nas mesmas baixadas as poças pequenas da garoa (`melt_as`): crescem nos primeiros 30% do tempo de secar e depois secam, as mais fundas por último. Não geram Eco (não está chovendo); o item da poça sim.
- **Poça que congela:** no Frio e na Geada, das 2 às 7 h locais, a poça com até metade do tamanho vira a poça de gelo da Geada (com o item dela), no mesmo lugar; de dia volta a ser água.
- **Vento local (`wind`):** a deriva das Fagulhas passa a seguir o vento do lugar: na rua, 1,35 vez o que sopra ao longo dela mais 15% do vento do clima; fora das ruas, metade. A direção da rua em cada célula sai do pacote visual da época (`world/street_dirs.dart`), não da simulação local.
- **Relevo de São Paulo:** `sao_paulo_e10_relief.bin` (1373 x 2103 amostras, de -11,3 a 1214,6 m, 2.989.059 bytes, SHA-256 `1c050f97…33b9`) listado em `relief_packs`. Fica em `pipeline/out/regions/` (fora do git, como os outros de São Paulo). O app aceita o tipo `relief` nos arquivos da região baixada e, sem ele, abre a região com o terreno plano. **Para chegar aos aparelhos falta publicar:** o arquivo no Pages e a entrada no `regions.json` assinado (o que só o dono da chave faz).

### Cenário

- **Vento:** fumaça (`smoke`), fuligem do smog (nasce nas avenidas) e areia (`sandstorm`, `dry_dust`) seguem o campo local, no lugar das folhas. As dunas andam a 0,02 m/s pela rua para o lado do vento e se amontoam no fim dela. As criaturas se inclinam e são empurradas pelo vento do lugar.
- **Vida urbana:** comércio com gente de dia (9 às 19 h), bares à noite (19 às 2 h, e metade no almoço), porta de escola na entrada e nas saídas, gente sentada nas praças de dia, gente esperando no ponto de ônibus. Entram e saem só com o lugar fora da vista. Ônibus (4% dos carros de avenida, no máximo três) encostam no ponto por 7 s e quem esperava anda até ele e embarca. Um em cada treze adultos passeia com cachorro. Em dia de jogo (`traffic_sim.match_utc` no `balance.json`, nas 2 h antes), os passantes tendem para o estádio do OSM.
- **Bichos:** pombos com o dobro do tamanho, três quadros de bater de asas e sombra no chão; gatos sentados junto de um terço das garagens; morcegos à noite em volta das praças; maritacas em bando cruzando a tela das 6 às 8 h e das 16 às 18 h.
- **Neve:** o pixel do campo passou de 0,55 m para 0,37 m (`coverRes` 48), perto do pixel de arte. Aplicado porque o que foi medido das simulações fica muito abaixo de 4 ms (421 µs o tráfego no aparelho); o bloco é montado fora da thread do desenho.
- **Debug:** a linha da simulação do tráfego mostra também o custo da água (por tile), do véu da neblina e dos bichos e do vento por quadro.
- **Pontos do OSM:** `campinas_e0_traffic.bin` regerado com os estádios.

### O que NÃO entrou

- **Relevo dos blocos do fallback:** não foi feito. O recorte do SRTM vem em tiles de 1 grau com 7 a 12 MB cada, e a altura é mundo: o app teria de refazer no aparelho, bit a bit, a amostragem e o filtro do `build_relief.py`. Os blocos do fallback continuam com terreno plano.
- **Calendário de jogos:** `match_utc` está vazio. O mecanismo está pronto e testado, mas as datas dos jogos da Ponte Preta e do Guarani precisam vir de quem as conhece.
- **Ciclistas na ciclovia:** o pacote visual não guarda a tag de ciclovia; os ciclistas continuam só nos caminhos de pedestre.
- **Horário de trabalho:** só a curva de densidade pela hora que já existia (rush das 8 e das 18 h); não há gente indo e voltando de um lugar de trabalho.
- **As poças ainda fora da máscara única dos blocos.**

### Testes

Novos em `epoch9_world_test` (grupo "época 10": densidade das poças antes e depois, rua molhada, deriva pelo vento local, degelo e congelamento), em `traffic_sim_test` (grupo "vida urbana": lugares pela hora, ônibus e embarque, dia de jogo) e em `birds_test` (gatos, morcegos, maritacas). Suíte: 1699 passam, 4 pulados (com os testes de ciclistas e de jogos do feed); `flutter analyze` limpo.

### Depois do pedido de 2026-11-12

- **Ciclovias:** entram num arquivo ao lado, `campinas_e0_cycle.bin` (`pipeline/build_cycle.py`: `highway=cycleway` e as vias com `cycleway`, `cycleway:left`, `cycleway:right` ou `cycleway:both`; 339 ciclovias com 134,9 km e 326 ciclofaixas com 161,6 km; 17.169 bytes), **e não dentro do pacote visual**: o SHA do `campinas_e0_vis.bin` está fixado em todas as épocas desde a 2, então mexer nele pediria época nova e faria os apps antigos recusarem o mapa. O arquivo é cenário, fora das épocas, como o de rota e o de pontos do tráfego. Com ele, os ciclistas (`world/sim/cyclists.dart`) pedalam só nas ciclovias, pela direita, e saem dos caminhos de pedestre; nascem e somem fora da vista. As ciclovias ainda não são desenhadas no mapa.
- **Dia de jogo:** o `match_utc` do `balance.json` fica vazio. O app lê os jogos do `events.json` assinado: entradas `{"kind": "match", "starts_utc": "2026-11-21T19:00:00Z"}` (o início do jogo em casa). Nas 2 h antes, os passantes tendem para o estádio do OSM. Os apps antigos ignoram o tipo que não conhecem.
- **Relevo do fallback: decidido que fica plano.** Os blocos baixados da Overpass fora das regiões com pacote não têm relevo: poças e ruas alagadas saem do sorteio pela seed, e a neblina vale igual em todo lugar.
- **Push:** regra nova no `CLAUDE.md` (push no fim de cada versão com testes passando e analyze limpo; publicar feed, `regions.json` e `docs/pages` continua pedindo autorização).

### No aparelho (2026-11-12, moto g54, APK 0.19.1+31, simulador de GPS e relógio de debug)

- **Neblina num vale de manhã:** relógio em 2026-11-13 08:50 UTC (5h50 locais), Neblina forçada, junto do lago no Taquaral: o véu preso ao mapa, em degraus de tom.
- **Poças se formando:** Chuva forçada a 10x numa esquina do Centro (o ponto baixo que o campo de água indica, 53 m a leste e 171 m ao sul do ponto do simulador): quatro capturas, do chão seco à poça cheia com a borda pontilhada, e os Ecos de Água em cima dela no fim.
- **Eco de Água na poça:** vídeo de 15 s no mesmo lugar.
- **Dilúvio no vale da Norte-Sul:** de bicicleta simulada do Centro até perto da Norte-Sul com a Orosimbo Maia (posição por estimativa, uns 1,3 km): a avenida ao lado alagada, com a borda do campo.
- **Medido no aparelho, por quadro:** tráfego 297 µs (120 carros, 70 passantes) e 113 µs (40 carros); véu da neblina 447 µs com neblina (14 µs sem); bichos e vento 73 a 87 µs. **Soma com neblina: menos de 1 ms**, contra o teto de 4 ms. Fora do quadro: bloco da cobertura (48 pixels por célula) 38,8 ms no isolate, 16 blocos na tela. **Uma vez por tile:** campo de água 12,9 a 30,1 ms, na thread do desenho (um tropeço de um ou dois quadros quando o jogador entra num tile z15 novo durante a chuva).
- **Os Ecos Agressivos abrem a folha de encontro quando o avatar chega perto**; cancelei todas sem sintonizar. O que o simulador coletou entrou como debug, fora da Bolsa.
- **Não visto:** as coisas novas de cenário desta versão (ônibus no ponto, gente no comércio e nos bares, gatos, morcegos, maritacas, fumaça, fuligem, areia, dunas andando) e os ciclistas nas ciclovias, que entraram depois das capturas.

## Fase 1 · fatia 8 · Bestiário: nove famílias novas e a tela refeita (0.20.0)

GDD rev 342. Versão 0.20.0+32, mesma chave de release. Save no schema 7.

### O que muda o mundo (época 11, começa em 2026-11-12 16:00 UTC)

- **Biomas Iluminado e Sagrado.** Não existiam nos pacotes de região (só Urbano, Verde, Água e Residencial). Entram em `shared/biomes.json` com `since_epoch: 11` e num pacote novo, `campinas_e11.bin`, gerado do mesmo extrato da época 0 (`pipeline/README.md`): Iluminado 2,0% da grade (avenidas e comércio), Sagrado 0,1% (igrejas e cemitérios). O `campinas_e0.bin` não foi tocado e sai byte a byte igual com `--epoch 0`.
- **Nove famílias** (GDD, "Famílias da fase 1"), cada uma com Fagulha, Eco e Espírito: Hum (Elétrico), Clod (Terra), Rust (Metal), Glare (Luz), Shade (Sombra), Wisp (Espectral), Bit (Digital), Sprig (Feérico) e Wyrm (Dracônico). As espécies têm `since_epoch: 11`: o que as épocas 6 a 10 geram não muda.
- **Tabelas por bioma:** nativas com peso 6 (Urbano: Soot, Hum, Rust; Verde: Frond, Clod, Sprig; Água: Rill; Residencial: Shade; Iluminado: Glare, Bit e Soot com 3; Sagrado: Wisp) e todas as outras com peso 1 em qualquer bioma. As Fagulhas seguem a mesma tabela, pelo tipo.
- **Condições por família** (`eco_v2.conditions`, `core/spawn_conditions.dart`): a hora pelo sol (dia, noite, crepúsculo real a menos de 6° do horizonte), a lua cheia (90% da face), o relevo (alto de morro e fundo de vale, a medida da neblina) e o clima multiplicam o peso da família no sorteio, no começo da janela da célula. Os números estão em `docs/clima-auditoria.md`, "Famílias da fase 1". O Wyrm tem peso zero fora dos eclipses, da chuva de meteoros e do Vento das Fendas, e só aparece para o Conjurador de nível 10 em diante.
- **Efeitos do clima que ganharam alvo:** o Eco carregado do raio é o Humoth, o do fim da Procissão é um Espectral, o pé do arco-íris dá Feérico, a cratera do meteoro dá Dracônico e Fagulhas Dracônicas; o Sol forte passa a pesar na Luz.
- **Comportamentos:** só Passivo (92) e Oculto (8).

### Sintonia

- **12 tipos** (`capture/eco_type.dart`), com a tabela de vantagens do GDD na contenção (1,5 forte, 0,66 resistido) e na tolerância (o selo de tipo ganha contra todo tipo que o dele vence; cada forte do Círculo amplia o dial). Um selo de tipo para cada um dos 12, com receita.
- **Padrões de resistência dos nove tipos novos** (`capture/type_patterns.dart`, números em `balance.json` `tuning.signal.phase1`): Terra com faixas pesadas no dial, Elétrico saltando entre 2 ou 3 frequências com arco, Metal com blindagem que só solta faísca, Luz com clarões e imagem residual, Sombra com a onda na tinta e o pulso fraco no dial, Espectral com a cópia cinza atrasada, Digital com cópias com glitch, Feérico invertendo o dial e trocando de padrão no meio, Dracônico somando um padrão a cada etapa. A mesma escala de intensidade, o mesmo teto de 20 s e as mesmas regras de lua e sobrenível dos três do MVP: com resistência forte (Conjurador 15 contra Eco 17) o jogador perfeito leva de 10 a 15 s em todos os 12 tipos.
- **Debug:** a seção Captura lista as espécies por tipo; escolher uma abre a sintonia dela.

### Bestiário

- Tela refeita como no protótipo aprovado: por família (cartão com a linha de fusão, capturada, vista ou ???, e "Família ???" antes da primeira forma), grade por camada com filtro em folha (tipo, camada, estado, só pesquisa incompleta) e busca por nome, tipo e lugar.
- **Detalhe da espécie** com quatro abas (Pesquisa, Sobre, Atributos, Sintonia), bolinhas de variante (bioma, Brilhante, Carmesim: preenchida, só contorno ou escura; tocar troca a arte), setas para a forma anterior e a seguinte, Marcar e Fundir.
- **Pesquisa em cinco níveis** (`player/research.dart`, tarefas em `creatures.json`): capturar uma vez (Lore I), ver na hora ou no clima da família (Onde aparece), capturar em dois biomas (Atributos e Lore II), achar uma variante (tolerância ×1,05 na espécie, `balance.json` `research`), capturar cinco vezes (Lore III).
- Os componentes (cartão de família, célula de espécie, folha de filtro, abas, etiqueta, botão) estão em `ui/menu/bestiary/bestiary_widgets.dart`, no tema do Design System. Os textos para revisão estão em `docs/textos-bestiario.md`.
- **Sprites provisórios** desenhados no código (`ui/sprites/phase1_masks.dart` e `phase1_sprites.dart`): uma silhueta por forma das nove famílias (Eco e Espírito) e uma Fagulha para cada uma das 12, na cor do tipo.

### Save

Schema 7: o bestiário guarda quantas capturas, quando a espécie foi vista (hora e clima) e em que biomas foi capturada; as Fagulhas coletadas entram nele. A migração v6 para v7 é pura (`save/migrations.dart`) e foi testada num save gravado pelo código da 0.19.1 (`test/fixtures/save_v6_0191.json`): as capturadas entram com as que estão na coleção (pelo menos uma), as Fagulhas da Bolsa entram como coletadas, e a hora e os biomas dos encontros antigos começam do zero.

### Restos da 0.19.1

- **Água no relevo fora da thread do desenho:** no mapa do jogo o que pesa vai para um isolate; o bloco aparece sem água até o tile chegar, e nada derivado de um tile a caminho fica guardado. A Patrulha continua calculando na hora.
- **Ciclovias desenhadas** a partir de `campinas_e0_cycle.bin`: linha de um pixel de arte, no ciano do sinal apagado (a ciclofaixa numa rua mais fraca que a ciclovia própria). Sem mudar o pacote visual nem a época.
- **Sons no zero** e sem interruptor nos Ajustes até o desenho de som.
- **Arisco e Agressivo saíram** (nas épocas antigas o sorteio é o mesmo e os dois valem como Passivo).

### Do pedido, o que NÃO entrou nesta versão

- **Habilidades de mapa sem efeito ainda** (o dado, as três faixas e o texto existem; na tela aparecem com "(em breve)"): Clod (material extra), Shade (visão à noite), Wisp (visão na neblina), Bit (Radar revela Ocultos) e Sprig (chance de variante). As de Hum (Radar), Rust (não gastar o selo na falha), Glare (tolerância de dia) e Wyrm (Essência extra) funcionam. A da Sprig mexe num sorteio do mundo (a variante sai de `hash(seed, época, célula, janela)`): do jeito que o GDD descreve, dois amigos veriam Ecos diferentes no mesmo lugar. Precisa de decisão.
- **São Paulo e o fallback sem Iluminado e Sagrado:** São Paulo segue com o pacote da época 5 (um `sao_paulo_e11.bin` precisa ser gerado e publicado no `regions.json` assinado) e os blocos do fallback seguem com os cinco biomas.
- **Becos e marquises** (Shade) e **cicatrizes de Fenda** (Wyrm): não há dado para isso.
- **"Marcar" só marca:** a forma marcada fica destacada no Bestiário; ainda não puxa nada no mapa nem no Radar.
- **A época 11 não está no feed assinado** (publicar é com o dono da chave).

### Testes

Novos: `capture/type_patterns_test` (um por padrão), `capture/eco_type_test` (a tabela dos 12 tipos na contenção e na tolerância), `core/spawn_conditions_test` (cada família nas condições dela, sem Wyrm antes do nível 10, épocas antigas iguais), `player/research_test` (pesquisa, estados, filtro, busca, bolinhas de variante), `ui/bestiary_screen_test` (as telas em 360×800, 412×915 e 480×1000), `save/migration_v7_test` e o grupo da água em fundo em `world/epoch9_world_test`.

### No aparelho (2026-11-12, moto g54, APK 0.20.0+32 com a chave de release, instalado por cima da 0.19.1)

- **Instalação:** `adb install -r` por cima da 0.19.1+31, sem desinstalar. O mapa abre com o save de antes (Conjurador no nível 13), já no schema 7.
- **Bestiário com o save real migrado:** Soot 33%, Frond 25% e Rill 25%, com as Fagulhas da Bolsa como coletadas, os Ecos e o Cinderkin capturados e os Espíritos de ritual vistos; as nove famílias novas como "Família ???" com as silhuetas; pesquisa total 7%. No detalhe do Sootling: "Capturada ×19" (os que estão na coleção), nível de pesquisa 2 de 5 ("Ver de dia" marcou na hora, com o mapa aberto), bolinhas de variante preenchidas e só com contorno, "Fundir 19/5". As quatro abas abrem.
- **Grade com o filtro:** a folha abre; com Fogo, Elétrico e Eco o botão diz "Ver 2 formas" e a grade fica com o Sootling e a silhueta do Humoth.
- **Uma sintonia de cada tipo novo pelo debug** (Captura, Eco 17 contra Conjurador 15, resistência 0,81), só capturas paradas: Humoth com o arco do salto; Pebblet com as faixas pesadas no dial; Rustling com as placas de blindagem e a faísca; Glimlet com o clarão e a imagem residual; Umbrel com a onda na tinta e o pulso fraco na borda do dial; Wisplet com a cópia cinza atrasada; Bitling com as cópias com glitch; Sprigglet com o aro do dial invertido e o pó; Wyrmlet com as escamas e a blindagem.
- **Não conferido no aparelho:** as ciclovias desenhadas e a água em fundo no mapa (não capturei o mapa, que mostra o lugar real do jogador), e nenhuma das famílias novas nascendo no mundo (a época 11 começou às 16:00 UTC, depois da sessão).
- Uma captura pegou um aviso de notificação de outro app por cima do Kenoma e foi apagada na hora; o script de captura agora descarta sozinho a captura que tiver um aviso por cima.
- A tecla voltar do Android não sai da tela de sintonia aberta pelo debug (só o "<" e o botão Menu do resultado saem).

## Fase 1 · fatia 8b · Camada pessoal de spawn e habilidades que mudam o jogo (0.20.1)

GDD rev 342 no repositório: a rev 350 não veio anexada e as duas cópias em `~/Downloads` são mais antigas que a 342, então o commit "docs: GDD rev 350" não foi feito. Os textos de Trabalho e os números das habilidades abaixo saíram do pedido, não do GDD novo. Versão 0.20.1+33, mesma chave de release. Save no schema 8. Nenhuma época nova: nada aqui muda o mundo base.

### Camada pessoal de spawn (`world/personal_layer.dart`)

- **A base não muda.** `SpawnField`, `generateCell` e as épocas ficam como estavam: os mesmos Ecos, Fagulhas, materiais e poças para todos, com qualquer Círculo (teste com todas as habilidades no máximo, de dia, à noite, na tempestade, na neblina e na chuva).
- **Por cima, só acréscimos:** Ecos (três vagas por célula z20 e janela: Hum, Shade, Wisp), poças do Rill, material a mais do Clod, chance de variante (Sprig) e de Oculto (Bit) nos Ecos da própria camada. Os uids são outros e nada da base sai.
- **Estável:** os sorteios saem de `FNV(seed, player_id, época, célula, janela)` e sempre na mesma ordem, nasça algo ou não. A build só decide se cada vaga nasce e com que chance: a faixa maior de uma habilidade só acrescenta ao que a menor dava, e voltar a uma build dá o mesmo resultado. Decisão de implementação: a build não entra no hash (o pedido falava em "conta mais player_id e build"); assim trocar de build não sorteia de novo, que é o que a regra da janela seguinte protege.
- **Troca de Círculo vale na janela seguinte** de cada célula: o save guarda as builds com o instante de início (`personal_builds`, as de mais de um dia saem) e cada célula usa a do começo da janela dela. A primeira build vale desde sempre.
- **Postes e marquises** vêm dos pontos do OSM do tráfego (`campinas_e0_traffic.bin`, cenário, fora das épocas): semáforos e pontos de ônibus são postes; comércio, bares e restaurantes são marquises. Becos não estão no dado. Onde não há arquivo de pontos (São Paulo, fallback), Hum e Shade não acrescentam nada.
- Números em `balance.json` `personal_layer` (noite com o sol abaixo de -6°, climas da tempestade e da neblina, o Sagrado, rastros do Wisp ×1,5, +2 de Essência do Bit) e as faixas em `creatures.json`.
- **Marcados:** `WorldSpawn.personal`, e no save a criatura capturada e a marca guardam `personal` e `hidden`. No mapa são iguais aos outros.
- **Debug** (Spawns, "Camada pessoal de spawn"): interruptor que esconde a camada (o mapa fica só com a base), o contador da sessão (Ecos, poças e materiais) e um Círculo de teste só no mapa (nível 10, sem mexer no save).

### Habilidades de mapa (todas com efeito; nenhuma "em breve")

| Família | Habilidade | Eco (faixas 1-9, 10-19, 20) | Espírito |
| --- | --- | --- | --- |
| Soot | Aura maior | 3, 5, 8 m | 5, 8, 11 m |
| Frond | Coleta mais longe | 3, 5, 8 m | 5, 8, 11 m |
| Rill | Na chuva, poças a mais por célula z17 (~300 m), com a chance de Eco de Água da poça | 1, 2, 3 | 2, 3, 4 |
| Hum | À noite e na tempestade, Eco Elétrico a mais junto do poste | 10, 15, 20% | 15, 20, 25% |
| Clod | Uma unidade a mais do material coletado | 5, 10, 15% | 10, 15, 20% |
| Rust | Não gastar o selo na falha | 5, 10, 15% | 10, 15, 20% |
| Glare | Tolerância de dia | 3, 5, 8% | 5, 8, 11% |
| Shade | À noite, um Eco a mais sob a marquise (da tabela do bioma) | 10, 15, 20% | 15, 20, 25% |
| Wisp | Na neblina e no Sagrado, Eco Espectral a mais; rastros do Radar ×1,5 | 10, 15, 20% | 15, 20, 25% |
| Bit | Oculto a mais nos Ecos da camada pessoal; +2 Essência ao destilar um que era Oculto | +5, 10, 15% | +10, 15, 20% |
| Sprig | Variante a mais nos Ecos da camada pessoal | +5, 10, 15% | +10, 15, 20% |
| Wyrm | Essência na destilação | +1, 1, 2 | +1, 2, 2 |

O Rill perdeu o alcance do rastreador e o Hum o do Radar (o Radar volta a ser só o padrão). O efeito aparece por extenso, com a faixa atual e a próxima, na aba Atributos do Bestiário (a faixa da criatura da espécie de nível mais alto na coleção) e no Círculo (um parágrafo por membro).

### Trabalho das criaturas

Só texto, na aba Atributos: "Trabalho: forja e fornalha (em breve)" e uma frase, por família (`creatures.json`, `families[].work`). **Os textos são provisórios** (escritos a partir das estações e altares do GDD rev 342): trocar pelos do GDD rev 350 quando ele chegar.

### Marcar

Até 3 espécies marcadas no Bestiário (`bestiary_pins`; a quarta é recusada com aviso; "Desmarcar" no mesmo botão). A marca aparece no cartão da família e no detalhe. No mapa, os Ecos marcados ganham cantos e uma seta em ciano; os spawns passam a ser gerados até o alcance do Radar (250 m) quando há marcadas, mas só as marcadas aparecem além da visão. Fora da tela, uma seta fica na borda apontando para elas, sem precisar de pulso. No Radar, um losango no ponto certo, também sem pulso. Na Patrulha, cada Eco marcado que entra no alcance do Radar dá um aviso ("Marcada no Bestiário: Humoth a 180 m, na R. ...") e a vibração de raro, uma vez por Eco. Os Ocultos marcados só aparecem depois de revelados.

### São Paulo

`sao_paulo_e11.bin` gerado com Iluminado (2,7%) e Sagrado (0,3%), SHA no `pipeline/README.md`. **Não publicado e não listado em nenhuma época:** a época 11 já começou, então ele só pode entrar numa época 12, que pede autorização.

### Save

Schema 8 (`save/migrations.dart`): a marca única `bestiary_pin` vira a lista `bestiary_pins`; as builds e a origem dos spawns são campos novos e opcionais. Testado com um save gravado pelo código da 0.20.0 (`test/fixtures/save_v7_0200.json`).

### Testes

Novos: `world/personal_layer_test` (base idêntica com e sem build, poças do mundo iguais com e sem Rill, estabilidade por jogador, build e janela, troca de Círculo só na janela seguinte, cada habilidade nas três faixas com cada faixa contendo a anterior, o interruptor e o contador), `save/migration_v8_test`, o grupo das marcadas em `world/world_view_test` (mapa, Radar, borda) e em `patrol/patrol_engine_test` (aviso uma vez por Eco). O teste do pacote adulterado em `ui/map_screen_test` fixa um instante da época 10 (falhava desde que a 11 começou, por usar o relógio de verdade). `ui/game_map_screen_test` "um Eco oculto forçado..." falha de vez em quando também na 0.20.0 (depende do relógio de verdade): ficou como estava.

### No aparelho (2026-11-13, moto g54, APK 0.20.1+33 com a chave de release, instalado por cima da 0.20.0)

- **Instalação:** `adb install -r` por cima da 0.20.0+32. O save migrou para o schema 8 e a marca que já existia (Ember Mote) continuou marcada.
- **Camada pessoal:** simulador no Centro, relógio de debug em 2026-11-14 01:30 UTC (22h30 locais), clima real (Vigília), Círculo de teste com Shade, Wisp e Sprig. O contador do debug deu 6 Ecos acrescentados na primeira passada (8 depois de reabrir o mapa). Na mesma célula, com o interruptor ligado, o Eco roxo do canto some e o verde (da base) fica no mesmo lugar.
- **Marcar:** Sootling e Frondling marcados (com o Ember Mote, três: as três marcas aparecem nos cartões, e o botão vira "Desmarcar"). No Radar, dois losangos sem pulso, a uns 190 m e 250 m. No mapa, setas na borda para os de fora da tela; de bicicleta simulada até um deles, os cantos e a seta em ciano em volta do Sootling. As duas marcas de teste foram tiradas no fim.
- **Círculo:** o parágrafo por membro, com a faixa atual e a próxima (Rillet, Frondling, Cinderkin do save real).
- **Não conferido no aparelho:** o aviso da Patrulha (só em teste), as poças do Rill (não choveu, e não forcei chuva) e o Hum (não estava no Círculo de teste). Também não conferi as pendências do pedido: uma família nova nascendo no mundo, as ciclovias desenhadas e a água fora da thread de desenho no mapa.
- O APK instalado ainda chama os chips do Círculo de teste de "Real" e "Vazio". Depois do build, eles viraram "Círculo real" e "Círculo vazio" por causa de um teste.

## Fase 1 · fatia 8c · GDD rev 350, época 12 com São Paulo e becos (0.20.2)

GDD rev 350 (commit próprio). Versão 0.20.2+34, mesma chave de release. Save no schema 8 (sem mudança).

### Do GDD rev 350

- **Habilidades com os números do GDD:** Rill +1, +2, +3 poças por célula z17 (como estava); **Hum e Wisp agora contam por hora**: N Ecos (Elétricos junto de postes, à noite e na tempestade; Espectrais numa célula com neblina ou no Sagrado) por bloco z17 (uns 300 m) e por hora UTC, cada um valendo a hora inteira; a faixa sai da build do começo da janela de 20 min do bloco (a troca do Círculo entra em até 20 min e a faixa maior só acrescenta vagas). **Shade** 5, 10 e 15% por célula e janela, em becos e sob marquises. **Sprig** de volta a +2, +4 e +6%. Bit e Clod como estavam. Os Espíritos ficam um degrau acima (`spirit.ability_steps`).
- **Trabalho** com o texto da tabela do GDD ("Trabalho: forja e fornalha (em breve)" e a frase depois dos dois-pontos; Rill e Glare não têm dois-pontos e ficam só com o título).
- A build continua fora do hash (aprovado).
- Os dados foram gravados pelo agente `conteudo` (novo fluxo do `CLAUDE.md`).

### Época 12 (pronta, não publicada; começa 2026-11-16 16:00 UTC)

- A 11 com `sao_paulo_e12.bin` (Iluminado 2,7%, Sagrado 0,3%) e `traffic_packs` novos, os pontos do OSM com **becos** (tipo 11): `highway=service` + `service=alley` e `footway`/`path` com prédio dos dois lados a até 9 m. Campinas: 2.845 becos (`campinas_e12_traffic.bin`, no APK); São Paulo: 51.184 (`sao_paulo_e12_traffic.bin`, baixado por `route_files.traffic`). Os tipos 0 a 10 saem iguais aos da época 0. SHAs no `pipeline/README.md`.
- O app: cada região leva os pontos dela (`LoadedRegion.traffic`, `LayeredWorld` como fonte de pontos), então a simulação do tráfego e a camada pessoal (Hum e Shade) passam a funcionar em São Paulo. O arquivo baixado só vale se a época vigente listar o mesmo nome e SHA-256.
- `scripts/assinar_regioes.py` lê os nomes da época (a 12 reaproveita o visual, o de caminhos e o de rota da 5) e aceita `--out`. Rascunho assinado do catálogo em `pipeline/out/regions/rascunho-e12/`. Passos de publicação em `docs/assinatura.md`, "Época 12": **o feed, o catálogo, o release `regions-e12` e o APK precisam sair antes do início**, senão quem tem São Paulo cai no fallback e quem não tem a época vê outro mundo.

### Testes

Novos: `data/traffic_e12_test` (época 12, pontos iguais aos de antes mais os becos, a época escolhe o arquivo), grupo "pontos do OSM" em `net/region_manager_test` (com uma fixture assinada nova, `test/net/fixtures/region_traffic`, chave de teste descartada), Hum e Wisp por hora e Shade em becos em `world/personal_layer_test`.

### No aparelho (2026-11-13, moto g54, APK 0.20.2+34 com a chave de release, instalado por cima da 0.20.1)

- **Instalação:** `adb install -r` por cima da 0.20.1+33; o save abriu igual (schema 8).
- **Famílias novas nascendo** (época 11, simulador no Centro, Chuva forçada): um Eco de Terra nível 14 (o bicho de cascalho redondo) e outro de uma família nova, verde, nível 14.
- **Ciclovias desenhadas:** a linha em ciano na margem da avenida, com os carros e os ônibus passando ao lado.
- **Poças do Rill:** Círculo de teste com Rill e Hum, relógio de debug 34 min à frente (a troca vale na janela seguinte) e o clima a 60×. O contador do debug deu **18 poças da camada pessoal** na sessão, mas nenhuma caiu na tela em duas voltas de bicicleta simulada (são 2 por bloco de uns 300 m no nível 10, e a tela tem uns 50 m). **Não vi uma poça desenhada nem a água do relevo:** parei depois de duas tentativas, como pede o `CLAUDE.md`. Para conferir, falta um jeito de achar uma poça (por exemplo, uma marca de debug no mapa nas poças da camada pessoal).
- O Hum não apareceu porque era dia (13h45 no relógio do jogo).

## Fase 1 · fatia 8d · Poças do Rill por célula z18, marcador de poças e GDD rev 352 (0.20.3)

GDD rev 352 (commit próprio; a seção nova, Obras no mundo, é da fase 2). Versão 0.20.3+35, mesma chave. Save no schema 8 (sem mudança). As mudanças de agentes (`CLAUDE.md`, `.claude/`) foram num commit separado.

- **Rill:** as poças da camada pessoal agora são por **célula z18** (uns 150 m), **2, 4 e 6** por célula nas três faixas, com **25, 35 e 45%** de chance de Eco de Água em cada uma. Os números estão no `balance.json` (`personal_layer.rill_bands`); a habilidade guarda só a faixa (o Espírito, um degrau acima, fica na última). Cada poça tenta até 8 pontos da célula até um cair na rua ou na calçada (a máscara do que se anda); se nenhum cai, ela não nasce. Continua estável por jogador, build, célula e janela de chuva, e a faixa maior só acrescenta.
- **Marcador de poças (debug, Spawns, "Poças no mapa"):** um alvo em cada poça na tela, laranja nas da camada pessoal (Rill) e ciano nas do mundo (água do relevo, ou o sorteio pela seed onde não há relevo). Botão **"Ir até a poça mais próxima"** (no item do debug e na folha do simulador): liga o GPS simulado sem recompensa e leva até a poça mais próxima a até 1 km.
- **Água do relevo na chuva forçada:** o cálculo fora da thread do desenho foi conferido em teste com a chuva e o Dilúvio forçados (Taquaral, Centro e o vale da Norte-Sul): o bloco começa seco, o tile fica pronto, quem desenha é avisado (`onTile`, `revision`) e as poças saem iguais às do cálculo na hora. Nenhum bug encontrado no código; falta ver no aparelho com o marcador.

### Testes

Novos: Rill por célula z18 em `world/personal_layer_test` (contagem por célula, toda poça no caminho, cada faixa contendo a anterior, a chance de Eco de cada faixa, os números do `balance.json`), `world/water_rain_test` (chuva e Dilúvio forçados com o cálculo em fundo) e `dev/puddle_debug_test` (poça mais próxima, o botão, o marcador). Suíte: 1812 passam, 4 pulados; `flutter analyze` limpo.

### No aparelho

Pendente: o celular estava desconectado. Falta, com o marcador ligado e numa chuva forçada, capturar as poças pessoais e as do relevo (e o Dilúvio num lugar baixo), e o Hum à noite numa rua com postes, com tempestade forçada.

### Depois do pedido de 2026-11-15

- **Época 12 adiada** para **2026-12-07 16:00 UTC** (era 2026-11-16), sem publicar nada. O `valid_until_utc` continua 2027-02-14.
- O celular sai do desenvolvimento por algumas versões: os testes da 0.20.3 no aparelho vão para o checklist da versão seguinte.

## Fase 1 · fatia 8e · Agentes, emulador, workbench e checklist do celular (0.20.4)

GDD rev 353 (commit próprio: o emulador conta como GPS simulado). Versão 0.20.4+36. Esta versão foi feita no notebook, sem o celular: **o build de release e a instalação no moto g54 ficam para o PC** (a chave de release está no notebook por decisão do usuário, mas aqui só entraram builds de debug, no emulador). Save no schema 8 (sem mudança).

### Sobras da 0.20.3, conferidas no emulador

- **Poças do Rill e da água do relevo:** com o marcador ligado e chuva forçada perto da Lagoa do Taquaral, alvos laranja nas poças do Rill (na rua, com Eco de Água) e ciano na poça do relevo (a baixada de 10 m da rua ao norte da lagoa). **Não era bug:** no celular eu não estava numa baixada, e na build de debug o tile da água leva alguns segundos para ficar pronto (no parque, sem rua por perto, as poças do Rill não têm onde cair). O cálculo em fundo foi conferido também em teste.
- **Dilúvio na Norte-Sul:** a rua alaga no fundo do vale (perto da Orosimbo Maia), com a borda do campo.
- **Hum à noite** (relógio do debug às 23h, tempestade forçada), no Centro: os Humoths da camada pessoal nos semáforos. Duas vagas da mesma hora caíam no mesmo poste: agora cada vaga pega um poste livre.
- **Época 12** adiada para 2026-12-07 16:00 UTC (na versão anterior). **Trava nova** (`test/release_guard_test.dart`): uma época que usa um pacote obrigatório (lógico, visual ou de caminhos) que não está no APK nem no `regions.json` publicado tem de começar daqui a pelo menos 7 dias; senão o teste falha, e o build de release, que pede os testes passando, também. A época 12 passa hoje e começa a falhar em 30/nov se o `sao_paulo_e12.bin` não for publicado. O relevo de São Paulo (opcional, não publicado desde a época 10) não trava.

### Agentes (commit próprio)

`testador` (haiku, effort low, proativo, só leitura), `criativo` (fable, effort medium, proativo; edita só `docs/textos-*.md`, `app/lib/ui/sprites/` e `tools/art/`, com um hook que recusa o resto) e `conteudista` (haiku, effort medium, só quando chamado; edita só `app/assets/data/`, menos `epochs.json`, e `workbench/catalog/catalog.json`). O revisor contra o GDD saiu: a thread principal relê as seções citadas antes de fechar cada versão. Thread principal em Opus (`.claude/settings.json`).

### Emulador (`docs/emulador.md`)

- `scripts/emulador/setup.sh` (KVM, SDK, imagem `android-34;google_apis;x86_64`, AVD `kenoma_g54` 1080×2400, 400 dpi, 4 GB; nada precisou de sudo), `iniciar.sh` (NVIDIA por PRIME, Intel, software; subiu na Intel, a NVIDIA deu falha de segmentação com o driver fora de versão) e `rota.py` (GPX a 1,4 m/s pelo `adb emu geo fix`; rotas públicas do OSM: volta da Lagoa do Taquaral 2,7 km, Rua 13 de Maio 1,6 km, Avenida Paulista 810 m; `--fixo=lat,lon`).
- **O emulador conta como GPS simulado** (GDD rev 353): `isPhysicalDevice` do `device_info_plus` (já era dependência transitiva, agora direta); sem o interruptor de recompensa, nada que se pega conta. Conferido no emulador: "+1 Pó de Essência de Planta (debug, fora da Bolsa)". A Patrulha com o GPS do emulador nunca dá recompensa.
- **Hashes das camadas** no debug ("Camada pessoal de spawn"): célula, janela, época, `base` e `pessoal`. O teste de dois aparelhos de verdade entra no checklist do celular.
- A build de debug leva x86_64. Só builds de debug entraram no emulador; nada foi instalado no celular.

### Workbench (`docs/workbench.md`)

- A skill ficou só neste repositório (`.claude/skills/game-workbench/`), com a descrição sem a ordem de se ativar sozinha, sem Vercel, `deploy.py`, `push.py`, `references/hosting.md` e `grades.json`; a aba Ratings e o card de nota independente saíram da página. O servidor escuta só em localhost; o acesso de fora é pelo `tailscale serve` (pede uma vez `sudo tailscale set --operator=$USER`). O HTTPS da tailnet já estava ligado.
- Tema do Design System (violeta, ciano, laranja, Silkscreen nos títulos e Pixelify Sans no texto, servidas do próprio repositório).
- **Catálogo** (`workbench/capture/catalogo.py`, lendo os dados do jogo e o que o `flutter test test_workbench/render_sprites_test.dart` exporta com as funções do jogo): 255 formas e variantes (sprites em PNG nos tamanhos do Bestiário e do mapa), 24 habilidades com as três faixas, 44 climas (filtro nativo, outras regiões, místico), 29 eventos, 25 datas do Calendário do Véu, 7 biomas, 7 materiais, 5 veículos do Modo Viagem (os "veículos especiais do tráfego" do GDD são da fase 2 e não existem no jogo) e 13 apps do celular, mais a aba Checklist. Climas capturados pela Simulação de clima do debug (1 min por clima, 60×) no Centro; biomas numa célula de cada um, com o clima Limpo.
- **O que ficou de fora ou errado** (conferido pelo `criativo` nas folhas de contato): os climas cuja peça anda ou depende da hora não aparecem na foto do Centro de dia (arco-íris, tornado, Procissão da Neblina, Vigília, Maré do Véu, olho do furacão, Frio, que só pinta de manhã); os eventos de noite estão com a foto de dia; Lua Carmim e Os Que Escutam não têm clima fixo nos dados (vêm do feed) e ficam sem imagem; Residencial e Iluminado mal se distinguem do Vazio e do Urbano no chão. Decisões de arte para o `criativo`: o Brilhante fica igual à variante Iluminada, e várias variantes têm o tom da própria cor da base (Frond Verde, Rill Aquática, Hum Iluminada...), então somem.
- **Clipes** (`adb screenrecord`, ~10 s): andando com tráfego, chuva formando poças, neve, Hum à noite e a navegação do Bestiário. Nenhuma sintonia.
- **Números** só medidos: custo por quadro (moto g54 da 0.19.1, do registro, e emulador marcado como emulador), Ecos à vista por faixa de nível, poças do Rill por célula z18 (1,99, 3,99 e 5,99 de 2, 4 e 6 pedidas) e o tamanho do APK.
- **Notas:** o servidor recebe e grava no `notes.json` (teste em `workbench/test_server.py`); nenhuma nota do usuário chegou nesta versão.

### Checklist do celular (`docs/checklist-celular.md`)

Cumulativo desde a 0.20.2 (a que está no celular), com as pendências da 0.20.0 e da 0.20.1, sem as famílias novas e as ciclovias (confirmadas). Regra no `CLAUDE.md`. Também é a aba Checklist do workbench.

### Testes

Novos: `test/dev/emulator_test` (emulador sem recompensa), `test/world/layer_hash_test` (base igual, pessoal diferente), `test/release_guard_test` (trava da época), `workbench/test_server.py` (notas, localhost, fontes, sem Ratings) e o teste dos postes distintos do Hum. Suíte: 1818 passam, 4 pulados; `flutter analyze` limpo.

### Conhecido

- Uma vez, ao abrir o mapa do jogo pelo menu de debug aberto de dentro do mapa (o que empilha dois mapas), a build de debug mostrou "setState() or markNeedsBuild() called during build" no `GameMapScreen`. Não se repetiu na mesma posição; fica anotado.
- **Falta:** o APK de release 0.20.4 no PC e a instalação no moto g54, e o checklist inteiro no celular.

## Fase 1 · fatia 8f · Clima e evento em camadas, laboratório visual e variantes legíveis (0.21.0)

GDD rev 356 (commit próprio). Versão 0.21.0+37, save no schema 9. Feita no notebook, só com builds de debug no emulador; o celular continua fora e o que só dá para ver nele foi para o `docs/checklist-celular.md`.

### Clima e evento em camadas (época 12)

- A mudança entrou na **época 12**, que ainda não foi publicada (começa 2026-12-07 16:00 UTC); as épocas 0 a 11 ficaram idênticas (conferido bloco a bloco). Não foi preciso abrir a 13.
- O clima é um de cada vez; até dois eventos por cima, com duração própria e uma agenda por região z12 e dia (`app/lib/core/climate_events.dart`). O terceiro espera a vaga (prioridade feed, astronomia, calendário, sorteio); o evento sem o requisito (dia, noite, clima) espera. A pilha `clima+evento+evento` monta uma definição só: peças do clima com os fluxos de sempre, peças do evento com fluxo próprio, spawn somado com teto de +++ (3,0) e piso de 0,3, modificadores juntos. A camada base sai da pilha.
- Reclassificação pelas tabelas do GDD: 13 climas viraram eventos com o mesmo id; a Chuva Carmim e a Garoa Prismática viraram o tingimento dos eventos Lua Carmim (`crimson_moon`) e Prisma do Véu (`veil_prism`). As três combinações (Vigília com Tempestade, Lua Carmim com Tempestade, Aurora com Neve) e nada além. As poças vermelhas e o raio da Lua Carmim dão Carmesins de verdade (variante no `PieceSpawn`).
- Dados: os climas e os eventos em blocos separados da época 12 (`climates`, `events`, `combos`) e o visual em dois arquivos (`clima.json`, `eventos.json`). Detalhes, decisões e a tabela de cada evento em `docs/clima-auditoria.md` ("Clima e evento em camadas").
- O clima do calendário e do feed ganha do Open-Meteo; os eventos do mundo ficam por cima do clima da rede.
- App Céu: clima e eventos ativos separados, os eventos de cada janela e os três próximos itens do calendário do Véu, marcados como clima ou evento. Debug: "Eventos forçados" (até dois, independentes do clima) e a linha da pilha nos avisos do mapa.
- Save 8 → 9: as marcas `climate:crimson_rain` e `climate:prismatic_drizzle` do Bestiário viram o evento e o clima embaixo; a pesquisa do Wyrm pede a Lua Carmim.

### Laboratório visual (debug)

- "Laboratório visual" em Mapa e câmera: o quarteirão da Praça Ramos de Azevedo (OSM, `app/assets/lab/centro_bloco.json`: praça, comércio nas avenidas, casas), com antes e depois, hora, giro, clima e até dois eventos, e o custo do quadro. Nada entra no mapa principal até a aprovação.
- O `criativo` conduziu: `docs/art/estilo-mapa.md` (paleta, pixel de 3 dp, regras de cada elemento e onde mora o céu dos eventos) e `app/lib/ui/sprites/map_style.dart` (paleta, chão por bioma com pontilhado, carimbos, paredes e telhados por tipo, curva de luz, céu). O renderizador (`app/lib/ui/lab/`) faz a altura falsa do GTA 2 a partir do centro da tela (funciona girando), a sombra pelo sol de verdade (`sunAzimuthDeg`, com teste), a sombra sobre o telhado vizinho, quintal e muro no Residencial, piso claro e neon no Iluminado, terreno baldio no Vazio, árvores, postes e, à noite, poças de luz, janelas e neon. A faixa do céu no topo leva o sol, a lua, as nuvens e a parte de céu dos eventos.
- O Blender e o Aseprite não foram usados: o `criativo` não tem acesso ao MCP e a arte saiu como dado de pixel em código, renderizada pelo jogo.
- **Desempenho no emulador** (build de debug, só a comparação vale; custo de desenhar o quarteirão, a média de 60 quadros): antes 1,1 a 1,3 ms; depois 37,6 ms de manhã, 38,6 ms ao meio-dia, 38,3 ms à noite e 41,2 ms com Vigília e Tempestade. O laboratório redesenha o quarteirão inteiro a cada quadro (gravação e `toImageSync`); se o estilo for aprovado, o mapa precisa guardar a cena parada e só refazer quando a câmera muda. A medida no celular está no checklist.

### Variantes legíveis

- `app/lib/ui/sprites/variant_art.dart` (`criativo`): cada variante muda o valor do corpo e ganha um acessório (Urbana: abafadores; Verde: broto e pintas; Aquática: listras e pingos; Residencial: telhado; Iluminada: tubo de neon; Sagrada: véu e auréola; Carmesim: chifres; Brilhante: risco e estrela). Só o Brilhante tem brilho animado. O mapa usa a arte da variante no lugar do tom por cima.
- Folhas de contato (cor e cinza) em `workbench/catalog/variantes_cor.png` e `variantes_cinza.png` (`test_workbench/variant_sheet_test.dart`).
- **Pendente (arte):** em alguns sprites a auréola encosta na cabeça (Rill, Frond e outros que tocam o topo do quadro) e alguns acessórios se confundem com antenas ou orelhas (lista do `criativo` no resumo da versão). A saída recomendada é baixar o corpo desses sprites 2 a 3 px.

### Bug do debug

"Abrir mapa do jogo" e a volta da Patrulha passam por `openGameMap`: com um mapa na pilha, volta até ele; com um mapa ainda saindo, espera ele fechar. O redesenho pedido pelo `DevTools` no meio de um build fica para depois do quadro. Teste em `test/ui/tuning_menu_test.dart`.

### Workbench

Fotos novas dos eventos e das combinações no estado certo (`workbench/capture/eventos.py`: noturnos à noite, o Frio de manhã, os que se movem em GIF, a Lua Carmim e Os Que Escutam forçados pelo debug); abas de clima e de evento separadas; biomas com o mapa de hoje e a cena do laboratório lado a lado; formas com a arte nova da variante e as duas folhas de contato.

### Testes

Novos: `test/core/climate_layers_test` (Vigília e Tempestade juntas na sexta-feira 13; arco-íris só na passagem de chuva ou garoa para sol, de dia; Tornado só com Tempestade ou Vendaval; Lua Carmim tingindo a chuva e só no céu com sol; o terceiro evento esperando; teto da soma; as três combinações; a mesma pilha dando a mesma camada base), `test/save/migration_v9_test` (save v8 da 0.20.x), `test/world/lab_block_test`, `test/ui/visual_lab_test` (laboratório e os dados de arte do `criativo`), o teste do bug em `test/ui/tuning_menu_test` (o menu agora limpa o cache de assets entre testes: dois testes abrem o mapa) e o azimute do sol em `test/core/astro_test`. Suíte: 1838 passam, 4 pulados; `flutter analyze` limpo.

### Conhecido

- Fotos do workbench: os que se movem (funil do tornado, Procissão, Vigília, Maré do Véu) foram capturados em GIF no Centro, mas a peça que anda nem sempre cai no quadro; o arco-íris é a captura com o GPS simulado levado ao pé. A Chuva de meteoros ficou de dia: o relógio do debug não pegou nas duas tentativas do script.
- O Céu e o calendário mostram o modelo da época vigente: até 7/dez, a 11, onde os eventos ainda são climas.

## Fase 1 · fatia 9 · O estilo do laboratório vira o mapa (0.22.0)

GDD rev 358 (commit próprio: o requisito do Tornado, as cores do mundo e o parágrafo dos dois estilos gráficos depois da Câmera). Versão 0.22.0+38, mesma chave, save no schema 9 (só preferências novas nos Ajustes). Feita no notebook, com o emulador; o celular não estava ligado, então os números em profile foram para o checklist.

### Sobras da 0.21.0

- **Criativo com Aseprite e Blender:** as ferramentas dos dois servidores MCP (escopo do usuário, valem neste repositório; os dois respondem) estão na lista do `.claude/agents/criativo.md`, nomeadas uma a uma, mais o `ToolSearch` (as ferramentas MCP chegam adiadas). A definição do agente só é relida no começo da sessão: nesta, o `criativo` ainda não as via, e a arte saiu como dado de pixel em código. O addon do Blender está um protocolo atrás (15 contra 16): `uvx mcp-for-blender install-addon` e reiniciar o Blender.
- **Olhos da Vigília vermelhos** (`#f02a3a`, escolha do `criativo`): a camada `eyes`, o chão do evento, o olhar (`gaze`) e o raio da Vigília. `docs/art/estilo-mapa.md`: o ciano é o sinal das ferramentas e o violeta é o jogador; nenhuma ameaça do Véu usa os dois.
- **Tornado do calendário traz o Vendaval** pela duração dele (`calendar_climate` no evento; o calendário que pede o Tornado vira Vendaval no `resolve`). Pelo sorteio continua pedindo Tempestade ou Vendaval. Isso muda o mundo: entrou na **época 13** (cópia da 12 com essa regra, início 2026-12-14 16:00 UTC). A 12 não mudou; como a Estação Seca do Véu é em agosto e setembro, as duas só diferem a partir de agosto de 2027.
- **Auréola da Sagrada:** o `criativo` baixou o corpo de 9 sprites (2 a 5 px) e redesenhou o Frondling (4 linhas a menos de folha); 10 formas não cabem sem redesenhar a máscara e ficaram com auréola fina de 1 px.
- **Workbench:** item de debug "Câmera segue a peça" (a câmera do mapa vai até a peça do clima que anda mais perto e a acompanha); `workbench/capture/eventos.py` liga o item nos GIFs. O relógio da Chuva de meteoros não era do app: o script tocava antes de o menu da build de debug abrir. Agora ele espera o menu e confere o "(OVERRIDE)" antes de seguir.

### O estilo novo (com o `criativo`)

- `app/lib/ui/sprites/map_style.dart`: paredes sempre mais escuras que o telhado (escada de valor por estilo), telhados por variante (`roofVariantsFor`: laje clara, fibrocimento, metal raro, duas cerâmicas, manta, ardósia), platibanda, caixa d'água, ar-condicionado e antena, `floorPx` para as janelas por andar, calçada portuguesa (`sidewalk_mosaic`), ponto de ônibus, banca, faixa de pedestre, portão, três árvores e o ipê em três carimbos com `ipeStamp` (roxo em junho e julho, amarelo em agosto e setembro), `sceneLightSplit` (quente no lado iluminado, frio na sombra), asfalto molhado com brilho e reflexo dos postes, névoa do horizonte, neve no telhado e `fineStamps`. As regras em `docs/art/estilo-mapa.md` ("0.22.0: do laboratório para o mapa").
- O Laboratório visual usa o mesmo renderizador do mapa no "depois"; o "antes" é o Simplificado.

### Prédios e árvores do OSM

`pipeline/build_buildings.py` grava `campinas_e0_bldg.bin` (32.116 prédios, 1.760 árvores, 417 KB, no APK; fora das épocas, como as ciclovias). O de São Paulo (2.199.471 prédios, 29 MB) saiu em `out/regions/` e **não vai ser publicado ainda**: o leitor guarda todos os prédios na memória, o que passaria de centenas de MB no celular; o app recusa arquivo de prédios acima de 4 MB. O app já sabe baixar e conferir `route_files.buildings`; falta um formato por tile, lido sob demanda. Até lá São Paulo sai no estilo Completo sem prédios. **A cobertura de prédios do OSM em Campinas é irregular**: há quarteirões cheios (a Praça Ramos de Azevedo tem 149 prédios em 380 m) e trechos do Centro quase vazios (9 prédios a 176 m do ponto de teleporte "Centro"). Onde não há prédio, o estilo novo mostra o chão, as ruas e as árvores.

### Giro: o que estava errado e o que mudou

- **O que girava errado.** No mapa antigo, o ruído do chão era uma textura girada como imagem e reamostrada a cada quadro: pixels tortos e serrilhado misturado. No laboratório, os módulos de chão e de telhado só eram transladados: ao girar, o desenho do piso escorregava por cima do chão, e o quarteirão inteiro era refeito em ângulo contínuo a cada quadro, então os pixels tremiam no giro.
- **O que mudou** (`app/lib/ui/city/`): o chão (ruas, lotes, grama, calçada, faixas, sombras, a planta dos prédios) é rasterizado já girado, na grade da tela, em blocos de 4 × 4 células z21 guardados em cache. No arrasto e na pinça os blocos ficam no ângulo mais próximo (passos de 3 graus) e no zoom do começo do gesto; um quarto de segundo depois de soltar, são refeitos no ângulo e no zoom exatos e só deslizam por pixels inteiros (teste: `onGrid`). Os blocos se sobrepõem 1 pixel de arte, com pixels iguais, para a emenda nunca abrir. Tudo que tem altura (árvores, postes, props, props de telhado, janelas, paredes, letreiros) é desenhado de pé, na tela, a cada quadro; paredes e telhados saem do centro da tela para fora em qualquer giro.

### Desempenho

- Tipo de build marcado em todo número: o laboratório escreve "DEBUG, NÃO VALE" / "PROFILE" / "RELEASE" no custo do quadro; o Debug, Desempenho, mostra o custo do mapa (chão, blocos refeitos, o que fica de pé, partículas) com a build; o `workbench/numbers.json` e o checklist dizem a build de cada número. A build de profile agora sai com a chave de release (`android/app/build.gradle.kts`): instala por cima da dos amigos sem apagar o save.
- **Cache:** o chão é refeito só quando o bloco entra na tela, o giro ou o zoom de alvo mudam, a luz muda de faixa (3 graus de altitude ou 5 de azimute do sol), a chuva molha o asfalto ou muda o nível de detalhe; no máximo 4 ms de blocos por quadro, os que faltam primeiro. O que fica de pé é refeito a cada quadro numa camada pequena (pixels de arte); a faixa do céu fica numa imagem.
- **Zoom aberto** (mais de 65 m de tela, o que inclui o zoom do debug): sem flores, tufos, props de telhado, antenas, janelas, letreiros, faixas e portões, metade do pontilhado; o tráfego e os passantes a mais de 40 m do jogador andam no passo maior.
- **Efeitos:** um orçamento de partículas só (`particle_cap`), dividido entre o clima e os dois eventos na proporção do pedido de cada camada (antes a primeira levava tudo); as camadas de tela em meia resolução, esticadas; o Simplificado usa metade.
- **Perfil no celular:** não foi feito (o moto g54 não estava ligado). O passo a passo em profile, com o que anotar, está no checklist (`0220-perfil-antes-depois`). A meta de 16 ms em profile fica sem número até lá.

### Mapa

- Completo é o padrão em todos os biomas; o estilo antigo é o Simplificado (Ajustes, "Gráficos do mapa"), trocado na hora, com a mesma lógica, a mesma máscara de ruas e a mesma camada base. Com o Completo acima de 20 ms por quadro em média por um minuto, um aviso sugere o Simplificado uma vez só (`StyleAdvisor`, guardado nos Ajustes).
- Ordem nova (`draw_order.dart`, `docs/clima-auditoria.md`): tráfego, depois prédios e o céu, depois o alcance e o que é do jogo. O telhado ou a copa sobre o Conjurador, um Eco, uma Fagulha ou um material fica translúcido. A neve e a geada acumulam também nos telhados, na posição deslocada; poças, alagamento e dunas continuam no chão (o mesmo `climateGround`, com a mesma câmera: a máscara de ruas e o campo de água não mudaram).
- O Vazio cercado de cidade usa o chão dos vizinhos (só desenho). O céu do horizonte ocupa 6% da tela, com a névoa de distância embaixo.

### Testes

Novos: `test/ui/city_renderer_test` (giro exato e grade com o mapa parado, passos de 3 graus no arrasto; cache refeito só nas condições; a rua desenhada onde a câmera do jogo diz, girada; o chão sem emenda; a árvore igual em dois giros; telhado translúcido sobre o avatar e o Eco; neve no telhado deslocado; nível de detalhe; ipê pela época; orçamento de partículas com a pilha cheia), `test/ui/map_style_switch_test` (troca sem reiniciar e a camada base igual), `test/world/style_advisor_test` (a sugestão uma vez só), `test/data/building_pack_test` e o Tornado da época 13 em `test/core/climate_layers_test`. Ajustados: a ordem das camadas, a lista de épocas e o menu de debug, que cresceu.

### Conhecido

- Prédios só onde o OSM tem contorno; São Paulo sem prédios até o leitor por tile.
- Os números do celular (profile e release) estão no checklist.
- Época 13 criada sem confirmação: começa em 2026-12-14 16:00 UTC; se a regra do Tornado não for para agora, basta apagá-la antes de distribuir.

## Fase 1 · fatia 9b · O mapa novo medido no celular (0.22.1)

Versão 0.22.1+39, mesma chave, instalada no moto g54 por cima da 0.21.0 (o save ficou). Medido em **build de profile no celular** (a build de profile agora tem a chave de release), com uma instrumentação temporária, nunca commitada (`FrameTiming` agregado a cada 3 s no logcat, o custo de cada camada e do `update`): Centro de Campinas, simulador andando com o joystick seguro o tempo todo (mantém os clocks altos), zoom alternando 40 e 80 m a cada 30 s. A tela do g54 vai a 120 Hz.

### O que a medida achou e o que mudou

- **O Completo da 0.22.0 era inutilizável andando:** 7 fps a 40 m e uns 18 fps a 80 m. Duas causas: (1) andando, a escala muda em frações ínfimas com a latitude, e o cache refazia um bloco por quadro; agora o zoom do quadro fica preso enquanto o real não sair 0,3% dele (`CityRenderer.stableKc`, com teste); (2) cada bloco desenhava as ruas, os prédios e as sombras do tile z15 inteiro (1,1 km) e confiava no recorte: 110 a 150 ms por bloco; agora cada bloco recebe só o que toca o retângulo dele, com 3 células de folga (`CityTile.within`).
- **A Vigília com Tempestade travava o mapa nos dois estilos** (3 fps): o `refresh` do mundo levava ~300 ms. Cada raio que cai no olhar procurava as zonas em volta (`_atZone` → `zonesNear`), e com o clima forçado pelo debug a memória das definições era pulada. Agora a memória vale também forçada (a definição só depende da região z12 e do instante) e o resultado de `_atZone` fica guardado pela queda: o `refresh` caiu para ~12 ms. O resultado é o mesmo (os testes de mundo e clima passam); só some o trabalho repetido. Isso também afetava a Vigília com Tempestade de verdade, numa sexta-feira 13.

### Números (profile, moto g54, Centro, andando; por janela de 3 s)

| Estilo | Clima | fps | build p50 / p90 (ms) | raster p50 / p90 (ms) | pior quadro (ms) |
| --- | --- | --- | --- | --- | --- |
| Simplificado | Limpo, 40 e 80 m | 77 a 87 | 2,1 a 2,8 / 3,3 a 4,2 | 9,1 a 10,8 / 11,4 a 12,0 | 15,6 |
| Simplificado | Tempestade + Tornado + Vigília | 75 a 81 | 4,4 a 5,3 / 7,3 a 9,4 | 4,8 a 6,2 / 6,0 a 7,5 | 33 |
| Completo (0.22.0) | Limpo, 40 m | 7 | 115 a 153 / 150 a 160 | 3,5 / 3,8 | 172 |
| Completo (0.22.1) | Limpo, 40 m | 92 a 118 | 3,4 a 4,6 / 4,5 a 5,9 | 4,2 a 6,4 / 4,9 a 10,2 | 17,5 |
| Completo (0.22.1) | Limpo, 80 m | 111 a 115 | 4,0 a 4,7 / 5,2 a 6,0 | 3,8 a 4,7 / 4,5 a 5,3 | 28,6 |
| Completo (0.22.1) | Tempestade + Tornado + Vigília | 62 a 75 | 5,8 a 7,1 / 8,0 a 12,1 | 4,3 a 5,7 / 5,2 a 6,8 | 32,9 |

- **O que pesa no Completo:** o chão parado custa 0,1 a 0,2 ms por quadro (os blocos prontos); um bloco novo entrando custa uns 5 a 10 ms (é dele parte dos piores quadros); o que fica de pé, 1 a 6 ms; as partículas e as camadas de tela ficam abaixo de 1 ms; o tráfego, 0,2 a 0,3 ms por passo; bichos e vento, 0,1 ms; o véu da neblina, menos de 0,02 ms. Simulações bem dentro dos 4 ms.
- **Meta de 16 ms:** cumprida no p90 em todos os casos medidos (o pior p90 é 12,1 ms, na pilha cheia). Os piores quadros isolados vão de 17 a 33 ms: blocos entrando na tela e o `refresh` do mundo a cada 0,25 s. O próximo passo, se for preciso, é refazer os blocos fora do quadro.
- O Simplificado tem o raster mais caro que o Completo (9 a 11 ms contra 4 a 6) porque redesenha as ruas inteiras a cada quadro; o Completo reaproveita os blocos.

## Fase 1 · fatia 9c · Giro, zoom ampliado, prédios por tile, Overture e arte no Aseprite (0.22.2)

GDD rev 359 (commit próprio: o Zoom ampliado depois da Câmera). Versão 0.22.2+40, mesma chave, save no schema 9 (só preferências novas). Feita no notebook, com o emulador; o celular não estava ligado, então as medidas em profile do zoom ampliado e do mapa de Rotas foram para o checklist.

### Giro

- **Modo de debug "Giro dos objetos"** (Mapa e câmera): escreve sobre cada objeto o tipo e a categoria (`ui/city/turn_category.dart`): gira com o chão, de pé, ou gira com o rumo. Capturas do mesmo trecho do Centro a 0°, 30° e 60°.
- **Os retângulos que giravam:** eram o remendo do asfalto (`patch`, um retângulo escuro com contorno), parte da textura da rua. A textura do chão ficava presa à tela: girando o mapa, os remendos, as manchas de óleo, as juntas e as ondas da calçada ficavam sempre na horizontal da tela e pareciam girar para acompanhar a rua. Agora a textura do chão gira com o chão.
- **A textura do telhado** fica alinhada à aresta mais longa do contorno e gira e anda exatamente com ele (`roofTextureMatrix`, com teste); a neve no telhado também.
- **Exceções, para o dono decidir:** os carros, ônibus, ciclistas e barcos do tráfego são vistos de cima e apontam para onde andam (giram com o rumo), e os nomes de rua acompanham a direção da rua. Nenhum prop com altura precisou de exceção: poste, ponto de ônibus, banca, árvore e props de telhado ficam de pé.

### Zoom ampliado e Rotas

- Ajustes, "Zoom ampliado" (desligado por padrão): a pinça vai a 250 m. Acima de 120 m o mapa passa para o Simplificado e volta ao Completo abaixo de 112 m (folga para não trocar no limite); na volta os blocos do Completo continuam no cache, sem tranco.
- De longe (acima de 120 m e no mapa de Rotas, que agora é sempre Simplificado): sem tráfego, passantes, bichos e partículas; as ruas finas somem antes das avenidas (trilhas acima de 120 m, locais acima de 200 m, secundárias acima de 400 m).
- O zoom não muda o jogo: os spawns continuam só dentro da visão, o toque e a Aura iguais (teste a 250 m). **Diferença no GDD:** o parágrafo novo diz "visão (60 m, menos na neblina)", mas a tabela dos climas diz que a Neblina *derruba* a visão para 60 m, e o `balance.json` usa 120 m. Ficou como estava (120 m, 60 na Neblina, 40 na Nevasca); se a visão normal for 60 m, é só o `view_m`.
- Debug "Largura da tela" (50, 80, 120, 250 m, dentro do limite da pinça): o zoom sem pinça, para teste e capturas.
- **Blocos fora do quadro:** os blocos de chão em volta da tela (um anel de 2) são gravados depois do quadro e rasterizados no thread de raster (`toImage`); o bloco que entra na tela já está pronto. Quando chegam os prédios de um tile, os blocos dele ficam marcados e são refeitos aos poucos, sem sumir.

### Prédios por tile

- Formato `BLD2` (`pipeline/bld_tiles.py`): tiles z15 com índice, cada um com o próprio gzip. O app lê só o índice e carrega os tiles em volta da câmera num `Isolate`, num cache que descarta os mais antigos acima de **24 MB** (estimativa de contornos e objetos); recusa tile acima de 512 KB (o maior de São Paulo tem 97 KB). Enquanto o tile carrega, o pedaço fica sem prédio.
- Campinas (448 KB, 676 tiles) e São Paulo (28,4 MB, 1.760 tiles, 2.199.471 prédios) convertidos do `BLD1` sem ler o extrato de novo. O de São Paulo não foi publicado.
- **Paulista no emulador** (build de debug, `rota.py paulista`, catálogo assinado servido localmente, nada publicado): 9 dos 1.760 tiles na memória, 4,2 MB, cada tile em uns 38 ms; a memória do app ficou estável (PSS de 855 a 870 MB em 3 minutos andando; é build de debug, que pesa bem mais que a release).
- Teste local do feed: a build de debug agora aceita http em `localhost` (`android/app/src/debug`, a release continua só https); `scripts/assinar_regioes.py --local` gera o catálogo com URLs relativas.

### Overture Maps (só medição)

`docs/overture-medicao.md`: no Centro de Campinas o Overture tem 3.046 prédios que o OSM não tem (10 vezes o OSM) e no Ouro Verde 4.898 (92 vezes); na Paulista só 99 (3%). Nenhum prédio só do Overture tem altura ou andares. POIs: de 4 a 30 vezes mais. Somaria uns 11,7 MB ao arquivo de Campinas e 35,9 MB ao de São Paulo. Licenças: prédios ODbL, places CDLA Permissive 2.0. A decisão de usar fica com o dono.

### Arte no Aseprite

O `criativo` viu as ferramentas do Aseprite e do Blender; o Blender não respondeu ao aperto de mão (o programa ou o servidor do addon estava fechado) e não foi usado. No Aseprite ele refez os 23 carimbos e módulos do estilo (telhados com as linhas na horizontal, para girar com a aresta mais longa; caixa d'água, ar-condicionado, antena; quatro árvores de espécies diferentes e o ipê; ponto de ônibus, banca, poste; a calçada portuguesa), em `tools/art/map/` e `app/assets/art/map/`. Debug "Arte do Aseprite" troca a arte em código por eles no mapa (o padrão continua a de código, até o dono escolher). Mudanças: `roof_metal` e `roof_metal_b` ficaram com 4 × 4 e 6 × 6; `roof_tar_light` ganhou módulo, mas não há estilo que o use; as sombras das árvores novas não foram refeitas.

### Também

- Época 13 apagada: a regra do Tornado com Vendaval está na 12, que ainda não saiu. A regra nova das épocas está no `CLAUDE.md`.
- `.claude/logs/` no `.gitignore`.

### Testes

Novos: `test/ui/turn_and_zoom_test` (categoria de giro de cada tipo, textura do telhado presa ao contorno, troca automática com folga, ruas que somem), o zoom ampliado em `test/ui/map_style_switch_test` (250 m, Simplificado, sem tráfego nem partículas, Ecos só dentro da visão, volta ao Completo), `test/data/building_pack_test` (índice, carga sob demanda, teto de memória, pedaço sem prédio enquanto carrega, tile grande recusado), blocos montados fora do quadro em `test/ui/city_renderer_test`, e o Tornado na época 12 em `test/core/climate_layers_test`.

## Fase 1 · fatia 9d · Overture Maps nos pacotes e arte do Aseprite (0.23.0)

GDD rev 360 (commit próprio: a visão dos Ecos é 120 m, que a Neblina derruba para 60 m e a Nevasca para 40 m). Versão 0.23.0+41, mesma chave, save no schema 9 (sem mudança). Feita no notebook, com o emulador.

### Respostas à 0.22.2

- As exceções de giro ficam: veículos apontam para onde andam e nomes de rua acompanham a rua.
- **Testes com o emulador ligado:** o tempo de cada teste passou a 60 s (`app/dart_test.yaml`, `timeout: 2x`), escrito no `CLAUDE.md`. Na suíte com o emulador ligado nenhum teste estourou desta vez; o mais lento sem `@Timeout` próprio levou 21 s (o círculo desenhado contra a lógica), perto dos 30 s de antes.
- **Arte do Aseprite é o padrão.** O `criativo` comparou os 22 PNGs com a arte em código: os valores são os mesmos (cada pixel é uma cor do `mapPalette`; luma média dos telhados igual na primeira casa). O painel "lavado" da `comparacao_arte.png` era o telhado translúcido (45%) do prédio com um Eco embaixo, que só aparecia no painel do Aseprite. Refeita a comparação no mesmo lugar, mesmo relógio e clima Limpo forçado: telhados 118, 119 e 137 contra a rua 76 de dia nas duas artes, e 63 a 73 contra 59 de noite, com diferença de no máximo 1 ponto; o avatar 112 de dia e 81 de noite nas duas. O debug agora é "Arte em código" (só para comparar; sai na próxima versão).
- **Sombras das árvores:** a sombra é a silhueta do carimbo da copa achatada a 70%, na cor da sombra (`city_ground.dart`), no lugar do oval igual para todas; os carimbos `tree_shadow*` que ninguém usava saíram. **`roof_tar_light` apagado:** com luma 117 caía em cima do `wall_urban` e do `roof_metal_b` sem dar degrau legível, e nenhum estilo o usava.
- **Blender:** o `criativo` alcança o Blender (5.2.3 LTS, addon 2.0, protocolo 16/16, sem aviso). Sem tarefa nesta versão.

### Overture nos pacotes

Release `2026-10-21.0`, fixada no pipeline e registrada na época 12 (`overture_release`); regras, números e licenças em `docs/overture-medicao.md`, comandos e SHAs em `pipeline/README.md`.

- **Prédios:** o OSM tem prioridade; do Overture entram só os contornos sem fonte OSM que não cobrem um prédio já aceito (mais de 30% da área do menor). Campinas: 32.116 do OSM e 901.031 do Overture (Google Open Buildings e Microsoft); nenhum do Overture tem altura nem classe, então a altura continua estimada pelo tamanho e pelo tipo. O arquivo de prédios de Campinas vai de 0,45 MB para 9,4 MB no APK (1.397 tiles z15, o maior com 46 KB, bem abaixo do limite de 512 KB); montar a cena do tile mais cheio (Ouro Verde, 3.621 prédios) levou 38 ms num teste da VM, contra 25 ms no Centro.
- **POIs:** confiança mínima 0,7 (dos 94.561 places de Campinas ficam 65.703 com 0,5, 45.525 com 0,7 e 23.418 com 0,9; nenhum marcado como fechado), junção com o OSM por grupo e nome parecido a até 30 m (1.208 casaram), 18.160 novos nos grupos do jogo.
- **Biomas:** um place sem par no OSM vale como a tag do OSM na área do prédio que o contém (shopping, supermercado, feira, igreja, escola, hospital, rodoviária); o comércio comum não vira Iluminado, como no OSM. Em Campinas mudam **6 das 87.300 células z18** (0,007%).
- **Pontos de spawn por condição:** as células z20 com beco ou marquise (Shade) vão de 4.456 para 15.784; as com poste (Hum) não mudam (1.856). Os becos vão de 2.845 para 4.298 pontos.
- **Época 12** (ainda não publicada, começa em 2026-12-07 16:00 UTC): `campinas_e12_ov.bin` e `campinas_e12_ov_traffic.bin` no lugar do `campinas_e11.bin` e do `campinas_e12_traffic.bin`; São Paulo com `sao_paulo_e12_ov.bin` e `sao_paulo_e12_ov_traffic.bin`, prontos e assinados localmente, não publicados.Em São Paulo: 2.726.173 prédios do Overture (o arquivo vai de 28,4 MB para 54,2 MB, o maior tile com 101 KB), 122.287 places novos, 108 das 179.208 células z18 mudam de bioma (0,06%) e as células da Shade vão de 46.313 para 116.154. O rascunho do catálogo assinado (`pipeline/out/regions/rascunho-e12/`) já lista os arquivos novos; `docs/pages` não mudou. A trava de release (`test/release_guard_test`) falha a partir de 2026-11-30 se o `sao_paulo_e12_ov.bin` não estiver publicado.
- **Créditos** nos Ajustes (botão "Créditos"): OpenStreetMap (ODbL), Overture Maps Foundation (prédios ODbL, places CDLA Permissive 2.0, com a release), Microsoft Global ML Building Footprints (ODbL), Google Open Buildings (CC BY 4.0), as fontes dos places presentes nos recortes (Meta, Microsoft, Uberall, PinMeTo, OpenTravel Alliance e DAC sob CDLA Permissive 2.0; AllThePlaces CC0; Foursquare Apache 2.0) e o SRTM. A página de atribuição do Overture não cita release (é a mesma para todas); a lista segue as fontes que aparecem nos dados baixados: sem Esri nem as outras fontes de prédios, que não estão em Campinas nem em São Paulo.

### Conhecido

- **Amigos com a 0.22.2:** a época 12 desse APK tem os arquivos sem o Overture. Quem não atualizar até 2026-12-07 16:00 UTC vê outros biomas em 6 células z18 de Campinas e outros pontos da Shade (só a camada pessoal, que já é individual); os spawns de base dependem do bioma.
- **Travamento no emulador:** ao ligar o simulador vindo do mapa da rede da Califórnia (posição padrão do emulador), o app ficou sem responder e o emulador caiu logo depois. Abrindo direto em Campinas pelo simulador não se repetiu. Item no checklist do celular para conferir o desempenho com 30 vezes mais prédios.
- No Ouro Verde, um contorno grande e irregular do Overture ao lado da lagoa parece prédio fantasma (área de concreto ou estacionamento); está no checklist.

### Testes

Novos: `pipeline/test_overture.py` (filtro de confiança, mapeamento de categorias, nome parecido, junção a 30 m, nenhum prédio duplicado, place dentro do prédio, mesmo arquivo com a mesma entrada); **pacote idêntico:** os três de Campinas gerados de novo do zero, da mesma release, saíram com os mesmos SHA-256; `test/ui/credits_screen_test` e o botão Créditos em `test/ui/settings_screen_test`. Corrigido: o mapa do jogo descartava as imagens do renderizador duas vezes quando o debug lia as estatísticas depois de o mapa fechar (só aparecia com a arte do Aseprite como padrão). Ajustados: `test/data/traffic_e12_test` (a época 12 com o Overture e a release registrada; os pontos de rua iguais, nenhum POI do OSM perdido) `test/data/building_pack_test` (o arquivo novo), `test/release_guard_test` (o nome do pacote de São Paulo) e os pacotes da época 12 nos assets falsos de `test/ui/map_screen_test`, `test/ui/game_map_screen_test`, `test/data/region_loader_test` e `test/net/region_manager_test`.

## Fase 1 · fatia 9e · Ajustes de arte do mapa (0.23.1)

Versão 0.23.1+42, mesma chave, save no schema 9 (só uma preferência nova). Feita no notebook. **O GDD não veio anexado**: o `docs/GDD.md` já estava na rev 360 (commit `5c85668`, com os dois estilos gráficos e o Zoom ampliado logo depois da Câmera, conferidos); as capturas do dono citadas no pedido também não vieram. O celular já tinha a 0.23.0 (a release mais nova), instalada antes desta versão.

### Respostas à 0.23.0

- **Épocas não publicadas** ficam com início em 2099-01-01 (e fim 90 dias depois); a data real só se escreve ao publicar, com 7 dias ou mais (`scripts/set_epoch_start.py <id> [data]`, que recusa menos). A época 12 foi para 2099 e a regra está no `CLAUDE.md`. Com isso, o "mundo desatualizado" passou a olhar a época vigente, não a maior validade da lista (`EpochSchedule.isStale`): senão uma época em 2099 esconderia um mundo vencido até lá. A trava de release continua igual.
- **Shade com teto:** no máximo `shade_max_per_z18` (2, `balance.json`) Ecos da Shade por célula z18 e janela; passam os de menor sorteio, então a faixa maior só acrescenta. Em Campinas, nos quarteirões que já tinham âncora antes do Overture, a faixa mais alta dá 1,39 Eco por quarteirão denso, contra 1,57 antes (sem teto seriam 1,79); com teto 1 seriam 0,85. A cobertura continua maior (de 2.104 para 6.956 células z18 com alguma âncora): é o mapa mais fiel; o teto segura a força em cada lugar. **Nenhuma outra habilidade ou spawn por condição cresceu:** o Hum usa semáforo e ponto de ônibus (iguais), a Rill e o Wisp não leem pontos, o Bit e a Glare dependem do bioma (5 células z18 de Campinas mudaram); os prédios novos só mudam desenho, becos e o bioma pelos places.
- **Contornos fantasma:** prédio que só o Overture tem sai quando metade ou mais cai sobre água, parque ou praça do OSM, ou quando passa de 500 m² e de 8 vezes a mediana do tile z15 sem confirmação do OSM (área de indústria, comércio, escola, hospital... em volta, ou POI dentro). Campinas: 1.606 sobre água, parque ou praça e 5.686 grandes demais, de 901.031; entram 893.739. São Paulo: 5.155 e 29.474, de 2.726.173; entram 2.691.544. O contorno do Ouro Verde ao lado da lagoa (791 m², Microsoft) caiu pela regra do tamanho. Época 12: `campinas_e12_ov2*` e `sao_paulo_e12_ov2*` no lugar dos `_ov` (que saíram dos assets).
- **Travamento na Califórnia:** com o `flutter run` de debug no emulador e a pilha Dart amostrada pelo VM service, a mesma sequência (mapa da rede na Califórnia, saltos de GPS para Campinas, liga o simulador) rodou duas vezes sem travar, com quadros de 7 a 38 ms. A trava da 0.23.0 aconteceu com o notebook a 1 GB de memória livre (o pipeline de São Paulo rodando) e o emulador caiu logo depois: tudo indica falta de memória da máquina, não um laço do app. Ficou no checklist para o celular.

### Giro

- **As marcas escuras nos telhados** eram a caixa d'água, o ar-condicionado e a antena (`roof_tank`, `roof_ac`, `roof_antenna`). O carimbo já saía de pé, mas o lugar dele era o centro do telhado mais um deslocamento **na tela**: ao girar o mapa, o prop corria em volta do telhado e parecia girar. Agora o lugar sai do chão (em volta do centro do contorno, em células z21) e sobe como o telhado.
- **As árvores:** o carimbo sempre saiu de pé; a sombra, a silhueta da copa achatada (0.23.0), era desenhada no chão, que gira, e a copa parecia mudar de forma. A sombra das árvores agora sai de pé, antes dos prédios, só mudando de lado com o sol.
- Os sprites do Aseprite entram pelo mesmo caminho dos de código (`LabArt.stamp`), conferido no teste novo com as duas artes.
- **Teste:** `test/ui/upright_turn_test.dart` desenha um trecho com prédios de todos os estilos e um prop de cada tipo, a 0° e a 90°, com a arte em código e a do Aseprite, e exige os mesmos pixels em cada sprite de pé (árvores, ipês, poste, ponto de ônibus, banca, caixa d'água, ar-condicionado, antena e os quatro letreiros); o prop de telhado também tem de girar 90° em volta do centro com o mapa. Todo carimbo de `mapStamps` e dos PNGs do Aseprite tem de estar em `uprightStampKinds` ou `groundStampKinds`. Conferido que o teste pega o erro antigo do prop de telhado. Os materiais têm o teste deles (`test/ui/material_sprites_test.dart`).

### Arte

O `criativo` decidiu a arte (`map_style.dart`, `material_sprites.dart`); o código do chão é da thread principal.

1. **Ladrilho só onde existe.** O piso branco paginado era o chão do Iluminado (`floor_lit`), que cobre a faixa de 14 m de toda avenida principal e secundária. Agora o chão de cada bioma é neutro (só o tom e um pontilhado leve), e por cima vem o uso do solo do OSM (`pipeline/build_ground.py`, `campinas_e0_ground.bin`, 4.722 áreas, 113 KB, cenário fora das épocas): estacionamento em asfalto com vagas, terreno baldio de terra e mato, lote residencial de terra batida com grama, comércio em cimento liso e ladrilho só em área de pedestre e praça. O Overture não trouxe uso do solo nesta versão (só prédios e places). São Paulo fica com o chão neutro (o catálogo de regiões ainda não baixa esse arquivo).
2. **Calçada.** A portuguesa só na zona do Centro (`mosaic_zone` em `pipeline/regions.json`, desenhada à mão: o OSM de Campinas não tem a área do bairro); o resto, concreto liso com junta discreta a cada 8 px. As larguras (2 e 3 m) já eram as reais; a "faixa grossa" era o mosaico e o piso do Iluminado ao lado.
3. **Escala de pixel.** O chão e o que fica de pé já saem na mesma grade (pixel de arte de 3 dp, vizinho mais próximo, deslocamento inteiro), conferido no código e numa captura ampliada do emulador; não achei filtro de suavização. O que pode esticar é o chão no meio do giro ou da pinça (o bloco do passo de 3 graus, desenhado com o resto do giro) até ser refeito um quarto de segundo depois. Sem as fotos do dono, ficou no checklist para fotografar quando aparecer.
4. **Paredes.** O telhado sai do pé no máximo um quarto da distância do centro da tela até a borda, na direção dele (`kRoofEdgeShare`; medido do centro, para o prédio na borda ou fora da tela não perder a parede), e as paredes ficaram mais escuras (Centro 85 / 63 / 46 no sol, sombra e manta; reboco 78 / 56; Iluminado 106 / 78; antes 113 / 87, 97 / 72, 132 / 100).
5. **Quadrados cinza e brancos** eram os materiais no chão (sucata e giz), desenhados como caixinhas coloridas. Cada um dos 11 materiais das épocas tem sprite agora (giz, ectoplasma, essência carmesim, ervas, cristal de gelo, meteorito, fragmento de prisma, água pura, runa, sucata, madeira), de pé, a 3 dp, com a base no ponto do spawn. `item.meteorite`, `item.rune` e `item.wood` estão nas épocas mas não no `items.json` (o `criativo` apontou; não mexi).
6. **Topo da tela.** O mapa (e a faixa do céu) começa embaixo da barra do HUD e termina na borda de baixo da área útil: nada do mapa passa por baixo da barra do HUD nem das barras do Android.
7. **Tela cheia.** Modo imersivo "sticky" em todo o app (mapa, sintonia e celular do jogo); as barras voltam com um deslize da borda e somem sozinhas. A bateria (em %, laranja com 20% ou menos) fica no HUD ao lado da hora, lida do Android a cada minuto (`batteryLevel` no canal `kenoma/system`). Ajustes, "Barras do Android", mostra as barras para quem prefere (`system_bars`).

### Conhecido

- **Capturas do emulador, não do celular:** o celular ficou desconectado do notebook durante o fechamento, então as capturas pedidas (estacionamento, calçada fora do Centro, prédio alto, topo com o HUD, giro de 30°) saíram do emulador, em build de debug, nos mesmos lugares escolhidos pelo debug (`/tmp/kenoma-shots/0231_*.png`). As do celular, em profile ou release, ficam no checklist.
- As vagas do estacionamento seguem os eixos do mundo, não a orientação do lote.

### Testes

Novos: `test/ui/upright_turn_test.dart`, `test/ui/material_sprites_test.dart`, `test/data/ground_pack_test.dart`, `test/ui/hud_battery_test.dart`, o teto da Shade em `test/world/personal_layer_test.dart`, o teto do telhado em `test/world/lab_block_test.dart`, a época em 2099 em `test/core/epochs_test.dart`, o mapa abaixo da barra em `test/ui/game_map_screen_test.dart`, "Barras do Android" em `test/ui/settings_screen_test.dart` e o filtro de fantasmas em `pipeline/test_overture.py`. Os testes de interface tiram os nomes dos pacotes de `epochs.json` em vez de escrevê-los à mão; os toques nos testes do mapa somam o canto do mapa (que agora começa embaixo da barra). O teste antigo da árvore em dois giros virou o teste de giro novo.

## Fase 1 · fatia 9f · Ajustes finos do mapa (0.23.2)

Versão 0.23.2+43, mesma chave, save sem mudança. O `criativo` decidiu a névoa e a sombra; o resto é código.

1. **Chão na pinça.** O vídeo da 0.23.1 no celular mostrou que o borrão era o chão no meio do gesto (os blocos do zoom do começo da pinça, esticados) e que sumia ao soltar. Agora, na pinça, os blocos seguem o zoom em passos de 6% a partir do zoom do começo do gesto (`zoomStep`), como o giro em passos de 3 graus: o chão estica no máximo uns 3% até o passo seguinte, e o zoom exato volta um quarto de segundo depois de soltar.
2. **HUD no topo.** O Android do moto g54 declara como recorte a faixa inteira da barra de status (117 px), mas o furo da câmera é só x 495 a 580. A janela agora desenha atrás do recorte (`windowLayoutInDisplayCutoutMode=shortEdges`, `values-v28`), e na tela cheia o mapa usa o retângulo do furo (`displayFeatures`) em vez da faixa: o HUD sobe até o topo, a parte da esquerda (hora, bateria, lua, clima) termina antes do furo e o selo fica à direita. Com "Barras do Android" ligado, vale a barra de status, como antes.
3. **Névoa.** A passagem do céu para o mapa ficou numa faixa curta (`max(5, 0,55 × céu)` fileiras, o dobro na neblina, contra 1,4 × céu antes), um ponto por pixel de arte, com limiar de ruído de gradiente intercalado (IGN) no lugar da matriz de Bayer 4 × 4: sem nível de 50% em xadrez e sem grade a cada 4 px (`tools/art/ref/haze_0232_opcoes.png`).
4. **Sombras.** A chave `shadow` foi de `#1A1424` a 42% para `#161A36` a 30%, e o renderizador usa a cor da chave (antes usava o contorno, quase preto): asfalto 57 → 49 na sombra, grama 118 → 91, calçada 167 → 125, vaga 105 sobre 49. **O "quase preto" do Dom Pedro não era sombra:** o `criativo` mediu a cor (`#312D3A`, opaca, sem vaga por baixo) e ela batia com a planta do prédio no chão. O que fica de pé descartava o prédio cujo centro saía da tela, e o shopping (centro fora da tela) perdia telhado e parede, sobrando só a planta escura. Agora entra todo prédio cujo contorno toca a tela, com a folga do maior deslocamento do telhado.

### Testes

Novos em `test/ui/city_renderer_test.dart`: os passos de zoom na pinça (no máximo meio passo esticado, zoom exato ao soltar), o shopping com o centro fora da tela desenhado, a névoa curta e sem período de 4 px e a sombra com alfa de no máximo 35%. Em `test/ui/game_map_screen_test.dart`: o HUD no topo com o furo do moto g54, a hora, a lua e o clima fora dele. Ajustado: o teste do cache (na pinça, menos de meio passo não refaz; mais, refaz no passo novo).

### Capturas

A 0.23.2 foi instalada no moto g54 (release, `versionName=0.23.2`), mas o celular estava em uso (Chrome em primeiro plano) e depois saiu do USB antes das capturas. Ficam para quando ele voltar: os mesmos lugares da 0.23.1 (Centro a 0° e a 30° com o "Giro dos objetos", o estacionamento do Dom Pedro, o Cambuí, o prédio alto no Centro e o topo da tela com o HUD).

## Fase 1 · fatia 10 · Crafting da fase 1, bolsa, bancada e loadout (0.24.0)

Versão 0.24.0+44, mesma chave, **save no schema 10**. GDD rev 361 (a seção "Regras da fase 1"): o arquivo não veio anexado à mensagem, mas a cópia de trabalho já tinha a seção nova e foi para o commit `docs: GDD rev 361`. Feita no notebook. O `criativo` fez nomes, textos (`docs/textos-crafting.md`, para revisão) e toda a arte nova; o `conteudista` passou o conjunto para os dados.

### O que entrou

1. **Qualidade.** Comum, bom e perfeito, guardados por pilha: a pilha comum usa o id puro (`item.chalk`) e as outras levam o sufixo (`item.chalk@good`), então todo material antigo já é comum sem mudar uma chave. O resultado herda o pior ingrediente; sem escolha, a receita gasta a pior pilha primeiro. O bruto pego no mapa sobe um nível no lugar real (bioma da tabela `crafting.quality.raw`) e outro na fase da lua certa; o conteúdo de coletor sai da condição (garoa comum, chuva boa, tempestade perfeita; neve boa, Nevasca perfeita). Selo bom e perfeito multiplicam a tolerância (1,15 e 1,3) e o tônico dura mais (1,25 e 1,5): a sintonia usa a melhor pilha do selo escolhido e o melhor tônico que o jogador tem (a folha de preparo mostra qual). Nenhuma receita exige qualidade.
2. **Coletores.** Garrafa de vidro, frasco escuro, pote de vela e frasco térmico. **Levados:** vazios no cinto (3, mais o equipamento), enchem com a condição em volta do jogador depois de uns 5 minutos dela (app aberto a cada 10 s; Patrulha a cada 30 s, que escreve a garrafa no diário). **Plantados:** pela Bolsa, aba Condições, só a pé (até a velocidade de caminhada da Patrulha), a 100 m ou mais de outro, até 3. A conta de um plantado é função da seed e do tempo naquele ponto (clima, eventos, noite e lua em passos de 10 min), igual de perto ou de longe, e segue de onde parou (`checked`). Colher pede o alcance de toque: toque no recipiente no mapa. Perecível estraga no mesmo ritmo plantado ou na bolsa; a neve derrete em água de neve em 72 h, menos no frasco térmico; o recipiente nunca some. Rotas e Radar listam os plantados com distância e estado; a Patrulha vibra e notifica quando um enche (uma vez por enchida).
3. **Refino e receitas.** 68 receitas no total (52 novas, com os `.alt`): 12 refinos no improviso com uma condição de agora (noite, sol forte, perto de água, área verde, chuva...), componentes na Bancada de casa, receitas de lua por grupo de fase (nova, crescente, cheia, minguante), oito amuletos de estação (dois por estação do hemisfério sul, pelas datas astronômicas; o de neve pede `item.snow`), duas bolsas maiores (receitas liberadas nos níveis 8 e 15), cinto, grimório e duas joias. As receitas aceitam `any:dust` e `any:trait` além de `any:essence`. Toda receita tem caminho comum: o Tônico de fumaça e as joias de calendário têm um `.alt` mais caro.
4. **Descoberta.** Receitas de improviso e refino se descobrem no Experimentar (até três materiais; nada se gasta: acerta e aprende, chega perto e recebe a pista, ou nada acontece); a silhueta com o degrau e a pista aparece quando o jogador tem um dos ingredientes. Componentes, lua, estações e equipamentos vêm de quatro páginas de grimório. **Fenda e Mercador ainda não existem**, então as quatro páginas são quests do mentor: `page.components` depois do terceiro refino, `page.moon` na primeira garrafa cheia, `page.seasons` no quinto componente e `page.gear` no nível 8 (`event_messages` com `page`).
5. **Bolsa.** Criaturas saíram da Bolsa (a Coleção abre pelo Círculo, "Ver a Coleção"). Topo com a bolsa equipada, espaços usados sobre o total com barra e a dica da próxima; abas com contagem; filtro por degrau; grade de 4 colunas com ícone, quantidade e 1 a 3 pontos de qualidade. O detalhe numa folha de baixo: origem, quantos de cada qualidade, receitas conhecidas que usam o item, silhuetas com pista, ver a receita, fixar no topo, equipar e descartar (quantos ou só comuns, segurando o botão um segundo; 1 Pó a cada 5, do tipo do item ou do tipo de que o jogador tem menos). 40 espaços, pilhas de 99. **Bolsa cheia** deixa o material e a Fagulha no mapa (com aviso); prêmio de diária, de ritual e o diário da Patrulha nunca se perdem por bolsa cheia.
6. **Bancada.** A tela antiga saiu: abas "Improviso · aqui" e "Bancada · casa" (do nível 5; **a casa ainda não existe no jogo**, então a aba vale em qualquer lugar), o Experimentar, a faixa "Agora, aqui" (noite ou dia, clima, fase, água a tantos metros, área verde, estação, do mesmo mundo do mapa) e as receitas em três grupos. A receita abre numa folha: ingredientes e resultado, a condição e se está cumprida, a pilha de cada ingrediente por qualidade, "Vai sair" com o que faltaria para subir, quantidade e Fazer. Destilar e fundir foram para uma tela própria (`DistillScreen`), ligada da Bancada e do Bestiário.
7. **Visual.** O `criativo` desenhou no Aseprite (`tools/art/ui/build_ui.lua`) as molduras em nove partes, abas, botões, células, pontos de qualidade, barra de capacidade e 85 ícones de 16 px (os genéricos de Essência e Pó são tingidos pela cor do tipo); as regras estão em `docs/art/estilo-ui.md`. O Flutter desenha as nove partes com um painter próprio, cada pixel de arte a 3 dp, sem suavização (o `centerSlice` do Flutter não escala os cantos). Só a Bolsa e a Bancada usam o visual novo.
8. **Loadout.** App novo do celular (nível 1), com os componentes de sempre: espaços de bolsa, cinto, grimório, amuleto e duas joias (**não há espaço de gadget**: o jogo ainda não tem gadget equipável; o Prisma de orvalho é consumível). Abas Equipamento e Aparência, "No personagem" em cada espaço e a soma dos efeitos. No mapa, o Conjurador mostra a bolsa, de 1 a 3 garrafas e o brilho do amuleto (sprites do `criativo`, espelhando junto).

### Conhecido

- O pote de vela enche com as Cinzas do Véu; a Noite das Fendas ainda está sem data no calendário (`calendar_pending`).
- Não existem lures no jogo: a regra "dura mais" vale para o tônico.
- O ícone do app Loadout no celular é provisório (desenho em código de 12 × 12); fica para o `criativo`.
- Capturas da 0.23.2 no moto g54 tiradas nesta sessão: `/tmp/kenoma-shots/0232_celular_*.png`.

### Testes

Novos: `test/crafting/phase1_test.dart` (qualidade pelo pior ingrediente, bruto pela condição, garrafa levada enchendo na chuva, plantado enchendo com o jogador longe e só colhido de perto, 100 m entre plantados, plantar de carro recusado, perecível estragando plantado, neve derretendo e o frasco térmico, descoberta sem gastar, descarte rendendo Pó, bolsa cheia recusando, loadout mostrando e escondendo no sprite, o bloco no save), `test/save/migration_v10_test.dart` (com `test/fixtures/save_v9_0232.json`, gravado pelo código real da 0.23.2), `test/ui/craft_screens_test.dart` e `test/ui/player_gear_test.dart` (o equipamento de pé, no tamanho do quadro do Conjurador, espelhando). Ajustados para o conteúdo novo: as listas exatas de selos e receitas viraram `containsAll`, a ordem dos apps ganhou o Loadout, a migração v9 e o save futuro usam `saveSchemaVersion`.

### Capturas

No emulador (build de debug, simulador no Centro, relógio em 2027-01-08 02:00 UTC: verão, lua nova, noite; o "Kit de crafting" do debug no save, nível 15), em `/tmp/kenoma-shots/0240_*.png`: a Bolsa (`bolsa`, `bolsa_detalhe`, `bolsa_condicoes`), a Bancada (`bancada`, `bancada_grupos`, `receita_lua` com o Selo umbral, `experimentar` com a pista "falta algo: sol forte de dia"), `amuleto_estacao` (o Amuleto do Aguaceiro com a condição do verão cumprida), `loadout` (bolsa, cinto e o Amuleto da Trovoada: +75% no verão), um coletor plantado no mapa (`coletor_mapa`, cheio depois de 45 min de chuva forçada) e no Radar (`coletor_radar`, a 24 m, água de chuva boa), o Conjurador equipado (`conjurador_equipado` e o recorte ampliado) e a folha de contato da arte de interface (`folha_ui`). A primeira captura da aba Condições mostrou neve guardada "derretendo em -1159 h": os recipientes guardados na bolsa não passavam pela conta do perecível. Corrigido (o passo dos coletores agora estraga também os guardados) e coberto em `phase1_test.dart`.

## Fase 1 · fatia 10b · Correções do crafting e a quest da primeira garrafa (0.24.1)

Versão 0.24.1+45, mesma chave, **save no schema 11**. Respostas à 0.24.0: o GDD é a rev 361 e as decisões listadas foram aprovadas (páginas pelo mentor, Bancada de casa no nível 5, Destilar e Fusão numa tela própria, receitas de lua pela luz engarrafada, sem gadget, sem lures, pote de vela só nas Cinzas por enquanto).

### Correções das capturas

1. **A bolsa nunca passa do limite.** Todo item entra por `GameState.add`, que agora passa pelo limite (`accept`, instalado pelo mapa): o que não cabe é recusado com aviso ("Bolsa cheia: 3 × Giz ficaram de fora"). Tirar do loadout, tirar do cinto e colher um plantado também recusam se não cabe (o item fica onde estava). O "Kit de crafting" do debug equipa a maior bolsa e põe, em ordem, só o que cabe, dizendo quanto ficou de fora. Um save que já passou do limite (o 63/40 do kit da 0.24.0) não perde nada, mas nada novo entra até abrir espaço.
2. **Telas do celular até o topo.** Em tela cheia, a Bolsa, a Bancada, o Loadout, o Radar e as outras telas do celular sobem até o topo e só a barra de status fina desvia do furo da câmera (`topCutout`, o mesmo retângulo do HUD do mapa); com as barras do Android à vista, vale a barra de status.
3. **Laranja só para urgência.** "Esperando uma condição", "Falta material", o que a receita pede e os ingredientes que faltam saem no texto mudo; o laranja ficou só na validade de algo que estraga em horas. O descarte e a bolsa cheia também saíram do laranja.
4. **Amuletos repetidos.** Eram os caminhos `.alt` (com Água de neve) do Amuleto da Trovoada e do Aguaceiro: a lista agora mostra uma linha por resultado, no melhor grupo que algum caminho alcança, e a receita aberta deixa escolher "Caminho 1 / Caminho 2".
5. **Validade na aba Condições.** Cada guardado mostra a validade com o verbo do conteúdo (`perish_verb` em `items.json`: "derrete em", "apaga em", "estraga em"; "não estraga" no que não estraga). Iguais (conteúdo, qualidade e validade) ficam numa linha com ×N; validades diferentes, linhas separadas. Os guardados na bolsa agora estragam no mesmo passo do cinto e dos plantados.
6. **"Pode fazer agora"** diz em cada receita a qualidade que sai ("Sai qualidade boa"), além dos pontos.
7. **Etiquetas de "Agora, aqui".** O `criativo` redesenhou a etiqueta (8 × 7, bordas 2) e recortou abas e botões; o código põe o conteúdo sempre a pelo menos a borda × 3 dp + 3 dp de cada lado.
8. **Coletor no mapa menor que o Conjurador.** Sprites de mapa novos do `criativo` (9 × 10 pixels, contra os 16 do Conjurador, no pixel dele): garrafa, frasco escuro, pote de vela e frasco térmico, sobre uma base de 9 pixels com o estado.
9. **Textos.** A qualidade sai sempre como "qualidade comum/boa/perfeita"; os recipientes concordam ("Garrafa de vidro cheia", "Frasco escuro cheio"; `gender: f` em 44 itens); plurais ("+1 garrafa no cinto", "+1 coletor plantado", "Já há 1 coletor plantado"); "na primavera"; os biomas em palavras ("num lugar sagrado"); o nome do ingrediente na receita quebra em até três linhas; as pistas do Experimentar e as mensagens da bolsa são as do `docs/textos-crafting.md`. Ícone do Loadout pelo `criativo` (o amuleto no cordão).

### Ensinar o crafting

- **Receita da Garrafa de vidro: 2 Sucata** (antes 2 Sucata e 1 Pó de Fogo). Não existe vidro no mundo; a garrafa é "vidro de sucata refundido", e pôr um material novo no mapa mudaria uma época.
- **Receitas conhecidas desde o começo:** Garrafa de vidro, Frasco escuro, Selo simples e **Tônico de foco com Água de chuva** (Ervas + Água de chuva), receita nova para o último passo da quest ter o que fazer com a água (antes, Água de chuva só entrava nos amuletos de verão). O resto se descobre experimentando. As antigas da Bancada (selos de tipo, reforçado, tônico, prisma) passaram a ser de experimento num jogo novo, mas a migração as marca como conhecidas em todo save da 0.24.0 ou antes: ninguém perde receita.
- **A quest "Primeira garrafa"**, do mentor: abre na primeira Sucata (ou no presente). Passos: fazer uma garrafa na Bancada, pôr no cinto, encher na chuva ou plantar se não estiver chovendo, e fazer uma receita com a água. Cada passo sai dos eventos do jogo (feito antes conta), solta a mensagem do mentor dele, e fica destacado na tela certa com a marca violeta: a garrafa na Bancada, a aba Condições e o botão Cinto na Bolsa, a dica de encher ou plantar, e as receitas que usam o que um coletor pegou. A lista de tarefas aparece no topo da Bolsa e da Bancada enquanto a quest está ligada. A página da lua passou a sair no fim da quest (antes saía junto com a primeira garrafa cheia).
- **O presente:** abrir a aba Condições sem nenhum recipiente faz o mentor deixar uma Garrafa de vidro, uma vez; o presente conta como o primeiro passo.
- O Detalhe de um material mostra "Usado em" com as receitas conhecidas; com Sucata na bolsa, a garrafa aparece em "Pode fazer agora".

### Testes

Novos: `test/crafting/phase1_fixes_test.dart` (limite da bolsa em todo caminho, caminhos `.alt` numa linha, a quest passo a passo, plantar valendo como encher, o presente uma vez, as receitas de começo e a garrafa de 2 Sucata, a validade com o verbo, concordância e plurais) e `test/save/migration_v11_test.dart` (com `test/fixtures/save_v10_0240.json`, gravado pelo código real da 0.24.0: as receitas antigas continuam conhecidas e a próxima Sucata liga a quest já no passo de encher).

### Capturas no moto g54 (release 0.24.1)

Com o simulador no Centro, relógio em 2027-01-08 (verão, lua nova, noite) e chuva forçada, no save real do celular (sem o kit do debug), em `/tmp/kenoma-shots/0241_celular_*.png`: o mapa, o celular com o ícone novo do Loadout (`apps`), a Bolsa (34/40, sem a faixa preta no topo), a aba Condições com o presente do mentor e a lista da quest (`condicoes`), a garrafa no cinto com a dica da chuva (`condicoes_cinto`), a garrafa cheia de Água de chuva, qualidade boa, depois de 5 minutos de chuva (`garrafa_cheia`), a Bancada com as etiquetas inteiras e "Sai qualidade comum", o Loadout e o Radar. O presente e os três primeiros passos da quest ficaram feitos no save do celular; o último (o tônico com a água) ficou para o dono.

Duas correções que as capturas pediram, na mesma versão:
- **Uma célula por pilha de 99.** Uma pilha de 551 Pó contava 6 espaços na barra, mas aparecia como uma célula só: agora são 6 células (99 × 5 e 56), como os espaços contam.
- **O tônico marcado no último passo.** O Tônico de foco tem dois caminhos (Água pura e Água de chuva) e a lista mostrava o da Água pura, sem a marca; agora a marca vale se algum caminho usa o que um coletor pegou, e a receita abre já no caminho da chuva. Coberto em `craft_screens_test.dart`.

## Fase 1 · fatia 10c · Ponto de ônibus, pássaros e o mapa que responde ao toque (0.24.2)

Versão 0.24.2+46, mesma chave, **save no schema 12** (o bloco `touches`, com o dia e o que cada interação já rendeu). Teste de migração com `test/fixtures/save_v11_0241.json`, gravado pelo código real da 0.24.1.

### Segurança ao controlar o celular

Na 0.24.1 o script de capturas seguiu tocando e digitando às cegas depois que o dono pegou o aparelho, e o texto foi parar numa conversa. Regras novas no `CLAUDE.md`, e o script novo `scripts/celular.sh`:
- antes de **cada** ação (toque, deslize, voltar, captura, comando) ele confere tela ligada, sem bloqueio e o `com.numb4r.kenoma` em primeiro plano; se não, para na hora, grava a trava `/tmp/kenoma-celular.parado` e recusa tudo até um `reset` explícito (nada de tentar de novo sozinho). A captura confere de novo depois e se apaga se algo mudou no meio;
- **nunca digita texto**: o debug vai por `celular.sh cmd "sim on; clock ...; weather rain; tp lat,lon; width 80; labels on; map"`, uma intent que só o Kenoma lê (`kenoma_cmd`, `lib/dev/debug_commands.dart`, entregue pela `MainActivity` em build de debug, profile e release);
- abrir o app (`start`) só com `KENOMA_CELULAR_LIBERADO=1`, depois que o dono disser na sessão que o aparelho está livre.
Nesta versão o celular não foi tocado (não foi liberado na sessão); as capturas são do emulador, pelo mesmo script.

### Correções

1. **Ponto de ônibus.** O retângulo que girava com o mapa, paralelo à rua, era o abrigo do ponto, que vem do OSM como um prédio pequeno (`roof`/`shelter`) e virava telhado. Prédio de até 40 m² a até 10 m de um ponto sai dos prédios; o ponto fica de pé (o carimbo), e só a base dele gira com o chão: a marca da calçada (4 × 1,6 m) e o meio-fio, ao longo da rua mais perto. No teste de giro (`street_sign` também).
2. **Pássaros por cima dos telhados.** Os bichos saem em duas passadas: no chão (pombo ciscando, gato no muro) por baixo dos prédios; no ar (pombo voando, maritacas, morcegos e a fumaça do vento) na camada do ar, depois dos prédios, das árvores e do Conjurador, abaixo só do clima da tela e do HUD. O pombo que pousa dentro de um prédio fica no telhado, na posição deslocada do telhado (a mesma conta das paredes). Folhas, papéis, fuligem e areia do vento rolam pelo chão e ficaram no chão; as Fagulhas já vinham depois dos prédios.
3. **Caco de vidro.** Material novo (`item.glass_shard`, `since_epoch: 12`), na época 12 (ainda não publicada): nas tabelas de material do Urbano (peso 2) e do Iluminado (peso 3, que é o bioma dos bares e do comércio). A Garrafa de vidro passou a 2 Cacos de vidro e a quest "Primeira garrafa" começa no primeiro caco. **Até a época 12 ser publicada não cai vidro no mundo**: a primeira garrafa vem do presente do mentor (aba Condições vazia). Pontos de reciclagem não estão no pacote da região; pô-los pediria o pipeline e um pacote novo na época 12. Quem já tem receita ou garrafa não perde nada.
4. **Giro dos objetos.** Rodado no Centro e no Dom Pedro (Fagulha, material, passante, poste, árvore, ponto de ônibus, placa, Eco, Conjurador de pé; telhado e rua girando com o chão; carro com o rumo): nenhum outro objeto na categoria errada além do abrigo. Pássaros, gatos e as folhas do vento não ganham rótulo nesse modo.

### O mapa responde ao toque

Todos só a até 30 m e a pé (`canTouch`), e nada muda o mundo dos amigos: o que é igual para o grupo sai da seed; o resto é cenário local ou recompensa pequena da camada pessoal, com limite por dia (`map_touch` no `balance.json`). Textos do `criativo` em `docs/textos-mapa.md` (para revisão), nos dados em `app/assets/data/mapa.json`; reações desenhadas no Aseprite (`fx_*.png`).
1. **Ponto de ônibus:** o próximo Ônibus Espectral ali (`spectralBusNext`, de 15 a 35 min por ponto, pela seed e pelo ponto: igual para o grupo). **O Ônibus Espectral ainda não circula no jogo**; este é o horário que ele terá de seguir quando vier. **O pacote não tem as linhas reais (`route_ref`)**: o painel diz que ninguém anotou as linhas do ponto.
2. **Pombos e maritacas:** o bando levanta voo; às vezes cai uma Pena (até 3 por dia).
3. **Banca de jornal:** a manchete do Véu do dia, de 24 modelos (clima de hoje ali, evento do calendário nos próximos 14 dias, ou a família de Eco mais vista a até 150 m), igual para amigos (`hash(seed, época, dia, banca)`). **As bancas não são do OSM**: são uma em três praças, como já eram desenhadas.
4. **Árvores:** sacodem; no outono pode cair Folha seca e, no ipê florido (roxo em junho e julho, amarelo em agosto e setembro), Flor de ipê (material de estação). Uma vez por árvore por dia, até 6 por dia. A copa não treme no desenho (fica para depois: as árvores saem do bloco já desenhado); a folha ou a pétala cai na frente dela.
5. **Poças:** a onda; um Eco de Água a até 40 m se vira para o Conjurador por 6 s (espelhado) e dá um pulo.
6. **Postes à noite:** piscam; um Hum a até 40 m pula e fica à vista 8 s a mais, mesmo além do alcance de visão. De dia o poste não acende.
7. **Gatos nos muros:** carinho (o coração), o gato segue o Conjurador por uns 100 m (cenário) e às vezes larga uma coisa (Sucata, Pena ou Giz; até 3 por dia).
8. **Placas de rua:** novas, nas esquinas onde uma rua com nome cruza outra; o painel mostra o nome. **Só as ruas principais e secundárias têm nome no pacote**, então só as esquinas delas têm placa.
Materiais novos com uso: Pena (tônico de foco com água pura), Folha seca (ervas secas, no outono), Flor de ipê (água lustral, na primavera). O Bestiário de lugares do workbench não foi mexido.

### Testes

Novos: `test/world/map_touch_test.dart` (alcance e a pé, limite por dia e por árvore, o ônibus igual para o grupo, a manchete igual para dois aparelhos no mesmo dia e com a concordância dos dias), `test/world/birds_layers_test.dart` (a camada do ar depois dos prédios, o pombo no telhado e no chão, o abrigo do ponto), `test/ui/touch_fx_test.dart` (a reação desenha e some), `test/save/migration_v12_test.dart` e a placa no teste de giro. Ajustado: o teste do Eco oculto espera até 150 quadros (a camada do ar deixou o quadro de teste mais caro e a suíte inteira passava do limite de 60).

### Capturas

No emulador, em `/tmp/kenoma-shots/0242_*`: o ponto de ônibus a 0° e girado (`ponto_0`, `ponto_girado`: a rua gira, o ponto fica de pé), o painel do ponto, da placa ("Avenida Francisco Glicério") e da banca, a árvore, o poste à noite ("piscou sozinho, nenhum Hum por perto"), o bando levantando voo (e a pena recusada pela bolsa cheia do emulador) com o vídeo `0242_bando_telhados.mp4`, e o gato largando uma Sucata. Não saíram nas capturas: a poça (a chuva forçada não chegou a formar poça perto) e a folha caindo (as duas árvores tocadas tiraram "nada hoje" no sorteio pessoal); a reação desenhada está coberta pelo teste.

## Fase 1 · fatia 10d · Época em teste e a copa que balança (0.24.3)

Versão 0.24.3+47, mesma chave, save no schema 12 (sem mudança de formato: a época em teste é uma chave nova em `settings`). Feita no emulador; o celular não foi liberado na sessão.

### Respostas à 0.24.2

- **Época em teste.** Item novo no menu de debug, seção Save: "Opções de desenvolvedor nos Ajustes" (`save.dev_options`, grava `settings.dev_options` no save do mapa aberto ou, sem mapa, no do disco). Com ele ligado, os Ajustes ganham a seção **Desenvolvedor** com o interruptor "Época N em teste": liga a época não publicada mais nova (início em 2099) só neste aparelho, também na release. Fica no save (`settings.dev_test_epoch`, o id), o mapa reabre com ela, o HUD mostra **ÉPOCA N EM TESTE** e o painel Dados diz "ÉPOCA N · EM TESTE". Por dentro: `testEpochId` em `core/epochs.dart`, lido do save antes do pacote da região (é ele que escolhe o pacote); `EpochSchedule.current()` devolve a época em teste em todo instante depois da primeira época, sem aviso de mundo vencido. **Some sozinha:** quando a época deixa de começar em 2099 (feed assinado ou APK novo), `testing` vira `null`, todo o app volta à época de todos, e ao abrir o mapa a chave sai do save. Recomeçar mantém a opção (é dos Ajustes).
- **Regra das épocas** no `CLAUDE.md` com a exceção: o dono testa a época nova pela opção de desenvolvedor; amigos só veem época publicada.
- **O que só existe na época 12** (e por isso não vale no celular sem a opção): clima e evento em camadas (15 climas viraram eventos por cima do clima, até 2 ao mesmo tempo, teto 3,0 e piso 0,3 na soma dos spawns; Lua Carmim e Prisma do Véu novos; as combinações Vigília com Tempestade, Carmim com Tempestade e Aurora com Neve; o arco-íris na virada de chuva para sol; eclipses como evento); os materiais de clima Meteorito, Runa caída e Galho de gelo; o Caco de vidro (Urbano 2, Iluminado 3) e por isso a primeira garrafa pelo mundo; o pacote lógico com o Overture (`campinas_e12_ov2.bin`, biomas de 6 células z18 de Campinas e São Paulo com os places, os contornos fantasma fora da conta) e os pontos do OSM do Overture (`*_e12_ov2_traffic.bin`: becos de 2.845 para 4.298, células da Shade de 4.456 para 15.784); a família Wyrm na Lua Carmim e a Procissão da Névoa fora da neblina. **Já valem para todos:** os prédios desenhados do Overture com os contornos fantasma tirados (`*_e12_ov2_bldg.bin` não depende da época) e o teto da Shade (`balance.json`).
- **A copa balança.** Todo toque numa árvore ou ipê (com folha ou sem) balança o carimbo de pé: as linhas da imagem saem do lugar por pixels de arte inteiros, o topo `3·e^(−1,5t)·sen(2π·2t)` por 1,4 s e o terço de baixo parado (a base escura da copa, presa à sombra, que não mexe). Números conferidos pelo `criativo` (ele trocou o amortecimento de 2,2 para 1,5: com 2,2 o topo parava em 0,7 s). A folha e a pétala continuam caindo na frente. Só no estilo Completo; no Simplificado as árvores não balançam.

- **No celular do dono** a época em teste fica ligada (pedido depois da versão): dois comandos de debug novos para isso, sem tocar nos menus, `scripts/celular.sh cmd "testepoch on; map"` (grava a não publicada mais nova e libera a seção Desenvolvedor; com o mapa aberto vale ao reabrir) e `testepoch off` / `devopts on|off`. Release 0.24.3+47 instalada por cima da 0.24.1, com o save.

### Limites

- Com a época 12 em teste, São Paulo pede `sao_paulo_e12_ov2.bin`, que não está no `regions.json` publicado: fora de Campinas a região baixável não abre (Campinas vem no APK).
- Os blocos do fallback (fora das regiões) montados com a época em teste ficam com o id dela até a época de todos passar dela: ao desligar a opção, o fallback não é refeito.
- No emulador, as bolinhas verdes dos gramados são arbustos do chão, não árvores: o toque não pega nelas. As árvores tocáveis são os carimbos de pé das calçadas e praças.

### Testes

Novos: `test/ui/tree_sway_test.dart` (o balanço vai para os dois lados e para; o topo sai do lugar e o terço de baixo fica, desenhado pelo `CityRenderer`), o grupo "época em teste" em `test/core/epochs_test.dart` (desligada, ligada, publicada, lida do save) e a seção Desenvolvedor em `test/ui/settings_screen_test.dart` (escondida, liga a não publicada mais nova com confirmação e reabre o mapa, desliga).

### Capturas

No emulador, em `/tmp/kenoma-shots/0243_*`: o item do debug (`debug_devopts`), a seção Desenvolvedor (`ajustes`, cortada antes do player_id), a confirmação, o mapa com **ÉPOCA 12 EM TESTE** no HUD (`hud_epoca12`) e a árvore da praça balançando (`arvore_balanca.mp4`, `.gif` ampliado e `arvore_quadros.png`).

## Fase 1 · fatia 10e · Voltar do debug e conceitos do Humoth (0.24.4)

Versão 0.24.4+48, mesma chave, save no schema 12 (sem mudança). Feita no notebook, no emulador; o celular não foi tocado.

### Voltar

- **Menu de debug:** ele é a primeira rota do app, então o Voltar fechava o app. Agora (`PopScope` em `DebugMenuView`) o Voltar sobe um nível: com busca, limpa a busca; no topo do menu, abre o mapa (`openGameMap`, que volta ao mapa da pilha ou abre um). Do mapa, o Voltar continua levando ao menu de debug: o Voltar não fecha mais o app (sai-se pelo botão de início do Android).
- **Telas do celular do jogo:** conferidas no emulador as 13 (Radar, Bestiário, Círculo, Bolsa, Loadout, Bancada, Chat, Fórum, Perfil, Rotas, Patrulha, Céu, Ajustes): Voltar sai do app para o celular e do celular para o mapa; o detalhe de um item da Bolsa fecha e volta à Bolsa. Dois lugares fechavam a tela inteira com um nível aberto por dentro e agora fecham só o nível: a lista de troca do **Loadout** e a escolha de material do **Experimentar** (Bancada).

### Humoth: só os conceitos

O `criativo` fez três conceitos no Aseprite, em `tools/art/teste/humoth/` (fora do git, no `.gitignore`), cada um em 19 px (pixel de 3 dp), 28 px (pixel de 2 dp) e retrato de 96 px, com as notas em `notas.md`: **A · Delta "Letreiro"** (mariposa-esfinge em voo planado, índigo frio, ocelos ciano), **B · Tenda "Brasa"** (pousada, asas em telhado, ameixa e quatro ocelos laranja), **C · Batimento "Véu"** (mariposa-lua, asas redondas, violeta do Véu e ocelos amarelos). Recomendação dele: B se a densidade ficar em 3 dp; A se o teste de 2 dp passar. As referências (o Humoth e o Conjurador atuais exportados, o mapa de noite no emulador) estão em `tools/art/teste/ref/`. Nada entrou no jogo; o dono escolhe o conceito e a densidade.

Observação do `criativo` para depois: o corpo escuro some no asfalto da noite e quem segura a leitura são a borda da asa, os ocelos e os veios. Se o tom da noite (`sceneLight`) for pintado por cima do Eco, os ocelos e veios apagam; para valerem como LED, terão de ir depois do tom, como as janelas e o neon. Nas folhas os conceitos estão sem o tom.

### Testes

Novos: o Voltar do menu de debug em `test/dev/debug_menu_test.dart` (limpa a busca, chama o mapa no topo, nunca sai) e o do Loadout e do Experimentar em `test/ui/craft_screens_test.dart`.

### Capturas

`/tmp/kenoma-shots/0244_humoth_mapa.png` (os três conceitos e o atual sobre o mapa de noite, ao lado do Conjurador, em 19 px a 3 dp e 28 px a 2 dp, na escala do jogo) e `0244_humoth_retratos.png` (os retratos de 96 px, com os de 19 e 28 px e o atual).

## Fase 1 · fatia 11 · Ônibus nos pontos, Outros Veilbreakers e Veículos do Véu (0.24.5)

Versão 0.24.5+49, mesma chave, **save no schema 13** (bloco `npcs`: as trocas do dia e a relação com os conhecidos). Teste de migração com `test/fixtures/save_v12_0244.json`, gravado pelo código real da 0.24.4. GDD rev 365 no repositório (`docs: GDD rev 365`): **o anexo não veio na mensagem**; o `docs/GDD.md` da árvore de trabalho já tinha as três seções novas (sem número de revisão no texto) e foi esse que entrou. Feita no emulador; o celular não foi tocado.

### Ônibus nos pontos (só cena)

- **Ônibus comuns:** já paravam no ponto e levavam quem esperava (0.19.0). Conferido no emulador: o ônibus encosta ao lado do ponto desenhado (os dois saem dos mesmos pontos do OSM) e espera. **Faltava descer:** agora de 0 a `bus_alight_max` (2) passantes descem pela porta, do lado da calçada da direita, andam até a esquina e seguem como os outros (`TrafficSim._alight`).
- **Ônibus Espectral** (`world/spectral_bus.dart`): passa de verdade no horário de cada ponto que a 0.24.2 já mostrava, freia até o ponto, fica parado, acelera e some; um passageiro espectral desce e some na calçada, ou aparece nela e embarca. Só seed, ponto e tempo: igual para o grupo, sem recompensa, sem levar o jogador. Anda na faixa do lado do ponto (mão direita), pelo ponto da rua mais perto guardado no prop (`CityProp.roadX/roadY`). Não depende do interruptor "Tráfego do Véu". Tocar no ponto com ele parado mostra uma das falas `bus_now`. Números em `map_touch.bus` do `balance.json` (`approach_s`, `dwell_s`, `leave_s`, `run_m`; só cena, por aparelho, mas o horário é o da seed).
- Arte do `criativo`: `bus_spectral.png` (32×12, de cima) e `spectral_passenger.png`.

### Outros Veilbreakers

- **Mundo** (`world/veilbreakers.dart`, números no bloco `veilbreakers` da **época 12**, que ainda não foi publicada: eles fazem Ecos sumirem, então moram na época e não no `balance.json`). Cada célula z18 em cada fatia de 15 min tem um NPC com chance `base_chance` × bioma (Iluminado ×3, verde ×2) × hora local (UTC-3, quase nada de madrugada, pico no fim da tarde). Identidade (nome, apelido, escola, roupa) e caminho saem de `hash(seed, época, célula, fatia)`: três células z20 em fila, cada ponto levado à calçada mais perto (o mesmo snapper dos spawns), ida e volta a 1,1 m/s. A posição é função do tempo: igual para amigos.
- **Sintonia:** só Ecos da camada base a até 45 m do caminho cuja janela fecha dentro da fatia; somem 120 s antes do fim da janela (chance 0,5, até 2 por fatia). O NPC para, os anéis do sinal fecham sobre o Eco (`fx_npc_tune.png`) e ele some. Nunca um Eco a até 30 m do jogador (local: no outro aparelho, longe, some). A camada pessoal não é tocada.
- **Conhecidos:** 2 por tile z15, sorteados entre os 8 do `npc.json`, presos à primeira célula z18 do tile com o bioma do lugar deles, só nos dias e horas da rotina.
- **Folha** (toque a até 30 m, a pé): nome, título da escola, a saudação (pela relação), a troca do dia e às vezes um rumor. **Troca:** uma por NPC por dia, sempre com perda (o valor de cada item é o custo nas receitas, material bruto = 1; um teste confere as 24 trocas), recusada sem material ou com a bolsa cheia. **Relação** (só conhecidos) sobe 1 por troca até 10, no save; com 3 as trocas ficam melhores, com 6 ainda melhores e entram os rumores raros. **Rumor** (35% por NPC por dia): família de um Eco da camada base perto (distância e rumo verdadeiros), minutos até o Espectral no ponto mais perto, o próximo evento do calendário; raros: um Brilhante ou um Oculto perto.
- Textos do `criativo` em `docs/textos-npc.md` (para revisão), nos dados em `app/assets/data/npc.json` (`conteudista`); números da conversa em `balance.json` (`npc`). Arte: 8 tiras de NPC (`npc_<escola>_<0|1>.png`, 3 quadros de 16×16, quatro escolas contando "sem escola").

### Veículos do Véu (só aparência)

- `item.vehicle.bike` e `item.vehicle.skate` (faixa de bicicleta) e `item.vehicle.cart` (faixa de carro), sem efeito nenhum; receitas na Bancada nas páginas `page.vehicle_light` (mentor no nível 6) e `page.vehicle_cart` (nível 11). Loadout com dois espaços novos (`vehicleBike`, `vehicleCar`), com "mostrar no personagem".
- A faixa (`rideBandOf`): com o Modo Viagem em curso, a do veículo escolhido; sem viagem, a velocidade do avatar contra os limites do Modo Viagem (a pé até 7 km/h, bicicleta até 25 km/h). Troca só depois de 1,5 s na faixa nova. A pé nada muda; na corrida de Uber ou 99 continua o carro da corrida. Duas camadas por veículo (`veh_*_back/front.png`, 32×24 com o Conjurador em (8, 2)), espelhadas como o avatar. Qualidade: Boa ganha brilho na cor do sinal, Perfeita brilho e rastro de faíscas.

### Debug (todas as builds, só neste aparelho)

Comandos novos no `celular.sh cmd` (agora o resultado sai no logcat, `kenoma_cmd [...]`): `npcs on|off` (um NPC em toda célula), `npctune [s]` (leva o GPS simulado para 45 m do próximo Eco que um NPC vai sintonizar e o relógio para pouco antes), `npc` (abre a folha do NPC mais perto), `spectral [s]` (perto do ponto mais perto, pouco antes do Espectral), `buses on|off` (quase todo carro de avenida vira ônibus), `speed <m/s>` (GPS simulado), `vehicle bike|skate|cart[@good|@perfect]` (equipa direto no save aberto).

### Limites

- **O anexo do GDD não veio**: o que entrou é o `docs/GDD.md` que já estava na árvore de trabalho.
- Ninguém esperava no ponto da gravação: o embarque e a descida dos ônibus comuns estão cobertos pelos testes, não pela captura.
- O caminho do NPC liga três pontos de calçada por retas: numa esquina fechada ele pode cortar o canto de um prédio.
- Textos com concordância a revisar no `docs/textos-npc.md`: "1 dias" nos rumores de evento e "3 Folha seca" na oferta (o nome do item vai sem plural).
- O anel da sintonia sai um pouco acima e à esquerda do centro do Eco.

### Testes

Novos: `test/crafting/vehicles_test.dart` (faixa por velocidade e por viagem; veículo certo por faixa; nenhum efeito; a mesma viagem de bicicleta, carro como passageiro e motorista, e ônibus dá o mesmo save, o mesmo baú, as mesmas Fagulhas e marcas e a mesma velocidade máxima com e sem veículo), `test/world/spectral_bus_test.dart` (no minuto do painel, igual em dois aparelhos), `test/world/veilbreakers_test.dart` (mesmo NPC em dois aparelhos, só Ecos que iam sumir, a pausa, madrugada contra fim da tarde, rotina dos conhecidos), `test/world/npc_talk_test.dart` (toda troca com perda, uma por NPC por dia, relação no save, rumor verdadeiro), `test/save/migration_v13_test.dart`, e a descida do ônibus em `test/world/sim/traffic_sim_test.dart`. **Teste intermitente corrigido:** o do Eco oculto (`game_map_screen_test`) falhava 1 vez em 5 já no código da 0.24.4: o Eco forçado anda e tem uid novo a cada rodada, e em 6 s às vezes saía do alcance da distorção; agora o jogador chega de novo onde ele está antes do pulso.

### Capturas

No emulador, em `/tmp/kenoma-shots/0245_*`: ônibus comum parado no ponto (`onibus_ponto.png` e `.mp4`), o Espectral passando (`onibus_espectral.mp4` e `_quadros.png`), um NPC sintonizando (`npc_sintonia.mp4` e `_quadros.png`), a folha (`npc_folha.png`), um rumor (`npc_rumor.png`), a troca recusada pela bolsa cheia (`npc_troca.png`), o avatar de bicicleta Perfeita e de carroça pelo GPS simulado (`veiculo_bicicleta.png`, `veiculo_carroca.png`).

## Fase 1 · fatia 12 · Pixel de 2 dp e o Humoth oficial animado (0.25.0)

Versão 0.25.0+50, mesma chave, save no schema 13 (sem mudança). Feita no notebook, no emulador; o celular não foi tocado. GDD rev 367 (`docs: GDD rev 367`): **o anexo não veio** e o `~/Downloads/GDD.md` era antigo (1º de outubro); o `docs/GDD.md` da árvore de trabalho já tinha as regras novas (2 dp, camada emissiva, animações mínimas) e foi esse que entrou.

### 0. Sobras da 0.24.5

- **Quantidade com substantivo numa função só** (`core/plural.dart`): `countText(n, singular)` ("1 dia", "2 dias", "3 Folhas secas", "2 Cacos de vidro", "2 Pós de Essência de Fogo"), o plural pelas regras do português no núcleo e nos adjetivos dele (o complemento depois de "de" não muda) e `plural` em `items.json` quando a regra erra (só "Cal viva" → "Cales vivas"). Nos dados, a lacuna de contagem é `{n:singular}` ou `{n:singular|plural}`, e `{n?Falta|Faltam}` concorda só a palavra; `mapa.json`, `npc.json`, `forum.json` e os `docs/textos-*.md` passaram a usá-la ("Faltam {dias} dias" virou `{dias?Falta|Faltam} {dias:dia}`; "{n} selo(s) simples" virou `{n:selo simples|selos simples}`). No código, a folha do NPC, o "+N item" das coletas, a fusão, o Perfil, a Patrulha, o Céu, o backup, o teste do Tecnomante e o limite de marcações. **Teste** (`test/core/plural_test.dart`): percorre todo texto de dados com 0, 1 e 2 e falha com "1 dias", "2 dia", lacuna de número junto de substantivo fora da função ou substantivo sem plural; e todo item tem plural.
- **Caminho dos NPCs pela calçada:** o caminho segue a rua mais perto do pacote visual (igual para todos), 35 m para cada lado do ponto mais perto, deslocado para a calçada em meia-esquadria (dobra onde a rua dobra, à mesma distância das duas ruas na esquina). Sem rua por perto, os pontos de calçada de antes. Teste com uma rua em L: o NPC fica sempre entre 3 m e 6,1 m do eixo (nunca na rua, nunca cortando a quina).
- **Efeitos centrados na criatura:** o pintor dos spawns guarda o centro em que desenhou cada Eco (com o empurrão do vento) e o anel da sintonia do NPC e o desfazer da fuga se centram nele (`anchoredRect`); antes iam pela posição crua e subiam 0,4 do tamanho. A marca e o destaque já saíam do mesmo centro.

### 1. Pixel de arte de 2 dp

- `map.art_pixel_dp` 3 → 2. Os tamanhos no mundo não mudaram: Conjurador e Familiar 24 px (eram 16), Eco 28 (19), Espírito 36 (24), material 15 (10). O `criativo` redesenhou na grade nova, com mais detalhe e nada ampliado: os 23 carimbos e texturas de `tools/art/map/` e as matrizes de `map_style.dart` (1,5×), o Conjurador de 24 × 24 à mão nos três quadros e o equipamento (bolsa, garrafas, amuleto), o Familiar, os 12 materiais, os 8 NPCs, o anel da sintonia, os três veículos (quadros 48 × 36 com o Conjurador em (12, 3)), o Ônibus Espectral e o passageiro.
- No renderizador: as janelas (largura, altura e passo) e a poça de luz do poste em 1,5×; o módulo de chão 96 (`labPatternPx`); a borda da calçada 1,5 px. A altura dos andares (`floorPx`) continua 4 m: é metro, não pixel. Os padrões em metros (poças, telhados, calçadas) já acompanhavam.
- **Ficou para a 0.25.1:** as 27 formas das famílias (exceto o Humoth) saem das matrizes de 48 reduzidas para 28 e 36 px por código (mais pixels a partir da arte de 48, não o 19 ampliado), sem o acabamento à mão; os carros, os passantes, os ônibus comuns e as Fagulhas continuam desenhados em código (não são carimbos), no tamanho em metros.
- **Desempenho** (emulador, build de profile, p50 do raster; o build fica em 5 a 6 ms): zoom fechado 15,2–15,9 ms em 3 dp → 14,4–15,9 em 2 dp; zoom aberto 18,4–19,6 → 18,1–20,4; Vigília com Tempestade 15,8–17,8 → 16,2–17,1. Sem piora; o raster do emulador (GPU do notebook) já passava de 16 ms antes. O dono decidiu seguir; a medida que vale, no celular, está no checklist.
- Testes de grade, giro, HUD e tamanho passaram para 2 dp (`city_renderer_test`, `upright_turn_test`, `map_balance_test`, `art_renderer_test`, `spirit_sprite_test`, `player_gear_test`, `familiar_form_test`).

### 2. Humoth oficial (conceito A, "Letreiro")

- Arte do `criativo` em `tools/art/creatures/humoth/` (gerada por `build.lua`): seis animações de 28 px, cada uma em três camadas (corpo, LEDs, brilho): `idle` (4 quadros, 8 fps), `drift` (4, 8), `alert` (3, 6), `flee` (6, 12), `spawn` (6, 10), `tuned` (6, 10); sete variantes por troca de cores e acessório (Urbano com braçadeiras, Verde com gola de folhas, Água com colar e gota, Residencial claro com cachecol, Iluminado o mais claro com gravata, Sagrado com auréola, Carmesim o mais escuro com o crescente da Lua Carmim); retrato de 96 px em 4 quadros. O padrão para as outras famílias está em `docs/art/estilo-criaturas.md`.
- **Camada emissiva** (`MapLayer.emissive`, depois de `climateScreen` e antes do HUD): o corpo recebe o tom da noite (multiplicado) e o clima da tela passa por cima dele; os ocelos, os veios, as faíscas e o brilho do Brilhante vêm depois, acesos. Vale para toda criatura com arte animada daqui para a frente.
- **No mapa** (`creature_anim.dart`, `creature_art.dart`): nascendo, a animação `spawn`; ao alcance de toque, `alert` (ocelos fixos); andando (pela posição dos últimos quadros), `drift`; senão `idle`, com a fase própria de cada um. Os LEDs piscam num ritmo próprio, fora de fase com as asas, com apagões e tremidas de mau contato. Espelhado pelo lado em que anda; de pé no giro. Fuga e sintonia que deu certo terminam com a saída animada (`Fx.exit`): a fuga sobe e sai de lado; a sintonia se desfaz e as faíscas voam até o Conjurador. O Brilhante é o único com brilho animado (uma faixa de luz que passa pelo corpo).
- **Bestiário:** o retrato animado (pairando, LEDs piscando) no cartão, na linha da família e no detalhe, com a cor da variante escolhida por cima, como as outras.
- **Sintonia:** o retrato no lugar do sprite; os LEDs acendem a cada salto de frequência do padrão Elétrico e ficam acesos fixos quando o sinal trava.
- O ciano dos ocelos é permitido (o Humoth não é ameaça). **Sem a costura do Véu:** o conceito aprovado não a tem; se for para ter, cabe como uma linha violeta na camada de brilho.

### Debug (todas as builds, só neste aparelho)

Comandos novos no `celular.sh cmd`: `event <id>|off` (os eventos do clima, como "Todos os eventos"), `creature <espécie> [biome|crimson|shiny] [n]` (como "Criar criatura"), `exit tuned|flee` (a saída animada do Eco mais perto, só no desenho) e `seen <espécie>` (marca como vista).

### Limites

- **Deriva sem vídeo:** as criaturas do "Criar criatura" não andam; a deriva está na folha de quadros e aparece nos Humoth do mundo, que andam pelo modelo de movimento.
- As variantes no retrato do Bestiário usam o tom por cima (como as outras criaturas), não a troca de cores do mapa.
- O nascer não espera o raio nem o poste: é a animação de quando o Eco aparece, onde ele aparecer.

### Testes

Novos: `test/core/plural_test.dart`, o caminho pela calçada em `test/world/veilbreakers_test.dart`, `test/ui/creature_anchor_test.dart` (efeito centrado na âncora do sprite), `test/ui/creature_emissive_test.dart` (a camada emissiva depois do tom e do clima; de noite o corpo escurece e o LED sai na cor cheia por cima do tom da tela), `test/ui/humoth_art_test.dart` (as seis animações na grade de 28 px com as três camadas do mesmo tamanho, o retrato de 96; cada variante distinta das outras e da comum em escala de cinza).

### Capturas e vídeos

Em `/tmp/kenoma-shots/0250_*`: o mesmo trecho do Centro em 3 dp e em 2 dp, de dia e de noite (`3dp_day`, `2dp_day`, `3dp_night`, `2dp_night`) e o Conjurador ampliado nas quatro (`conjurador_3dp_2dp`); o Humoth de noite (`humoth_noite`) e de dia com chuva (`humoth_dia_chuva`), a folha com todos os quadros e as variantes em cor e em cinza (`humoth_folha`), o retrato no Bestiário (`humoth_bestiario`, `humoth_bestiario_detalhe`), a sintonia com os LEDs acesos no salto (`humoth_sintonia`); vídeos: nascendo e pairando de noite (`humoth_nascer_noite.mp4`), sintonizado (`humoth_tuned.mp4`), fuga (`humoth_flee.mp4`) e a sintonia (`humoth_sintonia.mp4`).

## Fase 1 · fatia 13 · Resto da arte em 2 dp e desempenho no celular (0.25.1)

Versão 0.25.1+51, mesma chave, save no schema 13 (sem mudança). GDD rev 367: o `docs/GDD.md` já tinha "com o pixel de arte valendo 2 dp na tela" e a seção "Veículos do Véu"; o `~/Downloads/GDD.md` é de 1º de outubro e não tem nenhuma das duas.

### 1. Celular

O dono liberou o aparelho na sessão; tudo pelo `scripts/celular.sh`. A release da 0.25.0 foi instalada por cima da 0.24.3 (assinada com a chave de release) e o save ficou: nível 16, Familiar do Tecnomante, favoritos do debug. **A época 12 em teste está desligada no save do celular** (o HUD não mostra "Época 12 em teste"); não mexi.

Medido em build de profile com a mesma chave e uma sonda temporária (`FrameTiming` agregado a cada 3 s, nunca commitada), no Centro de Campinas às 20 h locais, simulador andando com o joystick seguro por 30 s em cada caso. O g54 renderizou até ~90 fps nesta sessão (na 0.22.1 chegava a ~118). p50 / p90 em ms:

| Estilo | Caso | fps | build | raster | quadros > 16 ms |
|---|---|---|---|---|---|
| Completo | 40 m | 86 a 89 | 5,7 a 6,5 / 7,0 a 8,2 | 6,7 a 8,7 / 8,2 a 9,4 | 0 a 1 por janela |
| Completo | 80 m | 58 a 65 | 7,3 a 8,9 / 9,5 a 11,8 | 11,3 a 13,1 / 12,1 a 14,8 | 1 a 7 por janela |
| Completo | Vigília com Tempestade, 40 m | 53 a 69 | 6,8 a 7,2 / 8,8 a 11,8 | 6,3 a 11,5 / 6,9 a 12,2 | 0 a 5 por janela |
| Simplificado | 40 m | 84 a 90 | 1,9 a 2,1 / 2,6 a 3,2 | 9,1 a 9,9 / 10,7 a 11,4 | 0 a 1 |
| Simplificado | 80 m, antes | 46 a 49 | 2,6 a 2,9 / 3,8 a 5,4 | 18,9 a 20,0 / 19,8 a 21,7 | **todos** |
| Simplificado | 80 m, depois | 65 a 71 | 2,1 a 2,4 / 3,1 a 4,1 | 12,2 a 12,5 / 14,0 a 14,6 | 0 a 3 |
| Simplificado | Vigília com Tempestade, 40 m | 52 a 59 | 3,1 a 3,5 / 4,5 a 9,2 | 10,6 a 12,2 / 11,5 a 14,4 | 0 a 8 |

- **O Completo não passa de 16 ms no p90 em nenhum caso** (o pior p90 é 14,8 ms, a 80 m): a otimização não precisou vir antes da seção 2. Uma primeira rodada seguida deu o Completo a 80 m com p90 de 17,3 ms no fim: era calor (CPU a 62 °C depois de ~15 min de carga). A frio, com a ordem trocada, os números acima.
- **Contra a 0.22.1 (3 dp):** o raster do Completo subiu de 4,2–6,4 para 6,7–8,7 ms a 40 m e de 3,8–4,7 para 11,3–13,1 ms a 80 m; o build, de 3,4–4,6 para 5,7–6,5 ms. O que pesa (inferência, sem medir camada por camada): os blocos do chão e o que fica de pé têm 2,25 vezes mais pixels na grade de 2 dp, e a 80 m entram mais blocos na tela.
- **O Simplificado a 80 m passava de 16 ms em todo quadro.** Ele refaz o buffer da arte a cada quadro, e cada tile com área verde ou água preenchia o buffer inteiro com o ruído do material, recortado pela área: a 80 m são muitos tiles, e o buffer de 2 dp tem 2,25 vezes mais pixels. Agora as áreas de todos os tiles viram um caminho só por material, com um recorte e um preenchimento (`art_renderer.dart`); o desenho é o mesmo (teste do renderizador e captura).
- Debug novo: `style full|simple` (os gráficos do mapa dos Ajustes, sem tocar na tela).

### 2. O resto da arte em 2 dp

Quatro `criativo`s em paralelo, em pastas separadas, no Aseprite, pelo `docs/art/estilo-criaturas.md`.

- **As 26 formas** que faltavam (todas: Soot, Rill e Frond com Eco, Espírito e Ritual; as nove da fase 1 com Eco e Espírito), cada uma com as seis animações nas três camadas, sete variantes por troca de cor e acessório, retrato de 96 animado e folha de conferência. Eco em 28 px; Espírito e Ritual em 36 (o código trata o Ritual como Espírito). As fontes ficam em `tools/art/creatures/<nome>/` com um kit por grupo (`sootling/_kit.lua`, `pebblet/kit.lua`, `wisplet/_fase1.lua`: não apagar essas pastas sem levar o kit). `scripts/sync_creature_art.py` copia para o app e reescreve o índice e o `pubspec`.
- **Criatura sem arte nenhuma:** nenhuma; as 27 espécies têm arte do Aseprite. As matrizes de 48 px continuam como reserva (testes, pasta incompleta).
- **Tráfego e Fagulhas:** carros (hatch, sedan, pickup, suv), moto, ciclista, ônibus comum e os três passantes (adulto, dupla, idoso) com as nove roupas do clima como camadas por cima; as cores-chave (`traffic_keys.json`) trocam pela paleta de cada fantasma, como faziam as matrizes; faróis, lanternas e janelas do ônibus acesos de noite. Uma Fagulha por tipo (chama, gota, folha, faísca, pedrinha, lasca, raio de luz, fiapo de sombra, chama fria, pixel, pó de fada, escama), 12 × 12 em 4 quadros, com contorno e brilho por cima da noite. Os NPCs Veilbreakers já eram do Aseprite desde a 0.25.0.
- **Retrato do Bestiário:** a variante troca as cores pelo mesmo mapa do mapa (sem o acessório), não um tom por cima.
- **Nascer com gatilho** (só no desenho; o Eco continua no ponto da seed, igual para os amigos, nenhuma época muda): o Humoth e o Coilkin nascem num raio que cai neles na tempestade, ou, à noite, nas faíscas que saem do poste mais perto (até 30 m); o Rill na poça que ondula (com chuva), o Clod do chão revirado, o Wisp de fiapos de neblina que se juntam. Sem gatilho que valha, nasce onde aparece, como antes. A escolha é pura e testada (`spawn_trigger.dart`); os climas de cada gatilho e o alcance do poste estão no `index.json` das criaturas.
- **Debug:** `creature <espécie> ... walk` cria uma criatura que anda em laço de 6 m (só no desenho), para ver a deriva e o espelhamento.

### Limites

- Continuam em código, na grade antiga: o barco e a canoa do Dilúvio, o cachorro do passeio e o carro da corrida do Modo Viagem.
- O retrato do Glitchkin usa blocos de 3 px de propósito (é feito de quadros repetidos); foge da regra de um tamanho de pixel só. Os retratos das 26 são o desenho da espécie refeito a 96 px, abaixo do acabamento do retrato do Humoth.
- O criativo apontou dois pontos fracos: os tufos do Thicketkin lembram pedra rachada, e o laço escuro da variante Iluminada quase some no Thicketkin e no Sootling.
- Os Rituais não têm entrada no Bestiário; o desenho deles saiu das falas do mentor.
- O raio do nascer dura ~0,1 s: só se vê inteiro no vídeo quadro a quadro.

### Testes

Novos: `test/ui/creature_art_test.dart` (substitui o `humoth_art_test`: as 27 espécies, grade, seis animações, três camadas, retrato, variantes distintas em cinza, retrato da variante com a silhueta igual), `test/ui/spawn_trigger_test.dart`, `test/ui/traffic_art_test.dart` (todo modelo com sprite, as nove roupas, a troca de cores, as Fagulhas, e cada fantasma desenhado com os pés na posição).

### Capturas e vídeos

Em `/tmp/kenoma-shots/0251_*`: uma folha por família (`familia_<família>.png`, todas as formas e variantes, 5×), o mapa de noite com dez criaturas de famílias diferentes (`familias_noite`), o tráfego na chuva e de noite (`trafego_chuva`, `trafego_noite`), o Simplificado a 80 m no celular (`cel_simples_80`); vídeos do Humoth no tom da noite: sintonizado (`humoth_tuned_noite.mp4`), fuga (`humoth_flee_noite.mp4`), deriva com a criatura de debug que anda (`humoth_deriva_noite.mp4`), nascendo no raio (`humoth_nasce_raio.mp4`) e no poste (`humoth_nasce_poste.mp4`).

## Fase 1 · fatia 14 · Modo de desenvolvimento das épocas e o ponto de ônibus (0.25.2)

Versão 0.25.2+52, mesma chave, save no schema 14. GDD rev 368 (`docs: GDD rev 368`): o anexo não veio e as duas cópias de `~/Downloads` são de outubro; o `docs/GDD.md` da árvore de trabalho já tinha o parágrafo "Enquanto só o desenvolvedor joga, o jogo fica em modo de desenvolvimento" (Épocas) e foi esse que entrou. Feita no notebook, no emulador; o celular não foi liberado nesta sessão.

### 1. Épocas: modo de desenvolvimento

- **Uma época só.** `app/assets/data/epochs.json` tem só a época de desenvolvimento, com `"dev": true`: o conteúdo inteiro da 12 (spawns, coleta, `eco_v2`, clima, NPCs, pacotes e SHA), início em 2026-09-22 (o começo do jogo) e validade até 2100. O id continua 12 porque ele entra no hash do mundo e nos `since_epoch`: o mundo é o mesmo que o dono jogava com a "Época 12 em teste", agora sem opção nenhuma.
- **Mudança de mundo entra nela direto** (`CLAUDE.md`, regra 5, reescrita; a linha da pipeline sobre não regerar `.bin` também, porque era a regra de congelar o SHA).
- **Saiu:** a época em teste (`testEpochId`, a opção dos Ajustes, a seção Desenvolvedor, o item do debug que a liberava, os comandos `testepoch` e `devopts`, a etiqueta do HUD), a trava de release (`test/release_guard_test.dart`) e o aviso de mundo desatualizado (`EpochSchedule.isStale` é sempre falso com `"dev"`). Os Ajustes mostram "ÉPOCA 12 · DESENVOLVIMENTO". Migração 13 → 14: tira `dev_test_epoch` e `dev_options` do save, o resto igual (teste com um save v13 da 0.25.1 que tinha os dois ligados).
- **Feed:** o código e os certificados continuam; com `"dev"` o app não funde as épocas do feed (o `docs/pages/epochs.json` publicado ainda tem as 0 a 7, que passariam por cima: a 7 começa depois de 2026-09-22). Os eventos do feed continuam lidos.
- **Épocas 0 a 11** saíram do APK e viraram fixture dos testes que usam os modelos antigos (clima, eclipse, água, arco-íris): `app/test/fixtures/epochs_history.json`. `epochsJson()` nos testes é o histórico mais a 12 no lugar de antes; `shippedEpochsJson()` é o arquivo do APK.
- **São Paulo embutido:** os sete arquivos da época 12 de SP (lógico, visual, relevo, vias, rota, pontos e prédios, todos conferidos pelo SHA da época) vão em `app/assets/regions/` e o mapa monta SP junto com Campinas (`loadEmbeddedRegion`); o catálogo não baixa o que já está no mundo. **O APK de release foi de 100,5 MB para 170,8 MB (+70,3 MB)**: os pacotes entram sem compressão, e os prédios de SP sozinhos são 53,5 MB. Esse arquivo também pesa no git (o GitHub avisa acima de 50 MB por arquivo).
- **Distribuição:** o passo a passo de quando o dono disser que vai distribuir (backup das chaves antes, a 12 vira a primeira publicada, voltam a trava e a regra antiga, o feed é republicado só com ela, SP pode sair do APK) está em `docs/distribuicao.md`.

### 2. O ponto de ônibus girava

- **O que girava:** com o "Giro dos objetos" sobre o ponto de -22.904769, -47.059802 (Centro) a 0°, 30° e 90° (comando de debug novo `turn <graus>`), o ponto tinha duas peças: o abrigo visto de cima (o carimbo `bus_stop`, 14 × 8, rotulado "ponto de ônibus · de pé", igual nos três ângulos) e, embaixo dele, a marca de calçada da 0.24.2 (4 × 1,6 m e o meio-fio), pintada no bloco do chão e girando com a rua. Ela não tinha rótulo no "Giro dos objetos" porque fazia parte do chão; era o retângulo que girava.
- **Agora:** a marca saiu (`city_ground.dart`) e o `criativo` redesenhou o ponto inteiro de pé (21 × 16): poste com a placa azul, cobertura, painel de trás e banco, no Aseprite e na matriz de reserva. Uma peça só, "de pé".
- **Teste no caminho real** (`test/ui/upright_turn_test.dart`): o trecho desenhado como o mapa desenha (o chão em blocos de cache e a camada de pé, na grade de 2 dp) com e sem o objeto, a 0°, 30° e 90°; o que o objeto põe na tela tem de ser a mesma imagem, pixel a pixel, podendo só deslizar até 1 pixel de arte (o mapa encaixa tudo na grade). Vale para o ponto de ônibus, a banca, a placa de rua e o poste, com a arte em código e com a do Aseprite. Com a marca de volta, o teste falha no ponto a 30°.

### Testes

Novos: `test/core/epochs_test.dart` (o grupo do modo de desenvolvimento), `test/world/dev_world_test.dart` (dois aparelhos da mesma versão, cada um lendo os próprios arquivos, veem o mesmo mundo do começo do jogo até 2030; outra seed, outro mundo), `test/save/migration_v14_test.dart`, `test/data/embedded_region_test.dart` (SP sai dos assets com tudo, e todo pacote da época está no APK), o feed ignorado em modo de desenvolvimento (`signed_feed_test`) e o caminho real do giro. Os testes de mundo desatualizado viraram "sem aviso no modo de desenvolvimento"; saíram os da época em teste e o da 0.13.1 sem rua viva (a época única pede a rua viva).

### Capturas

Em `/tmp/kenoma-shots/0252_*`: o ponto antes (`ponto_antes_0`, `_30`, `_90` e `ponto_antes_zoom`) e depois (`ponto_depois_0`, `_30`, `_90` e `ponto_depois_zoom`, com e sem os rótulos).

## Fase 1 · fatia 15 · HUD e celular no estilo da bolsa (0.26.0)

Versão 0.26.0+53, mesma chave, save no schema 14 (sem mudança). Só visual, salvo onde está escrito. Feita no notebook, no emulador; o celular não foi liberado nesta sessão. A sessão de arte paralela (`../kenoma-arte`, `arte-criaturas`) não teve arquivo tocado aqui, e `docs/art/pendencias-codigo.md` ainda não existe.

### 0. Pacotes de região fora do git

- `app/assets/regions/*.bin` (19 arquivos, 82 MB) saíram do controle de versão daqui para a frente (`.gitignore`, `git rm --cached`), sem reescrever o histórico. A lista versionada `scripts/regioes.sha256` diz o arquivo e o SHA-256 de cada um.
- `scripts/baixar_regioes.sh` baixa da GitHub Release `regioes-dev` só o que falta ou não confere, e confere o SHA (testado com uma release local: baixa, recusa arquivo errado com erro). O build do Android roda o script antes de empacotar (`baixarRegioes` no `build.gradle.kts`). `README.md` (novo) e `docs/emulador.md` dizem que ele roda uma vez por máquina; o `pipeline/README.md`, como regerar e subir.
- `scripts/subir_regioes.sh [--todos | arquivos]` sobe na release e reescreve a lista. **A release ainda não existe** (conferido de novo depois do push: a tag e os 19 arquivos dão 404, então um clone novo não faz build até ela subir): esta máquina não tem o GitHub CLI autenticado (o push é por SSH, e a API pede token). Até ela existir, o commit que tira os pacotes do git fica só local: com ele no `main`, um `git pull` apagaria os `.bin` da pasta de trabalho de quem já os tem (o worktree `kenoma-arte` inclusive), sem ter de onde baixar.
- Tamanho: os arquivos versionados vão de 98,8 MB para 16,9 MB. O `.git` continua com 120 MB (pacote de 36,4 MiB), porque o histórico fica como está; um clone novo baixa o histórico, e os 82 MB de pacotes passam a vir da release.

### 1 e 2. HUD e celular

A arte é de cinco `criativo`s no Aseprite (`tools/art/ui/apps`, `moon`, `climate`, `event`, `kit`, `types`, e `tools/art/traffic/build_extra.lua`); o guia (`docs/art/estilo-ui.md`) ganhou as seções "Kit do HUD e do celular", "Cores e ícones dos tipos" e "Como a integração usa o kit".

- **Ícones:** 17 apps e o bloqueado (tira de 3 quadros com glitch), as 8 fases da lua (mais Lua Carmim e Lua Dupla), os 31 climas e os 15 eventos (todo evento é uma bandeirola, para não confundir com clima), todos de 16 × 16.
- **HUD:** barra do topo (`hud_bar`) com lua e clima em ícone, selo DEBUG no aviso (`warn_tag`, faixas laranja), painel do relógio forçado com aro laranja, retrato (`hud_portrait`, XP em violeta: progresso do jogador), botão do celular com a bolinha (`phone_button`, `badge_dot`), anel do Radar em 9 quadros de recarga, bússola com mostrador parado e agulha girando, marcas do Radar na borda (seta `edge_mark`, tingida na distorção e no Brilhante), faixa de atalhos (`shortcut_chip`).
- **Sem crescer:** as peças fixas entram na caixa de antes na maior escala inteira de pixel físico (`UiPiece`, `UiIcon` em `app/lib/ui/kit.dart`): o `HudSize` não mudou e o teste de não sobreposição nos três tamanhos passa como antes.
- **Celular:** moldura `phone_body`, fundo `phone_wall`, ladrilhos `app_tile` e `app_tile_new`, ícones do Aseprite; barra de status e Céu com os ícones de lua, clima e evento.
- **Apps:** o visual muda pelas peças comuns, sem tocar na estrutura das telas: `panelBox()` virou a moldura `panel` em nove partes; `PixelButton` e `KButton`, o botão do kit (apertado afunda, desativado sem realce); `KTabs` e `KSegment`, as abas; `KChip`, o chip de condição (ligado com o aro violeta); `KTag` de tipo, a etiqueta de tipo; `SwitchListTile` e `AlertDialog` deram lugar a `KitSwitchTile` e `KitAlertDialog` (mesmos parâmetros); o interruptor solto do Loadout, a `KitSwitch`. O menu de debug ficou como estava.
- **Fechamento (sessão de arte, depois do merge do Hum):** o `panelBox` desenhava pelo `DecorationImage` com `centerSlice` e `scale`, que deixava o miolo em blocos claros e escuros (os espaços vazios do Círculo nas capturas de depois); agora `panelBox`, `cardBox` e `cellBox` (`menu/screen_frame.dart`) desenham pelo `NineSlicePainter` numa `KitDecoration` (`craft/ui_art.dart`). Os cartões de família e a grade do Bestiário, a busca, as fichas e o "onde" da espécie, as fichas do Perfil, os cartões da Fusão e da Coleção, os espaços do Círculo e do Loadout (vazio na `cell`, ocupado no `card` com o aro do sinal), as mensagens e o retrato do Chat e os pedidos do Fórum passaram para o `card` e a `cell` do kit. A barra do kit saiu da Bolsa para `KitBar` (`kit.dart`) e entrou no XP do Perfil e no progresso do Fórum. Ficam no desenho próprio: o sonar do Radar (pintado em pixel reto), as amostras de variante e os marcadores pequenos de estado.
- **Selo "Época 12 em teste":** não existe mais desde a 0.25.2 (modo de desenvolvimento); ficaram o DEBUG e o relógio forçado no estilo de aviso.

### 3. Cores dos tipos

A paleta nova dos 12 tipos (principal, claro, escuro) está em `typeColor`, `typeColorLight` e `typeColorDark` e no guia; nenhum tipo usa o ciano das ferramentas nem o violeta do jogador (o Digital foi para o verde-limão, a Sombra para o ameixa, o Fogo para o vermelho). As Fagulhas do mapa foram regeradas com ela. A etiqueta de tipo é ícone de 8 + nome no tom claro sobre o fundo neutro com o aro do tipo: a proposta de nome claro sobre o escuro do próprio tipo dava de 2,0:1 a 4,2:1.

### 4. Arte que ficou em código

Barco e canoa do Dilúvio, cachorro do passeio (dois quadros, a guia em tira própria até a mão do dono) e o carro da corrida (`ride_hatch`, `ride_sedan`, `ride_suv`: o carro do tráfego com a luz do teto acesa, sem marca de aplicativo) saem do Aseprite na grade de 2 dp, com as cores trocadas pela paleta como o resto do tráfego.

### Medidas

- **Custo do HUD** (emulador, build de profile, mesma cena com o HUD inteiro na tela, builds alternadas): antes build p50 4,5 ms e raster p50 14,0–15,7 ms; depois build 4,1 ms e raster 13,3–13,9 ms. Não subiu (o limite era +1 ms); a diferença é ruído do emulador.
- **Contraste:** todo texto corrido sobre os painéis com 4,5:1 ou mais. Os rótulos violeta, cinza e laranja na face do botão (3,7, 3,6 e 4,49) passaram ao tom claro.
- **Alvo de toque:** 48 dp em tudo que se toca; ficha de filtro, abas e segmento subiram de 36 e 42 dp.

### Testes

Novos: `test/ui/contrast_test.dart`, `test/ui/tap_target_test.dart`, `test/ui/ui_icons_test.dart` (todo app, clima, evento, tipo e lua com ícone; a fase da lua; os extras do tráfego), e "no nível 20 todo app da grade abre sem erro e volta ao celular" em `phone_menu_test.dart`. O de não sobreposição do HUD nos três tamanhos continua.

### Capturas

Em `/tmp/kenoma-shots/0260_*`: antes e depois do HUD, do celular e de dez apps (`antes_depois_<tela>.png`; o depois do Céu foi tirado antes dos ícones de lua e clima entrarem nele), `folha_icones.png` (apps, lua, climas e eventos), `folha_tipos.png`, `folha_kit.png` e `folha_extras_trafego.png`.

## Fase 1 · fatia 16 · Criaturas de ritual das nove famílias (0.26.1)

Versão 0.26.1+54, mesma chave, save no schema 14 (sem mudança). A versão sobe porque os rituais da fase 1 mudam o mundo (o Eco de ritual de cada uma entra na época de desenvolvimento). Instalada no moto g54 em 27/11/2026 por cima da 0.26.0, com `adb install -r`, sem abrir o app. Aprovadas pelo dono em 2026-11-26, as doze (`docs/art/conceitos/rituais/rituais.md`, "Estado final"; folha `docs/art/final/rituais_doze.png`).

- **Condições** (`0530362`): a receita lê o clima e o evento da célula (`climate`), o crepúsculo real (`twilight`) e as combinações `all` e `any`, para seguir a coluna "Onde e quando" do GDD.
- **Nove espécies novas**, uma por commit, com arte final (Espírito, 36 e 96 px, seis animações, três camadas, sete variantes), receita (Círculo nível 5), verbete e Eco de ritual na época de desenvolvimento (**muda o mundo**):

| Espécie | Família | Condição |
|---|---|---|
| Stormlamp | Hum | tempestade, 19h às 5h |
| Noonglass | Glare | sol forte ou arco-íris, 11h às 14h |
| Eaveshroud | Shade | nublado das 20h às 5h, ou Sol Negro |
| Staticroost | Bit | Estática |
| Vigilwick | Wisp | neblina ou Procissão |
| Cairnhollow | Clod | poeira seca |
| Duskwreath | Sprig | crepúsculo real na lua cheia |
| Cratercoil | Wyrm | Sol Negro ou chuva de meteoros |
| Gatewarden | Rust | smog |

- **Mentor:** uma dica por família ao ver o primeiro Eco de ritual dela (`ritual_hint_<familia>`), no formato das três do MVP.
- **Bestiário:** Kilnshade, Rootseer e Wellmirror ganharam verbete com as cinco pesquisas; o detalhe de todo Espírito de ritual mostra as pesquisas e a receita revelada.
- **Agentes:** `criativo` (só decide e entrega a spec) e `executor` (arte por script em lote, `tools/art/rodar.sh`), no lugar do `conteudista`.
- **Correção:** o Stormlamp entrou sem placeholder de sprite e derrubava a carga do mapa (`069f16d`, corrigido em `f3c19d3`).
- **Ficou de fora:** relevo e cicatriz de Fenda como condição; o conceito antigo do Gatewarden (duas folhas de portão) ficou como registro, substituído.

## Fase 1 · fatia 17 · Abertura rápida e o sprite provisório fora da release (0.26.2)

Versão 0.26.2+55, mesma chave, save no schema 14 (sem mudança). Pedido a partir do print do Bestiário no celular (27/11,
00:22): ao abrir o jogo as criaturas demoravam, e o Bestiário mostrava o sprite provisório no lugar de Sootling, Cinderkin e
Kilnshade.

**Medição** no moto g54, build de profile com a chave de release e marcas de tempo temporárias (fora do git), abertura a
frio (`am force-stop` e o ícone pelo `scripts/celular.sh start`); os tempos são desde o `main` do Dart, e o Android leva
mais 0,65 a 1,5 s do toque até ele (`Displayed`).

| | antes (0.26.1) | depois (0.26.2) |
|---|---|---|
| Ícone até o mapa | menu de debug e um toque em "Abrir mapa do jogo" | direto: splash, tela de carregamento, mapa |
| Pedido do mapa até o mapa jogável | 3,9 a 4,4 s | 1,36 s (desde o `main`) |
| Pacotes de região antes do mapa | 3,3 s (São Paulo 2,4 s) | 1,0 s (só Campinas) |
| Sprites provisórios gerados para o mapa | 360, 1,0 s | nenhum (release e profile) |
| Arte das criaturas pronta | 50 s depois do mapa abrir | antes do mapa abrir |
| Arquivos de arte de criatura lidos | 1680 PNGs (0,8 s de leitura, 11,2 s de decodificação, um por vez) | 12 folhas, em paralelo |
| Variantes montadas na abertura | 2940 tiras, 38 s | nenhuma: cada uma na primeira vez que aparece |
| Kit do HUD (258 PNGs) | 0,7 a 1,7 s, um por vez | em paralelo, pronto em ~0,7 s |

- **Folhas por família** (`scripts/pack_creature_atlas.py`): `app/assets/art/creatures/atlas/<família>.png` e `.json`
  (retângulo de cada PNG, o JSON da criatura e o das variantes, e o SHA-256 das fontes). O build do Android roda o script
  antes de empacotar (tarefa `folhasCriaturas`, como `baixarRegioes`), o `sync_creature_art.py` também, e
  `test/ui/creature_atlas_test.dart` falha com uma folha velha. As pastas soltas ficam como fonte, fora do APK. A leitura
  dos arquivos pesava pouco (0,8 s); o que pesava era decodificar 1680 imagens uma a uma. Cada camada se recorta da folha
  na primeira vez que é desenhada: recortar as 1680 na abertura segurava o raster ~1 s.
- **Tela de carregamento** (`ui/game/loading_screen.dart`): o splash do Android no fundo `#1a1424` (também no 12+), depois
  KENOMA e a costura violeta que fecha com o progresso. Durante ela, junto com os pacotes de Campinas: o kit do HUD, as
  Fagulhas e a folha de cada família que nasce na época (hoje as doze). Depois que o mapa abre: o tráfego do Aseprite (que
  começa junto e em geral já chegou) e, 5 s depois, São Paulo, montado noutro isolate.
- **O ícone abre o mapa**: a pilha começa com o menu de debug embaixo e o mapa em cima; o "Menu de debug" do selo de modo
  volta ao menu, como antes.
- **Provisório nunca na release** (`provisionalArt`, `kDebugMode`): sem a arte, o `EcoSprite` é a silhueta escura e o mapa
  não desenha a criatura; as não vistas do Bestiário usam a silhueta da arte de verdade. `test/ui/release_art_test.dart`
  falha se o provisório for desenhado na release.
- **Meta de 3 s**: cumprida na medição (1,36 s do `main` ao mapa jogável, mais o `Displayed`). O que resta de gargalo: o
  Android antes do Dart (0,65 a 1,5 s, varia a cada abertura) e os pacotes de Campinas (1,0 s, com o SHA conferido a cada
  abertura). Nos ~3 s depois de abrir, o aquecimento do próprio mapa (prédios, clima, faixas) ainda derruba quadros (14 a
  57 por segundo, pior quadro de 140 a 190 ms); já era assim e fica para depois.

## Fase 1 · fatia 18 · O SHA-256 guardado e os primeiros segundos do mapa (0.26.3)

Versão 0.26.3+56, mesma chave, save no schema 14 (sem mudança). A 0.26.2 ficou no celular (27/11), com uma medição de
abertura a frio da versão final.

**Medição** no moto g54, build de profile com a chave de release, abertura a frio pelo ícone (`am force-stop` e
`scripts/celular.sh start`), GPS real; os tempos são desde o `main` do Dart, mais o `Displayed` do Android. Marcas
temporárias fora do git: o tempo de cada seção do quadro do mapa (update e cada camada do render), todo quadro acima de
50 ms e o custo somado do SHA, dos tiles da cidade e dos blocos de chão.

| | 0.26.2 (três aberturas) | 0.26.3 (1ª depois de instalar · 2ª · 3ª) |
|---|---|---|
| `Displayed` | 1,33 a 1,88 s | 1,13 · 0,94 · 0,92 s |
| Mapa jogável desde o `main` | 1,49 a 1,75 s | 2,03 · 1,66 · 1,67 s |
| Quadros acima de 50 ms nos primeiros ~20 s | 12, 7 e 7 | 16 · 2 · 4 |
| Pior quadro | 200 a 219 ms | 246 · 206 · 215 ms |
| SHA-256 dos pacotes de Campinas | ~134 ms em toda abertura | conferido na 1ª; 0 ms nas outras |

- **SHA-256 guardado** (`data/sha_memo.dart`): o que bateu fica num JSON nos dados do app, pela instalação (versão e data
  da última instalação ou atualização do APK), o nome, o tamanho e o SHA que a época espera; os arquivos baixados do
  catálogo também pela data. Depois de instalar ou atualizar, tudo se confere de novo. Os pacotes esperam a memória abrir
  (~280 ms com o `PackageInfo` frio), em paralelo com a arte: o mapa aparece na mesma hora.
- **O que derrubava os quadros**, pelas marcas: o chão (blocos que faltavam saíam todos no mesmo quadro, 110 a 210 ms, e a
  primeira montagem da arte da cidade); os carimbos do Aseprite chegando com o mapa aberto (o renderizador era refeito
  inteiro); São Paulo entrando no mundo (a revisão nova refazia o chão, as células e o tráfego de Campinas, 60 a 120 ms);
  e o primeiro GPS longe de onde o mapa abriu (células 36 ms, Outros Veilbreakers 67 ms, tráfego 58 ms).
- **Feito:** os blocos que faltam entram no orçamento do quadro (12 ms, um no mínimo, do centro para fora) e uma revisão
  nova não apaga os blocos, só os marca para refazer; os carimbos e o renderizador do Completo saem na tela de
  carregamento; São Paulo entra sem subir a revisão quando o jogador e a câmera estão longe dela. Com a última posição
  conhecida, a tela de carregamento também prepara os tiles, as células, os Outros Veilbreakers e o tráfego dali.
- **Meta de nenhum quadro acima de 50 ms: não cumprida** (duas rodadas de correção; parei como manda a regra). Sobram três:
  1. o primeiro quadro do mapa (~250 ms entre o update do jogo e o desenho: a primeira montagem dos widgets do mapa ou uma
     coleta de lixo; precisa de um trace da DevTools para saber);
  2. o primeiro GPS quando ele cai longe de onde o mapa abriu (~200 ms): a última posição do Android
     (`getLastKnownPosition`) não responde em 500 ms com o app frio, então o mapa abre no centro de sempre. Saída
     proposta: o jogo lembrar a última posição do mapa no aparelho (guarda localização no disco: precisa do dono);
  3. São Paulo carregando de 5 a 12 s (quadros de 52 a 90 ms): os ~70 MB dos pacotes passam pela thread da interface até
     o isolate. Saída proposta: carregar São Paulo só quando o jogador ou a câmera se aproximam dela.

## Fase 1 · fatia 19 · A última posição, as regiões por distância e o esmaecer (0.26.4)

Versão 0.26.4+57, mesma chave, save no schema 15 (migração pura, testada a partir de um save real levado ao v14). As
decisões do dono depois da 0.26.3:

- **A última posição do mapa** (`map_last_cell`, a célula z21) fica no save deste aparelho e nunca sai dele: o backup e a
  exportação tiram a chave (`exportBackup`), o QR do grupo só leva o código, nada a envia (`docs/distribuicao.md`, seção 6).
  O mapa grava ao mudar de célula (no máximo a cada 30 s, e ao ir para segundo plano). Na abertura, o mapa parte dela e a
  tela de carregamento prepara aquela área (tiles da cidade, células, Outros Veilbreakers, tráfego); sem ela, o cache do
  Android, e sem os dois o centro de sempre. No debug, `scripts/celular.sh cmd "lastcell lat,lon"` fixa a posição guardada
  na sessão (para medir a abertura com o GPS longe).
- **Regiões por distância** (`world/region_reach.dart`, `balance.json` `region_load_km` 40 e `region_unload_km` 60): São
  Paulo e as regiões baixadas entram no mundo a menos de 40 km da borda delas e saem a mais de 60 km (as baixadas ficam no
  disco e continuam "prontas" no catálogo); no Modo Viagem todas entram e nenhuma sai. Teleporte entra pela mesma regra,
  porque muda a posição. Se a abertura já é perto de uma delas, ela entra ainda na tela de carregamento.
- **O primeiro quadro**: a tela de carregamento fica por cima até o mapa desenhar dois quadros e sai num esmaecer de
  300 ms; os toques passam assim que ele começa.

**Medição** no moto g54 (profile, abertura a frio, GPS real; desde o `main`, mais o `Displayed` do Android):

| | partida | esmaecer começa | some | quadros acima de 50 ms depois do esmaecer (20 s) |
|---|---|---|---|---|
| 1ª depois de atualizar (sem posição guardada) | centro padrão | 2,13 s | 2,45 s | 2 (166 e 87 ms) |
| 2ª | célula guardada | 2,06 s | 2,39 s | 0 |
| 3ª | célula guardada | 1,94 s | 2,26 s | 0 |
| com os toques soltos no esmaecer (1ª, 2ª) | célula guardada | 2,61 · 2,11 s | 2,97 · 2,45 s | 6 · 2 (54 a 86 ms) |

- O pico do primeiro quadro (255 a 353 ms, entre o update do jogo e o desenho) acontece antes do esmaecer, escondido: sem
  trace.
- Os que sobram depois do esmaecer são menores: o raster durante o esmaecer (58 a 84 ms: a tela translúcida inteira sobre o
  mapa) e o primeiro segundo do mapa (prédios, mundo e clima, 50 a 86 ms). Entre as aberturas com a mesma versão o número
  variou de 0 a 6, com o celular esquentando depois de muitas medições.
- A abertura com o GPS longe ficou para a 0.26.5 (o teleporte não movia o Conjurador; o celular desconectou).

**0.26.5** (versão 0.26.5+58, mesma chave e save). O teleporte do simulador pelo `celular.sh` (`sim on; tp ...`) não movia
o Conjurador: o relógio do simulador conta do 0 e o do GPS real em milissegundos desde 1970, e só o botão do próprio mapa
zerava o filtro e o marcador na troca de fonte. Pelo comando ou pelo menu de debug (que fica embaixo do mapa desde a
0.26.2), o filtro guardava o tempo do GPS real e recusava toda leitura do simulador como fora de ordem. Agora toda troca de
fonte com o mapa aberto passa por ele (`DevTools.switchSourceInMap`); um teste parte do GPS real, teleporta para São Paulo
pelo comando e confere a posição, o marcador, a célula guardada e a região carregada. Medição (profile, a frio):

| | partida | esmaecer começa | some | quadros acima de 50 ms depois do esmaecer (20 s) |
|---|---|---|---|---|
| 1ª depois de atualizar (SHA conferido de novo) | célula guardada | 2,07 s | 2,44 s | 4 (55 a 99 ms: dois do raster no esmaecer, dois do primeiro segundo do mapa) |
| 2ª | célula guardada | 1,76 s | 2,09 s | 1 (51 ms) |
| GPS a 19 km da célula guardada (teleporte a Valinhos, `sim on; tp`, e abertura no GPS real) | célula guardada (Valinhos) | 1,77 s | 2,10 s | 1 (113 ms) |

- Longe: o mapa abre em Valinhos, preparado pela tela de carregamento, e pula para casa quando o GPS acha (~3,2 s desde o
  `main`); o pulo custa um quadro de 113 ms (mundo, filtro do mundo, tráfego e chão da área nova) e mais nenhum acima de
  50 ms. O `lastcell` não foi preciso.

## Fase 1 · fatia 20 · O menu de debug como registro (0.26.6)

Versão 0.26.6+59, mesma chave e save. O menu de debug serve a dois usuários: o dono, no celular, e o Claude, pelo
`scripts/celular.sh cmd`. Os dois agora são vistas de um registro só (`app/lib/dev/debug_registry.dart`):

- **Registro.** Cada ação ou ajuste é uma entrada com id estável (`world.weather`, `pos.teleport`, `player.xp.add`), nome,
  aba, tipo de controle (alternar, escolha, número, coordenada, ação, leitura), parâmetros e valores válidos, se mexe no
  save e se é destrutiva. Os ids e os comandos de antes (`sim on`, `tp`, `lastcell`, `time.clock`, `map.free`...) são
  aliases; os favoritos guardados migram sozinhos.
- **Linha de comando.** `cmd list` (uma linha por entrada), `cmd state` (JSON do que está fora do real, a fonte de posição
  e o relógio), `cmd <id> <args>` (responde `ok` ou `erro`), `<id> real` desfaz e `<id> ?` descreve. O destrutivo pede
  `confirma=<palavra>`. O `celular.sh cmd` devolve a resposta lida do logcat.
- **Tela.** Gerada do registro: faixa "fora do real" no topo (um chip por override, tocar desfaz só ele, "Voltar tudo ao
  real" desfaz o que não mexe no save), busca, favoritos numa linha, seis abas (Mundo, Posição, Criaturas, Jogador,
  Visual, Sistema), chips em grade de 2, 3 ou 4 colunas, alternar numa linha, descrição atrás do (i). Cores pela spec do
  criativo: violeta escolhido, ciano fora do real, laranja com a tira "MEXE NO SAVE", vermelho com "APAGA: PEDE
  CONFIRMAÇÃO" e diálogo.
- **Teleporte e Mapa livre** viraram uma função: lugares (Unicamp, Centro, Taquaral, Valinhos, São Paulo), "lat, lon"
  colado ou toque longo no mapa do jogo. A tela do mapa livre (`ui/map/map_screen.dart`) saiu.
- **Testes.** Um falha se uma entrada não aparece na aba dela ou se um controle da tela (com o parâmetro) não existe no
  `cmd list`; outros cobrem os aliases, o `state`, a confirmação do destrutivo e a faixa do topo.
- O menu sai da build dos amigos antes de distribuir (`docs/distribuicao.md`, seção 5).
