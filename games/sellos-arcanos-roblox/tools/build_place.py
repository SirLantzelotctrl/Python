"""Genera el lugar de Roblox (SellosArcanos.rbxlx) a partir de src/ y el
paquete listo para subir (dist/SellosArcanos-Roblox-v1.0.zip).

Estructura que crea (la misma que default.project.json para Rojo):
  ReplicatedStorage/Shared              ModuleScripts (datos, fórmulas, red, textos)
  ServerScriptService/Server            Script «Main» + ModuleScripts del servidor
  StarterPlayer/StarterPlayerScripts/Client   LocalScript «Main» + ModuleScripts
  ServerStorage/CreatureModels          carpeta vacía: aquí van los 12 modelos importados

Uso: python3 -I tools/build_place.py
"""
import os
import uuid
import xml.etree.ElementTree as ET
import zipfile
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
DIST = os.path.join(ROOT, "dist")
WEB = os.path.join(ROOT, "..", "sellos-arcanos")
VERSION = "1.0"


def ref():
    return "RBX" + uuid.uuid4().hex.upper()


def cdata(text):
    # «]]>» no puede aparecer dentro de un bloque CDATA: se parte en dos
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


class Item:
    def __init__(self, cls, name, props=None, source=None):
        self.cls = cls
        self.name = name
        self.props = props or []  # (tipo, nombre, valor)
        self.source = source
        self.children = []

    def add(self, child):
        self.children.append(child)
        return child

    def xml(self, indent=1):
        pad = "\t" * indent
        out = [f'{pad}<Item class="{self.cls}" referent="{ref()}">', f"{pad}\t<Properties>"]
        out.append(f'{pad}\t\t<string name="Name">{escape(self.name)}</string>')
        for kind, name, value in self.props:
            if kind == "bool":
                value = "true" if value else "false"
            out.append(f'{pad}\t\t<{kind} name="{name}">{escape(str(value))}</{kind}>')
        if self.source is not None:
            out.append(f'{pad}\t\t<ProtectedString name="Source">{cdata(self.source)}</ProtectedString>')
        out.append(f"{pad}\t</Properties>")
        for c in self.children:
            out.append(c.xml(indent + 1))
        out.append(f"{pad}</Item>")
        return "\n".join(out)


def scripts_from(folder, parent):
    count = 0
    for f in sorted(os.listdir(folder)):
        if not f.endswith(".lua"):
            continue
        src = open(os.path.join(folder, f), encoding="utf-8").read()
        if f.endswith(".server.lua"):
            cls, name = "Script", f[: -len(".server.lua")]
        elif f.endswith(".client.lua"):
            cls, name = "LocalScript", f[: -len(".client.lua")]
        else:
            cls, name = "ModuleScript", f[: -len(".lua")]
        parent.add(Item(cls, name, source=src))
        count += 1
    return count


def build():
    items = []
    ws = Item("Workspace", "Workspace", [
        ("bool", "StreamingEnabled", True),
        ("int", "StreamingMinRadius", 96),
        ("int", "StreamingTargetRadius", 640),
        ("float", "FallenPartsDestroyHeight", -500),
        ("float", "Gravity", 196.2),
    ])
    items.append(ws)

    rs = Item("ReplicatedStorage", "ReplicatedStorage")
    shared = rs.add(Item("Folder", "Shared"))
    n_shared = scripts_from(os.path.join(SRC, "shared"), shared)
    items.append(rs)

    sss = Item("ServerScriptService", "ServerScriptService")
    server = sss.add(Item("Folder", "Server"))
    n_server = scripts_from(os.path.join(SRC, "server"), server)
    items.append(sss)

    ss = Item("ServerStorage", "ServerStorage")
    ss.add(Item("Folder", "CreatureModels"))
    items.append(ss)

    sp = Item("StarterPlayer", "StarterPlayer", [
        ("float", "CameraMaxZoomDistance", 120),
        ("float", "CameraMinZoomDistance", 8),
    ])
    sps = sp.add(Item("StarterPlayerScripts", "StarterPlayerScripts"))
    client = sps.add(Item("Folder", "Client"))
    n_client = scripts_from(os.path.join(SRC, "client"), client)
    sp.add(Item("StarterCharacterScripts", "StarterCharacterScripts"))
    items.append(sp)

    body = "\n".join(i.xml() for i in items)
    doc = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        "\t<Meta name=\"ExplicitAutoJoints\">true</Meta>\n"
        f"{body}\n</roblox>\n"
    )
    os.makedirs(DIST, exist_ok=True)
    out = os.path.join(DIST, "SellosArcanos.rbxlx")
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(doc)
    return out, n_shared, n_server, n_client


def verify(path):
    """Comprueba que el XML es válido y que cada script conserva su código."""
    tree = ET.parse(path)
    root = tree.getroot()
    found = {}
    for item in root.iter("Item"):
        props = item.find("Properties")
        name = props.find("string[@name='Name']").text
        src = props.find("ProtectedString[@name='Source']")
        if src is not None:
            found[(item.get("class"), name)] = src.text
    expected = 0
    for sub in ("shared", "server", "client"):
        for f in os.listdir(os.path.join(SRC, sub)):
            if f.endswith(".lua"):
                expected += 1
                original = open(os.path.join(SRC, sub, f), encoding="utf-8").read()
                if original not in found.values():
                    raise SystemExit(f"el código de {sub}/{f} no coincide en el .rbxlx")
    if len(found) != expected:
        raise SystemExit(f"se esperaban {expected} scripts y hay {len(found)}")
    classes = sorted({k[0] for k in found})
    return len(found), classes


def package(place):
    """Zip con el lugar, los modelos para importar, la guía y las imágenes."""
    zpath = os.path.join(DIST, f"SellosArcanos-Roblox-v{VERSION}.zip")
    obj_dir = os.path.join(WEB, "raw", "obj")
    tex_dir = os.path.join(WEB, "raw", "texturas")
    img_dir = os.path.join(ROOT, "marketing", "imagenes")
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(place, "SellosArcanos.rbxlx")
        for doc in ("GUIA_PUBLICAR.md", "MARKETING_ROBLOX.md", "README.md", "default.project.json"):
            p = os.path.join(ROOT, doc)
            if os.path.exists(p):
                z.write(p, doc)
        if os.path.isdir(obj_dir):
            for f in sorted(os.listdir(obj_dir)):
                z.write(os.path.join(obj_dir, f), f"modelos/{f}")
        if os.path.isdir(tex_dir):
            for f in sorted(os.listdir(tex_dir)):
                z.write(os.path.join(tex_dir, f), f"texturas/{f}")
        if os.path.isdir(img_dir):
            for dp, _, files in os.walk(img_dir):
                for f in sorted(files):
                    full = os.path.join(dp, f)
                    z.write(full, os.path.join("imagenes", os.path.relpath(full, img_dir)))
        for sub in ("shared", "server", "client"):
            for f in sorted(os.listdir(os.path.join(SRC, sub))):
                z.write(os.path.join(SRC, sub, f), f"src/{sub}/{f}")
    return zpath


if __name__ == "__main__":
    place, a, b, c = build()
    n, classes = verify(place)
    size = os.path.getsize(place) / 1024
    print(f"{os.path.relpath(place, ROOT)}: {n} scripts ({a} compartidos, {b} servidor, {c} cliente) · {size:.0f} KB · {', '.join(classes)}")
    z = package(place)
    print(f"{os.path.relpath(z, ROOT)}: {os.path.getsize(z) / 1024 / 1024:.1f} MB")
