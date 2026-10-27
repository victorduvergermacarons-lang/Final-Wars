# One-off (kept for the record): the Silent Shaft of milestone 4 of Act I. Writes
# its enemies (the Foreman, the Grey Heart, grey husks, the Grey Overseer), their
# abilities, buffs and loot, Caedan's shaft placement, the boss encounter and the
# zone itself (content/zones/silent_shaft.tres, via make_act1_zones.py's Map and
# writer). Then bake the zone's rows:
#   godot --headless --path . -s res://tools/once/bake_zone_rows.gd
# Edit the files directly now; running this again overwrites them.
# Usage: python3 tools/once/make_silent_shaft.py <project>
import os, sys

root = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, "make_act1_zones.py")).read()
src = src[:src.index("for build in [millbrook")]  # the helpers only, not the other zones
exec(compile(src, "make_act1_zones.py", "exec"))
CONTEXT["dungeon"] = 4


def save(path, text):
    with open(os.path.join(root, path), "w") as f:
        f.write(text)
    print("wrote", path)


STATS = ["hp", "mana", "phys_atk", "mag_atk", "phys_def", "mag_def", "crit_rate", "crit_damage", "speed",
         "accuracy", "evasion", "jump"]


def ability(aid, name, desc, effects, extra, ext=()):
    """effects: lists of 'key = value' lines (scaling: a list of (stat index, coefficient))."""
    lines = ['[gd_resource type="Resource" script_class="AbilityDef" format=3]', "",
             '[ext_resource type="Script" path="res://data/defs/ability_effect.gd" id="1_fx"]',
             '[ext_resource type="Script" path="res://data/defs/ability_scaling.gd" id="2_sc"]',
             '[ext_resource type="Script" path="res://data/defs/ability_def.gd" id="3_ab"]']
    lines += list(ext)
    lines.append("")
    refs = []
    for i, fx in enumerate(effects):
        sc_refs = []
        for j, (stat, coef) in enumerate(fx.get("scaling", [])):
            sid = "Resource_s%d_%d" % (i, j)
            lines += ['[sub_resource type="Resource" id="%s"]' % sid, 'script = ExtResource("2_sc")']
            if stat:
                lines.append("stat = %d" % stat)
            if coef != 1.0:
                lines.append("coefficient = %g" % coef)
            lines.append("")
            sc_refs.append('SubResource("%s")' % sid)
        fid = "Resource_fx%d" % i
        lines += ['[sub_resource type="Resource" id="%s"]' % fid, 'script = ExtResource("1_fx")']
        lines += fx.get("lines", [])
        if sc_refs:
            lines.append('scaling = Array[ExtResource("2_sc")]([%s])' % ", ".join(sc_refs))
        lines.append("")
        refs.append('SubResource("%s")' % fid)
    lines += ["[resource]", 'script = ExtResource("3_ab")', 'id = &"%s"' % aid, 'display_name = "%s"' % name,
              'description = "%s"' % desc]
    lines += extra
    lines.append('effects = Array[ExtResource("1_fx")]([%s])' % ", ".join(refs))
    save("content/abilities/%s.tres" % aid, "\n".join(lines) + "\n")


def buff(bid, name, fields):
    save("content/buffs/%s.tres" % bid, "\n".join(
        ['[gd_resource type="Resource" script_class="BuffDef" format=3]', "",
         '[ext_resource type="Script" path="res://data/defs/buff_def.gd" id="1_buff"]', "", "[resource]",
         'script = ExtResource("1_buff")', 'id = &"%s"' % bid, 'display_name = "%s"' % name] + fields) + "\n")


def loot(lid, gold, entries):
    """entries: (item id of a tree item, chance) or ('file:<plain item>', chance)."""
    lines = ['[gd_resource type="Resource" script_class="LootTable" format=3]', "",
             '[ext_resource type="Script" path="res://data/defs/loot_entry.gd" id="1_entry"]',
             '[ext_resource type="Script" path="res://data/defs/loot_table.gd" id="2_table"]']
    files = sorted({e[5:] for e, _ in entries if e.startswith("file:")})
    for f in files:
        lines.append('[ext_resource type="Resource" path="res://content/items/%s.tres" id="item_%s"]' % (f, f))
    lines.append("")
    refs = []
    for i, (e, chance) in enumerate(entries):
        sid = "Resource_e%d" % i
        lines += ['[sub_resource type="Resource" id="%s"]' % sid, 'script = ExtResource("1_entry")']
        lines.append('item = ExtResource("item_%s")' % e[5:] if e.startswith("file:") else 'item_id = &"%s"' % e)
        lines += ["chance = %g" % chance, ""]
        refs.append('SubResource("%s")' % sid)
    lines += ["[resource]", 'script = ExtResource("2_table")', "gold_min = %d" % gold[0], "gold_max = %d" % gold[1],
              'entries = Array[ExtResource("1_entry")]([%s])' % ", ".join(refs)]
    save("content/loot/%s.tres" % lid, "\n".join(lines) + "\n")


def enemy(eid, name, level, stats, abilities, fields, loot_id=""):
    lines = ['[gd_resource type="Resource" script_class="EnemyDef" format=3]', "",
             '[ext_resource type="Script" path="res://data/defs/ability_def.gd" id="1_ability"]',
             '[ext_resource type="Script" path="res://data/defs/enemy_def.gd" id="2_enemy"]',
             '[ext_resource type="Script" path="res://data/defs/stat_block.gd" id="3_stats"]']
    if loot_id:
        lines.append('[ext_resource type="Resource" path="res://content/loot/%s.tres" id="4_loot"]' % loot_id)
    for a in abilities:
        lines.append('[ext_resource type="Resource" path="res://content/abilities/%s.tres" id="ab_%s"]' % (a, a))
    lines += ["", '[sub_resource type="Resource" id="Resource_stats"]', 'script = ExtResource("3_stats")']
    lines += ["%s = %s" % (k, float(stats[k])) for k in STATS if k in stats]
    lines += ["", "[resource]", 'script = ExtResource("2_enemy")', 'id = &"%s"' % eid, 'display_name = "%s"' % name,
              "level = %d" % level, 'stats = SubResource("Resource_stats")',
              'abilities = Array[ExtResource("1_ability")]([%s])' % ", ".join('ExtResource("ab_%s")' % a for a in abilities)]
    if loot_id:
        lines.append('loot = ExtResource("4_loot")')
    lines += fields
    save("content/enemies/%s.tres" % eid, "\n".join(lines) + "\n")


PHYS_ATK, MAG_ATK = 2, 3  # Stat.Id
TARGETED, SKILLSHOT, GROUND = 1, 2, 3
BUFF, DASH_TO, ZONE = 4, 13, 17

# --- Abilities ------------------------------------------------------------------------
ability("foreman_pick", "Pick-Hammer", "A crushing swing of the Foreman's pick-hammer at whoever holds his eye.",
        [{"lines": ["base_amount = 8.0"], "scaling": [(0, 0.6)]}],
        ["shape = 1", "cooldown_seconds = 2.4", "max_height_difference = 2", "targeting = 1", "windup_seconds = 0.5"])
ability("foreman_slam", "Ground Slam", "Marks a 3-by-3 square of floor, then brings the hammer down on it.",
        [{"lines": ["base_amount = 12.0"], "scaling": [(0, 0.6)]}],
        ["shape = 1", "max_range = 3", "cooldown_seconds = 8.0", "requires_line_of_sight = false",
         "max_height_difference = 3", "targeting = 3", "area_radius = 1", "telegraph_seconds = 1.8"])
ability("foreman_charge", "Mine-Cart Charge", "Marks a tile 2-5 away, then barrels there and tramples whoever stands on it.",
        [{"lines": ["kind = 13", "applies = 1", "base_amount = 5.0"]},
         {"lines": ["base_amount = 8.0"], "scaling": [(0, 0.6)]}],
        ["shape = 1", "min_range = 2", "max_range = 5", "cooldown_seconds = 15.0", "max_height_difference = 2",
         "targeting = 3", "windup_seconds = 1.1"])
ability("grey_drain", "Grey Ground", "The grey creeps over the stone: whoever stands on it is slowed and drained of mana.",
        [{"lines": ["kind = 4", 'buff = ExtResource("4_greyed")']}],
        ["max_range = 0", "on_gcd = false", "requires_line_of_sight = false", "targeting = 1"],
        ['[ext_resource type="Resource" path="res://content/buffs/greyed.tres" id="4_greyed"]'])
ability("grey_heart_pulse", "Grey Pulse", "The Grey Heart pulses and the floor around the heroes turns grey.",
        [{"lines": ["kind = 17", "applies = 2", "duration_seconds = 12.0", 'zone_ability = ExtResource("4_drain")',
                    "zone_tick_seconds = 0.5"]}],
        ["max_range = 0", "on_gcd = false", "requires_line_of_sight = false", "targeting = 4"],
        ['[ext_resource type="Resource" path="res://content/abilities/grey_drain.tres" id="4_drain"]'])
ability("overseer_crush", "Overseer's Crush", "A heavy two-handed blow from the old shift overseer.",
        [{"lines": ["base_amount = 16.0"], "scaling": [(0, 1.0)]}],
        ["shape = 1", "cooldown_seconds = 2.6", "max_height_difference = 2", "targeting = 1", "windup_seconds = 0.6"])

# --- Buffs ------------------------------------------------------------------------------
buff("greyed", "Greyed", ["duration_seconds = 1.0", "step_cooldown_multiplier = 1.5", "mana_regen_percent = -3.0",
                          "is_debuff = true"])
buff("foreman_fury", "Grey Fury", ["duration_seconds = 3600.0", "cooldown_multiplier = 0.85",
                                   "damage_dealt_multiplier = 1.15"])

# --- Loot -------------------------------------------------------------------------------
loot("grey_overseer", (25, 45), [("leech_tide_scroll", 0.35), ("blazing_fist_scroll", 0.35), ("tidal_scroll", 0.35),
                                 ("file:minor_health_potion", 1.0), ("file:minor_mana_potion", 1.0),
                                 ("file:sunstone_shard", 1.0)])
loot("foreman", (80, 140), [("wave_scroll", 0.3), ("lash_of_embers_scroll", 0.3), ("mist_scroll", 0.3),
                            ("file:sunstone_shard", 1.0)])

# --- Enemies ------------------------------------------------------------------------------
# Party size grows them (CombatRules "Party size"); numbers are for one hero.
enemy("foreman", "The Foreman", 10,
      {"hp": 800, "phys_atk": 16, "phys_def": 18, "mag_def": 22, "accuracy": 8, "jump": 2},
      ["foreman_slam", "foreman_charge", "foreman_pick"],
      ["leash_radius = 16", "aggro_radius = 5", "combat_step_seconds = 1.1", "reaction_seconds = 0.35",
       "xp_reward = 1100", "ap_reward = 14", "respawn_seconds = 1e+09", "elite = true", "dungeon_boss = true",
       "weight = 2"], "foreman")
enemy("grey_heart", "The Grey Heart", 10,
      {"hp": 150, "phys_def": 10, "mag_def": 10},
      [],
      ["aggro_radius = 0", "leash_radius = 99", "xp_reward = 0", "respawn_seconds = 1e+09", "immobile = true",
       "look = 1", "weight = 2"])
enemy("grey_husk", "Grey Husk", 8,
      {"hp": 90, "phys_atk": 12, "phys_def": 6, "mag_def": 12, "jump": 1},
      ["husk_rake"],
      ["aggro_radius = 4", "leash_radius = 14", "combat_step_seconds = 1.2", "reaction_seconds = 0.5",
       "xp_reward = 25", "ap_reward = 1", "weight = 1"])
enemy("grey_overseer", "Grey Overseer", 9,
      {"hp": 760, "phys_atk": 24, "phys_def": 18, "mag_def": 26, "jump": 1},
      ["overseer_crush"],
      ["aggro_radius = 4", "leash_radius = 8", "combat_step_seconds = 1.3", "reaction_seconds = 0.45",
       "xp_reward = 320", "ap_reward = 6", "respawn_seconds = 1e+09", "weight = 2"], "grey_overseer")

# --- Caedan, come down after the party -----------------------------------------------------
save("content/npcs/caedan_shaft.tres", """[gd_resource type="Resource" script_class="NpcDef" format=3]

[ext_resource type="Script" path="res://data/defs/npc_def.gd" id="1_npc"]

[resource]
script = ExtResource("1_npc")
id = &"caedan_shaft"
display_name = "Prince Caedan Ashvale"
faction = 1
""")

# --- The encounter ------------------------------------------------------------------------
VICTORY = (50, 15)
save("content/encounters/foreman.tres", """[gd_resource type="Resource" script_class="BossEncounterDef" format=3]

[ext_resource type="Script" path="res://data/defs/boss_encounter_def.gd" id="1_enc"]
[ext_resource type="Resource" path="res://content/enemies/foreman.tres" id="2_boss"]
[ext_resource type="Resource" path="res://content/enemies/grey_heart.tres" id="3_heart"]
[ext_resource type="Resource" path="res://content/enemies/grey_husk.tres" id="4_adds"]
[ext_resource type="Resource" path="res://content/abilities/grey_heart_pulse.tres" id="5_pulse"]
[ext_resource type="Resource" path="res://content/buffs/foreman_fury.tres" id="6_fury"]
[ext_resource type="Resource" path="res://content/npcs/caedan_shaft.tres" id="7_caedan"]

[resource]
script = ExtResource("1_enc")
boss = ExtResource("2_boss")
heart = ExtResource("3_heart")
phase_at = Array[float]([0.6, 0.25])
pulse_seconds = Array[float]([0.0, 12.0, 9.0])
adds = ExtResource("4_adds")
adds_per_pulse = Array[int]([0, 1, 0])
max_adds = 2
grey_tiles_per_pulse = Array[int]([0, 6, 8])
grey_zone = ExtResource("5_pulse")
grey_seconds = 12.0
enrage_buff = ExtResource("6_fury")
boss_floor = 0.05
victory_npc = ExtResource("7_caedan")
victory_tile = Vector2i(%d, %d)
""" % VICTORY)


# --- The zone -----------------------------------------------------------------------------
# 66 x 30, walls 6 high everywhere but the three sections:
#  1. Upper tunnels (x 1-20): the entrance from Deepcut, husks among collapsed tunnels,
#     the rock turning grey; a lift down at the east end.
#  2. Deep seams (x 23-44): Sunstone seams gold where untouched, grey where mined out;
#     ledges and pillars (height and line of sight), and an optional side chamber.
#  3. The Foreman's chamber (x 47-64): the Foreman before the Grey Heart.
LIFT_DOWN, LIFT_UP = (19, 19), (24, 21)
ARRIVE_DOWN, ARRIVE_UP = (26, 21), (17, 19)


def silent_shaft():
    m = Map("silent_shaft", "The Silent Shaft", 66, 30, "mine_wall", 6)
    m.region, m.context = "bedrun", "dungeon"
    floor = lambda x0, y0, x1, y1, t="mine_floor", h=0: m.rect(x0, y0, x1, y1, t, h)
    # 1. Upper tunnels.
    floor(1, 13, 5, 16)                         # the entrance
    floor(5, 14, 9, 15)                         # adit east
    floor(8, 9, 13, 19)                         # first gallery
    floor(13, 11, 15, 12)                       # passage
    floor(14, 7, 19, 13)                        # second gallery
    floor(16, 13, 17, 18)                       # down the incline
    floor(14, 18, 20, 21)                       # the lift landing
    floor(9, 3, 10, 8)                          # a side tunnel, collapsed
    m.rect(9, 3, 10, 5, "mine_floor", 0, prop="small_rocks")
    m.rect(8, 2, 11, 2, "mine_floor", 0, prop="grey_boulders")
    floor(18, 21, 20, 23)                       # collapsed south drift
    m.rect(18, 22, 20, 23, "mine_floor", 0, prop="small_rocks")
    m.patches("grey_rock", ["mine_floor"], 3, 0.55, 401, (12, 6, 20, 22))  # the grey creeping in
    m.road([(2, 14), (8, 14)], 1, "slab")       # rails
    m.road([(10, 14), (13, 14), (13, 11), (16, 11), (16, 19)], 1, "slab")
    m.add_decor("cart", 7, 15, "Abandoned Ore Cart")
    m.add_decor("crates", 12, 9)
    m.add_decor("cart", 20, 19, "Mine Lift")
    m.put(*LIFT_DOWN, t="slab", prop=None)
    m.landmarks.append(("Mine Lift", 18, 20))
    m.scatter("small_rocks", 0.05, ["mine_floor", "grey_rock"], 403, (8, 7, 19, 20))
    m.enemy("human_husk", 11, 12, level=8)
    m.enemy("human_husk", 10, 17, level=8)
    m.enemy("human_husk", 17, 9, level=8)
    m.enemy("human_husk", 16, 16, level=8)
    m.graveyards += [(2, 15)]
    m.spawns += [(3, 14), (3, 15), (2, 14), (4, 14)]

    # 2. Deep seams.
    floor(24, 18, 33, 24)                       # the lift's foot
    floor(30, 6, 43, 17)                        # the seam hall
    floor(28, 12, 30, 18)                       # its west door
    m.rect(33, 7, 38, 11, "grey_rock", 2)       # a ledge (worked out, grey)
    m.rect(34, 12, 35, 12, "grey_rock", 1)      # its ramp
    m.rect(39, 13, 42, 16, "mine_floor", 3)     # a high seam face
    m.rect(38, 14, 38, 15, "mine_floor", 2)
    m.rect(37, 14, 37, 15, "mine_floor", 1)
    for p in [(31, 9), (36, 15), (41, 9), (32, 15)]:   # pillars left standing
        m.put(p[0], p[1], "mine_wall", 6, prop=None)
    floor(43, 14, 46, 15)                       # the drift to the chamber
    # Seams: gold where untouched (north-east), grey where mined out (west).
    for y in range(m.d):
        for x in range(23, 45):
            if m.T[y][x] != "mine_wall" or m.H[y][x] < 6:
                continue
            near = any(m.inside(x + dx, y + dy) and m.T[y + dy][x + dx] in ("mine_floor", "grey_rock")
                       for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)])
            if near and h32(x, y, 405) % 3 == 0:
                m.put(x, y, "sunstone" if x >= 37 else "spent_seam")
    m.scatter("sunstone_clusters", 0.06, ["mine_floor"], 407, (37, 6, 43, 17))
    m.scatter("grey_clusters", 0.06, ["grey_rock", "mine_floor"], 409, (24, 6, 36, 24))
    m.patches("grey_rock", ["mine_floor"], 3, 0.5, 411, (24, 18, 33, 24))
    m.put(*LIFT_UP, t="slab", prop=None)
    m.add_decor("cart", 23, 20, "Mine Lift")
    m.enemy("human_husk", 31, 13, level=9)
    m.enemy("human_husk", 35, 9, level=9)       # on the ledge
    m.enemy("human_husk", 40, 14, level=9)      # on the high face
    m.enemy("human_husk", 41, 8, level=9)
    # The side chamber (optional): south of the seam hall, behind a narrow cut.
    floor(36, 17, 36, 20)
    floor(33, 21, 42, 26, "mine_floor", 0)
    m.scatter("sunstone_clusters", 0.12, ["mine_floor"], 413, (33, 21, 42, 26))
    m.add_decor("crates", 41, 25, "Overseer's Strongbox")
    m.enemy("grey_overseer", 38, 24)
    m.landmarks.append(("Old Shift Office", 36, 22))

    # 3. The Foreman's chamber.
    floor(47, 4, 64, 26, "grey_rock", 0)
    floor(46, 13, 47, 16, "mine_floor", 0)
    m.rect(58, 11, 63, 19, "grey_rock", 1)       # the dais of the Heart
    for p in [(51, 8), (51, 22), (56, 6), (56, 24)]:
        m.put(p[0], p[1], "mine_wall", 6, prop=None)
    for y in range(3, 28):                       # black-gold seams all round the chamber
        for x in range(46, 66):
            if m.T[y][x] == "mine_wall" and m.H[y][x] == 6 and h32(x, y, 415) % 2 == 0:
                m.put(x, y, "sunstone" if h32(x, y, 417) % 3 else "spent_seam")
    m.enemy("foreman", 56, 15)
    m.enemy("grey_heart", 61, 15)
    m.landmarks.append(("The Foreman's Chamber", 49, 15))
    return m


m = silent_shaft()
write(m)
# The parts make_act1_zones.py's writer doesn't know: exits, the dungeon flags, the encounter.
path = os.path.join(root, "content/zones/silent_shaft.tres")
text = open(path).read()
head, rest = text.split("\n\n", 1)
ext = ['[ext_resource type="Script" path="res://data/defs/zone_exit.gd" id="s_exit"]',
       '[ext_resource type="Resource" path="res://content/encounters/foreman.tres" id="enc_foreman"]']
exits = [((1, 15), "deepcut", (34, 12)), (LIFT_DOWN, "", ARRIVE_DOWN), (LIFT_UP, "", ARRIVE_UP)]
subs = []
for i, (tile, to, to_tile) in enumerate(exits):
    s = '[sub_resource type="Resource" id="exit_%d"]\nscript = ExtResource("s_exit")\ntile = %s' % (i, v2(tile))
    if to:
        s += '\nto_zone = &"%s"' % to
    s += "\nto_tile = %s" % v2(to_tile)
    subs.append(s)
first_sub = rest.index("[sub_resource")
rest = rest[:first_sub] + "\n\n".join(subs) + "\n\n" + rest[first_sub:]
text = head + "\n\n" + "\n".join(ext) + "\n" + rest
text = text.rstrip("\n") + "\n" + "\n".join([
    'exits = Array[ExtResource("s_exit")]([%s])' % ", ".join('SubResource("exit_%d")' % i for i in range(len(exits))),
    "dungeon = true",
    'requires_quest = &"act1_07_the_silent_shaft"',
    'encounter = ExtResource("enc_foreman")',
]) + "\n"
open(path, "w").write(text)
print("added exits, dungeon flags and the encounter")
