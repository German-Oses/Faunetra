-- Árboles nativos del paisaje de cada bioma (adornos del borde del mapa, no se plantan).
-- Uso (desde la carpeta del proyecto):
--   aseprite -b --script herramientas/aseprite/arboles_paisaje.lua
-- Genera Assets/decoracion/arbol_<bioma>_<a|b>.png (64x96, base al centro de la fila inferior)
-- y una hoja de contactos en herramientas/aseprite/previas/arboles_paisaje.png.
-- Vista lateral, luz arriba-izquierda, contorno del tono más oscuro de cada material.

local floor, abs, sin, cos, pi, sqrt, max, min = math.floor, math.abs, math.sin, math.cos, math.pi, math.sqrt, math.max, math.min
local PROY = PROYECTO or app.fs.currentPath   -- PROYECTO permite ejecutarlo con dofile desde otra carpeta
local RAIZ = app.fs.joinPath(PROY, "Assets/decoracion/")
local PREV = app.fs.joinPath(PROY, "herramientas/aseprite/previas/")
local W, H = 64, 96
local BASE = H - 1

local function hex(s) return app.pixelColor.rgba(tonumber(s:sub(2,3),16), tonumber(s:sub(4,5),16), tonumber(s:sub(6,7),16), 255) end
-- Paleta de un material: o (contorno), d (sombra), m (medio), l (luz)
local function pal(o, d, m, l) return {o=hex(o), d=hex(d), m=hex(m), l=hex(l)} end
local function hash(x, y, s)
  local v = (x*374761393 + y*668265263 + s*982451653) % 2147483647
  v = (v ~ (v >> 13)) * 1274126177 % 2147483647
  return (v % 1000) / 1000
end

local function nuevo() return {c={}, mat={}} end
local function pon(m, x, y, col, mat)
  x, y = floor(x + 0.5), floor(y + 0.5)
  if x >= 0 and x < W and y >= 0 and y < H then m.c[y*W+x] = col; m.mat[y*W+x] = mat end
end
local function hay(m, x, y) return x >= 0 and x < W and y >= 0 and y < H and m.c[y*W+x] ~= nil end

-- Mata de follaje: elipse de borde irregular, sombreada desde arriba-izquierda.
-- `ralo` agrega huecos (follaje abierto); `sombra_extra` oscurece matas bajas o traseras.
local function mata(m, cx, cy, rx, ry, p, semilla, ralo, sombra_extra)
  ralo = ralo or 0; sombra_extra = sombra_extra or 0
  for y = floor(cy - ry - 1), floor(cy + ry + 1) do
    for x = floor(cx - rx - 1), floor(cx + rx + 1) do
      local dx, dy = (x - cx) / rx, (y - cy) / ry
      local d = dx*dx + dy*dy
      local h = hash(x, y, semilla)
      if d <= 1.0 - 0.28*h and h >= ralo then
        local s = dy*0.85 + dx*0.45 + (hash(x, y, semilla + 7) - 0.5)*0.4 + sombra_extra
        local col = p.m
        if s < -0.5 then col = p.l elseif s > 0.35 then col = p.d end
        pon(m, x, y, col, p)
      end
    end
  end
end

-- Tronco recto con corteza: luz a la izquierda, sombra a la derecha, vetas verticales.
local function tronco(m, cx, y0, y1, ancho, p, semilla, vetas)
  for y = y0, y1 do
    local w = ancho + ((y > y1 - 3) and 1 or 0)   -- se ensancha al pie
    local x0 = floor(cx - w/2 + 0.5)
    for x = x0, x0 + w - 1 do
      local col = p.m
      if x == x0 then col = p.l elseif x >= x0 + w - 1 - floor(w/4) then col = p.d end
      if vetas and hash(x, floor(y/3), semilla) > 0.78 then col = p.d end
      pon(m, x, y, col, p)
    end
  end
end

local function rama(m, x0, y0, x1, y1, grosor, p)
  local n = max(abs(x1 - x0), abs(y1 - y0), 1)
  for i = 0, n do
    local x, y = x0 + (x1 - x0)*i/n, y0 + (y1 - y0)*i/n
    for g = 0, grosor - 1 do pon(m, x + g, y, (g == 0) and p.m or p.d, p) end
  end
end

-- Fronda de palma o helecho: raquis arqueado con folíolos a ambos lados, que cuelgan
-- un poco y se acortan hacia la punta. La cara superior recibe la luz.
-- Corona: primero las frondas traseras (más oscuras), luego las delanteras, para separarlas.
local function fronda(m, cx, cy, ang, largo, caida, p, foliolo, trasera)
  if trasera then p = {o=p.o, d=p.o, m=p.d, l=p.m} end   -- las frondas de atrás van un tono más oscuras
  local px0, py0 = cx, cy
  for k = 1, largo do
    local x = cx + cos(ang)*k
    -- las frondas verticales casi no caen; las laterales se arquean hacia abajo
    local y = cy + sin(ang)*k*0.75 + k*k*caida*(0.15 + abs(cos(ang)))
    local tx, ty = x - px0, y - py0
    local n = sqrt(tx*tx + ty*ty)
    if n > 0 then tx, ty = tx/n, ty/n end
    local f = foliolo * (1 - (k/largo)*0.75)
    if k > 2 then
      for j = 1, floor(f + 0.5) do
        local cae = j*0.45
        pon(m, x - ty*j, y + tx*j + cae, (j > f - 1) and p.d or p.m, p)   -- lado de abajo
        pon(m, x + ty*j, y - tx*j + cae, (j < 2) and p.l or p.m, p)       -- lado de arriba
      end
    end
    rama(m, px0, py0, x, y, 1, {o=p.o, m=p.l, d=p.l})
    px0, py0 = x, y
  end
end

-- Contorno: cada píxel vacío junto al dibujo toma el tono `o` del material vecino.
local function corona(m, cx, cy, angulos, largo, caida, p, foliolo)
  for pasada = 0, 1 do
    for j, a in ipairs(angulos) do
      if j % 2 == pasada then fronda(m, cx, cy, a, largo + (j % 3)*2, caida, p, foliolo, pasada == 0) end
    end
  end
end

local function contorno(m)
  local agregar = {}
  for y = 0, H - 1 do for x = 0, W - 1 do
    if not hay(m, x, y) then
      for _, d in ipairs({{0,1},{1,0},{-1,0},{0,-1}}) do
        if hay(m, x + d[1], y + d[2]) then agregar[y*W+x] = m.mat[(y+d[2])*W + x + d[1]].o; break end
      end
    end
  end end
  for k, col in pairs(agregar) do m.c[k] = col end
end

local function guardar(m, nombre)
  contorno(m)
  local img = Image(W, H, ColorMode.RGB)
  for k, col in pairs(m.c) do img:drawPixel(k % W, floor(k / W), col) end
  img:saveAs(RAIZ .. nombre .. ".png")
  return img
end

-- ── Paletas ────────────────────────────────────────────────────────────────────────────
local CORTEZA_GRIS = pal("#2A2622", "#4E4640", "#6E645A", "#8E8476")
local CORTEZA_OSCURA = pal("#1E1814", "#3A2E26", "#55463A", "#75644F")
local ARBOLES = {}

-- 1a · Quillay (Quillaja saponaria): siempreverde de copa densa, redondeada e irregular.
ARBOLES.arbol_1_a = function(m)
  local hoja = pal("#1A2E1C", "#2E4A2A", "#4A6B34", "#6E8E45")
  tronco(m, 32, 66, BASE, 4, CORTEZA_GRIS, 11, true)
  rama(m, 31, 72, 24, 60, 2, CORTEZA_GRIS)
  rama(m, 33, 70, 41, 58, 2, CORTEZA_GRIS)
  local matas = {{22,56,11,9,0.25},{43,55,11,9,0.25},{32,58,13,9,0.2},{18,44,10,10,0.1},{46,43,10,10,0.1},
                 {32,44,14,12,0},{24,32,10,9,0},{40,31,11,10,0},{32,24,9,8,-0.1}}
  for i, t in ipairs(matas) do mata(m, t[1], t[2], t[3], t[4], hoja, i*13, 0, t[5]) end
end

-- 1b · Espino (Vachellia caven): bajo, copa plana en sombrilla, troncos torcidos, flores amarillas.
ARBOLES.arbol_1_b = function(m)
  local hoja = pal("#2A3418", "#45552A", "#66783A", "#8E9E52")
  local flor = hex("#F2C230")
  rama(m, 31, BASE, 27, 74, 3, CORTEZA_OSCURA)
  rama(m, 27, 74, 18, 58, 2, CORTEZA_OSCURA)
  rama(m, 33, BASE, 36, 76, 3, CORTEZA_OSCURA)
  rama(m, 36, 76, 46, 59, 2, CORTEZA_OSCURA)
  rama(m, 30, 80, 32, 60, 2, CORTEZA_OSCURA)
  local matas = {{14,58,10,5,0.15},{50,58,10,5,0.15},{32,58,14,5,0.1},{22,53,12,5,0},{42,53,12,5,0},{32,50,10,4,-0.1}}
  for i, t in ipairs(matas) do mata(m, t[1], t[2], t[3], t[4], hoja, i*17, 0.12, t[5]) end
  for k, col in pairs(m.c) do
    local x, y = k % W, floor(k / W)
    if m.mat[k] == hoja and hash(x, y, 5) > 0.93 then m.c[k] = flor end
  end
end

-- Cardón (Leucostele atacamensis): columna gruesa con costillas y espinas doradas.
local CARDON = pal("#26352A", "#465C44", "#62785A", "#86987A")
local ESPINA = hex("#E8D9A0")
local function columna(m, x0, y0, y1, ancho, semilla)
  for y = y0, y1 do
    local w = ancho
    if y < y0 + 2 then w = ancho - 2 end           -- punta redondeada
    local xi = x0 + floor((ancho - w)/2)
    for x = xi, xi + w - 1 do
      local rel = x - xi
      local col = ((rel % 3) == 1) and CARDON.d or CARDON.m       -- costillas
      if rel == 0 then col = CARDON.l elseif rel >= w - 2 then col = CARDON.d end
      if hash(x, y, semilla) > 0.95 then col = ESPINA end
      pon(m, x, y, col, CARDON)
    end
    if y > y0 + 1 and hash(x0, y, semilla + 1) > 0.85 then pon(m, xi - 1, y, ESPINA, CARDON) end
    if y > y0 + 1 and hash(x0, y, semilla + 2) > 0.85 then pon(m, xi + w, y, ESPINA, CARDON) end
  end
  for x = x0 + 1, x0 + ancho - 2 do pon(m, x, y0 - 1, ESPINA, CARDON) end   -- lana de la punta
end
local function brazo(m, desde_x, y_union, hasta_x, y_punta, ancho, semilla)
  local paso = (hasta_x > desde_x) and 1 or -1
  for x = desde_x, hasta_x, paso do
    for g = 0, ancho - 3 do pon(m, x, y_union + g, (g == 0) and CARDON.l or CARDON.m, CARDON) end
  end
  columna(m, hasta_x - floor(ancho/2), y_punta, y_union + ancho - 3, ancho, semilla)
end
-- 2a · Cardón adulto con brazos.
ARBOLES.arbol_2_a = function(m)
  columna(m, 27, 22, BASE, 11, 3)
  brazo(m, 27, 62, 17, 42, 8, 4)
  brazo(m, 37, 54, 46, 34, 8, 5)
end
-- 2b · Cardón joven, una sola columna.
ARBOLES.arbol_2_b = function(m)
  columna(m, 27, 46, BASE, 10, 7)
end

-- 3a · Coigüe (Nothofagus dombeyi): fuste recto y alto, follaje en pisos horizontales.
ARBOLES.arbol_3_a = function(m)
  local hoja = pal("#122618", "#1F4028", "#2E5C34", "#4C7F45")
  tronco(m, 32, 30, BASE, 4, CORTEZA_GRIS, 21, true)
  rama(m, 31, 52, 20, 46, 1, CORTEZA_GRIS)
  rama(m, 33, 40, 44, 34, 1, CORTEZA_GRIS)
  local pisos = {{24,50,14,5,0.2},{40,47,12,5,0.2},{30,40,17,6,0.1},{44,33,11,5,0},{22,30,12,5,0},{32,22,13,5,0},{34,13,8,5,-0.1}}
  for i, t in ipairs(pisos) do mata(m, t[1], t[2], t[3], t[4], hoja, i*19, 0.04, t[5]) end
end

-- 3b · Alerce (Fitzroya cupressoides): columnar y muy alto, corteza rojiza fibrosa.
ARBOLES.arbol_3_b = function(m)
  local hoja = pal("#10241E", "#1E3D33", "#2F5A48", "#4E7E62")
  local corteza = pal("#2E140C", "#5A2C1A", "#7E4228", "#A0623E")
  tronco(m, 32, 20, BASE, 5, corteza, 31, true)
  local y = 70
  local i = 0
  while y > 4 do
    i = i + 1
    local ancho = 6 + (y - 4) * 0.12
    local lado = (i % 2 == 0) and -1 or 1
    mata(m, 32 + lado*ancho*0.35, y, ancho, 5, hoja, i*23, 0.05, (y > 55) and 0.2 or 0)
    y = y - 6
  end
  mata(m, 32, 8, 4, 5, hoja, 99, 0, -0.1)
end

-- 4a · Lenga (Nothofagus pumilio) en otoño: copa ancha y escalonada, rojo-anaranjada.
ARBOLES.arbol_4_a = function(m)
  local hoja = pal("#4A1A10", "#8A2E18", "#C8501E", "#EE8A30")
  local acento = hex("#F5B942")
  tronco(m, 32, 58, BASE, 4, CORTEZA_GRIS, 41, true)
  rama(m, 31, 66, 20, 54, 2, CORTEZA_GRIS)
  rama(m, 33, 64, 45, 52, 2, CORTEZA_GRIS)
  local matas = {{18,52,11,7,0.25},{46,51,11,7,0.25},{32,52,12,7,0.2},{24,40,12,9,0.05},{42,39,12,9,0.05},{32,30,12,9,0},{30,20,8,6,-0.1}}
  for i, t in ipairs(matas) do mata(m, t[1], t[2], t[3], t[4], hoja, i*29, 0.03, t[5]) end
  for k, col in pairs(m.c) do
    if col == hoja.l and hash(k % W, floor(k / W), 9) > 0.7 then m.c[k] = acento end
  end
end

-- 4b · Ñirre (Nothofagus antarctica): bajo, de tallos torcidos, copa empujada por el viento.
ARBOLES.arbol_4_b = function(m)
  local hoja = pal("#5A2A0E", "#A0521C", "#D8862A", "#F2B84A")
  rama(m, 28, BASE, 30, 80, 3, CORTEZA_OSCURA)
  rama(m, 30, 80, 38, 64, 2, CORTEZA_OSCURA)
  rama(m, 34, BASE, 33, 84, 2, CORTEZA_OSCURA)
  rama(m, 33, 84, 46, 70, 2, CORTEZA_OSCURA)
  rama(m, 30, 82, 22, 70, 2, CORTEZA_OSCURA)
  local matas = {{24,66,8,6,0.2},{40,62,12,7,0.1},{52,66,9,6,0.2},{46,56,11,6,0},{34,56,9,6,0}}
  for i, t in ipairs(matas) do mata(m, t[1], t[2], t[3], t[4], hoja, i*31, 0.1, t[5]) end
end

-- 5a · Chonta (Juania australis): palma endémica de Juan Fernández, tronco verde anillado.
ARBOLES.arbol_5_a = function(m)
  local hoja = pal("#1A3A1E", "#2C5A2C", "#3F7E3A", "#64A050")
  local tallo = pal("#22301F", "#4A5E44", "#6A7E5E", "#8A9E78")
  tronco(m, 32, 38, BASE, 5, tallo, 51, false)
  for y = 40, BASE, 4 do for x = 30, 34 do pon(m, x, y, tallo.d, tallo) end end   -- anillos
  corona(m, 32, 34, {-3.0, -2.6, -2.2, -1.85, -1.5, -1.15, -0.8, -0.4, -0.1}, 17, 0.05, hoja, 3)
  mata(m, 32, 34, 5, 3, hoja, 57, 0, -0.1)
  for _, d in ipairs({{-3,39},{-2,40},{-1,39},{1,39},{2,40},{3,39},{-2,38},{2,38},{0,40}}) do pon(m, 32 + d[1], d[2], hex("#B8321E"), hoja) end
end

-- 5b · Helecho arborescente (Dicksonia berteroana): tronco fibroso grueso y gran corona de frondas.
ARBOLES.arbol_5_b = function(m)
  local hoja = pal("#1E3A14", "#2E5A1E", "#4A8A2E", "#7AB84A")
  local tallo = pal("#1E140C", "#3A2618", "#5A3E26", "#7A5A3A")
  tronco(m, 32, 46, BASE, 8, tallo, 61, true)
  corona(m, 32, 46, {-3.1, -2.75, -2.4, -2.05, -1.7, -1.4, -1.05, -0.7, -0.35, -0.05}, 24, 0.04, hoja, 4)
  mata(m, 32, 45, 5, 3, hoja, 67, 0, 0)
end

-- ── Generación y hoja de contactos ──────────────────────────────────────────────────────
local orden = {"arbol_1_a","arbol_1_b","arbol_2_a","arbol_2_b","arbol_3_a","arbol_3_b","arbol_4_a","arbol_4_b","arbol_5_a","arbol_5_b"}
local hoja_c = Image(#orden * (W + 8) + 8, H + 16, ColorMode.RGB)
hoja_c:clear(app.pixelColor.rgba(214, 206, 186, 255))
for i, nombre in ipairs(orden) do
  local m = nuevo()
  ARBOLES[nombre](m)
  local img = guardar(m, nombre)
  hoja_c:drawImage(img, Point(8 + (i - 1)*(W + 8), 8))
end
app.fs.makeAllDirectories(PREV)
hoja_c:resize(hoja_c.width * 3, hoja_c.height * 3)
hoja_c:saveAs(PREV .. "arboles_paisaje.png")
print("ok")
