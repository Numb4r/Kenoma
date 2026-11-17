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
