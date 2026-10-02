# Capturas do M4 · mapa estático

Geradas por `app/test/ui/map_shots_test.dart`, que renderiza a tela real do mapa (Flame + painel de debug)
numa tela de 1080 x 2400 com densidade 2,625, igual ao moto g54:

```
cd app && KENOMA_SHOTS_DIR=../docs/m4 flutter test test/ui/map_shots_test.dart
```

- `mapa_<lugar>_16px.png`: a tela na escala da spec (16 px lógicos por célula z21, ~26 x 57 células), com o
  dedo no centro. Aparecem a mira ciano do centro, o contorno violeta da célula z20 e o branco da z21 sob o
  dedo, e o painel de debug. O texto do painel sai em blocos porque o teste usa a fonte genérica do
  `flutter_test`; no aparelho é a Silkscreen.
- `mapa_<lugar>_zoom_minimo_vs_preview.png`: à esquerda o recorte do preview do M1 (um pixel por célula,
  ampliado), à direita o app no zoom mínimo (1 px lógico por célula), cobrindo as mesmas células.

Lugares: `unicamp` (-22,8174, -47,0697) e `centro` (-22,9056, -47,0608).

São renderizações do teste, não capturas do aparelho. A captura do moto g54 só entra quando o celular
estiver conectado.
