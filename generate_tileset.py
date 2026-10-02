import os
import struct
import zlib
import random

def write_png(filename, width, height, pixels):
    def png_pack(png_tag, data):
        chunk_head = png_tag + data
        return struct.pack("!I", len(data)) + chunk_head + struct.pack("!I", zlib.crc32(chunk_head) & 0xFFFFFFFF)

    raw_data = b""
    for y in range(height):
        raw_data += b'\x00' # No filter type
        for x in range(width):
            r, g, b, a = pixels[y][x]
            raw_data += struct.pack("!BBBB", r, g, b, a)

    with open(filename, 'wb') as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(png_pack(b"IHDR", struct.pack("!IIBBBBB", width, height, 8, 6, 0, 0, 0)))
        f.write(png_pack(b"IDAT", zlib.compress(raw_data)))
        f.write(png_pack(b"IEND", b""))

def hex_to_rgba(hex_color):
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4)) + (255,)

def generate_tileset(output_path):
    width = 192
    height = 64
    
    pixels = [[(0, 0, 0, 0) for _ in range(width)] for _ in range(height)]

    luz_hierba = hex_to_rgba("#68BA58")
    media_hierba = hex_to_rgba("#2F8246")
    sombra_hierba = hex_to_rgba("#1C4728")
    tierra_luz = hex_to_rgba("#8A5333")
    tierra_sombra = hex_to_rgba("#4D2A1B")
    oclusion = hex_to_rgba("#29150E")
    
    random.seed(42) # Para mantener los mechones de pasto consistentes
    
    for i in range(3):
        offset_x = i * 64
        
        # PASO 2: Capa 1 - Geometría y Silueta Base (Cara superior / Diamante)
        for y in range(16):
            left = 30 - y * 2
            right = 33 + y * 2
            for x in range(left, right + 1):
                color = luz_hierba if x < 32 else media_hierba
                pixels[y][offset_x + x] = color
                
        for y in range(16, 32):
            y_rel = y - 16
            left = 0 + y_rel * 2
            right = 63 - y_rel * 2
            for x in range(left, right + 1):
                color = luz_hierba if x < 32 else media_hierba
                pixels[y][offset_x + x] = color

        # NUEVO PASO: Textura y mechones de pasto sobre la cara superior
        # 1. Romper la silueta en los bordes superiores
        for y in range(3, 16, 3):
            tx = 30 - y * 2
            if y-2 >= 0:
                pixels[y-1][offset_x + tx] = luz_hierba
                pixels[y-2][offset_x + tx] = luz_hierba
                pixels[y-1][offset_x + tx + 1] = luz_hierba
                
        for y in range(4, 16, 4):
            tx = 33 + y * 2
            if y-2 >= 0:
                pixels[y-1][offset_x + tx] = media_hierba
                pixels[y-2][offset_x + tx] = media_hierba
                pixels[y-1][offset_x + tx - 1] = media_hierba

        # 2. Mechones en la superficie
        for _ in range(25):
            ty = random.randint(3, 28)
            if ty < 16:
                tleft = 30 - ty * 2
                tright = 33 + ty * 2
            else:
                y_rel = ty - 16
                tleft = 0 + y_rel * 2
                tright = 63 - y_rel * 2
                
            tx = random.randint(tleft + 2, tright - 2)
            is_left = tx < 32
            
            tuft_color = media_hierba if is_left else luz_hierba
            shadow_color = sombra_hierba if is_left else media_hierba
            
            pixels[ty][offset_x + tx] = shadow_color
            pixels[ty - 1][offset_x + tx] = tuft_color
            if random.random() > 0.5:
                pixels[ty - 1][offset_x + tx + 1] = tuft_color
                pixels[ty - 2][offset_x + tx + 1] = tuft_color

        # PASO 2: Capa 1 - Paredes de tierra y caída isométrica
        for x in range(32):
            wall_top = 16 + x // 2 + 1
            for y in range(wall_top, wall_top + 16):
                pixels[y][offset_x + x] = tierra_luz
                
        for x in range(32, 64):
            wall_top = 31 - (x - 32) // 2 + 1
            for y in range(wall_top, wall_top + 16):
                pixels[y][offset_x + x] = tierra_sombra

        # PASO 3: Capa 2 - Manto de Hierba (Mechones triangulares que caen)
        for x in range(32):
            wall_top = 16 + x // 2 + 1
            drop = [2, 3, 4, 3][x % 4]
            for dy in range(drop):
                pixels[wall_top + dy][offset_x + x] = sombra_hierba
                
        for x in range(32, 64):
            wall_top = 31 - (x - 32) // 2 + 1
            drop = [3, 4, 3, 2][x % 4]
            for dy in range(drop):
                pixels[wall_top + dy][offset_x + x] = sombra_hierba
                
        # PASO 4: Capa 3 - Textura de Tierra (Cúmulos 2-4px)
        clusters_left = [(6, 6), (14, 11), (22, 7)]
        for cx, cdy in clusters_left:
            wt = 16 + cx // 2 + 1
            cy = wt + cdy
            if cy + 1 < wt + 16:
                pixels[cy][offset_x + cx] = tierra_sombra
                pixels[cy][offset_x + cx + 1] = tierra_sombra
                pixels[cy + 1][offset_x + cx] = oclusion
            
        clusters_right = [(40, 8), (48, 5), (56, 11)]
        for cx, cdy in clusters_right:
            wt = 31 - (cx - 32) // 2 + 1
            cy = wt + cdy
            if cy + 1 < wt + 16:
                pixels[cy][offset_x + cx] = oclusion
                pixels[cy][offset_x + cx + 1] = oclusion
                pixels[cy + 1][offset_x + cx] = tierra_sombra

        # PASO 4: Capa 3 - Delineado selectivo (Aristas inferiores)
        for x in range(32):
            bottom_y = 16 + x // 2 + 16
            pixels[bottom_y][offset_x + x] = oclusion
        for x in range(32, 64):
            bottom_y = 31 - (x - 32) // 2 + 16
            pixels[bottom_y][offset_x + x] = oclusion

    write_png(output_path, width, height, pixels)
    print(f"✅ Tileset successfully saved to {output_path}")

if __name__ == '__main__':
    output = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tileset_isometria_bosque.png")
    generate_tileset(output)
