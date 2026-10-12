-- Baldosas de terrazas para la cordillera: ROCA (columna 7) y NIEVE (columna 8) de cada tileset.
-- Uso (desde la carpeta del proyecto):
--   aseprite -b --script herramientas/aseprite/terrazas.lua
-- Amplía Assets/tilesets/mapa_<id>.aseprite a 9 columnas (576 px) si hace falta, redibuja las
-- columnas 7 y 8 y exporta el .png. Puede ejecutarse de nuevo sin acumular cambios.
--
-- Geometría (igual que las baldosas existentes, 64x48): el rombo superior ocupa las filas 0-31
-- (semiancho 2y+2 arriba y 2(31-y)+2 abajo) y los costados bajan 16 px. Luz arriba-izquierda:
-- el costado izquierdo va iluminado y el derecho en sombra.

local floor, abs, max, min = math.floor, math.abs, math.max, math.min
local PROY = PROYECTO or app.fs.currentPath
local ANCHO_BALDOSA, ALTO_BALDOSA = 64, 48
local COLUMNA_ROCA, COLUMNA_NIEVE = 7, 8
local COLUMNAS = 9

local function hex(s) return app.pixelColor.rgba(tonumber(s:sub(2,3),16), tonumber(s:sub(4,5),16), tonumber(s:sub(6,7),16), 255) end
local function rampa(...) local r = {} for i, h in ipairs({...}) do r[i] = hex(h) end return r end
local function hash(x, y, s)
  local v = (x*374761393 + y*668265263 + s*982451653) % 2147483647
  v = (v ~ (v >> 13)) * 1274126177 % 2147483647
  return (v % 1000) / 1000
end

-- Roca de cada bioma, de oscuro a claro (5 tonos).
local ROCAS = {
  [1] = rampa("#3A3430", "#5A524A", "#7A7064", "#9A8E80", "#B8AC9C"),  -- cerros de la Zona Central
  [2] = rampa("#4A2A1E", "#6E3E2A", "#93583C", "#B47652", "#D09470"),  -- roca rojiza del altiplano
  [3] = rampa("#26282C", "#3C3F45", "#56595F", "#71747A", "#8E9196"),  -- basalto volcánico del sur
  [4] = rampa("#34303A", "#4E4A56", "#6A6674", "#888494", "#A8A4B2"),  -- granito patagónico
  [5] = rampa("#2A2422", "#433A36", "#5E534D", "#7A6E66", "#968A80"),  -- escoria volcánica insular
}
local NIEVE = rampa("#8FA3B8", "#B8C8D8", "#DCE6EE", "#F4F8FA", "#FFFFFF")

local function semiancho(y) return (y <= 15) and (2*y + 2) or (2*(31 - y) + 2) end
local function en_cara_superior(x, y) return y >= 0 and y <= 31 and abs(x - 31.5) <= semiancho(y) end
-- Fila donde empieza el costado bajo la columna x (borde inferior del rombo).
local function borde_inferior(x)
  local d = abs(x - 31.5)
  return min(31, floor(31 - (d - 2) / 2))
end
local function en_baldosa(x, y)
  if en_cara_superior(x, y) then return true end
  local b = borde_inferior(x)
  return y > b and y <= b + 16 and y <= 47
end

local function cara_roca(rp, x, y, semilla)
  -- piedra: grupos de grietas y guijarros dispersos. La luz por baldosa es leve: si fuera fuerte,
  -- cada rombo repetiría su degradado y se notaría la cuadrícula.
  local luz = -((x - 31.5) / 32 * 0.6 + (y - 15.5) / 16 * 0.5) * 0.25
  local v = luz + (hash(floor(x / 3), floor(y / 2), semilla) - 0.5) * 0.9
  local tono = 3
  if v > 0.35 then tono = 4 elseif v < -0.4 then tono = 2 end
  if hash(x, y, semilla + 1) > 0.93 then tono = 5 end
  if hash(floor(x / 2), y, semilla + 2) > 0.95 then tono = 1 end                -- grietas
  return rp[tono]
end

local function costado_roca(rp, x, y, semilla)
  local izquierdo = x < 32
  local prof = y - borde_inferior(x)                                             -- 1..16 bajo el canto
  local tono = izquierdo and 3 or 2
  if prof == 1 then tono = izquierdo and 5 or 3 end                             -- canto iluminado
  -- estratos: líneas horizontales (siguen la pendiente del costado) algo irregulares
  local estrato = (prof + floor(hash(floor(x / 6), 0, semilla) * 2)) % 5
  if estrato == 0 and prof > 2 then tono = tono - 1 end
  if hash(x, floor(y / 3), semilla + 3) > 0.9 then tono = tono - 1 end         -- grietas verticales
  if izquierdo and hash(x, y, semilla + 4) > 0.94 then tono = tono + 1 end
  return rp[max(1, min(5, tono))]
end

local function cara_nieve(x, y, semilla)
  local luz = -((x - 31.5) / 32 * 0.7 + (y - 15.5) / 16 * 0.6) * 0.25
  local v = luz + (hash(floor(x / 4), floor(y / 2), semilla) - 0.5) * 0.9
  local tono = 4
  if v < -0.45 then tono = 3 elseif v > 0.5 then tono = 5 end
  if hash(x, y, semilla + 5) > 0.97 then tono = 5 end                           -- destellos
  return NIEVE[tono]
end

local function dibujar_baldosa(img, x0, rp, nevada, semilla)
  for y = 0, ALTO_BALDOSA - 1 do
    for x = 0, ANCHO_BALDOSA - 1 do
      local col = nil
      if en_cara_superior(x, y) then
        col = nevada and cara_nieve(x, y, semilla) or cara_roca(rp, x, y, semilla)
      elseif en_baldosa(x, y) then
        col = costado_roca(rp, x, y, semilla)
        -- la nieve rebalsa el canto: 2-4 px con goteras irregulares
        if nevada then
          local prof = y - borde_inferior(x)
          local goteo = 2 + floor(hash(x, 0, semilla + 6) * 3)
          if prof <= goteo then col = (x < 32) and NIEVE[3] or NIEVE[2] end
        end
      end
      img:drawPixel(x0 + x, y, col or app.pixelColor.rgba(0, 0, 0, 0))
    end
  end
end

for id = 1, 5 do
  local ruta = app.fs.joinPath(PROY, "Assets/tilesets/mapa_" .. id)
  local spr = app.open(ruta .. ".aseprite")
  local actual = Image(spr.width, spr.height, spr.colorMode)
  actual:drawSprite(spr, 1)
  local ancho = max(spr.width, COLUMNAS * ANCHO_BALDOSA)
  if spr.width < ancho then spr:crop(0, 0, ancho, spr.height) end
  local img = Image(ancho, ALTO_BALDOSA, spr.colorMode)
  img:drawImage(actual, Point(0, 0))
  dibujar_baldosa(img, COLUMNA_ROCA * ANCHO_BALDOSA, ROCAS[id], false, id * 7)
  dibujar_baldosa(img, COLUMNA_NIEVE * ANCHO_BALDOSA, ROCAS[id], true, id * 7 + 1)
  spr.cels[1].image = img
  spr.cels[1].position = Point(0, 0)
  spr:saveAs(ruta .. ".aseprite")
  spr:saveCopyAs(ruta .. ".png")
  spr:close()
end
print("ok")
