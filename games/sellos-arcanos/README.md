# Sellos Arcanos · Invoca. Sella. Domina.

Juego de acción y colección de criaturas en 3D para navegador (PC y móvil), hecho con Three.js a partir del paquete de arte «Sellos Arcanos · Modelos 3D» y del documento de diseño.

- 12 criaturas con 3 formas (36 entradas de Bestiario), 48 habilidades, 4 dominios elementales.
- Combate en tiempo real con equipo de 3, esquiva y Definitiva; minijuego de sellado trazando la runa.
- 12 islas con su jefe Primordial de 3 fases y anclas rúnicas.
- Progresión: niveles, entrenamiento, evolución, vínculo, rango de Sellador, contratos diarios, recompensa diaria y Pase Arcano.
- Tienda cosmética (tintes, sellos, efectos) con cristales; compras con Stripe en la web propia; anuncios con premio en portales.
- Español e inglés, teclado, táctil y mando, guardado automático.

## Comandos

```bash
npm install
```

```bash
npm run dev
```

```bash
npm run build
```

`npm run build` deja el juego listo en `dist/` (el mismo build sirve para Vercel, itch.io y los portales; se detecta la plataforma por el dominio).

Para regenerar los recursos desde `raw/` (modelos y renders originales):

```bash
npm run assets
```

## Variables de entorno

| Variable | Dónde | Para qué |
|---|---|---|
| `STRIPE_SECRET_KEY` | Vercel (servidor) | Activa las compras con dinero real |
| `STRIPE_CURRENCY` | Vercel (servidor) | Moneda (por defecto `usd`) |
| `ALLOWED_RETURN_ORIGINS` | Vercel (servidor) | Dominios extra a los que Stripe puede volver |
| `VITE_ADSENSE_CLIENT` | build | Anuncios H5 de Google en la web propia |
| `VITE_GD_GAME_ID` | build | ID de GameDistribution |
| `VITE_API_BASE` | build | URL de la API de pagos si el juego se sirve desde otro dominio (p. ej. itch.io) |

## Estructura

```
api/            Funciones de Vercel: checkout y verificación de Stripe
public/assets/  Modelos (creatures.bin), texturas y renders en WebP
raw/            Paquete de arte original (obj, png)
src/data/       Criaturas, habilidades, islas y tienda
src/core/       Guardado, idioma, audio, plataformas
src/engine/     Render, criaturas 3D, círculos mágicos, efectos, controles
src/game/       Combate, IA, habilidades, sellado, progresión
src/ui/         Pantallas
marketing/      Plan de lanzamiento, textos e imágenes promocionales
tools/          Conversión de recursos e imágenes promocionales
```

Pruebas: parámetro `?fakeads=1` simula anuncios; `?platform=poki` (o `crazygames`, `gamedistribution`) fuerza una plataforma; `?capture=1` congela el reloj para grabar tráilers fotograma a fotograma.

Ver `marketing/LANZAMIENTO.md` para publicar y promocionar, y `FABRICA.md` para hacer el siguiente juego.
