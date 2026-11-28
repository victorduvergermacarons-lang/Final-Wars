"""Threat and tanking merged into the stance rework (2026-11-25): marks the Earth
tanking abilities built on the threat-tanking branch as built on the stance sheet.
The stance sheet's own Effect, Cooldown and stance keys stay (it is the newer design);
only the timing columns of the four newly built instants and Rock Throw's note change.
Patches design/Ability_Tree.xlsx's XML in place (inline strings; no shared strings).
Run from the project root: python3 tools/once/earth_tanking_stances.py
Then re-import: godot --headless --path . -s res://tools/import_ability_tree.gd
"""
import re
import shutil
import zipfile

PATH = "design/Ability_Tree.xlsx"
GENERATED = "Generated (AI, not yet confirmed)"
CHANGES = {
    "E01": {"T": "Threat x3: the Stone Guard's ranged opener."},
    "E07": {"U": GENERATED, "V": "none", "X": "No bar: a self shield."},
    "E08": {"U": GENERATED, "V": "none", "X": "No bar: a taunt."},
    "E14": {"U": GENERATED, "V": "none", "X": "No bar: a self buff."},
    "E15": {"U": GENERATED, "V": "none", "X": "No bar: a debuff."},
    # Water Shield built 2026-11-25 (user request: self-cast when no ally is selected).
    "W12": {"U": GENERATED, "V": "none", "X": "No bar: a shield."},
}

zin = zipfile.ZipFile(PATH)
sheet = zin.read("xl/worksheets/sheet1.xml").decode("utf-8")


def cell_text(row, col):
    m = re.search(r'<c r="%s%d"([^>]*?)(?:/>|>(.*?)</c>)' % (col, row), sheet, re.S)
    if not m or not m.group(2):
        return ""
    t = re.search(r"<t[^>]*>(.*?)</t>", m.group(2), re.S)
    if t:
        return t.group(1)
    v = re.search(r"<v>(.*?)</v>", m.group(2))
    return v.group(1) if v else ""


def col_index(c):
    n = 0
    for ch in c:
        n = n * 26 + ord(ch) - 64
    return n


def set_cell(row, col, value):
    global sheet
    pat = re.compile(r'<c r="%s%d"( s="\d+")?[^>]*?(?:/>|>.*?</c>)' % (col, row), re.S)
    m = pat.search(sheet)
    style = (m.group(1) or "") if m else ""
    text = value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    new = '<c r="%s%d"%s t="inlineStr"><is><t>%s</t></is></c>' % (col, row, style, text)
    if m:
        assert "<f>" not in m.group(0), "%s%d holds a formula" % (col, row)
        sheet = sheet[:m.start()] + new + sheet[m.end():]
        return
    row_m = re.search(r'<row r="%d"[^>]*>(.*?)</row>' % row, sheet, re.S)
    insert_at = row_m.end(1)
    for c in re.finditer(r'<c r="([A-Z]+)%d"' % row, row_m.group(1)):
        if col_index(c.group(1)) > col_index(col):
            insert_at = row_m.start(1) + c.start()
            break
    sheet = sheet[:insert_at] + new + sheet[insert_at:]


rows = {cell_text(r, "A"): r for r in range(2, 400) if cell_text(r, "A") in CHANGES}
assert set(rows) == set(CHANGES), set(rows) ^ set(CHANGES)
for ability_id, cols in CHANGES.items():
    for col, value in cols.items():
        set_cell(rows[ability_id], col, value)
tmp = PATH + ".tmp"
with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
    for info in zin.infolist():
        data = zin.read(info.filename)
        if info.filename == "xl/worksheets/sheet1.xml":
            data = sheet.encode("utf-8")
        zout.writestr(info, data)
zin.close()
shutil.move(tmp, PATH)
print("patched", len(CHANGES), "Earth rows")
