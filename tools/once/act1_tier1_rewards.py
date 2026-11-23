"""One-off (2026-11-23, stance rework, user decision): during all of Act I only tier-1
scrolls drop or are given; beating the Silent Shaft (the Foreman) brings the first
tier-2 drop. Each later scroll in an Act I loot table becomes a built tier-1 scroll of
the same element (chances unchanged); the Foreman drops the built tier-2 scrolls;
shops drop Scroll of the Current (Flow State is tier 3) and sell Scorch Scroll; quest
rewards: see QUESTS below.

    python3 tools/once/act1_tier1_rewards.py
"""
import glob
import re

TIER1 = {
    "lash_of_embers_scroll": "spark_scroll",              # Fire Whip -> Fire Dart
    "scroll_of_burning_feet": "sun_warriors_breath_scroll",  # Flame Dash -> Sun Warrior's Breath
    "scroll_of_the_fireball": "scorch_scroll",            # Fireball -> Scorch
    "scorched_earth_scroll": "cinder_kick_scroll",        # Burning Ground -> Fire Kick
    "blazing_fist_scroll": "ember_fist_scroll",           # Blazing Combo -> Fire Punch
    "mist_scroll": "menders_scroll",                      # Soothing Mist -> Healing Touch
    "leech_tide_scroll": "river_lash_scroll",             # Leeching Tide -> Water Whip
    "tidal_scroll": "frost_shard_scroll",                 # Tidal Blessing -> Frost Shard
    "wave_scroll": "river_lash_scroll",                   # Water Pulse -> Water Whip
    "glacier_scroll": "frost_shard_scroll",               # Ice Spikes -> Frost Shard
    "gale_scroll": "breeze_scroll",                       # Air Blast -> Gust
    "bulwark_scroll": "pillar_scroll",                    # Earth Wall -> Raise Pillar
}
FOREMAN_TIER2 = ["blazing_fist_scroll", "scorched_earth_scroll", "mist_scroll", "leech_tide_scroll", "tidal_scroll"]
FOREMAN_CHANCE = 0.2


def loot():
    for path in sorted(glob.glob("content/loot/*.tres")):
        s = open(path).read()
        if path.endswith("foreman.tres"):
            # Its three scroll entries become five tier-2 ones.
            entries = re.findall(r'\[sub_resource type="Resource" id="(Resource_e\d+)"\]\nscript = ExtResource\("1_entry"\)\nitem_id = &"[a-z_]+"\nchance = [0-9.]+\n\n', s)
            body = re.sub(r'\[sub_resource type="Resource" id="Resource_e\d+"\]\nscript = ExtResource\("1_entry"\)\nitem_id = &"[a-z_]+"\nchance = [0-9.]+\n\n', "", s)
            new = "".join(f'[sub_resource type="Resource" id="Resource_t2_{i}"]\nscript = ExtResource("1_entry")\n'
                          f'item_id = &"{item}"\nchance = {FOREMAN_CHANCE}\n\n' for i, item in enumerate(FOREMAN_TIER2))
            body = body.replace('[sub_resource type="Resource" id="Resource_e3"]', new + '[sub_resource type="Resource" id="Resource_e3"]', 1)
            for e in entries:
                body = body.replace(f'SubResource("{e}"), ', "").replace(f'SubResource("{e}")', "")
            refs = ", ".join(f'SubResource("Resource_t2_{i}")' for i in range(len(FOREMAN_TIER2)))
            body = body.replace('entries = Array[ExtResource("1_entry")]([', f'entries = Array[ExtResource("1_entry")]([{refs}, ', 1)
            open(path, "w").write(body)
            print("foreman: tier-2", ", ".join(FOREMAN_TIER2))
            continue
        changed = []
        for old, new in TIER1.items():
            if f'&"{old}"' in s:
                s = s.replace(f'&"{old}"', f'&"{new}"')
                changed.append(f"{old} -> {new}")
        if changed:
            open(path, "w").write(s)
            print(path, "; ".join(changed))


def shops():
    for name in ["hilda", "trader_tamsin", "guild_quartermaster"]:
        path = f"content/npcs/{name}.tres"
        s = open(path).read()
        assert '&"scroll_of_the_current"' in s, path
        s = s.replace('&"scroll_of_the_current"', '&"scorch_scroll"')
        open(path, "w").write(s)
        print(path, "scroll_of_the_current -> scorch_scroll")


## Quest rewards: the Act I element scrolls (1-04 and 1-06, per element) and the two
## finales' choices, tier 1 only. Water and Air have no third built tier-1 scroll, so
## their 1-06 scroll waits for Water Shield / Air Blade (nothing given meanwhile).
QUESTS = {
    "act1_04_grain_for_deepcut": {"mist_scroll": "frost_shard_scroll"},
    "act1_06_recognition": {"tidal_scroll": None, "gale_scroll": None},
    "act1_07_the_silent_shaft": {"scroll_of_the_fireball": "scorch_scroll", "glacier_scroll": "frost_shard_scroll",
                                 "bulwark_scroll": "pillar_scroll"},
    "beast_of_greenfields": {"scroll_of_the_fireball": "scorch_scroll", "glacier_scroll": "frost_shard_scroll",
                             "bulwark_scroll": "pillar_scroll"},
}


def quests():
    for qid, swaps in QUESTS.items():
        path = f"content/quests/{qid}.tres"
        s = open(path).read()
        for old, new in swaps.items():
            assert f'&"{old}"' in s, (path, old)
            if new is None:
                s = re.sub(rf',\s*&"{old}"|&"{old}",\s*|&"{old}"', "", s, count=1)
            else:
                s = s.replace(f'&"{old}"', f'&"{new}"')
        open(path, "w").write(s)
        print(path, swaps)


if __name__ == "__main__":
    loot()
    shops()
    quests()
