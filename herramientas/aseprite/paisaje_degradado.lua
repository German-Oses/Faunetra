-- Paisaje degradado: árboles muertos, tocones y cardón seco para el borde del refugio antes de
-- restaurarlo (ver biomas/paisaje_vivo.gd). Misma escala de píxel y luz (arriba-izquierda) que
-- arboles_detallados.lua, de donde salen el tronco, las ramas y el contorno.
-- Uso (desde la carpeta del proyecto):
--   aseprite -b --script herramientas/aseprite/paisaje_degradado.lua
-- Genera Assets/decoracion/arbol_seco_a.png, arbol_seco_b.png, cardon_seco.png y tocon.png, y la
-- hoja herramientas/aseprite/previas/paisaje_degradado.png.

local floor, abs, sin, max, min = math.floor, math.abs, math.sin, math.max, math.min
local PROY = PROYECTO or app.fs.currentPath
local RAIZ = app.fs.joinPath(PROY, "Assets/decoracion/")
local PREV = app.fs.joinPath(PROY, "herramientas/aseprite/previas/")
local W, H, BASE = 128, 192, 191

local function hex(s) return app.pixelColor.rgba(tonumber(s:sub(2,3),16), tonumber(s:sub(4,5),16), tonumber(s:sub(6,7),16), 255) end
local function rampa(...) local r = {} for i, h in ipairs({...}) do r[i] = hex(h) end return r end
local function hash(x, y, s)
  local v = (x*374761393 + y*668265263 + s*982451653) % 2147483647
  v = (v ~ (v >> 13)) * 1274126177 % 2147483647
  return (v % 1000) / 1000
end
local function clamp(v, a, b) return max(a, min(b, v)) end

local function lienzo(w, h) W, H, BASE = w, h, h - 1 return {c = {}, mat = {}} end
local function idx(x, y) return y*W + x end
local function dentro(x, y) return x >= 0 and x < W and y >= 0 and y < H end
local function pon(m, x, y, rp, tono)
  x, y = floor(x + 0.5), floor(y + 0.5)
  if not dentro(x, y) then return end
  m.c[idx(x, y)] = rp[clamp(tono, 1, 6)]; m.mat[idx(x, y)] = rp
end
local function hay(m, x, y) return dentro(x, y) and m.c[idx(x, y)] ~= nil end

-- Madera muerta: gris blanquecina, sin corteza (el sol y el viento la "platean").
local MADERA = rampa("#1E1A18", "#3A3430", "#5A524A", "#7C7268", "#9E948A", "#C2B8AC")
-- Madera quemada, para variar algunos troncos.
local CARBON = rampa("#120E0C", "#221C18", "#362C26", "#4C4038", "#665850", "#86786C")

-- Fuste que se angosta, con raíces al pie, grietas verticales y la punta quebrada en astillas.
local function fuste(m, cx, y_top, ancho_base, ancho_top, rp, semilla, inclinacion)
  for y = y_top, BASE do
    local t = (y - y_top) / (BASE - y_top)
    local w = ancho_top + (ancho_base - ancho_top) * t
    local pie = BASE - y
    if pie < 10 then w = w + (10 - pie)^1.6 * 0.18 end
    local xc = cx + inclinacion * (1 - t) * 10
    local x0, x1 = floor(xc - w/2 + 0.5), floor(xc + w/2 - 0.5)
    for x = x0, x1 do
      local u = (x - x0) / max(1, x1 - x0)
      -- astillas: la punta quebrada es irregular, cada columna corta a otra altura
      if y - y_top < 9 and hash(x, 0, semilla + 7) * 9 > y - y_top then goto siguiente end
      local tono = 4
      if u < 0.2 then tono = 5 elseif u > 0.7 then tono = 3 end
      if u > 0.9 then tono = 2 end
      local tramo = floor(y / (4 + floor(hash(x, 0, semilla) * 6)))
      if hash(x, tramo, semilla + 1) > 0.78 then tono = tono - 2 end   -- grietas profundas
      if u < 0.2 and hash(x, y, semilla + 2) > 0.8 then tono = 6 end
      pon(m, x, y, rp, tono)
      ::siguiente::
    end
  end
end

-- Rama seca: tramos quebrados que se angostan, con una ramita lateral en cada quiebre.
local function rama_seca(m, x0, y0, ang, largo, grosor, rp, semilla, nivel)
  local x, y = x0, y0
  local tramos = 3
  for k = 1, tramos do
    local a = ang + (hash(k, nivel, semilla) - 0.5) * 0.7
    local l = largo / tramos
    local x1, y1 = x + math.cos(a) * l, y + sin(a) * l
    local n = max(abs(x1 - x), abs(y1 - y), 1)
    for i = 0, n do
      local t = i / n
      local px, py = x + (x1 - x)*t, y + (y1 - y)*t
      local g = max(1, grosor * (1 - (k - 1 + t) / tramos * 0.7))
      for d = 0, floor(g) - 1 do
        pon(m, px, py + d - floor(g/2), rp, (d == 0) and 5 or ((d >= floor(g) - 1) and 2 or 3))
      end
    end
    if nivel < 2 and hash(k, 3, semilla + nivel) > 0.35 then
      rama_seca(m, x1, y1, a + ((k % 2 == 0) and -0.9 or 0.9), largo * 0.35, max(1, grosor - 1), rp, semilla + k * 13, nivel + 1)
    end
    x, y = x1, y1
  end
end

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

local SPRITES = {}

-- Árbol muerto alto: fuste quebrado y ramas desnudas que apuntan hacia arriba.
SPRITES.arbol_seco_a = function()
  local m = lienzo(128, 192)
  rama_seca(m, 63, 120, -2.5, 46, 4, MADERA, 3, 0)
  rama_seca(m, 66, 104, -0.7, 42, 4, MADERA, 5, 0)
  rama_seca(m, 63, 84, -2.2, 30, 3, MADERA, 9, 0)
  rama_seca(m, 66, 70, -1.0, 26, 3, MADERA, 11, 0)
  -- muñón de una rama arrancada
  for i = 0, 5 do pon(m, 58 - i, 140 - i * 0.4, MADERA, (i == 0) and 3 or 4); pon(m, 58 - i, 141 - i * 0.4, MADERA, 2) end
  fuste(m, 64, 52, 14, 6, MADERA, 7, 0.15)
  return m
end

-- Árbol muerto bajo e inclinado, en parte quemado.
SPRITES.arbol_seco_b = function()
  local m = lienzo(128, 192)
  rama_seca(m, 70, 132, -0.6, 40, 3, CARBON, 21, 0)
  rama_seca(m, 72, 122, -1.9, 28, 3, CARBON, 23, 0)
  fuste(m, 62, 112, 13, 7, CARBON, 17, 0.9)
  -- la base aún muestra madera clara donde no alcanzó el fuego
  for y = 160, BASE do for x = 50, 76 do
    if hay(m, x, y) and hash(x, y, 31) > 0.55 then pon(m, x, y, MADERA, (x < 58) and 4 or 3) end
  end end
  return m
end

-- Cardón seco: la carne se pudrió y quedan las costillas leñosas (surcos oscuros, huecos por donde
-- se ve el interior), la punta quebrada y un brazo que se dobló hacia el suelo.
SPRITES.cardon_seco = function()
  local m = lienzo(128, 192)
  local rp = rampa("#241C14", "#3E3224", "#5A4A36", "#76644C", "#948064", "#B4A084")
  local function disco(cx, cy, r, semilla)
    for y = floor(cy - r), floor(cy + r) do for x = floor(cx - r), floor(cx + r) do
      local dx, dy = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
      if dx*dx + dy*dy <= 1 then
        local v = -(dx * 0.75 + dy * 0.4)
        local tono = (v > 0.4) and 4 or ((v < -0.45) and 2 or 3)   -- un tono más oscuro que la columna
        if (x + y) % 5 == 0 then tono = tono - 1 end                 -- costillas también en el brazo
        if hash(x, y, semilla) > 0.9 then tono = 1 end
        pon(m, x, y, rp, tono)
      end
    end end
  end
  -- columna principal
  local x0, ancho, y_top = 53, 22, 66
  for y = y_top, BASE do
    for x = x0, x0 + ancho - 1 do
      local u = (x - x0 + 0.5) / ancho
      local d = y - y_top
      if d < 8 and hash(x, 1, 3) * 8 > d then goto sig end           -- punta quebrada en astillas
      local tono = 4
      if u < 0.22 then tono = 5 elseif u > 0.74 then tono = 3 end
      if u > 0.9 then tono = 2 end
      if (x - x0) % 5 == 0 then tono = 2 end                          -- surcos entre costillas
      if hash(x, floor(y / 6), 7) > 0.86 then tono = 1 end            -- huecos: interior podrido
      if u < 0.22 and hash(x, y, 8) > 0.82 then tono = 6 end
      pon(m, x, y, rp, tono)
      ::sig::
    end
  end
  -- brazo doblado: sale hacia la derecha y cuelga hacia el suelo
  for i = 0, 30 do
    local t = i / 30
    local cx = 74 + t * 22
    local cy = 112 - sin(t * math.pi) * 10 + t * t * 34
    disco(cx, cy, 6.5 - t * 1.5, 11)
  end
  -- trozo caído en el suelo, a la izquierda
  for i = 0, 18 do disco(26 + i, BASE - 4 - (i % 2) * 0.3, 4.5, 13) end
  return m
end

-- Tocón de árbol talado: corte con anillos, raíces al pie.
SPRITES.tocon = function()
  local m = lienzo(48, 40)
  local corteza = rampa("#1C1612", "#362A20", "#52402E", "#6E583E", "#8A7252", "#A88E6A")
  local corte = rampa("#3A2C1E", "#6A5236", "#8E7450", "#B0946A", "#CCB088", "#E4CCA4")
  local cx, alto, r = 24, 16, 11
  for y = BASE - alto, BASE do
    local pie = BASE - y
    local w = r + ((pie < 6) and (6 - pie) * 0.9 or 0)
    for x = floor(cx - w), floor(cx + w) do
      local u = (x - (cx - w)) / (2 * w)
      local tono = (u < 0.25) and 5 or ((u > 0.72) and 3 or 4)
      if hash(x, floor(y / 3), 5) > 0.75 then tono = tono - 1 end
      pon(m, x, y, corteza, tono)
    end
  end
  -- cara superior del corte (elipse) con anillos concéntricos
  local cy = BASE - alto
  for y = cy - 6, cy + 6 do for x = cx - r, cx + r do
    local dx, dy = (x - cx) / r, (y - cy) / 5.5
    local d = math.sqrt(dx*dx + dy*dy)
    if d <= 1 then
      local tono = 4 - floor(dx + dy)                 -- luz desde arriba-izquierda
      if floor(d * 5) % 2 == 1 then tono = tono - 1 end
      if d > 0.86 then pon(m, x, y, corteza, 3) else pon(m, x, y, corte, clamp(tono, 2, 6)) end
    end
  end end
  -- grieta radial
  for i = 0, 6 do pon(m, cx + i, cy + i * 0.4, corte, 1) end
  return m
end

local orden = {"arbol_seco_a", "arbol_seco_b", "cardon_seco", "tocon"}
local hoja = Image(4 * 140 + 12, 192 + 24, ColorMode.RGB)
hoja:clear(app.pixelColor.rgba(214, 206, 186, 255))
for i, nombre in ipairs(orden) do
  local img = guardar(SPRITES[nombre](), nombre)
  hoja:drawImage(img, Point(12 + (i - 1) * 140, 12 + 192 - img.height))
end
app.fs.makeAllDirectories(PREV)
hoja:resize(hoja.width * 2, hoja.height * 2)
hoja:saveAs(PREV .. "paisaje_degradado.png")
print("ok")
