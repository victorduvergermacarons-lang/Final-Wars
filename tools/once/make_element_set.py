"""Element set rewards for the Act I main quests (2026-11-20, user request).

Each element gets five Common pieces (Hands, Head, Feet, a ring and a charm) built
on its two key stats (Earth Phys Atk + Phys Def, Water Magic Atk + Phys Def, Fire
Magic Atk + Magic Def, Air Phys Atk + Magic Def) plus a little of one or two other
stats. The main quests hand them out by the hero's element:

  1-01 Hands            given
  1-02 Head             given; choice of a Minor Mana or Minor Health Potion
  1-03 Feet             given
  1-04 ring             or the element's next scroll (choice of one)
  1-05 charm            or a first weapon: Rusty Shortsword, Hunter's Shortbow, Iron Mallet
  1-06 the scroll after that, given
  1-07 unchanged (Fireball, Glacier or Bulwark scroll)

Run from the project root: python3 tools/once/make_element_set.py
Writes content/items/<id>.tres and edits content/quests/act1_0[1-6]_*.tres.
"""
import re

# StatBlock field names.
KEY = {
    "earth": ("phys_atk", "phys_def"),
    "water": ("mag_atk", "phys_def"),
    "fire": ("mag_atk", "mag_def"),
    "air": ("phys_atk", "mag_def"),
}
EXTRA = {  # (extra stat 1, extra stat 2) with their values
    "earth": (("hp", 10), ("accuracy", 2)),
    "water": (("mana", 10), ("hp", 10)),
    "fire": (("mana", 10), ("crit_rate", 1)),
    "air": (("evasion", 2), ("speed", 3)),
}
NAMES = {
    "earth": ["Quarryman's Gloves", "Quarryman's Hood", "Quarryman's Boots", "Granite Ring", "Bedrock Charm"],
    "water": ["Riverweave Gloves", "Riverweave Hood", "Riverweave Sandals", "Tidestone Ring", "Pearl Pendant"],
    "fire": ["Emberstitch Gloves", "Emberstitch Cap", "Emberstitch Boots", "Cinder Ring", "Ashglass Pendant"],
    "air": ["Breezecloth Wraps", "Breezecloth Hood", "Breezecloth Shoes", "Gale Ring", "Feather Charm"],
}
ELEMENT_NAME = {"earth": "Earth", "water": "Water", "fire": "Fire", "air": "Air"}
# The element's next scrolls after its starting two (abilities in the game, in its
# unlock order): 1-04's choice, then 1-06's.
NEXT_SCROLLS = {
    "earth": ("pillar_scroll", "stomp_scroll"),            # Raise Pillar, Seismic Stomp
    "water": ("mist_scroll", "tidal_scroll"),              # Soothing Mist (40), Tidal Blessing (65)
    "fire": ("spark_scroll", "sun_warriors_breath_scroll"),  # Fire Dart, Sun Warrior's Breath
    "air": ("featherstep_scroll", "gale_scroll"),          # Air Step, Air Blast (tier 2)
}
# Per piece: EquipSlot.Type, price, (attack, defense), growth (attack, defense),
# which extras (1, 2, or "speed" for boots), description.
SLOT_HANDS, SLOT_HEAD, SLOT_FEET, SLOT_ACCESSORY = 4, 0, 3, 7
PIECES = [
    (SLOT_HANDS, 12, (2, 1), (1.0, 0.5), [0], "Work gloves of the Floor Guild, for a {e} adept."),
    (SLOT_HEAD, 12, (1, 3), (0.5, 1.0), [1], "A guild-issue hood, for a {e} adept."),
    (SLOT_FEET, 12, (2, 2), (0.5, 1.0), ["speed"], "Road-worn boots, for a {e} adept."),
    (SLOT_ACCESSORY, 15, (3, 2), (1.0, 0.5), [0], "A plain ring that hums with {e}."),
    (SLOT_ACCESSORY, 15, (3, 3), (1.0, 1.0), [1], "A keepsake that steadies a {e} adept."),
]


def slug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower().replace("'", "")).strip("_")


def stat_lines(values):
    order = ["hp", "mana", "phys_atk", "mag_atk", "phys_def", "mag_def", "crit_rate", "speed", "accuracy", "evasion"]
    return "".join("%s = %s\n" % (k, float(values[k])) for k in order if k in values)


ids = {}
for el in KEY:
    ids[el] = []
    a, d = KEY[el]
    for (slot, price, (sa, sd), (ga, gd), extras, desc), name in zip(PIECES, NAMES[el]):
        stats = {a: sa, d: sd}
        for x in extras:
            k, v = ("speed", 3) if x == "speed" else EXTRA[el][x]
            stats[k] = stats.get(k, 0) + v
        growth = {a: ga, d: gd}
        item_id = slug(name)
        ids[el].append(item_id)
        open("content/items/%s.tres" % item_id, "w").write("""[gd_resource type="Resource" script_class="ItemDef" format=3]

[ext_resource type="Script" path="res://data/defs/stat_block.gd" id="1_stats"]
[ext_resource type="Script" path="res://data/defs/item_def.gd" id="2_item"]

[sub_resource type="Resource" id="stats"]
script = ExtResource("1_stats")
%s
[sub_resource type="Resource" id="growth"]
script = ExtResource("1_stats")
%s
[resource]
script = ExtResource("2_item")
id = &"%s"
display_name = "%s"
description = "%s"
slot = %d
price = %d
stats = SubResource("stats")
growth = SubResource("growth")
element = &"%s"
""" % (stat_lines(stats), stat_lines(growth), item_id, name.replace('"', '\\"'),
            desc.format(e=ELEMENT_NAME[el]), slot, price, el))


def by_element(pick):
    return "{\n" + ",\n".join('"%s": [%s]' % (el, ", ".join('&"%s"' % i for i in pick(el))) for el in KEY) + "\n}"


def edit_quest(path, given=None, choice=None, choice_ids=None, drop_reward_items=False):
    s = open(path).read()
    s = re.sub(r'\nelement_(reward|choice)_ids = \{[^}]*\}', "", s)
    if choice_ids is not None:
        s = re.sub(r'reward_choice_ids = Array\[StringName\]\(\[[^\]]*\]\)',
                   "reward_choice_ids = Array[StringName]([%s])" % ", ".join('&"%s"' % i for i in choice_ids), s)
    if drop_reward_items:
        s = re.sub(r'\nreward_items = Array\[ExtResource\("3_item"\)\]\(\[[^\]]*\]\)', "", s)
    extra = ""
    if given is not None:
        extra += "element_reward_ids = %s\n" % by_element(given)
    if choice is not None:
        extra += "element_choice_ids = %s\n" % by_element(choice)
    s = s.replace("reward_choice_ids = ", extra + "reward_choice_ids = ", 1)
    open(path, "w").write(s)


Q = "content/quests/"
edit_quest(Q + "act1_01_guild_comes_to_millbrook.tres", given=lambda el: [ids[el][0]], choice_ids=[])
edit_quest(Q + "act1_02_applicants_wanted.tres", given=lambda el: [ids[el][1]],
           choice_ids=["minor_mana_potion", "minor_health_potion"], drop_reward_items=True)
edit_quest(Q + "act1_03_wells_for_the_windsteppe.tres", given=lambda el: [ids[el][2]], choice_ids=[])
edit_quest(Q + "act1_04_grain_for_deepcut.tres", choice=lambda el: [ids[el][3], NEXT_SCROLLS[el][0]], choice_ids=[])
edit_quest(Q + "act1_05_fever_in_millbrook.tres", choice=lambda el: [ids[el][4]],
           choice_ids=["rusty_shortsword", "hunters_shortbow", "iron_mallet"])
edit_quest(Q + "act1_06_recognition.tres", given=lambda el: [NEXT_SCROLLS[el][1]], choice_ids=[])
print("wrote", sum(len(v) for v in ids.values()), "items:", ids)
