#!/usr/bin/env python3
"""Gera docs/textos-mentor.md a partir de app/assets/data/mentor.json e forum.json.

O JSON é a fonte: o app lê dele. O .md existe para revisão. Depois de mudar um texto no JSON, rode
`python3 scripts/mentor_md.py` e o teste `test/story/story_texts_test.dart` confere que os dois batem.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
mentor = json.loads((ROOT / "app/assets/data/mentor.json").read_text())
forum = json.loads((ROOT / "app/assets/data/forum.json").read_text())

out = []
out.append("# Textos do mentor e do fórum\n")
out.append("Para revisão. **A fonte é o JSON** (`app/assets/data/mentor.json` e `forum.json`): o app lê de lá. Este arquivo é gerado por "
           "`python3 scripts/mentor_md.py`; mude o texto no JSON, rode o script e o teste confere que os dois batem. "
           "Se preferir, edite aqui e me diga o que mudou que eu passo para o JSON.\n")
out.append("## Tom do mentor\n")
out.append("Um dos Que Escutam, o único que ficou em silêncio, falando pelo celular como se fosse um ocultista humano. Parece "
           "benevolente e pronto para ajudar, e nunca deixa de parecer suspeito. Responde perguntas com outras perguntas, faz "
           "pedidos que não fazem sentido na hora e sabe coisas que não deveria saber. Recusa dar um nome (nomes fazem barulho). "
           "Frases curtas, sem pressa, sem exclamação. No celular aparece como **Número desconhecido**.\n")
out.append(f"## Chat: {mentor['contact']['name']}\n")
out.append("O tutorial sai uma mensagem de cada vez, depois de alguns segundos de jogo com o mapa aberto (o tempo é contado desde a "
           "mensagem anterior). Uma mensagem pode esperar um acontecimento do jogo.\n")
out.append("| # | Id | Espera | Só depois de | Texto |\n| --- | --- | --- | --- | --- |")
for i, m in enumerate(mentor["tutorial"], 1):
    req = m.get("requires")
    cond = f"{req['event']} ≥ {req['min']}" if req else "-"
    out.append(f"| {i} | `{m['id']}` | {m['after_s']:g} s | {cond} | {m['text']} |")
out.append("")
out.append("## Falas do Familiar\n")
out.append("O Familiar ainda não fala (GDD): ele se comunica por gestos, ícones e silêncios, então as falas são **gestos entre asteriscos**. Cada uma sai sozinha, uma vez, "
           "quando o acontecimento acontece, e aparece no chat com o nome FAMILIAR.\n")
out.append("| # | Id | Quando | Texto |\n| --- | --- | --- | --- |")
for i, m in enumerate(mentor.get("familiar", []), 1):
    req = m["requires"]
    out.append(f"| {i} | `{m['id']}` | {req['event']} ≥ {req['min']} | {m['text']} |")
out.append("")
out.append("## Falas de desbloqueio do celular\n")
out.append("Quando um app novo do celular se forma (o nível do Conjurador liberou), o Familiar comenta num balão dentro do celular. "
           "Os apps de nível 1 já vêm abertos e não têm fala.\n")
out.append("| App | Texto |\n| --- | --- |")
for k, v in mentor.get("phone_unlock", {}).items():
    out.append(f"| `{k}` | {v} |")
out.append("")
out.append("## Fusão (nível 6)\n")
out.append("O mentor ensina a fusão quando o Conjurador chega ao nível 6 (evento `level_6`): cinco Ecos da mesma família mais Essência do tipo "
           "viram o Espírito da família. O Familiar comenta a primeira fusão. Estas são as falas, também listadas nas tabelas acima.\n")
out.append("| Id | Quando | Texto |\n| --- | --- | --- |")
for m in [*mentor["tutorial"], *mentor.get("familiar", [])]:
    if m["id"].startswith("fusion_"):
        req = m.get("requires")
        out.append(f"| `{m['id']}` | {req['event'] + ' ≥ ' + str(req['min']) if req else 'depois da anterior'} | {m['text']} |")
out.append("")
out.append(f"## Fórum {forum['forum']}: pedidos diários\n")
out.append("Três pedidos por dia, sorteados por `hash(seed, época, data, slot)`. O texto tem `{n}` (a meta), `{tipo}` (Fogo, Planta, "
           "Água ou qualquer tipo) e `{item}` (giz, ervas, água pura). Usuários: " + ", ".join(f"`{u}`" for u in forum["users"]) + ".\n")
for t in forum["templates"]:
    out.append(f"### `{t['id']}` · {t['category']} · {t['user']}")
    out.append(f"Conta o evento `{t['kind']}`, meta de {t['target'][0]} a {t['target'][1]} (cresce com o nível). "
               f"Recompensa: {t['reward']['xp']} XP e " + ", ".join(f"{q}× `{i}`" for i, q in t["reward"]["items"].items()) + ".\n")
    for tx in t["texts"]:
        out.append(f"- {tx}")
    out.append("")
(ROOT / "docs/textos-mentor.md").write_text("\n".join(out))
print("docs/textos-mentor.md")
