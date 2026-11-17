# Kit de publicidad · Sellos Arcanos

| Archivo | Para qué |
|---|---|
| `LANZAMIENTO.md` | Plan paso a paso: dónde publicar, cómo cobrar, calendario de 4 semanas, anuncios pagados y métricas |
| `TEXTOS.md` | Descripciones de tienda (ES/EN), 8 guiones de vídeos cortos, posts de Reddit, correo para creadores, nota de prensa |
| `video/trailer_es.mp4`, `video/trailer_en.mp4` | Tráiler vertical (TikTok, Shorts, Reels) con gameplay real, textos y música |
| `imagenes/es/`, `imagenes/en/` | Portada de portales (1920×1080, 1280×720, 800×800, 800×1200), GameDistribution (512×384, 512×512), itch.io (630×500), miniatura de YouTube, post de Instagram, historia de TikTok, cabecera de X y anuncio de Facebook |
| `imagenes/*/bestiario/` | 12 fichas de criatura (1080×1350) para publicar una al día |
| `imagenes/icon_512.png` | Ícono limpio para portales y tiendas |
| `../releases/sellos-arcanos-v1.0-web.zip` | El juego listo para subir a CrazyGames, Poki, GameDistribution, itch.io o cualquier hosting estático |

Para regenerar las imágenes (por ejemplo, tras cambiar el arte): convierte las fuentes a TTF y ejecuta `tools/make_promo.py`.

```bash
pip install fonttools brotli
```

```bash
python3 -I tools/make_promo.py /ruta/a/ttf marketing/imagenes
```
