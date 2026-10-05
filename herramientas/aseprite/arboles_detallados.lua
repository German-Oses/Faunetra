-- Árboles detallados del paisaje (128x192, misma escala de píxel que las baldosas).
-- Uso (desde la carpeta del proyecto):
--   aseprite -b --script herramientas/aseprite/arboles_detallados.lua
-- Genera Assets/decoracion/arbol_<bioma>_<a|b>.png y la hoja herramientas/aseprite/previas/arboles_detallados.png.
--
-- Cómo se construye una copa (luz arriba-izquierda, sombreada como un solo volumen):
--   1. Las "masas" (elipses) definen el volumen; su interior se rellena con el tono más oscuro,
--      que es lo que se ve por los huecos del follaje.
--   2. Se dibujan las ramas que asoman por esos huecos.
--   3. Cientos de racimos de hojas, de atrás hacia adelante: cada uno toma su tono de la luz
--      global de la copa más su propio volumen, tiene borde dentado (puntas de hojas) y deja
--      una línea de oclusión sobre los racimos que tapa.
--   4. Contorno del tono más oscuro de cada material.

local floor, abs, sin, cos, pi, sqrt, max, min = math.floor, math.abs, math.sin, math.cos, math.pi, math.sqrt, math.max, math.min
local PROY = PROYECTO or app.fs.currentPath
local RAIZ = app.fs.joinPath(PROY, "Assets/decoracion/")
local PREV = app.fs.joinPath(PROY, "herramientas/aseprite/previas/")
local W, H = 128, 192
local BASE = H - 1

local function hex(s) return app.pixelColor.rgba(tonumber(s:sub(2,3),16), tonumber(s:sub(4,5),16), tonumber(s:sub(6,7),16), 255) end
-- Rampa de 6 tonos, de oscuro a claro: 1 contorno · 2 hueco · 3 sombra · 4 medio · 5 luz · 6 brillo.
local function rampa(...) local r = {} for i, h in ipairs({...}) do r[i] = hex(h) end return r end
local function hash(x, y, s)
  local v = (x*374761393 + y*668265263 + s*982451653) % 2147483647
  v = (v ~ (v >> 13)) * 1274126177 % 2147483647
  return (v % 1000) / 1000
end
local function clamp(v, a, b) return max(a, min(b, v)) end

-- Lienzo: color y material (rampa) por píxel, más un "orden" para la oclusión entre racimos.
local function nuevo() return {c = {}, mat = {}, orden = {}} end
local function idx(x, y) return y*W + x end
local function dentro(x, y) return x >= 0 and x < W and y >= 0 and y < H end
local function pon(m, x, y, rp, tono, orden)
  x, y = floor(x + 0.5), floor(y + 0.5)
  if not dentro(x, y) then return end
  local k = idx(x, y)
  m.c[k] = rp[clamp(tono, 1, 6)]; m.mat[k] = rp; m.orden[k] = orden or 0
end
local function hay(m, x, y) return dentro(x, y) and m.c[idx(x, y)] ~= nil end

-- ── Tronco y ramas ─────────────────────────────────────────────────────────────────────
-- Fuste que se angosta hacia arriba, con raíces que se abren al pie, vetas verticales y nudos.
local function tronco(m, cx, y_top, ancho_base, ancho_top, rp, semilla, inclinacion, liso)
  inclinacion = inclinacion or 0
  for y = y_top, BASE do
    local t = (y - y_top) / (BASE - y_top)
    local w = ancho_top + (ancho_base - ancho_top) * t
    local pie = BASE - y
    if pie < 10 then w = w + (10 - pie)^1.6 * 0.18 end      -- raíces
    local x_centro = cx + inclinacion * (1 - t) * 6
    local x0, x1 = floor(x_centro - w/2 + 0.5), floor(x_centro + w/2 - 0.5)
    for x = x0, x1 do
      local u = (x - x0) / max(1, x1 - x0)                   -- 0 izquierda (luz) · 1 derecha
      local tono = 4
      if u < 0.18 then tono = 5 elseif u > 0.72 then tono = 3 end
      if u > 0.9 then tono = 2 end
      -- vetas: columnas que se oscurecen a tramos irregulares
      local tramo = floor(y / (3 + floor(hash(x, 0, semilla) * 5)))
      if not liso and hash(x, tramo, semilla + 1) > 0.72 then tono = tono - 1 end
      if u < 0.18 and hash(x, y, semilla + 2) > 0.85 then tono = 6 end
      pon(m, x, y, rp, tono, -1)
    end
  end
  -- nudos
  for i = 1, (liso and 0 or 3) do
    local ny = floor(y_top + (BASE - y_top) * (0.2 + 0.25 * i) + hash(i, 1, semilla) * 6)
    local nx = floor(cx - 2 + hash(i, 2, semilla) * 4)
    pon(m, nx, ny, rp, 2, -1); pon(m, nx + 1, ny, rp, 2, -1); pon(m, nx, ny - 1, rp, 3, -1); pon(m, nx + 1, ny + 1, rp, 5, -1)
  end
end

local function rama(m, x0, y0, x1, y1, grosor0, grosor1, rp)
  local n = max(abs(x1 - x0), abs(y1 - y0), 1)
  for i = 0, n do
    local t = i / n
    local x, y = x0 + (x1 - x0)*t, y0 + (y1 - y0)*t
    local g = grosor0 + (grosor1 - grosor0) * t
    for d = 0, floor(g) do
      pon(m, x, y + d - floor(g/2), rp, (d == 0) and 5 or ((d >= floor(g)) and 2 or 3), -1)
    end
  end
end

-- ── Copa ───────────────────────────────────────────────────────────────────────────────
-- masas: {{cx, cy, rx, ry}, ...}. o: radio_min, radio_max, paso, ralo (huecos), puntas.
local function copa(m, masas, rp, semilla, o)
  local x0, y0, x1, y1 = W, H, 0, 0
  for _, s in ipairs(masas) do
    x0 = min(x0, s[1] - s[3]); x1 = max(x1, s[1] + s[3])
    y0 = min(y0, s[2] - s[4]); y1 = max(y1, s[2] + s[4])
  end
  local ccx, ccy = (x0 + x1) / 2, (y0 + y1) / 2
  local cw, ch = max(1, (x1 - x0) / 2), max(1, (y1 - y0) / 2)
  local function en_masa(x, y, holgura)
    for _, s in ipairs(masas) do
      local dx, dy = (x - s[1]) / (s[3] + holgura), (y - s[2]) / (s[4] + holgura)
      if dx*dx + dy*dy <= 1 then return true end
    end
    return false
  end
  -- 1. interior en sombra (se ve por los huecos)
  for y = floor(y0), floor(y1) do for x = floor(x0), floor(x1) do
    if en_masa(x, y, -2) and not hay(m, x, y) then pon(m, x, y, rp, 2, 0) end   -- respeta tronco y ramas
  end end
  -- 3. racimos (las ramas del paso 2 las dibuja quien llama, antes de copa)
  local racimos = {}
  local paso = o.paso or 5
  for gy = floor(y0), floor(y1), paso do
    for gx = floor(x0), floor(x1), paso do
      local jx = gx + (hash(gx, gy, semilla) - 0.5) * paso
      local jy = gy + (hash(gx, gy, semilla + 1) - 0.5) * paso
      if en_masa(jx, jy, -1) and hash(gx, gy, semilla + 2) > (o.ralo or 0.08) then
        racimos[#racimos + 1] = {x = jx, y = jy,
          r = (o.radio_min or 4) + hash(gx, gy, semilla + 3) * ((o.radio_max or 7) - (o.radio_min or 4))}
      end
    end
  end
  table.sort(racimos, function(a, b) return a.y < b.y end)   -- de atrás (arriba) hacia adelante
  for n, rc in ipairs(racimos) do
    -- luz global: arriba-izquierda de la copa, y los racimos del borde exterior reciben más luz
    local gx, gy = (rc.x - ccx) / cw, (rc.y - ccy) / ch
    local global = -(gx * 0.55 + gy * 0.95)
    for y = floor(rc.y - rc.r - 2), floor(rc.y + rc.r + 2) do
      for x = floor(rc.x - rc.r - 2), floor(rc.x + rc.r + 2) do
        local dx, dy = (x - rc.x) / rc.r, (y - rc.y) / rc.r
        local d = sqrt(dx*dx + dy*dy)
        -- borde dentado: puntas de hojas que sobresalen
        local ang = math.atan(dy, dx)
        local borde = 1 + (o.puntas or 0.22) * (hash(floor(ang * 4 + 8), n, semilla + 4) - 0.35)
        if d <= borde then
          local locl = -(dx * 0.5 + dy * 0.8)                  -- volumen propio del racimo
          local ruido = (hash(x, y, semilla + 5) - 0.5) * 0.5
          local v = global * 0.9 + locl * 0.8 + ruido
          local tono = 4
          if v > 0.95 then tono = 6 elseif v > 0.35 then tono = 5 elseif v < -0.75 then tono = 2 elseif v < -0.15 then tono = 3 end
          if d > borde - 0.22 and dy > 0.1 then tono = min(tono, 3) end   -- canto inferior en sombra
          -- oclusión: el racimo oscurece lo que tapa justo debajo de su borde inferior
          if d > borde - 0.15 and dy > 0.3 and hay(m, x, y + 1) and m.mat[idx(x, y + 1)] == rp then
            local k = idx(x, y + 1)
            if m.orden[k] > 0 and m.orden[k] < n then m.c[k] = rp[1] end
          end
          pon(m, x, y, rp, tono, n)
        end
      end
    end
  end
end

-- Contorno: cada píxel vacío junto al dibujo toma el tono más oscuro del material vecino.
local function contorno(m)
  local agregar = {}
  for y = 0, H - 1 do for x = 0, W - 1 do
    if not hay(m, x, y) then
      for _, d in ipairs({{0,1},{1,0},{-1,0},{0,-1}}) do
        if hay(m, x + d[1], y + d[2]) then agregar[idx(x, y)] = m.mat[idx(x + d[1], y + d[2])][1]; break end
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

-- ── Frondas (palmas y helechos) ────────────────────────────────────────────────────────
-- Raquis arqueado con folíolos a ambos lados, inclinados hacia la punta y algo caídos.
-- El lado de arriba de cada folíolo recibe luz y el de abajo queda en sombra; las frondas
-- `traseras` van un tono más oscuras para que la corona se lea en capas.
local function fronda(m, cx, cy, ang, largo, caida, rp, foliolo, trasera)
  local off = trasera and -1 or 0
  local px, py = cx, cy
  for k = 1, largo do
    local x = cx + cos(ang) * k
    local y = cy + sin(ang) * k * 0.8 + k * k * caida * (0.15 + abs(cos(ang)))
    local tx, ty = x - px, y - py
    local n = sqrt(tx*tx + ty*ty)
    if n > 0 then tx, ty = tx / n, ty / n end
    if k > 3 and k % 2 == 0 then
      local L = foliolo * (1 - (k / largo)^1.5 * 0.85)
      for lado = -1, 1, 2 do
        local nx, ny = -ty * lado, tx * lado
        for j = 1, floor(L + 0.5) do
          local fx = x + nx * j + tx * j * 0.35
          local fy = y + ny * j + ty * j * 0.35 + j * j * 0.05
          local tono = (ny < 0) and 5 or 3
          if j == floor(L + 0.5) then tono = 4 end
          pon(m, fx, fy, rp, tono + off, -1)
          pon(m, fx, fy + 1, rp, tono - 1 + off, -1)
        end
      end
    end
    pon(m, x, y, rp, 5 + off, -1)
    pon(m, x, y + 1, rp, 3 + off, -1)
    px, py = x, y
  end
end

-- Corona de frondas: primero las traseras (alternas, más oscuras), luego las delanteras.
local function corona(m, cx, cy, angulos, largo, caida, rp, foliolo)
  for pasada = 0, 1 do
    for j, a in ipairs(angulos) do
      if j % 2 == pasada then
        fronda(m, cx, cy, a, largo + (j % 3) * 3, caida, rp, foliolo, pasada == 0)
      end
    end
  end
end

-- ── Cactus columnares ──────────────────────────────────────────────────────────────────
-- Columna con sombreado cilíndrico, costillas (cresta clara, surco oscuro), areolas con
-- espinas cada pocos píxeles y la punta redondeada con lana.
local function columna(m, x0, y_top, y_bot, ancho, rp, espina, lana, semilla)
  local costillas = max(3, floor(ancho / 4))
  for y = y_top, y_bot do
    local w = ancho
    local d = y - y_top
    if d < ancho / 2 then w = floor(ancho * sqrt(max(0, 1 - ((ancho/2 - d) / (ancho/2))^2)) + 0.5) end
    local xi = x0 + floor((ancho - w) / 2)
    for x = xi, xi + w - 1 do
      local u = (x - x0 + 0.5) / ancho                       -- 0..1 a lo ancho
      local tono = 4
      if u < 0.2 then tono = 5 elseif u > 0.78 then tono = 3 end
      if u > 0.92 then tono = 2 end
      local fase = (u * costillas) % 1                         -- posición dentro de la costilla
      if fase < 0.2 then tono = tono - 1                       -- surco
      elseif fase > 0.45 and fase < 0.65 and u < 0.7 then tono = tono + 1 end   -- cresta
      pon(m, x, y, rp, tono, -1)
      -- areolas sobre las crestas
      if fase > 0.45 and fase < 0.65 and (y + floor(u * 13)) % 6 == 0 and d > 2 then
        pon(m, x, y, rp, 4, -1); m.c[idx(x, y)] = espina
        if hash(x, y, semilla) > 0.5 then pon(m, x + 1, y - 1, rp, 4, -1); m.c[idx(x + 1, y - 1)] = espina end
      end
    end
    -- espinas que asoman por los costados
    if d > 3 and (y % 5 == 0) then
      for _, sx in ipairs({xi - 1, xi + w}) do
        if dentro(sx, y) and not hay(m, sx, y) and hash(sx, y, semilla + 1) > 0.3 then
          pon(m, sx, y, rp, 4, -1); m.c[idx(sx, y)] = espina
        end
      end
    end
  end
  -- lana dorada en la punta
  for x = x0 + 2, x0 + ancho - 3 do
    for y = y_top - 1, y_top + 2 do
      if hash(x, y, semilla + 2) > 0.45 then pon(m, x, y, rp, 4, -1); m.c[idx(x, y)] = lana end
    end
  end
end

-- Brazo de cardón: sale del tronco, se curva en un codo y sube como columna propia.
-- El codo se dibuja con discos a lo largo de una curva, sombreados de izquierda (luz) a derecha.
local function brazo(m, x_desde, y_eje, x_hasta, y_punta, grosor, rp, espina, lana, semilla)
  local r = grosor / 2
  local y_codo = y_eje - grosor                                  -- donde termina la curva y empieza la columna
  local pasos = 24
  for i = 0, pasos do
    local t = i / pasos
    -- curva cuadrática: horizontal al salir del tronco, vertical al llegar a la columna
    local cx = (1 - t)^2 * x_desde + 2 * (1 - t) * t * x_hasta + t^2 * x_hasta
    local cy = (1 - t)^2 * y_eje + 2 * (1 - t) * t * y_eje + t^2 * y_codo
    for y = floor(cy - r), floor(cy + r) do
      for x = floor(cx - r), floor(cx + r) do
        local dx, dy = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
        if dx*dx + dy*dy <= 1 then
          local v = -(dx * 0.7 + dy * 0.5)
          local tono = (v > 0.45) and 5 or ((v < -0.45) and 3 or 4)
          if v < -0.85 then tono = 2 end
          pon(m, x, y, rp, tono, -1)
          if hash(x, y, semilla + 3) > 0.94 then m.c[idx(x, y)] = espina end   -- areolas sueltas
        end
      end
    end
  end
  columna(m, floor(x_hasta - r), y_punta, y_codo, grosor, rp, espina, lana, semilla)
end

-- ── Especies ───────────────────────────────────────────────────────────────────────────
local ARBOLES = {}

-- 3a · Coigüe (Nothofagus dombeyi): fuste alto y recto, copa irregular en pisos horizontales
-- de follaje fino y oscuro.
ARBOLES.arbol_3_a = function(m)
  local hoja = rampa("#0C1D16", "#15301F", "#1F4529", "#2C5D33", "#467A3D", "#77A04E")
  local corteza = rampa("#1C1814", "#3A322B", "#57493C", "#766452", "#94826C", "#B3A28A")
  tronco(m, 64, 24, 13, 5, corteza, 7, 0.3)
  -- ramas casi horizontales que sostienen cada piso de follaje
  rama(m, 63, 118, 30, 110, 3, 1, corteza)
  rama(m, 65, 102, 96, 96, 3, 1, corteza)
  rama(m, 63, 84, 30, 78, 3, 1, corteza)
  rama(m, 65, 64, 98, 58, 2, 1, corteza)
  rama(m, 63, 46, 38, 40, 2, 1, corteza)
  -- pisos planos y separados: el sello del coigüe
  copa(m, {
    {64, 20, 15, 7},
    {42, 38, 20, 7}, {84, 44, 18, 6},
    {66, 60, 30, 8},
    {34, 78, 22, 7}, {94, 86, 24, 7},
    {58, 100, 30, 8},
    {30, 112, 16, 6}, {92, 114, 18, 6},
  }, hoja, 31, {radio_min = 4, radio_max = 6, paso = 5, ralo = 0.1, puntas = 0.3})
end

-- 3b · Alerce (Fitzroya cupressoides): columnar y muy alto, corteza rojiza fibrosa y follaje
-- escamoso azulado en mechones pequeños.
ARBOLES.arbol_3_b = function(m)
  local hoja = rampa("#0A1C18", "#123027", "#1C4535", "#295E46", "#427A58", "#6C9A6E")
  local corteza = rampa("#240C06", "#4E1E10", "#76321C", "#9A4A2C", "#BC6A46", "#D68C66")
  tronco(m, 64, 30, 17, 8, corteza, 11, 0)
  local masas = {}
  local y, i = 150, 0
  while y > 12 do
    i = i + 1
    local ancho = 9 + (y - 12) * 0.13
    local lado = (i % 2 == 0) and -1 or 1
    masas[#masas + 1] = {64 + lado * ancho * 0.45, y, ancho, 8}
    y = y - 11
  end
  masas[#masas + 1] = {64, 12, 7, 9}
  for k = 1, #masas - 1, 2 do
    local s = masas[k]
    rama(m, 64, s[2] + 4, s[1] + (s[1] > 64 and s[3] or -s[3]) * 0.6, s[2], 2, 1, corteza)
  end
  copa(m, masas, hoja, 53, {radio_min = 3, radio_max = 5, paso = 4, ralo = 0.14, puntas = 0.35})
end


-- Salpica flores (2 px: centro y pétalo) sobre el follaje iluminado.
local function flores(m, rp, c1, c2, proporcion, semilla)
  local nuevas = {}
  for k, _ in pairs(m.c) do
    local x, y = k % W, floor(k / W)
    if m.mat[k] == rp and m.c[k] ~= rp[1] and m.c[k] ~= rp[2] and hash(x, y, semilla) < proporcion then
      nuevas[#nuevas + 1] = {x, y}
    end
  end
  for _, p in ipairs(nuevas) do
    m.c[idx(p[1], p[2])] = c1
    if hay(m, p[1] + 1, p[2]) then m.c[idx(p[1] + 1, p[2])] = c2 end
  end
end

-- 1a · Quillay (Quillaja saponaria): siempreverde de copa densa y redondeada, hojas brillantes.
ARBOLES.arbol_1_a = function(m)
  local hoja = rampa("#0F1F14", "#1B3320", "#2A4A2C", "#3E6436", "#5E8240", "#8FA85A")
  local corteza = rampa("#1E1A16", "#3C3530", "#5A5048", "#786C60", "#968A7C", "#B4A898")
  tronco(m, 64, 104, 15, 8, corteza, 3, 0.2)
  rama(m, 63, 132, 36, 104, 4, 2, corteza)
  rama(m, 65, 128, 94, 100, 4, 2, corteza)
  rama(m, 64, 116, 62, 84, 3, 2, corteza)
  copa(m, {
    {64, 48, 26, 18}, {38, 72, 24, 20}, {90, 70, 26, 20},
    {64, 90, 36, 20}, {32, 108, 20, 14}, {96, 108, 22, 14}, {62, 30, 18, 12},
  }, hoja, 13, {radio_min = 5, radio_max = 8, paso = 6, ralo = 0.06, puntas = 0.25})
end

-- 1b · Espino (Vachellia caven): bajo, troncos torcidos y copa plana en sombrilla, con
-- pompones amarillos.
ARBOLES.arbol_1_b = function(m)
  local hoja = rampa("#1C2410", "#2E3A18", "#45542A", "#5F7036", "#7E8E46", "#A6B462")
  local corteza = rampa("#140F0C", "#2A201A", "#3E3026", "#574536", "#705A46", "#8C735A")
  rama(m, 60, BASE, 54, 160, 6, 4, corteza)
  rama(m, 54, 160, 30, 126, 4, 2, corteza)
  rama(m, 66, BASE, 72, 156, 6, 4, corteza)
  rama(m, 72, 156, 98, 124, 4, 2, corteza)
  rama(m, 62, 168, 66, 120, 4, 2, corteza)
  copa(m, {
    {64, 112, 30, 9}, {36, 118, 22, 8}, {92, 118, 24, 8},
    {16, 126, 13, 6}, {112, 126, 13, 6}, {64, 102, 18, 7},
  }, hoja, 17, {radio_min = 3, radio_max = 6, paso = 5, ralo = 0.16, puntas = 0.35})
  flores(m, hoja, hex("#F2C230"), hex("#FFE27A"), 0.045, 5)
end

-- Cardón (Leucostele atacamensis): columnas gris verdosas, costillas marcadas, espinas doradas.
local CARDON = rampa("#1A2A1E", "#2C4232", "#3F5A44", "#56745A", "#719074", "#9AB496")
local ESPINA = hex("#E8D9A0")
local LANA = hex("#F0E6C8")
-- 2a · Cardón adulto con brazos.
ARBOLES.arbol_2_a = function(m)
  columna(m, 52, 40, BASE, 24, CARDON, ESPINA, LANA, 3)
  brazo(m, 52, 114, 30, 72, 16, CARDON, ESPINA, LANA, 4)
  brazo(m, 75, 96, 100, 54, 16, CARDON, ESPINA, LANA, 5)
end
-- 2b · Cardón joven, una sola columna con un brote.
ARBOLES.arbol_2_b = function(m)
  columna(m, 54, 104, BASE, 20, CARDON, ESPINA, LANA, 7)
  brazo(m, 73, 160, 84, 140, 12, CARDON, ESPINA, LANA, 8)
end

-- 4a · Lenga (Nothofagus pumilio) en otoño: copa amplia y escalonada en rojos y naranjos.
ARBOLES.arbol_4_a = function(m)
  local hoja = rampa("#3A1208", "#6A200E", "#9A3416", "#C8521E", "#E87E2C", "#F6B24A")
  local corteza = rampa("#2A2826", "#4A4644", "#6A6460", "#8A847E", "#A8A29A", "#C6C0B6")
  tronco(m, 64, 92, 15, 7, corteza, 21, -0.2)
  rama(m, 63, 124, 32, 98, 4, 2, corteza)
  rama(m, 65, 118, 96, 92, 4, 2, corteza)
  rama(m, 64, 104, 54, 66, 3, 1, corteza)
  copa(m, {
    {64, 40, 22, 14}, {40, 60, 24, 15}, {88, 58, 24, 15},
    {64, 80, 36, 16}, {28, 96, 20, 12}, {100, 96, 20, 12}, {64, 104, 26, 10},
  }, hoja, 41, {radio_min = 4, radio_max = 7, paso = 5, ralo = 0.07, puntas = 0.3})
end

-- 4b · Ñirre (Nothofagus antarctica): bajo y torcido, copa empujada por el viento patagónico.
ARBOLES.arbol_4_b = function(m)
  local hoja = rampa("#40200A", "#723A12", "#A2581C", "#CC7E28", "#E8A63A", "#F8D060")
  local corteza = rampa("#141010", "#2A2220", "#40342E", "#584A42", "#726258", "#8C7C70")
  rama(m, 58, BASE, 68, 150, 6, 3, corteza)
  rama(m, 68, 150, 88, 124, 3, 2, corteza)
  rama(m, 66, BASE, 50, 148, 5, 3, corteza)
  rama(m, 50, 148, 42, 132, 3, 2, corteza)
  rama(m, 64, 164, 80, 140, 3, 2, corteza)
  copa(m, {
    {78, 120, 26, 11}, {104, 126, 18, 9}, {48, 128, 18, 9}, {88, 108, 20, 9}, {60, 112, 16, 8},
  }, hoja, 43, {radio_min = 3, radio_max = 6, paso = 5, ralo = 0.15, puntas = 0.35})
end

-- 5a · Chonta (Juania australis): palma endémica de Juan Fernández, tronco verde anillado y
-- racimos de frutos rojos bajo la corona.
ARBOLES.arbol_5_a = function(m)
  local hoja = rampa("#0E2614", "#1A3E1E", "#28582A", "#3A7638", "#58964A", "#86B868")
  local tallo = rampa("#1A2618", "#2E3E2A", "#46583E", "#607556", "#7E9270", "#A2B292")
  tronco(m, 64, 68, 11, 9, tallo, 51, 0, true)
  for y = 72, BASE - 4, 5 do                                    -- anillos de cicatrices foliares
    for x = 59, 69 do if hay(m, x, y) then pon(m, x, y, tallo, 3, -1) end end
  end
  corona(m, 64, 64, {-3.05, -2.7, -2.35, -2.0, -1.7, -1.45, -1.15, -0.8, -0.45, -0.1}, 40, 0.012, hoja, 7)
  local fruto, fruto2 = hex("#B8321E"), hex("#E05A3A")
  for i = 1, 26 do                                               -- racimos de frutos
    local fx = 56 + floor(hash(i, 1, 9) * 16)
    local fy = 70 + floor(hash(i, 2, 9) * 10)
    pon(m, fx, fy, tallo, 2, -1); m.c[idx(fx, fy)] = (i % 3 == 0) and fruto2 or fruto
  end
end

-- 5b · Helecho arborescente (Dicksonia berteroana): tronco fibroso grueso con frondas secas
-- colgando y una gran corona de frondas.
ARBOLES.arbol_5_b = function(m)
  local hoja = rampa("#10260C", "#1C4014", "#2C5E1E", "#40802A", "#62A23A", "#94C860")
  local tallo = rampa("#160E08", "#2C1C10", "#46301C", "#62462A", "#7E5E3C", "#9C7A54")
  tronco(m, 64, 96, 19, 15, tallo, 61, 0)
  for i = 1, 9 do                                                -- frondas secas colgando (falda)
    local x = 54 + i * 2.2
    for k = 0, 14 + floor(hash(i, 1, 3) * 10) do pon(m, x + sin(k * 0.3 + i) * 1.5, 98 + k, tallo, 2 + (i % 2), -1) end
  end
  corona(m, 64, 94, {-3.12, -2.85, -2.55, -2.25, -1.95, -1.7, -1.45, -1.2, -0.9, -0.6, -0.3, -0.02}, 52, 0.01, hoja, 8)
end

-- ── Generación y hoja de contactos ──────────────────────────────────────────────────────
local orden = {"arbol_1_a", "arbol_1_b", "arbol_2_a", "arbol_2_b", "arbol_3_a", "arbol_3_b",
  "arbol_4_a", "arbol_4_b", "arbol_5_a", "arbol_5_b"}
local hoja_c = Image(#orden * (W + 12) + 12, H + 24, ColorMode.RGB)
hoja_c:clear(app.pixelColor.rgba(214, 206, 186, 255))
for i, nombre in ipairs(orden) do
  local m = nuevo()
  ARBOLES[nombre](m)
  hoja_c:drawImage(guardar(m, nombre), Point(12 + (i - 1) * (W + 12), 12))
end
app.fs.makeAllDirectories(PREV)
hoja_c:resize(hoja_c.width * 2, hoja_c.height * 2)
hoja_c:saveAs(PREV .. "arboles_detallados.png")
print("ok")
