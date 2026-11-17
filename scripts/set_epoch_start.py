#!/usr/bin/env python3
"""Escreve a data real de uma época em app/assets/data/epochs.json, na hora de publicar (0.23.1): época não publicada fica
com início em 2099-01-01. O início é daqui a 7 dias (ou a data dada, que tem de estar a 7 dias ou mais), arredondado para a
PRÓXIMA janela de 20 minutos (1200 s), e o fim 90 dias depois. A trava de release (`test/release_guard_test.dart`) continua
valendo. Uso: scripts/set_epoch_start.py <id_da_época> [AAAA-MM-DDTHH:MM:SSZ]"""
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

path = Path(__file__).resolve().parent.parent / "app/assets/data/epochs.json"
eid = int(sys.argv[1])
data = json.loads(path.read_text())
epoch = next(e for e in data["epochs"] if e["id"] == eid)
MIN_AHEAD = 7 * 86400
wanted = int(datetime.strptime(sys.argv[2], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc).timestamp()) if len(sys.argv) > 2 else int(time.time()) + MIN_AHEAD
if wanted < time.time() + MIN_AHEAD:
    sys.exit("o início tem de estar a pelo menos 7 dias de agora")
start = -(-wanted // 1200) * 1200
fmt = lambda t: datetime.fromtimestamp(t, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
epoch["starts_utc"] = fmt(start)
epoch["valid_until_utc"] = fmt(start + 90 * 86400)
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
print(f"época {eid}: {epoch['starts_utc']} até {epoch['valid_until_utc']}")
