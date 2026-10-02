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

**Status: implementado, falta medir a fluidez no celular.** O pacote `campinas_e0.bin` é carregado e o SHA-256 conferido contra a época vigente (erro claro na tela se não bate). `world/` consulta bioma por célula z21, por célula z20 e por lat/lon e calcula as células visíveis. O mapa é desenhado em Flame com texturas provisórias por bioma (paleta em `shared/biomes.json`) e cache por chunk. O menu de debug abre o mapa em qualquer coordenada (padrão Unicamp) e mostra, sob o dedo, a coordenada, as células z20 e z21 e os biomas. Todas as células do `.bin` batem com o preview do M1 (`test/data/region_preview_test.dart`). As capturas estão em `docs/m4/`.

## M5 · GPS e simulador

Posição real via `geolocator`, marcador do jogador e círculo da Aura.

Simulador de GPS de debug com:
- joystick;
- teleporte;
- override do relógio UTC.

**Pronto quando:**
- andar com o celular move o marcador;
- o simulador permite testar tudo sentado.

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

## M7 · Encontro completo

- Tocar num Eco dentro da Aura abre a folha de preparo (escolha de selo e tônico) e depois a sintonia do M3 com aquele Eco.
- Sucesso adiciona a criatura à coleção, dá Ectoplasma e atualiza o bestiário.
- Falha perde o selo já consumido e pode fazer a criatura fugir; a fuga entra no registro.
- Marcação por toque longo, com duração e limite.

**Pronto quando** o ciclo andar, encontrar, sintonizar, capturar e voltar ao mapa funciona sem intervenção de debug, inclusive sintonizando um Eco marcado depois de sair da célula.

## M8 · Círculo e bestiário

- Três espaços ativos.
- Habilidades de mapa por faixa de nível: Aura maior, alcance de coleta e alcance do rastreador.
- Bônus de tolerância por tipo forte.
- XP das criaturas no Círculo.
- Bestiário com vista e capturada.

**Pronto quando:**
- trocar o Círculo muda de forma visível a Aura, a coleta ou o rastreador;
- levar um tipo forte deixa a sintonia perceptivelmente mais fácil.

## M9 · Bancada e destilação

Bancada com as quatro receitas: selo simples, selo reforçado, selos de tipo e tônico. Destilação de Ecos em Essência.

**Pronto quando:**
- dá para sustentar capturas só com selos fabricados a partir do que se coleta andando;
- destilar um Eco repetido para fazer um selo melhor parece uma boa troca.

## M10 · Progressão, save e seed

- XP do Conjurador pela curva da spec, com nível máximo 15 e bônus de descanso.
- Save no formato da spec (`KSV1`, SHA-256 e JSON em gzip), versionado, com escrita atômica, rodízio de 3 e migrações.
- Exportar e importar backup.
- Tela de Ajustes com o código do grupo, QR para mostrar e escanear, e a época atual com o aviso de mundo desatualizado.

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
