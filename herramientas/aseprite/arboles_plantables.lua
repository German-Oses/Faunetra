-- Árboles plantables redibujados para que sigan el estilo del resto de la flora (guayacán, luma de
-- Juan Fernández, toromiro): follaje en verdes medios con 3 tonos, textura de hojas, flores o frutos
-- como acento, luz arriba-izquierda y un vaivén suave de la copa (8 cuadros).
--   alerce (64x64), pitao, luma y arrayan (32x32). Pitao y luma antes compartían pitao_luma.aseprite.
-- Uso (desde la carpeta del proyecto):
--   aseprite -b --script herramientas/aseprite/arboles_plantables.lua
-- Después hay que regenerar las etapas: aseprite -b --script herramientas/aseprite/plantas_etapas.lua
dofile(app.fs.joinPath(PROYECTO or app.fs.currentPath, "herramientas/aseprite/lib_faunetra.lua"))

-- Alerce (Fitzroya cupressoides): conífera columnar alta, corteza rojiza fibrosa y follaje en
-- ramilletes escalonados; el vaivén crece con la altura para que la punta se meza más que la base.
local function alerce(m, t, f)
  local th = 2*pi*t
  local hoja = P("#7AA872", "#4A7C56", "#2C5236")
  local brillo = hex("#A6C88E")
  local tronco = P("#B0683E", "#8A4A2C", "#552E1E")
  local base, tx = 63, 32
  for y = 40, base do
    local w = (y > base-3) and 4 or ((y > base-8) and 3 or 2)
    for x = tx-w, tx+w-1 do
      local col = tronco.m
      if x < tx-w+1 then col = tronco.l elseif x >= tx+w-1 then col = tronco.d end
      if (x+y*3) % 7 == 0 then col = tronco.d end   -- fibras de la corteza
      px(m, x, y, col)
    end
  end
  -- Ramilletes de abajo hacia arriba: {cy, rx, ry}
  local pisos = {{45,15,5}, {39,13.5,5}, {33,12,5}, {27,10,4.5}, {21,8.5,4.5}, {15,6.5,4}, {10,4.5,3}, {5,2.5,2.5}}
  for i, p in ipairs(pisos) do
    local ox = r(sin(th + i*0.35) * (0.3 + i*0.12))
    elipse(m, tx+ox, p[1], p[2], p[3], function(dx, dy, x, y)
      local h = hash(x-ox, y, i)
      if h < 0.07 and abs(dx) > 0.6 then return nil end
      if h > 0.94 and dy < 0.2 then return brillo end
      return somb(hoja)(dx, dy)
    end)
  end
end

crear("Plantas", "alerce", 64, 8, 200, "idle", alerce)

-- Pitao (Pitavia punctata): árbol siempreverde de copa densa y follaje lustroso, flores blancas.
crear("Plantas", "pitao", 32, 8, 180, "idle", function(m, t, f)
  arbol(m, t, f, {
    hoja = P("#5E9A50", "#356E3C", "#1F4826"), tronco = P("#8A7A6A", "#6A5C50", "#433A33"),
    alto_tronco = 20, vaiven = 0.7, flores = hex("#E8E6C8"), brillo = hex("#8CC070"),
    copas = {{16,14,11,5.5}, {9,17,5,3.5}, {23,17,5,3.5}, {16,10,6,3.5}},
  })
end)

-- Luma (Amomyrtus luma): siempreverde de corteza canela lisa, flores blancas y frutos oscuros.
crear("Plantas", "luma", 32, 8, 180, "idle", function(m, t, f)
  arbol(m, t, f, {
    hoja = P("#82AE5E", "#527E40", "#2F5428"), tronco = P("#C4885A", "#9A643E", "#603C26"),
    alto_tronco = 21, vaiven = 0.6, flores = hex("#FFFFFF"), brillo = hex("#3A2638"),
    copas = {{16,12,6,8.5}, {13,17,4,4}, {19,17,4,4}, {16,5,3.5,3}},
  })
end)

-- Arrayán (Luma apiculata): varios troncos color canela con manchas claras, copa en nubes y flores blancas.
crear("Plantas", "arrayan", 32, 8, 180, "idle", function(m, t, f)
  local tronco = P("#E8975A", "#C0703A", "#7E4424")
  local o = {
    hoja = P("#8CB060", "#5A8442", "#34572A"), tronco = tronco,
    alto_tronco = 31, vaiven = 0.8, flores = hex("#F6F2E2"), brillo = hex("#A8C878"),
    copas = {{9,13,6,4.5}, {23,13,6,4.5}, {16,10,7,5}, {13,16,4,3}, {20,16,4,3}},
  }
  for _, rm in ipairs({{15,31,15,26}, {15,26,10,18}, {15,26,17,17}, {17,31,18,27}, {18,27,23,18}, {14,31,13,28}, {13,28,8,21}}) do
    linea(m, rm[1], rm[2], rm[3], rm[4], tronco.m)
  end
  px(m, 16, 31, tronco.l) px(m, 16, 30, tronco.d) px(m, 16, 29, tronco.l)
  px(m, 15, 29, hex("#F0E2CC")) px(m, 18, 29, hex("#F0E2CC")) px(m, 12, 24, hex("#F0E2CC"))
  arbol(m, t, f, o)
end)

hoja_contactos("arboles_plantables.png")
