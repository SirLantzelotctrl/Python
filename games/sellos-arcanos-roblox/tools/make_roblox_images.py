"""Imágenes para la página del juego en Roblox y su promoción, a partir del
arte del paquete (reutiliza el generador de la versión web).

  icono_512.png                 icono de la experiencia (sin texto, como pide Roblox)
  <idioma>/miniatura_1..5.jpg   miniaturas 1920×1080 para la página del juego
  <idioma>/youtube_1280x720.jpg, tiktok_1080x1920.jpg, cuadrado_1080.jpg

Uso: python3 -I tools/make_roblox_images.py <carpeta_ttf> [salida]
"""
import importlib.util
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB_PROMO = os.path.join(ROOT, "..", "sellos-arcanos", "tools", "make_promo.py")
TTF = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "marketing", "imagenes")

# el generador web lee sus argumentos al cargarse
sys.argv = [WEB_PROMO, TTF, os.path.join(ROOT, "dist", "_tmp")]
spec = importlib.util.spec_from_file_location("make_promo", WEB_PROMO)
P = importlib.util.module_from_spec(spec)
spec.loader.exec_module(P)
from PIL import Image, ImageDraw  # noqa: E402

TEXT = {
    "es": {
        "title": "SELLOS ARCANOS",
        "shots": [
            ("arte_clave", "INVOCA · SELLA · DOMINA", "12 Primordiales · 36 formas · 12 islas"),
            ("combate", "COMBATE EN TIEMPO REAL", "Q · E · R · F  y ventaja de dominio"),
            ("sellado", "TRAZA LA RUNA", "Sella a la bestia antes de que escape"),
            ("miniatura", "COLECCIONA Y EVOLUCIONA", "Cría · Adulta · Primordial"),
            ("carga", "VENCE AL PRIMORDIAL", "Jefes con fases y anclas rúnicas"),
        ],
        "cta": "JUEGA GRATIS",
        "where": "Gratis en Roblox · PC, móvil, consola y tablet",
    },
    "en": {
        "title": "ARCANE SEALS",
        "shots": [
            ("arte_clave", "SUMMON · SEAL · RULE", "12 Primordials · 36 forms · 12 islands"),
            ("combate", "REAL-TIME BATTLES", "Q · E · R · F  and domain advantage"),
            ("sellado", "TRACE THE RUNE", "Seal the beast before it breaks free"),
            ("miniatura", "COLLECT AND EVOLVE", "Hatchling · Adult · Primordial"),
            ("carga", "DEFEAT THE PRIMORDIAL", "Multi-phase bosses and rune anchors"),
        ],
        "cta": "PLAY FREE",
        "where": "Free on Roblox · PC, mobile, console and tablet",
    },
}


def shot(lang, scene, headline, sub, w, h, cta=False, focus=(0.5, 0.45)):
    t = TEXT[lang]
    bg = P.cover(Image.open(os.path.join(P.RAW, "escenas", scene + ".png")).convert("RGBA"), w, h, focus)
    portrait = h > w
    bg.alpha_composite(P.gradient(w, h, [(0, 225), (0.24, 110), (0.4, 0), (0.68, 0), (1, 240)]))
    s = min(w, h)
    title = int(s * (0.11 if portrait else 0.095))
    ty = int(h * (0.11 if portrait else 0.15))
    P.glow_text(bg, (w / 2, ty), t["title"], P.CINZEL(title), radius=max(8, title // 4))
    P.glow_text(bg, (w / 2, ty + title * 1.05), headline, P.SANS8(max(18, int(title * 0.46))), fill=(236, 230, 255), glow=(9, 8, 23), radius=8, spacing=0.16)
    d = ImageDraw.Draw(bg)
    if cta:
        P.octagon_button(bg, w / 2, int(h * (0.85 if portrait else 0.83)), t["cta"], P.CINZEL7(max(16, int(s * 0.045))), c=max(8, s // 70))
        d.text((w / 2, int(h * (0.93 if portrait else 0.935))), t["where"], font=P.SANS5(max(12, int(s * 0.03))), fill=P.MUTED, anchor="mm")
    else:
        d.text((w / 2, int(h * 0.9)), sub, font=P.SANS7(max(14, int(s * 0.042))), fill=P.BRIGHT, anchor="mm")
    return bg.convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    Image.open(os.path.join(P.RAW, "escenas", "icono.png")).convert("RGB").resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "icono_512.png"))
    for lang, t in TEXT.items():
        folder = os.path.join(OUT, lang)
        os.makedirs(folder, exist_ok=True)
        for i, (scene, head, sub) in enumerate(t["shots"], 1):
            shot(lang, scene, head, sub, 1920, 1080).save(os.path.join(folder, f"miniatura_{i}.jpg"), quality=90)
        shot(lang, "arte_clave", t["shots"][0][1], "", 1280, 720, cta=True).save(os.path.join(folder, "youtube_1280x720.jpg"), quality=88)
        shot(lang, "combate", t["shots"][1][1], "", 1080, 1920, cta=True).save(os.path.join(folder, "tiktok_1080x1920.jpg"), quality=88)
        shot(lang, "sellado", t["shots"][2][1], "", 1080, 1080, cta=True).save(os.path.join(folder, "cuadrado_1080.jpg"), quality=88)
    print("ok", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
