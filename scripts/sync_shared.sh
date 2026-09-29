#!/usr/bin/env bash
# Copia a fonte única de biomas para os assets do app.
set -euo pipefail
cd "$(dirname "$0")/.."
cp shared/biomes.json app/assets/data/biomes.json
