-- Mapa de Chile del menú principal (ui/menu_mundos/menu_mundos.gd): la silueta continental
-- dividida en los cuatro biomas del juego por latitud, más un recuadro con las islas oceánicas.
-- Cada bioma se exporta como una imagen del mismo tamaño (transparente fuera de su zona), para
-- que el menú las apile, detecte el toque por su forma y las coloree según su restauración.
--   Norte Árido (2): 17,5°–29,5° S · Zona Central (1): 29,5°–37,5° S
--   Bosques Templados del Sur (3): 37,5°–44° S · Patagonia (4): 44°–56° S
--   Territorios Insulares (5): Rapa Nui y Juan Fernández, en un recuadro al oeste.
-- La silueta es una simplificación de la costa y la frontera; el ancho está exagerado ×2 para
-- que el país, que es muy angosto, se pueda tocar en un celular.
-- Uso (desde la carpeta del proyecto, o con el MCP de Aseprite: run_lua_script):
--   aseprite -b --script herramientas/aseprite/mapa_chile.lua
-- Genera Assets/UI/mapa_chile/zona_<id>.png y la previa herramientas/aseprite/previas/mapa_chile.png,
-- e imprime el ancla de cada zona (para las etiquetas del menú).

local floor, abs, max, min = math.floor, math.abs, math.max, math.min
local PROY = PROYECTO or app.fs.currentPath
local DESTINO = DESTINO_MAPA or app.fs.joinPath(PROY, "Assets/UI/mapa_chile") .. "/"
local PREV = PREVIA_MAPA or (app.fs.joinPath(PROY, "herramientas/aseprite/previas") .. "/")
local pc = app.pixelColor
local W, H = 200, 300
local LAT0, KY = 17.0, 7.4        -- y = (latitud sur - LAT0) * KY + 4
local LON0, KX = -75.9, 12.0      -- x = (longitud - LON0) * KX + X0
local X0 = 54                     -- espacio a la izquierda para el recuadro insular

local function hex(s, a) return pc.rgba(tonumber(s:sub(2,3),16), tonumber(s:sub(4,5),16), tonumber(s:sub(6,7),16), a or 255) end
local function hash(x, y, s)
  local v = (x*374761393 + y*668265263 + s*982451653) % 2147483647
  v = (v ~ (v >> 13)) * 1274126177 % 2147483647
  return (v % 1000) / 1000
end
local function proyectar(lat, lon) return X0 + (lon - LON0) * KX, (lat - LAT0) * KY + 4 end
local function latitud(y) return (y - 4) / KY + LAT0 end

-- Contorno simplificado (latitud sur, longitud): costa de norte a sur, Tierra del Fuego y
-- frontera oriental de sur a norte.
local CONTORNO = {
  {18.35,-70.38},{19.6,-70.2},{20.2,-70.15},{21.4,-70.06},{22.1,-70.2},{23.1,-70.45},{23.65,-70.42},
  {24.6,-70.55},{25.4,-70.5},{26.3,-70.65},{27.07,-70.85},{28.0,-71.15},{28.47,-71.25},{29.3,-71.35},
  {29.9,-71.35},{30.6,-71.7},{31.6,-71.6},{32.4,-71.45},{33.0,-71.65},{33.6,-71.65},{34.4,-72.0},
  {35.3,-72.4},{36.0,-72.75},{36.8,-73.15},{37.2,-73.6},{37.6,-73.65},{38.4,-73.5},{39.4,-73.25},
  {39.8,-73.4},{40.6,-73.75},{41.4,-73.85},{41.8,-74.05},{42.6,-74.2},{43.4,-74.35},{44.0,-74.5},
  {44.6,-74.75},{45.4,-74.6},{45.9,-75.1},{46.6,-75.6},{47.2,-75.3},{48.0,-75.5},{48.8,-75.6},
  {49.6,-75.5},{50.4,-75.4},{51.2,-75.2},{52.0,-74.9},{52.6,-74.6},{53.2,-74.0},{53.8,-73.2},
  {54.3,-72.2},{54.8,-71.0},{55.2,-69.6},{55.6,-68.3},{55.98,-67.3},{55.4,-66.6},{54.9,-67.0},
  {54.9,-68.6},{53.6,-68.6},{52.65,-68.6},{52.35,-69.4},{52.15,-70.5},{52.0,-71.9},{51.4,-72.4},
  {50.7,-73.1},{50.0,-73.4},{49.2,-72.9},{48.6,-72.4},{47.6,-72.2},{46.8,-71.9},{46.0,-71.6},
  {45.0,-71.6},{44.0,-71.8},{43.0,-71.75},{42.0,-71.8},{41.0,-71.9},{40.0,-71.6},{39.0,-71.3},
  {38.0,-71.1},{37.0,-71.0},{36.0,-70.6},{35.0,-70.45},{34.0,-70.2},{33.0,-70.0},{32.0,-70.2},
  {31.0,-70.4},{30.0,-70.0},{29.0,-69.8},{28.0,-69.1},{27.0,-68.7},{26.0,-68.5},{25.0,-68.4},
  {24.0,-67.7},{23.0,-67.2},{22.3,-67.9},{21.5,-68.2},{20.6,-68.5},{20.0,-68.6},{19.2,-68.9},
  {18.4,-69.2},{17.5,-69.5},{17.8,-69.9},
}
local POLIGONO = {}
for _, p in ipairs(CONTORNO) do local x, y = proyectar(p[1], p[2]); POLIGONO[#POLIGONO + 1] = {x, y} end

local function dentro(pol, x, y)
  local c, j = false, #pol
  for i = 1, #pol do
    local xi, yi, xj, yj = pol[i][1], pol[i][2], pol[j][1], pol[j][2]
    if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then c = not c end
    j = i
  end
  return c
end

-- Bioma de una fila según su latitud.
local function zona_de(y)
  local lat = latitud(y + 0.5)
  if lat < 29.5 then return 2 elseif lat < 37.5 then return 1 elseif lat < 44.0 then return 3 end
  return 4
end

-- Paleta por bioma: suelo claro/medio/oscuro, cordillera, nieve y separador.
local PALETA = {
  [2] = {l = "#E6C27E", m = "#D2A45E", d = "#B5854A", cord = "#A8826A", nieve = "#F2EEE6", salar = "#F0EBDD"},
  [1] = {l = "#C4BE72", m = "#A9A35A", d = "#878645", cord = "#9A8E78", nieve = "#F2F2EE"},
  [3] = {l = "#6FA85E", m = "#4F8A48", d = "#3A6E3A", cord = "#7E8A82", nieve = "#F2F6F4"},
  [4] = {l = "#A9BFA4", m = "#8CA68A", d = "#6E8A70", cord = "#9AA6AE", nieve = "#F4F8FA", hielo = "#DCEEF4"},
}
local CONTORNO_COLOR = hex("#2E3A30")

-- Canales que separan la tierra (latitud, longitud): Estrecho de Magallanes (aísla Tierra del
-- Fuego), canal de Chacao y golfo de Ancud (Chiloé) y algunos canales patagónicos.
local CANALES = {
  {{52.55,-68.4},{52.6,-69.4},{52.75,-70.2},{53.2,-70.85},{53.75,-71.2},{53.7,-72.2},{53.25,-73.0},{52.85,-73.7},{52.6,-74.7}},
  {{41.75,-73.95},{41.85,-73.4},{42.4,-73.25},{43.1,-73.4},{43.5,-73.9}},
  {{44.6,-74.9},{45.0,-74.1},{45.4,-73.6}},
  {{46.9,-75.7},{47.3,-74.6},{47.7,-74.2}},
  {{48.6,-75.7},{49.0,-74.7},{49.3,-74.2}},
  {{50.2,-75.6},{50.5,-74.6},{50.8,-74.1}},
  {{51.6,-75.3},{51.9,-74.4},{52.2,-73.6}},
  {{54.3,-71.6},{54.6,-70.4},{54.9,-69.4}},
}
local agua = {}
for _, canal in ipairs(CANALES) do
  for i = 1, #canal - 1 do
    local x0, y0 = proyectar(canal[i][1], canal[i][2])
    local x1, y1 = proyectar(canal[i + 1][1], canal[i + 1][2])
    local n = max(abs(x1 - x0), abs(y1 - y0), 1) * 2
    for k = 0, n do
      local x, y = floor(x0 + (x1 - x0) * k / n), floor(y0 + (y1 - y0) * k / n)
      agua[y * W + x] = true
      if i == 1 or canal == CANALES[1] then agua[y * W + x + 1] = true end
    end
  end
end

-- Máscara de tierra y zona por píxel.
local tierra, zona = {}, {}
for y = 0, H - 1 do for x = 0, W - 1 do
  if dentro(POLIGONO, x + 0.5, y + 0.5) and not agua[y * W + x] then
    tierra[y * W + x] = true
    zona[y * W + x] = zona_de(y)
  end
end end
local function es_tierra(x, y) return x >= 0 and y >= 0 and x < W and y < H and tierra[y * W + x] end

-- Borde oriental de cada fila (para dibujar la cordillera de los Andes).
local este = {}
for y = 0, H - 1 do for x = W - 1, 0, -1 do if es_tierra(x, y) then este[y] = x; break end end end

local imagenes, anclas = {}, {}
for _, id in ipairs({1, 2, 3, 4, 5}) do
  local img = Image(W, H, ColorMode.RGB)
  img:clear(pc.rgba(0, 0, 0, 0))
  imagenes[id] = img
  anclas[id] = {sx = 0, sy = 0, n = 0, este = 0}
end

for y = 0, H - 1 do for x = 0, W - 1 do
  if es_tierra(x, y) then
    local id = zona[y * W + x]
    local p = PALETA[id]
    local h = hash(x, y, id)
    local col = p.m
    -- luz arriba-izquierda: la costa (oeste) más clara, el interior medio, cerca de la cordillera más oscuro
    -- la cordillera corre por el borde oriental del continente (al sur de 52° el borde es Tierra del Fuego)
    local hacia_este = (este[y] and latitud(y) < 52.0) and (este[y] - x) or 99
    if h < 0.18 then col = p.l elseif h > 0.86 then col = p.d end
    if hacia_este <= 3 then
      col = p.cord
      if (hacia_este <= 1 and hash(x, y, 7) < 0.55) then col = p.nieve end
    elseif hacia_este <= 5 and h < 0.5 then
      col = p.d
    end
    if p.salar and hacia_este >= 4 and hacia_este <= 9 and hash(floor(x / 3), floor(y / 3), 11) < 0.18 then col = p.salar end
    if p.hielo and hacia_este >= 3 and hacia_este <= 8 and latitud(y) > 47.5 and latitud(y) < 51.5 and hash(x, y, 13) < 0.7 then col = p.hielo end
    local c = hex(col)
    -- contorno exterior y separación entre biomas
    local borde = not (es_tierra(x - 1, y) and es_tierra(x + 1, y) and es_tierra(x, y - 1) and es_tierra(x, y + 1))
    if borde then c = CONTORNO_COLOR
    elseif es_tierra(x, y - 1) and zona[(y - 1) * W + x] ~= id then c = hex(p.d) end
    imagenes[id]:drawPixel(x, y, c)
    local a = anclas[id]
    a.sx, a.sy, a.n = a.sx + x, a.sy + y, a.n + 1
  end
end end

-- Recuadro insular: océano claro, borde punteado, Rapa Nui (triángulo) y Juan Fernández.
do
  local img = imagenes[5]
  local x0, y0, x1, y1 = 3, 70, 49, 150
  for y = y0, y1 do for x = x0, x1 do
    local borde = x == x0 or x == x1 or y == y0 or y == y1
    if borde then
      if (x + y) % 4 < 2 then img:drawPixel(x, y, hex("#F4F1E4")) else img:drawPixel(x, y, hex("#2E5A6E")) end
    else
      img:drawPixel(x, y, hex("#5FA8C4", 150))
    end
  end end
  local function isla(cx, cy, puntos, color_l, color_m)
    for _, p in ipairs(puntos) do
      local x, y = cx + p[1], cy + p[2]
      img:drawPixel(x, y, (p[1] + p[2] < 0) and hex(color_l) or hex(color_m))
    end
  end
  -- Rapa Nui: triángulo con sus tres volcanes y un moái
  local rapa = {}
  for dy = -5, 5 do for dx = -7, 7 do
    if dy >= -5 + abs(dx) * 0.7 and dy <= 4 then rapa[#rapa + 1] = {dx, dy} end
  end end
  isla(18, 92, rapa, "#8CC06A", "#5E9A4E")
  for _, p in ipairs({{11, 96}, {25, 96}, {18, 87}}) do img:drawPixel(p[1], p[2], hex("#6E5A44")) end
  img:drawPixel(20, 92, hex("#4A4440")); img:drawPixel(20, 93, hex("#4A4440"))
  -- Archipiélago Juan Fernández: Robinson Crusoe y Alejandro Selkirk
  local rc, sk = {}, {}
  for dy = -3, 3 do for dx = -6, 6 do if (dx / 6) ^ 2 + (dy / 3) ^ 2 <= 1 then rc[#rc + 1] = {dx, dy} end end end
  for dy = -2, 2 do for dx = -3, 3 do if (dx / 3) ^ 2 + (dy / 2) ^ 2 <= 1 then sk[#sk + 1] = {dx, dy} end end end
  isla(34, 128, rc, "#7EB866", "#4E8A48")
  isla(14, 132, sk, "#7EB866", "#4E8A48")
  for _, p in ipairs({{34, 127}, {33, 128}}) do img:drawPixel(p[1], p[2], hex("#6E7A5E")) end
  anclas[5] = {sx = 26, sy = 110, n = 1, este = x1}
end

-- Contorno oscuro alrededor de las islas del recuadro
for _, id in ipairs({5}) do
  local img = imagenes[id]
  local copia = img:clone()
  for y = 71, 149 do for x = 4, 48 do
    local c = copia:getPixel(x, y)
    if pc.rgbaA(c) == 255 and pc.rgbaR(c) < 200 then
      for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        local n = copia:getPixel(x + d[1], y + d[2])
        if pc.rgbaA(n) < 255 then img:drawPixel(x, y, CONTORNO_COLOR); break end
      end
    end
  end end
end

app.fs.makeAllDirectories(DESTINO)
app.fs.makeAllDirectories(PREV)
local hoja = Image(W * 3, H * 3, ColorMode.RGB)
hoja:clear(pc.rgba(110, 180, 205, 255))
local lineas = {}
for _, id in ipairs({1, 2, 3, 4, 5}) do
  imagenes[id]:saveAs(DESTINO .. "zona_" .. id .. ".png")
  for y = 0, H - 1 do for x = 0, W - 1 do
    local c = imagenes[id]:getPixel(x, y)
    if pc.rgbaA(c) > 0 then for dy = 0, 2 do for dx = 0, 2 do hoja:drawPixel(x * 3 + dx, y * 3 + dy, c) end end end
  end end
  local a = anclas[id]
  local cx, cy = floor(a.sx / a.n), floor(a.sy / a.n)
  local ex = (id == 5) and a.este or (este[cy] or cx)
  lineas[#lineas + 1] = string.format("%d: Vector2(%d, %d)", id, ex, cy)
end
hoja:saveAs(PREV .. "mapa_chile.png")
print("ANCLAS {" .. table.concat(lineas, ", ") .. "}")
