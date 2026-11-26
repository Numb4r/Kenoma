# Rust (Metal)

- **Bicho:** besouro, fechado no besouro-rinoceronte (*Strategus aloeus*), que é comum na cidade e vem para a luz. Não é troca: é a escolha da espécie, porque o chifre dele vira a ponta de lança do portão.
- **Pedaço da cidade:** grade e portão de ferro: barra redonda, travessa, ponta de lança, chapa rebitada, cadeado, resto de tinta verde.
- **Traço-assinatura:** casco de grade: barras de ferro a cada 3 px com vão entre elas, e luz fria por trás do vão. O Metal é essa luz que passa pela grade.
- **Cor:** ferro escuro, ferrugem (`#874A2E`, `#B06A3C`), tinta verde gasta, latão do cadeado; o emissivo é azul-aço frio (`#9FB3C8`, `#EAF2FA`, `#5E7088`). No Arquétipo o corpo vira cinza de aço e o violeta do Véu aparece só na borda do vão.
- **Contorno:** pata fina de ferrugem sem contorno do Espírito para cima (entra depois do contorno, para não fechar bolsos).

## Etapas

- **Fagulha (Filing Mote):** um caco de grade que a limalha remontou, com a luz ainda nos vãos.
- **Eco (Rustling):** o besouro-rinoceronte em proporção natural; os élitros são uma grade enferrujada com luz dentro, como uma lanterna, o chifre é uma ponta de lança, e uma barra do casco está arrombada para fora.
- **Espírito (Gratekin):** um élitro se ergueu como folha de portão de barras torcidas, com três lanças em cima; sete patas, dois chifres, cinco olhos de parafuso no pronoto e um cadeado fechado pendurado atrás.
- **Entidade Maior:** a catraca: três élitros de grade em cata-vento em volta de um cubo de chapa; no lugar do rosto, um buraco de fechadura aceso com sete olhos de parafuso em volta, e oito patas finas que não tocam o chão.
- **Arquétipo:** a jaula: uma gaiola de barras cinzentas vista pelo canto, com as barras finas abertas à força em volta de um vão; do besouro sobram três chifres de lança e três feixes de patas.

## Regras quebradas

- **Entidade Maior (apoio):** ela pende de um cadeado fechado em nada; a corrente está esticada e não há onde ela se prenda.
- **Arquétipo (geometria):** as três barras da frente e as três de trás da gaiola trocam de lugar sem dobrar (cada uma passa por cima de uma e por baixo da outra), e nenhuma chega ao canto: todas acabam na borda do vão.
- **Arquétipo (regra física):** dentro do vão a luz anda reta e dobra em esquadro, como barra de ferro.

## Arte final (família inteira)

Kit em `tools/art/creatures/_rust.lua`; espécies em `rustling/`, `gratekin/`, `rust_entidade/` e `rust_arquetipo/` (nomes e pastas das duas últimas são provisórios), Fagulha em `tools/art/sparks/spark_metal.lua`. Folha: `docs/art/final/rust.png`. A Entidade e o Arquétipo são os da rodada 3. O `pebblet/kit.lua` antigo não é mais usado por nenhum build.

- **Luz:** só a do tipo Metal da paleta (`#566274`, `#93A1B3`, `#CCD6E2`), no lugar do azul-aço da linha "Cor" acima, em toda etapa. `leds` é o miolo da luz atrás da grade (no abdome, na Entidade); o resto é `glow`. O Arquétipo não tem `leds`.
- **Costuras do Véu:** Rustling três, curtas e de 1 px (duas no pronoto, uma na cabeça), longe da luz da grade; Gratekin duas mais largas (no pronoto, em cima e embaixo dos parafusos); Entidade uma larga, na dobradiça; Arquétipo nenhuma (o vão); a Fagulha ficou sem, como as outras refeitas.
- **Animação:** no Rustling a luz de dentro respira, a barra arrombada treme e o chifre acena; no Gratekin a folha erguida range, o cadeado balança e os parafusos giram; na Entidade as duas folhas rangem uma depois da outra, a luz do abdome respira e os vergalhões, presos no chão, dobram para acompanhar o corpo; no Arquétipo as faixas do vão descem atrás das barras, a folha aberta range e as nove patas mexem cada uma no seu passo (mais as regras do vão do `K.run`).
- **Retratos:** 96 nas três etapas de baixo; o do Arquétipo é o besouro inteiro em 128 (escala 1,85, margem de 5 px), com o `_retrato.lua`: o fundo do vão é um só atrás de todas as barras, violeta junto da moldura do casco e quase preto no meio, com estrelas.

## Rodada 2 (substitui a rodada 1 nestas etapas; aguarda aprovação)

| Etapa | O que é | Regra quebrada |
|---|---|---|
| Entidade Maior | O portão inteiro: duas folhas de grade (élitros), chapa da fechadura no meio com o buraco aceso como rosto e três parafusos de olho, chifre de lança, seis patas de ferrugem. Uma costura larga embaixo da chapa. Luz do Metal da paleta. | a corrente fica de pé e o cadeado cai para cima |
| Arquétipo | Besouro de frente, élitros abertos como folhas de portão, espelhado; entre elas o vão em arco, com portão dentro de portão. Três chifres, seis patas de aço fora do chão. | física: a luz acende atrás das barras sem haver nada atrás; geometria: portão dentro de portão |

## Rodada 3 (substitui a rodada 2 nestas etapas; aprovada)

**Aprovada pelo dono** (`docs/art/conceitos/rodada3/rodada3.png` e `arquetipos.png`): a Entidade Maior e o Arquétipo em 64. A família está aprovada por inteiro e segue para a arte final sem nova rodada de conceito.

A luz de todas as peças desta rodada é só a da paleta do tipo.

| Etapa | O que é | Regra quebrada |
|---|---|---|
| Entidade Maior | Besouro-rinoceronte de perfil com os élitros levantados; cada élitro é uma folha de portão com barras, travessa e lanças. O abdome fica aberto e aceso; costura na dobradiça. | as patas não são dele: sete vergalhões saem do chão e seguram o corpo por onde alcançam |
| Arquétipo | Besouro em pé, alto e torto, sem cabeça (um colar vazio). O casco é só grade, com o vão atrás das barras; um élitro fechado, o outro aberto como folha de portão. Nove patas finas, seis de um lado e três do outro. | física: as patas saem de dentro do vão e nenhuma toca o chão; geometria: a folha aberta e o casco fechado são a mesma grade |
