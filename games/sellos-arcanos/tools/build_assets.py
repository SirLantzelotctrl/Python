"""Convierte los recursos de raw/ a formatos ligeros para la web.

- raw/obj/*.obj  -> public/assets/creatures.bin + creatures.json
  Posiciones cuantizadas a Int16 dentro de la caja de cada criatura e índices
  Uint16 por pieza. El sombreado facetado se calcula en el shader (flatShading),
  así que no hacen falta normales.
- raw/renders y raw/texturas -> WebP redimensionados.

Uso: python3 -I tools/build_assets.py   (desde games/sellos-arcanos)
"""
import json
import os
import struct
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "raw")
OUT = os.path.join(ROOT, "public", "assets")

CREATURES = ["Hidra", "Fenix", "Kraken", "Grifo", "Cerbero", "Basilisco",
             "Wyvern", "Golem", "Leviatan", "Aracna", "Ciervo", "Tortuga"]


def parse_obj(path):
    verts = []
    parts = []  # (material, [faces])
    cur = None
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("v "):
                _, x, y, z = line.split()[:4]
                verts.append((float(x), float(y), float(z)))
            elif line.startswith("usemtl"):
                cur = (line.split()[1], [])
                parts.append(cur)
            elif line.startswith("f "):
                idx = [int(tok.split("/")[0]) - 1 for tok in line.split()[1:]]
                for k in range(1, len(idx) - 1):  # triangulate fans
                    cur[1].append((idx[0], idx[k], idx[k + 1]))
    return verts, parts


def build_models():
    blob = bytearray()
    manifest = {}

    def align():
        while len(blob) % 4:
            blob.append(0)

    for name in CREATURES:
        verts, parts = parse_obj(os.path.join(RAW, "obj", name + ".obj"))
        xs, ys, zs = zip(*verts)
        mn = (min(xs), min(ys), min(zs))
        mx = (max(xs), max(ys), max(zs))
        scale = [(mx[i] - mn[i]) / 65535.0 or 1e-6 for i in range(3)]
        entry = {"min": mn, "max": mx, "scale": scale, "parts": []}
        # merge parts that share the same material
        merged = {}
        order = []
        for mat, faces in parts:
            if mat not in merged:
                merged[mat] = []
                order.append(mat)
            merged[mat].extend(faces)
        for mat in order:
            faces = merged[mat]
            remap = {}
            local = []
            idx = []
            for tri in faces:
                for vi in tri:
                    if vi not in remap:
                        remap[vi] = len(local)
                        local.append(verts[vi])
                    idx.append(remap[vi])
            assert len(local) < 65536, (name, mat, len(local))
            align()
            pos_off = len(blob)
            for (x, y, z) in local:
                q = [round((v - mn[i]) / scale[i]) - 32768 for i, v in enumerate((x, y, z))]
                blob.extend(struct.pack("<hhh", *q))
            align()
            idx_off = len(blob)
            blob.extend(struct.pack("<%dH" % len(idx), *idx))
            entry["parts"].append({"mat": mat, "v": len(local), "i": len(idx),
                                   "po": pos_off, "io": idx_off})
        manifest[name.lower()] = entry
        tris = sum(p["i"] for p in entry["parts"]) // 3
        print(f"{name:10s} tris={tris:6d} bbox_min={tuple(round(v,2) for v in mn)} bbox_max={tuple(round(v,2) for v in mx)}")
    with open(os.path.join(OUT, "creatures.bin"), "wb") as fh:
        fh.write(blob)
    with open(os.path.join(OUT, "creatures.json"), "w") as fh:
        json.dump(manifest, fh, separators=(",", ":"))
    print("creatures.bin", len(blob) // 1024, "KB")


def to_webp(src, dst, size=None, quality=82, keep_alpha=False):
    im = Image.open(src)
    if not keep_alpha:
        im = im.convert("RGB")
    if size:
        im.thumbnail(size, Image.LANCZOS)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im.save(dst, "WEBP", quality=quality, method=6)


def build_images():
    r = os.path.join(RAW, "renders")
    for name in CREATURES:
        to_webp(os.path.join(r, "criaturas", name + ".png"),
                os.path.join(OUT, "img", "criaturas", name.lower() + ".webp"), (512, 512), 80)
        to_webp(os.path.join(r, "siluetas", name + ".png"),
                os.path.join(OUT, "img", "siluetas", name.lower() + ".webp"), (256, 256), 85, True)
    for f in os.listdir(os.path.join(r, "tintes")):
        to_webp(os.path.join(r, "tintes", f),
                os.path.join(OUT, "img", "tintes", os.path.splitext(f)[0].lower() + ".webp"), (400, 400), 80)
    for f in os.listdir(os.path.join(r, "escenas")):
        base = os.path.splitext(f)[0]
        to_webp(os.path.join(r, "escenas", f),
                os.path.join(OUT, "img", "escenas", base + ".webp"), (1600, 1600), 78)
    for f in os.listdir(os.path.join(RAW, "texturas")):
        base = os.path.splitext(f)[0]
        size = (512, 512) if base == "halo" else (1024, 1024)
        to_webp(os.path.join(RAW, "texturas", f), os.path.join(OUT, "tex", base + ".webp"), size, 90, True)
    # iconos de la app
    icon = Image.open(os.path.join(r, "escenas", "icono.png")).convert("RGB")
    for s in (512, 192, 180, 32):
        icon.resize((s, s), Image.LANCZOS).save(os.path.join(ROOT, "public", f"icon-{s}.png"), optimize=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    build_models()
    if "--models-only" not in sys.argv:
        build_images()
    print("ok")
