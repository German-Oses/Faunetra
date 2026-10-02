# Guía: especies, animaciones y colisiones

## 1. Cómo está organizado

Hay **un solo molde** del que salen todas las especies:

```
entities/especies/
├── especie.tscn            ← MOLDE BASE (no se edita por animal)
│   ├── AnimatedSprite2D    ← lo que se ve
│   └── Area2D
│       └── CollisionShape2D ← la zona clickeable
├── especie.gd              ← lógica común (click, datos, etc.)
└── animales/
    └── pudu.tscn           ← escena HEREDADA del molde, solo para animales animados

data/especies/
├── pud.tres                ← ficha de datos del pudú (nombre, bioma, estado…)
└── zorro_culpeo.tres       ← ficha de datos del zorro
```

Hay **dos tipos de especie**:

| Tipo | Qué necesita | Ejemplo |
|---|---|---|
| **Estática** (una foto) | Solo su `.tres`, con la imagen en **Textura** | Cactus, flamenco, guanaco |
| **Animada** | Su `.tres` + una escena propia en `animales/` | Pudú |

**Regla simple:**
- Lo que **se ve y colisiona** va en la **escena** (`.tscn`).
- Lo que **es información** (nombre, estado, bioma…) va en el **`.tres`**.

---

## 2. Especie estática (foto)

1. Pon la imagen en `Assets/sprites/<bioma>/`. **Debe tener transparencia real** (ver sección 7).
2. Abre el `.tres` de la especie en `data/especies/`.
3. Arrastra la imagen a la casilla **Textura**.
4. Ajusta **Escala** si se ve muy grande o pequeña. Con imágenes de ~1250 px, `0.1` queda bien.
5. Deja **Escena** vacía.
6. Guarda (**Cmd+S**).

---

## 3. Especie animada, paso a paso

### Paso A — Hacer la animación en Aseprite
1. Dibuja los frames.
2. Crea un **tag** por animación (clic derecho en la línea de frames → *New Tag*). Por ejemplo: `idle`, `walk`, `comer`.
   Cada tag se convierte en una animación separada en Godot.
3. Guarda el `.aseprite` en `Assets/Animales/`.

### Paso B — Importarlo como animación en Godot
1. En **FileSystem**, selecciona el `.aseprite`.
2. Ve a la pestaña **Import** (arriba a la izquierda, al lado de *Scene*).
3. En **Import As** elige **Aseprite SpriteFrames**.
4. Presiona **Reimport**.

> Si queda como *"Aseprite (No Import)"*, no se podrá usar como animación.

### Paso C — Crear la escena del animal
1. En FileSystem, clic derecho en `entities/especies/especie.tscn` → **New Inherited Scene**.
2. Guárdala en `entities/especies/animales/<nombre>.tscn` (ej: `zorro_culpeo.tscn`).
3. Renombra el nodo raíz (ej: `ZorroCulpeo`).

Los nodos aparecen en amarillo: vienen del molde. **No los borres ni agregues otros nodos iguales**, solo cambia sus propiedades.

### Paso D — Poner la animación
1. Selecciona el nodo **AnimatedSprite2D**.
2. En el Inspector, arrastra tu `.aseprite` a **Sprite Frames**.
   (No uses *New SpriteFrames*: eso crea una animación vacía).
3. En **Animation**, elige la animación inicial (ej: `walk`).
4. En el panel **SpriteFrames** de abajo, activa el botón **Autoplay on Load** (icono ▶ con flecha) para que arranque sola.
5. Usa el ▶ de ese panel para previsualizarla. Ahí también puedes cambiar la velocidad (FPS).

### Paso E — Ajustar el tamaño
- Con el **AnimatedSprite2D** seleccionado: **Transform → Scale**.
- Referencia: con frames de 32×32, `Scale = 3` → 96 px en pantalla; `4` → 128 px (similar a las fotos de otras especies).

### Paso F — Ajustar la colisión
1. Selecciona **Area2D → CollisionShape2D**.
2. En **Shape**, haz clic en la flecha → **New CircleShape2D** (o **CapsuleShape2D** si el animal es alargado).
   ⚠️ Hazlo aunque ya tenga una forma: la que viene del molde es compartida y si la editas cambias la de todas las especies.
3. En el visor 2D, arrastra los **puntos naranjos** hasta que la forma cubra el cuerpo del animal.

> La colisión **no se agranda** con el sprite: si cambias la escala del sprite, reajusta la colisión.

### Paso G — Conectar la escena con sus datos
1. Abre el `.tres` del animal en `data/especies/`.
2. Arrastra la escena `animales/<nombre>.tscn` a la casilla **Escena**.
3. Deja vacías **Textura** y **Escala** (la escena manda en lo visual).
4. Guarda (**Cmd+S**).

---

## 4. Ver cómo quedó

| Quiero… | Cómo |
|---|---|
| Ver solo la animación | Doble clic en el `.aseprite` → panel SpriteFrames → ▶ |
| Ver el animal suelto | Abrir `entities/especies/vista_previa_especie.tscn` → botón **claqueta** (o **Cmd+R**) |
| Verlo en su bioma | Abrir la escena del bioma (ej: `biomas/bosque_templado/bosque_templado.tscn`) → **claqueta** / **Cmd+R** |
| Ver el juego completo | Botón **▶** (corre `main.tscn`, que carga el bioma de `main.gd`) |

Para usar `vista_previa_especie.tscn` con otro animal: clic derecho en el nodo `Especie` → **Delete**, luego arrastra la escena del animal dentro y ponle su `.tres` en **Data**.

---

## 5. Que aparezca en un bioma

1. En su `.tres`, **ID Bioma** debe coincidir con el bioma:

   | Bioma | ID | Escena |
   |---|---|---|
   | Zona Central Mediterránea | `1` | `biomas/zona_central/zona_central.tscn` |
   | Norte Árido | `2` | `biomas/desierto/desierto.tscn` |
   | Bosques Templados del Sur | `3` | `biomas/bosque_templado/bosque_templado.tscn` |
   | Patagonia | `4` | `biomas/patagonia/patagonia.tscn` |
   | Territorios Insulares | `5` | `biomas/territorios_insulares/territorios_insulares.tscn` |

2. Las especies **ya no se colocan en posiciones fijas**. Todos los biomas heredan de `biomas/bioma.gd`, que monta la grilla del refugio (`biomas/terreno_refugio.gd`) sobre el `TileMapLayer`:
   - **Flora** (`tipo` = `planta` u `hongo`): aparece en la barra de plantación del bioma y el jugador la planta en una parcela. Las especies `EX` (extintas) no se pueden plantar; solo se descubren en la Biopedia.
   - **Fauna** (el resto): llega sola cuando el refugio cumple sus requisitos de flora sana y salud.

3. Reglas del ecosistema en `data/ecosistema/reglas_ecosistema.json` (se referencian las especies por su **nombre común**, sin importar tildes):
   - `sinergias`: planta que potencia el crecimiento de otra adyacente (ej: Alerce → Luma, «Aura de Humedad», +20%).
   - `atracciones`: plantas que deben estar sanas para que llegue un animal (ej: Pudú ← Quila + Arrayán). Un animal sin regla usa la regla general (cantidad de plantas sanas y % de salud crecientes).
   - `bloqueadores`: basura y especies invasoras de cada bioma, con su costo en PR.
   - El campo **Umbral Desbloqueo** del `.tres` es el % mínimo de salud del bioma para que esa especie de fauna aparezca.

4. Para ver un bioma en el juego: presiona ▶ y usa las teclas **1–5** para cambiar de bioma (atajo de desarrollo en `main.gd`, ignora los bloqueos). En builds de depuración, **F7** da +100 PR y **F8** simula 3 días sin jugar.

> Una especie sin **Textura** ni **Escena** aparece como un cuadro de color según su tipo, hasta que tenga su arte.
> La partida se guarda en `user://faunetra_guardado.json`; bórralo para empezar de cero.

---

## 6. Checklist rápido para un animal nuevo

- [ ] `.aseprite` con tags, en `Assets/Animales/`
- [ ] Importado como **Aseprite SpriteFrames**
- [ ] Escena heredada en `entities/especies/animales/`
- [ ] AnimatedSprite2D: Sprite Frames + Animation + Autoplay + Scale
- [ ] CollisionShape2D: **New** shape propia, ajustada al cuerpo
- [ ] `.tres`: casilla **Escena** apuntando a la escena, **ID Bioma** correcto
- [ ] (Fauna) Opcional: regla de atracción en `data/ecosistema/reglas_ecosistema.json`
- [ ] Guardado todo (**Cmd+S**)

---

## 7. Problemas comunes

| Síntoma | Causa | Solución |
|---|---|---|
| El animal no se ve | Sprite Frames vacío (se usó *New SpriteFrames*) | Arrastrar el `.aseprite` a la casilla |
| No puedo arrastrar el `.aseprite` | Importado como *No Import* | Paso B |
| Se ve borroso | Filtro de textura | El molde ya usa *Nearest*; no cambies **Texture → Filter** |
| Se ve diminuto | Frames chicos (32 px) | Subir **Scale** del AnimatedSprite2D |
| No aparece en el juego | ID Bioma incorrecto, o es fauna y aún no se cumplen sus requisitos | Sección 5 (la Biopedia muestra la pista de qué necesita) |
| Al apretar ▶ sale otro bioma | ▶ corre `main.gd` | Teclas **1–5**, la claqueta / **Cmd+R**, o cambiar `BIOMA_INICIAL` en `main.gd` |
| Imagen con fondo blanco o a cuadros | La imagen tiene la "transparencia" pintada | Exportar un PNG con transparencia real (en Aseprite: fondo transparente) |
| Cambié la colisión y cambió en todas | Se editó la forma compartida del molde | En la escena del animal: Shape → **New CircleShape2D** |
| Godot pregunta por archivos cambiados | Se editaron fuera del editor | Elegir **Reload** |
