"""Comprueba el uso de la API de Roblox contra el volcado oficial (API-Dump.json):
clases de Instance.new, servicios, Enum.X.Y, propiedades asignadas y métodos.

Uso: python3 -I tools/check_api.py <API-Dump.json>
"""
import json
import os
import re
import sys

dump = json.load(open(sys.argv[1], encoding="utf-8"))
classes = {c["Name"]: c for c in dump["Classes"]}
enums = {e["Name"]: {i["Name"] for i in e["Items"]} for e in dump["Enums"]}

members_by_class = {}
for name, c in classes.items():
    members_by_class[name] = {m["Name"]: m for m in c["Members"]}


def all_members(cls):
    out = {}
    while cls:
        out.update(members_by_class.get(cls, {}))
        cls = classes[cls].get("Superclass") if cls in classes else None
        if cls == "<<<ROOT>>>":
            break
    return out


all_props = set()
all_methods = set()
for c in dump["Classes"]:
    for m in c["Members"]:
        if m["MemberType"] in ("Property",):
            all_props.add(m["Name"])
        elif m["MemberType"] in ("Function", "YieldFunction", "Event", "Callback"):
            all_methods.add(m["Name"])

# tipos de datos (Vector3, CFrame...) y miembros de módulos propios
DATATYPE_MEMBERS = {
    "Magnitude", "Unit", "X", "Y", "Z", "Position", "LookVector", "RightVector", "UpVector", "R", "G", "B", "Scale", "Offset",
    "Lerp", "Dot", "FilterDescendantsInstances", "FilterType", "Cross", "Inverse", "ToWorldSpace", "ToObjectSpace", "PointToWorldSpace", "NextNumber", "NextInteger",
}

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src")
problems = 0


def report(path, line, msg):
    global problems
    problems += 1
    print(f"{os.path.relpath(path, root)}:{line}: {msg}")


created = {}  # nombre de variable -> clase (heurística por archivo)
for dirpath, _, files in os.walk(root):
    for f in files:
        if not f.endswith(".lua"):
            continue
        path = os.path.join(dirpath, f)
        src = open(path, encoding="utf-8").read()
        lines = src.split("\n")
        for i, ln in enumerate(lines, 1):
            code = ln.split("--")[0]
            for m in re.finditer(r'Instance\.new\("(\w+)"', code):
                if m.group(1) not in classes:
                    report(path, i, f"clase desconocida {m.group(1)}")
            for m in re.finditer(r'(?:UI\.new|neon)\(\s*"(\w+)"', code):
                if m.group(1) not in classes:
                    report(path, i, f"clase desconocida {m.group(1)}")
            for m in re.finditer(r'GetService\("(\w+)"\)', code):
                if m.group(1) not in classes:
                    report(path, i, f"servicio desconocido {m.group(1)}")
            for m in re.finditer(r'Enum\.(\w+)\.(\w+)', code):
                e, item = m.group(1), m.group(2)
                if e not in enums:
                    report(path, i, f"Enum desconocido {e}")
                elif item not in enums[e]:
                    report(path, i, f"Enum.{e}.{item} no existe")
            for m in re.finditer(r'[:](\w+)\(', code):
                name = m.group(1)
                if name[0].isupper() and name not in all_methods and name not in DATATYPE_MEMBERS and name not in ("FireServer", "FireClient", "FireAllClients", "InvokeServer", "Connect", "Once", "Wait", "Disconnect"):
                    report(path, i, f"método desconocido :{name}()")
            # propiedades asignadas: obj.Prop = valor  (Prop en mayúscula)
            for m in re.finditer(r'\b(\w+)\.([A-Z]\w*)\s*=[^=]', code):
                obj, prop = m.group(1), m.group(2)
                if obj in ("Config", "UI", "Fx", "Hud", "State", "Menus", "Core", "World", "Encounters", "Companions", "Progression", "Shop", "DataService", "Factory", "Sealing", "GameData", "Formulas", "S", "Net", "MarketplaceService"):
                    continue
                if prop not in all_props and prop not in DATATYPE_MEMBERS:
                    report(path, i, f"propiedad desconocida .{prop}")
            # propiedades en tablas de constructores { Prop = ... } dentro de UI.new/neon/part
            if re.search(r'(UI\.new|neon|part|World\.part|UI\.panel|UI\.label|UI\.button|UI\.bar|UI\.scroll)\(', code):
                for m in re.finditer(r'[{,]\s*([A-Z]\w*)\s*=', code):
                    prop = m.group(1)
                    if prop not in all_props and prop not in ("Primary", "StrokeColor"):
                        report(path, i, f"propiedad desconocida en constructor {prop}")
print(f"{problems} problemas")
sys.exit(1 if problems else 0)
