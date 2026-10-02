-- Script de Aseprite para crear un lienzo, una paleta GBA y dibujar un cofre
-- Se puede ejecutar desde Aseprite en: File -> Scripts -> Run Script...

-- 1. Crear un lienzo de 32x32 píxeles
local sprite = Sprite(32, 32, ColorMode.INDEXED)

-- 2. Definir una paleta de colores estilo GBA (máx 8 colores)
local palette = Palette(8)
palette:setColor(0, Color{ r=0, g=0, b=0, a=0 })         -- 0: Transparente (Fondo)
palette:setColor(1, Color{ r=24, g=24, b=24, a=255 })    -- 1: Contorno oscuro
palette:setColor(2, Color{ r=92, g=58, b=33, a=255 })    -- 2: Madera oscura (sombra)
palette:setColor(3, Color{ r=143, g=86, b=59, a=255 })   -- 3: Madera media (base)
palette:setColor(4, Color{ r=191, g=121, b=88, a=255 })  -- 4: Madera clara (luz)
palette:setColor(5, Color{ r=115, g=115, b=115, a=255 }) -- 5: Metal oscuro (sombra/bordes)
palette:setColor(6, Color{ r=178, g=178, b=178, a=255 }) -- 6: Metal medio (brillo)
palette:setColor(7, Color{ r=237, g=201, b=86, a=255 })  -- 7: Oro/Latón (cerradura)

sprite:setPalette(palette)

-- 3. Nombrar la capa principal 'Base_Cofre'
local layer = sprite.layers[1]
layer.name = "Base_Cofre"

-- 4. Dibujar el cofre del tesoro cerrado
local frame = sprite.frames[1]
local cel = layer:cel(frame)
if not cel then
  cel = sprite:newCel(layer, frame)
end
local image = cel.image

-- Funciones auxiliares para dibujar formas
local function drawRect(x, y, w, h, col)
  for cy = y, y+h-1 do
    for cx = x, x+w-1 do
      if cx >= 0 and cx < 32 and cy >= 0 and cy < 32 then
        image:drawPixel(cx, cy, col)
      end
    end
  end
end

local function drawLineH(x1, x2, y, col)
  for cx = x1, x2 do
    if cx >= 0 and cx < 32 and y >= 0 and y < 32 then
      image:drawPixel(cx, y, col)
    end
  end
end

local function drawLineV(x, y1, y2, col)
  for cy = y1, y2 do
    if x >= 0 and x < 32 and cy >= 0 and cy < 32 then
      image:drawPixel(x, cy, col)
    end
  end
end

-- Dimensiones y posición central
local cx, cy = 6, 12 -- Cofre de 20x16 píxeles

-- Dibujar silueta/contorno
drawRect(cx, cy, 20, 16, 1)

-- Madera principal
drawRect(cx+1, cy+1, 18, 14, 3)

-- Sombras en la madera
drawRect(cx+1, cy+11, 18, 4, 2)
drawLineH(cx+1, cx+18, cy+1, 2)

-- Luces en la madera
drawLineH(cx+2, cx+17, cy+2, 4)

-- Bordes metálicos principales
drawLineV(cx+1, cy+1, cy+14, 6)
drawLineV(cx+18, cy+1, cy+14, 6)
drawLineH(cx+1, cx+18, cy+5, 6)
drawLineH(cx+1, cx+18, cy+14, 6)

-- Sombras en el metal
drawLineH(cx+2, cx+17, cy+6, 5)
drawLineV(cx+2, cy+1, cy+14, 5)

-- Cerradura (dorada y agujero)
drawRect(cx+8, cy+4, 4, 5, 7)
drawRect(cx+9, cy+6, 2, 2, 1)

app.refresh()
