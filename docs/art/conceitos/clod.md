# Clod (Terra)

- **Bicho:** tatu-bola (*Tolypeutes tricinctus*), sem troca. De perfil, andando na ponta das garras da frente, com os dois escudos e as três cintas.
- **Pedaço da cidade:** cascalho e entulho de obra: brita, seixo ocre, caco de tijolo, guia de concreto quebrada, vergalhão enferrujado.
- **Traço-assinatura:** placas de cascalho (seixos com rejunte escuro, cada um com luz em cima e sombra embaixo) e a junta âmbar acesa entre elas. A Terra é a luz que vaza da junta.
- **Cor:** cinzas de concreto, ocre, terra roxa e queratina; o emissivo é só âmbar (`#E8B860`, `#FFF0D0`, `#C7823B`). No Arquétipo o corpo vira osso e cinza e o violeta do Véu aparece só no vão.

## Etapas

- **Fagulha (Grit Mote):** uma placa de cascalho que se soltou da carapaça, com a junta ainda acesa na borda quebrada.
- **Eco (Pebblet):** o tatu-bola em proporção natural; os escudos são placas de cascalho, as juntas das cintas acendem, e falta uma placa no escudo de trás: o buraco é luz.
- **Espírito (Bouldkin):** a metade da frente da carapaça virou um bloco de guia quebrada com vergalhão e musgo; cinco patas, dois rabos e três olhos em fila numa cabeça pequena demais.
- **Entidade Maior:** o entulho do bairro de pé como um disco, à maneira do Tribrachidium: três braços de carapaça em cata-vento, cada um terminando numa cabeça de tatu sem olhos; os três olhos estão no entulho, garras a mais em volta da borda.
- **Arquétipo:** a bola que não fecha: uma espiral de cintas cor de osso em volta de um vão, com um colar de garras viradas para dentro; do tatu sobram três feixes de garras de cavar e três escudos de cabeça sem rosto.

## Regras quebradas

- **Entidade Maior (peso):** doze metros de entulho se equilibram na ponta de uma garra só, e a poeira dela sobe em vez de cair.
- **Arquétipo (geometria):** a ponta de fora da espiral passa por baixo do próprio começo, e dentro do vão está a mesma espiral outra vez, e outra dentro dela: o dentro é maior que o fora e não tem fundo.
- **Arquétipo (regra física):** não tem chão nem peso próprio; o cascalho em volta cai para dentro dela de todos os lados.

## Arte final (família inteira)

Kit em `tools/art/creatures/_clod.lua`; espécies em `pebblet/`, `bouldkin/`, `clod_entidade/` e `clod_arquetipo/` (nomes e pastas das duas últimas são provisórios), Fagulha em `tools/art/sparks/spark_earth.lua`. Folha: `docs/art/final/clod.png`. A Entidade é a bola de entulho da rodada 3; o Arquétipo é o tatu partido no meio com o vão em ampulheta (o que está em `rodada3/arquetipos.png`). O `pebblet/kit.lua` antigo continua na pasta porque `gratekin` e `rustling` ainda o usam.

- **Luz:** só a do tipo Terra da paleta (`#7E5A32`, `#C0915A`, `#E6C594`), no lugar do âmbar da linha "Cor" acima. `leds` são o buraco de luz do Pebblet, os três olhos do Bouldkin e o olho aceso da cabeça virada da Entidade; o resto é `glow`.
- **Ajuste do dono na Entidade:** as cabeças do mapa são desenhadas pixel a pixel (escudo de placas, duas orelhas, olho, focinho escuro). A da direita é a cabeça inteira de perfil; a da esquerda sai do lado oposto, de cabeça para baixo, com o olho aceso; a terceira sai pelo alto.
- **Costuras do Véu:** Pebblet três, curtas e de 1 px (os dois escudos e o escudo da cabeça), longe das juntas; Bouldkin duas mais largas (escudo de trás e face do bloco); Entidade uma larga, fechando a bola embaixo; Arquétipo nenhuma (o vão); a Fagulha ficou sem, como as outras refeitas.
- **Animação:** no Pebblet a luz corre pelas juntas, a cabeça fareja e o rabo balança; com medo fecha em bola e foge rolando (o `flee` é a bola girando). O Bouldkin anda devagar, as cinco patas fora de passo e os dois rabos um contra o outro. A Entidade balança sem abrir e cada cabeça entra e sai da trinca no seu passo. No Arquétipo a metade de trás sobe com o `body_dy` e a da frente um quadro depois, as cintas de dentro do vão afundam e o cascalho cai de lado para ele (mais as regras do vão do `K.run`).
- **Retratos:** 96 nas três etapas de baixo; o do Arquétipo é o tatu inteiro em 128 (escala 1,85, margem de 5 px), com o `_retrato.lua`.

## Rodada 2 (substitui a rodada 1 nestas etapas; aguarda aprovação)

| Etapa | O que é | Regra quebrada |
|---|---|---|
| Entidade Maior | Tatu pequeno, seis patas, cintas acesas; a carapaça vira um monte de entulho que alarga para cima (cascalho, entulho, guia, parede), com um segundo rosto virado no alto. Uma costura larga entre o tatu e o monte. | o monte é mais largo em cima e não cai; o cascalho rola morro acima |
| Arquétipo | Tatu de perfil partido no meio: dois escudos de osso, no lugar das cintas o vão em ampulheta com as cintas repetidas menores; cabeça pequena demais e sem rosto, garras grandes demais. | física: as metades andam sem estar ligadas, e o cascalho cai de lado para dentro do vão; geometria: as cintas não chegam ao fundo |

## Rodada 3 (substitui a rodada 2 nestas etapas; aprovada)

**Aprovada pelo dono** (`docs/art/conceitos/rodada3/rodada3.png` e `arquetipos.png`): a Entidade Maior e o Arquétipo em 64. A família está aprovada por inteiro e segue para a arte final sem nova rodada de conceito.

**Ajuste que entra direto na arte final, Entidade Maior:** pelo menos uma cabeça de tatu legível em 48 px, saindo de um ponto errado da bola (de cabeça para baixo ou do lado oposto às patas).

A luz de todas as peças desta rodada é só a da paleta do tipo.

| Etapa | O que é | Regra quebrada |
|---|---|---|
| Entidade Maior | Tatu fechado em bola de entulho (escudo de cascalho, pedaço de parede, vergalhão, as três cintas com a junta acesa). Três cabeças e três patas saem dela por onde não há abertura, cada uma de uma trinca acesa. A costura fecha a bola embaixo. | a bola não abre, e o que está dentro dela está fora |
