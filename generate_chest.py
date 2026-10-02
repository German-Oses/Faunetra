import math
from PIL import Image

# Palette
palette = [
    (0, 0, 0, 0),         # 0: Transparent
    (24, 24, 24, 255),    # 1: Dark outline
    (92, 58, 33, 255),    # 2: Dark wood
    (143, 86, 59, 255),   # 3: Medium wood
    (191, 121, 88, 255),  # 4: Light wood
    (115, 115, 115, 255), # 5: Dark metal
    (178, 178, 178, 255), # 6: Medium metal
    (237, 201, 86, 255)   # 7: Gold/Brass
]

img = Image.new('RGBA', (32, 32), palette[0])
pixels = img.load()

def draw_rect(x, y, w, h, col):
    for cy in range(y, y+h):
        for cx in range(x, x+w):
            if 0 <= cx < 32 and 0 <= cy < 32:
                pixels[cx, cy] = palette[col]

def draw_line_h(x1, x2, y, col):
    for cx in range(x1, x2+1):
        if 0 <= cx < 32 and 0 <= y < 32:
            pixels[cx, y] = palette[col]

def draw_line_v(x, y1, y2, col):
    for cy in range(y1, y2+1):
        if 0 <= x < 32 and 0 <= cy < 32:
            pixels[x, cy] = palette[col]

cx, cy = 6, 12

# Outline
draw_rect(cx, cy, 20, 16, 1)

# Main wood
draw_rect(cx+1, cy+1, 18, 14, 3)

# Wood shadows
draw_rect(cx+1, cy+11, 18, 4, 2)
draw_line_h(cx+1, cx+18, cy+1, 2)

# Wood highlights
draw_line_h(cx+2, cx+17, cy+2, 4)

# Metal edges
draw_line_v(cx+1, cy+1, cy+14, 6)
draw_line_v(cx+18, cy+1, cy+14, 6)
draw_line_h(cx+1, cx+18, cy+5, 6)
draw_line_h(cx+1, cx+18, cy+14, 6)

# Metal shadows
draw_line_h(cx+2, cx+17, cy+6, 5)
draw_line_v(cx+2, cy+1, cy+14, 5)

# Lock
draw_rect(cx+8, cy+4, 4, 5, 7)
draw_rect(cx+9, cy+6, 2, 2, 1)

img.save('cofre_tesoro.png')
print("Image saved.")
