"""One-off (2026-11-23, stance rework, user request): every Fire, Earth and Air ability
unlocks at the same Mastery as the Water ability in its stance slot (stance → branch).
Stances 2-5 already matched; in stance 1 Water's slots unlock at 0 / 0 / 25 / 50, so:
Fire Kick, Stone Skin, Gust 25 → 0; Sun Warrior's Breath, Raise Pillar, Air Step 50 → 25;
Scorch, Metal Shards 75 → 50; Air Blade 0 → 50.

Sets each row's Unlock Step and the cached result of its Mastery Required formula (the
formula itself is unchanged), patched as XML like the other sheet scripts, so the file
opens with the right numbers without being recalculated. Run once, then re-import:

    python3 tools/once/stance_copy_water_steps.py
    godot --headless --path . -s res://tools/import_ability_tree.gd
"""
import html
import re
import shutil
import tempfile
import zipfile

SHEET = "design/Ability_Tree.xlsx"
ABILITIES = "xl/worksheets/sheet1.xml"
POINTS = {1: 25, 2: 30, 3: 35, 4: 40, 5: 50}
BASE = {1: 0, 2: 100, 3: 225, 4: 375, 5: 550}


def main():
    z = zipfile.ZipFile(SHEET)
    files = {n: z.read(n) for n in z.namelist()}
    z.close()
    xml = files[ABILITIES].decode()
    header = re.search(r'<row r="1".*?</row>', xml, re.S).group(0)

    def text(c):
        t = re.search(r"<t[^>]*>(.*?)</t>", c, re.S)
        v = re.search(r"<v>(.*?)</v>", c, re.S)
        out = t.group(1) if t else (v.group(1) if v else "")
        return html.unescape(out)

    cols = {}
    for c in re.findall(r"<c [^>]*?(?:/>|>.*?</c>)", header, re.S):
        cols[text(c)] = re.search(r'r="([A-Z]+)1"', c).group(1)
    need = ["ID", "Tree", "Tier", "Mastery Required", "Key (stance → branch)", "Unlock Step"]
    rows = {}
    for row in re.findall(r'<row r="\d+".*?</row>', xml, re.S):
        n = re.search(r'<row r="(\d+)"', row).group(1)
        vals = {}
        for name in need:
            m = re.search(rf'<c r="{cols[name]}{n}"[^>]*?(?:/>|>.*?</c>)', row, re.S)
            vals[name] = text(m.group(0)) if m else ""
        if vals["ID"]:
            rows[vals["ID"]] = (n, row, vals)
    water = {}
    for _, (n, row, v) in rows.items():
        if v["Tree"] == "Water" and "→" in v["Key (stance → branch)"]:
            water[v["Key (stance → branch)"].replace(" ", "")] = int(float(v["Unlock Step"]))
    changed = []
    for rid, (n, row, v) in rows.items():
        key = v["Key (stance → branch)"].replace(" ", "")
        if v["Tree"] not in ("Fire", "Earth", "Air") or "→" not in key:
            continue
        step = water[key]
        if int(float(v["Unlock Step"])) == step:
            continue
        tier = int(float(v["Tier"]))
        new_row = re.sub(rf'(<c r="{cols["Unlock Step"]}{n}"[^>]*><v>)[^<]*(</v>)', rf"\g<1>{step}\g<2>", row)
        new_row = re.sub(rf'(<c r="{cols["Mastery Required"]}{n}"[^>]*>.*?<v>)[^<]*(</v>)',
                         rf"\g<1>{v['Tree']} Mastery {BASE[tier] + step * POINTS[tier]}\g<2>", new_row, flags=re.S)
        xml = xml.replace(row, new_row)
        changed.append(f"{rid} {v['Mastery Required']} -> {BASE[tier] + step * POINTS[tier]}")
    files[ABILITIES] = xml.encode()
    tmp = tempfile.mktemp(suffix=".xlsx")
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as out:
        for name, data in files.items():
            out.writestr(name, data)
    shutil.move(tmp, SHEET)
    print("\n".join(changed))


if __name__ == "__main__":
    main()
