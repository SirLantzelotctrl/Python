# Publicar Sellos Arcanos en Roblox — paso a paso

La primera vez se tarda entre 1 y 2 horas. Todo lo que hay que tocar está aquí, en orden.

## Qué hay en el paquete

| Archivo / carpeta | Para qué sirve |
|---|---|
| `SellosArcanos.rbxlx` | El juego completo: servidor, cliente, datos, tienda y guardado. Se abre con Roblox Studio. |
| `modelos/` | Las 12 criaturas en `.obj` + `.mtl` para importarlas (paso 3). |
| `imagenes/` | Icono 512×512 y miniaturas 1920×1080 en español e inglés para la página del juego. |
| `texturas/` | Círculos mágicos en PNG (opcional, paso 10). |
| `src/` y `default.project.json` | El código fuente, por si usas Rojo o quieres revisar el código. |
| `MARKETING_ROBLOX.md` | Plan de lanzamiento y publicidad, con los textos listos para copiar. |

## 1. Prepara tu cuenta de Roblox

1. Verifica tu correo y activa la **verificación en dos pasos** (Configuración → Seguridad).
2. Decide a qué público quieres llegar. El género de colección de criaturas tiene mucho público infantil, así que conviene llegar a todas las edades:
   - **Mayores de 16**: cuenta en regla con al menos 2 días, verificación de edad (estimación facial o documento) y el cuestionario de madurez (paso 6).
   - **Roblox Kids (5–8 años) y Roblox Select (9–15 años)**: además, verificación de identidad + verificación en dos pasos + suscripción Roblox Plus/Premium, **o bien** pagar una tasa de 1.000 R$ por juego que Roblox te devuelve a los 3 meses si el juego cumple las normas. Roblox prueba primero el juego con jugadores mayores de 16 y después lo evalúa para los más jóvenes.
   - Roblox cambió estas reglas en mayo y junio de 2026. Antes de publicar, consulta en Creator Hub la página **Publishing requirements / Roblox Kids and Select**.

## 2. Abre el juego en Roblox Studio

1. Instala Roblox Studio desde create.roblox.com e inicia sesión.
2. **Archivo → Abrir desde archivo…** y elige `SellosArcanos.rbxlx`.
3. Pulsa **Play** (F5). El mundo se construye solo: la Ciudadela con los 12 portales y las 12 islas. Elige tu primera criatura y juega.
   - Hasta que importes los modelos (paso 3), las criaturas aparecen como figuras provisionales. El juego funciona igual.
   - En **Ver → Salida** no debería salir ningún error en rojo. La línea `[Sellos Arcanos] servidor listo · 12 criaturas · 12 islas` confirma que el servidor ha arrancado bien.

## 3. Importa las 12 criaturas

1. En Studio: pestaña **Inicio → Importar 3D**.
2. Selecciona los 12 archivos `.obj` de la carpeta `modelos/`. Deja los `.mtl` en la misma carpeta.
3. Acepta las opciones por defecto. Cada archivo se convierte en un **Model** con el nombre del archivo (`Hidra`, `Fenix`, `Golem`…) y piezas como `Hidra_Cuerpo` o `Hidra_Brillo`. **No cambies los nombres**: el juego reconoce las piezas por su nombre y les pone el material Neon y el color del elemento automáticamente.
4. En el **Explorador**, arrastra los 12 modelos a **ServerStorage → CreatureModels**.
5. Pulsa Play: ahora las criaturas usan los modelos de verdad. El juego ajusta su tamaño según la forma: Cría, Adulta o Primordial (jefe).

Ninguna pieza supera el límite de Roblox de 20.000 triángulos por malla (la más grande tiene 11.368), así que no hace falta reducir nada.

> Si alguna criatura camina de espaldas, cambia `Config.ModelYawOffset` (ReplicatedStorage → Shared → Config) de `180` a `0`.

## 4. Publica la experiencia

1. **Archivo → Publicar en Roblox → Crear nueva experiencia**.
   - Nombre: `Sellos Arcanos`. Descripción: cópiala de `MARKETING_ROBLOX.md`.
   - Género: RPG. Dispositivos: Ordenador, Teléfono, Tablet y Consola (los controles de mando ya están puestos).
2. **Inicio → Configuración del juego → Seguridad** → activa **Permitir acceso de Studio a los servicios de API**. Sin esto, el progreso no se guarda cuando pruebas en Studio. En los servidores reales se guarda siempre.
3. Vuelve a publicar con **Archivo → Publicar en Roblox** (Alt+P) cada vez que cambies algo.

## 5. Crea los productos de Robux y los pases

En **create.roblox.com/dashboard/creations → tu experiencia → Monetización**:

**Productos para desarrolladores** (se pueden comprar muchas veces):

| Nombre en Roblox | Precio | Dónde pegar el ID en `Config` |
|---|---|---|
| 100 Cristales Arcanos | 49 R$ | `Config.Products[1].id` |
| 550 Cristales Arcanos | 249 R$ | `Config.Products[2].id` |
| 1200 Cristales Arcanos | 499 R$ | `Config.Products[3].id` |
| 2600 Cristales Arcanos | 999 R$ | `Config.Products[4].id` |
| Pack del Fundador | 149 R$ | `Config.Products[5].id` (el juego impide comprarlo dos veces) |

**Pases** (se compran una sola vez):

| Nombre en Roblox | Precio | Dónde pegar el ID |
|---|---|---|
| Pase Arcano Premium | 399 R$ | `Config.GamePasses.pase_premium.id` |
| Sellador VIP | 299 R$ | `Config.GamePasses.vip.id` |

Después:

1. Abre **ReplicatedStorage → Shared → Config** en Studio y pega cada ID en lugar del `0`.
2. Publica de nuevo.
3. Como imagen de cada producto puedes usar `imagenes/es/cuadrado_1080.jpg` o los retratos de las criaturas.

Notas:

- La tienda del juego lee de Roblox el **precio real** de cada producto. Si cambias precios en el panel, o usas la herramienta de **optimización de precios** de Roblox, no tienes que tocar el código.
- Un producto con ID `0` no aparece en la tienda, así que puedes lanzar sin algunos.
- Las compras están protegidas contra duplicados: si Roblox reintenta un recibo, los cristales no se dan dos veces.
- Roblox te ingresa el 70 % de cada venta. Los suscriptores de Roblox Premium reciben 5 cristales diarios, porque su tiempo de juego te genera **Premium Payouts**.

## 6. Página del juego y cuestionario de madurez

En el panel de tu experiencia:

1. **Icono**: `imagenes/icono_512.png`.
2. **Miniaturas**: `imagenes/es/miniatura_1.jpg` a `miniatura_5.jpg`. En **Localización** puedes subir las de `imagenes/en/` para los jugadores en inglés.
3. **Audiencia → Madurez y cumplimiento**: rellena el cuestionario con sinceridad. Respuestas que corresponden a este juego:
   - Violencia: fantasía leve. Criaturas mágicas que luchan con hechizos, sin sangre ni muertes realistas.
   - Sin sangre, sin contenido romántico, sin miedo intenso, sin lenguaje adulto.
   - **Sin artículos aleatorios de pago**: todo lo que se compra es fijo y se sabe qué es.
   - Sin chat propio (se usa el de Roblox) y sin enlaces externos.

   El resultado esperado es contenido **leve**, que permite llegar a Roblox Kids y Select.
4. **Idiomas**: el juego trae español e inglés y elige según el idioma de la cuenta (se puede cambiar en Ajustes). En **Localización** puedes activar la traducción automática para los demás idiomas.
5. **Servidores privados**: actívalos. Por ejemplo, 100 R$ al mes. Son otra fuente de ingresos.
6. Cuando todo funcione: **Configuración → Básica → Público**.

## 7. Grupo y códigos (promoción)

- Crea un **grupo de Roblox** llamado «Sellos Arcanos» y vincúlalo a la experiencia. Pega su ID en `Config.GroupId`. Quien se une y pulsa *Reclamar* en **Tienda → Códigos** recibe 30 cristales y 300 de esencia, una vez por cuenta.
- Los **códigos** están en **ServerScriptService → Server → Codes**. Los jugadores no pueden verlos. Ya vienen tres: `SELLOS`, `LANZAMIENTO` (caduca el 31-03-2027) y `PRIMORDIAL`. Añade uno distinto por cada creador de contenido (`MARIA20 = { crystals = 60 }`, por ejemplo) para saber qué vídeo trae más jugadores. Hay un límite de intentos para que nadie los adivine a la fuerza.

## 8. Comprueba antes de abrir al público

- [ ] **Prueba → Servidor + 2 jugadores**: los dos ven las mismas criaturas, combaten y sellan.
- [ ] **Prueba → Dispositivo**: con un teléfono emulado, los botones táctiles funcionan.
- [ ] Una compra de prueba en Studio: es simulada y no cobra. Los cristales llegan y el Pack del Fundador desaparece de la tienda.
- [ ] Sal y vuelve a entrar en el juego publicado: el progreso se mantiene.
- [ ] Canjea el código `SELLOS` en **Tienda → Códigos**.
- [ ] En **Ver → Salida**, ningún error en rojo.

## 9. Actualizaciones

1. Cambia lo que quieras en Studio y publica.
2. En el panel de la experiencia, menú **⋯ → Reiniciar servidores para actualizaciones** (*Restart Servers for Updates*), para que todos los jugadores tengan la versión nueva sin perder el progreso.
3. El guardado usa `Config.DataStoreName = "SellosArcanos_Perfiles_v1"`. **No lo cambies**: si lo cambias, todos los jugadores empiezan de cero.

## 10. Opcional: música y círculos con textura

El juego funciona sin recursos propios: los círculos se hacen con piezas de neón y no hay música. Si quieres más acabado:

1. Sube los PNG de `texturas/` como calcomanías e imágenes (Creator Hub → Development Items) y una pista de música con licencia (por ejemplo, de la biblioteca de audio de Roblox).
2. Pega los IDs en `Config.Assets`.

## Cobrar el dinero (DevEx)

- Con al menos **30.000 Robux ganados**, 13 años o más y la verificación de identidad, pides el cambio en **create.roblox.com/dashboard/devex**.
- Tarifa estándar desde septiembre de 2025: unos **0,0038 US$ por Robux**. Hay una tarifa mayor para parte del gasto de adultos en EE. UU. desde junio de 2026. Comprueba la cifra actual en la página de DevEx, porque Roblox la actualiza.
- Ejemplo: 100.000 R$ ganados ≈ 380 US$.

## Si algo falla

| Síntoma | Solución |
|---|---|
| La tienda dice «Los productos aún no están configurados» | Los IDs de `Config.Products` siguen a `0` (paso 5). |
| No guarda el progreso en Studio | Activa el acceso de Studio a los servicios de API (paso 4.2). |
| Las criaturas son figuras simples | Los modelos no están en **ServerStorage → CreatureModels**, o les has cambiado el nombre (paso 3). |
| Una criatura mira hacia atrás | `Config.ModelYawOffset` a `0`. |
| «Ese código no existe» | El código debe estar en **Server → Codes** en MAYÚSCULAS. Publica después de añadirlo. |
| El botón del grupo no aparece | `Config.GroupId` sigue a `0`. |

## Para desarrolladores

- Código fuente en `src/` (`shared`, `server`, `client`). Con Rojo: `rojo serve default.project.json`.
- Pruebas: `python3 -I tools/sim/run_sim.py` (y con `--touch` para móvil) juega una partida completa contra la lógica real del servidor y del cliente en un Roblox simulado: combate, sellado, jefe, tienda, códigos, compras, guardado y reconexión.
- `npm run check` revisa la sintaxis; `python3 -I tools/check_api.py API-Dump.json` comprueba cada clase, propiedad y método contra la API oficial de Roblox, y avisa de las funciones obsoletas.
- `python3 -I tools/build_place.py` genera el `.rbxlx` y el zip.
