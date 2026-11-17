# Sellos Arcanos — versión Roblox

RPG de colección de criaturas: invoca a tu criatura, combate en tiempo real en 12 islas, traza la runa para **sellar** a los enemigos debilitados y vence a los 12 jefes Primordiales.

- **Para publicarlo**: [`GUIA_PUBLICAR.md`](GUIA_PUBLICAR.md)
- **Para promocionarlo**: [`MARKETING_ROBLOX.md`](MARKETING_ROBLOX.md)
- **Archivo del juego**: `dist/SellosArcanos.rbxlx` (y el paquete `dist/SellosArcanos-Roblox-v1.0.zip`, se generan con `npm run build`)

## Qué incluye

- **Servidor autoritativo**: combate a 20 Hz, IA de criaturas salvajes, estados alterados, ventaja de dominio, jefes con fases y anclas, sellado validado en el servidor. El cliente no puede darse recompensas.
- **Guardado** en DataStore con bloqueo de sesión (evita duplicar objetos entre servidores), autoguardado y guardado al cerrar.
- **Monetización**: productos de Robux con recibos idempotentes, pases (Pase Arcano Premium y VIP), Pack del Fundador de compra única, regalo diario a suscriptores Premium, precios leídos de Roblox.
- **Retención**: recompensa diaria, contratos, Pase Arcano por temporadas, bestiario, evolución en 3 formas, vínculo y rangos.
- **Promoción**: códigos canjeables guardados solo en el servidor y con límite de intentos; recompensa por unirse al grupo.
- **Cliente**: HUD, menús (Ciudadela, Bestiario, ficha, Tienda, Pase, Ajustes), minijuego de sellado con ratón, táctil, teclado o mando, efectos y sonido. Interfaz en español e inglés, adaptada a PC, móvil, tablet y consola.

## Estructura

```
src/shared   → ReplicatedStorage/Shared           (datos, fórmulas, red, textos, Config)
src/server   → ServerScriptService/Server         (Main + servicios + Codes)
src/client   → StarterPlayerScripts/Client        (Main + UI, HUD, efectos, sellado, menús)
tools/       → generación, comprobaciones y simulador
```

`GameData.lua` se genera a partir de los datos de la versión web (`npm run gen`), así que las dos versiones comparten criaturas, habilidades, islas y tienda.

## Comprobaciones

```bash
npm run check
```

```bash
python3 -I tools/check_api.py API-Dump.json
```

```bash
python3 -I tools/sim/run_sim.py
```

```bash
python3 -I tools/sim/run_sim.py --touch
```

```bash
npm run build
```

1. `npm run check` revisa la sintaxis de los 22 scripts.
2. `check_api.py` comprueba clases, propiedades, enums y métodos contra el volcado oficial de la API de Roblox, y avisa de las funciones obsoletas.
3. `run_sim.py` ejecuta el servidor y el cliente reales en un Roblox simulado y juega una partida completa: elegir criatura con el botón, viajar, combatir con las teclas, sellar trazando la runa, vencer al Primordial, pulsar todos los botones de todos los menús, canjear códigos, comprar con Robux, guardar y reconectar. Con `--touch` repite la partida en un teléfono táctil de 844×390.
4. `npm run build` genera el `.rbxlx` y el zip para publicar. Si cambias el arte, `python3 -I tools/make_roblox_images.py <carpeta_ttf>` regenera las imágenes.
