"""Starting elements (user request, 2026-11-17): writes content/elements/<id>.tres and
each element's starting shirt and pants (content/items/<id>.tres).

Run from the project root: python3 tools/once/make_element_start.py
Then edit the .tres files directly.
"""

# Stat.Id values: PHYS_ATK 2, MAG_ATK 3, PHYS_DEF 4, MAG_DEF 5.
ELEMENTS = [
    {
        "id": "earth", "name": "Earth", "order": 0, "color": "Color(0.55, 0.42, 0.25, 1)",
        "description": "Stand firm and hold the line: hurl stone and harden your skin.",
        "mastered": "E01", "mastered_scroll": "pebble_scroll", "learning": "granite_skin_scroll",
        "stats": ("phys_atk", "phys_def"), "key": (2, 4),
        "shirt": ("quarrymans_shirt", "Quarryman's Shirt"),
        "pants": ("quarrymans_trousers", "Quarryman's Trousers"),
    },
    {
        "id": "water", "name": "Water", "order": 1, "color": "Color(0.25, 0.45, 0.7, 1)",
        "description": "Mend your friends and lash your foes with the river's flow.",
        "mastered": "W01", "mastered_scroll": "menders_scroll", "learning": "river_lash_scroll",
        "stats": ("mag_atk", "phys_def"), "key": (3, 4),
        "shirt": ("riverweave_shirt", "Riverweave Shirt"),
        "pants": ("riverweave_breeches", "Riverweave Breeches"),
    },
    {
        "id": "fire", "name": "Fire", "order": 2, "color": "Color(0.75, 0.3, 0.15, 1)",
        "description": "Strike fast and hot: punches and kicks wreathed in flame.",
        "mastered": "F01", "mastered_scroll": "ember_fist_scroll", "learning": "cinder_kick_scroll",
        "stats": ("mag_atk", "mag_def"), "key": (3, 5),
        "shirt": ("emberstitch_shirt", "Emberstitch Shirt"),
        "pants": ("emberstitch_trousers", "Emberstitch Trousers"),
    },
    {
        "id": "air", "name": "Air", "order": 3, "color": "Color(0.45, 0.65, 0.6, 1)",
        "description": "Move like the wind: shove foes away and break their focus.",
        "mastered": "A01", "mastered_scroll": "open_palm_scroll", "learning": "breeze_scroll",
        "stats": ("phys_atk", "mag_def"), "key": (2, 5),
        "shirt": ("breezecloth_shirt", "Breezecloth Shirt"),
        "pants": ("breezecloth_leggings", "Breezecloth Leggings"),
    },
]

# Small on purpose (weaker than Acolyte's Leggings: HP 20, Mana 15, Magic Attack 6).
SHIRT = {"stats": (2, 2), "growth": (1, 0.5)}  # (attack stat, defense stat)
PANTS = {"stats": (1, 2), "growth": (0.5, 1)}


def item(item_id, name, slot, element, piece):
    atk, dfn = element["stats"]
    sa, sd = piece["stats"]
    ga, gd = piece["growth"]
    return f'''[gd_resource type="Resource" script_class="ItemDef" format=3]

[ext_resource type="Script" path="res://data/defs/stat_block.gd" id="1_stats"]
[ext_resource type="Script" path="res://data/defs/item_def.gd" id="2_item"]

[sub_resource type="Resource" id="stats"]
script = ExtResource("1_stats")
{atk} = {float(sa)}
{dfn} = {float(sd)}

[sub_resource type="Resource" id="growth"]
script = ExtResource("1_stats")
{atk} = {float(ga)}
{dfn} = {float(gd)}

[resource]
script = ExtResource("2_item")
id = &"{item_id}"
display_name = "{name}"
description = "Plain clothes for a new {element["name"]} adept."
slot = {slot}
price = 10
stats = SubResource("stats")
growth = SubResource("growth")
element = &"{element["id"]}"
'''


for e in ELEMENTS:
    clothes = [(e["shirt"], 1, SHIRT), (e["pants"], 2, PANTS)]
    for (item_id, name), slot, piece in clothes:
        with open(f"content/items/{item_id}.tres", "w") as f:
            f.write(item(item_id, name, slot, e, piece))
    ids = ", ".join(f'&"{c[0][0]}"' for c in clothes)
    with open(f"content/elements/{e['id']}.tres", "w") as f:
        f.write(f'''[gd_resource type="Resource" script_class="StartingElementDef" format=3]

[ext_resource type="Script" path="res://data/defs/starting_element_def.gd" id="1_def"]

[resource]
script = ExtResource("1_def")
id = &"{e["id"]}"
display_name = "{e["name"]}"
description = "{e["description"]}"
tree = "{e["name"]}"
order = {e["order"]}
color = {e["color"]}
mastered_ability_id = &"{e["mastered"]}"
mastered_scroll_id = &"{e["mastered_scroll"]}"
learning_scroll_id = &"{e["learning"]}"
clothes_ids = Array[StringName]([{ids}])
key_stats = Array[int]([{e["key"][0]}, {e["key"][1]}])
''')
print("wrote", len(ELEMENTS), "elements and", 2 * len(ELEMENTS), "items")
