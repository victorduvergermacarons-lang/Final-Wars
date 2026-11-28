"""One-off (2026-11-28, fire physics phase 3): behavior files for the eight Fire abilities
that weren't built (F10, F11, F12, F14, F15, F16, F18, F23) and their buffs. Numbers are
mine (approved defaults: "build gameplay for the 8 unbuilt abilities"); tune them in the
files afterwards. Run once: python3 tools/once/make_fire_behaviors.py
"""
import os

EFF = 'res://data/defs/ability_effect.gd'
DEF = 'res://data/defs/ability_def.gd'
BUFF = 'res://data/defs/buff_def.gd'
MOD = 'res://data/defs/stat_modifier.gd'


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write(text)
    print('wrote', path)


def dmg(sid, power, extra=''):
    return f'''[sub_resource type="Resource" id="{sid}"]
script = ExtResource("e")
damage_type = 1
base_amount = -1.0
sheet_scaling = true
power = {power}
{extra}
'''


HEAD = '''[gd_resource type="Resource" script_class="AbilityDef" format=3]

[ext_resource type="Script" path="%s" id="e"]
[ext_resource type="Script" path="%s" id="d"]
''' % (EFF, DEF)


def ability(aid, body, subs, extra_ext=''):
    return HEAD + extra_ext + '\n' + subs + '\n[resource]\nscript = ExtResource("d")\nid = &"%s"\n' % aid + body


# --- buffs ---------------------------------------------------------------
write('content/buffs/overheat_burn.tres', f'''[gd_resource type="Resource" script_class="BuffDef" format=3]

[ext_resource type="Script" path="{BUFF}" id="b"]
[ext_resource type="Resource" path="res://content/abilities/overheat_burst.tres" id="x"]

[resource]
script = ExtResource("b")
id = &"overheat_burn"
display_name = "Overheated"
duration_seconds = 8.0
is_debuff = true
ramps = true
end_ability = ExtResource("x")
end_radius = 1.5
''')
write('content/buffs/breath_scorched.tres', f'''[gd_resource type="Resource" script_class="BuffDef" format=3]

[ext_resource type="Script" path="{MOD}" id="m"]
[ext_resource type="Script" path="{BUFF}" id="b"]

[sub_resource type="Resource" id="mod_0"]
script = ExtResource("m")
stat = 5
flat = -15.0

[resource]
script = ExtResource("b")
id = &"breath_scorched"
display_name = "Scorched (Magic Defense down)"
duration_seconds = 8.0
modifiers = Array[ExtResource("m")]([SubResource("mod_0")])
is_debuff = true
''')
write('content/buffs/jet_propulsion.tres', f'''[gd_resource type="Resource" script_class="BuffDef" format=3]

[ext_resource type="Script" path="{BUFF}" id="b"]

[resource]
script = ExtResource("b")
id = &"jet_propulsion"
display_name = "Jet Propulsion"
duration_seconds = 3.0
flies = true
''')

# --- part abilities (sub abilities in their own files, so buffs can point at them) ----
write('content/abilities/overheat_burst.tres', ability('overheat_burst', 'effects = Array[ExtResource("e")]([SubResource("a")])\ntargeting = 1\ntree = "Fire"\ntier = 2\n',
      dmg('a', 0.8)))
write('content/abilities/phoenix_kick_landing.tres', ability('phoenix_kick_landing', 'effects = Array[ExtResource("e")]([SubResource("a")])\ntargeting = 1\ntree = "Fire"\ntier = 3\n',
      dmg('a', 1.3)))

# --- the eight abilities -------------------------------------------------------
# F12 Fire Stream: a 2 s channelled line, 8 ticks; its reach grows with Fire Mastery
write('content/tree/behaviors/F12.tres', ability('F12', '''mana_cost = 15.0
effects = Array[ExtResource("e")]([SubResource("a")])
targeting = 2
channel_seconds = 2.0
channel_tick_seconds = 0.25
reach_by_mastery = Vector2(2.25, 5.75)
''', dmg('a', 0.2, 'can_crit = false')))
# F23 Overheat: a burn growing each second for 8 s, bursting within 1 tile at the end
write('content/tree/behaviors/F23.tres', ability('F23', '''max_range = 6
mana_cost = 12.0
effects = Array[ExtResource("e")]([SubResource("a")])
targeting = 1
''', '''[sub_resource type="Resource" id="a"]
script = ExtResource("e")
kind = 8
damage_type = 1
base_amount = -1.0
sheet_scaling = true
can_crit = false
buff = ExtResource("ob")
power = 1.2
''', '[ext_resource type="Resource" path="res://content/buffs/overheat_burn.tres" id="ob"]\n'))
# F11 Jet Propulsion: fly 3 s
write('content/tree/behaviors/F11.tres', ability('F11', '''target = 0
max_range = 0
mana_cost = 15.0
effects = Array[ExtResource("e")]([SubResource("a")])
targeting = 4
''', '''[sub_resource type="Resource" id="a"]
script = ExtResource("e")
kind = 4
applies = 1
buff = ExtResource("jb")
''', '[ext_resource type="Resource" path="res://content/buffs/jet_propulsion.tres" id="jb"]\n'))
# F15 Phoenix Kick: leap 0.5 s to 1 tile short of the target, crash down within 1.5 tiles
write('content/tree/behaviors/F15.tres', ability('F15', '''max_range = 6
mana_cost = 15.0
effects = Array[ExtResource("e")]([SubResource("a")])
targeting = 1
landing_ability = ExtResource("land")
landing_radius = 1.5
''', '''[sub_resource type="Resource" id="a"]
script = ExtResource("e")
kind = 14
applies = 1
base_amount = 1.0
duration_seconds = 0.5
''', '[ext_resource type="Resource" path="res://content/abilities/phoenix_kick_landing.tres" id="land"]\n'))
# F10 Flame Wheel: a spinning kick on everyone around you
write('content/tree/behaviors/F10.tres', ability('F10', '''target = 0
max_range = 0
mana_cost = 12.0
effects = Array[ExtResource("e")]([SubResource("a")])
targeting = 4
''', dmg('a', 1.0)))
# F16 Inferno: a circle of half-tile blocks, warned 0.75 s, burning 4 s
write('content/tree/behaviors/F16.tres', ability('F16', '''max_range = 8
mana_cost = 25.0
effects = Array[ExtResource("e")]([SubResource("z")])
targeting = 3
telegraph_seconds = 0.75
block_circle = 2.5
''', '''[sub_resource type="Resource" id="burn_d"]
script = ExtResource("e")
damage_type = 1
base_amount = -1.0
sheet_scaling = true
can_crit = false
power = 0.5

[sub_resource type="Resource" id="burn"]
script = ExtResource("d")
id = &"F16_burn"
effects = Array[ExtResource("e")]([SubResource("burn_d")])
targeting = 1
tree = "Fire"
tier = 4

[sub_resource type="Resource" id="z"]
script = ExtResource("e")
kind = 17
applies = 2
duration_seconds = 4.0
zone_ability = SubResource("burn")
'''))
# F14 Breath of Fire: a cone (about 5 tiles), Magic Defense down 8 s
write('content/tree/behaviors/F14.tres', ability('F14', '''mana_cost = 18.0
effects = Array[ExtResource("e")]([SubResource("a"), SubResource("b")])
targeting = 2
aim = 1
''', dmg('a', 1.2) + '''
[sub_resource type="Resource" id="b"]
script = ExtResource("e")
kind = 4
buff = ExtResource("sc")
''', '[ext_resource type="Resource" path="res://content/buffs/breath_scorched.tres" id="sc"]\n'))
# F18 Combustion Blast: marked 1 s, then a huge blast within 1.5 tiles
write('content/tree/behaviors/F18.tres', ability('F18', '''max_range = 12
mana_cost = 25.0
effects = Array[ExtResource("e")]([SubResource("a")])
targeting = 3
telegraph_seconds = 1.0
''', dmg('a', 2.2)))
