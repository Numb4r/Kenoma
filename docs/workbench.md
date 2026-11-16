# Workbench

Uma página local com tudo do jogo em abas (formas e variantes, habilidades, climas, eventos, Calendário do Véu, biomas,
materiais, veículos, apps do celular e o checklist do celular), o andamento da versão, as capturas, os clipes, os números
medidos e uma caixa de nota em cada item. A skill que monta a página fica só neste repositório
(`.claude/skills/game-workbench/`), sem hospedagem e sem as avaliações por screenshot (a aba Ratings fica escondida).

## Subir

```
python3 workbench/server.py          # http://localhost:8977, só na própria máquina
```

O servidor escuta só em `127.0.0.1`. O acesso de outro aparelho é pelo Tailscale, dentro da tailnet, **nunca `funnel`**:

```
tailscale serve --bg 8977            # https dentro da tailnet; para desfazer: tailscale serve reset
```

Na primeira vez em cada máquina o `tailscale serve` pede root. Rode uma vez `sudo tailscale set --operator=$USER` e depois o
comando acima sem sudo. O HTTPS da tailnet (`tail3e1e61.ts.net`) já está ligado.

| Máquina | Endereço na tailnet |
| --- | --- |
| Notebook (Dell Inspiron 14 5440) | https://yuri-inspiron-14-5440.tail3e1e61.ts.net/ |
| PC | https://yuri-pc.tail3e1e61.ts.net/ |

No PC, o mesmo: `python3 workbench/server.py` e `tailscale serve --bg 8977` na raiz do repositório.

## O que fica fora do git

O repositório é público: `workbench/catalog/` (o `catalog.json` e as imagens), `workbench/clips/`, `workbench/shots/` e
`workbench/notes.json` ficam no `.gitignore`. No git ficam só a página, o servidor, a configuração, `tasks.json`,
`numbers.json` e os scripts de captura.

## Refazer o catálogo

```
cd app && flutter test test_workbench/render_sprites_test.dart   # sprites (Bestiário e mapa) e os textos do jogo
cd .. && python3 workbench/capture/catalogo.py                   # catalog.json a partir dos dados do jogo
```

Os climas são capturas no emulador: suba o mapa no Centro com a Simulação de clima do debug, toque em "1 min por clima" e
logo depois rode `python3 workbench/capture/climas.py $(date +%s)`. Os ids das linhas são os do jogo (`soot.eco@urban`,
`storm`, `0203-pocas-rill`): as notas ficam presas a eles.

## Notas

No começo de cada versão, a thread principal lê `workbench/notes.json`:

- **Nota de visual ou de bug** vai para o topo da fila e é feita. Uma nota num item do Checklist que falhou conta como bug.
- **Nota que muda regra** (spawn, economia, determinismo, feature nova) não é feita: ganha status `design` e a resposta
  "levar ao design", e entra no resumo final para ser levada ao design.
- Nota terminada ganha status `done` e uma resposta curta.

## Andamento

O `tasks.json` é atualizado no começo e no fim de cada seção do prompt (não a cada passo). O "Running now" reconhece o
`flutter run` e o emulador `kenoma_g54`. Os números (`numbers.json`) são só o que foi medido; os do emulador ficam marcados
como emulador e servem só para comparar antes e depois (o orçamento de 4 ms vale medido no moto g54). Desde a 0.22.0 todo
número diz também o tipo de build (debug, profile ou release): só profile e release no moto g54 valem como medida.
