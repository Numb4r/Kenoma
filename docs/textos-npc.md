# Textos dos NPCs (0.24.5: Outros Veilbreakers, Veículos do Véu, Ônibus Espectral)

Para revisão do dono. A thread principal copia daqui para `app/assets/data/`. Base: GDD, "Outros Veilbreakers", "Veículos do Véu", "Ônibus nos pontos". Lacunas entre chaves são preenchidas pelo código. Tom: gente da rua que também escuta o Véu, curto, sem exclamação. Uma fala por linha, até ~90 caracteres já com a lacuna preenchida em mente.

Lacunas usadas: `{da}` (o que o jogador entrega, com quantidade), `{recebe}` (o que o jogador leva, com quantidade), `{familia}` (nome próprio da família, sem artigo), `{metros}` (número, a unidade "m" já está no texto), `{direcao}` (norte, sul, leste, oeste, nordeste...; sempre depois de "para o" ou "sentido"), `{min}`, `{evento}`, `{dias}`, `{seg}`.

## Nomes

Só primeiro nome. Gênero: m, f ou n (neutro).

- m: Caio, Davi, Enzo, Tiago, Raul, Jonas, Ícaro, Benício, Otávio, Ravi, Luan, Heitor, Moacir, Wesley, Kauê, Severino
- f: Lia, Jade, Íris, Marina, Tainá, Dandara, Cecília, Rosa, Yara, Nina, Olívia, Thaís, Jussara, Aline, Mirela, Kelly
- n: Ariel, Dani, Cris, Alê, Sam, Francis, Jô, Kim

### Apelidos

Formato: "Nome, o Apelido" (m), "Nome, a Apelido" (f), "Nome, Apelido" (n, sem artigo). O artigo segue o gênero do nome, não o da palavra ("Jade, a Giz"). Onde há duas formas, `m / f`; para n vale a primeira.

- Estática
- Faísca
- Antena
- Chiado
- Giz
- Ruído
- Mariposa
- Costura
- Poste
- Fuligem
- Lacre
- Vigia
- Insone
- Escuta
- Sem-Sinal
- Meia-Noite
- Pé-de-Vento
- Andarilho / Andarilha
- Calado / Calada
- Canhoto / Canhota

## Escolas

Título visto na folha, abaixo do nome. Duas variações por escola, sorteadas pela seed.

- `technomancer`: Tecnomante de rua | Tecnomante de antena
- `shaman`: Xamã Urbano de praça | Xamã Urbano de calçada
- `sealer`: Selador de esquina | Selador de giz
- sem escola: Sem escola ainda | Conjurador sem escola

## Falas

### saudacao
- Você também escuta. Dá para ver pelo jeito de segurar o aparelho.
- Boa. Achei que só eu andava por aqui com o dial ligado.
- Não te conheço, mas conheço esse chiado.
- Fala baixo. Tem um Eco ali que ainda não decidiu se fica.
- Outro Veilbreaker. A cidade está ficando pequena.
- Passando também? A rua hoje está com o Véu fino.
- Opa. Sua Aura encostou na minha, desculpa.
- Você é novo por aqui ou eu que ando distraído?
- Pode chegar. Eu não mordo, só troco.
- Tudo quieto? Quieto demais, eu diria.

### saudacao_conhecido
- Você de novo. Bom sinal.
- Olha quem voltou. A bolsa veio mais cheia hoje?
- Já reconheço seu passo antes de ver a Aura.
- De novo por aqui. Esse bairro te pegou, hein.
- E aí. Guardei uma coisa pensando em quem passasse.
- Você troca direito. Isso é raro na rua.
- Chegou na hora. Eu já ia embora.
- Ainda com o mesmo dial? Aguenta bem.
- Opa. Hoje eu tenho coisa melhor que da outra vez.
- Senta um minuto. O Véu não foge.

### saudacao_amigo
- Estava te esperando. Não conta para ninguém.
- Para você eu abro a bolsa de dentro.
- Meu chiado favorito chegou.
- Ouvi uma coisa hoje e pensei: isso é para você.
- Com você eu não preciso baixar a voz.
- Chegou quem escuta de verdade.
- Se eu sumir um dia, procure onde a gente sempre troca.
- Hoje a troca é boa. Para os outros eu digo que acabou.
- Você anda melhor que eu, já. Não espalha.
- Vem cá. Tem coisa que só se conta de perto.

### oferta
- Me dá {da} e leva {recebe}. Sai perdendo um pouco, mas hoje é o que tem.
- Tenho {recebe} sobrando. Por {da} é seu.
- Preciso de {da}. Pago com {recebe}, e não reclame da conta.
- {da} por {recebe}. Rua não dá troco.
- Troco {recebe} por {da}. Uma vez por dia, que eu também preciso andar.
- Você tem {da}? Eu tenho {recebe}. O resto é conversa.
- Hoje eu aceito {da}. Em troca, {recebe}.
- {recebe}, saindo agora. Custa {da}.
- Estou atrás de {da}. Se ajudar, leva {recebe}.
- Negócio simples: {da} seu, {recebe} meu. Topa?

### troca_feita
- Feito. Bom para mim, razoável para você.
- Fechado. Amanhã tem outra.
- Era o que eu precisava. Vai com calma.
- Certo. Guarda bem, isso some fácil na bolsa.
- Trocado. A rua agradece.
- Pronto. Ninguém viu, ninguém ouviu.
- Boa troca. Para mim, pelo menos.
- Combinado e cumprido. Assim que eu gosto.
- Valeu. Você facilita a minha volta para casa.
- Feito. Se perguntarem, foi um bom preço.

### ja_trocou_hoje
- Hoje já foi. Volta amanhã.
- Uma por dia. Mais que isso o Véu repara.
- Já trocamos hoje. Minha bolsa também tem fundo.
- Amanhã eu trago outra coisa. Hoje acabou.
- Calma. Quem troca duas vezes no dia fica devendo.
- Por hoje é só conversa.
- Já levou o que eu tinha. Deixa a rua repor.
- Amanhã, mesmo lugar, se eu ainda estiver por aqui.

### sem_material
- Você não tem o que eu preciso. Fica para outro dia.
- Sua bolsa está leve para essa troca.
- Falta coisa aí. Dá uma volta no quarteirão e volta.
- Sem isso não fecha. Eu espero até amanhã.
- Olhei daqui: não tem. Não adianta sacudir a bolsa.
- Ainda não. Junta mais um pouco e me procura.
- Sem o material eu só posso te dar bom-dia.
- A rua dá isso de graça, é só andar. Depois a gente troca.

### sintonizando
- Um {familia}. Já estava indo embora, eu só não deixei.
- Espera. Acabei de fechar um {familia} e a mão ainda treme.
- Você viu? {familia}. Quase escapou no último giro.
- Esse {familia} ia sumir de qualquer jeito. Melhor comigo.
- Peguei um {familia} agora. O dial ainda está quente.
- Shh. O sinal do {familia} ainda está assentando.
- {familia}, no fim do sinal. Só pego os que ninguém mais ia pegar.
- Era um {familia} velho, quase sem onda. Deu dó de deixar.
- Pronto, {familia} guardado. Agora posso conversar.
- Não era seu, fica tranquilo. Aquele {familia} já estava apagando.

## Rumores

Todos verdadeiros: o código só escolhe um modelo quando o fato existe no mundo determinístico.

### familia
- Vi um {familia} a uns {metros} m daqui, para o {direcao}.
- Tem {familia} rondando, {metros} m sentido {direcao}. Eu não tinha o selo certo.
- Se você procura {familia}: {metros} m para o {direcao}. De nada.
- Passei por um {familia} agora há pouco. Uns {metros} m, sentido {direcao}.
- O chiado de {familia} vem dali, para o {direcao}. {metros} m, no máximo.
- Deixei um {familia} para trás, {metros} m para o {direcao}. Ainda deve estar lá.
- Anda {metros} m sentido {direcao}. Tem um {familia} que não era para mim.
- {familia}, {metros} m para o {direcao}. Vai devagar, ele assusta fácil.

### onibus
- O Espectral passa no ponto mais perto em {min} min. Eu não subiria.
- Ônibus Espectral em {min} min, ali no ponto. Só para olhar.
- Daqui a {min} min o Espectral encosta no ponto. Sempre desce alguém que some.
- Quer ver o Espectral? {min} min, no ponto mais próximo. Ele é pontual.
- Em {min} min passa o que não está na tabela. Ponto aqui do lado.
- Faltam {min} min para o Espectral. Dá tempo de chegar andando.
- O ponto mais perto recebe visita em {min} min. Não é linha da prefeitura.

### evento
- {evento} chega em {dias:dia}. Eu já estou juntando material.
- {dias?Falta|Faltam} {dias:dia} para {evento}. A rua já está diferente, repara.
- Ouvi que {evento} vem em {dias:dia}. Deixa a Bancada pronta.
- Em {dias:dia}, {evento}. Quem guarda selo agora agradece depois.
- {evento} em {dias:dia}. O Véu sempre afina antes.
- Marca aí: {evento}, daqui a {dias:dia}.
- É hoje: {evento}. Por isso tem tanta gente na rua. (só com `{dias}` = 0)
- {evento} já começou. Não fica parado aqui comigo. (só com `{dias}` = 0)

### brilhante (raro, relação alta)
- Só para você: um {familia} Brilhante, {metros} m para o {direcao}.
- Vi brilho de {familia} a {metros} m, sentido {direcao}. Não contei para mais ninguém.
- Tem um {familia} Brilhante a {metros} m para o {direcao}. Eu errei o dial. Vai você.
- Corre sem correr: {familia} Brilhante, {metros} m, sentido {direcao}.
- Um {familia} que brilha, {metros} m para o {direcao}. Leva o seu melhor selo.
- Guardei esta para quem troca direito: {familia} Brilhante, {metros} m, sentido {direcao}.

### oculto (raro, relação alta)
- Tem algo escondido a {metros} m, para o {direcao}. O Radar acha, o olho não.
- Passa o Radar {metros} m sentido {direcao}. Eu senti e não vi.
- Um Eco oculto, {metros} m para o {direcao}. Quem me contou foi a estática.
- A uns {metros} m, sentido {direcao}, o chiado muda. Tem coisa embaixo.
- Não aparece no mapa, mas está lá: {metros} m para o {direcao}.
- {metros} m para o {direcao} tem um Eco que não quer ser visto. Pulsa o Radar.

## Conhecidos

Fixos por bairro. `rotina` é lida por código: `dias; hora inicial-hora final; lugar`, dias em `seg ter qua qui sex sab dom`, horas locais em 24 h, lugar entre `praca`, `iluminado`, `urbano`. As três falas substituem a saudação comum, em qualquer nível de relação.

### Dona Zefa, a Costura
- gênero: f
- escola: `sealer`
- personalidade: Costureira aposentada que remenda o Véu como remendava barra de calça, e cobra pelo serviço.
- rotina: `ter, qui; 15-18; praca` (terças e quintas, 15 h às 18 h, nas praças)
- Senta. Em pé ninguém troca direito.
- O Véu está descosturando ali na esquina. Depois eu passo um ponto.
- Você anda rápido demais. Selo bom se faz devagar.

### Tico, o Antena
- gênero: m
- escola: `technomancer`
- personalidade: Conserta celular na calçada e jura que metade dos defeitos é Eco morando dentro.
- rotina: `seg, qua, sex; 18-21; iluminado` (segundas, quartas e sextas, 18 h às 21 h, no Iluminado)
- Deixa eu ver seu aparelho. Não, não vou abrir. Hoje não.
- Debaixo de poste aceso o sinal vem limpo. Por isso eu fico aqui.
- Se o seu dial travar, não fui eu.

### Jurema, a Mariposa
- gênero: f
- escola: `shaman`
- personalidade: Vende ervas e só aparece de noite; fala com os Ecos antes de falar com gente.
- rotina: `sex, sab; 19-23; praca` (sextas e sábados, 19 h às 23 h, nas praças)
- Espera. Eu estava no meio de uma conversa. Pronto, pode falar.
- A praça de noite é outra praça. Você já percebeu.
- Trouxe folha? Quem traz folha eu atendo primeiro.

### Seu Nilo, o Vigia
- gênero: m
- escola: sem escola
- personalidade: Porteiro noturno que escuta o Véu há trinta anos e nunca quis escolher lado.
- rotina: `seg, ter, qua, qui; 20-23; urbano` (segunda a quinta, 20 h às 23 h, no Urbano)
- Boa noite. Aqui passa de tudo, e eu anoto.
- Escola é coisa de jovem. Eu só escuto.
- Vi você ontem na outra rua. Não precisa confirmar.

### Bia, a Faísca
- gênero: f
- escola: `technomancer`
- personalidade: Entregadora de bicicleta que cruza a cidade inteira e troca sem descer do selim.
- rotina: `seg, ter, qua, qui, sex; 11-14; urbano` (segunda a sexta, 11 h às 14 h, no Urbano)
- Rápido, que eu tenho entrega. Mentira, tenho cinco minutos.
- Hoje eu passei por três bairros. Cada um chia de um jeito.
- Você ainda anda a pé? Respeito. Eu não tenho essa paciência.

### Ariel, Sem-Sinal
- gênero: n
- escola: `sealer`
- personalidade: Fala pouco, desenha sigilos a giz no chão e some quando chove.
- rotina: `sab, dom; 9-12; praca` (sábados e domingos, 9 h às 12 h, nas praças)
- Cuidado onde pisa. Esse traço ainda não secou.
- Oi.
- Hoje o chão está bom para giz. Amanhã não sei.

### Mestre Otacílio, o Calado
- gênero: m
- escola: `shaman`
- personalidade: Jogador de dama da praça; ganha de todo mundo e diz que os Ecos sopram as jogadas.
- rotina: `qua, dom; 14-17; praca` (quartas e domingos, 14 h às 17 h, nas praças)
- Sua vez. Na troca, digo. Na dama você não ganha.
- Paciência é a única escola que presta. As outras são enfeite.
- Fica quieto um instante. Ouviu? Pois é.

### Lorena, a Meia-Noite
- gênero: f
- escola: sem escola
- personalidade: Garçonete de fim de turno; troca o que os clientes esquecem e o que o Véu deixa nas mesas.
- rotina: `qui, sex, sab; 21-24; iluminado` (quintas, sextas e sábados, 21 h às 24 h, no Iluminado)
- Fechei o caixa agora. O que sobrou na bolsa é para trocar.
- Você não imagina o que fica debaixo de mesa de bar.
- A esta hora só anda quem escuta. Ou quem perdeu o ônibus.

## Veículos do Véu

Só aparência (GDD, "Veículos do Véu"). Ids são sugestão.

### item.vehicle.bike
- nome: Bicicleta do Véu
- gênero: f
- descrição: Quadro de ferro frio e aros que chiam baixinho. Não te leva mais longe, só mais bonito.

### item.vehicle.skate
- nome: Skate do Véu
- gênero: m
- descrição: Tábua riscada de sigilos, rodas que soltam faísca no asfalto. Anda no seu passo, não no dele.

### item.vehicle.cart
- nome: Carroça do Véu
- gênero: f
- descrição: Madeira velha, lanterna na frente e nada puxando. Aparece quando a rua passa depressa demais.

### Páginas do grimório

- `page.vehicle_light`: Página das duas rodas | Bicicleta e skate do Véu, para aparecer bem quando a rua passa depressa.
- `page.vehicle_cart`: Página da carroça | Uma carroça do Véu que nada puxa, para as ruas que passam por você.

### Falas do mentor (receitas)

- `page_vehicle_light` (bicicleta e skate, nível baixo): Vi você passar depressa. O Véu não gosta de pressa, mas gosta de quem passa bem. Deixei uma página no grimório: nela cabem duas rodas e também quatro, menores. Não levam a lugar nenhum que os seus pés não levem. Então para que servem?
- `page_vehicle_cart` (carroça, nível maior): Há ruas que passam por você, e não o contrário. Para elas existe uma carroça. Nada a puxa, e é melhor não perguntar o quê. A página está no grimório. Ela não rende nada, só te mostra. Quem você quer que te veja passando?

## Ônibus Espectral

Toque no ponto com o Espectral parado ali agora. O código usa as duas primeiras quando tem `{seg}` e as duas últimas quando não tem.

- Ônibus Espectral no ponto. Sai em {seg} s.
- Ele está aqui. Portas abertas por mais {seg} s, e não é para você.
- Ônibus Espectral parado. Alguém desceu e a calçada já esqueceu quem.
- O Espectral encostou. Olhe, mas não dê sinal.
