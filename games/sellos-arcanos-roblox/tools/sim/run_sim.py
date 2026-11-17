"""Ejecuta la lógica del servidor de Roblox en un entorno simulado y juega una
partida: elegir inicial, viajar, combatir, sellar, vencer al Primordial,
comprar y guardar. Uso: python3 -I tools/sim/run_sim.py"""
import os
import sys
from lupa import LuaRuntime

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().readfile = lambda p: open(os.path.join(ROOT, p), encoding="utf-8").read()
mock_src = open(os.path.join(ROOT, "tools/sim/roblox_mock.lua"), encoding="utf-8").read()
M = lua.execute(mock_src)
client_src = open(os.path.join(ROOT, "tools/sim/client_mock.lua"), encoding="utf-8").read()
lua.execute(client_src, M)
lua.globals().M = M
scenario = open(os.path.join(ROOT, "tools/sim/scenario.lua"), encoding="utf-8").read()
result = lua.execute(scenario)
errors = list(M.errors.values())
print(f"\n{len(errors)} errores de ejecución")
sys.exit(1 if errors else 0)
