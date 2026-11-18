# Textos do mapa (0.24.2: o mapa responde ao toque)

Para revisão do dono. A thread principal copia daqui para `app/assets/data/`. Lacunas entre chaves (`{min}`, `{clima}`) são preenchidas pelo código. Tom: o da cidade vista pelo Véu, curto, sem exclamação.

## Materiais

### item.glass_shard
- nome: Caco de vidro
- gênero: m
- descrição: Resto de garrafa na calçada dos bares. Corta menos do que parece.
- onde: Urbano e Iluminado, perto de bares e comércio

### item.feather
- nome: Pena
- gênero: f
- descrição: De pombo ou de maritaca. Leve o bastante para o Véu carregar.

### item.dry_leaf
- nome: Folha seca
- gênero: f
- descrição: Caiu no outono e ainda estala. Guarda o som da árvore que a soltou.

### item.ipe_flower
- nome: Flor de ipê
- gênero: f
- descrição: Só cai de ipê florido, poucas semanas por ano. No chão dura um dia.

A Garrafa de vidro (`item.vessel.glass`) passa a "Cacos de vidro refundidos, bons para guardar o que cai do céu." (já em `docs/textos-crafting.md`).

## Ponto de ônibus

- título do painel: Ponto de ônibus
- próximo, de dia: Ônibus Espectral passa em {min} min.
- próximo, à noite: Ônibus Espectral passa em {min} min. A esta hora, pode vir uma linha que não existe.
- passando agora (`{min}` = 0): Ônibus Espectral no ponto. Ele não espera.
- linhas do OSM: Linhas daqui: {linhas}
- sem linhas no OSM: Ninguém anotou as linhas deste ponto. As do Véu passam mesmo assim.

## Manchetes do Véu

Banca de jornal: uma manchete por banca por dia, igual para amigos. Título do painel: **Manchetes do Véu**. Rodapé: `Edição de hoje. Amanhã é outra.`

Formato: `- GRUPO | manchete | corpo`. `{clima}` é o nome do clima de hoje ali, como está em `clima.json` (maiúscula inicial, por isso vem sempre depois de dois-pontos ou em começo de frase). `{evento}` é o nome do evento; `{dias}` é o número de dias até ele (o código escolhe os modelos "hoje" quando `{dias}` é 0; estão marcados). `{familia}` é o nome próprio da família.

- CLIMA | Previsão para hoje: {clima} | Quem sai sem olhar o céu volta com a bolsa vazia.
- CLIMA | {clima} muda o humor das ruas | Moradores relatam Ecos que ontem não estavam ali.
- CLIMA | Céu do dia: {clima} | O Véu acompanha. O que aparece hoje pode não voltar amanhã.
- CLIMA | {clima}: garrafas no cinto, recomendam | Há quem guarde o tempo. Há quem só se molhe.
- CLIMA | Boletim do Véu confirma: {clima} | Coletores plantados ontem agradecem.
- CLIMA | {clima} deixa marcas no chão do bairro | Olhe para baixo antes de olhar para o aparelho.
- CLIMA | Dia de {clima}: sinal oscila | Conjuradores pedem calma no dial.
- CLIMA | {clima} outra vez, e ninguém reclamou | A cidade muda de cara. Os Ecos mudam junto.
- EVENTO | {evento} chega em {dias:dia} | Quem tem selo guardado, que confira a bolsa.
- EVENTO | {dias?Falta|Faltam} {dias:dia} para {evento} | A banca avisa cedo. Depois não diga que não soube.
- EVENTO | Contagem: {dias:dia} até {evento} | Dizem que o Véu afina antes. Ninguém mediu.
- EVENTO | {evento} em {dias:dia}, prepare a Bancada | Receitas de calendário não esperam o atrasado.
- EVENTO | Bairro se prepara: {evento} em {dias:dia} | Combine a rota com quem anda na sua frequência.
- EVENTO | Hoje: {evento} | Só hoje. Amanhã vira história de banca. (só com `{dias}` = 0)
- EVENTO | {evento} começou | O que nasce hoje não nasce em outro dia. (só com `{dias}` = 0)
- EVENTO | É dia de {evento} na cidade | Saia. O resto a rua explica. (só com `{dias}` = 0)
- FAMÍLIA | {familia} visto de novo no bairro | Terceiro relato da semana. Coincidência não é.
- FAMÍLIA | Moradores ouvem {familia} à noite | "Achei que era a geladeira", diz vizinha.
- FAMÍLIA | {familia} anda aparecendo por aqui | Quem procura, leve o selo certo.
- FAMÍLIA | Mais um {familia} perto da praça | A banca não confirma nem desmente. Só vende jornal.
- FAMÍLIA | Rastro de {familia} nas ruas do bairro | Sinal fresco. Dial na mão.
- FAMÍLIA | {familia}: o bairro tem um novo vizinho | Não paga aluguel e não dá bom-dia.
- FAMÍLIA | Procura-se: {familia} | Visto por último a poucas quadras desta banca.
- FAMÍLIA | {familia} some quando alguém chega perto | Especialistas recomendam chegar devagar.

## Placa de rua

- rótulo do painel: Você está em
- frase de apoio: Diga este nome a um amigo. A rua é a mesma para os dois.

## Avisos curtos

| Id sugerido | Quando | Texto |
| --- | --- | --- |
| `map.feather_drop` | a ave voou e caiu uma pena | Caiu uma pena. |
| `map.leaf_drop` | a copa soltou uma folha seca | Caiu uma folha seca. |
| `map.ipe_drop` | o ipê florido soltou uma flor | Caiu uma flor de ipê. |
| `map.limit_feather` | limite do dia, penas | As aves já deram o que tinham hoje. |
| `map.limit_tree` | limite do dia, folhas e flores | As árvores já deram o que tinham hoje. |
| `map.limit_cat` | limite do dia, gatos | Os gatos já cansaram de você por hoje. |
| `map.limit_puddle` | limite do dia, poças | As poças não respondem mais hoje. |
| `map.limit_lamp` | limite do dia, postes | Os postes não piscam mais para você hoje. |
| `map.cat_follow` | o gato começou a seguir | O gato resolveu ir com você. |
| `map.cat_gift` | o gato largou um item | O gato largou uma coisa no chão. |
| `map.cat_leave` | o gato desistiu (opcional) | O gato achou coisa melhor para fazer. |
| `map.tree_empty` | árvore sem nada hoje | Esta árvore não tem nada para dar hoje. |
| `map.puddle_empty` | poça sem Eco de Água por perto | Só água. Nenhum Eco de Água por perto. |
| `map.lamp_empty` | poste pisca, sem Hum por perto | O poste piscou sozinho. Nenhum Hum por perto. |
