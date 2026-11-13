# Pipeline de região

Gera `app/assets/regions/<região>_e<época>.bin` a partir do extrato da Geofabrik e de `shared/biomes.json`. O `build_visual.py` gera, do mesmo extrato, o pacote visual `<região>_e<época>_vis.bin` (ruas, água e verde, só desenho).
Comandos em `CLAUDE.md`.

## Extrato usado na época 0

| Campo | Valor |
| --- | --- |
| Arquivo | `sudeste-latest.osm.pbf` (Geofabrik, Sudeste do Brasil) |
| Data do extrato (`Last-Modified`) | 2026-09-28 22:50 UTC |
| Baixado em | 2026-09-29 |
| Tamanho | 859.555.836 bytes |
| MD5 | `d4778499e2017add7ee7879dd3b64b3c` (confere com o `.md5` publicado pela Geofabrik) |
| SHA-256 do `campinas_e0.bin` | `559f3551cf04ef399eaca600a4397e4a074d1c58b8b744f83e46503fabfa4f30` |
| SHA-256 do `campinas_e0_vis.bin` | `e8491fa298a07beb4703cf4fe03d2694ed07490365efa8183d80963aab0c531b` (versão 2, 3,13 MB, 1.442 tiles z15; mesmo extrato). A versão 1, `d0ba04db14106e0cffb24b8076adf147116f6e1833f0fdc027c8955ed1fa6f27`, está no histórico do git |

O extrato muda todo dia. Regerar com outro extrato dá outro `.bin` e outro SHA-256, e isso muda o mundo:
o pacote novo só entra numa época nova. Com o mesmo extrato (mesmo MD5) e as mesmas regras, o `.bin` sai
byte a byte igual.

## Métricas da época 0

Medidas em células de spawn (z20, moda das 2×2 células z21, empate pela maior prioridade), com o pacote acima.

| Região | Urbano |
| --- | --- |
| Área urbana de Campinas (~254 km², heurística: limite municipal + blocos de ~500 m com ≥12% de ruas residenciais) | 14,5% |
| Núcleo de ±1 km do centro | 49,0% |

O recorte de 6 km do centro tem 29,4% de Urbano: a maior parte dele é bairro, não centro.

## Regra por densidade de POIs: avaliada, fora da época 0

Testamos transformar em Urbano as células Vazio de blocos de ~105 m com pelo menos T POIs comerciais (`shop`, `amenity` sem mobiliário urbano, `office`, `craft`). Com T=2, o núcleo do centro iria de 49,0% para 65,5%, o recorte de 6 km de 29,4% para 37,0% e a área urbana de 14,5% para 16,3%. Ficou de fora porque:

- depende da cobertura de POIs no OSM, que é fina (7.182 POIs na grade, 0,6 por bloco no recorte do centro), e o resultado mudaria a cada extrato;
- o ganho é pequeno fora do núcleo, que já passa sem a regra;
- os blocos de ~105 m deixam bordas quadradas visíveis.

Reavaliar numa época futura se o teste de rua mostrar que o centro parece vazio demais.

## Vias onde não se anda (época 2)

`build_nowalk.py --region campinas` lê do mesmo extrato da época 0 (MD5 acima) as vias `motorway`, `trunk` e os links delas e grava `app/assets/regions/campinas_e2_nowalk.bin` (1.966 vias, 40.913 bytes, SHA-256 `05c64cf5a9c29511bc0e32ec06863d5cd9a4a9de0e0e909d9c0c19a1acdaf625`). A época 2 fixa esse SHA-256: Fagulhas, materiais e Ecos não nascem sobre essas vias.

## São Paulo (época 5)

Mesmo extrato da época 0 (MD5 acima), mesmas regras de bioma. Município inteiro, bbox `[-46.83, -24.01, -46.36, -23.35]`. Gerado com `--epoch 5 --out-dir out/regions` nos três scripts, fora de `app/assets/`: **não entra no APK**, é baixado pelo app (`docs/assinatura.md`, "Regiões baixáveis").

| Arquivo | Bytes | SHA-256 |
| --- | --- | --- |
| `sao_paulo_e5.bin` | 807.677 | `75fc763478409e6b6853ca859165b8b96fc7868b1c99014d71c068657b6cbd47` |
| `sao_paulo_e5_vis.bin` | 11.043.360 | `9204f9ce5c6154878a8ac0c4f6b7e8e6aa7a598662bb2d0b2363d916b03e76b7` |
| `sao_paulo_e5_nowalk.bin` | 139.188 | `74bcb43321a838cfec1c8cd927e65cd64daf8bb0f33d17fcb21654085376f582` |

Total de 11,99 MB. O oráculo do fallback (`app/test/world/fallback/`, fixtures de `export_fixture.py`) compara a grade do Dart com os pacotes de Campinas e de São Paulo.

## Campinas com os biomas Iluminado e Sagrado (época 11)

Mesmo extrato da época 0 (MD5 `d4778499e2017add7ee7879dd3b64b3c`, conferido em 2026-11-12). `shared/biomes.json` ganhou dois biomas com `since_epoch: 11`: Iluminado (id 5: avenidas `primary` e `secondary` com 14 m de cada lado, `landuse` e `building` de comércio, `amenity=marketplace` e as áreas de `shop=mall|supermarket|department_store`; mesma prioridade do Urbano e pintado depois dele) e Sagrado (id 6: `amenity=place_of_worship|grave_yard`, `landuse=cemetery|religious` e os prédios de igreja, capela, catedral e templo; a maior prioridade). O `build_region.py --epoch N` só usa os biomas com `since_epoch` até N: `--epoch 0` continua dando o `campinas_e0.bin` byte a byte (SHA-256 `559f3551…`, conferido numa pasta à parte antes de gerar o novo).

| Arquivo | Bytes | SHA-256 |
| --- | --- | --- |
| `app/assets/regions/campinas_e11.bin` | 439.957 | `52a09041894f7301209cc707ae759fe241e9a09c09f50856ddafa7d996367244` |

Na grade inteira: Vazio 53,6%, Verde 30,6%, Residencial 6,8%, Urbano 5,2% (era 7,1%), Iluminado 2,0%, Água 1,6%, Sagrado 0,1%. O pacote visual não muda (as ruas são as mesmas).

**Fora desta época:** São Paulo segue com `sao_paulo_e5.bin` (sem Iluminado nem Sagrado) até a época 12, que lista o `sao_paulo_e12.bin` (abaixo); os blocos do fallback (Overpass) ignoram os biomas com `since_epoch` e seguem com os cinco de sempre em todas as épocas.

### São Paulo com Iluminado e Sagrado (época 12, gerado em 2026-11-13, não publicado)

Mesmo extrato (MD5 `d4778499e2017add7ee7879dd3b64b3c`, conferido de novo), mesma bbox da época 5. `build_region.py --region sao_paulo --epoch 11 --out-dir out/regions` (os biomas até a época 11; a 12 não traz bioma novo), renomeado para o nome da época em que entra, fora de `app/assets/`. O visual (`sao_paulo_e5_vis.bin`), o de caminhos (`_nowalk`) e o de rota (`_noaccess`) não mudam.

| Arquivo | Bytes | SHA-256 |
| --- | --- | --- |
| `out/regions/sao_paulo_e12.bin` | 862.387 | `b59bff411f332636333408d5cd19c84aa9156b93901d23ab0dc3f6c000155050` |

Na grade inteira (2739 × 4199 em z21): Vazio 45,4%, Verde 35,8%, Urbano 6,1%, Água 5,9%, Residencial 3,8%, Iluminado 2,7%, Sagrado 0,3%.

A época 12 (`app/assets/data/epochs.json`) lista este arquivo em `region_packs.sao_paulo`. O rascunho do catálogo assinado está em `out/regions/rascunho-e12/` (`scripts/assinar_regioes.py sao_paulo 12 --out ...`); a publicação está em `docs/assinatura.md`, "Época 12".

## Arquivo de rota (0.17.0, fora das épocas)

`build_noaccess.py --region <região>` lê do mesmo extrato da época 0 (MD5 `d4778499e2017add7ee7879dd3b64b3c`, conferido em 2026-11-09) as vias do pacote visual (as mesmas de `highway_class`) com `access`, `foot`, `bicycle`, `vehicle` ou `motor_vehicle` em `no` ou `private`, as escadas e calçadas sem `bicycle=yes|designated|permissive`, e os viadutos (`bridge`). Só a rota do Modo Viagem lê: é individual, não muda o mundo, não entra em época e pode ser regerado sem época nova. O pacote visual continua o mesmo (o SHA dele é mundo desde a época 2). Regras e formato no cabeçalho do script; o fallback tira os mesmos bits das tags da Overpass (`accessMask` em `osm_rules.dart`).

| Arquivo | Linhas | Bytes | SHA-256 |
| --- | --- | --- | --- |
| `app/assets/regions/campinas_e0_noaccess.bin` | 11.975 (a pé 7.676, bicicleta 10.870, motorizado 7.724, viaduto 1.010) | 184.014 | `84b0f5cd59eeddc986cc1f9bb95cbe60cacdb7acd99bfffb27c4c2aa6c25e06a` |
| `out/regions/sao_paulo_e5_noaccess.bin` (`--epoch 5 --out-dir out/regions`, não embarcado) | 54.324 (a pé 10.696, bicicleta 48.581, motorizado 9.321, viaduto 4.525) | 672.482 | `feaecc1c025a0deb77b82598de69c4f5df397dbf251f59f9bf429a45ccd97165` |

No `regions.json` assinado, o de São Paulo entra em `route_files.access` da região (`file`, `url`, `sha256`, `bytes`, `sig`, como os de `files`), **nunca em `files`**: a 0.16 exige que todo arquivo de `files` esteja em `epochs.json` e recusaria a região inteira. A 0.17 baixa o arquivo de rota depois da região (também para quem já tem São Paulo), confere o SHA-256 do catálogo e a assinatura; sem ele, a rota funciona sem os bits de acesso.

## Pontos do tráfego (0.18.0, fora das épocas)

`build_traffic.py --region <região>` lê do mesmo extrato os nós `highway=traffic_signals|stop|give_way|crossing` e as entradas fora da rua (`amenity=parking|parking_entrance`, `building=garage|garages|parking`, `entrance=garage`; de uma área, o centro). Só a simulação local do tráfego lê: é cenário, difere entre aparelhos, não muda o mundo, não entra em época e pode ser regerado sem época nova. Formato no cabeçalho do script (`TRF1`); leitor em `app/lib/data/traffic_pack.dart`.

| Arquivo | Pontos | Bytes | SHA-256 |
| --- | --- | --- | --- |
| `app/assets/regions/campinas_e0_traffic.bin` (0.19.0, com a vida urbana; regerado na 0.19.1 com os estádios, tipo 10) | 14.967 (semáforo 909, pare 1.137, preferência 77, faixa 4.933, entrada 934, ônibus 1.258, comércio 2.536, bar 1.026, escola 582, praça 1.575) | 56.231 | `c82bfdac97252ad6f9ca2bc05c53b531ff0119cb5872223d09be13e423fb186c` |
| `app/assets/regions/campinas_e12_traffic.bin` (`--epoch 12`, com os becos, tipo 11) | 17.821 (os 14.976 de antes, iguais, e 2.845 becos: 396 `service=alley` e 3.131 `footway`/`path`, entre 31.980 prédios) | 66.823 | `a83629433e75e0764ed85ef2dffb660688f59b897d6dd8aa71df3bacd8085fa5` |
| `out/regions/sao_paulo_e12_traffic.bin` (`--epoch 12 --out-dir out/regions`, não embarcado) | 187.221 (semáforo 9.485, pare 3.163, preferência 336, faixa 55.450, entrada 8.780, ônibus 23.212, comércio 16.604, bar 6.583, escola 3.393, praça 8.991, estádio 40, beco 51.184: 7.331 `service=alley` e 20.375 `footway`/`path`, entre 2.183.297 prédios) | 674.764 | `e9185114b56ce436c2035a250ed29d8fad56e9a0d22fb067e04f317f70d71e55` |

**Da época 12 em diante a época fixa o arquivo de pontos** (`traffic_packs`): não é mundo (só a simulação local e a camada pessoal de cada jogador leem), mas os becos da Shade entram por ele, e a época diz qual vale. O de Campinas vai no APK; o de São Paulo entra em `route_files.traffic` do `regions.json` assinado e o app só o aceita se a época vigente listar o mesmo nome e SHA-256. Antes da época 12 vale o `campinas_e0_traffic.bin`. Os tipos 0 a 10 do arquivo da época 12 saem iguais aos do da época 0 (um teste compara), e o app antigo ignora o tipo 11.

São Paulo e os blocos do fallback ainda não têm o arquivo: onde não há nenhum ponto em volta, a simulação põe semáforo nos cruzamentos de avenidas e faz a rua menor ceder a vez. Para São Paulo, o arquivo entraria em `route_files` do `regions.json` assinado, como o de rota.


## Relevo (0.19.0, época 9: é mundo)

`build_relief.py --region <região> --epoch <época>` baixa os tiles `.hgt` do SRTMGL1 (1 segundo de arco, uns 30 m) do espelho público `elevation-tiles-prod` (skadi) para `cache/srtm/`, amostra a altura no centro de cada célula z20 da região, preenche os vazios, passa um filtro gaussiano (sigma de 1,2 amostra) e grava em decímetros (`REL1`, formato no cabeçalho do script). **O SHA-256 entra em `relief_packs` da época: o arquivo nunca é regerado por cima** (o script recusa se ele já existe).

| Arquivo | Amostras | Alturas | Bytes | SHA-256 |
| --- | --- | --- | --- | --- |
| `app/assets/regions/campinas_e9_relief.bin` | 1169 x 1206 (z20) | 527,8 a 998,6 m | 1.373.573 | `1bb9c5acd6f6e09f49af449b7bd7f026cc30d237fa167bf4ac209278481e7d86` |

São Paulo ainda não tem relevo: precisaria do arquivo gerado, listado numa época e publicado no feed assinado.

| `out/regions/sao_paulo_e10_relief.bin` (`--epoch 10 --out-dir out/regions`, não embarcado, época 10) | 1373 x 2103 (z20) | -11,3 a 1214,6 m | 2.989.059 | `1c050f97ce36cdc2d27bdab33a31d9fadfaeb8fd7e07ee91a618b0f8c7bd33b9` |

No `regions.json` assinado, o relevo de São Paulo entra em `files.relief` da região. O app (0.19.1 em diante) o trata como opcional: sem o arquivo no disco a região abre com o terreno plano.

## Ciclovias (0.19.1, fora das épocas)

`build_cycle.py --region <região>` lê do mesmo extrato as ciclovias (`highway=cycleway`) e as vias do pacote visual com ciclofaixa (`cycleway`, `cycleway:left`, `cycleway:right`, `cycleway:both`). **Não entra no pacote visual**, cujo SHA é mundo: é um arquivo ao lado, só para os ciclistas da simulação local. Formato `CYC1` no cabeçalho do script; leitor em `app/lib/data/cycle_pack.dart`.

| Arquivo | Linhas | Bytes | SHA-256 |
| --- | --- | --- | --- |
| `app/assets/regions/campinas_e0_cycle.bin` | 665 (ciclovia 339, 134,9 km; ciclofaixa 326, 161,6 km) | 17.169 | `a9fb9657752b0eec699f47b6739b1fea16e35d1205a151bbd4c352cc63a4ccc2` |
