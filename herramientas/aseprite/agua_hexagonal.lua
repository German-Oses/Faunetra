-- Uso (desde la carpeta del proyecto):
--   aseprite -b --script-param id=3 --script herramientas/aseprite/agua_hexagonal.lua
-- Redibuja el agua (columnas 4 y 5) de Assets/tilesets/mapa_<id>.aseprite y exporta el .png.
-- Solo reconoce los colores de agua de PALETAS: si cambias la paleta del agua, actualízala aquí.
-- Trama hexagonal isométrica para las baldosas de agua (columnas 4 y 5 del tileset).
-- Panal sobre la red de puntos a=(16,0), b=(8,8): compatible con el paso de las baldosas (64,0) y (32,16),
-- así el patrón continúa sin costuras entre parcelas vecinas.
local PALETAS = {
  [1] = {"#6AA8B8", "#A4D8E0", "#4A8496"},
  [2] = {"#6FC2CC", "#B8EEF0", "#4A98A8"},
  [3] = {"#4F9AB8", "#9AD4EA", "#346E8E"},
  [4] = {"#56BCCC", "#B8EEF0", "#3A8E9E"},
  [5] = {"#2F8FB8", "#8ED4F0", "#206A8E"},
}
local function hex(h) return {tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16)} end
local function mezcla(c1, c2, t)
  return app.pixelColor.rgba(math.floor(c1[1]+(c2[1]-c1[1])*t+0.5), math.floor(c1[2]+(c2[2]-c1[2])*t+0.5), math.floor(c1[3]+(c2[3]-c1[3])*t+0.5), 255)
end

function trama_agua(img, id, x0, cuadro)
  local p = PALETAS[id]
  local base, claro, oscuro = hex(p[1]), hex(p[2]), hex(p[3])
  local es_agua = {}
  for _,c in ipairs({base, claro, oscuro}) do es_agua[app.pixelColor.rgba(c[1],c[2],c[3],255)] = true end
  local C_BASE = mezcla(base, base, 0)
  local C_LINEA = mezcla(base, claro, 0.38)
  local C_BRILLO = mezcla(base, claro, 1.0)
  es_agua[C_LINEA] = true  -- así el script puede volver a ejecutarse sobre un tileset ya tramado
  -- máscara: los píxeles que hoy son agua (la cara superior de la baldosa)
  local agua = {}
  for y=0,47 do for x=0,63 do
    if es_agua[img:getPixel(x0+x, y)] then agua[y*64+x] = true end
  end end
  -- 1) fondo liso
  for y=0,47 do for x=0,63 do
    if agua[y*64+x] then img:putPixel(x0+x, y, C_BASE) end
  end end
  local function pintar(x, y, col)
    if x>=0 and x<=63 and y>=0 and y<=47 and agua[y*64+x] then img:putPixel(x0+x, y, col) end
  end
  -- 2) panal: cada punto de la red dibuja sus aristas superiores (pendiente 1:4, escalones
  --    limpios de 4 px) y su arista vertical derecha; las demás las dibujan sus vecinos.
  --    Vértices del hexágono: (0,±5), (±8,±3).
  for j=-3,8 do for i=-4,6 do
    local cx, cy = 16*i + 8*j, 8*j
    for dx=0,7 do
      pintar(cx + dx, cy - 5 + dx // 4, C_LINEA)
      pintar(cx - dx, cy - 5 + dx // 4, C_LINEA)
    end
    for dy=-3,3 do pintar(cx + 8, cy + dy, C_LINEA) end
    -- destello: uno por baldosa y cuadro, en el centro de una celda (periódico con la baldosa)
    local h = (2*i - j) % 8
    if (cuadro == 0 and h == 0) or (cuadro == 1 and h == 4) then
      for dx=-1,1 do pintar(cx + dx, cy, C_BRILLO) end
    end
  end end
end


local id = tonumber(app.params["id"] or "")
if id then
  local ruta = "Assets/tilesets/mapa_" .. id
  local spr = app.open(ruta .. ".aseprite")
  local img = Image(spr.width, spr.height, spr.colorMode)
  img:drawSprite(spr, 1)
  trama_agua(img, id, 256, 0)
  trama_agua(img, id, 320, 1)
  spr.cels[1].image = img
  spr.cels[1].position = Point(0, 0)
  spr:saveAs(ruta .. ".aseprite")
  spr:saveCopyAs(ruta .. ".png")
end
