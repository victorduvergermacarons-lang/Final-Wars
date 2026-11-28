"""One-off (2026-11-28, water physics follow-up): Frost Shard (W04) cooldown 0.5 s (a third
of 1.5 s, user request); its damage is a third too (behaviour file, power 0.3). Patched
as XML like water_physics_sheet.py.

    python3 tools/once/water_physics_sheet_2.py
    godot --headless --path . -s res://tools/import_ability_tree.gd
"""
import sys

sys.path.insert(0, "tools/once")
import water_physics_sheet as w  # noqa: E402

w.CHANGES = {"W04": {"Cooldown (s)": "0.5",
                     "Timing Notes": "Instant since 2026-11-28 (water physics): 4 points of the rope break off and freeze into the shard. Cooldown 0.5 s and a third of the damage since the follow-up (user)."}}

if __name__ == "__main__":
    w.main()
