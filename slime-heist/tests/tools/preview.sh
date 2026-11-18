#!/usr/bin/env bash
# Genera imágenes de vista previa (docs/*.png) a partir de la geometría real del juego.
# Requiere Lune y Python 3 con numpy + pillow.
set -euo pipefail
cd "$(dirname "$0")/../.."
API="tests/.cache/API-Dump.json"
OUT="$(mktemp -d)"
[ -f "$API" ] || bash tests/run_tests.sh >/dev/null
lune run tests/tools/export_slimes.luau "$API" . "$OUT/slimes.json"
lune run tests/tools/export_scene.luau "$API" . "$OUT/scene.json"
python3 tests/tools/render.py sheet "$OUT/slimes.json" docs/slimes.png
python3 tests/tools/render.py scene "$OUT/scene.json" docs/base.png -55 42 28 -100 2 -52 1280 720
python3 tests/tools/render.py scene "$OUT/scene.json" docs/portal.png -130 22 45 -190 9 -2 960 540
