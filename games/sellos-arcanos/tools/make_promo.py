"""Genera las imágenes promocionales (portales, redes sociales, tienda) a partir
del arte del paquete. Uso: python3 -I tools/make_promo.py <carpeta_ttf> <salida>

Necesita las fuentes del juego en TTF (ver marketing/README.md para convertirlas).
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "raw", "renders")
TTF = sys.argv[1]
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)

NIGHT = (9, 8, 23)
BRIGHT = (244, 241, 251)
INK = (196, 191, 220)
MUTED = (158, 153, 189)


def font(name, size):
    return ImageFont.truetype(os.path.join(TTF, name), size)


CINZEL = lambda s: font("Cinzel-normal-800-latin.ttf", s)
CINZEL7 = lambda s: font("Cinzel-normal-700-latin.ttf", s)
SANS8 = lambda s: font("AlegreyaSans-normal-800-latin.ttf", s)
SANS7 = lambda s: font("AlegreyaSans-normal-700-latin.ttf", s)
SANS5 = lambda s: font("AlegreyaSans-normal-500-latin.ttf", s)
LORE = lambda s: font("Alegreya-italic-400-latin.ttf", s)

CREATURES = json.load(open(os.path.join(os.path.dirname(__file__), "promo_creatures.json"), encoding="utf-8"))


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def cover(img, w, h, focus=(0.5, 0.5)):
    iw, ih = img.size
    s = max(w / iw, h / ih)
    nw, nh = int(iw * s + 0.5), int(ih * s + 0.5)
    img = img.resize((nw, nh), Image.LANCZOS)
    x = int((nw - w) * focus[0])
    y = int((nh - h) * focus[1])
    return img.crop((x, y, x + w, y + h))


def gradient(w, h, stops, vertical=True):
    """stops: [(pos 0..1, alpha 0..255)] de color NIGHT"""
    g = Image.new("L", (1, 256) if vertical else (256, 1))
    for i in range(256):
        p = i / 255
        a = stops[0][1]
        for (p0, a0), (p1, a1) in zip(stops, stops[1:]):
            if p0 <= p <= p1:
                a = a0 + (a1 - a0) * ((p - p0) / max(1e-6, p1 - p0))
        g.putpixel((0, i) if vertical else (i, 0), int(a))
    g = g.resize((w, h), Image.BICUBIC)
    layer = Image.new("RGBA", (w, h), NIGHT + (0,))
    layer.putalpha(g)
    return layer


def glow_text(base, xy, text, fnt, fill=BRIGHT, glow=(176, 107, 255), radius=18, anchor="mm", spacing=0.06):
    w, h = base.size
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # interletraje manual (Cinzel en mayúsculas luce mejor espaciada)
    if spacing:
        total = sum(d.textlength(ch, font=fnt) for ch in text) + spacing * fnt.size * (len(text) - 1)
        x0 = xy[0] - total / 2 if anchor[0] == "m" else xy[0]
        x = x0
        for ch in text:
            d.text((x, xy[1]), ch, font=fnt, fill=fill, anchor="l" + anchor[1])
            x += d.textlength(ch, font=fnt) + spacing * fnt.size
    else:
        d.text(xy, text, font=fnt, fill=fill, anchor=anchor)
    g = layer.copy()
    alpha = g.getchannel("A")
    col = Image.new("RGBA", (w, h), glow + (0,))
    col.putalpha(alpha)
    col = col.filter(ImageFilter.GaussianBlur(radius))
    base.alpha_composite(col)
    base.alpha_composite(col)
    base.alpha_composite(layer)


def octagon_button(base, cx, cy, text, fnt, bg=BRIGHT, fg=(18, 15, 38), pad=(56, 26), c=16):
    d = ImageDraw.Draw(base)
    tw = d.textlength(text, font=fnt) + 0.14 * fnt.size * (len(text) - 1)
    w = tw + pad[0] * 2
    h = fnt.size + pad[1] * 2
    x0, y0 = cx - w / 2, cy - h / 2
    x1, y1 = cx + w / 2, cy + h / 2
    d.polygon([(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)], fill=bg)
    x = cx - tw / 2
    for ch in text:
        d.text((x, cy), ch, font=fnt, fill=fg, anchor="lm")
        x += d.textlength(ch, font=fnt) + 0.14 * fnt.size


TEXT = {
    "es": {"title": "SELLOS ARCANOS", "tag": "INVOCA · SELLA · DOMINA", "cta": "JUEGA GRATIS", "sub": "En tu navegador · PC y móvil",
           "hook": "Traza la runa. Sella a la bestia.", "count": "12 PRIMORDIALES · 36 FORMAS", "best": "BESTIARIO"},
    "en": {"title": "ARCANE SEALS", "tag": "SUMMON · SEAL · RULE", "cta": "PLAY FREE", "sub": "In your browser · PC & mobile",
           "hook": "Trace the rune. Seal the beast.", "count": "12 PRIMORDIALS · 36 FORMS", "best": "BESTIARY"},
}


def key_visual(lang, w, h, scene="arte_clave", focus=(0.5, 0.45), cta=True, sub=True):
    t = TEXT[lang]
    bg = cover(Image.open(os.path.join(RAW, "escenas", scene + ".png")).convert("RGBA"), w, h, focus)
    portrait = h > w
    bg.alpha_composite(gradient(w, h, [(0, 235), (0.26, 120), (0.42, 0), (0.7, 0), (1, 245)]))
    s = min(w, h)
    title_size = int(s * (0.12 if portrait else 0.1))
    ty = int(h * (0.12 if portrait else 0.16))
    glow_text(bg, (w / 2, ty), t["title"], CINZEL(title_size), radius=max(8, title_size // 4))
    glow_text(bg, (w / 2, ty + title_size * 0.95), t["tag"], SANS7(max(14, int(title_size * 0.24))), fill=(214, 207, 240), glow=(9, 8, 23), radius=6, spacing=0.4)
    if cta:
        octagon_button(bg, w / 2, int(h * (0.86 if portrait else 0.84)), t["cta"], CINZEL7(max(16, int(s * 0.045))), c=max(8, s // 70))
    if sub:
        d = ImageDraw.Draw(bg)
        d.text((w / 2, int(h * (0.93 if portrait else 0.94))), t["sub"], font=SANS5(max(12, int(s * 0.028))), fill=MUTED, anchor="mm")
    return bg.convert("RGB")


def creature_card(c, lang, w=1080, h=1350):
    color = hexrgb(c["color"])
    img = Image.new("RGBA", (w, h), NIGHT + (255,))
    art = Image.open(os.path.join(RAW, "criaturas", c["file"] + ".png")).convert("RGBA").resize((w, w), Image.LANCZOS)
    img.alpha_composite(art, (0, 60))
    img.alpha_composite(gradient(w, h, [(0, 255), (0.07, 0), (0.55, 0), (0.78, 255), (1, 255)]))
    d = ImageDraw.Draw(img)
    d.text((64, 70), (TEXT[lang]["best"]), font=SANS7(26), fill=MUTED, anchor="lm")
    d.line([(64 + d.textlength(TEXT[lang]["best"], font=SANS7(26)) + 18, 70), (64 + d.textlength(TEXT[lang]["best"], font=SANS7(26)) + 62, 70)], fill=(74, 70, 102), width=2)
    d.text((64 + d.textlength(TEXT[lang]["best"], font=SANS7(26)) + 80, 70), "Nº " + c["num"], font=CINZEL7(28), fill=(220, 215, 240), anchor="lm")
    el = c["el"][lang].upper()
    f = SANS7(24)
    pw = d.textlength(el, font=f) + 0.3 * 24 * len(el) + 50
    d.rounded_rectangle([w - 64 - pw, 44, w - 64, 96], radius=26, outline=color, width=2)
    x = w - 64 - pw + 25
    for ch in el:
        d.text((x, 70), ch, font=f, fill=color, anchor="lm")
        x += d.textlength(ch, font=f) + 0.3 * 24
    sub = c["sub"][lang].upper()
    d.text((64, h - 360), sub, font=SANS7(26), fill=color, anchor="lm")
    name_font = CINZEL7(92 if len(c["name"][lang]) < 17 else 78)
    d.text((64, h - 270), c["name"][lang], font=name_font, fill=BRIGHT, anchor="lm")
    # lore con salto de línea
    words = c["lore"][lang].split()
    lines, cur = [], ""
    lf = LORE(36)
    for wd in words:
        test = (cur + " " + wd).strip()
        if d.textlength(test, font=lf) > w - 128:
            lines.append(cur)
            cur = wd
        else:
            cur = test
    lines.append(cur)
    for i, ln in enumerate(lines[:3]):
        d.text((64, h - 185 + i * 50), ln, font=lf, fill=INK, anchor="lm")
    d.text((w - 64, h - 40), TEXT[lang]["title"].title() if lang == "en" else "Sellos Arcanos", font=CINZEL7(26), fill=MUTED, anchor="rm")
    return img.convert("RGB")


def main():
    sizes = {
        # portales
        "portal_cover_1920x1080": (1920, 1080, True),
        "portal_landscape_1280x720": (1280, 720, True),
        "portal_square_800x800": (800, 800, True),
        "portal_portrait_800x1200": (800, 1200, True),
        "gamedistribution_512x384": (512, 384, False),
        "gamedistribution_512x512": (512, 512, False),
        "itch_cover_630x500": (630, 500, True),
        # redes
        "youtube_thumb_1280x720": (1280, 720, True),
        "instagram_post_1080x1080": (1080, 1080, True),
        "story_tiktok_1080x1920": (1080, 1920, True),
        "x_header_1500x500": (1500, 500, False),
        "facebook_ad_1200x628": (1200, 628, True),
    }
    for lang in ("es", "en"):
        folder = os.path.join(OUT, lang)
        os.makedirs(folder, exist_ok=True)
        for name, (w, h, cta) in sizes.items():
            scene = "combate" if "story" in name else "arte_clave"
            img = key_visual(lang, w, h, scene=scene, cta=cta, sub=cta and min(w, h) >= 500)
            img.save(os.path.join(folder, name + ".jpg"), quality=88)
        cards = os.path.join(folder, "bestiario")
        os.makedirs(cards, exist_ok=True)
        for c in CREATURES:
            creature_card(c, lang).save(os.path.join(cards, f"{c['num']}_{c['file'].lower()}.jpg"), quality=88)
    # ícono sin texto (las tiendas y portales piden el ícono limpio)
    Image.open(os.path.join(RAW, "escenas", "icono.png")).convert("RGB").resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "icon_512.png"))
    print("ok", OUT)


if __name__ == "__main__":
    main()
