with open("entities/especies/especie.gd", "r") as f:
    content = f.read()

content = content.replace("	if data == null:", "	if data == null or sprite == null:")

with open("entities/especies/especie.gd", "w") as f:
    f.write(content)

