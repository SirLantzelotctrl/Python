# Fábrica de juegos (web y Roblox)

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

## Fábrica de juegos de Roblox

La versión de Roblox está en `../sellos-arcanos-roblox/` y es la principal. Para el siguiente juego de Roblox se reutiliza tal cual:

| Pieza | Qué hace |
|---|---|
| `src/server/DataService.lua` | Guardado en DataStore con bloqueo de sesión, autoguardado y campos nuevos sin borrar progreso |
| `src/server/ShopService.lua` | Productos de Robux con recibos sin duplicados, pases, regalo a Premium |
| `src/server/Codes.lua` + `Actions.redeem` | Códigos canjeables solo en el servidor y con límite de intentos; recompensa por unirse al grupo |
| `src/shared/Net.lua` | RemoteEvents y RemoteFunctions con nombre |
| `src/client/UI.lua` | Ventanas, botones, barras, avisos y escala para PC, móvil y consola |
| `tools/sim/` | Roblox simulado: juega una partida entera contra el servidor y el cliente reales (`--touch` para móvil) |
| `tools/check_api.py` | Valida clases, propiedades, enums y métodos contra la API oficial y avisa de las obsoletas |
| `tools/build_place.py` | Genera el `.rbxlx` y el zip listo para abrir en Studio |
| `tools/make_roblox_images.py` | Icono y miniaturas con los tamaños de Roblox |

Para un juego nuevo se cambian los datos (`tools/gen_shared.mjs` los genera desde `src/data/` de la web), las reglas (`CombatCore`, `Encounters`), las pantallas (`Menus`, `Hud`) y los textos (`Strings`). Después:

```bash
npm run build
```

```bash
python3 -I tools/sim/run_sim.py
```

Antes de publicar, el escenario de `tools/sim/scenario.lua` debe pasar entero, tanto en escritorio como con `--touch`.

## Sobre Roblox

La guía para publicar paso a paso está en `../sellos-arcanos-roblox/GUIA_PUBLICAR.md`, y el plan de promoción en `MARKETING_ROBLOX.md`. Publicar requiere tu cuenta y Roblox Studio en tu ordenador: el juego se abre desde `releases/SellosArcanos.rbxlx`, se importan los 12 modelos y se publica.
