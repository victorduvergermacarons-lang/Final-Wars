"""One-off (2026-11-28, water physics phase 4): design/Ability_Tree.xlsx, Abilities tab,
patched as XML so the sheet's formulas keep their cached results.

- Water Whip (W02) and Frost Shard (W04): instant (user brief); Frost Shard cooldown 1.5 s.
- Healing Touch (W01) and Leeching Tide (W07): no bar; their timings are the approved
  demos' fixed ones (heal 1.2 s after the cast; a 0.4 s reach, then a 3 s channel).
- Effect texts: Healing Touch, Water Shield, Frost Shard and Leeching Tide as reworked.

Run once (it sets cells; running it again changes nothing), then re-import:
    python3 tools/once/water_physics_sheet.py
    godot --headless --path . -s res://tools/import_ability_tree.gd
"""
import re
import shutil
import tempfile
import zipfile
from xml.sax.saxutils import escape

SHEET = "design/Ability_Tree.xlsx"
ABILITIES = "xl/worksheets/sheet1.xml"

INSTANT = {"Timing Status": "Manual", "Timing Bar (s)": "none", "Timing Zones": ""}
CHANGES = {
    "W02": dict(INSTANT, **{"Timing Notes": "Instant since 2026-11-28 (water physics): the whole rope is thrown; a second press within 1.5 s decides how much water comes back (100% at 0.5 s, 50% at once, 0% at 1.5 s or no press)."}),
    "W01": dict(INSTANT, **{"Timing Notes": "No bar since 2026-11-28 (water physics): the rope winds round the target and the heal lands 1.2 s after the cast.",
                            "Effect": "Heal yourself or an ally within 4 tiles with the whole rope; what full health turns away comes back."}),
    "W04": dict(INSTANT, **{"Timing Notes": "Instant since 2026-11-28 (water physics): 4 points of the rope break off and freeze into the shard.",
                            "Cooldown (s)": "1.5",
                            "Effect": "Range 6; 4 points of your rope freeze into a shard that damages and slows the target for 2s."}),
    "W07": dict(INSTANT, **{"Timing Notes": "No bar since 2026-11-28 (water physics): a 0.4 s reach, then a 3 s channel ticking every 0.5 s.",
                            "Effect": "Latch onto an enemy within 5 tiles for 3s: damage every 0.5s, and each tick draws 4 water into your pouch (24 in all)."}),
    "W12": {"Effect": "Absorb shield on you or an ally for 20s, as strong as the water in your rope; it loses water as it absorbs. When it breaks it splashes damage on adjacent enemies and its water is lost; when it ends the rest comes back."},
}


def col_letter(n):
    s = ""
    while n:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


def main():
    z = zipfile.ZipFile(SHEET)
    files = {n: z.read(n) for n in z.namelist()}
    z.close()
    shared = re.findall(r"<si>(.*?)</si>", files.get("xl/sharedStrings.xml", b"").decode(), re.S)
    texts = ["".join(re.findall(r"<t[^>]*>(.*?)</t>", s, re.S)) for s in shared]
    xml = files[ABILITIES].decode()

    def cell_text(c):
        v = re.search(r"<v>(.*?)</v>", c)
        if 't="s"' in c and v:
            return texts[int(v.group(1))]
        t = re.search(r"<t[^>]*>(.*?)</t>", c, re.S)
        return t.group(1) if t else (v.group(1) if v else "")

    header = re.search(r'<row r="1".*?</row>', xml, re.S).group(0)
    cols = {}
    for c in re.findall(r"<c [^>]*?(?:/>|>.*?</c>)", header, re.S):
        ref = re.search(r'r="([A-Z]+)1"', c).group(1)
        cols[cell_text(c).replace("&amp;", "&")] = ref
    for name in {k for ch in CHANGES.values() for k in ch}:
        if name not in cols:
            raise SystemExit(f"no column '{name}' in the Abilities tab")

    def set_cell(row_xml, rownum, ref, value):
        cell_ref = f"{ref}{rownum}"
        m = re.search(rf'<c r="{cell_ref}"[^>]*?(?:/>|>.*?</c>)', row_xml, re.S)
        style = re.search(r's="(\d+)"', m.group(0)).group(1) if m and 's="' in m.group(0) else None
        st = f' s="{style}"' if style else ""
        if value == "":
            new = f'<c r="{cell_ref}"{st}/>'
        elif re.fullmatch(r"-?\d+(\.\d+)?", value):
            new = f'<c r="{cell_ref}"{st}><v>{value}</v></c>'
        else:
            new = f'<c r="{cell_ref}"{st} t="inlineStr"><is><t>{escape(value)}</t></is></c>'
        if m:
            return row_xml.replace(m.group(0), new)
        # Insert in column order.
        def colnum(r):
            n = 0
            for ch in r:
                n = n * 26 + ord(ch) - 64
            return n
        cells = list(re.finditer(r'<c r="([A-Z]+)\d+"[^>]*?(?:/>|>.*?</c>)', row_xml, re.S))
        for c in cells:
            if colnum(c.group(1)) > colnum(ref):
                return row_xml[:c.start()] + new + row_xml[c.start():]
        return row_xml.replace("</row>", new + "</row>")

    done = set()
    for row in re.findall(r'<row r="\d+".*?</row>', xml, re.S):
        rownum = re.search(r'<row r="(\d+)"', row).group(1)
        first = re.search(rf'<c r="A{rownum}"[^>]*?(?:/>|>.*?</c>)', row, re.S)
        if not first:
            continue
        rid = cell_text(first.group(0)).strip()
        if rid in CHANGES:
            new_row = row
            for name, value in CHANGES[rid].items():
                new_row = set_cell(new_row, rownum, cols[name], value)
            xml = xml.replace(row, new_row)
            done.add(rid)
    if done != set(CHANGES):
        raise SystemExit(f"rows not found: {set(CHANGES) - done}")
    files[ABILITIES] = xml.encode()
    tmp = tempfile.mktemp(suffix=".xlsx")
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as out:
        for n, data in files.items():
            out.writestr(n, data)
    shutil.move(tmp, SHEET)
    print("patched", ", ".join(sorted(done)))


if __name__ == "__main__":
    main()
