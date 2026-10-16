#!/usr/bin/env python3
"""Fixa o início da época 2 em app/assets/data/epochs.json: agora, arredondado para a PRÓXIMA janela de 20 minutos
(1200 s), e o fim 90 dias depois. Rode uma vez, na hora de gerar o release. Uso: scripts/set_epoch_start.py [id_da_época]"""
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

path = Path(__file__).resolve().parent.parent / "app/assets/data/epochs.json"
eid = int(sys.argv[1]) if len(sys.argv) > 1 else 2
data = json.loads(path.read_text())
epoch = next(e for e in data["epochs"] if e["id"] == eid)
start = -(-int(time.time()) // 1200) * 1200
fmt = lambda t: datetime.fromtimestamp(t, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
epoch["starts_utc"] = fmt(start)
epoch["valid_until_utc"] = fmt(start + 90 * 86400)
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
print(f"época {eid}: {epoch['starts_utc']} até {epoch['valid_until_utc']}")
