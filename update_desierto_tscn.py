import re

with open("biomas/desierto/desierto.tscn", "r") as f:
    content = f.read()

# Replace bosque_templado references
content = content.replace("res://biomas/bosque_templado/bosque_templado.gd", "res://biomas/desierto/desierto.gd")
content = content.replace('name="BosqueTemplado"', 'name="Desierto"')
content = content.replace('uid://dc18w4npr47xe', 'uid://desiert0scriptx') # Fake UID for script
content = content.replace('uid://darnyur322f12', 'uid://desiert0scenex') # Fake UID for scene

with open("biomas/desierto/desierto.tscn", "w") as f:
    f.write(content)

