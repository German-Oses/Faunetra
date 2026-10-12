-- Estados de la caseta del guardaparque según la salud del refugio (ver biomas/paisaje_vivo.gd):
-- abandonada → en reparación → restaurada. Se derivan de Assets/decoracion/caseta.png (que no se
-- modifica), así que si cambia la caseta basta con volver a ejecutar el script.
-- Uso (desde la carpeta del proyecto):
--   aseprite -b --script herramientas/aseprite/caseta_estados.lua
-- Genera Assets/decoracion/caseta_abandonada.png, caseta_reparacion.png, caseta_restaurada.png y la
-- hoja herramientas/aseprite/previas/caseta_estados.png.
--
-- Zonas de caseta.png (64x64): techo verde (cara izquierda en luz, derecha en sombra) en y 5-39,
-- chimenea x 41-44 / y 7-15, pared izquierda clara con la puerta (x 20-27, y 33-48) y pared derecha
-- con la ventana (x 37-46, y 34-41).

local floor, abs, sqrt, max, min = math.floor, math.abs, math.sqrt, math.max, math.min
local PROY = PROYECTO or app.fs.currentPath
local RAIZ = app.fs.joinPath(PROY, "Assets/decoracion/")
local PREV = app.fs.joinPath(PROY, "herramientas/aseprite/previas/")
local pc = app.pixelColor

local function hex(s) return pc.rgba(tonumber(s:sub(2,3),16), tonumber(s:sub(4,5),16), tonumber(s:sub(6,7),16), 255) end
local function clave(c) return string.format("#%02x%02x%02x", pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c)) end
local function hash(x, y, s)
  local v = (x*374761393 + y*668265263 + s*982451653) % 2147483647
  v = (v ~ (v >> 13)) * 1274126177 % 2147483647
  return (v % 1000) / 1000
end

local CONTORNO = "#2e2418"
local TECHO = {["#5e9a5a"] = 1, ["#2a5a32"] = 2, ["#3e7a44"] = 3}   -- luz, sombra, junta
local MADERA = {["#c89a62"] = 1, ["#a8783e"] = 2, ["#7a5428"] = 3}  -- clara, media, oscura (puerta)
local VIDRIO = "#9ad4ea"

local function base()
  return Image{fromFile = RAIZ .. "caseta.png"}
end
local function en(img, x, y) return x >= 0 and y >= 0 and x < img.width and y < img.height end
local function color(img, x, y) return clave(img:getPixel(x, y)) end
local function opaco(img, x, y) return en(img, x, y) and pc.rgbaA(img:getPixel(x, y)) > 0 end
local function pon(img, x, y, h) if en(img, x, y) then img:drawPixel(x, y, hex(h)) end end

-- Recolorea con un mapa {color original -> color nuevo}.
local function recolorear(img, mapa)
  for y = 0, img.height - 1 do for x = 0, img.width - 1 do
    if opaco(img, x, y) then
      local n = mapa[color(img, x, y)]
      if n then pon(img, x, y, n) end
    end
  end end
end

-- Agujero irregular en el techo: interior oscuro, una viga cruzada y tejas rotas alrededor.
local function agujero(img, cx, cy, r, semilla)
  for y = cy - r - 1, cy + r + 1 do for x = cx - r - 2, cx + r + 2 do
    if opaco(img, x, y) and TECHO_SECO[color(img, x, y)] then
      local dx, dy = (x - cx) / (r + 0.5), (y - cy) / (r * 0.7 + 0.5)
      local d = sqrt(dx*dx + dy*dy) + (hash(x, y, semilla) - 0.5) * 0.5
      if d < 0.8 then
        pon(img, x, y, (abs((x - cx) - (y - cy) * 1.6) < 1) and "#5a4630" or "#1a130e")
      elseif d < 1.15 then
        pon(img, x, y, "#3a3020")
      end
    end
  end end
end

-- Cada estado parte de la caseta original.
local ESTADOS = {}

-- Abandonada: madera gris y podrida, techo cubierto de musgo seco y con agujeros, puerta caída,
-- ventana tapiada en cruz, chimenea desmoronada y maleza al pie.
TECHO_SECO = {}
ESTADOS.caseta_abandonada = function()
  local img = base()
  local techo = {["#5e9a5a"] = "#7a7a58", ["#2a5a32"] = "#4a4a36", ["#3e7a44"] = "#5c5a42"}
  for k, v in pairs(techo) do TECHO_SECO[v] = true end
  recolorear(img, techo)
  recolorear(img, {["#c89a62"] = "#9a8c78", ["#a8783e"] = "#7a6c58", ["#7a5428"] = "#4e4236",
    ["#8a8a92"] = "#6e6a66", ["#6e6e78"] = "#56524e"})
  agujero(img, 24, 25, 3, 1)
  agujero(img, 45, 23, 2, 2)
  agujero(img, 34, 15, 2, 3)
  -- tablas sueltas: huecos oscuros en la pared izquierda
  for _, t in ipairs({{13, 42, 5}, {30, 37, 4}, {14, 50, 3}}) do
    for i = 0, t[3] - 1 do if opaco(img, t[1] + i, t[2]) then pon(img, t[1] + i, t[2], "#2a221a") end end
  end
  -- puerta caída: el vano queda negro y la hoja se apoya inclinada al lado
  for y = 33, 48 do for x = 18, 27 do
    if opaco(img, x, y) and color(img, x, y) == "#4e4236" then pon(img, x, y, "#120e0a") end
  end end
  for i = 0, 11 do pon(img, 28 + floor(i / 4), 50 - i, "#4e4236"); pon(img, 29 + floor(i / 4), 50 - i, "#3a3028") end
  -- ventana tapiada: el vidrio se oscurece y dos tablas en cruz
  recolorear(img, {[VIDRIO] = "#2a2a2e"})
  for i = 0, 8 do pon(img, 37 + i, 34 + i * 0.8, "#8a7c66"); pon(img, 45 - i, 34 + i * 0.8, "#6e6250") end
  -- chimenea desmoronada: se pierden las filas de arriba
  for y = 6, 10 do for x = 40, 45 do if opaco(img, x, y) then img:drawPixel(x, y, pc.rgba(0, 0, 0, 0)) end end end
  pon(img, 41, 11, CONTORNO); pon(img, 44, 11, CONTORNO); pon(img, 42, 11, "#56524e")
  -- maleza seca al pie de las paredes
  for x = 11, 52 do
    if hash(x, 7, 9) > 0.55 then
      local y = 0
      for yy = 63, 0, -1 do if opaco(img, x, yy) then y = yy; break end end
      if y > 40 then pon(img, x, y, "#8a7a3a"); if hash(x, 8, 9) > 0.5 then pon(img, x, y - 1, "#a8964a") end end
    end
  end
  return img
end

-- En reparación: madera original con tablas nuevas más claras, una lona azul sobre el agujero
-- grande del techo, la puerta puesta y una escalera apoyada en la pared derecha.
ESTADOS.caseta_reparacion = function()
  local img = base()
  TECHO_SECO = {["#5e9a5a"] = true, ["#2a5a32"] = true, ["#3e7a44"] = true}
  agujero(img, 34, 15, 2, 3)
  -- lona sobre la cara izquierda del techo, amarrada en las esquinas
  local lona = {["#5e9a5a"] = "#5a8cc0", ["#3e7a44"] = "#3e6a9a", ["#2a5a32"] = "#34587e"}
  for y = 19, 30 do for x = 16, 31 do
    local dentro = abs(x - 23.5) / 8 + abs(y - 24.5) / 6 < 1
    if dentro and opaco(img, x, y) then
      local n = lona[color(img, x, y)]
      if n then pon(img, x, y, ((x + y) % 7 == 0) and "#7aaad8" or n) end
    end
  end end
  for _, p in ipairs({{17, 24}, {23, 19}, {30, 25}, {24, 30}}) do pon(img, p[1], p[2], "#e8e0c8") end
  -- tablas nuevas
  for _, t in ipairs({{13, 42, 6}, {12, 47, 5}, {28, 40, 5}}) do
    for i = 0, t[3] - 1 do if opaco(img, t[1] + i, t[2]) and MADERA[color(img, t[1] + i, t[2])] then pon(img, t[1] + i, t[2], "#e6c08a") end end
  end
  -- escalera apoyada en la pared derecha
  for y = 30, 53 do
    local d = floor((y - 30) / 6)
    pon(img, 47 + d, y, "#d8b070"); pon(img, 51 + d, y, "#d8b070")
    pon(img, 48 + d, y, "#8a6a3a"); pon(img, 52 + d, y, "#8a6a3a")
    if (y - 30) % 4 == 2 then for x = 48 + d, 50 + d do pon(img, x, y, "#c8a060") end end
  end
  -- balde de pintura y tablas apiladas al pie
  for x = 7, 11 do for y = 50, 53 do pon(img, x, y, (x == 7) and "#5a6a74" or "#8aa0aa") end end
  pon(img, 8, 49, "#2e2418"); pon(img, 9, 49, "#e8e0c8"); pon(img, 10, 49, "#2e2418")
  return img
end

-- Restaurada: la caseta original con una jardinera florida bajo la ventana y un farol en la puerta.
-- (El humo de la chimenea lo agrega el juego, animado.)
ESTADOS.caseta_restaurada = function()
  local img = base()
  for x = 37, 47 do
    local y = 42 + floor((x - 37) * 0.45)
    pon(img, x, y, "#7a5428"); pon(img, x, y + 1, "#5a3c1c")
    local f = hash(x, 1, 4)
    if x % 2 == 1 then pon(img, x, y - 1, (f < 0.33) and "#e05a5a" or ((f < 0.66) and "#f2c84a" or "#f4f0e8")) else pon(img, x, y - 1, "#4e8a40") end
  end
  -- farol junto a la puerta
  pon(img, 28, 33, CONTORNO); pon(img, 28, 34, "#f6d870"); pon(img, 28, 35, "#e8a83a"); pon(img, 28, 36, CONTORNO)
  return img
end

local orden = {"caseta_abandonada", "caseta_reparacion", "caseta_restaurada"}
local hoja = Image(3 * 72 + 8, 72, ColorMode.RGB)
hoja:clear(pc.rgba(214, 206, 186, 255))
for i, nombre in ipairs(orden) do
  local img = ESTADOS[nombre]()
  img:saveAs(RAIZ .. nombre .. ".png")
  hoja:drawImage(img, Point(8 + (i - 1) * 72, 4))
end
app.fs.makeAllDirectories(PREV)
hoja:resize(hoja.width * 6, hoja.height * 6)
hoja:saveAs(PREV .. "caseta_estados.png")
print("ok")
