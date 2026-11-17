# Fábrica de juegos web

Sellos Arcanos está construido para que el siguiente juego cueste mucho menos. Esta guía explica qué partes se reutilizan tal cual y qué se cambia.

## Qué se reutiliza sin tocar

| Carpeta | Qué hace |
|---|---|
| `src/core/platform.js` | Detecta el portal (CrazyGames, Poki, GameDistribution, itch.io o web propia) y unifica anuncios con premio, anuncios entre partidas, eventos de juego y pagos con Stripe |
| `src/core/save.js` | Guardado local + nube de CrazyGames, recarga de energía por tiempo |
| `src/core/i18n.js` + `strings.js` | Español e inglés (añadir un idioma = una columna más) |
| `src/core/audio.js` | Música y efectos sintetizados: no hace falta ningún archivo de sonido |
| `src/engine/renderer.js` | Three.js con bloom y calidad automática para móviles |
| `src/engine/input.js` | Teclado, joystick táctil, deslizar y mando |
| `src/engine/fx.js` | Partículas, ondas, avisos en el suelo, rayos y números de daño |
| `src/ui/ui.js` + `styles.css` | Marcos, botones, modales, avisos, monedas |
| `api/` | Cobro con Stripe Checkout y verificación |
| `tools/build_assets.py` | Convierte modelos .obj y renders a formatos ligeros |
| `tools/make_promo.py` | Genera todas las imágenes para portales y redes |

## Qué se cambia en cada juego nuevo

1. **Arte** en `raw/` (modelos .obj separados por material + renders). Ejecuta `npm run assets`.
2. **Datos** en `src/data/`: criaturas/personajes, habilidades, niveles/islas y catálogo de la tienda.
3. **Reglas** en `src/game/`: el combate y el minijuego principal (aquí, el sellado).
4. **Pantallas** en `src/ui/`: se copian las de este juego y se cambian textos y orden.
5. **Textos** en `src/core/strings.js` y `marketing/TEXTOS.md`.

## Ideas que reutilizan este mismo motor y los mismos 12 modelos

- **Sellos Arcanos: Defensa** — tower defense: colocas criaturas sobre círculos y las oleadas avanzan por un camino.
- **Arena de Primordiales** — modo «supervivencia» de oleadas infinitas con mejoras entre rondas (género tipo *survivor*, muy fuerte en portales).
- **Duelos de Sellos** — autobattler 3 contra 3 por temporadas.
- **Bestiario: Puzzle** — juego de unir tres con las runas; las criaturas son los premios.

## Proceso de cada lanzamiento (checklist)

- [ ] Documento de diseño de una página (concepto, bucle, monetización justa).
- [ ] Arte convertido (`npm run assets`) y peso inicial < 20 MB.
- [ ] Partida completa probada con el bot (`tests/` en el bloc de notas de la sesión) en escritorio y móvil.
- [ ] `npm run build` y despliegue en Vercel (web propia).
- [ ] Imágenes promocionales: `python3 -I tools/make_promo.py <ttf> marketing/imagenes`.
- [ ] Tráiler vertical de 15 s con gameplay real.
- [ ] Envío a CrazyGames, Poki, GameDistribution, itch.io.
- [ ] Calendario de publicaciones de `marketing/LANZAMIENTO.md`.

## Sobre Roblox

El documento de diseño original es para Roblox. La versión web ya está lista para publicar hoy; los datos de `src/data/` (criaturas, estadísticas, habilidades, islas, tienda) y el `LEEME.txt` del paquete de arte sirven para montar la versión de Roblox en Roblox Studio (importar los .obj, materiales Neon, Bloom). Publicar en Roblox requiere tu cuenta y Roblox Studio en tu ordenador.
