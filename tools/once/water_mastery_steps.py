"""Water tree: per-ability Mastery requirements (user request, 2026-11-15).

Patches design/Ability_Tree.xlsx in place, editing its XML directly (openpyxl
would drop the cached results of the sheet's formulas, which the importer reads):
- Abilities tab, column E (Mastery Required): the 23 Water rows get fixed text
  "Water Mastery N" instead of the tier formula;
- column H (Prerequisites): prerequisites that would unlock after the ability are
  removed (Tidal Blessing, Water Shield and Revive keep none);
- xl/calcChain.xml (Excel's list of formula cells, rebuilt by Excel on open) is
  removed, since it would still list the replaced formulas.

Run from the project root: python3 tools/once/water_mastery_steps.py
Then re-import: godot --headless --path . -s res://tools/import_ability_tree.gd
"""
import re
import shutil
import zipfile

PATH = "design/Ability_Tree.xlsx"
STEPS = {  # ability name -> Water Mastery required
    "Water Whip": 0, "Healing Touch": 0, "Water Shield": 20, "Soothing Mist": 40,
    "Tidal Blessing": 65, "Frost Shard": 90, "Revive": 120, "Leeching Tide": 150,
    "Spirit Water": 185, "Flow State": 220, "Water Pulse": 260, "Ice Spikes": 300,
    "Water Jet": 345, "Healing Rain": 390, "Ice Prison": 440, "Rising Tide": 490,
    "Tidal Wave": 545, "Steam Veil": 600, "Ocean Spirit": 655, "Bloodbending": 715,
    "Octopus Form": 775, "Full Moon": 835, "Tidal Resurgence": 900,
}

zin = zipfile.ZipFile(PATH)
sheet = zin.read("xl/worksheets/sheet1.xml").decode("utf-8")
shared = [re.sub(r"<[^>]+>", "", x) for x in
          re.findall(r"<si>(.*?)</si>", zin.read("xl/sharedStrings.xml").decode("utf-8"), re.S)]


def cell_text(row: int, col: str) -> str:
    m = re.search(r'<c r="%s%d"([^>]*?)(?:/>|>(.*?)</c>)' % (col, row), sheet, re.S)
    if not m or not m.group(2):
        return ""
    attrs, inner = m.group(1), m.group(2)
    if "inlineStr" in attrs:
        return re.search(r"<t[^>]*>(.*?)</t>", inner).group(1)
    v = re.search(r"<v>(.*?)</v>", inner)
    v = v.group(1) if v else ""
    return shared[int(v)] if 't="s"' in attrs else v


def set_text(row: int, col: str, text: str) -> None:
    global sheet
    pat = re.compile(r'<c r="%s%d"( s="\d+")?[^>]*?(?:/>|>.*?</c>)' % (col, row), re.S)
    m = pat.search(sheet)
    assert m, (col, row)
    style = m.group(1) or ""
    new = '<c r="%s%d"%s t="inlineStr"><is><t>%s</t></is></c>' % (col, row, style, text)
    sheet = sheet[:m.start()] + new + sheet[m.end():]


rows = {}  # name -> row
for r in range(2, 400):
    if cell_text(r, "B") == "Water" and cell_text(r, "F"):
        rows[cell_text(r, "F")] = r
assert set(rows) == set(STEPS), set(rows) ^ set(STEPS)

for name, need in STEPS.items():
    set_text(rows[name], "E", "Water Mastery %d" % need)
for name, r in rows.items():
    text = cell_text(r, "H")
    if text in ("", "—", "-"):
        continue
    keep = []
    for part in [p.strip() for p in text.split(";") if p.strip()]:
        if part in STEPS and STEPS[part] > STEPS[name]:
            print("%s: drops prerequisite %s (unlocks at %d, after %d)" % (name, part, STEPS[part], STEPS[name]))
            continue
        keep.append(part)
    if keep != [p.strip() for p in text.split(";") if p.strip()]:
        set_text(r, "H", "; ".join(keep) if keep else "—")

tmp = PATH + ".tmp"
with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
    for info in zin.infolist():
        if info.filename == "xl/calcChain.xml":
            continue
        data = zin.read(info.filename)
        if info.filename == "xl/worksheets/sheet1.xml":
            data = sheet.encode("utf-8")
        elif info.filename == "[Content_Types].xml":
            data = re.sub(rb'<Override PartName="/xl/calcChain.xml"[^>]*/>', b"", data)
        elif info.filename == "xl/_rels/workbook.xml.rels":
            data = re.sub(rb'<Relationship [^>]*Target="calcChain.xml"/>', b"", data)
        zout.writestr(info, data)
zin.close()
shutil.move(tmp, PATH)
print("patched", len(STEPS), "Water rows")
