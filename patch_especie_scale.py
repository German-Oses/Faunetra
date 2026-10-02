with open("entities/especies/especie.gd", "r") as f:
    content = f.read()

# Inside _actualizar_visual()
if "sprite.scale = Vector2(0.1, 0.1)" not in content:
    content = content.replace("sprite.texture = data.textura", "sprite.texture = data.textura\n\t\tsprite.scale = Vector2(0.1, 0.1)\n\t\tarea.scale = Vector2(2.0, 2.0) # To ensure it's clickable")
    with open("entities/especies/especie.gd", "w") as f:
        f.write(content)

