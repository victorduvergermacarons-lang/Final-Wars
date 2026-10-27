# One-off (kept for the record): writes the Act I quests of milestones 3 and 4
# (1-01 to 1-07 and three side quests) as content/quests/<id>.tres. Their lines are in
# content/dialogue/act1.json. Edit the .tres files directly now; running this
# again overwrites them. Usage: python3 tools/once/make_act1_quests.py <project>
import sys

root = sys.argv[1]
KIND = {"kill": 0, "collect": 1, "talk": 2, "reach": 3, "escort": 4, "deliver": 5, "interact": 6, "investigate": 7}
MAIN, SIDE = 0, 1


def v2(p):
    return "Vector2i(%d, %d)" % p


def quest(qid, title, category, area, giver, objectives, xp, gold, turn_in="", prereq=(), min_level=1,
          given=(), items=(), choices=(), flag="", ends_act=0, return_zone=""):
    """objectives: dicts with kind, text and the kind's fields (count, enemy, item, npc,
    zone, tile, radius, path, spots). items/given: (item id, count) of plain .tres items;
    choices: ids of ability-tree items (built at load)."""
    ext = ['[ext_resource type="Script" path="res://data/defs/quest_objective.gd" id="1_obj"]',
           '[ext_resource type="Script" path="res://data/defs/quest_def.gd" id="2_quest"]',
           '[ext_resource type="Script" path="res://data/defs/item_def.gd" id="3_item"]']
    files = []
    for o in objectives:
        if o.get("item"):
            files.append(o["item"])
    files += [i for i, _ in given] + [i for i, _ in items]
    for f in dict.fromkeys(files):
        ext.append('[ext_resource type="Resource" path="res://content/items/%s.tres" id="item_%s"]' % (f, f))
    subs, refs = [], []
    for i, o in enumerate(objectives):
        sid = "Objective_%d" % i
        refs.append('SubResource("%s")' % sid)
        lines = ['[sub_resource type="Resource" id="%s"]' % sid, 'script = ExtResource("1_obj")',
                 "kind = %d" % KIND[o["kind"]], 'text = "%s"' % o["text"]]
        if o.get("count", 1) != 1:
            lines.append("count = %d" % o["count"])
        if o.get("enemy"):
            lines.append('enemy = &"%s"' % o["enemy"])
        if o.get("item"):
            lines.append('item = ExtResource("item_%s")' % o["item"])
        if o.get("npc"):
            lines.append('npc = &"%s"' % o["npc"])
        if o.get("zone"):
            lines.append('zone = &"%s"' % o["zone"])
        if o.get("tile"):
            lines.append("tile = %s" % v2(o["tile"]))
        if o.get("radius"):
            lines.append("radius = %d" % o["radius"])
        if o.get("path"):
            lines.append("path = Array[Vector2i]([%s])" % ", ".join(v2(p) for p in o["path"]))
        if o.get("spots"):
            lines.append("spots = Array[Vector2i]([%s])" % ", ".join(v2(p) for p in o["spots"]))
        subs.append("\n".join(lines))
    res = ['[resource]', 'script = ExtResource("2_quest")', 'id = &"%s"' % qid, 'title = "%s"' % title,
           "category = %d" % category, 'area = "%s"' % area, 'giver = &"%s"' % giver]
    if turn_in:
        res.append('turn_in = &"%s"' % turn_in)
    if prereq:
        res.append("prerequisites = Array[StringName]([%s])" % ", ".join('&"%s"' % p for p in prereq))
    if min_level > 1:
        res.append("min_level = %d" % min_level)
    res.append('objectives = Array[ExtResource("1_obj")]([%s])' % ", ".join(refs))
    if given:
        res.append('given_items = Array[ExtResource("3_item")]([%s])'
                   % ", ".join('ExtResource("item_%s")' % i for i, n in given for _ in range(n)))
    res += ["reward_xp = %d" % xp, "reward_gold = %d" % gold]
    if items:
        res.append('reward_items = Array[ExtResource("3_item")]([%s])'
                   % ", ".join('ExtResource("item_%s")' % i for i, n in items for _ in range(n)))
    if choices:
        res.append("reward_choice_ids = Array[StringName]([%s])" % ", ".join('&"%s"' % c for c in choices))
    if flag:
        res.append('sets_world_flag = &"%s"' % flag)
    if ends_act:
        res += ["ends_act = %d" % ends_act, 'return_zone = &"%s"' % return_zone]
    text = '[gd_resource type="Resource" script_class="QuestDef" format=3]\n\n' + "\n".join(ext) + "\n\n"
    text += "\n\n".join(subs) + "\n\n" + "\n".join(res) + "\n"
    with open("%s/content/quests/%s.tres" % (root, qid), "w") as f:
        f.write(text)
    print("wrote", qid)


Q01, Q02, Q03, Q04, Q05, Q06 = ("act1_01_guild_comes_to_millbrook", "act1_02_applicants_wanted",
                                "act1_03_wells_for_the_windsteppe", "act1_04_grain_for_deepcut",
                                "act1_05_fever_in_millbrook", "act1_06_recognition")

quest(Q01, "1-01 The Guild Comes to Millbrook", MAIN, "Millbrook", "maren_voss_field", [
    {"kind": "kill", "text": "Wolves driven off the fields", "count": 3, "enemy": "wolf"},
    {"kind": "kill", "text": "Boars driven off the fields", "count": 2, "enemy": "boar"},
], xp=120, gold=15, items=[("minor_health_potion", 2)],
    choices=["pebble_scroll", "open_palm_scroll", "hunters_shortbow"])

quest(Q02, "1-02 Applicants Wanted", MAIN, "The Crossing", "maren_voss", [
    {"kind": "talk", "text": "Register with Warden Dorne at the Guild Hall", "npc": "warden_dorne"},
    {"kind": "talk", "text": "Draw a Guild kit from the quartermaster", "npc": "guild_quartermaster"},
], xp=150, gold=20, prereq=[Q01], min_level=2, items=[("minor_mana_potion", 2)],
    choices=["spark_scroll", "river_lash_scroll", "iron_mallet"])

quest(Q03, "1-03 Wells for the Windsteppe", MAIN, "Windsteppe", "maren_voss", [
    {"kind": "escort", "text": "Escort the well-diggers to Tsaga's Camp", "npc": "well_diggers", "zone": "windsteppe",
     "path": [(40, 21), (28, 22), (21, 22), (17, 23)]},
    {"kind": "kill", "text": "Iron wolves driven off", "count": 4, "enemy": "iron_wolf"},
], xp=400, gold=40, turn_in="saran", prereq=[Q02], min_level=3, items=[("minor_health_potion", 2)],
    choices=["breeze_scroll", "frost_shard_scroll", "travelers_longsword"])

quest(Q04, "1-04 Grain for Deepcut", MAIN, "Road to Deepcut", "guild_board", [
    {"kind": "escort", "text": "Escort the grain wagon to Deepcut's end of the road", "npc": "grain_caravan",
     "zone": "deepcut_road", "path": [(19, 10), (21, 7), (37, 8), (40, 10), (55, 10)]},
], xp=450, gold=40, turn_in="steward_brann", prereq=[Q02], min_level=3, items=[("minor_health_potion", 2)],
    choices=["cinder_kick_scroll", "stomp_scroll", "yew_longbow"])

quest(Q05, "1-05 Fever in Millbrook", MAIN, "Millbrook", "guild_board", [
    {"kind": "talk", "text": "Ask Odo the Apothecary for healers", "npc": "apothecary_odo"},
    {"kind": "deliver", "text": "Fever draughts brought to Healer Wenna", "count": 3, "item": "fever_draught",
     "npc": "healer_wenna"},
    {"kind": "investigate", "text": "The grey river examined in Millbrook", "zone": "town", "spots": [(23, 27)]},
    {"kind": "investigate", "text": "The grey stream examined on the Road to Deepcut", "zone": "deepcut_road",
     "spots": [(34, 16)]},
    {"kind": "investigate", "text": "The stream's source found in Deepcut", "zone": "deepcut", "spots": [(32, 21)]},
], xp=450, gold=40, turn_in="healer_wenna", prereq=[Q02], min_level=3, given=[("fever_draught", 3)],
    items=[("minor_health_potion", 2), ("minor_mana_potion", 2)],
    choices=["featherstep_scroll", "pillar_scroll", "quarry_maul"])

quest(Q06, "1-06 Recognition", MAIN, "The Crossing", "maren_voss", [
    {"kind": "talk", "text": "Hear out Prince Caedan Ashvale", "npc": "caedan_ashvale"},
], xp=450, gold=60, turn_in="caedan_ashvale", prereq=[Q03, Q04, Q05], min_level=6,
    choices=["sun_warriors_breath_scroll", "scroll_of_the_current", "travelers_longsword"], flag="brann_descended")

quest("act1_side_the_white_death", "The White Death", SIDE, "Windsteppe", "saran", [
    {"kind": "collect", "text": "Iron wolf pelts", "count": 4, "item": "iron_wolf_pelt"},
    {"kind": "deliver", "text": "Winter stores brought to Elder Tsaga", "item": "winter_stores", "npc": "elder_tsaga"},
], xp=300, gold=30, prereq=[Q03], min_level=4, given=[("winter_stores", 1)],
    items=[("minor_health_potion", 3)])

quest("act1_side_shift_bell", "Shift Bell", SIDE, "Deepcut", "mine_board", [
    {"kind": "interact", "text": "Rubble cleared from the collapsed shaft", "npc": "collapsed_shaft"},
    {"kind": "kill", "text": "Husks put down", "count": 3, "enemy": "human_husk"},
    {"kind": "talk", "text": "Bring Miner Ostrik out", "npc": "trapped_miner"},
], xp=350, gold=45, turn_in="trapped_miner", prereq=[Q04], min_level=6, items=[("minor_health_potion", 2)])

quest("act1_side_pins_on_the_map", "Pins on the Map", SIDE, "The Crossing", "guild_board", [
    {"kind": "reach", "text": "Millbrook's grey river visited", "zone": "town", "tile": (22, 20), "radius": 2},
    {"kind": "reach", "text": "Tsaga's Camp visited", "zone": "windsteppe", "tile": (15, 21), "radius": 2},
    {"kind": "reach", "text": "The ambush on the Road to Deepcut visited", "zone": "deepcut_road", "tile": (31, 9),
     "radius": 2},
    {"kind": "reach", "text": "Deepcut's tailings pond visited", "zone": "deepcut", "tile": (32, 21), "radius": 2},
    {"kind": "interact", "text": "Every site marked on the Guild Map", "npc": "guild_map"},
], xp=500, gold=40, turn_in="maren_voss", prereq=[Q06], min_level=7, items=[("minor_mana_potion", 2)])

quest("act1_07_the_silent_shaft", "1-07 The Silent Shaft", MAIN, "The Silent Shaft", "caedan_ashvale", [
    {"kind": "reach", "text": "Ride the lift down to the deep seams", "zone": "silent_shaft", "tile": (26, 21),
     "radius": 3},
    {"kind": "reach", "text": "Find where the silence comes from", "zone": "silent_shaft", "tile": (49, 15), "radius": 2},
    {"kind": "kill", "text": "Break the Grey Heart", "enemy": "grey_heart"},
    {"kind": "talk", "text": "Speak with Prince Caedan", "npc": "caedan_shaft"},
], xp=1200, gold=120, turn_in="caedan_shaft", prereq=[Q06], min_level=8,
    items=[("minor_health_potion", 3), ("minor_mana_potion", 3)],
    choices=["scroll_of_the_fireball", "glacier_scroll", "bulwark_scroll"], flag="act1_complete", ends_act=1,
    return_zone="crossing")
