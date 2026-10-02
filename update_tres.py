import os
import re

updates = {
    "tintero_del_desierto.tres": "Montagnea arenaria.png",
    "guanaco_norteo.tres": "Guanaco.png",
    "queoa_de_altura.tres": "Queñoa de altura.png",
    "chinchilla_cordillerana.tres": "Chinchilla.png",
    "ratn_chinchilla_ceniciente.tres": "Abrocoma cinerea.png",
    "sandilln_de_los_andes.tres": "Sandillón de los ratones.png",
    "flamenco_andino.tres": "FlamencAndino.png",
    "caracol_de_vertiente_norte.tres": "CaracoldeaguaDulce.png",
    "chayotillo_del_norte.tres": "Chayotillo.png",
    "lagartija_de_constanza.tres": "LagartijaDeConstanza.png",
    "cuervo_de_pantano_de_la_puna.tres": "Cuervo de pantano de la puna.png",
    "corredor_de_tarapac.tres": "CorredorDeTarapaca.png",
    "vicua.tres": "Vicuyña.png",
    "aj_de_zorra.tres": "AjiZorra.png",
    "balita_de_barriga.tres": "Ectinogonia barrigai.png",
    "cactus_de_la_costa_norte.tres": "Cactus costero del norte.png"
}

tres_dir = "data/especies"

for tres, png in updates.items():
    filepath = os.path.join(tres_dir, tres)
    if not os.path.exists(filepath):
        print(f"Skipping {tres}, not found.")
        continue
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    if "textura =" in content:
        print(f"Already has texture: {tres}")
        continue
    
    # We want to change id_bioma = 1 to id_bioma = 2
    # Because bosque_templado uses id_bioma = 1, so desierto should be 2.
    content = content.replace("id_bioma = 1", "id_bioma = 2")
    
    ext_id = "2_tex"
    ext_path = f"res://assets/sprites/desierto/{png}"
    
    # Insert ext_resource after the last ext_resource
    # Find [resource] block
    resource_idx = content.find("[resource]")
    if resource_idx != -1:
        insert_text = f'[ext_resource type="Texture2D" path="{ext_path}" id="{ext_id}"]\n\n'
        content = content[:resource_idx] + insert_text + content[resource_idx:]
    
    # Add textura = ExtResource(...) to the end
    content += f'textura = ExtResource("{ext_id}")\n'
    
    with open(filepath, 'w') as f:
        f.write(content)
        
    print(f"Updated {tres}")

