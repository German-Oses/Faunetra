import re

filepath = "/Users/joshuavillavicencio/ProyectoTitulo/entities/especies/especie.gd"
with open(filepath, 'r') as f:
    content = f.read()

# Make sure they scale nicely, maybe 0.1 scale? Let's check image sizes first.
