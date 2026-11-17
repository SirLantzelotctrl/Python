# Sellos Arcanos en Roblox — plan de lanzamiento y publicidad

En Roblox el algoritmo de descubrimiento manda. Recomienda más los juegos que **retienen** (los jugadores vuelven al día siguiente y a la semana), **enganchan** (sesiones largas) y **convierten** (quien hace clic en la miniatura se queda a jugar). La publicidad de pago solo acelera ese proceso. El plan tiene tres fases: preparar la página, conseguir los primeros jugadores, y después mantener el juego vivo con actualizaciones.

## 1. Página del juego (textos listos)

**Título**: `Sellos Arcanos` → con cada actualización: `Sellos Arcanos [🌑 ECLIPSE]`, `Sellos Arcanos [⚡ NUEVA ISLA]`…

**Descripción (español)**

```
🔮 Invoca, sella y domina a los 12 Primordiales.

Explora 12 islas flotantes, combate en tiempo real junto a tu criatura y,
cuando el enemigo esté débil, TRAZA LA RUNA para sellarlo antes de que escape.

✨ 12 criaturas · 36 formas (Cría → Adulta → Primordial)
⚔️ Combate con ventaja de dominio: Abisal > Ígneo > Natural > Arcano > Abisal
🐉 Jefes Primordiales con fases y anclas rúnicas
📖 Bestiario, contratos diarios, Pase Arcano y cosméticos
📱 PC, móvil, tablet y consola

🎁 CÓDIGOS: abre la Tienda → Códigos. ¡Prueba SELLOS!
👥 Únete al grupo para una recompensa gratis.
```

**Description (English)**

```
🔮 Summon, seal and rule the 12 Primordials.

Explore 12 floating islands, battle in real time beside your creature and,
when the foe is weak, TRACE THE RUNE to seal it before it breaks free.

✨ 12 creatures · 36 forms (Hatchling → Adult → Primordial)
⚔️ Domain advantage: Abyssal > Igneous > Natural > Arcane > Abyssal
🐉 Primordial bosses with phases and rune anchors
📖 Bestiary, daily contracts, Arcane Pass and cosmetics
📱 PC, mobile, tablet and console

🎁 CODES: open Shop → Codes. Try SELLOS!
👥 Join the group for a free reward.
```

**Imágenes**:

- Icono: `imagenes/icono_512.png`.
- Miniaturas: `imagenes/es/miniatura_1..5.jpg`, o las de `en/` para el público en inglés.
- Si Roblox te ofrece **pruebas de miniaturas o iconos**, úsalas: prueba el icono de la Hidra contra el de un sello de color y quédate con el que tenga más clics.

## 2. Antes de lanzar (semana 0)

1. **Grupo de Roblox** «Sellos Arcanos». Vincúlalo al juego y pon su ID en `Config.GroupId`: la recompensa por unirse hace crecer el grupo, y los miembros reciben los anuncios del grupo.
2. **Servidor de Discord** con canales #anuncios, #códigos, #sugerencias, #capturas y #errores. Pon el enlace en la descripción del grupo; los enlaces externos en la página del juego dependen de la edad de la cuenta y de las normas de Roblox.
3. **Prueba cerrada** con 10–20 personas: amigos y gente de Discord. Mide si entienden el sellado sin explicación. El tutorial aparece en los primeros 15 segundos.
4. Prepara 3 **vídeos cortos** verticales (15–30 s) grabados en el juego: (a) trazar la runa y sellar, (b) la Hidra Primordial en fase 3, (c) evolución Cría → Primordial. Las miniaturas `tiktok_1080x1920.jpg` sirven de portada.

## 3. Lanzamiento (semanas 1–2)

### Anuncios patrocinados (Ads Manager)

- En **ads.roblox.com** crea una campaña de **experiencia patrocinada**: tu juego aparece en Inicio y en Búsqueda.
- Empieza con un presupuesto pequeño durante 5–7 días (por ejemplo, 15–30 US$/día) y **mira estas métricas en Analíticas**, no solo los clics:
  - **Tasa de partidas cualificadas** (*Qualified Play-Through Rate*): quien entra y juega más de un minuto. Si es baja, la miniatura promete algo que el juego no enseña pronto.
  - **Retención D1 y D7**. Compárala con los *benchmarks* de juegos parecidos que muestra Creator Hub.
  - **Ingresos por usuario de pago** y **conversión a pagador**.
- Si la retención D1 está por encima de la media del género, sube el presupuesto. Si está por debajo, mejora el juego antes de gastar más: el algoritmo deja de recomendar los juegos que no retienen.
- Segmenta por idioma: una campaña en español y otra en inglés, cada una con sus miniaturas.

### Creadores de contenido (lo más rentable)

- Busca youtubers y tiktokers de Roblox **pequeños y medianos** (5k–200k suscriptores) que hagan juegos de criaturas o RPG, sobre todo en español, donde hay menos competencia.
- Dale a cada uno **su propio código** en `Server → Codes` (`MARIA20 = { crystals = 60 }`). Así sus seguidores reciben algo y tú sabes qué vídeo funciona.
- Mensaje tipo:

```
¡Hola, {nombre}! Soy el creador de Sellos Arcanos, un juego de Roblox de
coleccionar criaturas mágicas sellándolas con runas (12 Primordiales, jefes
con fases). Me encantaría que lo probaras: he creado el código {CODIGO} para tu
comunidad (60 cristales gratis). Si haces vídeo, te doy acceso anticipado a la
próxima isla. ¡Gracias!
```

### Códigos (publicidad gratis)

- Las webs y vídeos de «códigos de Roblox» publican los códigos de cada juego. Esto da tráfico constante y gratuito.
- Publica un código nuevo con **cada actualización** y en los hitos: 1.000 miembros en el grupo, 10.000 visitas… Anúncialo en el grupo, en Discord y en la descripción.
- Pon fecha de caducidad (`expires`) a los códigos de evento, para que la gente vuelva a por el siguiente.

## 4. Mantener el juego vivo (cada 2–3 semanas)

| Semana | Actualización | Gancho |
|---|---|---|
| 3 | Equilibrio y mejoras según las métricas | Código `GRACIAS` |
| 5 | Evento de fin de semana: doble esencia | Título `[⚡ x2]` |
| 7 | Temporada 2 del Pase Arcano: tintes y sellos nuevos | Título `[🌑 TEMPORADA 2]` |
| 10 | Nueva isla o modo jefe cooperativo | Vídeo con creadores |

Para cada actualización: cambia el título, sube una miniatura nueva, publica un código, pon un anuncio en el grupo y en Discord, y reinicia los servidores para actualizar.

## 5. Monetización: qué vigilar

- **Primera compra**: el Pack del Fundador (149 R$, una vez) es la oferta de entrada. Si menos del 1–2 % de los jugadores compra algo, prueba a bajarle el precio con la **optimización de precios** de Roblox. La tienda ya muestra el precio real, así que no hay que tocar el código.
- **Pase Arcano** (399 R$ o 800 cristales): la temporada da motivos para volver cada día.
- **Roblox Premium**: los suscriptores reciben cristales diarios. Su tiempo de juego te genera **Premium Payouts** sin que paguen nada.
- **Servidores privados**: actívalos (por ejemplo, 100 R$/mes) para grupos de amigos y creadores.
- **Anuncios con recompensa** (*Rewarded Video*): Roblox los habilita para experiencias con mucho tráfico (unos 100.000 usuarios activos diarios) y contenido leve. Cuando el juego llegue a esa cifra, se puede añadir un «mira un anuncio y duplica tu recompensa» solo para mayores de 13.

## 6. Normas que hay que respetar

- No prometas en miniaturas ni en anuncios cosas que no hay en el juego, y no uses logotipos ni personajes de otros juegos.
- Nada de «dame Robux gratis» ni de pedir datos personales. Las recompensas por unirse al grupo o canjear códigos están permitidas.
- Rellena el **cuestionario de madurez** de verdad (ver `GUIA_PUBLICAR.md`): sin él, Roblox limita quién puede jugar.
- Las reglas para llegar a menores de 16 (Roblox Kids y Select) cambiaron en 2026. Están resumidas en la guía de publicación.

## 7. Objetivos realistas del primer mes

| Métrica | Objetivo de partida |
|---|---|
| Tasa de partidas cualificadas | > 50 % |
| Retención D1 | ≥ media del género en Creator Hub |
| Sesión media | > 12 min |
| Conversión a pagador | 1–3 % |
| Miembros del grupo | 10 % de los visitantes únicos |

Si no se alcanzan, el orden de prioridad es: 1) los primeros 60 segundos (tutorial y primer sellado), 2) la miniatura, y 3) el ritmo de recompensas de la primera hora. No subas el presupuesto de anuncios hasta haberlo mejorado.
