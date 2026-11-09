#!/usr/bin/env python3
"""Monta docs/pages/regions.json a partir dos pacotes em pipeline/out/regions, assina cada arquivo e o próprio JSON com a
chave do feed (Ed25519) e grava os .sig. NÃO publica nada. Uso: scripts/assinar_regioes.py sao_paulo 5"""
import hashlib
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


def main() -> None:
    region, epoch = sys.argv[1], int(sys.argv[2])
    info = json.loads((ROOT / "pipeline/regions.json").read_text())[region]
    files = {}
    for kind, suffix in (("logic", ""), ("visual", "_vis"), ("nowalk", "_nowalk")):
        name = f"{region}_e{epoch}{suffix}.bin"
        data = (OUT / name).read_bytes()
        files[kind] = {
            "file": name,
            "url": RELEASE.format(epoch=epoch, file=name),
            "sha256": hashlib.sha256(data).hexdigest(),
            "bytes": len(data),
            "sig": sign(OUT / name),
        }
    target = PAGES / "regions.json"
    doc = {"format": 1, "regions": [{"id": region, "name": info["name"], "bbox": info["bbox"], "epoch": epoch, "files": files}]}
    target.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
    (PAGES / "regions.json.sig").write_text(sign(target))
    total = sum(f["bytes"] for f in files.values())
    print(f"{target} e .sig assinados; {total} bytes em {len(files)} arquivos")
    print("Nada foi publicado. Comando em docs/assinatura.md, seção Regiões.")


if __name__ == "__main__":
    main()
