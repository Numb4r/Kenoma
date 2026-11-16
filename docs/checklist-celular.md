# Checklist do celular

O que precisa ser conferido no moto g54 quando a versão for instalada nele. É cumulativo: cobre tudo desde a última versão
que está no celular (hoje a **0.20.2**, mais as pendências da 0.20.0 e da 0.20.1), e cada versão nova acrescenta os itens
dela. **Um item só sai daqui quando o relatório confirmar que passou.** A ordem vai da versão mais nova para a mais antiga;
as pendências antigas ficam no fim. O código entre crases é o id do item (o workbench guarda as notas por ele: não mude).

Antes de qualquer captura: tela de bloqueio desligada (`isKeyguardShowing=false`) e o Kenoma em primeiro plano.

## 0.20.4

- [ ] `0204-emulador-sem-recompensa` **O emulador não dá recompensa.** No emulador (não no celular), com o interruptor "GPS simulado dá recompensa" do debug desligado, pegue uma Fagulha: o aviso diz "(debug, fora da Bolsa)" e a Bolsa não muda. Ligado o interruptor, a Fagulha entra.
- [ ] `0204-workbench-tailscale` **O workbench abre no celular pelo Tailscale.** Com o servidor rodando no notebook ou no PC, abra o endereço do `docs/workbench.md` no navegador do celular, dentro da tailnet. Mande uma nota de um item: ela tem de aparecer no `workbench/notes.json` da máquina.
- [ ] `0204-workbench-checklist` **A aba Checklist do workbench mostra estes itens**, na ordem deste arquivo, com o filtro por versão, e aceita nota em cada item.
- [ ] `0204-desempenho-4ms` **Desempenho medido no celular.** Debug, Desempenho, com o tráfego, a neblina forçada e uma chuva: tráfego, véu da neblina, bichos e vento e a cobertura do clima somados abaixo de 4 ms por quadro; o cálculo da água do relevo uma vez por tile, fora do quadro. O emulador só serve para comparar antes e depois.

## 0.20.3

- [ ] `0203-pocas-rill` **Dá para perceber as poças do Rill andando na chuva.** Numa chuva de verdade (ou forçada no debug), com um Rill no Círculo, em cada uma das três faixas (níveis 1 a 9, 10 a 19, 20): 2, 4 e 6 poças a mais por quadra de uns 150 m, sempre na rua ou na calçada, algumas com Eco de Água.
- [ ] `0203-marcador-pocas` **O marcador de poças e o "ir até a poça mais próxima".** Debug, Spawns, "Poças no mapa": alvo laranja nas poças do Rill e ciano nas da água do relevo. O botão "Ir até a poça mais próxima" liga o GPS simulado sem recompensa e leva até uma poça.
- [ ] `0203-agua-relevo` **A água do relevo nas baixadas, sem tranco.** Chuva forçada perto da Lagoa do Taquaral e Dilúvio forçado na Norte-Sul (perto da Orosimbo Maia): as poças nas baixadas e a rua alagada aparecem; entrar de bicicleta simulada num bloco novo não dá tranco (o tile da água é calculado fora do quadro e chega em menos de um segundo na build de release).
- [ ] `0203-hum-noite` **Hum à noite perto de postes, e na tempestade.** À noite (ou com o relógio do debug à noite), numa rua com semáforos ou pontos de ônibus, com um Hum no Círculo: Ecos Elétricos a mais junto dos postes, em postes diferentes. De dia com tempo limpo, nenhum; de dia com tempestade forçada, aparecem.
- [ ] `0203-hash-camadas` **Hash da camada base igual no celular e no emulador.** Ponha o emulador no lugar do celular (`scripts/emulador/rota.py --fixo=lat,lon`, com o lat e lon do celular), e compare no debug ("Camada pessoal de spawn") a célula, a janela e os dois hashes: a `base` tem de ser igual e a `pessoal`, diferente.
- [ ] `0203-epoca12-adiada` **A época 12 não começou em 16/nov.** Debug, Assinaturas, "Identidade e época": a época vigente é a 11, e a 12 aparece com início em 2026-12-07 16:00 UTC.

## 0.20.2

- [ ] `0202-shade-becos` **Shade em becos à noite.** À noite, com um Shade no Círculo, num beco (`service=alley`) ou num caminho estreito entre prédios: às vezes um Eco a mais ali, como sob as marquises. Só na época 12 em diante (os becos vêm no arquivo de pontos dela).
- [ ] `0202-hum-wisp-hora` **Hum e Wisp por hora.** Com um Hum (à noite, perto de postes) ou um Wisp (na neblina ou no Sagrado) no Círculo, 1, 2 e 3 Ecos a mais por quadra de uns 300 m e por hora, nas três faixas; os da mesma hora continuam lá a hora inteira.
- [ ] `0202-trabalho-gdd` **O Trabalho das famílias com o texto do GDD**, na aba Atributos do Bestiário: "Trabalho: forja e fornalha (em breve)" para o Soot e a frase depois, e assim nas doze.
- [ ] `0202-sao-paulo-e12` **São Paulo na época 12, depois de publicada.** Só quando a época 12 estiver publicada (feed, catálogo e release `regions-e12`): em São Paulo o mapa baixa o pacote novo (Iluminado e Sagrado aparecem na grade de biomas do debug) e o arquivo de pontos (Hum e Shade passam a ter onde nascer).

## 0.20.1

- [ ] `0201-interruptor-pessoal` **O interruptor da camada pessoal.** Debug, "Camada pessoal de spawn": esconder tira os extras do mapa (o mundo base fica igual), mostrar devolve; o contador de Ecos, poças e materiais sobe enquanto se anda.
- [ ] `0201-shade-wisp-sprig` **Shade, Wisp e Sprig à noite acrescentam o que dizem.** À noite, na mesma célula, com o Círculo vazio e depois com Shade, Wisp e Sprig: os Ecos a mais (sob marquises, Espectrais na neblina ou no Sagrado) e mais variantes entre eles.
- [ ] `0201-clod-bit` **Clod e Bit.** Com um Clod no Círculo, de vez em quando um material vem com uma unidade a mais. Com um Bit, mais Ocultos entre os Ecos da camada pessoal, e destilar um Eco que era Oculto rende 2 de Essência a mais.
- [ ] `0201-janela-seguinte` **Trocar o Círculo muda a camada pessoal só a partir da janela seguinte.** Parado numa célula, troque o Círculo: os extras da janela atual não mudam; mudam quando a janela da célula vira (até 20 min).
- [ ] `0201-texto-habilidade` **A habilidade por extenso.** Na aba Atributos do Bestiário e no Círculo: o efeito por extenso, com a faixa atual e a próxima, e o Trabalho como "em breve". Nenhuma habilidade de mapa diz "em breve".
- [ ] `0201-marcar` **Marcar até 3 espécies.** No Bestiário, marcar destaca a espécie no mapa (cantos e seta em ciano, seta na borda quando fora da tela) e no Radar (losango sem pulso), dentro do alcance do Radar; na Patrulha, avisa uma vez por Eco. A quarta marca é recusada com aviso.

## 0.20.0

- [ ] `0200-sem-som` **Nenhum som toca**, em lugar nenhum, e os Ajustes não têm interruptor de som. A vibração continua.
- [ ] `0200-wyrm-nivel` **O Wyrm não aparece antes do nível 10** do Conjurador, nem nos eclipses, na chuva de meteoros ou no Vento das Fendas.
- [ ] `0200-sintonia-tipos` **A sintonia de cada tipo novo**, pelo debug (Captura, uma espécie de cada tipo): o padrão de resistência certo (faixas pesadas da Terra, salto do Elétrico, blindagem do Metal, clarão da Luz, tinta da Sombra, cópia atrasada do Espectral, glitch do Digital, dial invertido do Feérico, etapas do Dracônico).
- [ ] `0200-bestiario` **O Bestiário.** A vista por família, a grade com filtro, a busca, as 4 abas do detalhe, as bolinhas de variante trocando a arte e as setas entre as formas.
- [ ] `0200-sem-arisco` **Nenhum Eco Arisco ou Agressivo**, e o Eco não foge depois de uma sintonia falha com o Xamã Urbano.

## Pendências antigas

- [ ] `antigo-teste-de-rua` **O teste de rua** de `docs/teste-de-rua.md`, inteiro.
- [ ] `antigo-notificacoes-corrida` **O texto real das notificações de uma corrida de Uber ou 99**, para o Modo Viagem reconhecer o passageiro.
