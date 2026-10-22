-- Íconos de los minijuegos de la pestaña Juegos (ui/minijuegos/juegos.gd), 16x16 con la paleta de
-- Assets/UI/iconos: contorno verde oscuro, verdes con luz arriba-izquierda y crema.
--   rompecabezas.png: una pieza de rompecabezas.   cartas.png: dos cartas del memorice.
-- Uso (desde la carpeta del proyecto, o con el MCP de Aseprite: run_lua_script):
--   aseprite -b --script herramientas/aseprite/iconos_juegos.lua
local PROY = PROYECTO or app.fs.currentPath
local DESTINO = DESTINO_ICONOS or (app.fs.joinPath(PROY, "Assets/UI/iconos") .. "/")
local pc = app.pixelColor
local COLORES = {
  ["#"] = pc.rgba(35, 64, 47, 255),    -- contorno
  ["g"] = pc.rgba(78, 154, 71, 255),   -- verde
  ["l"] = pc.rgba(140, 192, 106, 255), -- verde claro (luz)
  ["d"] = pc.rgba(47, 107, 58, 255),   -- verde oscuro (sombra)
  ["c"] = pc.rgba(246, 239, 217, 255), -- crema
  ["t"] = pc.rgba(217, 201, 160, 255), -- crema en sombra
}
local ICONOS = {
  rompecabezas = {
    "................",
    "......###.......",
    ".....#lll#......",
    ".....#lgg#......",
    "..#####gg#####..",
    "..#llggggggdd#..",
    "..#lgggggggdd###",
    "..#lggggggggd#l#",
    "###gggggggggd#g#",
    "#ll#ggggggggdd##",
    "#gg#ggggggggdd#.",
    "###gggggggggdd#.",
    "..#ggggggggddd#.",
    "..#dddddddddd##.",
    "..############..",
    "................",
  },
  cartas = {
    "................",
    ".#########......",
    ".#ggggggg#......",
    ".#glllllg#......",
    ".#gl#####d###...",
    ".#gl#ccccccc#...",
    ".#gl#ccggccc#...",
    ".#gl#cgllgcc#...",
    ".#gl#cglggct#...",
    ".#gg#ccgdgct#...",
    ".####cccgcct#...",
    "....#cccgcct#...",
    "....#cccccct#...",
    "....#tttttttt#..",
    "....##########..",
    "................",
  },
}
app.fs.makeAllDirectories(DESTINO)
for nombre, filas in pairs(ICONOS) do
  local img = Image(16, 16, ColorMode.RGB)
  img:clear(pc.rgba(0, 0, 0, 0))
  for y, fila in ipairs(filas) do
    for x = 1, #fila do
      local c = COLORES[fila:sub(x, x)]
      if c then img:drawPixel(x - 1, y - 1, c) end
    end
  end
  img:saveAs(DESTINO .. nombre .. ".png")
end
print("ok")
