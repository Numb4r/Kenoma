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

## Arquivo de rota (0.17.0, fora das épocas)

`build_noaccess.py --region <região>` lê do mesmo extrato da época 0 (MD5 `d4778499e2017add7ee7879dd3b64b3c`, conferido em 2026-11-09) as vias do pacote visual (as mesmas de `highway_class`) com `access`, `foot`, `bicycle`, `vehicle` ou `motor_vehicle` em `no` ou `private`, as escadas e calçadas sem `bicycle=yes|designated|permissive`, e os viadutos (`bridge`). Só a rota do Modo Viagem lê: é individual, não muda o mundo, não entra em época e pode ser regerado sem época nova. O pacote visual continua o mesmo (o SHA dele é mundo desde a época 2). Regras e formato no cabeçalho do script; o fallback tira os mesmos bits das tags da Overpass (`accessMask` em `osm_rules.dart`).

| Arquivo | Linhas | Bytes | SHA-256 |
| --- | --- | --- | --- |
| `app/assets/regions/campinas_e0_noaccess.bin` | 11.975 (a pé 7.676, bicicleta 10.870, motorizado 7.724, viaduto 1.010) | 184.014 | `84b0f5cd59eeddc986cc1f9bb95cbe60cacdb7acd99bfffb27c4c2aa6c25e06a` |
| `out/regions/sao_paulo_e5_noaccess.bin` (`--epoch 5 --out-dir out/regions`, não embarcado) | 54.324 (a pé 10.696, bicicleta 48.581, motorizado 9.321, viaduto 4.525) | 672.482 | `feaecc1c025a0deb77b82598de69c4f5df397dbf251f59f9bf429a45ccd97165` |

No `regions.json` assinado, o de São Paulo entra em `route_files.access` da região (`file`, `url`, `sha256`, `bytes`, `sig`, como os de `files`), **nunca em `files`**: a 0.16 exige que todo arquivo de `files` esteja em `epochs.json` e recusaria a região inteira. A 0.17 baixa o arquivo de rota depois da região (também para quem já tem São Paulo), confere o SHA-256 do catálogo e a assinatura; sem ele, a rota funciona sem os bits de acesso.

