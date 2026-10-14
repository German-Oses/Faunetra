-- Caseta del guardaparque y sus estados según la salud del refugio (ver biomas/paisaje_vivo.gd):
-- caseta (base), abandonada → en reparación → restaurada.
-- Se construye en 3D y se proyecta a la misma isometría 2:1 de las baldosas, así la base de las
-- paredes forma una V (la esquina delantera abajo) y calza con el suelo. Techo a dos aguas con la
-- cumbrera a lo largo de un eje de la baldosa: frontón con la puerta en la cara izquierda y la
-- ventana en el costado derecho. Luz arriba-izquierda.
-- Uso (desde la carpeta del proyecto, o con el MCP de Aseprite: run_lua_script):
--   aseprite -b --script herramientas/aseprite/caseta_estados.lua
-- Genera Assets/decoracion/caseta.png, caseta_abandonada.png, caseta_reparacion.png,
-- caseta_restaurada.png y la previa herramientas/aseprite/previas/caseta_estados.png.
-- Imprime la punta de la chimenea respecto del pie del sprite (CHIMENEA en paisaje_vivo.gd).

local floor, abs, sqrt, max, min = math.floor, math.abs, math.sqrt, math.max, math.min
local PROY = PROYECTO or app.fs.currentPath
local RAIZ = DESTINO_CASETA or app.fs.joinPath(PROY, "Assets/decoracion/")
local PREV = PREVIA_CASETA or app.fs.joinPath(PROY, "herramientas/aseprite/previas/")
local pc = app.pixelColor
local T = 64

local function hex(s) return pc.rgba(tonumber(s:sub(2,3),16), tonumber(s:sub(4,5),16), tonumber(s:sub(6,7),16), 255) end
local function hash(x, y, s)
  local v = (x*374761393 + y*668265263 + s*982451653) % 2147483647
  v = (v ~ (v >> 13)) * 1274126177 % 2147483647
  return (v % 1000) / 1000
end

-- ── Geometría ───────────────────────────────────────────────────────────────────────────
-- Mundo: u hacia abajo-derecha, v hacia abajo-izquierda, h hacia arriba (px de la baldosa).
local A, B = 26, 20          -- largo del costado derecho (u) y del frontón (v)
local HW = 16                -- alto de las paredes
local PEND = 0.6             -- pendiente del techo (h por unidad de u); 1.0 dejaría una cara de canto
local O = 2                  -- alero
local HR = HW + PEND * A / 2 -- cumbrera
local CX, CY = 29, 38        -- proyección de (0,0,0)

local function S(u, v, h) return CX + (u - v), CY + (u + v) / 2 - h end

-- Caras: origen y dos aristas en el mundo + polígono de pantalla. Se pintan en orden.
local function cara(id, p0, e1, e2, puntos)
  local pol = {}
  for _, p in ipairs(puntos) do local x, y = S(p[1], p[2], p[3]); pol[#pol+1] = {x, y} end
  local x0, y0 = S(p0[1], p0[2], p0[3])
  local ax, ay = S(p0[1]+e1[1], p0[2]+e1[2], p0[3]+e1[3]); ax, ay = ax - x0, ay - y0
  local bx, by = S(p0[1]+e2[1], p0[2]+e2[2], p0[3]+e2[3]); bx, by = bx - x0, by - y0
  local det = ax * by - ay * bx
  return {id = id, pol = pol, mundo = function(x, y)
    local dx, dy = x - x0, y - y0
    local a, b = (dx * by - dy * bx) / det, (ax * dy - ay * dx) / det
    return p0[1] + a*e1[1] + b*e2[1], p0[2] + a*e1[2] + b*e2[2], p0[3] + a*e1[3] + b*e2[3]
  end}
end

local CU0, CU1, CV0, CV1 = 18, 21, 4, 7         -- chimenea sobre el faldón derecho
local function techo_der(u) return HW + PEND * (A - u) end
local HT = HR + 4

local CARAS = {
  cara("pared_izq", {0, B, 0}, {1, 0, 0}, {0, 0, 1},
    {{0, B, 0}, {A, B, 0}, {A, B, HW}, {A/2, B, HR}, {0, B, HW}}),
  cara("pared_der", {A, 0, 0}, {0, 1, 0}, {0, 0, 1},
    {{A, 0, 0}, {A, B, 0}, {A, B, HW}, {A, 0, HW}}),
  cara("techo_izq", {A/2, -O, HR}, {-1, 0, -PEND}, {0, 1, 0},
    {{-O, -O, HW - PEND*O}, {A/2, -O, HR}, {A/2, B+O, HR}, {-O, B+O, HW - PEND*O}}),
  cara("techo_der", {A/2, -O, HR}, {1, 0, -PEND}, {0, 1, 0},
    {{A/2, -O, HR}, {A+O, -O, HW - PEND*O}, {A+O, B+O, HW - PEND*O}, {A/2, B+O, HR}}),
  cara("chim_izq", {CU0, CV1, 0}, {1, 0, 0}, {0, 0, 1},
    {{CU0, CV1, techo_der(CU0)}, {CU1, CV1, techo_der(CU1)}, {CU1, CV1, HT}, {CU0, CV1, HT}}),
  cara("chim_der", {CU1, CV0, 0}, {0, 1, 0}, {0, 0, 1},
    {{CU1, CV0, techo_der(CU1)}, {CU1, CV1, techo_der(CU1)}, {CU1, CV1, HT}, {CU1, CV0, HT}}),
  cara("chim_top", {CU0, CV0, HT}, {1, 0, 0}, {0, 1, 0},
    {{CU0, CV0, HT}, {CU1, CV0, HT}, {CU1, CV1, HT}, {CU0, CV1, HT}}),
}

local function dentro(pol, x, y)
  local c = false
  local j = #pol
  for i = 1, #pol do
    local xi, yi, xj, yj = pol[i][1], pol[i][2], pol[j][1], pol[j][2]
    if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then c = not c end
    j = i
  end
  return c
end

-- Rasteriza: para cada píxel, la última cara que lo cubre y su punto en el mundo.
local MAPA = {}
for y = 0, T - 1 do for x = 0, T - 1 do
  for _, f in ipairs(CARAS) do
    if dentro(f.pol, x + 0.5, y + 0.5) then
      local u, v, h = f.mundo(x + 0.5, y + 0.5)
      MAPA[y * T + x] = {cara = f.id, u = u, v = v, h = h, debajo = MAPA[y * T + x]}
    end
  end
end end

-- ── Paletas ─────────────────────────────────────────────────────────────────────────────
local BASE = {
  madera_l = "#D2A468", madera_m = "#AE7E44", junta_l = "#A8783E", junta_m = "#86602E",
  piedra = "#8A8478", piedra_d = "#6A645C",
  techo_l = "#6EAA62", techo_m = "#4A8650", teja_l = "#5A9654", teja_m = "#3A6E40", cumbrera = "#8CC27A",
  puerta = "#7A5428", puerta_d = "#5A3C1E", marco = "#5A3C1E", vidrio = "#9AD4EA", vidrio_l = "#D2EEF6",
  chim_l = "#9A948C", chim_m = "#76706A", chim_top = "#3A3430",
  contorno = "#2E2418",
}
local SECA = {
  madera_l = "#A49684", madera_m = "#827462", junta_l = "#7E705E", junta_m = "#62564A",
  piedra = "#78726A", piedra_d = "#5A5650",
  techo_l = "#8A8A62", techo_m = "#66664A", teja_l = "#76764E", teja_m = "#54543C", cumbrera = "#9A9A72",
  puerta = "#4E4236", puerta_d = "#3A3028", marco = "#3A3028", vidrio = "#2A2A2E", vidrio_l = "#3A3A40",
  chim_l = "#7A746E", chim_m = "#5E5852", chim_top = "#2A2420",
  contorno = "#2A221A",
}

-- ── Dibujo de la caseta ─────────────────────────────────────────────────────────────────
local function en_puerta(m) return m.cara == "pared_izq" and m.u >= 10 and m.u < 16 and m.h < 11.5 end
local function en_ventana(m) return m.cara == "pared_der" and m.v >= 6 and m.v < 14 and m.h >= 5 and m.h < 11.5 end

local function color_de(m, P, o)
  local c = m.cara
  if c == "pared_izq" or c == "pared_der" then
    local izq = c == "pared_izq"
    if m.h < 1.5 then return (hash(floor(m.u + m.v), 1, 3) < 0.35) and P.piedra_d or P.piedra end
    if en_puerta(m) then
      if m.u < 10.9 or m.u >= 15.1 or m.h >= 10.6 then return P.marco end
      if o.puerta_abierta then return "#120E0A" end
      if abs(m.u - 13) < 0.5 and m.h > 3 then return P.puerta_d end   -- junta de las dos hojas
      if m.u > 14 and abs(m.h - 5.5) < 0.6 then return "#E2B84A" end   -- manilla
      return P.puerta
    end
    if en_ventana(m) then
      if m.v < 6.9 or m.v >= 13.1 or m.h < 5.9 or m.h >= 10.6 then return P.marco end
      if abs(m.v - 10) < 0.5 or abs(m.h - 8.2) < 0.45 then return P.marco end
      if o.tapiada then return "#1A1A1E" end
      return (m.v < 9 and m.h > 8.5) and P.vidrio_l or P.vidrio
    end
    -- tablones horizontales: junta cada 3 px de alto
    if floor(m.h) % 3 == 0 then return izq and P.junta_l or P.junta_m end
    return izq and P.madera_l or P.madera_m
  elseif c == "techo_izq" or c == "techo_der" then
    local izq = c == "techo_izq"
    local d = abs(m.u - A/2)                         -- distancia desde la cumbrera
    if d < 0.8 then return P.cumbrera end
    local fila = floor(d / 1.6)
    local corrido = (fila % 2) * 2
    if (d % 1.6) < 0.55 or (floor(m.v + corrido) % 4 == 0) then return izq and P.teja_l or P.teja_m end
    return izq and P.techo_l or P.techo_m
  elseif c == "chim_izq" then
    return (floor(m.h) % 3 == 0) and P.chim_m or P.chim_l
  elseif c == "chim_der" then
    return P.chim_m
  elseif c == "chim_top" then
    return P.chim_top
  end
end

local function dibujar(P, o)
  local img = Image(T, T, ColorMode.RGB)
  img:clear(pc.rgba(0, 0, 0, 0))
  -- Sin chimenea (abandonada): se ve lo que había debajo de su parte alta.
  local function ver(m)
    while m and o.sin_chimenea and m.cara:sub(1, 4) == "chim" and m.h > HT - 5 do m = m.debajo end
    return m
  end
  for k, m0 in pairs(MAPA) do
    local m = ver(m0)
    if m then
      local c = color_de(m, P, o)
      if c then img:drawPixel(k % T, floor(k / T), hex(c)) end
    end
  end
  -- contorno: silueta y bordes entre paredes y techo
  local con = hex(P.contorno)
  local poner = {}
  for y = 0, T - 1 do for x = 0, T - 1 do
    local m = ver(MAPA[y * T + x])
    if m then
      local borde = false
      for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
        local xx, yy = x + d[1], y + d[2]
        local n = (xx >= 0 and yy >= 0 and xx < T and yy < T) and ver(MAPA[yy * T + xx]) or nil
        if not n then borde = true
        elseif (m.cara:sub(1, 5) == "pared") ~= (n.cara:sub(1, 5) == "pared") and m.cara:sub(1, 5) == "pared" then borde = true
        elseif m.cara == "pared_izq" and n.cara == "pared_der" then borde = true
        elseif m.cara:sub(1, 4) == "chim" and n.cara:sub(1, 4) ~= "chim" then borde = true end
      end
      if borde then poner[#poner+1] = {x, y} end
    end
  end end
  for _, p in ipairs(poner) do img:drawPixel(p[1], p[2], con) end
  return img
end

-- Utilidades para los detalles de cada estado (en coordenadas del mundo o de pantalla).
local function px(img, x, y, c) x, y = floor(x), floor(y); if x >= 0 and y >= 0 and x < T and y < T then img:drawPixel(x, y, hex(c)) end end
local function pxm(img, u, v, h, c) local x, y = S(u, v, h); px(img, x, y, c) end
local function opaco(img, x, y) return x >= 0 and y >= 0 and x < T and y < T and pc.rgbaA(img:getPixel(x, y)) > 0 end

-- Agujero en un faldón del techo: (u, v) del centro y radio, en el mundo.
local function agujero(img, cara, uc, vc, r, semilla)
  for k, m in pairs(MAPA) do
    if m.cara == cara then
      local d = sqrt(((m.u - uc) / 1.2)^2 + (m.v - vc)^2) + (hash(k, 1, semilla) - 0.5) * 0.6
      if d < r then
        px(img, k % T, floor(k / T), (abs((m.v - vc) - (m.u - uc)) < 0.7) and "#5A4630" or "#1A130E")
      elseif d < r + 0.7 then
        px(img, k % T, floor(k / T), "#3A3020")
      end
    end
  end
end

local ESTADOS = {}

ESTADOS.caseta = function() return dibujar(BASE, {}) end

-- Abandonada: madera gris, techo con musgo seco y agujeros, puerta caída, ventana tapiada,
-- chimenea desmoronada y maleza al pie.
ESTADOS.caseta_abandonada = function()
  local img = dibujar(SECA, {puerta_abierta = true, tapiada = true, sin_chimenea = true})
  agujero(img, "techo_der", 20, 14, 2.8, 1)
  agujero(img, "techo_izq", 6, 7, 2.0, 2)
  agujero(img, "techo_der", 16, 3, 1.6, 3)
  -- tablas en cruz sobre la ventana
  for i = 0, 7, 0.5 do pxm(img, A, 6.5 + i, 5.5 + i * 0.7, "#8A7C66"); pxm(img, A, 13.5 - i, 5.5 + i * 0.7, "#6E6250") end
  -- hoja de la puerta caída, apoyada en la pared
  for i = 0, 10, 0.5 do pxm(img, 16.5 + i * 0.25, B + 0.5, i, "#4E4236"); pxm(img, 17.3 + i * 0.25, B + 0.5, i, "#3A3028") end
  -- tablas sueltas: huecos oscuros
  for _, t in ipairs({{2, 7, 4}, {19, 12, 3}}) do for i = 0, t[3] - 1 do pxm(img, t[1] + i, B, t[2], "#2A221A") end end
  for i = 0, 3 do pxm(img, A, 15 + i, 13, "#2A221A") end
  -- maleza seca al pie
  for x = 0, T - 1 do
    if hash(x, 7, 9) > 0.5 then
      for y = T - 1, 30, -1 do
        if opaco(img, x, y) then px(img, x, y, "#8A7A3A"); if hash(x, 8, 9) > 0.5 then px(img, x, y - 1, "#A8964A") end break end
      end
    end
  end
  return img
end

-- En reparación: madera original con algunas tablas nuevas, lona azul sobre el agujero del techo,
-- escalera apoyada en el costado derecho y un balde al pie.
ESTADOS.caseta_reparacion = function()
  local img = dibujar(BASE, {})
  for k, m in pairs(MAPA) do
    if m.cara == "techo_der" and m.u > 16 and m.u < 23 and m.v > 10 and m.v < 18 then
      local borde = m.u < 16.8 or m.u > 22.2 or m.v < 10.8 or m.v > 17.2
      px(img, k % T, floor(k / T), borde and "#3A5E9A" or ((floor(m.v) % 3 == 0) and "#5A8AD0" or "#6E9EE0"))
    end
    if m.cara == "pared_izq" and (floor(m.h) == 6 and m.u > 2 and m.u < 8 or floor(m.h) == 14 and m.u > 17 and m.u < 23) then
      px(img, k % T, floor(k / T), "#EAC28A")   -- tablas nuevas
    end
  end
  -- escalera apoyada en el costado derecho (rieles y peldaños)
  for h = 0, HW + 1, 0.5 do
    local v = 18.6 - h * 0.1
    pxm(img, A + 1.5, v, h, "#8A6A3A"); pxm(img, A + 1.5, v - 2.5, h, "#8A6A3A")
    if floor(h) % 3 == 1 then for i = 0, 2.5, 0.5 do pxm(img, A + 1.5, v - i, h, "#B08A50") end end
  end
  -- balde al pie de la puerta
  for _, p in ipairs({{-1, 0}, {0, 0}, {1, 0}, {-1, -1}, {0, -1}, {1, -1}, {0, -2}}) do
    local x, y = S(5, B + 3, 0); px(img, x + p[1], y + p[2] - 1, (p[2] == -2) and "#B4BCC4" or "#7E8890")
  end
  return img
end

-- Restaurada: jardinera con flores bajo la ventana y un farol encendido junto a la puerta.
ESTADOS.caseta_restaurada = function()
  local img = dibujar(BASE, {})
  for v = 6, 13.5, 0.5 do
    pxm(img, A + 0.6, v, 4.6, "#7A5428"); pxm(img, A + 0.6, v, 4.0, "#5A3C1E")
    if hash(floor(v * 2), 3, 5) > 0.35 then
      local c = ({"#E2483A", "#F4F0E6", "#F2C230", "#D8399C"})[floor(hash(floor(v * 2), 4, 5) * 4) + 1]
      pxm(img, A + 0.6, v, 5.4, c)
    end
  end
  pxm(img, 17.5, B + 0.6, 9, "#3A3430"); pxm(img, 17.5, B + 0.6, 8, "#F2D04A"); pxm(img, 17.5, B + 0.6, 7, "#C89A2A")
  return img
end

app.fs.makeAllDirectories(RAIZ)
app.fs.makeAllDirectories(PREV)
local orden = {"caseta", "caseta_abandonada", "caseta_reparacion", "caseta_restaurada"}
local hoja = Image(T * 4 * 4, T * 4, ColorMode.RGB)
hoja:clear(pc.rgba(214, 196, 160, 255))
for i, n in ipairs(orden) do
  local img = ESTADOS[n]()
  img:saveAs(RAIZ .. n .. ".png")
  for y = 0, T - 1 do for x = 0, T - 1 do
    local c = img:getPixel(x, y)
    if pc.rgbaA(c) > 0 then for dy = 0, 3 do for dx = 0, 3 do hoja:drawPixel(((i - 1) * T + x) * 4 + dx, y * 4 + dy, c) end end end
  end end
end
hoja:saveAs(PREV .. "caseta_estados.png")
local x, y = S((CU0 + CU1) / 2, (CV0 + CV1) / 2, HT)
print(string.format("ok CHIMENEA = Vector2(%.1f, %.1f)", x - T / 2, y - T))
