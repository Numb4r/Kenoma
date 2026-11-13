#!/usr/bin/env python3
"""Monta docs/pages/regions.json a partir dos pacotes em pipeline/out/regions, assina cada arquivo e o próprio JSON com a
chave do feed (Ed25519) e grava os .sig. NÃO publica nada. Uso: scripts/assinar_regioes.py sao_paulo 5 [--out pasta]

Os nomes dos arquivos saem da época em app/assets/data/epochs.json (region_packs, visual_packs, walkable.exclude_packs e,
da época 12 em diante, traffic_packs), então uma época pode reaproveitar arquivos de épocas anteriores: cada arquivo aponta
para o release da época do nome dele (regions-e5, regions-e12...), onde ele já está ou vai entrar. Com --out, o JSON e o
.sig vão para outra pasta (um rascunho), e docs/pages fica como está."""
import hashlib
import re
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KEY = Path.home() / ".kenoma-signing/publicacao_ed25519.pem"
OUT = ROOT / "pipeline/out/regions"
PAGES = ROOT / "docs/pages"
RELEASE = "https://github.com/Numb4r/Kenoma/releases/download/regions-e{epoch}/{file}"


def sign(path: Path) -> str:
    with tempfile.TemporaryDirectory() as tmp:
        sig = Path(tmp) / "sig.bin"
        subprocess.run(["openssl", "pkeyutl", "-sign", "-rawin", "-inkey", str(KEY), "-in", str(path), "-out", str(sig)], check=True)
        return sig.read_bytes().hex()


def _ref(data: Path) -> dict:
    d = data.read_bytes()
    return {"sha256": hashlib.sha256(d).hexdigest(), "bytes": len(d), "sig": sign(data)}


def _url(name: str) -> str:
    return RELEASE.format(epoch=re.search(r"_e(\d+)", name).group(1), file=name)


def main() -> None:
    args = sys.argv[1:]
    out_dir = PAGES
    if "--out" in args:
        i = args.index("--out")
        out_dir = Path(args[i + 1])
        del args[i:i + 2]
    region, epoch = args[0], int(args[1])
    info = json.loads((ROOT / "pipeline/regions.json").read_text())[region]
    ep = next(e for e in json.loads((ROOT / "app/assets/data/epochs.json").read_text())["epochs"] if e["id"] == epoch)
    pinned = {
        "logic": ep["region_packs"].get(region),
        "visual": (ep.get("visual_packs") or {}).get(region),
        "nowalk": ((ep.get("walkable") or {}).get("exclude_packs") or {}).get(region),
    }
    files = {}
    for kind, ref in pinned.items():
        if ref is None:
            continue
        files[kind] = {"file": ref["file"], "url": _url(ref["file"]), **_ref(OUT / ref["file"])}
        if files[kind]["sha256"] != ref["sha256"]:
            sys.exit(f"{ref['file']}: SHA-256 diferente do da época {epoch}")
    # Fora de files (a 0.16 recusaria a região inteira se um arquivo de files não estivesse na época): o de rota e, da
    # época 12 em diante, o de pontos do OSM, que o app só aceita se a época vigente listar o mesmo arquivo e SHA-256.
    route_files = {}
    access = sorted(OUT.glob(f"{region}_e*_noaccess.bin"))
    if access:
        route_files["access"] = {"file": access[-1].name, "url": _url(access[-1].name), **_ref(access[-1])}
    traffic = (ep.get("traffic_packs") or {}).get(region)
    if traffic:
        route_files["traffic"] = {"file": traffic["file"], "url": _url(traffic["file"]), **_ref(OUT / traffic["file"])}
        if route_files["traffic"]["sha256"] != traffic["sha256"]:
            sys.exit(f"{traffic['file']}: SHA-256 diferente do da época {epoch}")
    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / "regions.json"
    entry = {"id": region, "name": info["name"], "bbox": info["bbox"], "epoch": epoch, "files": files}
    if route_files:
        entry["route_files"] = route_files
    doc = {"format": 1, "regions": [entry]}
    target.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
    (out_dir / "regions.json.sig").write_text(sign(target))
    total = sum(f["bytes"] for f in files.values())
    print(f"{target} e .sig assinados; {total} bytes em {len(files)} arquivos, rota: {', '.join(route_files) or 'nenhum'}")
    print("Nada foi publicado. Comando em docs/assinatura.md, seção Regiões.")


if __name__ == "__main__":
    main()
