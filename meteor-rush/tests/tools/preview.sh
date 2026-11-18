#!/usr/bin/env bash
# Genera las imágenes de docs/ a partir de la geometría real del juego.
# Requiere Lune y Python 3 con numpy + pillow.
set -euo pipefail
cd "$(dirname "$0")/../.."
API="tests/.cache/API-Dump.json"
OUT="$(mktemp -d)"
if [ ! -f "$API" ]; then
	mkdir -p tests/.cache
	curl -sSL -o "$API" https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json
fi
for what in critters eggs meteors; do
	lune run tests/tools/export_models.luau "$API" . "$OUT/$what.json" "$what"
	python3 tests/tools/render.py sheet "$OUT/$what.json" "docs/$what.png"
done
lune run tests/tools/export_scene.luau "$API" . "$OUT/scene.json"
python3 tests/tools/render.py scene "$OUT/scene.json" docs/scene.png -70 42 78 18 0 -6 1280 720
python3 tests/tools/render.py scene "$OUT/scene.json" docs/mining.png 52 13 2 28 3 -21 1280 720
