"""Raytracer mínimo para previsualizar la geometría generada por el juego.

Uso:
  python3 render.py sheet  <slimes.json> <salida.png>
  python3 render.py scene  <scene.json>  <salida.png> [camx camy camz tx ty tz]

Soporta elipsoides (SpecialMesh esfera / Ball), bloques y cilindros (eje X, como en Roblox).
"""
import json
import math
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

LIGHT = np.array([-0.45, 0.85, -0.35])
LIGHT /= np.linalg.norm(LIGHT)


def intersect(part, O, D):
    """Devuelve (t, normal_mundo) para los rayos O, D (arrays Nx3)."""
    c = part["cf"]
    pos = np.array(c[0:3])
    R = np.array(c[3:12]).reshape(3, 3)
    ol = (O - pos) @ R
    dl = D @ R
    half = np.array(part["size"]) / 2
    N = D.shape[0]
    kind = part["kind"]
    with np.errstate(divide="ignore", invalid="ignore", over="ignore"):
        if kind == "ellipsoid":
            os_ = ol / half
            ds = dl / half
            a = (ds * ds).sum(1)
            b = 2 * (os_ * ds).sum(1)
            cc = (os_ * os_).sum(1) - 1
            disc = b * b - 4 * a * cc
            ok = disc >= 0
            sq = np.sqrt(np.where(ok, disc, 0))
            t = (-b - sq) / (2 * a)
            t = np.where(ok & (t > 1e-4), t, np.inf)
            hit = ol + np.where(np.isfinite(t), t, 0)[:, None] * dl
            nl = hit / (half ** 2)
        elif kind == "block":
            inv = 1.0 / dl
            t0 = (-half - ol) * inv
            t1 = (half - ol) * inv
            tmin = np.nan_to_num(np.minimum(t0, t1), nan=-np.inf)
            tmax = np.nan_to_num(np.maximum(t0, t1), nan=np.inf)
            tn = tmin.max(1)
            tf = tmax.min(1)
            ok = (tn <= tf) & (tn > 1e-4)
            t = np.where(ok, tn, np.inf)
            axis = tmin.argmax(1)
            nl = np.zeros((N, 3))
            nl[np.arange(N), axis] = -np.sign(dl[np.arange(N), axis])
        else:
            h = half[0]
            r = min(half[1], half[2])
            a = dl[:, 1] ** 2 + dl[:, 2] ** 2
            b = 2 * (ol[:, 1] * dl[:, 1] + ol[:, 2] * dl[:, 2])
            cc = ol[:, 1] ** 2 + ol[:, 2] ** 2 - r * r
            disc = b * b - 4 * a * cc
            ok = (disc >= 0) & (a > 1e-12)
            ts = (-b - np.sqrt(np.where(ok, disc, 0))) / (2 * a)
            xh = ol[:, 0] + ts * dl[:, 0]
            tside = np.where(ok & (ts > 1e-4) & (np.abs(xh) <= h), ts, np.inf)

            def cap(sign):
                tc = (sign * h - ol[:, 0]) / dl[:, 0]
                pt = ol + np.nan_to_num(tc)[:, None] * dl
                good = (tc > 1e-4) & (pt[:, 1] ** 2 + pt[:, 2] ** 2 <= r * r)
                return np.where(good, tc, np.inf)

            tcap = np.minimum(cap(1), cap(-1))
            t = np.minimum(tside, tcap)
            hit = ol + np.where(np.isfinite(t), t, 0)[:, None] * dl
            side_normal = np.stack([np.zeros(N), hit[:, 1], hit[:, 2]], 1)
            cap_normal = np.stack([np.sign(hit[:, 0]), np.zeros(N), np.zeros(N)], 1)
            nl = np.where((tside <= tcap)[:, None], side_normal, cap_normal)
    nw = nl @ R.T
    nw /= np.linalg.norm(nw, axis=1, keepdims=True) + 1e-9
    return t, np.nan_to_num(nw)


def shade(part, normal):
    color = np.array(part["color"])
    if part.get("neon"):
        return np.clip(np.tile(color * 1.15 + 0.08, (normal.shape[0], 1)), 0, 1)
    lam = np.clip(normal @ LIGHT, 0, 1)
    spec = lam ** 30 * 0.25
    s = 0.45 + 0.65 * lam
    return np.clip(color[None, :] * s[:, None] + spec[:, None], 0, 1)


def camera(cam, target, W, H, fov=48):
    cam = np.array(cam, float)
    fwd = np.array(target, float) - cam
    fwd /= np.linalg.norm(fwd)
    right = np.cross(fwd, [0, 1, 0])
    right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    half = math.tan(math.radians(fov) / 2)
    return cam, fwd, right, up, half


def render_scene(parts, W, H, cam_pos, target, fov=48, bg_top=(0.55, 0.75, 1.0), bg_bottom=(0.85, 0.92, 1.0), fog=None):
    cam, fwd, right, up, half = camera(cam_pos, target, W, H, fov)
    aspect = W / H
    xs = ((np.arange(W) + 0.5) / W * 2 - 1) * half * aspect
    ys = (1 - (np.arange(H) + 0.5) / H * 2) * half
    X, Y = np.meshgrid(xs, ys)
    dirs = fwd + X[..., None] * right + Y[..., None] * up
    dirs /= np.linalg.norm(dirs, axis=-1, keepdims=True)
    yy = np.linspace(0, 1, H)[:, None, None]
    image = (np.array(bg_top) * (1 - yy) + np.array(bg_bottom) * yy) * np.ones((H, W, 3))
    zbuf = np.full((H, W), np.inf)

    def bbox(part):
        c = np.array(part["cf"][0:3])
        r = np.linalg.norm(part["size"]) / 2
        v = c - cam
        z = v @ fwd
        if z + r < 0.1:
            return None
        if z - r <= 0.5:
            return 0, W, 0, H
        sx = (v @ right) / z / (half * aspect)
        sy = (v @ up) / z / half
        rr = r / (z - r) / half
        x0 = int((sx - rr * 1.1 / aspect + 1) / 2 * W) - 1
        x1 = int((sx + rr * 1.1 / aspect + 1) / 2 * W) + 2
        y0 = int((1 - (sy + rr * 1.1)) / 2 * H) - 1
        y1 = int((1 - (sy - rr * 1.1)) / 2 * H) + 2
        x0, x1 = max(0, x0), min(W, x1)
        y0, y1 = max(0, y0), min(H, y1)
        if x0 >= x1 or y0 >= y1:
            return None
        return x0, x1, y0, y1

    opaque = [p for p in parts if p["transparency"] < 0.15]
    transparent = [p for p in parts if 0.15 <= p["transparency"] < 0.95]
    for p in opaque:
        box = bbox(p)
        if not box:
            continue
        x0, x1, y0, y1 = box
        sub = dirs[y0:y1, x0:x1].reshape(-1, 3)
        O = np.broadcast_to(cam, sub.shape)
        t, n = intersect(p, O, sub)
        t = t.reshape(y1 - y0, x1 - x0)
        closer = t < zbuf[y0:y1, x0:x1]
        if not closer.any():
            continue
        col = shade(p, n).reshape(y1 - y0, x1 - x0, 3)
        zbuf[y0:y1, x0:x1] = np.where(closer, t, zbuf[y0:y1, x0:x1])
        image[y0:y1, x0:x1] = np.where(closer[..., None], col, image[y0:y1, x0:x1])

    # Sombras baratas: rayo hacia la luz contra piezas opacas grandes y cercanas no se hace;
    # en su lugar oscurecemos ligeramente según la profundidad (ambient occlusion falso).
    def dist_key(p):
        return -np.linalg.norm(np.array(p["cf"][0:3]) - cam)

    for p in sorted(transparent, key=dist_key):
        box = bbox(p)
        if not box:
            continue
        x0, x1, y0, y1 = box
        sub = dirs[y0:y1, x0:x1].reshape(-1, 3)
        O = np.broadcast_to(cam, sub.shape)
        t, n = intersect(p, O, sub)
        t = t.reshape(y1 - y0, x1 - x0)
        closer = t < zbuf[y0:y1, x0:x1]
        if not closer.any():
            continue
        alpha = 1 - p["transparency"]
        col = shade(p, n).reshape(y1 - y0, x1 - x0, 3)
        blended = image[y0:y1, x0:x1] * (1 - alpha) + col * alpha
        image[y0:y1, x0:x1] = np.where(closer[..., None], blended, image[y0:y1, x0:x1])

    if fog:
        depth = np.where(np.isfinite(zbuf), zbuf, fog * 3)
        f = np.clip((depth - fog * 0.35) / fog, 0, 0.55)[..., None]
        image = image * (1 - f) + np.array(bg_bottom) * f
    return Image.fromarray((np.clip(image, 0, 1) * 255).astype(np.uint8))


def sheet(models, out_path, tile=230, columns=6):
    rows = math.ceil(len(models) / columns)
    img = Image.new("RGB", (columns * tile, rows * (tile + 26)), (25, 27, 40))
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 15)
    except OSError:
        font = ImageFont.load_default()
    for i, m in enumerate(models):
        body = next((p for p in m["parts"] if p["name"] == "Body"), m["parts"][0])
        S, Hb = body["size"][0], body["size"][1]
        cam = (S * 0.9, Hb * 1.25, -S * 2.6)
        target = (0, Hb * 0.62, 0)
        tile_img = render_scene(m["parts"], tile, tile, cam, target, fov=42, bg_top=(0.16, 0.18, 0.28), bg_bottom=(0.2, 0.22, 0.34))
        x = (i % columns) * tile
        y = (i // columns) * (tile + 26)
        img.paste(tile_img, (x, y))
        label = m["name"] + ("" if m["mutation"] == "Normal" else f" ({m['mutation']})") + " · " + m["rarity"]
        draw.text((x + 6, y + tile + 4), label[:30], fill=(240, 240, 255), font=font)
    img.save(out_path)


if __name__ == "__main__":
    mode, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]
    data = json.load(open(src))
    if mode == "sheet":
        sheet(data, dst)
    else:
        if len(sys.argv) >= 10:
            vals = [float(v) for v in sys.argv[4:10]]
            cam, target = vals[0:3], vals[3:6]
        else:
            cam, target = (-60, 48, 34), (-100, 2, -50)
        W = int(sys.argv[10]) if len(sys.argv) > 10 else 1280
        H = int(sys.argv[11]) if len(sys.argv) > 11 else 720
        render_scene(data, W, H, cam, target, fog=420).save(dst)
    print("saved", dst)
