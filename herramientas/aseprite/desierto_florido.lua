-- Parches de flores del Desierto Florido (Norte Árido), para PaisajeVivo: aparecen sobre la arena
-- cuando el bioma está casi restaurado. Cada parche es un manchón plano de 40x22 que se apoya sobre
-- una parcela isométrica, a la misma escala de píxel que las baldosas. Luz arriba-izquierda.
-- Especies reales del fenómeno (costa y llanos de la Región de Atacama):
--   pata de guanaco (Cistanthe longiscapa): el manto fucsia más típico.
--   añañuca (Rhodophiala): roja y amarilla, flor de trompeta sobre un tallo.
--   suspiro (Nolana): celeste a lila con la garganta clara.
--   garra de león (Leontochir ovallei): racimos rojo anaranjado, endémica y escasa.
--   malvilla (Cristaria): lila, flores pequeñas.
-- Uso (desde la carpeta del proyecto, o con el MCP de Aseprite: run_lua_script):
--   aseprite -b --script herramientas/aseprite/desierto_florido.lua
-- Genera Assets/decoracion/flores_<especie>_a.png y _b.png, y la previa
-- herramientas/aseprite/previas/desierto_florido.png.

local floor, abs, max, min = math.floor, math.abs, math.max, math.min
local PROY = PROYECTO or app.fs.currentPath
local DESTINO = DESTINO_FLORES or app.fs.joinPath(PROY, "Assets/decoracion/")
local PREV = PREVIA_FLORES or app.fs.joinPath(PROY, "herramientas/aseprite/previas/")
local pc = app.pixelColor
local W, H = 40, 22

local function hex(s) return pc.rgba(tonumber(s:sub(2,3),16), tonumber(s:sub(4,5),16), tonumber(s:sub(6,7),16), 255) end
local function hash(x, y, s)
  local v = (x*374761393 + y*668265263 + s*982451653) % 2147483647
  v = (v ~ (v >> 13)) * 1274126177 % 2147483647
  return (v % 1000) / 1000
end

-- Hojas: verde grisáceo de planta de desierto (rosetas bajas y carnosas).
local HOJA = { l = hex("#A2B45A"), m = hex("#6E8A3E"), d = hex("#44602E") }

local ESPECIES = {
  pata_de_guanaco = { forma = "copa",     l = "#F58CC8", m = "#D8399C", d = "#9A1E72", centro = "#F2D04A" },
  ananuca_roja    = { forma = "trompeta", l = "#F2765A", m = "#D23A2E", d = "#8E1E2A", centro = "#F2D04A" },
  ananuca_amarilla= { forma = "trompeta", l = "#FBE07A", m = "#E8B32E", d = "#B07A1E", centro = "#F6EFC4" },
  suspiro         = { forma = "campana",  l = "#C6DCF4", m = "#8CA8E0", d = "#5E6AB8", centro = "#F6EFC4" },
  garra_de_leon   = { forma = "racimo",   l = "#F6A04A", m = "#E2602A", d = "#A43620", centro = "#F2D04A" },
  malvilla        = { forma = "estrella", l = "#D8B6EE", m = "#B286D6", d = "#7A58A8", centro = "#F2E2A0" },
}

local function put(img, x, y, c)
  if c and x >= 0 and y >= 0 and x < W and y < H then img:drawPixel(x, y, c) end
end

-- Roseta de hojas al pie de cada flor.
local function hojas(img, x, y, s)
  put(img, x-1, y, HOJA.m) put(img, x+1, y, HOJA.d) put(img, x, y, HOJA.d)
  if hash(x, y, s) < 0.6 then put(img, x-2, y, HOJA.l) end
  if hash(y, x, s) < 0.5 then put(img, x+2, y, HOJA.m) end
  put(img, x, y-1, HOJA.m)
end

local DIBUJAR = {
  copa = function(img, x, y, p)   -- 5 pétalos abiertos, centro amarillo
    hojas(img, x, y+2, 1)
    put(img, x, y-1, p.l) put(img, x-1, y, p.l) put(img, x+1, y, p.m) put(img, x, y+1, p.d) put(img, x-1, y+1, p.m) put(img, x+1, y-1, p.m)
    put(img, x, y, p.centro)
  end,
  trompeta = function(img, x, y, p)   -- tallo y flor de trompeta inclinada
    hojas(img, x, y+3, 2)
    put(img, x, y+2, HOJA.m) put(img, x, y+1, HOJA.d)
    put(img, x-1, y-1, p.l) put(img, x, y-1, p.m) put(img, x+1, y-1, p.m)
    put(img, x-1, y, p.m) put(img, x, y, p.d) put(img, x+1, y, p.centro)
  end,
  campana = function(img, x, y, p)   -- flor redonda con garganta clara
    hojas(img, x, y+2, 3)
    put(img, x, y-1, p.l) put(img, x-1, y, p.l) put(img, x+1, y, p.m) put(img, x, y+1, p.d)
    put(img, x-1, y-1, p.m) put(img, x+1, y+1, p.d) put(img, x, y, p.centro)
  end,
  racimo = function(img, x, y, p)   -- espiga de flores alternadas
    hojas(img, x, y+3, 4)
    for k = -2, 2 do put(img, x, y+k, (k % 2 == 0) and p.m or HOJA.d) end
    put(img, x-1, y-2, p.l) put(img, x+1, y-1, p.m) put(img, x-1, y, p.m) put(img, x+1, y+1, p.d) put(img, x, y-3, p.l)
  end,
  estrella = function(img, x, y, p)   -- flores pequeñas en grupo
    hojas(img, x, y+2, 5)
    put(img, x, y, p.centro) put(img, x-1, y, p.l) put(img, x+1, y, p.m) put(img, x, y-1, p.l) put(img, x, y+1, p.d)
    put(img, x+2, y+1, p.m) put(img, x-2, y+1, p.d)
  end,
}

-- Puntos dentro de una elipse plana (la parcela vista en isométrico), ordenados de atrás hacia
-- adelante para que las flores de abajo tapen a las de arriba.
local function puntos(semilla, densidad)
  local lista = {}
  for gy = 3, H - 4, 3 do
    for gx = 3, W - 4, 4 do
      local jx = floor(hash(gx, gy, semilla) * 3) - 1
      local jy = floor(hash(gy, gx, semilla + 7) * 2)
      local x, y = gx + jx + ((gy % 6 == 0) and 2 or 0), gy + jy
      local dx, dy = (x - W/2) / (W/2 - 2), (y - H/2) / (H/2 - 2)
      if dx*dx + dy*dy <= 1.0 and hash(x, y, semilla + 13) < densidad then
        lista[#lista+1] = {x, y}
      end
    end
  end
  table.sort(lista, function(a, b) return a[2] < b[2] end)
  return lista
end

app.fs.makeAllDirectories(DESTINO)
app.fs.makeAllDirectories(PREV)
local nombres = {}
for n in pairs(ESPECIES) do nombres[#nombres+1] = n end
table.sort(nombres)
local hoja = Image((W + 4) * 2 * 4, (H + 4) * #nombres * 4, ColorMode.RGB)
hoja:clear(pc.rgba(214, 196, 160, 255))   -- arena del Norte Árido
for i, n in ipairs(nombres) do
  local e = ESPECIES[n]
  local p = { l = hex(e.l), m = hex(e.m), d = hex(e.d), centro = hex(e.centro) }
  for v, variante in ipairs({{"a", 0.75}, {"b", 0.5}}) do
    local img = Image(W, H, ColorMode.RGB)
    img:clear(pc.rgba(0, 0, 0, 0))
    for _, q in ipairs(puntos(i * 31 + v * 7, variante[2])) do DIBUJAR[e.forma](img, q[1], q[2], p) end
    img:saveAs(DESTINO .. "flores_" .. n .. "_" .. variante[1] .. ".png")
    for y = 0, H - 1 do for x = 0, W - 1 do
      local c = img:getPixel(x, y)
      if pc.rgbaA(c) > 0 then
        for dy = 0, 3 do for dx = 0, 3 do
          hoja:drawPixel(((v - 1) * (W + 4) + 2 + x) * 4 + dx, ((i - 1) * (H + 4) + 2 + y) * 4 + dy, c)
        end end
      end
    end end
  end
end
hoja:saveAs(PREV .. "desierto_florido.png")
print("ok", #nombres * 2)
