-- Etapas de crecimiento de cada planta (ver entities/especies/especie.gd):
--   brote (recién plantada), plántula y joven. La adulta es el sprite de la especie.
-- La joven es la especie reducida al ESCALA_JOVEN, redibujada a la misma densidad de píxel que el
-- resto del arte: cada píxel toma el color más repetido de su zona del original y se rehace el
-- contorno, así no queda como el adulto achicado con píxeles más finos.
-- Cada especie se dibuja según su forma de crecimiento (árbol, palmera, arbusto, hierba, helecho,
-- cactus, hongo o líquen) con los colores tomados de su propio sprite, para que el jugador la
-- reconozca desde chica. 32x32, base en la fila 31, luz arriba-izquierda, como lib_faunetra.lua.
-- Uso (desde la carpeta del proyecto):
--   aseprite -b --script herramientas/aseprite/plantas_etapas.lua
-- Genera Assets/Plantas/etapas/<especie>_brote.png, _plantula.png y _joven.png, y la hoja
-- herramientas/aseprite/previas/plantas_etapas.png.

local floor, abs, sin, cos, pi, sqrt, max, min = math.floor, math.abs, math.sin, math.cos, math.pi, math.sqrt, math.max, math.min
local PROY = PROYECTO or app.fs.currentPath
local ORIGEN = app.fs.joinPath(PROY, "Assets/Plantas/")
local DESTINO = app.fs.joinPath(PROY, "Assets/Plantas/etapas/")
local PREV = app.fs.joinPath(PROY, "herramientas/aseprite/previas/")
local pc = app.pixelColor
local T = 32

local FORMAS = {
  abrojo_de_mas_afuera = "arbusto", aji_de_zorra = "arbusto", alerce = "conifera", arrayan = "arbol",
  cactus_costa_norte = "columnar", cactus_patagonico = "cactus", calafate = "arbusto", calle_calle = "hierba",
  chayotillo = "hierba", chilenito = "cactus", cortadera_insular = "hierba", guayacan = "arbol",
  helecho_pelicula = "helecho", hongo_subterraneo = "hongo", lenga = "arbol", liquen_de_la_estepa = "liquen",
  liquen_de_roca = "liquen", liquen_insular_gigante = "liquen", luma_de_juan_fernandez = "arbol",
  maihuen = "cactus", orquidea_zona_central = "hierba", palma_chilena = "palmera", palma_de_rapa_nui = "palmera",
  palo_gordo = "columnar", peperomia = "arbusto", pitao = "arbol", luma = "arbol", quenoa_de_altura = "arbol",
  quila = "hierba", sandillon = "cactus", seta_del_roble_maule = "hongo", teresa = "hierba",
  tintero_del_desierto = "hongo", toromiro = "arbol",
}

local function hash(x, y, s)
  local v = (x*374761393 + y*668265263 + s*982451653) % 2147483647
  v = (v ~ (v >> 13)) * 1274126177 % 2147483647
  return (v % 1000) / 1000
end

-- ── Colores de la especie ───────────────────────────────────────────────────────────────
local function hsl(c)
  local r, g, b = pc.rgbaR(c) / 255, pc.rgbaG(c) / 255, pc.rgbaB(c) / 255
  local mx, mn = max(r, g, b), min(r, g, b)
  local l = (mx + mn) / 2
  if mx == mn then return 0, 0, l end
  local d = mx - mn
  local s = (l > 0.5) and d / (2 - mx - mn) or d / (mx + mn)
  local h
  if mx == r then h = (g - b) / d + ((g < b) and 6 or 0) elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
  return h * 60, s, l
end
local function lum(c) local _, _, l = hsl(c) return l end

-- Cuenta los colores del primer cuadro y elige: follaje (3 tonos), tallo y un color de acento.
local function paleta(ruta, forma)
  local spr = app.open(ruta)
  local img = Image(spr.spec)
  img:drawSprite(spr, 1)
  spr:close()
  local cuenta = {}
  for p in img:pixels() do
    local c = p()
    if pc.rgbaA(c) > 0 then cuenta[c] = (cuenta[c] or 0) + 1 end
  end
  local lista = {}
  for c, n in pairs(cuenta) do lista[#lista + 1] = {c = c, n = n} end
  table.sort(lista, function(a, b) return a.n > b.n end)
  local function elegir(filtro, cuantos)
    local r = {}
    for _, e in ipairs(lista) do
      if #r >= cuantos then break end
      local h, s, l = hsl(e.c)
      if filtro(h, s, l) then r[#r + 1] = e.c end
    end
    return r
  end
  local vegetal = forma ~= "hongo" and forma ~= "liquen"
  local hoja = elegir(function(h, s, l) return l > 0.1 and (not vegetal or (h > 45 and h < 200 and s > 0.12)) end, 3)
  if #hoja < 3 then hoja = elegir(function(h, s, l) return l > 0.1 end, 3) end
  table.sort(hoja, function(a, b) return lum(a) < lum(b) end)
  while #hoja < 3 do table.insert(hoja, hoja[#hoja] or pc.rgba(80, 140, 70, 255)) end
  local tallo = elegir(function(h, s, l) return h >= 10 and h <= 45 and s > 0.15 and l > 0.15 and l < 0.6 end, 1)[1]
    or hoja[1]
  local acento = elegir(function(h, s, l) return s > 0.45 and l > 0.45 and (h < 45 or h > 280) end, 1)[1]
  local contorno = lista[1].c
  for _, e in ipairs(lista) do if lum(e.c) < lum(contorno) then contorno = e.c end end
  return {d = hoja[1], m = hoja[2], l = hoja[3], tallo = tallo, acento = acento, contorno = contorno}
end

-- ── Dibujo ───────────────────────────────────────────────────────────────────────────────
local TIERRA = {pc.rgba(62, 46, 32, 255), pc.rgba(90, 70, 48, 255), pc.rgba(122, 98, 68, 255)}
local GRIS = {pc.rgba(96, 98, 104, 255), pc.rgba(130, 132, 138, 255), pc.rgba(166, 168, 172, 255)}

local function nuevo() return {} end
local function pon(m, x, y, c)
  x, y = floor(x + 0.5), floor(y + 0.5)
  if c and x >= 0 and x < T and y >= 0 and y < T then m[y * T + x] = c end
end
local function elipse(m, cx, cy, rx, ry, fn)
  for y = floor(cy - ry), floor(cy + ry + 0.999) do for x = floor(cx - rx), floor(cx + rx + 0.999) do
    local dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
    if dx*dx + dy*dy <= 1 then pon(m, x, y, fn(dx, dy, x, y)) end
  end end
end
local function linea(m, x0, y0, x1, y1, c)
  local n = max(abs(x1 - x0), abs(y1 - y0), 1)
  for i = 0, n do pon(m, x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, c) end
end
-- Sombreado de un volumen con luz arriba-izquierda.
local function vol(p) return function(dx, dy) local s = dy + dx * 0.4 if s < -0.5 then return p.l elseif s > 0.45 then return p.d end return p.m end end

-- Montículo de tierra recién removida donde se plantó.
local function monticulo(m, ancho)
  elipse(m, 16, 31, ancho, 2.2, function(dx, dy) if dy < -0.3 then return TIERRA[3] elseif dy > 0.2 then return TIERRA[1] end return TIERRA[2] end)
end

local function hojita(m, cx, cy, rx, ry, p)
  elipse(m, cx, cy, rx, ry, vol(p))
end

-- Brote: dos cotiledones sobre un tallito (o el equivalente de cada forma).
local BROTE = {}
BROTE.planta = function(m, p)
  monticulo(m, 5)
  linea(m, 16, 29, 16, 24, p.m)
  hojita(m, 13.5, 23.5, 2.6, 1.3, p)
  hojita(m, 18.5, 22.5, 2.6, 1.3, p)
end
BROTE.palmera = function(m, p)
  monticulo(m, 5)
  -- una hoja plegada como lanza, típica de las palmas al germinar
  for y = 20, 29 do
    local w = (y < 23) and 0 or 1
    for x = 16 - w, 16 + w do pon(m, x, y, (x < 16) and p.l or ((x > 16) and p.d or p.m)) end
  end
  pon(m, 17, 19, p.m)
end
BROTE.hierba = function(m, p)
  monticulo(m, 5)
  linea(m, 15, 29, 13, 23, p.m); linea(m, 16, 29, 16, 22, p.l); linea(m, 17, 29, 19, 24, p.d)
end
BROTE.helecho = function(m, p)
  monticulo(m, 5)
  -- báculo: fronda enrollada en espiral
  linea(m, 16, 29, 16, 24, p.m)
  for a = 0, 9 do
    local ang, rr = a * 0.65, 2.6 - a * 0.22
    pon(m, 17 + cos(ang) * rr, 22 + sin(ang) * rr, (a < 4) and p.l or p.m)
  end
end
BROTE.cactus = function(m, p)
  monticulo(m, 5)
  elipse(m, 16, 27.5, 2.5, 2.4, function(dx, dy, x, y) if (x + y) % 3 == 0 then return p.d end return vol(p)(dx, dy) end)
end
BROTE.hongo = function(m, p)
  monticulo(m, 6)
  for _, h in ipairs({{14, 28, 1.8}, {18.5, 29, 1.3}}) do
    elipse(m, h[1], h[2], h[3], h[3] * 0.8, function(dx, dy) if dy > 0.3 then return p.d end return (dx < -0.2 and dy < 0) and p.l or p.m end)
  end
end
BROTE.liquen = function(m, p)
  elipse(m, 16, 29, 5, 2.4, function(dx, dy) if dy > 0.3 then return GRIS[1] end return (dy < -0.3) and GRIS[3] or GRIS[2] end)
  for _, s in ipairs({{14, 28}, {17, 27.5}, {19, 29}}) do pon(m, s[1], s[2], p.m); pon(m, s[1] + 1, s[2], p.l) end
end

-- Plántula: ya muestra la forma de la especie, pero chica y con pocas hojas.
local PLANTULA = {}
PLANTULA.arbol = function(m, p)
  monticulo(m, 4)
  linea(m, 16, 30, 16, 17, p.tallo); linea(m, 17, 30, 17, 22, p.tallo)
  linea(m, 16, 24, 13, 22, p.tallo); linea(m, 17, 21, 20, 19, p.tallo)
  hojita(m, 12, 21, 2.8, 2, p); hojita(m, 20.5, 18.5, 3, 2.1, p)
  hojita(m, 16.5, 15, 3.6, 2.8, p)
end
PLANTULA.conifera = function(m, p)
  monticulo(m, 4)
  linea(m, 16, 30, 16, 26, p.tallo)
  for i = 0, 4 do
    local y, w = 13 + i * 3, 1.5 + i * 0.9
    elipse(m, 16, y, w, 1.6, vol(p))
  end
  pon(m, 16, 11, p.m)
end
PLANTULA.palmera = function(m, p)
  monticulo(m, 4)
  linea(m, 16, 30, 16, 25, p.tallo)
  for j, ang in ipairs({-2.7, -2.2, -1.57, -0.95, -0.45}) do
    for k = 1, 7 do
      local x, y = 16 + cos(ang) * k, 24 + sin(ang) * k * 0.7 + k * k * 0.06
      pon(m, x, y, p.m); if k % 2 == 0 then pon(m, x, y + 1, p.d) end; if k < 4 then pon(m, x, y - 1, p.l) end
    end
  end
end
PLANTULA.arbusto = function(m, p)
  monticulo(m, 6)
  linea(m, 15, 30, 14, 25, p.tallo); linea(m, 17, 30, 18, 25, p.tallo)
  for _, l in ipairs({{12.5, 25, 3.2, 2.6}, {19.5, 25, 3.2, 2.6}, {16, 22.5, 3.6, 2.8}}) do hojita(m, l[1], l[2], l[3], l[4], p) end
  if p.acento then pon(m, 15, 21, p.acento); pon(m, 20, 24, p.acento) end
end
PLANTULA.hierba = function(m, p)
  monticulo(m, 5)
  for i = 1, 5 do
    local ang = -pi / 2 + (i - 3) * 0.38
    local largo = 7 + ((i % 2 == 0) and 2 or 0)
    for k = 0, largo do
      local x, y = 16 + cos(ang) * k + (i - 3) * k * k * 0.015, 30 + sin(ang) * k
      pon(m, x, y, (k < 2) and p.d or ((i % 2 == 0) and p.m or p.l))
    end
  end
end
PLANTULA.helecho = function(m, p)
  monticulo(m, 5)
  for i, ang in ipairs({-2.5, -0.65}) do
    for k = 0, 8 do
      local x, y = 16 + cos(ang) * k, 29 + sin(ang) * k + k * k * 0.04
      pon(m, x, y, p.d)
      if k % 2 == 0 and k > 1 then pon(m, x - 0.7, y - 1, p.m); pon(m, x + 0.7, y - 1, p.l) end
    end
  end
  linea(m, 16, 29, 16, 22, p.m)
  for a = 0, 8 do local ang, rr = a * 0.7, 2.2 - a * 0.2; pon(m, 17 + cos(ang) * rr, 20 + sin(ang) * rr, p.l) end
end
PLANTULA.cactus = function(m, p)
  monticulo(m, 5)
  elipse(m, 16, 26, 4, 3.8, function(dx, dy, x, y)
    if x % 3 == 0 then return p.d end
    if (x + y) % 4 == 0 and hash(x, y, 2) < 0.5 then return p.l end
    return vol(p)(dx, dy) end)
  if p.acento then pon(m, 16, 22, p.acento); pon(m, 15, 22, p.acento) end
end
PLANTULA.columnar = function(m, p)
  monticulo(m, 4)
  for y = 19, 30 do for x = 14, 18 do
    local c = (x == 14) and p.l or ((x == 18) and p.d or p.m)
    if x == 16 and y % 3 == 0 then c = p.l end
    if y == 19 and (x == 14 or x == 18) then c = nil end
    pon(m, x, y, c)
  end end
end
PLANTULA.hongo = function(m, p)
  monticulo(m, 6)
  for _, h in ipairs({{13.5, 25, 3, 2.2}, {19, 27, 2.2, 1.6}}) do
    linea(m, h[1], h[2] + 1, h[1], 30, GRIS[3])
    elipse(m, h[1], h[2], h[3], h[4], function(dx, dy) if dy > 0.35 then return p.d end return (dx < -0.2 and dy < 0) and p.l or p.m end)
  end
end
PLANTULA.liquen = function(m, p)
  elipse(m, 16, 28, 7, 3.2, function(dx, dy) if dy > 0.3 then return GRIS[1] end return (dy < -0.3) and GRIS[3] or GRIS[2] end)
  for i = 0, 4 do
    local ang = i * pi / 2.5
    elipse(m, 16 + cos(ang) * 3.2, 27 + sin(ang) * 1.2, 1.8, 1.1, function(dx, dy) return (dx*dx + dy*dy > 0.5) and p.l or p.m end)
  end
end

local function forma_brote(forma)
  if forma == "palmera" or forma == "hierba" or forma == "helecho" or forma == "hongo" or forma == "liquen" then return forma end
  if forma == "cactus" or forma == "columnar" then return "cactus" end
  return "planta"
end

-- Contorno de un píxel con el tono más oscuro de la especie (o tierra/gris si es el suelo).
local function contorno(m, color)
  local agregar = {}
  for y = 0, T - 1 do for x = 0, T - 1 do
    if not m[y * T + x] then
      for _, d in ipairs({{0, 1}, {1, 0}, {-1, 0}, {0, -1}}) do
        local xx, yy = x + d[1], y + d[2]
        if xx >= 0 and yy >= 0 and xx < T and yy < T and m[yy * T + xx] then agregar[y * T + x] = color; break end
      end
    end
  end end
  for k, c in pairs(agregar) do m[k] = c end
end

-- ── Joven ────────────────────────────────────────────────────────────────────────────────
local ESCALA_JOVEN = 0.62

local function joven(ruta_especie, color_contorno, ruta)
  local spr = app.open(ruta_especie)
  local img = Image(spr.spec)
  img:drawSprite(spr, 1)
  spr:close()
  local W, H = img.width, img.height
  -- caja de lo dibujado
  local x0, y0, x1, y1 = W, H, -1, -1
  for y = 0, H - 1 do for x = 0, W - 1 do
    if pc.rgbaA(img:getPixel(x, y)) > 0 then
      x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
    end
  end end
  local ancho, alto = x1 - x0 + 1, y1 - y0 + 1
  local nw, nh = max(1, floor(ancho * ESCALA_JOVEN + 0.5)), max(1, floor(alto * ESCALA_JOVEN + 0.5))
  -- apoyada en el mismo pie y centrada como la adulta
  local ox = floor(x0 + (ancho - nw) / 2 + 0.5)
  local oy = y1 - nh + 1
  local salida = Image(W, H, ColorMode.RGB)
  local paso = 1 / ESCALA_JOVEN
  for ty = 0, nh - 1 do for tx = 0, nw - 1 do
    -- zona del original que cubre este píxel: gana el color más repetido (o vacío si predomina)
    local sx0, sy0 = x0 + floor(tx * paso), y0 + floor(ty * paso)
    -- sin salirse de lo dibujado: fuera del lienzo Aseprite devuelve blanco opaco
    local sx1, sy1 = min(x1, x0 + floor((tx + 1) * paso - 0.001)), min(y1, y0 + floor((ty + 1) * paso - 0.001))
    local cuenta, vacios, total = {}, 0, 0
    for sy = sy0, sy1 do for sx = sx0, sx1 do
      total = total + 1
      local c = img:getPixel(sx, sy)
      if pc.rgbaA(c) == 0 then vacios = vacios + 1
      elseif lum(c) > lum(color_contorno) + 0.02 then cuenta[c] = (cuenta[c] or 0) + 1   -- el contorno se rehace
      end
    end end
    local mejor, n = nil, 0
    for c, k in pairs(cuenta) do if k > n then mejor, n = c, k end end
    if mejor and vacios * 2 <= total + 1 then salida:drawPixel(ox + tx, oy + ty, mejor) end
  end end
  -- contorno de un píxel con el tono más oscuro de la especie
  local agregar = {}
  for y = 0, H - 1 do for x = 0, W - 1 do
    if pc.rgbaA(salida:getPixel(x, y)) == 0 then
      for _, d in ipairs({{0, 1}, {1, 0}, {-1, 0}, {0, -1}}) do
        local xx, yy = x + d[1], y + d[2]
        if xx >= 0 and yy >= 0 and xx < W and yy < H and pc.rgbaA(salida:getPixel(xx, yy)) > 0 then
          agregar[#agregar + 1] = {x, y}; break
        end
      end
    end
  end end
  for _, p in ipairs(agregar) do salida:drawPixel(p[1], p[2], color_contorno) end
  salida:saveAs(ruta)
  return salida
end

local function guardar(m, color, ruta)
  contorno(m, color)
  local img = Image(T, T, ColorMode.RGB)
  for k, c in pairs(m) do img:drawPixel(k % T, floor(k / T), c) end
  img:saveAs(ruta)
  return img
end

app.fs.makeAllDirectories(DESTINO)
local nombres = {}
for nombre in pairs(FORMAS) do nombres[#nombres + 1] = nombre end
table.sort(nombres)
local hoja = Image(#nombres * 3 * 34 + 4, 38, ColorMode.RGB)
hoja:clear(pc.rgba(214, 206, 186, 255))
for i, nombre in ipairs(nombres) do
  local forma = FORMAS[nombre]
  local p = paleta(ORIGEN .. nombre .. ".aseprite", forma)
  local b, pl = nuevo(), nuevo()
  BROTE[forma_brote(forma)](b, p)
  PLANTULA[forma](pl, p)
  local ib = guardar(b, p.contorno, DESTINO .. nombre .. "_brote.png")
  local ip = guardar(pl, p.contorno, DESTINO .. nombre .. "_plantula.png")
  local ij = joven(ORIGEN .. nombre .. ".aseprite", p.contorno, DESTINO .. nombre .. "_joven.png")
  if ij.width > 32 then ij:resize(32, 32) end
  hoja:drawImage(ib, Point(4 + (i - 1) * 102, 3))
  hoja:drawImage(ip, Point(4 + (i - 1) * 102 + 32, 3))
  hoja:drawImage(ij, Point(4 + (i - 1) * 102 + 64, 3))
end
app.fs.makeAllDirectories(PREV)
hoja:resize(hoja.width * 3, hoja.height * 3)
hoja:saveAs(PREV .. "plantas_etapas.png")
print("ok", #nombres)
