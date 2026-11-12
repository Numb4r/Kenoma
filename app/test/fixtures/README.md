# Fixtures de teste

- `campinas_e0_preview.png`: o preview do M1 (uma cor por bioma, 2331 x 2404 pixels, um pixel por célula z21)
  gerado na mesma execução do pipeline que gerou `app/assets/regions/campinas_e0.bin`. O `pipeline/out/` não é
  versionado, então esta cópia é a referência para `test/data/region_preview_test.dart`. Só se troca junto
  com o `.bin`, numa época nova.
- `save_v5_0150.json`: save do schema 5 gravado pelo código real da 0.15.0 (commit 6f352cc, build 0.15.0+23). O
  `app/` desse commit foi extraído com `git archive 6f352cc app shared` numa pasta temporária, e lá um teste
  descartável abriu `save_v4_0140.json` num `KsvSaveStore`, escolheu o Xamã (teste com nota 72), revelou a névoa num
  passeio real e num pedaço do simulador (conjunto `debug`), capturou um Eco com variante, ganhou Ectoplasma, desligou
  o tráfego e leu de volta o KSV1 gravado em disco. É a base de `test/save/migration_v6_test.dart` (névoa →
  `celulas_visitadas`).
- `save_v6_0191.json`: save do schema 6 gravado pelo código real da 0.19.1 (commit b63dc4a, build 0.19.1+31), do mesmo
  jeito: `git archive b63dc4a app shared` numa pasta temporária, e lá um teste descartável abriu `save_v5_0150.json`
  numa `GameSession`, viu e capturou Ecos (comum, variante Urbana e Brilhante), viu um Espírito, pôs Fagulhas de Fogo e
  de Água na Bolsa e gravou. É a base de `test/save/migration_v7_test.dart` (o bestiário ganha as contagens da pesquisa
  e as Fagulhas).
