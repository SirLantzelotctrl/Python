#!/usr/bin/env bash
# Ejecuta las pruebas del juego en el simulador (requiere Lune: https://lune-org.github.io/docs)
# Uso: bash tests/run_tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."
CACHE="tests/.cache"
API="$CACHE/API-Dump.json"
mkdir -p "$CACHE"
if [ ! -f "$API" ]; then
	echo "Descargando API-Dump de Roblox..."
	curl -sSL -o "$API" https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json
fi
echo "== Partida completa (Studio, con DataStore) =="
lune run tests/run.luau "$API" .
echo
echo "== Servidor en vivo sin DataStore =="
lune run tests/run_nostore.luau "$API" .
