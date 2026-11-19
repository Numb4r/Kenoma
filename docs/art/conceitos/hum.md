# Hum (Elétrico)

- **Bicho:** mariposa-esfinge (mantida: é o Humoth).
- **Pedaço da cidade:** letreiro de LED e fios; nas etapas altas, a rede elétrica do bairro (transformador de poste, cruzeta, isolador).
- **Traço-assinatura:** o olho de LED, ciano `#5fd3c6` com o miolo claro, o mesmo bloco em todas as etapas; os veios elétricos amarelos acompanham.
- **Materiais:** pó de asa índigo, pelo roxo-escuro, cobre desencapado, borracha de cabo, aço galvanizado, porcelana, madeira de poste. No Arquétipo a asa vira cinza.

| Etapa | Nome | Mapa | O que é |
|---|---|---|---|
| Fagulha | Arc Mote | 12 | Um ocelo arrancado da asa, ainda aceso, com um veio pendurado soltando faísca. |
| Eco | Humoth | 28 | A mariposa-esfinge com dois olhos de letreiro nas asas e veios elétricos. Não muda. |
| Espírito | Coilkin | 36 | A mariposa tomada pelos fios: abdômen em bobina de cobre, asas de trás só na armação de fio, três antenas (a do meio é um fio desencapado) e três olhos, dois numa asa e um na outra. |
| Entidade Maior | sem nome | 48 | O poste é o corpo: o transformador abriu numa boca de pé, com dentes de aleta e olhos lá dentro; duas asas rasgadas pendem como mortalha e a terceira sobe atrás da cruzeta, com três, dois e dois olhos de tamanhos diferentes; mais olhos soltos no poste, e cinco antenas no lugar das pernas. Nenhuma cabeça. **Regra quebrada: gravidade.** Os fios da cruzeta caem para cima. |
| Arquétipo | sem nome | 64 | A forma original: no lugar do corpo, uma boca redonda de armação de letreiro com doze dentes, e dentro dela um túnel de armações com o olho de LED no fim e outros pelo caminho, em espiral. Três asas de cinza de tamanhos diferentes (três, um e dois olhos), sete antenas sem cabeça em volta da gola de pelo. A armação está partida embaixo, o vão escorre para fora e o raio sai dali. O vão é mais escuro que o contorno (`#0d0914`). **Regra quebrada: o dentro é maior que o fora.** O túnel afunda mais do que o corpo tem de fundo; o raio não cai do céu, sai de dentro dela. |

Fonte: `tools/art/creatures/conceitos/hum/build.lua`. Cada etapa é uma função da escala. Fagulha e Espírito: o retrato é o desenho do mapa ampliado, com o olho em matriz de LED. Entidade Maior e Arquétipo: o retrato mantém a pose e ganha detalhe só dele (pupila em cada olho, cada uma para um lado; barbas nas antenas; escamas e veios ramificados nas asas; veio da madeira e rebites; na Entidade, olhos inteiros dentro da boca; no Arquétipo, os dentes da segunda armação, a terceira armação do túnel e olhos inteiros no vão). O Coilkin antigo e a Fagulha elétrica de `tools/art/sparks/` ficam substituídos por estes quando a etapa for aprovada.
