# Sellos Arcanos · Plan de lanzamiento y publicidad

Este plan sigue lo que hacen los juegos web que funcionan: publicar en varios portales a la vez (cada portal trae su propio público y paga por anuncios), tener una web propia donde cobras con Stripe, y mover el juego con vídeos cortos de 10 a 30 segundos.

## 1. Dónde publicar (en este orden)

| # | Canal | Qué ganas | Cómo cobras | Qué subes |
|---|---|---|---|---|
| 1 | **Web propia** (Vercel + dominio) | Control total, compras con Stripe, SEO | Stripe (cristales, Pack del Fundador, Pase) + AdSense H5 cuando te aprueben | Ya está listo: `npm run build` y desplegar |
| 2 | **CrazyGames** (developer.crazygames.com) | Uno de los portales más grandes, con mucho público de 10 a 25 años | Reparto de ingresos por anuncios del SDK. Las compras con Xsolla son por invitación | El zip de `dist-portal/` + imágenes de `imagenes/` |
| 3 | **Poki** (developers.poki.com) | El portal más grande de Europa; curado, primero se envía y luego te invitan | Reparto de anuncios (sin compras) | Igual que CrazyGames, con `?platform=poki` no hace falta: se detecta solo |
| 4 | **GameDistribution** | Distribuye tu juego a cientos de webs de juegos | Reparto de anuncios | Pon tu `VITE_GD_GAME_ID` al construir |
| 5 | **itch.io** | Comunidad indie, buena para devlogs y feedback | «Paga lo que quieras» + enlace a la web propia | Zip de `dist/`, portada `itch_cover_630x500.jpg` |
| 6 | **Newgrounds, Y8, Armor Games** | Tráfico extra gratis | Anuncios propios del portal | Mismo zip |

El mismo build funciona en todos: el juego detecta el dominio y usa el SDK de anuncios correcto. En los portales se esconde la compra con dinero real (lo exigen sus reglas) y se dejan los cristales que se ganan jugando.

### Requisitos que cumplimos (portales)
- Solo anuncios del SDK del portal, pausando el juego y silenciando el audio durante el anuncio.
- Anuncios con premio opcionales y siempre con alternativa sin anuncio (Esencia, esperar la Tinta).
- Anuncios entre partidas como mucho uno cada 3 minutos y nunca a mitad de combate.
- Avisos de `loadingStart/Stop`, `gameplayStart/Stop` y `happytime` (al sellar).
- Sin enlaces externos dentro del juego, todo en inglés y español, funciona en móvil, ratón, teclado, táctil y mando.
- Peso inicial ~3 MB (los portales piden menos de 20-50 MB).

## 2. Cómo se gana dinero

1. **Anuncios con premio** (la fuente principal en portales): +3 Tinta, cofre diario, duplicar Esencia, revivir al equipo.
2. **Anuncios entre expediciones** (solo al volver a la Ciudadela, cada 3 min como mínimo).
3. **Compras en la web propia (Stripe)**:
   - Pack del Fundador US$ 2,99 (una vez): la oferta de entrada, convierte mejor que nada.
   - Cristales: 0,99 / 4,99 / 9,99 / 19,99.
   - Pase Arcano Premium US$ 4,99 por temporada (o 800 cristales).
   - Sin anuncios US$ 3,99.
4. **Temporadas cada 8 semanas** (como dice el documento de diseño): tintes nuevos, un sello nuevo y un pase nuevo. Cada temporada es una excusa para volver a anunciar el juego.

Regla del diseño que mantenemos: nada se compra al azar y nada da poder. Esto además te protege legalmente (las cajas de botín pagadas están reguladas en varios países y el público incluye menores) y es requisito de los portales.

## 3. Configurar los pagos (15 minutos)

1. Crea la cuenta en https://dashboard.stripe.com y activa los pagos (datos fiscales y cuenta bancaria).
2. En Stripe → Desarrolladores → Claves API copia la **clave secreta**.
3. En Vercel → tu proyecto → Settings → Environment Variables añade:
   - `STRIPE_SECRET_KEY` = la clave secreta (marca "Sensitive").
   - `STRIPE_CURRENCY` = `usd` (o `eur`, `mxn`...).
   - `ALLOWED_RETURN_ORIGINS` = `https://tu-dominio.com` (si usas dominio propio o itch.io).
4. Vuelve a desplegar. La pestaña «Cristales» de la tienda aparece sola cuando la clave existe.
5. Prueba primero con la clave `sk_test_...` y la tarjeta 4242 4242 4242 4242.

## 4. Anuncios en la web propia (Google H5 Games Ads)

1. Solicita AdSense con el dominio propio y pide acceso a «H5 Games Ads (Ad Placement API)».
2. Cuando te aprueben, construye con `VITE_ADSENSE_CLIENT=ca-pub-XXXXXXXX npm run build`.
3. Hasta entonces la web propia funciona sin anuncios y cobra solo con Stripe.

## 5. Calendario de las 4 primeras semanas

| Día | Acción |
|---|---|
| -7 | Abre TikTok, YouTube (Shorts), Instagram, X y un servidor de Discord con el nombre del juego. Sube las 12 fichas del Bestiario (una al día) |
| -3 | Envía el juego a CrazyGames y Poki (tardan días en revisar). Sube a itch.io como «Early Access» |
| 0 | Lanzamiento: publica el tráiler vertical en TikTok/Shorts/Reels, post en Reddit (ver `TEXTOS.md`), devlog en itch.io |
| 1-7 | 1 vídeo corto al día (guiones en `TEXTOS.md`). Responde todos los comentarios. Fija el enlace en la bio |
| 3 | Escribe a 20 creadores pequeños (1k-50k) que juegan juegos de navegador o de colección (plantilla en `TEXTOS.md`) |
| 7 | Mira qué vídeo funcionó mejor y haz 3 variaciones del mismo gancho |
| 8-14 | Campaña pagada pequeña (abajo) con los 2 vídeos que mejor funcionaron |
| 14 | Primer evento: «Lluvia de Estrellas doble» un fin de semana. Anúncialo en Discord y redes |
| 21 | Publica en GameDistribution, Newgrounds y Y8 |
| 28 | Revisión: retención (cuántos vuelven al día siguiente), ingresos por usuario, qué isla abandona la gente |

## 6. Publicidad pagada (presupuesto inicial sugerido: 100-300 US$)

- **TikTok Ads (Spark Ads)**: impulsa tu mejor vídeo orgánico, objetivo «Tráfico» a la web propia, 10-20 US$/día, edad 18-34, intereses «juegos móviles, anime, juegos de colección».
- **Meta (Instagram Reels)**: mismo vídeo, 10 US$/día, ubicación solo Reels.
- **Reddit Ads**: subreddits r/WebGames, r/incremental_games, r/pokemon (solo con creatividad propia), 5 US$/día.
- Corta lo que cueste más de 0,15 US$ por clic. Duplica lo que baje de 0,05.
- Usa el `facebook_ad_1200x628.jpg` y el tráiler vertical.

## 7. Qué medir

- **Retención D1 / D7** (los portales te la muestran): objetivo D1 > 25 %.
- **Tiempo de sesión**: objetivo > 12 minutos.
- **Conversión** en la web propia: % que compra algo (un 1-3 % es normal).
- **ARPDAU** (ingreso por usuario activo diario) en el panel de cada portal.

## 8. Fábrica de juegos: cómo hacer el siguiente

Este juego está hecho para reutilizarse (ver `../FABRICA.md`). Para el siguiente juego copias la carpeta, cambias `src/data/` (criaturas, habilidades, islas, tienda) y el arte, y mantienes igual: plataformas, anuncios, pagos, guardado, idiomas, audio y el generador de imágenes promocionales.

## 9. Antes de cobrar: lo legal mínimo

- **Stripe** te pedirá una web con política de reembolsos, términos y forma de contacto. Añade esas páginas a tu dominio (pueden ser sencillas) y pon el enlace en la configuración de Stripe.
- **Menores**: el público incluye menores de edad. Mantén la tienda solo cosmética, sin compras al azar (ya está así) y no pidas datos personales (el juego no los pide). En la UE y EE. UU. los anuncios personalizados a menores están restringidos: los portales lo gestionan con su SDK; en tu web propia activa en AdSense la opción de anuncios no personalizados para tráfico infantil.
- **Impuestos**: Stripe Tax puede calcular el IVA de las compras digitales si vendes en Europa.
- **Métricas**: la web propia lleva Vercel Web Analytics (sin cookies). Actívalo en el panel de Vercel → Analytics.
