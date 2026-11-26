# Sprig (Feérico)

- **Bicho:** maritaca (sem troca). Verde-oliva, cabeça mais escura, mancha azul na garganta, crisso vermelho, bico cor de chifre.
- **Pedaço da cidade:** folha seca e árvore de calçada (casca, raiz, caco de pedra portuguesa, gola de concreto).
- **Traço-assinatura:** asa de folha, uma folha seca com a nervura central acesa.
- **Luz do tipo:** pólen verde-ouro (`#CFEA6B`, `#F6FFC8`) nas nervuras e solto; rosa do crepúsculo (`#F5A3B5`) nos olhos e na garganta. Violeta do Véu só na borda do vão do Arquétipo.

## Etapas

- **Fagulha (Pollen Mote):** uma sâmara de tipuana cuja semente é um grão de pólen aceso; a asa da sâmara é a folha seca com a nervura.
- **Eco (Sprigglet):** a maritaca em proporção natural, pairando; o único erro é que as duas asas são folhas secas.
- **Espírito (Fairkin):** a maritaca tomada pela árvore: quatro asas de folha (uma já só nervura), dois olhos do mesmo lado, folha de topete, casca subindo pela barriga, raízes agarradas a um caco de pedra portuguesa.
- **Entidade Maior:** a ave pousada na própria gola de concreto, sem cabeça; no pescoço, três asas de folha em cata-vento; o rosto desceu para o peito (o bico sai de um oco na casca, três olhos em volta), três pés, a cauda virou raiz.
- **Arquétipo:** a copa sem árvore. Três galhos de cinza em roda, três asas de folha morta que viram só nervura, uma gola de pena e bicos sem cabeça fechando sobre o vão; raízes pendem dela com Fagulhas na ponta.

## Regras quebradas

- **Entidade Maior (regra física):** o tempo. As três asas do cata-vento estão em três estações ao mesmo tempo: uma brotando, uma seca, uma já só nervura.
- **Arquétipo (geometria impossível):** os três galhos estão em roda e cada um nasce do meio do seguinte; nenhum tem tronco, a roda não tem começo.
- **Arquétipo (regra física):** a luz. A casca é clara do lado do vão e escura por fora, em toda a volta: ela é iluminada pelo buraco, não pelo céu.

## Arte final (família inteira)

Kit em `tools/art/creatures/_sprig.lua`; espécies em `sprigglet/`, `fairkin/`, `sprig_entidade/` e `sprig_arquetipo/` (nomes e pastas das duas últimas são provisórios), Fagulha em `tools/art/sparks/spark_fae.lua`. Folha: `docs/art/final/sprig.png`.

- **Como o kit funciona:** as quatro etapas estão no kit, com a textura no pixel; ele não carrega mais o build do conceito. Cada etapa é uma função de `(k, S, a)`, em que `a` é a pose do quadro (asas, cabeça, respiração, inclinação); sem `a`, sai a pose do conceito, que é o quadro 0 do `idle` e do retrato. O `build.lua` de cada espécie escolhe a pose por quadro.
- **Sprigglet (laço de 8 quadros a 8 fps):** duas batidas de asa por laço (no alto, descendo, embaixo atrás do corpo, voltando encurtada), a asa de lá acompanha e some atrás da cabeça, o rabo compensa, o corpo sobe 1 px na batida; no meio do laço a cabeça abaixa o bico e volta, e o peito respira. `drift`: o corpo inteiro inclina 8°. `alert`: asas abertas em V, cabeça erguida, parado, a nervura acendendo. `flee`: asas fechadas sobre o corpo e cabeça encolhida, depois sai inclinado com a batida curta. `spawn`: silhueta fechada, meia abertura, pose do `idle`.
- **Fairkin (laço de 8 quadros, `body_dy` 0):** pousada na pedra, que não se mexe. As quatro asas abanam cada uma no seu passo (a de cá e a de lá em sentidos opostos, a escura atrasada), a cabeça vira o bico para baixo e volta, a folha de topete e o rabo de graveto balançam, o peito respira. `drift`: o corpo inclina sobre as raízes. `alert`: asas em leque, cabeça erguida. `flee`: senta na pedra com as asas fechadas e salta com ela, inclinada.
- **Entidade, com o ajuste do dono:** redesenhada no kit (`entidade`), sem mudança nesta rodada. Quatro cabeças de maritaca, cada uma no seu pescoço e virada para um lado (cima, frente, baixo, trás), com o anel do olho, a mancha azul e o bico cor de chifre, todas gritando com a garganta acesa. A folha seca fica só nas duas asas, que batem em sentidos opostos; cada cabeça sobe e desce no seu passo.
- **Arquétipo (6 quadros a 5 fps):** as seis cabeças se mexem fora de fase: cada pescoço balança no anel, estica e encolhe, a cabeça vira para onde grita e o bico abre e fecha (a maior só encolhe, porque já está no limite do quadro); asas e rabos também. O vão anda em outro ritmo: os três lóbulos da borda giram, as cabeças de dentro afundam e voltam duas vezes por laço, o pontilhado corre. Pelo `K.run`: a máscara atrasa um quadro, no `spawn` ela se fecha sobre o vão, no `flee` os pescoços encolhem, os bicos fecham e o vão engole o resto. `alert`: tudo parado, pescoços esticados, bicos abertos.
- **Luz:** só a do tipo Feérico da paleta (`#C0669E`, `#FFA8E0`, `#FFD6F1`), pelo `fae()` do conceito, no lugar do pólen verde-ouro e do rosa da linha "Luz do tipo" acima. `leds` é o tom claro (brilho do olho, ponta das nervuras); o resto é `glow`.
- **Costuras do Véu:** Sprigglet três, curtas e de 1 px; Fairkin duas mais largas; Entidade uma larga, no peito; Arquétipo nenhuma (o vão); a Fagulha ficou sem, como as outras refeitas.
- **Retratos:** 96 nas três etapas de baixo; o do Arquétipo é o bando inteiro em 128 (escala 1,85, margem de 5 px), com o `_retrato.lua`.

## Rodada 2 (substitui a rodada 1 nestas etapas; aguarda aprovação)

| Etapa | O que é | Regra quebrada |
|---|---|---|
| Entidade Maior | Árvore de calçada de cabeça para baixo: a copa é um bando fundido (três cabeças, uma virada e sem olhos) sobre pontas de asa-folha; as raízes, pés de ave, seguram a calçada no alto. Duas costuras largas no tronco. | a calçada fica no ar e as folhas caem para cima |
| Arquétipo | Maritaca de frente, asas erguidas, espelhada: dois perfis sem olho de costas um para o outro; entre eles o vão em forma de folha, com bicos repetidos para dentro. | física: pousa num galho que nasce da própria cauda, sem nada embaixo; geometria: os dois perfis da mesma cabeça ao mesmo tempo |

## Rodada 3 (substitui a rodada 2 nestas etapas; aprovada)

**Aprovada pelo dono** (`docs/art/conceitos/rodada3/rodada3.png` e `arquetipos.png`): a Entidade Maior e o Arquétipo em 64. A família está aprovada por inteiro e segue para a arte final sem nova rodada de conceito.

**Ajuste que entra direto na arte final, Entidade Maior:** o conceito lê como moita, perto demais do Frond. Pelo menos três cabeças de maritaca com bico e olho nítidos, saindo em direções diferentes. A folha seca fica só nas asas.

A luz de todas as peças desta rodada é só a da paleta do tipo.

| Etapa | O que é | Regra quebrada |
|---|---|---|
| Entidade Maior | Bando fundido num corpo só de pena verde-oliva: quatro cabeças de maritaca em pescoços próprios, todas de bico aberto com a garganta acesa, uma virada para trás. Leque de asas de folha seca, dois rabos, pés que se seguram. Costura larga no peito. | as asas estão cada uma num ponto diferente da batida e o corpo não cai |
| Arquétipo | Seis maritacas cinza, sem olho, de tamanhos diferentes, gritando para a frente e para os lados; os pescoços saem de um mesmo anel de pena. Dentro do anel está o vão, com as cabeças repetidas para dentro. Asas de folha morta varridas para trás. | geometria: os pescoços saem de um corpo que não está lá; física: as asas são só nervura da metade para a ponta e ele paira |
